# gaspol-parallel — when to use each mode

Moved verbatim from `SKILL.md` (IDS-23).

### Mode 1: `plan-phases`

**Use when:**
- You have an implementation plan (from `gaspol-plan`)
- Phases are mostly independent (can be done in sequence without heavy cross-dependencies)
- You want to stay in this session (continuous execution, not separate worktrees per human review)


### Mode 2: `independent-domains`

**Use when:**
- 3+ failures with different root causes (e.g., broken tests in auth, API, and UI simultaneously)
- Multiple independent subsystems need changes (database migration + frontend component + API endpoint, when they don't depend on each other)
- No shared state between tasks — each agent can work without knowing what the others are doing
- Embarrassingly parallel work
- Large refactoring across multiple unrelated files or modules

### Do NOT Use This Skill When

- Tasks are trivial (< 3 steps each) — just implement directly
- Tasks are heavily interdependent — implement sequentially yourself
- Related failures (fixing one might fix others) — work sequentially
- Shared state — tasks read/write the same files, variables, database tables
- Sequential dependencies — task B depends on output of task A
- Single root cause with multiple symptoms
- Small tasks where dispatch overhead exceeds time saved

## Overview (continued)

Each task gets a dedicated implementer subagent with full context (no accumulated state drift), followed by two independent review passes: spec compliance (did you build the right thing?) then code quality (did you build it right?). Anti-placeholder rules are enforced at every stage.

## Integration

This skill works with:
- **gaspol-worktree**: Phase 0 isolation — required before concurrent dispatch (mode: independent-domains), recommended for overlapping plan-phases
- **gaspol-plan**: Provides the implementation plan with task breakdown (mode: plan-phases)
- **gaspol-debug**: Identifies independent failure domains to dispatch (mode: independent-domains)
- **gaspol-tdd**: Each dispatched agent follows TDD independently
- **gaspol-review**: Provides the code-reviewer template for quality review
- **plan-verifier** agent: Blocking final audit (mode: plan-phases)
- **gaspol-finish**: Finalizes the work after all tasks complete
