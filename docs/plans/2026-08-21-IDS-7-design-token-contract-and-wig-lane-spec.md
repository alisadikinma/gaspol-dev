**Ticket:** IDS-7

# IDS-7 — Layer 4 gets a source of truth: DESIGN.md token contract + Web Interface Guidelines lane

## Why this exists

The user's standing complaint since the first review of this plugin: *"hasil akhir tidak sama
dgn mockup"* — a full app build ships colours and fonts that drifted from the design.

IDS-6 addressed the *context* half of the bug density problem (task briefs, fix-loop escalation,
conflict matrix). This ticket addresses the *fidelity* half, and it turns out most of the work
is not new construction. It is finishing something that was declared done and never wired up.

## What the audit actually found (2026-08-21)

Reading `skills/gaspol-verify/scripts/design_audit.py` (205 lines at the time of the audit) against what
`skills/gaspol-verify/SKILL.md` Layer 4 claims it does surfaced three defects. All three are
verified by reading the file, not inferred:

**D1 — `--design-system` is accepted and never read.**
`design_audit.py:170` declares `parser.add_argument("--design-system", help="Path to CLAUDE.md
or design tokens reference")`. Grep for `design_system` in the file: **0 hits**. The flag is
parsed into a namespace that nothing consults. Consequence: the script cannot compare a colour
against a token list, because it never loads one. It can only report "a hex literal appears
here" — which is not a compliance judgement, it is a pattern count.

**D2 — WCAG AA contrast is claimed in two places and computed in zero.**
The module docstring (line 10) lists "contrast issues" among what it detects.
`gaspol-verify/SKILL.md` Layer 4 states it validates "WCAG AA contrast ratios". Grep for
`contrast` in the script: **1 hit, and it is that docstring line**. No luminance computation, no
ratio, no threshold. This is the same defect class IDS-6 fixed at `gaspol-finish` Step 5 — a
step recorded as passed that never ran. Iron Law 3 forbids it everywhere else in this plugin.

**D3 — it scans the whole project, never the diff.**
`design_audit.py:104` `def scan_project(project_root: Path)` walks the tree. Grep for `git` in
the file: **0 hits**. On any repository with pre-existing code, Layer 4 collects hundreds of
findings that predate the branch. Because Layer 4 FAILS below score 60, the gate fails
permanently on any legacy project — which means in practice it is either ignored or switched
off. A gate that always fails is indistinguishable from no gate.

Taken together: Layer 4's design sub-check has been reporting a number, not enforcing a
contract, since v1.2.

## Prior-art verdict (gaspol-write-skill Step 0, three lookups)

| Lookup | Result |
|---|---|
| Installed already? | `ui-ux-pro-max` (design *generation*, 84 styles / 192 palettes) and 12 `leonxlnx/taste-skill` skills are installed. **None lints code against a project token contract.** `ui-ux-pro-max`'s own audit needs Playwright + a running URL — it cannot run offline pre-merge, which is why `design_audit.py` was kept in v1.14. |
| Built into the harness? | `/security-review` exists and is already wired into `gaspol-finish`. There is no built-in design or a11y lint. |
| On the marketplace? | `vercel-labs/agent-skills` ships `web-design-guidelines`. |

**Verdict: DELTA.** Named explicitly, because a DELTA that does not name its delta is a fake one:

- `web-design-guidelines`' SKILL.md is 1.2KB and contains **zero rules**. It is a pointer that
  WebFetches `vercel-labs/web-interface-guidelines/main/command.md` at review time. We adopt
  **the ruleset and the fetch-don't-fork mechanism**; we do not install the skill, because a
  fetcher wrapped in a second fetcher buys nothing and costs a per-session description.
- `voltagent/awesome-design-md` supplies the **DESIGN.md format** (YAML frontmatter with a
  machine-readable `colors:` map, originally from Google Stitch) and 73 worked examples. We
  adopt the format and **point at** the repo. We do **not** vendor the 73 files — that is
  precisely the 1.4MB fork deleted in v1.14.
- `Abhinav1004/Image2Code` was evaluated and **rejected**: academic pix2code (TensorFlow/Keras +
  Streamlit), 77% accuracy on a synthetic DSL over toy iOS/Android/Web datasets. Not tooling, not
  maintained as such, and outperformed by any current VLM reading a screenshot.

