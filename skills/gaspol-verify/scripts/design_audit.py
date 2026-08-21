"""
Design Audit Script -- offline, pre-merge design-compliance lint for gaspol-verify Layer 4.

Detects, and only what it actually detects:
- Colours and fonts that are not in the project's DESIGN.md token contract,
  severity split by CSS role (structural BLOCKS, decorative WARNs)
- WCAG 2.1 AA contrast of the contract's own foreground/background token pairs
- Non-responsive layouts (missing breakpoints)
- Missing component states (loading/error/empty)
- Accessibility gaps (missing ARIA, no keyboard support)

Until IDS-7 this docstring also claimed "contrast issues" while the file
contained no contrast computation at all, and accepted a --design-system flag it
never read. Both are now true or gone. If a check is ever removed, remove its
line here in the same change -- a claimed check that does not run is worse than
a missing one, because it reads as covered.

Usage:
    python3 design_audit.py <project_root> [--changed-files BASE] [--design-system DIR] [--json]

    --changed-files BASE   audit only UI/style files changed in BASE..HEAD (Layer 4 mode)
    --design-system DIR    directory holding DESIGN.md, when not the project root
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


# Regex patterns for detection
HARDCODED_COLOR_PATTERNS = [
    # Hex colors in JSX/TSX/Vue
    re.compile(r"(?:color|background|bg|border|fill|stroke)[:=][\s'\"`]*#[0-9a-fA-F]{3,8}"),
    # RGB/RGBA
    re.compile(r"(?:color|background|bg|border|fill|stroke)[:=][\s'\"`]*rgba?\("),
    # Tailwind arbitrary values
    re.compile(r"\b(?:bg|text|border)-\[#[0-9a-fA-F]{3,8}\]"),
    # SHORTHAND. `border: 1px solid #999` is the standard border syntax and was
    # invisible to every pattern above, which require the literal to sit
    # immediately after the property name. The blocking verdict rests on this
    # detector, so its blind spots decided what silently passed -- and this was
    # the commonest form of all.
    re.compile(r"\b(?:border|outline)(?:-(?:top|right|bottom|left|block|inline))?\s*:[^;{}\n]*?(?:#[0-9a-fA-F]{3,8}|rgba?\()"),
    # Decorative colour carriers. Detected so they can be classified WARN --
    # before IDS-7 they were invisible, so the docs promised a WARN for
    # shadows that the scanner could never emit.
    re.compile(r"\b(?:shadow|drop-shadow|ring)-\[[^\]]*#[0-9a-fA-F]{3,8}[^\]]*\]"),
    re.compile(r"(?:box-shadow|text-shadow)\s*:[^;}]*(?:#[0-9a-fA-F]{3,8}|rgba?\()"),
]

HARDCODED_FONT_PATTERNS = [
    re.compile(r"font-family[:=][\s'\"`]+[^var(]"),
    # Tailwind arbitrary font
    re.compile(r"\bfont-\[[^\]]+\]"),
]

# Which CSS role a colour plays. Decided by property name, so the verdict is
# deterministic and needs no judgement call.
#
# Structural colours carry the design: a wrong one is visible drift from the
# mockup, which is the whole reason this gate exists. Decorative colours are
# ordinary craft -- a one-off `rgba(0,0,0,0.05)` shadow is not drift. Blocking on
# those produces false alarms, false alarms get the gate switched off, and a
# disabled gate is worth less than a noisy one.
DECORATIVE_COLOR_ROLE = re.compile(
    r"box-shadow|text-shadow|outline-color|\bshadow-\[|\bring-\[|\bdrop-shadow-\[",
    re.I,
)
# Any colour carrying transparency is decorative by construction: a token map
# holds opaque brand colours, so an alpha value can never match one.
TRANSPARENT_COLOR = re.compile(
    # A 4th component in rgba() is alpha, whatever its notation: 0, 0.05, .5, 1,
    # or a percentage. Requiring a decimal point missed rgba(0,0,0,0) -- fully
    # transparent, and the docs promise anything with alpha only WARNs.
    r"rgba?\([^)]*,[^)]*,[^)]*,[^)]*\)|#[0-9a-fA-F]{8}\b",
    re.I,
)

HEX_IN_TEXT = re.compile(r"#[0-9a-fA-F]{3,8}\b")

# Responsive breakpoint indicators (Tailwind)
RESPONSIVE_INDICATORS = re.compile(r"\b(?:sm|md|lg|xl|2xl):[a-z-]+")

# State indicators
STATE_INDICATORS = {
    "loading": re.compile(r"\b(?:loading|isLoading|pending|isPending)\b"),
    "error": re.compile(r"\b(?:error|isError|hasError)\b"),
    "empty": re.compile(r"\b(?:empty|isEmpty|nodata|no_data)\b"),
}

# A11y indicators
A11Y_PATTERNS = {
    "aria": re.compile(r"\baria-[a-z]+"),
    "role": re.compile(r'\brole=["\']'),
    "semantic": re.compile(r"<(?:nav|main|article|section|aside|header|footer)\b"),
    "keyboard": re.compile(r"\b(?:onKeyDown|onKeyPress|tabIndex)\b"),
}

# UI-related file extensions
UI_EXTENSIONS = {".tsx", ".jsx", ".vue", ".svelte", ".astro", ".html"}
STYLE_EXTENSIONS = {".css", ".scss", ".sass", ".module.css"}


class DesignContractError(Exception):
    """A DESIGN.md exists but cannot be read as a token contract.

    Deliberately distinct from "no contract at all". A present-but-broken file
    proves someone INTENDED a contract, so continuing without one would silently
    drop a gate they asked for. Callers must stop and ask, never treat this as
    an empty contract -- an empty contract reads as "nothing violated".
    """


def _strip_inline_comment(value: str) -> str:
    """Drop a trailing ` # comment` from a frontmatter value.

    Without this, `text: "#1F2937"  # ink` stored the token as
    `#1F2937"  # ink`, so the colour the file itself DECLARES was reported as an
    off-contract structural violation everywhere it appeared -- a false BLOCKING
    on correct code, from an edit anyone hand-maintaining this file would make.

    Only a `#` preceded by whitespace starts a comment; a leading `#` is the hex
    colour itself and must survive.
    """
    return re.sub(r"\s+#.*$", "", value).strip()


def _normalise_hex(value: str) -> str:
    """Lowercase a hex colour and expand the 3-digit form to 6 digits.

    Without this, `#FFF` and `#ffffff` are the same colour stored under two
    different keys, and half the contract silently fails to match.
    Only hex is lowercased. Non-hex values (font names, `rgb(...)`) keep their
    author casing -- `Poppins` is what appears in the source and in the report,
    and folding it to `poppins` would make both harder to match and to read.
    """
    v = value.strip().strip("\"'")
    if re.fullmatch(r"#[0-9a-fA-F]{3}", v):
        return "#" + "".join(c * 2 for c in v[1:]).lower()
    if re.fullmatch(r"#[0-9a-fA-F]{6,8}", v):
        return v.lower()
    return v


def load_design_contract(project_root) -> dict | None:
    """Read the token contract from <project_root>/DESIGN.md.

    Expected shape -- YAML frontmatter delimited by `---` on its own line at the
    very start of the file, with two recognised top-level keys:

        ---
        colors:
          primary: "#2563EB"
          text:    "#1F2937"
        fonts:
          heading: "Poppins"
          body:    "Inter"
        ---

    Values may be quoted or bare. Any other top-level key is ignored rather than
    rejected, so the file stays useful as human documentation. Format origin:
    Google Stitch DESIGN.md, with 73 worked examples at
    https://github.com/voltagent/awesome-design-md (referenced, never vendored).

    Parsed with the stdlib on purpose: the shape is flat `key: value` under two
    headings, so a real YAML dependency would buy nothing.

    Three states, and they must stay distinct:
      * file absent               -> None      (gate not run; NOT a failure)
      * parses, has colors        -> dict      (gate active)
      * present but unparseable   -> raises DesignContractError (caller STOPS)
    """
    path = Path(project_root) / "DESIGN.md"
    if not path.is_file():
        return None

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise DesignContractError(f"{path}: unreadable ({exc})") from exc

    match = re.match(r"^---[ \t]*\n(.*?)\n---[ \t]*(?:\n|$)", text, re.S)
    if not match:
        raise DesignContractError(
            f"{path}: no YAML frontmatter -- expected a '---' delimited block at the top of the file"
        )

    contract: dict[str, dict[str, str]] = {"colors": {}, "fonts": {}}
    section = None
    for raw in match.group(1).split("\n"):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        top = re.fullmatch(r"([A-Za-z_][\w-]*):[ \t]*", raw)
        if top:
            key = top.group(1).lower()
            section = key if key in contract else None
            continue
        entry = re.fullmatch(r"[ \t]+([A-Za-z_][\w-]*):[ \t]*(.+?)[ \t]*", raw)
        if entry and section:
            value = _strip_inline_comment(entry.group(2))
            contract[section][entry.group(1).lower()] = _normalise_hex(value)

    if not contract["colors"]:
        raise DesignContractError(
            f"{path}: frontmatter has no non-empty 'colors:' map -- nothing to enforce"
        )

    return contract


# WCAG 2.1 AA. Written out so nobody re-derives it wrong from memory.
AA_NORMAL_TEXT = 4.5   # body copy
AA_LARGE_TEXT = 3.0    # large text and UI boundaries

# Which token names read as foreground vs background. Deliberately narrow: a
# pairing that cannot be determined is REPORTED as undetermined, never guessed.
# An assumed pair graded confidently is the same lie this check exists to fix.
_FOREGROUND_TOKENS = ("text", "ink", "body", "foreground", "fg", "on-surface")
_BACKGROUND_TOKENS = ("surface", "background", "bg", "canvas", "paper")


def _relative_luminance(hex_colour: str) -> float:
    """WCAG 2.1 relative luminance of an opaque #rrggbb colour."""
    h = _normalise_hex(hex_colour).lstrip("#")[:6]
    channels = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255
        channels.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4)
    r, g, b = channels
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(hex_a: str, hex_b: str) -> float:
    """WCAG 2.1 contrast ratio between two colours. Order-independent, 1.0-21.0."""
    la, lb = _relative_luminance(hex_a), _relative_luminance(hex_b)
    lo, hi = sorted((la, lb))
    return (hi + 0.05) / (lo + 0.05)


