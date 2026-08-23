# IDS-14 — Two gates that advise, and nobody enforces

**Ticket:** IDS-14
**Date:** 2026-08-23
**Branch:** IDS-14-regression-gate-visual-diff
**Status:** spec

## The complaint

Two of the three items recorded as open at the end of IDS-13, restated by the owner:

> - Belum ada yang membandingkan screenshot dengan mockup — Live App Check menangkapnya untuk
>   dilihat manusia, tidak ada perbandingan otomatis. Tunggakan IDS-6 bagian B.
> - Perbaikan bug belum wajib meninggalkan test regresi — dianjurkan `gaspol-debug`, tidak
>   diperiksa siapa pun.

The third (eval harness) is IDS-15 by the owner's decision, under the Batch Gate's two-ticket
ceiling. Split reason on record: **disjoint subsystems** — these two enforce rules inside
`skills/`, the eval harness measures the plugin from `tests/` and returns a score rather than a
verdict — **and** the combined plan exceeds the phase threshold.

## The defect class, verified not assumed

Both items are the same shape, and it is the shape this plugin has now shipped four fixes for:
**a rule exists, and no machine enforces it.** IDS-7 (a design gate never wired up), IDS-8 (a
setting nothing read), IDS-12 (`gaspol-execute` only read code, never ran it), IDS-13 (a Live App
Check with no detector). Evidence for these two, by command:

| Defect | Evidence |
|---|---|
| The regression rule holds its own escape hatch | `skills/gaspol-debug/SKILL.md:139` — *"Create a failing test case **(if possible)**"*. "If possible", with nothing testing for possibility, is a default rather than an exception |
| Nothing downstream checks it | `grep -rn regression skills/gaspol-verify skills/gaspol-finish` → **0 hits**. The word appears in `gaspol-tdd`'s integration table describing what `gaspol-debug` *should* do, and in neither gate that could catch its absence |
| Nothing compares a screenshot to anything | `live-app-check.md` captures a screenshot as human-readable evidence and stops there. `grep -rn "data-vv" skills/` → **0 hits**; every occurrence sits in IDS-6's and IDS-7's `docs/plans/` prose |

## The blocker inside the second item, stated before it is discovered mid-build

**There is nothing to compare against.** A geometry diff needs a reference contract — IDS-6 Part B
specifies `canvas.html` carrying `data-vv="<screen>.<element>"` markers. That format exists nowhere
in this repository. "Compare the screenshot to the mockup" is not one missing step; its left-hand
side is missing too.

IDS-6 Part B in full is a new skill (`gaspol-visual-verify`), a canvas format, a restructuring of
brainstorm and plan into two fidelity stages, and six wiring points. That is not this ticket.

**This ticket builds the machine and the contract it reads. It does not restructure the process.**
The same order IDS-13 used: `detect-app-target` (the machine) → `live-app-check.md` (the contract)
→ minimal wiring → the rest recorded as deferred with its reason. Building the machine first is
what makes the process change decidable later; the other order is how IDS-7's gate came to exist
for five versions with no scanner behind it.

## Part A — the regression gate

### A1. The rule stops excusing itself

`gaspol-debug` Phase 4 step 1 becomes a gate with **three states and no silent default**:

| State | Ledger line |
|---|---|
| written | `regression-test: <path>::<name> — RED at <sha>, GREEN after fix` |
| genuinely not testable | `regression-test: N/A — <reason>` |
| not written | `regression-test: not run — <reason>` |

`(if possible)` is deleted. `N/A` survives it, with the reason written down, for the cases that are
real: a CI-infrastructure fix, an environment-only failure, a docs typo. The difference between
`(if possible)` and `N/A — <reason>` is the whole of Part A — one is a default nobody has to
defend, the other is a decision with a name on it. Same treatment `live-app-check` gives `N/A`,
same reason: an unusable gate gets switched off, which costs more than the false alarms it prevents.

**RED before GREEN is not optional inside the written state.** A test added after the fix, never
observed failing, proves only that it passes now. The ledger line records the SHA it was red at,
which is a fact that can be checked rather than a claim.

### A2. A machine that checks it — `skills/gaspol-debug/scripts/regression-gate`

Prose cannot enforce prose. The script answers one question — *does this branch fix a bug, and if
so did it leave a regression test?* — deterministically:

- Reads commit subjects over `<BASE>..HEAD`. A branch is bug-fixing when a subject carries a
  conventional-commit `fix` type or a `bug`/`hotfix`/`regression`/`revert` keyword. The same signal
  `skills/gaspol-review/git-history-reviewer.md` already uses, reused rather than reinvented.
- Reads the ledger for a `regression-test:` line.
- Prints the verdict. Exit **0** satisfied / **1** BLOCKING (fix commits, no line) / **3** UNKNOWN
  (ledger unreadable) / **4** none (not a bug-fixing branch).

Exit 4 prints `regression-gate: not applicable — no fix commits in <BASE>..HEAD` and is **never
counted as a pass**, for the reason `marketplace-manifest`'s exit 4 is not.

### A3. Wiring — two callers, both already there

| Where | Change |
|---|---|
| `gaspol-verify` Layer 1 | run `regression-gate`, record the verdict beside `live-app-check:` |
| `gaspol-finish` Step 0 | run it among the deterministic checks, before any agent is dispatched |

Step 0 is the right place for the blocking copy: it exists (IDS-9), it already runs deterministic
checks before expensive agents, and a missing regression test is exactly the finding that must not
cost an Opus audit to discover.

## Part B — the visual diff machine

### B1. `skills/gaspol-verify/scripts/geometry-diff`

