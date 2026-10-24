---
name: gaspol-parallel
description: "Use when executing implementation plans with independent phases (mode: plan-phases) OR when handling 2+ independent problem domains ad-hoc (mode: independent-domains)."
---

# gaspol-parallel (with Mode Field)

## Overview

Fresh subagent per task + two-stage review = high quality, fast iteration.

## Mode Field (NEW)

This skill supports two modes, selected at invocation:

### Mode 1: `plan-phases`

Execute an implementation plan with multiple phases that are mostly independent.

Read `references/modes.md` when choosing between modes, or when you need the Overview rationale or the Integration list of related skills.

**Process:** Phase Intake → per-phase (Implementer → Spec Review → Quality Review) → Final integration

### Mode 2: `independent-domains`

Dispatch one agent per independent problem domain for true concurrent resolution (divide-and-conquer).

**Process:** Domain Identification → DAG Lane Scheduling (`scripts/dag-lanes`) → Wave-by-Wave Dispatch (each wave = one batch of concurrent Agent calls, one per lane; lanes with multiple tasks run sequentially inside) → Review + Integrate. A new wave starts only after the previous wave's tasks all return.

Read `references/modes.md` when you are unsure whether parallel dispatch fits: it holds the Do NOT Use list.

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
checked as you check it.

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
clean — rows written, nothing found — proceed without further comment.

## Process Flow

Read `references/process-flow.md` when you dispatch an implementer or need the full step text, the Validation Ladder table or the `dag-lanes` example.

### Mode `plan-phases` — Phase 1: Plan Intake

Extract each task's number, title, full requirements, dependencies and acceptance criteria. When the plan carries `**Format:** waves-v1`, take deps, files, model and effort from the
output of `skills/gaspol-plan/scripts/plan-waves` instead of re-deriving them (invoke it
anchored: `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan>`).
Confirm task list with user before starting.

### Mode `independent-domains` — Phase 1: Domain Identification + DAG Lane Scheduling

For EACH task, write its **dependency + write set**: `deps` and `files` (a shared DB table is a synthetic file token, e.g. `db:users`).

**Run the scheduler** (BLOCKING — do not hand-schedule; topological order and file-overlap
grouping are error-prone by eye) with `skills/gaspol-parallel/scripts/dag-lanes`.
- **Wave** = dependency layer. Never start wave N+1 until wave N fully completes.
- **Lane** = within a wave, tasks sharing a file are one lane (run **sequentially**); lanes
  with no file overlap run **concurrently**.
- The scheduler rejects dependency cycles and unknown deps (`ValueError`) — fix the task
  graph before dispatching.
- **Sanity-check the matrix.** If two tasks landed in the same lane but you expected them
  parallel, you under-declared `files` (or over-declared a shared one). Adjust and re-run.

### Phase 2: Task Execution (repeat per task)

**Record the base SHA first** (`git rev-parse HEAD`) — this is the BASE you pass to
`review-package` later. NEVER use `HEAD~1` as the base: a multi-commit task has more than one
commit and `HEAD~1` silently drops all but the last.

**Extract the task's brief first.** Run
`skills/gaspol-parallel/scripts/task-brief <PLAN_FILE> <N>` — it writes that one task's
full text to `.gaspol/tasks/<TICKET>/task-<N>-brief.md` and prints the path. The brief is
the single source of the implementer's requirements. Use the `implementer-prompt.md` template. A dispatch prompt carries exactly five things: one line on where the task fits, the brief path ("read this first — it is your requirements, with the exact values to use **verbatim**"), interfaces from earlier tasks, your resolution of any ambiguity, and the **report-file path** (`.gaspol/tasks/<TICKET>/task-<N>-report.md`) with the short return contract.

**Never reference the plan.** A subagent handed a 2000-line plan reads the wrong task —
the plan stays off-limits; the **task-scoped brief** is the handoff.

**Exact values** — numbers, magic strings, signatures, test cases — live only in the brief.
Retyping them into the prompt is where they drift.

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

The implementer runs the **Validation Ladder** — `DONE` is not allowed until it passes — and reports a **§0 Status** line
(`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`).

##### Validation Ladder (fail-fast, cheapest first)

Run the levels **in order, stopping at the
first failure**. L1–L3 commands come from `skills/gaspol-execute/scripts/detect-stack <project-root>`; `<level>: UNKNOWN` → STOP and ask the user for the correct command, don't guess.
- **Fail at level N → fix, then restart the ladder from L1** — a fix can re-break an earlier level.
- **A level that genuinely doesn't apply is skipped explicitly, not silently** — e.g. "L3 Build:
  N/A, no build step".
- **An implementer subagent cannot run `detect-stack` itself** — the orchestrator resolves the L1–L3
  commands before dispatch and pastes them verbatim into the task prompt (see
  `implementer-prompt.md`).

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

Before either review, run `skills/gaspol-parallel/scripts/review-package <BASE> HEAD` and hand the path it prints to the
reviewer subagents. **BASE is the Step-2 SHA, never `HEAD~1`**.

#### Step 5: Spec Review

Dispatch with `subagent_type: "gaspol-dev:spec-reviewer"`, `model: "opus"`, using `spec-reviewer-prompt.md` (pass the review-package path):
- Reviewer reads ACTUAL CODE (not the implementer's report)
- Checks for placeholder data (CRITICAL)

**Fix → re-review loop:** if issues are found, run **The Fix Loop** below — do not accept
"I fixed it" without a clean re-review. Do NOT proceed to quality review until spec passes.

#### Step 6: Code Quality Review

Dispatch with `subagent_type: "gaspol-dev:code-reviewer"`, `model: "opus"`, using `code-quality-reviewer-prompt.md` (pass the same
review-package path).

**Adversarial refutation (gaspol-review Step 2.5):** before acting on any Critical/Important
finding, dispatch one refuter subagent per finding (default REFUTED) to kill false positives.
Drop REFUTED findings; only CONFIRMED (or unverifiable) ones proceed.

**Fix → re-review loop:** surviving Critical/Important findings go through **The Fix Loop**
below. Note Minor issues in the ledger (`Task <N>: minor (deferred): <one-liner>`) and point
the final review at that list — a roll-up nobody reads is a silent discard. Minor findings
never enter the loop. Do not mark the task complete with unresolved Critical/Important
findings.

##### The Fix Loop

**Canonical rule: [skills/_shared/fix-loop.md](../_shared/fix-loop.md)** — read it when a review returns findings.
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

Read `references/anti-placeholder-examples.md` when you need the definition of a placeholder or the code examples.

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

## Task Execution Tracking

Read `references/task-tracking.md` when you tick a task in the ledger or reach a session-length checkpoint.

**Durable ledger (survives `/compact`) — tick-then-append gate, BLOCKING:** after EACH task
completes and BEFORE the next one starts, update the plan's resolved ledger (`.gaspol/progress/PROGRESS-<TICKET>.md`). This is blocking, like a test
gate: no next task until both steps are written, never batched at the end — a crash mid-run
must leave a truthful state, not a stale one: (a) tick the task's `## Checklist` line; (b) append its line to the `## Log`, ending in the `NEXT:` cursor. `## Log` stays the last block in the file. **Never** write under `.git/`.

**Session-length checkpoint:** after every **3rd** wave/phase completed in the current run, use the **AskUserQuestion** tool: offer continue, stop here with the resume point, or raise the threshold. Do **not** fire on wave/phase 1 or 2.

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