def check_contract_contrast(contract: dict | None) -> list[dict]:
    """Grade every foreground/background token pair in the contract against AA.

    Returns a list of findings. All are WARN: a contract that ships a
    low-contrast pair is a design problem to fix, not a reason to block a branch
    that merely used the tokens as declared.

    When no pairing can be determined, that is REPORTED rather than silently
    skipped or, worse, guessed at. Grading an assumed pair confidently would
    reintroduce the exact defect this replaces -- a contrast verdict nobody
    actually computed.
    """
    if not contract:
        return []

    colors = contract.get("colors", {})
    # An 8-digit #rrggbbaa carries alpha, and luminance is computed from the RGB
    # bytes alone -- so 6% black would grade 21:1, identical to opaque black, a
    # number with no relation to what renders. Excluded and SAID, never graded.
    def _opaque(v: str) -> bool:
        return v.startswith("#") and len(v) in (4, 7)

    translucent = sorted(k for k, v in colors.items() if v.startswith("#") and not _opaque(v))
    fg = {k: v for k, v in colors.items() if any(t in k for t in _FOREGROUND_TOKENS) and _opaque(v)}
    bg = {k: v for k, v in colors.items() if any(t in k for t in _BACKGROUND_TOKENS) and _opaque(v)}

    notes = []
    if translucent:
        notes.append({
            "severity": "INFO",
            "message": (
                "contrast: not graded for translucent token(s) "
                + ", ".join(translucent)
                + " — alpha is not composited, so a ratio would not describe what renders"
            ),
        })

    if not fg or not bg:
        return notes + [
            {
            "severity": "INFO",
            "message": (
                "contrast: no declared foreground/background pairing in DESIGN.md — "
                "not graded (naming a token 'text' and one 'surface' enables this check)"
            ),
        }]

    findings = list(notes)
    for fk, fv in sorted(fg.items()):
        for bk, bv in sorted(bg.items()):
            ratio = contrast_ratio(fv, bv)
            if ratio < AA_NORMAL_TEXT:
                findings.append({
                    "severity": "WARN",
                    "message": (
                        f"contrast: {fk} ({fv}) on {bk} ({bv}) is {ratio:.2f}:1 — "
                        f"below WCAG AA {AA_NORMAL_TEXT}:1 for body text"
                        + ("" if ratio < AA_LARGE_TEXT else f" (meets {AA_LARGE_TEXT}:1 for large text only)")
                    ),
                })
    return findings


