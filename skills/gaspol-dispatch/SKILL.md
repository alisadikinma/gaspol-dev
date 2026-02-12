---
name: gaspol-dispatch
description: "Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies. Dispatches one agent per problem domain for parallel resolution."
---

# Dispatching Parallel Agents

## Core Principle

One agent per independent problem domain. Parallel resolution. No shared state.

Dispatching agents is the concurrent version of divide-and-conquer. Each agent gets a focused, self-contained task with clear inputs and outputs. They work in isolation and their results are integrated afterward.

---

## When to Use

- **3+ failures with different root causes** -- e.g., broken tests in auth, API, and UI simultaneously
- **Multiple independent subsystems** need changes -- e.g., database migration + frontend component + API endpoint (when they don't depend on each other)
- **No shared state** between tasks -- each agent can work without knowing what the others are doing
- **Embarrassingly parallel** work -- tasks that are truly independent
- **Large refactoring** across multiple unrelated files or modules

## When NOT to Use

- **Related failures** -- if fixing one might fix the others, work sequentially
- **Need full context** -- if understanding the whole system is required for each task
- **Exploratory debugging** -- you don't yet know what's wrong, let alone how to split it
- **Shared state** -- tasks read/write the same files, variables, or database tables
- **Sequential dependencies** -- task B depends on the output of task A
- **Single root cause** -- multiple symptoms but one underlying problem
- **Small tasks** -- the overhead of dispatching exceeds the time saved

---

## The Pattern

### Step 1: Identify Independent Domains

List all tasks. For each pair, ask: "Can these be done simultaneously without conflicts?"

```
Task A: Fix authentication middleware
Task B: Update user profile UI
Task C: Add rate limiting to API

A + B: Independent? YES (different layers)
A + C: Independent? YES (auth vs rate limiting, different middleware)
B + C: Independent? YES (frontend vs backend)

Result: All 3 can be dispatched in parallel.
```

**Conflict check:**
- Do they modify the same files? If yes, do NOT parallelize.
- Do they modify the same database tables? If yes, do NOT parallelize.
- Does one produce output the other needs? If yes, do NOT parallelize.

### Step 2: Create Focused Task Descriptions

Each agent gets a self-contained prompt with:

1. **Context** -- What the agent needs to know (and ONLY that)
2. **Task** -- Exactly what to do (specific, measurable)
3. **Constraints** -- What NOT to touch
4. **Output** -- What to produce (files changed, tests added, summary)

```
AGENT 1: Authentication Middleware Fix
CONTEXT: The auth middleware in src/middleware/auth.ts rejects valid JWT tokens
         when the token contains a "roles" claim as an array instead of string.
TASK:    Fix the JWT validation to accept both array and string role claims.
         Add tests for both formats.
CONSTRAINTS: Do NOT modify the User model, routing, or any other middleware.
OUTPUT:  Modified auth.ts, new test file, summary of changes.
```

```
AGENT 2: User Profile UI Update
CONTEXT: The profile page at src/screens/Profile.tsx needs a timezone selector.
TASK:    Add a timezone dropdown using the existing Select component from Shadcn UI.
         Wire it to the user_preferences table via the existing updateProfile hook.
CONSTRAINTS: Do NOT modify the authentication flow, API endpoints, or database schema.
OUTPUT:  Modified Profile.tsx, updated hook if needed, summary of changes.
```

### Step 3: Dispatch Agents

Use the Task tool or subagent mechanism to dispatch each agent with its focused task description.

**Rules for dispatching:**
- Each agent works in isolation
- Each agent follows TDD (gaspol-tdd) independently
- Each agent reports its changes as a summary
- No agent should reference or depend on another agent's work

### Step 4: Review and Integrate

After all agents complete:

1. **Read each summary** -- understand what was changed
2. **Check for conflicts** -- any unexpected file overlaps?
3. **Run the full test suite** -- do all changes work together?
4. **Resolve conflicts** -- if agents modified the same file unexpectedly, manually merge
5. **Integration test** -- verify the combined changes work as a system

---

## Agent Prompt Structure

Template for agent task descriptions:

```
## Task: [Clear, specific title]

### Context
[Minimum necessary background. Only what this agent needs.]

### Objective
[Exactly what to accomplish. One clear goal.]

### Files to Modify
[Explicit list of files this agent should touch.]

### Files NOT to Modify
[Explicit list of files this agent must NOT touch.]

### Acceptance Criteria
- [ ] [Specific, testable criterion]
- [ ] [Specific, testable criterion]
- [ ] Tests pass for all changes

### Output
Provide a summary with:
1. Files modified (with brief description of each change)
2. Tests added
3. Any concerns or edge cases discovered
```

---

## Verification After Integration

After integrating all agent outputs:

- [ ] Full test suite passes (not just individual agent tests)
- [ ] No file conflicts between agent changes
- [ ] No duplicate code introduced by separate agents
- [ ] Integration points work correctly (agents' changes interact properly)
- [ ] No regressions in unrelated functionality

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Dispatching dependent tasks | Agents block on each other or produce conflicting changes | Identify dependencies, run sequentially |
| Vague task descriptions | Agents guess at scope, overlap with each other | Write specific, bounded tasks |
| Too many agents | Overhead exceeds benefit, integration becomes complex | 2-4 agents maximum for most tasks |
| No integration step | Individual changes work alone but break together | Always run full suite after integration |
| Dispatching before understanding | You split the problem wrong because you didn't analyze it | Debug/analyze first, then dispatch |

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-debug` | Identifies independent failure domains to dispatch |
| `gaspol-tdd` | Each dispatched agent follows TDD independently |
| `gaspol-execute` | Dispatch is one strategy within execution |
| `gaspol-verify` | Final verification after integrating all agent outputs |
| `gaspol-worktree` | Each agent can work in a separate worktree for true isolation |
