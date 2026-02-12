---
name: gaspol-parallel
description: "Use when executing implementation plans with independent tasks in the current session. Dispatches fresh subagent per task with anti-placeholder enforcement and two-stage review (spec compliance then code quality)."
---

# Sparkfluence Parallel Development

## Overview

Fresh subagent per task + two-stage review = high quality, fast iteration.

Each task gets a dedicated implementer subagent with full context (no accumulated state drift), followed by two independent review passes: spec compliance (did you build the right thing?) then code quality (did you build it right?). Anti-placeholder rules are enforced at every stage.

## When to Use

Use this skill when ALL of the following are true:
- You have an implementation plan (from `gaspol-plan`)
- Tasks are mostly independent (can be done in sequence without heavy cross-dependencies)
- You want to stay in this session (not creating worktrees for parallel human review)

Do NOT use when:
- Tasks are trivial (< 3 steps each) — just implement directly
- Tasks are heavily interdependent — implement sequentially yourself
- You need human review between tasks — use `gaspol-worktree` instead

## Process Flow

### Phase 1: Plan Intake

1. Read the implementation plan (from `gaspol-plan` output or user-provided)
2. Extract individual tasks with their:
   - Task number and title
   - Full requirements text
   - Dependencies on other tasks (if any)
   - Acceptance criteria
3. Determine execution order based on dependencies
4. Confirm task list with user before starting

### Phase 2: Task Execution (repeat per task)

For each task in dependency order:

#### Step 1: Prepare Context

Gather scene-setting context the implementer needs:
- Relevant sections from CLAUDE.md (architecture, conventions, patterns)
- Existing code that the task touches or depends on
- Output from previous tasks (if this task depends on them)
- Any user clarifications from planning phase

#### Step 2: Dispatch Implementer

Use the `implementer-prompt.md` template. Key rules:
- **Paste the full task text** into the subagent prompt — NEVER reference a file
- Include all scene-setting context inline
- Include anti-placeholder rules (see below)
- Include self-review checklist

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
5. Reports completion with the specified format

#### Step 5: Spec Review

Dispatch the spec reviewer using `spec-reviewer-prompt.md`:
- Reviewer reads ACTUAL CODE (not the implementer's report)
- Compares implementation to requirements line by line
- Checks for placeholder data (CRITICAL)
- Returns: spec-compliant OR list of issues

If issues found:
1. Fix each issue (yourself or dispatch implementer again)
2. Re-run spec review until clean
3. Do NOT proceed to quality review until spec passes

#### Step 6: Code Quality Review

Dispatch the code quality reviewer using `code-quality-reviewer-prompt.md`:
- Uses the `gaspol-review` skill's code-reviewer template
- Reviews commits between the task's base SHA and current HEAD
- Focuses on code quality, architecture, testing, production readiness

If issues found:
1. Fix Critical issues immediately
2. Fix Important issues before proceeding
3. Note Minor issues (fix if quick, otherwise track)

#### Step 7: Mark Complete

- Record the task as done
- Note any issues deferred to later tasks
- Move to next task

### Phase 3: Final Review

After ALL tasks complete:
1. Run `gaspol-review` on the full changeset (all tasks combined)
2. Run `gaspol-finish` to finalize

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
| Dispatching parallel implementation subagents | Race conditions, merge conflicts, context drift |
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
- **gaspol-plan**: Provides the implementation plan with task breakdown
- **gaspol-review**: Provides the code-reviewer template for quality review
- **gaspol-finish**: Finalizes the work after all tasks complete
- **gaspol-worktree**: Alternative when you need human review between tasks

## Task Execution Tracking

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