def _declaration_at(line_text: str, match_text: str) -> str:
    """The single declaration containing `match_text`, not the whole line.

    Classifying on the whole line was a real hole: one minified rule such as
    `.a { background: #ff0000; box-shadow: 0 1px 2px rgba(0,0,0,.05) }` reported
    the structural violation as WARN because a decorative property shared the
    line -- and so did any Tailwind `className="shadow-[…] bg-[…]"`. Classifying
    on the bare match is the opposite error: the property name sits outside the
    matched fragment, so the WARN branch becomes unreachable.

    A Tailwind arbitrary value is bounded by whitespace or a quote; a CSS
    declaration is bounded by `;`, `{` or `}`.
    """
    idx = line_text.find(match_text)
    if idx < 0:
        return match_text

    delims = " \t\"'`" if "-[" in match_text else ";{}"
    start = max((line_text.rfind(d, 0, idx) for d in delims), default=-1)
    end_candidates = [line_text.find(d, idx + len(match_text)) for d in delims]
    end_candidates = [e for e in end_candidates if e != -1]
    end = min(end_candidates) if end_candidates else len(line_text)
    return line_text[start + 1 : end]


def _font_severity(line_text: str, contract: dict | None) -> str | None:
    """Classify a font declaration against the contract's `fonts:` map.

    Typography drift is exactly the complaint this gate exists for, so an
    off-contract family BLOCKS. Parsing `fonts:` and never reading it would be
    defect D1's shape -- a contract key consulted only by len() -- rebuilt
    inside the fix for D1.

    Three outcomes, and the middle one is the whole point of this docstring:

      * "BLOCKING"  -- a family is declared and this is not it
      * None        -- a declared family is used: compliant means silent
      * "UNJUDGED"  -- the contract has NO `fonts:` map, so nothing can be
                       judged. The finding is still REPORTED, exactly as it was
                       before any contract existed.

    `UNJUDGED` exists because collapsing it into None was the same defect this
    ticket exists to kill, one layer down. `extract-design-tokens` emits colours
    only, so the documented onboarding path produces a colours-only contract --
    and adopting one turned `Hardcoded fonts: 2` into `Hardcoded fonts: 0`. A
    count of zero reads as checked-and-clean; nothing had been checked.
    """
    if not contract:
        return None
    if not contract.get("fonts"):
        return "UNJUDGED"

    declared = {v.strip().strip("\"'").lower() for v in contract["fonts"].values()}
    used = re.search(r"font-family\s*[:=]\s*(.+?)(?:;|}|$)", line_text)
    if not used:
        used = re.search(r"font-\[([^\]]+)\]", line_text)
    if not used:
        return "BLOCKING"

    families = [
        f.strip().strip("\"'").replace("_", " ").lower()
        for f in used.group(1).split(",")
    ]
    # Generic fallbacks are not brand fonts; a stack is compliant when its FIRST
    # real family is declared.
    generics = {
        "sans-serif", "serif", "monospace", "cursive", "fantasy", "system-ui",
        "ui-sans-serif", "ui-serif", "ui-monospace",
        "inherit", "initial", "unset", "revert",
    }
    real = [f for f in families if f and f not in generics]
    if not real:
        # `inherit`, `unset`, or a bare `sans-serif` claims no brand font at all,
        # so there is nothing to judge against the contract. `font-family:
        # inherit` is idiomatic in a CSS reset -- blocking it is a false positive
        # on correct code.
        return None
    if real[0] in declared:
        return None
    return "BLOCKING"


