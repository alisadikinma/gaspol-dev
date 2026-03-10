# gaspol-dev — Plugin Instructions

## The Rule

**Invoke relevant skills BEFORE any response or action.**

If there is even a 1% chance a skill applies to the user's request, invoke the Skill tool first. Do not respond, do not start working, do not "just quickly do this one thing." Invoke the skill.

## Skill Routing

When a user message arrives, match it against this table and invoke the skill BEFORE responding:

| User Intent | Skill to Invoke |
|-------------|-----------------|
| Create feature, add component, build something new | `gaspol-brainstorm` |
| Design UI, pick colors, layout, styling | `gaspol-design` |
| Plan implementation, break down a task | `gaspol-plan` |
| Execute an existing plan from `docs/plans/` | `gaspol-execute` |
| Execute plan with independent parallel tasks | `gaspol-parallel` |
| 2+ independent tasks, parallel work needed | `gaspol-dispatch` |
| Implement or fix anything (before writing code) | `gaspol-tdd` |
| Bug, error, test failure, unexpected behavior | `gaspol-debug` |
| Review code quality after completing work | `gaspol-review` |
| Received code review feedback from others | `gaspol-receive-review` |
| Claim work is done, ready to commit/merge | `gaspol-verify` |
| Done with feature branch, merge/PR/cleanup | `gaspol-finish` |
| Update CLAUDE.md after code changes | `gaspol-sync-docs` |
| Need feature isolation, git worktree | `gaspol-worktree` |
| Create or edit a skill | `gaspol-write-skill` |

### Priority Order

When multiple skills apply:

1. **Process skills first** (brainstorm, debug, plan) — determine WHAT to do
2. **Implementation skills second** (tdd, execute) — determine HOW to do it
3. **Utility skills third** (worktree, dispatch, finish) — support the workflow

## Workflow Chains

Skills chain together automatically:

```
brainstorm → plan → execute → verify → sync-docs → review → finish
```

- `gaspol-brainstorm` auto-triggers `gaspol-design` for UI work (Phase 3)
- `gaspol-brainstorm` leads to `gaspol-plan` after design approval
- `gaspol-execute` runs per-phase checkpoints, then auto-invokes: verify → sync-docs → review
- `gaspol-finish` runs verification chain before presenting merge options

## Behavioral Rules

### 1. Brainstorm: Ask Before Building

When the user wants to create, add, or modify anything:
- Ask clarifying questions ONE at a time (multiple choice, max 4 options)
- Propose 2-3 approaches with trade-offs
- For UI work, auto-trigger design intelligence
- Produce implementation-ready spec with Data Integration Map
- Do NOT jump to code. Explore the idea first.

### 2. Anti-Placeholder Enforcement

When implementing, NEVER silently substitute placeholders for real integrations:
- If plan says "integrate with X" but you're about to write `const data = [...]` → STOP
- Present three options: (a) implement real integration, (b) skip entirely, (c) placeholder with explicit TODO
- NEVER choose option (c) silently

### 3. Per-Phase Checkpoints

During execution, after EACH phase (not batched):
- Present structured checkpoint report
- List all data sources as Real or Placeholder
- Wait for user approval before proceeding

### 4. Evidence Before Assertions

Before claiming anything is done:
- Run the verification command (`tsc --noEmit`, `npm test`, `npm run build`)
- Read the COMPLETE output
- Quote the evidence in your response

### 5. CLAUDE.md-First

Before exploring any codebase:
- Read CLAUDE.md first to understand existing architecture
- Extract hooks, contexts, routes, tables, design tokens
- Only explore codebase for details NOT in CLAUDE.md

## Architecture

| Path | Purpose |
|------|---------|
| `skills/` | 16 skill directories, each with SKILL.md |
| `agents/` | 4 agent definitions |
| `hooks/` | SessionStart hook (announces available skills) |
| `.claude-plugin/` | Plugin + marketplace metadata |

### Agents

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Code review between commits |
| `code-simplifier` | Simplify and refine code for clarity |
| `plan-verifier` | Compare plan vs actual code changes |
| `spec-reviewer` | Verify implementation matches specification |

## Red Flags: Rationalizations for NOT Invoking Skills

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple for a skill" | Simple tasks still benefit from process discipline |
| "I already know how to do this" | Skills encode lessons learned; your memory doesn't |
| "It'll be faster without the skill" | Faster now = slower later when bugs appear |
| "The user just wants a quick answer" | Quick answer + correct process > quick answer + debt |
| "I'll follow the skill mentally" | Mental following = skipping steps. Invoke it. |
| "This skill doesn't quite fit" | 1% chance = invoke. Let the skill decide. |
| "The user didn't ask for TDD" | Users say WHAT, not HOW. TDD is HOW. |
