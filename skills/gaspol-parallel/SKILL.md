---
name: gaspol-parallel
description: "Use when executing implementation plans with independent phases (mode: plan-phases) OR when handling 2+ independent problem domains ad-hoc (mode: independent-domains). Dispatches fresh subagent per task with anti-placeholder enforcement, conflict check, and two-stage review (spec compliance then code quality). Replaces former gaspol-dispatch."
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

**Process:** Domain Identification → Conflict Check → Concurrent Dispatch (single message, multiple Agent tool calls) → Review + Integrate

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
- A spec/quality review fails after 3 fix attempts (escalate — see Handling Failures).
- A genuine ambiguity in a task blocks progress (ask via AskUserQuestion).
- An Iron Law violation or destructive operation is required (always pause).
- All tasks complete.

Update the visual task tracker as you go (see Task Execution Tracking) instead of narrating each task in prose. This is the in-session analogue of `gaspol-auto`'s hard-stop guardrails — autonomous flow, bounded by the same always-pause conditions.

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

### Mode `independent-domains` — Phase 1: Domain Identification + Conflict Check

1. List all problems/tasks
2. For each pair, ask: "Can these be done simultaneously without conflicts?"
3. **Conflict check** (BLOCKING):
   - Do they modify the same files? If yes → do NOT parallelize
   - Do they modify the same database tables? If yes → do NOT parallelize
   - Does one produce output the other needs? If yes → do NOT parallelize
4. If all pairs pass conflict check, proceed to concurrent dispatch
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

Use the `implementer-prompt.md` template. Key rules:
- **Paste the full task text** into the subagent prompt — NEVER reference a file
- Include all scene-setting context inline
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
2. Runs tests (if applicable)
3. Runs `tsc --noEmit` to verify types
4. Self-reviews against the checklist
5. Reports completion with the specified format — including a **§0 Status** line
   (`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`)

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

Dispatch the spec reviewer using `spec-reviewer-prompt.md` (pass the review-package path):
- Reviewer reads ACTUAL CODE (not the implementer's report)
- Compares implementation to requirements line by line
- Checks for placeholder data (CRITICAL)
- Returns: spec-compliant OR list of issues

**Fix → re-review loop:** if issues are found, dispatch a fix (yourself or a fresh implementer
subagent) and then **RE-RUN the spec review** — do not accept "I fixed it" without a clean
re-review. Loop until spec passes; do NOT proceed to quality review until it does. After 3
loops still failing → escalate (see Handling Failures).

#### Step 6: Code Quality Review

Dispatch the code quality reviewer using `code-quality-reviewer-prompt.md` (pass the same
review-package path):
- Uses the `gaspol-review` skill's code-reviewer template
- Reviews the diff in the review package (base SHA → HEAD)
- Focuses on code quality, architecture, testing, production readiness

**Fix → re-review loop:** for Critical/Important findings, dispatch a fix subagent then
**RE-RUN the quality review** until clean. Note Minor issues (fix if quick, else track). Do not
mark the task complete with unresolved Critical/Important findings.

#### Step 7: Mark Complete

- Record the task as done
- Note any issues deferred to later tasks
- Move to next task

### Phase 3: Final Review + Integration

**Mode `plan-phases`:** After ALL phases complete:
1. Run `gaspol-review` on the full changeset
2. Run `plan-verifier` agent (BLOCKING — step-level evidence-based)
3. Run `gaspol-finish` to finalize

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
| Making subagent read plan file instead of pasting task text | Subagent may misparse, miss context, or read stale version |
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

**Durable ledger (survives `/compact`):** alongside the visual tracker below, append one
line per finished task to `.gaspol/progress.md` in the project root (create if absent):
`Task [N] [title] — COMPLETE — <1-line summary>`. The visual tracker is in-memory and is
lost on compaction; the ledger is the durable record a resumed session reads to know which
tasks are done. **Never** write under `.git/` (protected path — agent writes blocked).
Ensure `.gaspol/` is in the project `.gitignore` (working-tree scratch, never committed);
`git clean -fdx` deletes it, recover from `git log`.

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
- After 3 attempts, stop and escalate to user
- Something may be wrong with the spec, not the implementation
- Present: what was attempted, what keeps failing, proposed resolution

### Quality Review Finds Architectural Issues
- If the architecture was specified in the plan, this is a spec issue (go back to spec)
- If the architecture was left to implementer discretion, fix per reviewer guidance
- If reviewer and implementer disagree, you (the orchestrator) decide based on project conventions

### Tests Fail
- Implementer must fix before reporting completion
- If tests are flaky/environmental, note for user but don't block
- New test failures in unrelated code = flag but don't block this task