RGB_CALL = re.compile(r"rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,[^)]*)?\)", re.I)


def _colours_in(text: str) -> list[str]:
    """Every colour literal in `text`, normalised to lowercase hex.

    Includes `rgb()`/`rgba()` written out numerically. Without this the SAME
    colour blocked or passed depending on notation -- `#2563eb` was silent while
    `rgb(37, 99, 235)` BLOCKED, because the contract holds hex and the comparison
    was hex-only. That is a false-alarm source, and false alarms are what get a
    gate switched off.
    """
    found = [_normalise_hex(h) for h in HEX_IN_TEXT.findall(text)]
    for r, g, b in RGB_CALL.findall(text):
        try:
            found.append("#%02x%02x%02x" % (int(r), int(g), int(b)))
        except ValueError:  # out of range -- not a colour we can compare
            continue
    return found


def contrast_gate_label(contract: dict | None, findings: list[dict]) -> str:
    """One line saying whether contrast was graded, and on how many pairs.

    `check_contract_contrast` returns [] both when there is nothing to grade and
    when every pair passes. That is the same inference-from-absence hole
    `font_gate` was added to close, one key over -- an empty list read as
    "clean" whether or not anything ran.
    """
    if contract is None:
        return "not run — no DESIGN.md"
    colors = contract.get("colors", {})
    opaque = {k: v for k, v in colors.items() if v.startswith("#") and len(v) in (4, 7)}
    fg = [k for k in opaque if any(x in k for x in _FOREGROUND_TOKENS)]
    bg = [k for k in opaque if any(x in k for x in _BACKGROUND_TOKENS)]
    if not fg or not bg:
        return "not run — no declared foreground/background pairing"
    below = sum(1 for f in findings if f.get("severity") == "WARN")
    return f"active — {len(fg) * len(bg)} pair(s) graded, {below} below AA {AA_NORMAL_TEXT}:1"


