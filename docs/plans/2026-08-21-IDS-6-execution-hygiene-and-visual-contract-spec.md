**Ticket:** IDS-6

# Execution Hygiene + Visual Contract

## Problem

Two failure modes observed when gaspol builds a full application:

1. **Bug density rises with task index.** Tasks 1-3 land clean; tasks 8-15 leak
   defects. The cause is not task difficulty — it is controller context. Every
   dispatch prompt pastes the full task text, and every subagent prints its full
   report back. Both stay resident and are re-read on every later turn, so the
   controller's decision quality degrades as the build proceeds.
2. **The shipped UI does not match the mockup.** Every gate gaspol runs is
   static: `tsc`/lint/unit/build (Layer 1), regex placeholder scan (Layer 3),
   code-reading integration trace and regex design lint (Layer 4). Nothing ever
   runs the application, and nothing ever compares a rendered screen against the
   design. The design itself only exists as prose (aesthetic direction, ASCII
   layout blueprint), and prose cannot be diffed against a render, so drift is
   invisible until a human opens a browser.

## Prior-Art Verdict: DELTA

Searched per the `gaspol-write-skill` Step 0 gate.

| Lookup | Result |
|---|---|
| Installed already | `gaspol-verify/scripts/design_audit.py` — static source lint, offline. Different job, kept. |
| Built into harness | No built-in visual-fidelity command. |
| Marketplace (`npx skills find`) | `sebkay/skills@ui-mockup-fidelity`; `software-mansion/argent@argent-screenshot-diff` |

**`ui-mockup-fidelity`** (read in full) covers the *prevention* half: tiered
constraints (hard/default/flexible), a component-extraction protocol, a
deviation protocol, and `references/layout-token-contract.md`. It has no
verification whatsoever — no screenshot, no diff, no gate. **Decision: install
it and route to it.** gaspol does not rewrite implementer discipline.

**`argent-screenshot-diff`** (read in full) covers the *verification* half but is
bound to the argent MCP tool server and a mobile simulator (`udid`), so it
cannot compare a web app to an HTML mockup. Two of its rules are adopted
verbatim: capture at `scale: 1.0` with the image block suppressed so full-size
PNGs never enter context, and its "poor fit" list (unpausable animation, dynamic
content, timestamps) as the determinism requirements for capture.

**The delta gaspol builds:** the design *contract artifact*, deterministic web
verification against it, and the wiring into plan/brief/ledger/verify.

KB precedent applied: `architecture/stochastic-suite-needs-a-baseline` — an
LLM-produced score is a sample, not a verdict.

## Part A — Execution Hygiene

### A1. Task-scoped brief handoff

New `skills/gaspol-parallel/scripts/task-brief <PLAN_FILE> <N>` extracts task N's
full text to `.gaspol/tasks/<TICKET>/task-<N>-brief.md` and prints the path.

The dispatch prompt carries: one line of project context, the brief path
(introduced as the requirements, to be used verbatim), interfaces and decisions
from earlier tasks the brief cannot know, the controller's resolution of any
ambiguity it spotted, and the report-file path. Exact values — numbers, magic
strings, signatures, test cases — appear only in the brief.

The existing `gaspol-parallel` rule `NEVER reference a file` is **narrowed, not
reversed**: never reference the plan; always reference the task-scoped brief.
The rule was written to stop a subagent from reading a 2000-line plan and
picking the wrong task. That failure remains prevented.

### A2. Report file per task

The implementer writes its full report to
`.gaspol/tasks/<TICKET>/task-<N>-report.md` and returns only: status, commit
list, a one-line test summary, and concerns. Long output stops entering the
controller's context.

### A3. Fix loop — five rounds with escalation

Replaces "3 attempts then escalate to the user".

- Rounds 1-3: resume the same implementer, sending the open findings verbatim.
  Its context is intact — it knows the task, the code, and its own choices.
- Rounds 4-5: dispatch a **fresh** implementer one model tier above the one that
  got stuck, framed as "a prior implementer attempted this task N times; you own
  it now — read the report file for what was tried."
- Every round: the implementer fixes, re-runs the tests covering the amended
  code, appends its fix report to the same report file. The controller confirms
  the fix report contains the covering tests, the command run, and the output
  before dispatching the re-review.

A loop that survives three resumes usually means the implementer cannot see its
own problem. Fresh eyes plus a capability bump is the correct response — not a
human interrupt.