## KB precedent applied

| Entry | Applied as |
|---|---|
| `architecture/search-the-market-before-building-a-capability` (accepted 2026-08-21) | The three lookups above were run before any design was written. |
| `architecture/marker-file-is-not-proof-tool-installed` (accepted 2026-08-20) | **A binding constraint, not an option.** A present `DESIGN.md` proves the project *intends* a token contract; it does not prove the file parses. Three states must stay distinct — see the table in Part 1. Never emit a plausible pass. |
| `architecture/vacuous-assertion-proves-nothing` | Every new gate needs a fixture that *violates* the contract and makes the test fail first. A test that passes against a compliant fixture only proves nothing crashed. |

## Design

### Part 1 — DESIGN.md as the token contract

A `DESIGN.md` at the target project root. Plain markdown, YAML frontmatter, no tooling to
install and nothing to parse beyond stdlib:

```yaml
---
colors:
  primary: "#2563EB"
  text:    "#1F2937"
  border:  "#E5E7EB"
  surface: "#FFFFFF"
fonts:
  heading: "Poppins"
  body:    "Inter"
---
```

Two authoring paths, one format (user decision, 2026-08-21):

- **Existing projects** — a script extracts tokens from what the repo already declares:
  `tailwind.config.{js,ts,cjs,mjs}` theme colours, CSS custom properties (`--color-*`,
  `--brand-*`), or a `theme.json`. Extraction only; it never invents a token.
- **New projects** — `gaspol-brainstorm` Phase 3 writes it from the approved `ui-ux-pro-max`
  output, freezing the agreed palette into the contract before any code exists.

**When the extractor runs — offered, never automatic.** The first time Layer 4 meets a UI
changeset in a repo with no `DESIGN.md`, it runs the extractor in dry-run, shows the tokens it
found, and asks via `AskUserQuestion`: `[Write DESIGN.md]` / `[Not now — keep the gate off]` /
`[I'll write it myself]`. Writing a contract file into someone's repository unasked is the same
overreach as auto-installing a marketplace skill. A `[Not now]` answer is recorded in the
ledger and Layer 4 does not re-ask on later phases of the same branch.

Three states, kept strictly distinct:

| State | Behaviour |
|---|---|
| No `DESIGN.md` | Current behaviour unchanged. Recorded as `design-contract: none — token gate not run`. **Not a failure.** |
| Present and parses | Token gate active. |
| Present but unparseable / no `colors:` map | **`UNKNOWN` + STOP and ask the user.** Never a silent pass, never a silent skip. |

### Part 2 — enforcement strength by CSS role

An off-contract colour is not uniformly a defect. Deciding by **CSS property name** keeps this
deterministic — no heuristics, no model judgement (user decision, 2026-08-21):

| BLOCKING (must match a token) | WARN only |
|---|---|
| `color`, `background`, `background-color`, `border-color`, `fill`, `stroke` | `box-shadow`, `text-shadow`, `outline-color` |
| Tailwind `bg-[#…]`, `text-[#…]`, `border-[#…]` | Tailwind `shadow-[…]`, any colour with alpha < 1 (`rgba(…, 0.05)`) |

Rationale for the split: a one-off `rgba(0,0,0,0.05)` shadow is ordinary craft, not drift.
Blocking on it produces false alarms, false alarms produce a disabled gate, and a disabled gate
is worth less than a noisy one.

Matching is case-insensitive and normalises 3-digit hex to 6-digit before comparison
(`#FFF` and `#ffffff` are the same token).

### Part 3 — scan the diff, not the project

`scan_project(project_root)` gains a file-list entry point. `gaspol-verify` passes the branch's
changed UI files, derived from `git diff --name-only <BASE>..HEAD` filtered to the existing
`UI_EXTENSIONS` / `STYLE_EXTENSIONS` sets. Whole-project mode stays available behind an explicit
flag for a deliberate audit, but Layer 4 never uses it.

This is what makes the gate usable on a repository that already has code, and it closes D3.

### Part 4 — the Web Interface Guidelines lane