def _colour_severity(match_text: str, line_text: str, contract: dict | None) -> str | None:
    """Classify one colour occurrence against the token contract.

    Returns None when there is nothing to report -- either no contract is loaded
    (no judgement is made, as before IDS-7) or every colour in the
    match is a contract token. Compliant must mean SILENT: emitting a
    low-severity finding for a colour that is correct makes the report unreadable
    and trains people to skim past it.

    The role is read from the whole LINE, not from `match_text`. The regexes
    match a short fragment such as `color: rgba(` -- a decorative declaration
    like `box-shadow: 0 1px 2px rgba(...)` has its property name outside that
    fragment, so classifying on the fragment alone would leave the WARN branch
    unreachable and quietly block every shadow in the codebase.
    """
    if not contract:
        return None

    allowed = {v for v in contract.get("colors", {}).values() if v.startswith("#")}
    scope_for_value = _declaration_at(line_text, match_text)
    literals = _colours_in(match_text) or _colours_in(scope_for_value)
    if literals and all(lit in allowed for lit in literals):
        return None

    scope = _declaration_at(line_text, match_text)
    if DECORATIVE_COLOR_ROLE.search(scope) or TRANSPARENT_COLOR.search(scope):
        return "WARN"
    return "BLOCKING"


def scan_file(path: Path, contract: dict | None = None) -> dict:
    """Scan a single UI file for design system violations."""
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as exc:
        return {"error": str(exc), "file": str(path)}

    findings = {
        "file": str(path),
        "hardcoded_colors": [],
        "hardcoded_fonts": [],
        "responsive_breakpoints": False,
        "states": {k: False for k in STATE_INDICATORS},
        "a11y": {k: False for k in A11Y_PATTERNS},
    }

    # Patterns overlap by design (a shorthand pattern and a longhand one can both
    # match `border-color: #999`), so the same declaration must not be reported
    # twice. Key on the line plus the colour literal, not on the matched text --
    # two patterns produce different fragments for one violation.
    seen_colours: set[tuple[int, str]] = set()
    for pattern in HARDCODED_COLOR_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            literals = tuple(sorted(_normalise_hex(h) for h in HEX_IN_TEXT.findall(match.group())))
            key = (line_num, "|".join(literals) or match.group())
            if key in seen_colours:
                continue
            seen_colours.add(key)
            item = {"line": line_num, "match": match.group()}
            if contract:
                line_text = content.split("\n")[line_num - 1]
                severity = _colour_severity(match.group(), line_text, contract)
                if severity is None:
                    continue  # the colour IS a token -- compliant means silent
                item["severity"] = severity
            findings["hardcoded_colors"].append(item)

    for pattern in HARDCODED_FONT_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            item = {"line": line_num, "match": match.group()}
            if contract:
                severity = _font_severity(content.split("\n")[line_num - 1], contract)
                if severity is None:
                    continue  # a declared family is used -- compliant means silent
                if severity != "UNJUDGED":
                    item["severity"] = severity
                # UNJUDGED: no fonts: map, so report it exactly as the
                # no-contract path does -- unjudged, but never silenced.
            findings["hardcoded_fonts"].append(item)

    findings["responsive_breakpoints"] = bool(RESPONSIVE_INDICATORS.search(content))

    for state_name, pattern in STATE_INDICATORS.items():
        findings["states"][state_name] = bool(pattern.search(content))

    for a11y_name, pattern in A11Y_PATTERNS.items():
        findings["a11y"][a11y_name] = bool(pattern.search(content))

    return findings


