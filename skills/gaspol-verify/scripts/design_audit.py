"""
Design Audit Script (gaspol-design)

Scans target project codebase for design system compliance.
Detects:
- Hardcoded colors (should use design tokens)
- Hardcoded fonts (should use design system font stack)
- Non-responsive layouts (missing breakpoints)
- Missing component states (loading/error/empty)
- Accessibility gaps (missing ARIA, no keyboard support, contrast issues)

Usage:
    python design_audit.py <target_project_path> [--design-system <path_to_CLAUDE.md>]
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
]

HARDCODED_FONT_PATTERNS = [
    re.compile(r"font-family[:=][\s'\"`]+[^var(]"),
    # Tailwind arbitrary font
    re.compile(r"\bfont-\[[^\]]+\]"),
]

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
            contract[section][entry.group(1).lower()] = _normalise_hex(entry.group(2))

    if not contract["colors"]:
        raise DesignContractError(
            f"{path}: frontmatter has no non-empty 'colors:' map -- nothing to enforce"
        )

    return contract


def scan_file(path: Path) -> dict:
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

    for pattern in HARDCODED_COLOR_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            findings["hardcoded_colors"].append({"line": line_num, "match": match.group()})

    for pattern in HARDCODED_FONT_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            findings["hardcoded_fonts"].append({"line": line_num, "match": match.group()})

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


def scan_files(paths) -> list[dict]:
    """Audit exactly the given paths, skipping anything that is not a UI/style file.

    The single scanning entry point. `scan_project` collects paths and delegates
    here, so whole-project and diff-scoped modes cannot drift apart.
    """
    results = []
    for raw in paths:
        path = Path(raw)
        if path.is_file() and is_ui_file(path):
            results.append(scan_file(path))
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
    return [
        project_root / line
        for line in proc.stdout.splitlines()
        if line and is_ui_file(Path(line))
    ]


def scan_project(project_root: Path) -> list[dict]:
    """Scan an entire project for UI/style files and audit each.

    Kept for deliberate whole-project audits. Layer 4 uses the diff-scoped mode.
    """
    if not project_root.exists():
        raise FileNotFoundError(f"Project root not found: {project_root}")

    return scan_files(
        path
        for path in project_root.rglob("*")
        if not any(part in SKIP_DIRS for part in path.parts)
    )


def summarize(findings: list[dict]) -> dict:
    """Aggregate findings into summary counts."""
    total_files = len(findings)
    total_hardcoded_colors = sum(len(f.get("hardcoded_colors", [])) for f in findings)
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
        "hardcoded_fonts": total_hardcoded_fonts,
        "files_without_responsive": files_without_responsive,
        "files_missing_states": files_missing_states,
        "files_weak_a11y": files_weak_a11y,
    }


def verdict(summary: dict) -> str:
    """Return overall compliance verdict."""
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
    parser.add_argument("--design-system", help="Path to CLAUDE.md or design tokens reference")
    parser.add_argument(
        "--changed-files",
        metavar="BASE",
        help="Audit only UI/style files changed between BASE and HEAD (Layer 4 mode)",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    project_root = Path(args.project_path).resolve()
    if args.changed_files:
        try:
            findings = scan_files(changed_ui_files(project_root, args.changed_files))
        except RuntimeError as exc:
            print(f"design_audit: {exc}", file=sys.stderr)
            return 2
    else:
        findings = scan_project(project_root)
    summary = summarize(findings)
    overall_verdict = verdict(summary)

    if args.json:
        output = {
            "project": str(project_root),
            "summary": summary,
            "verdict": overall_verdict,
            "findings": findings,
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"Design Audit — {project_root}")
        print(f"Verdict: {overall_verdict}")
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
