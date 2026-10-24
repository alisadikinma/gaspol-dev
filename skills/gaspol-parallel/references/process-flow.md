# gaspol-parallel — full Process Flow

Moved verbatim from `SKILL.md` (IDS-23). `SKILL.md` keeps every gate of this flow as a sentence in its body.

## Process Flow

Select based on mode:

### Mode `plan-phases` — Phase 1: Plan Intake

1. Read the implementation plan (from `gaspol-plan` output or user-provided)
2. Extract individual tasks with their:
   - Task number and title
   - Full requirements text
   - Dependencies on other tasks (if any)
   - Acceptance criteria

   When the plan carries `**Format:** waves-v1`, take deps, files, model and effort from the
   output of `skills/gaspol-plan/scripts/plan-waves` instead of re-deriving them (invoke it
   anchored: `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan>`).
   Its `wave`/`lane` lines are the order and its `phase` lines are the settings.
3. Determine execution order based on dependencies (for a `waves-v1` plan this is the `wave` lines)
4. Confirm task list with user before starting

### Mode `independent-domains` — Phase 1: Domain Identification + DAG Lane Scheduling

1. List all problems/tasks.
2. For EACH task, write its **dependency + write set** (this is what the scheduler needs):
   - `deps`: which other task(s) must finish first (one produces output the other needs)
   - `files`: which files/modules the task writes (treat a shared DB table as a synthetic
     file token, e.g. `db:users`, so the scheduler serializes table writers too)
3. **Run the scheduler** (BLOCKING — do not hand-schedule; topological order and file-overlap
   grouping are error-prone by eye):

   ```bash
   echo '{"tasks":[
     {"id":"auth-fix","files":["src/auth.ts"]},
     {"id":"ui-tz","files":["src/Profile.tsx"]},
     {"id":"auth-test","deps":["auth-fix"],"files":["src/auth.ts"]},
     {"id":"db-migrate","files":["db:users"]}
   ]}' | skills/gaspol-parallel/scripts/dag-lanes
   ```

   It returns a **LANE VERIFICATION MATRIX** + **DISPATCH PLAN** + a `{"waves":[...]}` JSON.
   - **Wave** = dependency layer. Never start wave N+1 until wave N fully completes.
   - **Lane** = within a wave, tasks sharing a file are one lane (run **sequentially**); lanes
     with no file overlap run **concurrently**.
   - This replaces the old all-or-nothing conflict check: a single dependency no longer forces
     the whole batch sequential — independent tasks still parallelize, dependents just wait for
     their wave. The matrix is the proof that **no two concurrently-dispatched tasks touch the
     same file** (the safe-parallelism guarantee).
   - The scheduler rejects dependency cycles and unknown deps (`ValueError`) — fix the task
     graph before dispatching.
4. **Sanity-check the matrix.** If two tasks landed in the same lane but you expected them
   parallel, you under-declared `files` (or over-declared a shared one). Adjust and re-run.
5. Create focused task descriptions per domain (self-contained prompts):
   - Context (what the agent needs to know, ONLY that)
   - Task (exactly what to do, specific, measurable)
   - Constraints (what NOT to touch)
   - Output (what to produce)

Example:
```
Agent 1: Authentication Middleware Fix
  Context: src/middleware/auth.ts rejects JWT with array roles
  Task: Fix JWT validation to accept both array and string role claims
  Constraints: Do NOT modify User model, routing, other middleware
  Output: Modified auth.ts, new test file, summary

Agent 2: User Profile UI Update
  Context: src/screens/Profile.tsx needs timezone selector
  Task: Add timezone dropdown using existing Select component
  Constraints: Do NOT modify auth flow, API endpoints, database schema
  Output: Modified Profile.tsx, updated hook if needed, summary
```

### Phase 2: Task Execution (repeat per task)

For each task in dependency order:

#### Step 1: Prepare Context

Gather scene-setting context the implementer needs:
- Relevant sections from CLAUDE.md (architecture, conventions, patterns)
- Existing code that the task touches or depends on
- Output from previous tasks (if this task depends on them)
- Any user clarifications from planning phase

#### Step 2: Dispatch Implementer

**Record the base SHA first** (`git rev-parse HEAD`) — this is the BASE you pass to
`review-package` later. NEVER use `HEAD~1` as the base: a multi-commit task has more than one
commit and `HEAD~1` silently drops all but the last.

**Extract the task's brief first.** Run
`skills/gaspol-parallel/scripts/task-brief <PLAN_FILE> <N>` — it writes that one task's
full text to `.gaspol/tasks/<TICKET>/task-<N>-brief.md` and prints the path. The brief is
the single source of the implementer's requirements.

Use the `implementer-prompt.md` template. A dispatch prompt carries exactly five things:

1. One line on where this task fits in the project.
2. The **brief path**, introduced as "read this first — it is your requirements, with the
   exact values to use **verbatim**".
3. Interfaces and decisions from earlier tasks that the brief cannot know.
4. Your resolution of any ambiguity you noticed in the brief.
5. The **report-file path** (`.gaspol/tasks/<TICKET>/task-<N>-report.md`) and the short
   return contract.

**Never reference the plan.** A subagent handed a 2000-line plan reads the wrong task —
that is the failure the older blanket rule existed to prevent, and it is still prevented.
The rule is narrowed, not reversed: the plan stays off-limits; the **task-scoped brief** is
the handoff.

**Exact values** — numbers, magic strings, signatures, test cases — live only in the brief.
Retyping them into the prompt is where they drift.

Everything you paste into a dispatch prompt, and everything a subagent prints back, stays
resident in your context for the rest of the session and is re-read on every later turn. Do
not paste accumulated prior-task summaries ("state after tasks 1-3") into later dispatches.
A fresh subagent needs its task, the interfaces it touches, and the global constraints —
nothing else.

Key rules:
- Include anti-placeholder rules (see below)
- Include self-review checklist
- **Always specify the model explicitly.** For a `waves-v1` plan, pass `model` and `effort`
  exactly as the `phase` line from `plan-waves` gives them; do not infer them. The class-based
  guidance that follows applies only to legacy plans and `independent-domains` mode. Scaled to
  task class (see `docs/rubric-model-switching.md`): mechanical/transcription → cheap; integration/judgment →
  standard; architecture/review → most capable. An unspecified model defaults to the wrong
  tier. **Turn count beats token price** — a cheap model that takes 2-3× the turns costs more
  wall-clock and context than the right-tier model; floor implementers working from prose at
  the standard tier.

#### Step 3: Handle Questions

The implementer may ask questions before or during implementation. This is GOOD.
- Answer questions immediately with technical specifics
- If you don't know, ask the user — do NOT guess
- Questions are cheap; wrong implementations are expensive

#### Step 4: Implementer Completes

The implementer:
1. Implements the task
2. Runs the **Validation Ladder** below — `DONE` is not allowed until it passes
3. Self-reviews against the checklist
4. Reports completion with the specified format — including a **§0 Status** line
   (`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`)

##### Validation Ladder (fail-fast, cheapest first)

> Same ladder as `skills/_shared/verification-loop.md`, which IDS-12 extracted so the in-session
> path (`gaspol-execute`) could run it too. The levels, the fail-fast rule and the explicit-skip
> rule are stated there; what follows is this skill's per-task application of them.

A passing unit test proves nothing if the types don't compile, and a green build proves
nothing if the edge cases were never exercised. Run these levels **in order, stopping at the
first failure** — cheap fast checks gate the expensive slow ones, so a typo never costs a full
integration run.

**L1–L3 commands come from `skills/gaspol-execute/scripts/detect-stack <project-root>`, not a
literal `tsc --noEmit`** — that's one stack's command, hardcoding it silently skips L1 on every
non-node project. Run `detect-stack` once for the project, then map its output onto the ladder:

| # | Level | Gate (what must pass) |
|---|-------|-----------------------|
| 1 | **Static** | The `static:` command `detect-stack` prints, clean on changed files. `<level>: UNKNOWN` → STOP and ask the user for the correct command, don't guess. No stack markers at all → use the plan-declared command for this phase. |
| 2 | **Unit** | The `unit:` command `detect-stack` prints — tests covering the changed units pass (the TDD tests written for this task). Same `UNKNOWN`/no-markers handling as L1. |
| 3 | **Build** | The `build:` command `detect-stack` prints, if it has a build step. `detect-stack` prints no `build:` line for that stack → explicit **N/A**, not a silent skip. |
| 4 | **Integration** | Integration/e2e tests exercising the changed code path pass, if any exist. |
| 5 | **Edge** | The non-happy paths are actually run — null/empty/boundary/error branch, not just the success case. This is the anti-"green on happy path only" gate. |

Rules:
- **Fail at level N → fix, then restart the ladder from L1** — a fix can re-break an earlier level
  (a type error introduced while fixing the build), and L1–L2 are the cheap fast levels, so
  rerunning them costs almost nothing. Never resume mid-ladder on faith.
- **A level that genuinely doesn't apply is skipped explicitly, not silently** — e.g. "L3 Build:
  N/A, no build step" / "L4 Integration: N/A, no integration suite". A silent skip reads as
  "passed" when it didn't (same failure mode as placeholder data).
- **An implementer subagent cannot run `detect-stack` itself** (it may not have repo access to
  the script, or any context beyond the dispatched prompt) — the orchestrator resolves the L1–L3
  commands before dispatch and pastes them verbatim into the task prompt (see
  `implementer-prompt.md`).