SKIP_DIRS = {"node_modules", ".git", ".next", "dist", "build", "out", "__pycache__", ".cache"}


def is_ui_file(path: Path) -> bool:
    """Return True if path is a UI or style source file.

    STYLE_EXTENSIONS used to be declared and never consulted here, so `.css` and
    `.scss` were never scanned at all while Layer 4's docs claimed they were --
    the same defect class as a flag that is parsed and never read.
    """
    return path.suffix in UI_EXTENSIONS or path.suffix in STYLE_EXTENSIONS


def scan_files(paths, contract: dict | None = None) -> list[dict]:
    """Audit exactly the given paths, skipping anything that is not a UI/style file.

    The single scanning entry point. `scan_project` collects paths and delegates
    here, so whole-project and diff-scoped modes cannot drift apart.

    `contract` is the loaded DESIGN.md token map, or None. With None no
    `severity` field is added and no contract-derived judgement is made.

    The findings LIST is NOT identical to pre-IDS-7: this ticket also added
    decorative-carrier patterns (`shadow-[…]`, `box-shadow`, `text-shadow`) and
    a border/outline shorthand pattern, all of which fire with or without a
    contract. Saying "byte-for-byte" here was wrong, and it survived three
    review rounds because the guarding test only asserted the absence of a
    severity field.
    """
    results = []
    for raw in paths:
        path = Path(raw)
        if path.is_file() and is_ui_file(path):
            results.append(scan_file(path, contract))
    return results