### A4. Scoped re-review

`review-package <FIX_BASE> HEAD`, where `FIX_BASE` is the head the
previous review saw. The re-reviewer reads only the fix diff against the
findings list, not the whole task again. New prompt file
`skills/gaspol-parallel/re-review-prompt.md`.

### A5. Pre-flight plan conflict matrix (BLOCKING, before task 1)

Before the first dispatch, scan the plan and write a table to the ledger:

- one row per pair of tasks sharing a file or an interface — the two tasks, what
  one produces against what the other consumes, and the finding;
- one row per task — whether its own text agrees with itself (the tests it
  specifies against the code it specifies, the files it creates against the
  files it later touches).

"The scan is clean" without those rows is not a scan that was run. Every
finding is ruled on before execution begins, and each ruling is recorded in the
ledger.

## Part B — Visual Contract

### B1. `canvas.html` — the single source of visual truth

One file per ticket in the consumer project, tracked in git at
`docs/plans/YYYY-MM-DD-<TICKET>-<topic>-canvas.html`. It lives on the ticket
branch and reaches main on merge, exactly like the spec and plan files.

Sections, added in stages:

| Section | Written at | Binding |
|---|---|---|
| `§ Screens` | brainstorm Phase 3 (wireframe) → design lock (hi-fi) | yes |
| `§ User flow` | brainstorm Phase 3 (mermaid) | yes |
| `§ Tokens` | design lock | yes |
| `§ Execution` | after `gaspol-plan` (mermaid phase DAG) | no |
| `§ Mapping` | after `gaspol-plan` (phase → screen id → threshold) | no |

Requirements on `§ Screens`:

- **Markup is written in the target stack**, not generic HTML. The implementer
  copies markup and binds data; it does not translate a design. Translation is
  where drift is born, so the translation step is removed rather than policed.
- **Every binding element carries `data-vv="<screen>.<element>"`.** Copied markup
  carries the marker along. A missing marker means the markup was rewritten
  rather than copied — structural early warning, before a single pixel is
  compared.
- **Content is realistic worst-case**: long names, nine-digit numbers, empty
  lists, 200-item lists. A mockup with three short rows lies about the layout,
  and forces empty/overflow states to be designed rather than discovered.

`§ Tokens` embeds a `<script type="application/json">` block **and** the CSS
custom properties the application imports. Canvas and app consume the same token
file. Colour and spacing cannot drift, because neither side copies the other.

The file is published as an Artifact; one URL lives for the whole ticket and is
recorded in the plan header's `**Artifact:**` field, which becomes mandatory for
UI tickets. The post-plan artifact offer in `gaspol-plan` is removed — it is no
longer a separate step, only a redeploy of the same path.

Reference PNGs are **not** committed. They are regenerated from `canvas.html`
into `.gaspol/design/<TICKET>/` at verify time, so a stale baseline cannot
exist and the repository does not carry binaries.

### B2. Two-fidelity timing

- **Structural lock — brainstorm Phase 3.** Screen inventory, user flow, per
  screen the data it needs and the states it has. Wireframe grade, no colour.
  Derived from requirements, so it is decidable this early, and it is exactly
  what `gaspol-plan` needs to break phases.
- **Visual lock — new BLOCKING phase after `gaspol-plan`, before
  `gaspol-execute`.** Full `ui-ux-pro-max` pass, canvas upgraded to
  high fidelity, tokens finalised, user approves per screen.

Pixel-level design matures only once the plan has fixed the component inventory
and data shapes. Locking it before the plan means designing against guesses;
locking it after execution starts means there is no contract to verify against.
The one boundary that cannot move: the visual lock happens before any UI code.

This also removes waste — pixel work currently runs during brainstorm for 2-3
candidate approaches, most of which are discarded.

### B3. `gaspol-visual-verify` (new skill)

1. **Resolve a runner, in order:** Playwright MCP → chrome-devtools MCP → local
   `playwright` in the target project → none. With no runner, the result is
   reported as **NOT RUN**. It is never recorded as passed.
2. **Boot the app**, navigate each route in `§ Mapping`.
3. **Geometry diff (deterministic, BLOCKING).** For each `data-vv` marker,
   compare computed style and bounding box between canvas and app. Output is
   numeric and actionable: `hero.cta gap 12px vs 24px`, `card.title font-size
   14 vs 16`, `nav.bg #3B82F6 vs var(--primary)`.