stdlib-only Python, the constraints its sibling `design_audit.py` already carries: offline, no
dependency, no network. It takes **two geometry snapshots as JSON** and diffs them per `data-vv`
marker.

Snapshot shape, written by the extractor and by nothing else:

```json
{"source": "canvas", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 160, "h": 44},
                           "style": {"font-size": "16px", "color": "rgb(59, 130, 246)"}}}}
```

**The extractor is printed, never constructed.** `geometry-diff --emit-extractor` prints one
literal JavaScript expression to stdout; the caller passes it to the Playwright MCP's
`browser_evaluate` against the canvas, then against the live app, and saves both results. The same
security invariant `detect-stack` and `detect-app-target` carry, for the same reason: the caller
**executes** what this prints, so nothing read out of a scanned project file may reach stdout.

### B2. What the diff rules on

| Finding | Severity | Why |
|---|---|---|
| marker in canvas, absent in app | **BLOCKS** | markup was rewritten rather than copied — structural drift, catchable before a pixel is compared |
| marker in app, absent in canvas | WARN | an element added during implementation is often legitimate; a silent one is not |
| structural geometry beyond tolerance (`w`, `h`, `font-size`, `padding`, `margin`, `gap`) | **BLOCKS** | the wrong-layout half of the mockup-mismatch complaint |
| structural colour differs (`color`, `background-color`, `border-color`) | **BLOCKS** | matches `design_audit.py`'s existing role split, so the two scripts cannot disagree about the same property |
| decorative differs (`box-shadow`, `outline-color`, `opacity`, anything with alpha) | WARN | a one-off shadow is craft, not drift. Blocking on it produces false alarms; false alarms get the gate switched off |

**Tolerances, and why fluid layouts do not make this useless.** Absolute pixels compare with a
default tolerance of 2px. Widths and horizontal positions additionally compare as a **ratio of the
viewport**, and the *smaller* of the two deviations wins — an element that is 640px in a 1440
canvas and 610px in a 1366 browser is 44.4% of both and passes, while the same element at 44%
versus 61% fails at any viewport. IDS-6 recorded "geometry diff is noisy on fluid layouts" as a
risk with "compare as ratios" as the mitigation; this is that mitigation, made specific enough to
implement and to test.

Colours normalise to an RGBA tuple before comparison, so `#3B82F6`, `rgb(59, 130, 246)` and
`rgb(59 130 246)` are one value. Without that the diff reports drift between two spellings of the
same colour, which is the fastest way to make a gate untrusted.

### B3. Three states, never blurred

| State | Exit | Behaviour |
|---|---|---|
| both snapshots parse | 0 / 1 | diff runs; 1 when a BLOCKING finding stands |
| a snapshot present and unparseable | **3** | `visual-diff: UNKNOWN — <file> is not a geometry snapshot` → **STOP and ask.** Never degrade to an empty diff: an empty diff reads as *"nothing differs"*, which is exactly the false claim this gate exists to prevent |
| no canvas contract in the project | **4** | `visual-diff: none — no canvas contract` — **not a failure.** Most projects have no canvas, and a gate that fails every one of them is a gate that gets switched off |

### B4. The contract file — `skills/_shared/visual-contract.md`

States the canvas format once: `data-vv="<screen>.<element>"` on every binding element, markup
written in the target stack so the implementer copies rather than translates, realistic worst-case
content, and where the file lives (`docs/plans/YYYY-MM-DD-<TICKET>-<topic>-canvas.html`, on the
branch, per the repo's fixed standard). Cites IDS-6 Part B as its origin and names precisely which
parts this ticket does **not** build, so the deferral cannot be mistaken for completion.

### B5. Wiring — one caller, honest about being partial

`skills/_shared/live-app-check.md`, web lane: after the screenshot is captured, if a canvas exists
for the ticket, run the extractor against both and diff. Recorded as
`visual-diff: <n> blocking, <m> warnings`, or one of the three states above.

The mobile lane gets **nothing**. `adb exec-out screencap` produces a PNG with no DOM behind it, so
there is no geometry to extract and this machine does not apply. Saying so is the point: IDS-6
already scoped Part B as web-only, and a gate silently absent on one lane is how a partial gate
comes to read as a whole one.

## Non-goals, each with its reason

- **The rest of IDS-6 Part B** — `gaspol-visual-verify` as a skill, the two-fidelity restructure of
  brainstorm and plan, the pixel-diff trigger, the `§ Execution` / `§ Mapping` canvas sections. The
  machine must exist before the process depending on it is worth changing.
- **Pixel diffing.** The geometry pass answers *what* differs. A pixel pass answers *that*
  something differs outside what was measured, needs a stored reference image and a comparison
  library, and is worth nothing until the geometry pass is trusted.
- **The eval harness** — IDS-15, by the owner's decision.
- **Auto-generating a canvas from an existing app.** That records what was built as though it were
  what was designed, inverting the contract.

## Risks

| Risk | Mitigation |
|---|---|
| `regression-gate` fires on a branch that legitimately has no test | `N/A — <reason>` is a first-class state and the ledger line is one line to write |
| Commit-keyword detection misses a fix that says neither `fix` nor `bug` | Exit 4 prints *not checked*, never a pass, so the miss is visible rather than silent |
| The geometry diff is noisy enough to get switched off | Ratio comparison on fluid axes, colour normalisation, and the structural/decorative severity split — all three exist to keep the blocking set small and true |
| The extractor drifts from the shape the diff expects | One script owns both, and `--self-test` covers the round trip |
| This is mistaken for closing IDS-6 Part B | `visual-contract.md` names what is not built, and so does the CLAUDE.md entry |