def changed_ui_files(project_root: Path, base: str) -> list[Path]:
    """Return the UI/style files changed between `base` and HEAD.

    Why this exists: `scan_project` walks the whole tree, so on a repository with
    existing code Layer 4 collected hundreds of findings that predate the branch.
    Because Layer 4 FAILS below score 60, the gate then failed permanently and
    got ignored -- a gate that always fails is indistinguishable from no gate.

    An unresolvable base raises. It must never fall back to scanning everything:
    a silent widening turns a green branch red for reasons nobody introduced.
    """
    # `f"{base}..HEAD"` is a single argv element, so a base beginning with `-`
    # arrives at git as an OPTION rather than a revision -- `--output=/tmp/x`
    # becomes `--output=/tmp/x..HEAD`, and git writes the diff to that path.
    # argparse rejects the space-separated form but passes `--changed-files=-…`
    # straight through, so the guard belongs here. BASE is operator-supplied
    # today, but this is a trust boundary and those are not where scope gets cut.
    if base.startswith("-"):
        raise RuntimeError(
            f"refusing BASE {base!r}: a revision must not begin with '-' — "
            "git would parse it as an option, not a commit"
        )

    proc = subprocess.run(
        ["git", "-C", str(project_root), "diff", "--name-only", f"{base}..HEAD"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"git diff --name-only {base}..HEAD failed in {project_root}: "
            f"{proc.stderr.strip() or 'unknown error'}"
        )

    # git reports paths relative to the REPOSITORY ROOT, not to -C. Joining them
    # onto project_root doubles the prefix whenever project_root is a
    # subdirectory -- "apps/web" + "apps/web/src/A.tsx" -- and every path then
    # vanishes through is_file(). That is silent: zero files scanned, verdict
    # COMPLIANT. Not a gate that always fails (defect D3) but one that always
    # PASSES, on any monorepo.
    top = subprocess.run(
        ["git", "-C", str(project_root), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if top.returncode != 0:
        raise RuntimeError(
            f"git rev-parse --show-toplevel failed in {project_root}: "
            f"{top.stderr.strip() or 'unknown error'}"
        )
    repo_root = Path(top.stdout.strip()).resolve()
    root = project_root.resolve()

    files = []
    for line in proc.stdout.splitlines():
        if not line or not is_ui_file(Path(line)):
            continue
        path = repo_root / line
        # Scope stays project_root: a changed file elsewhere in the monorepo is
        # someone else's diff, not this audit's.
        if root == repo_root or root in path.parents:
            files.append(path)
    return files


def scan_project(project_root: Path, contract: dict | None = None) -> list[dict]:
    """Scan an entire project for UI/style files and audit each.

    Kept for deliberate whole-project audits. Layer 4 uses the diff-scoped mode.
    """
    if not project_root.exists():
        raise FileNotFoundError(f"Project root not found: {project_root}")

    return scan_files(
        (
            path
            for path in project_root.rglob("*")
            if not any(part in SKIP_DIRS for part in path.parts)
        ),
        contract,
    )


def summarize(findings: list[dict]) -> dict:
    """Aggregate findings into summary counts."""
    total_files = len(findings)
    total_hardcoded_colors = sum(len(f.get("hardcoded_colors", [])) for f in findings)
    blocking_findings = sum(
        1
        for f in findings
        for c in f.get("hardcoded_colors", [])
        if c.get("severity") == "BLOCKING"
    ) + sum(
        1
        for f in findings
        for c in f.get("hardcoded_fonts", [])
        if c.get("severity") == "BLOCKING"
    )
    total_hardcoded_fonts = sum(len(f.get("hardcoded_fonts", [])) for f in findings)
    files_without_responsive = sum(1 for f in findings if not f.get("responsive_breakpoints", False))
    files_missing_states = {
        state: sum(1 for f in findings if not f.get("states", {}).get(state, False))
        for state in STATE_INDICATORS
    }
    files_weak_a11y = sum(
        1 for f in findings
        if not any(f.get("a11y", {}).get(k, False) for k in ("aria", "role", "semantic"))
    )

    return {
        "total_ui_files": total_files,
        "hardcoded_colors": total_hardcoded_colors,
        "blocking_findings": blocking_findings,
        "hardcoded_fonts": total_hardcoded_fonts,
        "files_without_responsive": files_without_responsive,
        "files_missing_states": files_missing_states,
        "files_weak_a11y": files_weak_a11y,
    }


def verdict(summary: dict) -> str:
    """Return overall compliance verdict.

    With a token contract loaded, a single BLOCKING colour fails outright rather
    than being scored: the contract says which colours are correct, so an
    off-contract structural colour is drift by definition, not a deduction to be
    averaged away by an otherwise tidy file. WARN findings never fail.
    """
    if summary.get("blocking_findings", 0) > 0:
        return "🔴 NON-COMPLIANT"

    score = 100
    if summary["hardcoded_colors"] > 0:
        score -= min(30, summary["hardcoded_colors"] * 2)
    if summary["hardcoded_fonts"] > 0:
        score -= min(20, summary["hardcoded_fonts"] * 3)
    if summary["files_without_responsive"] > summary["total_ui_files"] * 0.5:
        score -= 20
    if summary["files_weak_a11y"] > summary["total_ui_files"] * 0.3:
        score -= 15

    if score >= 80:
        return "🟢 COMPLIANT"
    elif score >= 60:
        return "🟡 PARTIAL COMPLIANCE"
    else:
        return "🔴 NON-COMPLIANT"


def main():
    parser = argparse.ArgumentParser(description="Design system compliance audit")
    parser.add_argument("project_path", help="Target project root")
    parser.add_argument(
        "--design-system",
        metavar="DIR",
        help="Directory holding DESIGN.md, when it is not the project root",
    )
    parser.add_argument(
        "--changed-files",
        metavar="BASE",
        help="Audit only UI/style files changed between BASE and HEAD (Layer 4 mode)",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    project_root = Path(args.project_path).resolve()

    # The token contract. `--design-system` names the directory holding DESIGN.md
    # when it does not sit at the project root. It used to be parsed and never
    # read -- a flag that silently does nothing is worse than no flag, because it
    # reads as a feature that is switched on.
    contract_root = Path(args.design_system).resolve() if args.design_system else project_root
    try:
        contract = load_design_contract(contract_root)
    except DesignContractError as exc:
        # Present but unreadable. STOP -- never continue as if no contract exists,
        # which would silently drop a gate the project asked for.
        print(f"design_audit: design-contract: UNKNOWN — {exc}", file=sys.stderr)
        return 2

    if args.changed_files:
        try:
            findings = scan_files(
                changed_ui_files(project_root, args.changed_files), contract
            )
        except RuntimeError as exc:
            print(f"design_audit: {exc}", file=sys.stderr)
            return 2
    else:
        findings = scan_project(project_root, contract)
    summary = summarize(findings)
    overall_verdict = verdict(summary)

    contrast_findings = check_contract_contrast(contract)
    contrast_gate = contrast_gate_label(contract, contrast_findings)

    # Computed once and emitted in BOTH branches. Layer 4 invokes --json, so a
    # state that lives only in the text branch is invisible to the gate that
    # consumes this -- leaving a reader to infer "unjudged" from the ABSENCE of a
    # severity key, which is the inference-from-absence this state exists to end.
    if contract is None:
        font_gate = "not run — no DESIGN.md"
    elif not contract.get("fonts"):
        font_gate = "not run — DESIGN.md declares no fonts: map, font findings are unjudged"
    else:
        font_gate = f"active ({len(contract['fonts'])} declared families)"

    if args.json:
        output = {
            "project": str(project_root),
            "design_contract": (
                "none" if contract is None
                else f"loaded ({len(contract['colors'])} colors, {len(contract['fonts'])} fonts)"
            ),
            "font_gate": font_gate,
            "contrast_gate": contrast_gate,
            "summary": summary,
            "verdict": overall_verdict,
            "contrast": contrast_findings,
            "findings": findings,
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"Design Audit — {project_root}")
        print(f"Verdict: {overall_verdict}")
        print(
            "design-contract: none — token gate not run"
            if contract is None
            else f"design-contract: loaded ({len(contract['colors'])} colors, {len(contract['fonts'])} fonts)"
        )
        print(f"font-gate: {font_gate}")
        print(f"contrast-gate: {contrast_gate}")
        for f in contrast_findings:
            print(f"  {f['severity']}: {f['message']}")
        print()
        print(f"Files scanned: {summary['total_ui_files']}")
        print(f"Hardcoded colors: {summary['hardcoded_colors']}")
        print(f"Hardcoded fonts: {summary['hardcoded_fonts']}")
        print(f"Files without responsive breakpoints: {summary['files_without_responsive']}")
        print(f"Files with weak a11y: {summary['files_weak_a11y']}")
        print()
        print("State coverage (files missing each state indicator):")
        for state, count in summary["files_missing_states"].items():
            print(f"  {state}: {count}")

    return 0 if "COMPLIANT" in overall_verdict and "NON" not in overall_verdict else 1


if __name__ == "__main__":
    sys.exit(main())