4. **Pixel diff (trigger).** Screenshots at 375 / 768 / 1440 against the
   regenerated reference. It answers "something differs outside what was
   measured"; the geometry pass answers "what".
5. **Runtime smoke (BLOCKING).** Zero console errors, zero failed network
   requests on the happy path.
6. **Missing-marker report.** Any `data-vv` present in canvas and absent in the
   app is reported as probable rewritten markup.

Capture determinism: animations disabled, fonts awaited, fixed viewport, and
full-size PNGs never loaded into context.

**No VLM judge.** A model-scored rubric compensates for a weak contract; with
`canvas.html` as the contract and markup copied rather than translated, fidelity
is measurable by construction. Holistic judgment (hierarchy, balance) stays
where it belongs — human approval at the visual lock, assisted by
`gaspol-verify/rules/anti-ai-slop.md` — which is a design decision, not an
implementation check.

### B4. Wiring

| Integration point | Change |
|---|---|
| `gaspol-brainstorm` Phase 3 | produce structural `canvas.html`, not prose |
| `gaspol-plan` | append `§ Execution` + `§ Mapping`; per-UI-phase verification names a screen id and threshold; remove the artifact offer |
| new visual-lock phase | BLOCKING between plan and execute |
| UI task brief | carries canvas path + screen id + reference markup; routes to `ui-mockup-fidelity` |
| Validation Ladder (`gaspol-parallel`) | new level: visual-verify + runtime smoke before `DONE` |
| `gaspol-verify` Layer 4 | invoke visual-verify when a canvas exists; `design_audit.py` unchanged (static, offline, pre-merge — a different job) |

## Data Integration Map

| Component | Data source | Exists? | Action |
|---|---|---|---|
| `task-brief` | plan `-plan.md` in `docs/plans/` | yes | parse markdown, follow `review-package` conventions |
| brief / report files | `.gaspol/tasks/<TICKET>/` | no | new convention, gitignored |
| fix-loop state | ledger `.gaspol/progress/PROGRESS-<TICKET>.md` | yes | add per-round lines |
| conflict matrix | same ledger | yes | new table section |
| `canvas.html` | written by brainstorm + plan + visual lock | no | new template, tracked in git |
| tokens | JSON block + CSS variables in canvas | no | app imports the same custom properties |
| browser runner | Playwright MCP / chrome-devtools MCP / local playwright | partly | tiered probe, degrade to NOT RUN |
| reference PNGs | regenerated from canvas | no | `.gaspol/design/<TICKET>/`, gitignored |
| implementer discipline | `ui-mockup-fidelity` | no | install, soft reference |

No placeholder path exists in this design: every artifact above is produced by a
real script or a real skill step, and the one gate that can fail to run reports
itself as NOT RUN rather than as passed.

## Non-Goals

- **Eval harness.** Needs a fixture repository and automated scoring — real work
  of its own. Without it none of the above can be *proven* to have helped, but
  building it first delays two fixes whose defects are already established.
  Separate ticket.
- **Autonomy change** ("rulings, not stalls"). gaspol's per-phase checkpoints are
  a deliberate choice, not an oversight. Narrowing them trades safety for speed
  and is a preference call, not a defect fix. Separate decision.
- **Mobile/native visual verification.** Web only. `argent-screenshot-diff`
  already covers the simulator case for anyone who needs it.

## Risks

| Risk | Mitigation |
|---|---|
| Visual lock lands after the plan and is rejected outright, burning the plan | The expensive decisions (screen count, navigation flow) were locked structurally at brainstorm; style rejection rarely invalidates a phase breakdown |
| Geometry diff is noisy on fluid layouts | Thresholds are per-property with tolerances; fluid dimensions compared as ratios, not absolute pixels |
| `data-vv` markers leak into production markup | Stripped by the build, or kept — they are inert attributes and useful for E2E selectors |
| The three-tier runner probe silently picks a weak tier | The resolved tier is named in the report; NOT RUN is a distinct outcome from a pass |
| `ui-mockup-fidelity` upstream changes or disappears | Soft reference only, exactly as with `ui-ux-pro-max`: no `dependencies` key, degrade with a message |
| Part A changes the machine that executes Part B | Order the phases so the hygiene work merges before the visual work is built on top of it |

## Sequencing Constraint

Part A phases must complete and merge before Part B's implementation phases
begin. Part B is built by the execution engine Part A repairs.