Fetch `https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md`
(~7.8KB, 22 sections: accessibility, focus states, forms, animation, performance, mobile, touch)
and apply it to the same changed-file list. Its output format is already `file:line - terse
finding`, which Layer 4 consumes without an adaptor.

Runs automatically whenever the changeset contains a UI file (user decision, 2026-08-21). Cost is
~2k tokens on UI diffs and zero on backend-only work.

Offline or fetch failure → fall back to `design_audit.py` alone and record
`wig-lane: not run (fetch failed)`. **Never recorded as passed.** Same rule
`gaspol-finish` already applies to an unavailable `/security-review`.

Fetch-don't-fork is the point: gaspol's static `rules/` forks will drift exactly as the 1.4MB
`gaspol-design` fork did. Vercel maintains the ruleset; we consume it.

### Part 5 — remove or honour the contrast claim

Honour it. WCAG relative-luminance and contrast ratio is ~15 lines of pure stdlib Python, and
Part 1 already supplies the colours to compare. Check foreground/background token pairs declared
in `DESIGN.md` against the AA thresholds (4.5:1 body, 3:1 large text / UI boundaries).

If a pair cannot be determined (no declared pairing), report it as such — do not assume a pairing
and grade it. The docstring and `gaspol-verify/SKILL.md` are corrected to describe what actually
runs, in the same change.

## Data Integration Map

| Feature | Data source | Exists? | Action |
|---|---|---|---|
| Token contract | `DESIGN.md` frontmatter at target project root | No | Create — extractor script + brainstorm Phase 3 authoring |
| Token extraction input | `tailwind.config.*`, CSS custom properties, `theme.json` in the target repo | Yes (varies per project) | Read only, never write to them |
| Changed-file list | `git diff --name-only <BASE>..HEAD` | Yes (git) | Wire into `design_audit.py` |
| UI/style extensions | `UI_EXTENSIONS` / `STYLE_EXTENSIONS` in `design_audit.py` | Yes | Reuse as-is |
| WIG ruleset | `vercel-labs/web-interface-guidelines/main/command.md` | Yes (upstream) | Fetch at review time, never vendor |
| DESIGN.md format reference | `voltagent/awesome-design-md` (73 examples) | Yes (upstream) | Point at it, never vendor |
| Contrast thresholds | WCAG 2.1 AA (4.5:1 / 3:1) | N/A (constants) | Implement in stdlib Python |

No placeholders anywhere in this ticket: every input above is a real file, a real git command, or
a real fetched document.

## Scope boundary — stated so it is not overclaimed later

`DESIGN.md` pins **tokens** — colour, typography, spacing. It does **not** pin **layout
geometry**. This ticket therefore closes the "wrong colours and fonts" half of the
mockup-mismatch complaint and leaves the "wrong layout" half open.

Layout geometry remains the subject of IDS-6's deferred Part B (canvas.html as a single visual
source, `data-vv` DOM markers, geometry diffing, a runner probe). Nothing here supersedes that,
and nothing here should be reported as having solved it.

## Laziness ladder notes

- No new dependency. YAML frontmatter is parsed with a stdlib reader (~54 lines) for the flat
  `key: "value"` shape actually used — pulling in PyYAML for that would fail rung 4.
- No new skill. This is an upgrade to `gaspol-verify` Layer 4 plus one extractor script.
- No vendored data. Both upstreams are referenced, not copied.
- The whole-project scan is kept behind a flag rather than deleted — one line, and it is the
  extractor's own useful mode.

## Risks

| Risk | Mitigation |
|---|---|
| Extractor invents tokens from a config it half-understands | Extraction is literal — a colour must appear as a value in the source file. Unrecognised config shape → emit nothing and say so, never a guess. |
| Token gate fires on a legacy repo's untouched files | Part 3: diff-scoped only. |
| WIG fetch becomes a hard dependency | Explicit fallback + honest `not run` record. Never blocks on network. |
| Upstream WIG changes shape and breaks parsing | It is prose consumed by a model, not a parsed schema. A shape change degrades quality, not correctness. If the fetch returns something that is not the guidelines, record `not run`. |
| The three fixed defects get re-broken silently | Each gets its own assertion in `tests/ticket-scripts/`, including a negative test that fails if `--design-system` is ever parsed-but-unread again. |
