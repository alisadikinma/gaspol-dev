---
name: gaspol-parallel
description: "Use when executing implementation plans with independent phases (mode: plan-phases) OR when handling 2+ independent problem domains ad-hoc (mode: independent-domains)."
---

# gaspol-parallel (with Mode Field)

## Overview

Fresh subagent per task + two-stage review = high quality, fast iteration.

Each task gets a dedicated implementer subagent with full context (no accumulated state drift), followed by two independent review passes: spec compliance (did you build the right thing?) then code quality (did you build it right?). Anti-placeholder rules are enforced at every stage.

## Mode Field (NEW)

This skill supports two modes, selected at invocation:

### Mode 1: `plan-phases`

Execute an implementation plan with multiple phases that are mostly independent.

**Use when:**
- You have an implementation plan (from `gaspol-plan`)
- Phases are mostly independent (can be done in sequence without heavy cross-dependencies)
- You want to stay in this session (continuous execution, not separate worktrees per human review)

**Process:** Phase Intake → per-phase (Implementer → Spec Review → Quality Review) → Final integration

### Mode 2: `independent-domains`

Dispatch one agent per independent problem domain for true concurrent resolution (divide-and-conquer).

**Use when:**
- 3+ failures with different root causes (e.g., broken tests in auth, API, and UI simultaneously)
- Multiple independent subsystems need changes (database migration + frontend component + API endpoint, when they don't depend on each other)
- No shared state between tasks — each agent can work without knowing what the others are doing
- Embarrassingly parallel work
- Large refactoring across multiple unrelated files or modules

**Process:** Domain Identification → DAG Lane Scheduling (`scripts/dag-lanes`) → Wave-by-Wave Dispatch (each wave = one batch of concurrent Agent calls, one per lane; lanes with multiple tasks run sequentially inside) → Review + Integrate. A new wave starts only after the previous wave's tasks all return.

### Do NOT Use This Skill When

- Tasks are trivial (< 3 steps each) — just implement directly
- Tasks are heavily interdependent — implement sequentially yourself
- Related failures (fixing one might fix others) — work sequentially
- Shared state — tasks read/write the same files, variables, database tables
- Sequential dependencies — task B depends on output of task A
- Single root cause with multiple symptoms
- Small tasks where dispatch overhead exceeds time saved

## Phase 0: Workspace Isolation (MANDATORY before concurrent dispatch)

Before dispatching ANY concurrent implementer subagents, ensure an isolated workspace exists — invoke **`gaspol-worktree`**.

- **Mode `independent-domains`** (truly concurrent dispatch): isolation is **required**. Parallel agents editing the same working directory race on files. gaspol-worktree Step 0 detects existing isolation (no double-nesting) and creates a worktree via the harness native tool or a safe git fallback.
- **Mode `plan-phases`** (sequential phases in one session): isolation is **recommended** when phases touch overlapping files or you want the current branch protected; optional for small, append-only phase sets.

If `gaspol-worktree` reports you are already in a linked worktree, proceed — do not nest. If the user declines isolation, work in place but note the elevated conflict risk in mode `independent-domains`.

## Continuous Execution Discipline

Once the task list is confirmed and the workspace is isolated, **execute all tasks continuously — do not pause to check in between tasks.** Fresh subagent per task already prevents context drift; mid-run "Should I continue?" prompts and per-task progress summaries waste the user's time. The user asked you to execute the plan, so execute it.

**The only reasons to stop mid-run:**
- The fix loop trips its round-5 breaker AND adjudicating the open findings still leaves every path forward a guess (see The Fix Loop).
- A genuine ambiguity in a task blocks progress (ask via AskUserQuestion).
- An Iron Law violation or destructive operation is required (always pause).
- All tasks complete.
- The session-length checkpoint fires — every 3rd wave/phase completed this run (see Task
  Execution Tracking below) — a deliberate, bounded context-budget offer via AskUserQuestion,
  not a per-task check-in.

Update the visual task tracker as you go (see Task Execution Tracking) instead of narrating each task in prose. This is the in-session analogue of `gaspol-auto`'s hard-stop guardrails — autonomous flow, bounded by the same always-pause conditions.

## Pre-Flight Conflict Matrix (BLOCKING — before the first dispatch)

Scan the plan once for conflicts **before the first task runs**, writing down what you
checked as you check it. A contradiction found before task 1 costs a ruling; the same
contradiction found at task 12 costs everything built on top of it.

The scan's output is a **table, not a verdict**. Two kinds of row, both required:

| Kind | One row for | Columns |
|---|---|---|
| Cross-task | every pair of tasks that **share a file** or an interface | the two tasks · what one produces against what the other consumes · the finding |
| Self-consistency | every task — whether its own text **agrees with itself** | the task · its tests against the code it specifies, the files it creates against the files it later touches · the finding |

Also flag anything the plan explicitly mandates that the review rubric treats as a defect
(a test that asserts nothing, a verbatim-duplicated logic block).

**"The scan is clean" without those rows is not a scan that ran.** Write the table to the
ledger — **above `## Log`**, never below it, because `scan-active-ledgers` reads the file's
last non-empty line and anything under `## Log` breaks active-vs-done detection.

Rule on every finding before execution begins: weigh it against the plan text with the spec
as the binding authority, and record the **ruling** beside its row. If the scan is genuinely
clean — rows written, nothing found — proceed without further comment. The review loop
remains the net for conflicts that only emerge from implementation.

## Process Flow

Select based on mode:

### Mode `plan-phases` — Phase 1: Plan Intake

1. Read the implementation plan (from `gaspol-plan` output or user-provided)
2. Extract individual tasks with their:
   - Task number and title
   - Full requirements text
   - Dependencies on other tasks (if any)
   - Acceptance criteria
3. Determine execution order based on dependencies
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
- **Always specify the model explicitly**, scaled to task class (see
  `docs/rubric-model-switching.md`): mechanical/transcription → cheap; integration/judgment →
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

Dispatch with `subagent_type: "gaspol-dev:code-reviewer"`, `model: "sonnet"` (see the template's
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

**Canonical rule: [skills/_shared/fix-loop.md](../_shared/fix-loop.md)** — five rounds maximum,
rounds 1-3 resume the fixer that has the context, rounds 4-5 dispatch fresh one model tier up,
the re-review is scoped to `FIX_BASE..HEAD`, and round 5 adjudicates rather than escalating.
`gaspol-finish` applies the same rule to its BLOCKING gates; the rule is stated once so the two
cannot drift.

**What is specific to this skill:** the fixer is the task's implementer, its persistent memory is
the report file beside the brief, and the scoped diff is built with
`scripts/review-package <FIX_BASE> HEAD` and dispatched via
[re-review-prompt.md](re-review-prompt.md). `FIX_BASE` is the head the previous review saw —
never `HEAD~1`, which silently drops all but the last commit of a multi-commit fix.

#### Step 7: Mark Complete

- Record the task as done
- Note any issues deferred to later tasks
- Move to next task

### Phase 3: Final Review + Integration

**Mode `plan-phases`:** After ALL phases complete:
1. Run `gaspol-review` on the full changeset
2. Run `plan-verifier` agent (BLOCKING — step-level evidence-based)
3. Present the finish offer per [_shared/finish-offer.md](../_shared/finish-offer.md) — three
   options, the user picks. Finishing is not the automatic next step, and deferring writes a
   ledger cursor rather than being forgotten. Do not restate the modal here.

**Mode `independent-domains`:** After ALL agents complete (concurrent dispatch returned):
1. Read each agent's summary
2. Check for conflicts — any unexpected file overlaps?
3. Run the full test suite — do all changes work together?
4. Resolve conflicts — if agents modified same file unexpectedly, manually merge
5. Integration test — verify combined changes work as a system
6. Run `gaspol-verify` (all 4 layers including plan-verifier if applicable)

## Anti-Placeholder Rules (CRITICAL)

These rules MUST be included in every implementer dispatch. They are the single most common source of bugs in subagent-driven development.

### What is a Placeholder?

A placeholder is any data that is hardcoded in the component/function when the task specification requires it to come from a real source (API, hook, context, database, props).

### Examples of Placeholders

```typescript
// PLACEHOLDER: Hardcoded array that should come from API
const topics = [
  { id: 1, title: "How to go viral", score: 85 },
  { id: 2, title: "Content strategy", score: 72 },
];

// PLACEHOLDER: Static value that should come from context/hook
const userName = "John Doe";
const isPremium = true;

// PLACEHOLDER: Mock function that should call real API
const handleGenerate = () => {
  console.log("TODO: implement");
  setResult({ success: true }); // fake success
};

// PLACEHOLDER: Component rendering static data instead of props/state
<div className="score">{85}</div>  // should be {score} from props
```

### Anti-Placeholder Checklist

For every component/function the implementer creates:
1. **Trace every data source**: Where does each piece of data come from? Hook? Context? API? Props?
2. **Verify imports match usage**: If component uses user data, does it import `useAuth`? If it shows sessions, does it import `useChatSessions`?
3. **Check data flow completeness**: Does data flow from source through to rendering, or does it stop at a static value?
4. **Flag unknowns explicitly**: If a real data source doesn't exist yet, the implementer MUST ask — not silently placeholder

## Red Flags

| Red Flag | Why It's Dangerous |
|----------|-------------------|
| Starting on main/master without user consent | Pollutes the main branch with incomplete work |
| Skipping spec review | "It looks done" is not the same as "it meets requirements" |
| Skipping quality review | Spec-compliant code can still be poorly written |
| Proceeding with unfixed Critical/Important issues | Technical debt compounds; fix now or pay 10x later |
| Dispatching parallel implementation subagents WITHOUT worktree isolation | Race conditions, merge conflicts, context drift — invoke gaspol-worktree (Phase 0) first |
| Pausing to ask "should I continue?" between tasks | Breaks continuous execution — only stop on the bounded always-pause conditions |
| Pasting task text into the dispatch instead of handing over the brief path | The paste stays resident in the controller's context and is re-read every turn; the brief is task-scoped and cannot be misparsed into the wrong task |
| Skipping scene-setting context in implementer dispatch | Subagent lacks project knowledge, makes wrong assumptions |
| Ignoring subagent questions | Forces subagent to guess, leading to wrong implementations |
| Accepting "close enough" on spec compliance | Small spec gaps become large bugs in production |
| Accepting placeholder data as spec-compliant | Users see fake data; real integrations never get built |
| Starting quality review before spec passes | Quality-reviewing code that doesn't meet spec is wasted effort |
| Batching multiple tasks into one subagent | Accumulated state causes drift; fresh subagent per task |
| Not recording base SHA before each task | Cannot isolate task changes for review |

## Integration

This skill works with:
- **gaspol-worktree**: Phase 0 isolation — required before concurrent dispatch (mode: independent-domains), recommended for overlapping plan-phases
- **gaspol-plan**: Provides the implementation plan with task breakdown (mode: plan-phases)
- **gaspol-debug**: Identifies independent failure domains to dispatch (mode: independent-domains)
- **gaspol-tdd**: Each dispatched agent follows TDD independently
- **gaspol-review**: Provides the code-reviewer template for quality review
- **plan-verifier** agent: Blocking final audit (mode: plan-phases)
- **gaspol-finish**: Finalizes the work after all tasks complete

## Task Execution Tracking

**Durable ledger (survives `/compact`) — tick-then-append gate, BLOCKING:** alongside the
visual tracker below, after EACH task completes and BEFORE the next one starts, update the
plan's resolved ledger — `.gaspol/progress/PROGRESS-<TICKET>.md` when the plan header names it
(new plans, created by `gaspol-plan` at plan-write time), else an older ledger path
(`.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md`) per its backward-compat
rule (create the file, and its parent dir, if genuinely absent). This is blocking, like a test
gate: no next task until both steps are written, never batched at the end — a crash mid-run
must leave a truthful state, not a stale one:
- **(a) Tick the Checklist:** flip this task's `## Checklist` line — `- [ ]` → `- [>]` when the
  task starts, → `- [x] — DONE` on completion, or → `- [~] — <reason>` if cancelled/skipped
  (reason mandatory, detail in the Log). See `skills/gaspol-plan/SKILL.md` "Progress Ledger
  Format" for the exact four-state template.
- **(b) Append to the Log:**
  `Task [N] [title] — COMPLETE — <1-line summary> — NEXT: <next task, or "DONE">`. If a task
  is left unfinished (blocker or `/compact`), append instead:
  `Task [N] [title] — WIP — <what's done> — BLOCKER: <what's stuck> — NEXT: <exact resume action>`.
The trailing `NEXT:`/`BLOCKER:` fields are the handoff cursor a resumed session reads to know
where to continue and what's blocking (older lines without the suffix still parse). `## Log`
stays the last block in the file — `scan-active-ledgers` reads the file's last non-empty line.
The visual tracker is in-memory and is lost on compaction; the ledger is the durable record a
resumed session reads to know which tasks are done. **Never** write under `.git/` (protected
path — agent writes blocked). Ensure `.gaspol/` is in the project `.gitignore` (working-tree
scratch, never committed); `git clean -fdx` deletes it, recover from `git log`.

**Session-length checkpoint (context-budget nudge):** count waves completed (mode
`independent-domains`) or phases completed (mode `plan-phases`) in the **current run** —
not ones restored from the ledger on resume, only ones this run itself finishes. After every
**3rd** wave/phase completes — the 3rd, 6th, 9th, ... — use the **AskUserQuestion** tool:

> "N phases done this session. Continue here, or pick up fresh next session? The ledger
> (`.gaspol/progress/PROGRESS-<TICKET>.md`, or the plan's declared ledger path) has the exact
> resume point either way."

Options:
- **(a) Continue as normal** — proceed with the next wave/phase immediately
- **(b) Stop here** — report the resume point clearly (the last ledger line's `NEXT:` cursor)
  and end the session
- **(c) Raise the threshold for this run** — user specifies N; don't ask again until N more
  waves/phases complete

Do **not** fire on wave/phase 1 or 2 — only starting at the 3rd completed in this run,
repeating every 3rd thereafter unless raised. This is a bounded, explicit exception to
Continuous Execution Discipline, not a contradiction of it — see the added bullet there.

Track progress visually for the user:

```
Task 1/5: Build ChatSidebar component
  [x] Implementer dispatched
  [x] Implementation complete
  [x] Spec review: PASS
  [x] Quality review: PASS (1 minor noted)
  Status: COMPLETE

Task 2/5: Add session persistence hook
  [x] Implementer dispatched
  [x] Implementation complete
  [x] Spec review: FAIL (2 issues)
  [ ] Fix issues
  [ ] Re-run spec review
  [ ] Quality review
  Status: IN PROGRESS — fixing spec issues
```

## Handling Failures

### Implementer Can't Complete Task
- Ask what's blocking them
- Provide additional context or clarify requirements
- If task is genuinely blocked by missing infrastructure, skip and note for user

### Spec Review Keeps Failing
- Run The Fix Loop: rounds 1-3 resume the implementer, rounds 4-5 bring fresh eyes one model
  tier up. Do not blind-retry the same model with nothing changed.
- If the round-5 breaker trips, something may be wrong with the spec rather than the
  implementation. Adjudicate each open finding and record the ruling.
- Escalate to the user only when adjudication leaves every path forward a guess. Present:
  what was attempted across the rounds, what keeps failing, proposed resolution.

### Quality Review Finds Architectural Issues
- If the architecture was specified in the plan, this is a spec issue (go back to spec)
- If the architecture was left to implementer discretion, fix per reviewer guidance
- If reviewer and implementer disagree, you (the orchestrator) decide based on project conventions

### Tests Fail
- Implementer must fix before reporting completion
- If tests are flaky/environmental, note for user but don't block
- New test failures in unrelated code = flag but don't block this task