- The ladder is per-task verification depth; it does not replace Steps 5–6 (independent spec +
  quality review by a *different* subagent). Self-validation and independent review are different
  guarantees.

##### Handling Implementer Status

Route on the reported status — do NOT treat every return as "done":

- **DONE** — generate the review package and proceed to Step 5.
- **DONE_WITH_CONCERNS** — read the concerns FIRST. If they bear on correctness or scope,
  resolve them before review; if they are observations, note and proceed.
- **NEEDS_CONTEXT** — provide the missing information and **re-dispatch** the same task. Do
  not review a guess.
- **BLOCKED** — assess the blocker. Something must change (more context, a different model, a
  plan fix, or escalate to the user). **Never** ignore the escalation or blind-retry the same
  model with no change.

##### Generate the review package

Before either review, produce a stable diff artifact:

```bash
skills/gaspol-parallel/scripts/review-package <BASE> HEAD   # BASE = SHA recorded in Step 2
```

It prints the package path (`.gaspol/review/<base>-<head>.diff`). Hand that path to the
reviewer subagents so they audit one stable artifact. **BASE is the Step-2 SHA, never `HEAD~1`**
(the script rejects `HEAD~1` for this reason).

#### Step 5: Spec Review

Dispatch with `subagent_type: "gaspol-dev:spec-reviewer"`, `model: "opus"` (see the template's own
Model Selection section), using `spec-reviewer-prompt.md` (pass the review-package path):
- Reviewer reads ACTUAL CODE (not the implementer's report)
- Compares implementation to requirements line by line
- Checks for placeholder data (CRITICAL)
- Returns: spec-compliant OR list of issues

**Fix → re-review loop:** if issues are found, run **The Fix Loop** below — do not accept
"I fixed it" without a clean re-review. Do NOT proceed to quality review until spec passes.

#### Step 6: Code Quality Review

Dispatch with `subagent_type: "gaspol-dev:code-reviewer"`, `model: "opus"` (see the template's
own Model Selection section), using `code-quality-reviewer-prompt.md` (pass the same
review-package path):
- Uses the `gaspol-review` skill's code-reviewer template
- Reviews the diff in the review package (base SHA → HEAD)
- Focuses on code quality, architecture, testing, production readiness

**Adversarial refutation (gaspol-review Step 2.5):** before acting on any Critical/Important
finding, dispatch one refuter subagent per finding (default REFUTED) to kill false positives —
otherwise the fix → re-review loop below burns turns chasing hallucinated bugs. Drop REFUTED
findings; only CONFIRMED (or unverifiable) ones proceed.

**Fix → re-review loop:** surviving Critical/Important findings go through **The Fix Loop**
below. Note Minor issues in the ledger (`Task <N>: minor (deferred): <one-liner>`) and point
the final review at that list — a roll-up nobody reads is a silent discard. Minor findings
never enter the loop. Do not mark the task complete with unresolved Critical/Important
findings.

##### The Fix Loop

**Canonical rule: [skills/_shared/fix-loop.md](../../_shared/fix-loop.md)** — five rounds maximum,
rounds 1-3 resume the fixer that has the context, rounds 4-5 dispatch fresh one model tier up,
the re-review is scoped to `FIX_BASE..HEAD`, and round 5 adjudicates rather than escalating.
`gaspol-finish` applies the same rule to its BLOCKING gates; the rule is stated once so the two
cannot drift.

**What is specific to this skill:** the fixer is the task's implementer, its persistent memory is
the report file beside the brief, and the scoped diff is built with
`scripts/review-package <FIX_BASE> HEAD` and dispatched via
[re-review-prompt.md](../re-review-prompt.md). `FIX_BASE` is the head the previous review saw —
never `HEAD~1`, which silently drops all but the last commit of a multi-commit fix.

#### Step 7: Mark Complete

- Record the task as done
- Note any issues deferred to later tasks
- Move to next task

### Phase 3: Final Review + Integration

**Mode `plan-phases`:** After ALL phases complete:
1. Run `gaspol-review` on the full changeset
2. Run `plan-verifier` agent (BLOCKING — step-level evidence-based)
3. Present the finish offer per [_shared/finish-offer.md](../../_shared/finish-offer.md) — three
   options, the user picks. Finishing is not the automatic next step, and deferring writes a
   ledger cursor rather than being forgotten. Do not restate the modal here.

**Mode `independent-domains`:** After ALL agents complete (concurrent dispatch returned):
1. Read each agent's summary
2. Check for conflicts — any unexpected file overlaps?
3. Run the full test suite — do all changes work together?
4. Resolve conflicts — if agents modified same file unexpectedly, manually merge
5. Integration test — verify combined changes work as a system
6. Run `gaspol-verify` (all 4 layers including plan-verifier if applicable)
