---
name: gaspol-execute
description: "Use when you have a written implementation plan to execute. Enforces anti-placeholder rules, per-phase checkpoints, CLAUDE.md-first approach, and mandatory completion gates. NEVER silently substitute placeholders for real integrations."
---

# gaspol-execute

> "What gets planned gets built — with real data, real integrations, real verification."

## Overview

This is the execution engine for Sparkfluence. When a plan exists in `docs/plans/`, this skill ensures it gets implemented with **FULL FIDELITY** — meaning every integration point, data source, and component described in the plan is built with real, working code.

**Announce at start:**
> "I'm using the gaspol-execute skill to implement the plan at `[plan path]`. Every phase will have a checkpoint report and no placeholders will be substituted for real integrations without your explicit approval."

### Why This Skill Exists

Execution is where plans die. The three most common failure modes are:

1. **Placeholder Substitution** — Plan says "integrate with WorkspaceContext" but implementer writes `const segments = [{id: 1, text: 'Sample'}]` because it's faster.
2. **Step Skipping** — Phase 3 is "hard" so it gets combined with Phase 4, and half the requirements disappear.
3. **Phantom Completion** — "It's done!" but nobody ran the code, checked for TODOs, or verified data flows.

This skill makes all three impossible through enforcement rules, checkpoint gates, and mandatory verification.

---

## The Iron Laws

These are non-negotiable. No rationalization overrides them.

```
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

Every decision during execution must pass through these three laws. If a decision violates any law, STOP and ask the user.

---

## Pre-Execution Protocol

**MANDATORY before writing ANY code.** Do not skip any step.

### Step 1: Read the Plan

Read the plan file from `docs/plans/` completely. Not skimming — read every section, every phase, every bullet point. Identify:

- Total number of phases
- Dependencies between phases
- External integrations required (APIs, hooks, contexts, tables)
- Files that will be created vs. modified
- Data flow: where does each piece of data originate and terminate?

If the plan has gaps, contradictions, or unclear instructions — raise them NOW, before writing code.

### Step 2: Read CLAUDE.md

Read `CLAUDE.md` in its entirety to understand:

- Existing routes and components (do NOT recreate what exists)
- Existing hooks and contexts (do NOT write new ones that duplicate existing)
- Database tables and their schemas (do NOT guess column names)
- Design system tokens (do NOT invent new colors or patterns)
- API key patterns (pool vs. env secrets)
- Edge Function conventions (CORS, response format, error handling)

### Step 3: Create TodoWrite

Create a TodoWrite entry for EVERY phase in the plan. The mapping must be 1:1 — if the plan has 6 phases, the TodoWrite has 6 items. Do not combine phases. Do not add phases the plan doesn't have.

### Step 4: List Modified Files

Before touching any file, list ALL files that will be created or modified across ALL phases. This gives the user a clear picture of the blast radius.

### Step 5: Identify Reusable Code

From CLAUDE.md, extract everything that already exists and can be reused:

- Hooks: `useAuth`, `useChatSessions`, `useSessionPersistence`, etc.
- Contexts: `WorkspaceContext`, `AuthContext`, `OnboardingContext`, etc.
- Utilities: `apiKeyRotation.ts`, `orderIdGenerator.ts`, `supabase.ts`, etc.
- Components: Shadcn UI primitives, layout components, feature components
- Types: existing interfaces in `src/types/`
- Design tokens: color palette, component patterns, typography scales

Document which existing code will be used in each phase.

---

## CLAUDE.md-First Rule

Before starting ANY phase, consult CLAUDE.md. This is not optional.

### What to Extract

| Category | What to Look For | Why |
|----------|-----------------|-----|
| Routes | Existing route structure in `index.tsx` | Avoid route conflicts |
| Hooks | Listed hooks and their signatures | Use existing, don't duplicate |
| Contexts | Provider hierarchy and available state | Access data correctly |
| Tables | Schema, columns, RLS policies | Query correctly |
| API Endpoints | Edge Functions and their I/O format | Call correctly |
| Design Tokens | Colors, spacing, component patterns | Match existing UI |
| Conventions | Naming, file organization, patterns | Stay consistent |

### What This Prevents

- Creating `useSegmentData()` when `useWorkspace()` already provides segments
- Adding a new route that conflicts with existing redirects
- Using `#7C3AED` (purple) instead of `#10B981` (emerald)
- Calling `Deno.env.get('OPENROUTER_API_KEY')` when OpenRouter keys are in the pool table
- Creating `src/utils/helpers.ts` when utilities belong in `src/lib/`

---

## Anti-Placeholder Rules

**This is the most critical section of this skill.** Read `anti-placeholder-rules.md` for the full reference.

### The Core Rule

Before implementing ANY component that displays, processes, or transforms data:

1. **TRACE the data source.** Where does this data come from? A hook? A context? An API call? A prop?
2. **CHECK the plan.** Does the plan specify a real integration for this data?
3. **If YES** — implement the real integration. Period.
4. **If about to write hardcoded data** — STOP. You are about to create a placeholder.

### Decision Gate

If the plan says "integrate with X" but you are about to write `const data = [...]`:

**STOP.** Present the user with three options:

- **(a) Implement real integration now** — the correct default
- **(b) Skip this step entirely** — user decides it's not needed yet
- **(c) Use placeholder with explicit TODO** — user accepts technical debt knowingly

**NEVER choose option (c) silently.** That is the entire point of this skill.

### Data Source Classification

| Data Source | Status | Example Code |
|------------|--------|--------------|
| Supabase query via hook | REAL | `const { data } = useSegments()` |
| Context state | REAL | `const { segments } = useWorkspace()` |
| Edge function response | REAL | `const result = await supabase.functions.invoke(...)` |
| Props from parent (with real source) | REAL | `function Card({ segment }: Props)` |
| Computed from real data | REAL | `const total = segments.reduce(...)` |
| Hardcoded array in component | PLACEHOLDER | `const data = [{id:1, name:'test'}]` |
| Empty array awaiting API | PLACEHOLDER | `const data: Segment[] = []` |
| String literals for dynamic content | PLACEHOLDER | `const title = "Sample Title"` |
| Commented-out API call | PLACEHOLDER | `// TODO: fetch from API` |
| Mock function returning static data | PLACEHOLDER | `const fetchData = () => mockData` |

---

## Per-Phase Checkpoint

After completing EACH phase (not a batch of phases — EACH one), present a structured checkpoint report. See `checkpoint-template.md` for the exact format.

### Checkpoint Rules

1. **One phase, one checkpoint.** Never batch-complete multiple phases.
2. **Wait for approval.** Do not proceed to the next phase until the user says to continue.
3. **Report deviations.** If anything differs from the plan, explain what and why.
4. **Classify data sources.** Every component that handles data must list its source and whether it is real or placeholder.
5. **List all file changes.** Every file created or modified in the phase.

### Checkpoint Template Summary

```
## Phase [X] Complete: [Phase Name]

### Implemented:
- [feature] with [real data source]

### Data Sources:
| Component | Data Source | Type |
|-----------|-----------|------|
| [name] | [source] | Real / Placeholder |

### Files Modified:
- [file path] (created/modified)

### Deviations from Plan:
- None / [description + justification]

### Next Phase: [X+1] — [description]
-> Waiting for approval before proceeding.
```

---

## Execution Flow

### Step 1: Load and Review Plan

- Read the plan file from `docs/plans/`
- Read CLAUDE.md for architecture context
- Identify all phases, dependencies, and data flows
- Raise any concerns about gaps or contradictions
- Create TodoWrite with 1:1 phase mapping

### Step 2: Execute Phase

- Mark the current phase as `in_progress` in TodoWrite
- Implement all requirements for this phase
- For every data-displaying component, trace the data source
- For every integration point, implement the real connection
- If blocked on a real integration, STOP and ask — do not substitute
- Follow CLAUDE.md design system, naming conventions, and patterns

### Step 3: Phase Checkpoint Report

- Present the structured checkpoint report (see template)
- List all components and their data sources with real/placeholder classification
- List all files created or modified
- Report any deviations from the plan with justification
- Mark the phase as `completed` in TodoWrite

### Step 4: Wait for User Approval

- Do NOT proceed until the user explicitly approves
- If the user requests changes, implement them before moving on
- If the user skips a phase, acknowledge and note the skip

### Step 5: Repeat

- Return to Step 2 for the next phase
- Continue until all phases are complete

### Step 6: Completion Gate

- Scan ALL changed files for placeholder indicators (see below)
- Scan for unused functions, orphaned imports, console.log statements
- Report findings — do NOT claim complete if issues exist

### Step 7: Auto-Invoke Verification Chain

After all phases pass the completion gate:

1. **gaspol-verify** — Run type checking, linting, build verification
2. **gaspol-sync-docs** — Update CLAUDE.md with new routes, hooks, tables, etc.
3. **gaspol-review** — Code quality review for consistency and best practices

---

## Completion Gate

**MANDATORY before claiming the implementation is done.**

### Scan All Changed Files For:

```
// TODO
// FIXME
// placeholder
// mock
// dummy
// temp
// hack
// PLACEHOLDER
// MOCK
// DUMMY
// TEMP
// HACK
```

### Also Check For:

- **Hardcoded arrays/objects** that the plan says should come from hooks, context, or API calls
- **Components that import zero hooks/context** but the plan says they should display dynamic data
- **Functions defined but never called** — dead code from incomplete integration
- **`console.log` statements** left in production code (not inside `if (import.meta.env.DEV)`)
- **Empty event handlers** — `onClick={() => {}}` that should have real logic
- **Commented-out code blocks** — real implementation replaced with comments
- **Magic numbers/strings** — hardcoded values that should come from config or constants

### If ANY Issues Found:

Report them in a structured list:

```
## Completion Gate: BLOCKED

### Issues Found:
1. [file:line] — `// TODO: connect to API` — placeholder comment
2. [file:line] — `const segments = []` — empty array, plan says use WorkspaceContext
3. [file:line] — `console.log('debug')` — remove before completion

### Action Required:
Fix these issues or get explicit user approval to ship with them.
```

Do NOT claim the implementation is complete. Do NOT move to the verification chain.

---

## When to Stop Executing

Stop execution and consult the user when:

| Situation | Action |
|-----------|--------|
| **Blocker** — dependency not available, API not ready, missing credentials | Report the blocker, suggest alternatives, wait for guidance |
| **Gap in plan** — instructions unclear, contradictory, or missing detail | Quote the unclear section, propose interpretation, wait for confirmation |
| **Repeated failure** — same verification failing after 2 attempts | Report what was tried, share error details, ask for help |
| **Plan drift** — what you are building no longer matches the plan | Stop, compare plan vs. reality, report the divergence |
| **Scope creep** — you want to add something the plan does not mention | Ask first. The plan is the spec. |
| **Architecture conflict** — plan contradicts CLAUDE.md conventions | Report the conflict, recommend the CLAUDE.md approach, wait for decision |

---

## Red Flags

If you observe any of these during execution, STOP and reassess.

| Red Flag | What It Means | Correct Action |
|----------|--------------|----------------|
| About to write `const data = [...]` | PLACEHOLDER — check plan for real source | Trace data source, implement real integration |
| "I'll connect this to the API later" | Deferring real work | Connect NOW or ask user for explicit skip |
| Skipping a plan phase without asking | VIOLATION of Law 2 | Ask user before skipping any phase |
| "This is basically done" without running code | VIOLATION of Law 3 | Run completion gate scan first |
| Creating a new hook that CLAUDE.md already lists | Didn't read CLAUDE.md | Use the existing hook |
| Batch-completing 3+ phases without checkpoints | VIOLATION of checkpoint rules | One phase, one checkpoint, one approval |
| "Close enough to the plan" | Plan drift without acknowledgment | Compare explicitly, report deviations |
| Component has no imports from hooks/context | Likely using hardcoded data | Verify data source against plan |
| File has more than 3 TODO comments | Incomplete implementation | Resolve TODOs or flag to user |
| Test file created but no assertions written | Phantom test coverage | Write real assertions or flag as incomplete |

---

## Rationalization Prevention

These are the excuses that lead to placeholder-riddled codebases. None of them are valid.

| Excuse | Reality | Correct Action |
|--------|---------|----------------|
| "I'll add real data later" | "Later" never comes. | Add it now or ask user to explicitly defer. |
| "The plan didn't specify exact implementation" | The Data Integration Map IS the specification. | Trace the data flow and implement it. |
| "This placeholder is temporary" | Placeholders become permanent. | Ask user before adding any placeholder. |
| "The hook doesn't exist yet" | That's your job to create it. | Create the hook or flag as a blocker. |
| "It works the same with mock data" | Works does not equal Complete. | Plan says real integration. Do real integration. |
| "Just this one component" | One placeholder leads to many. No exceptions. | Apply the same standard everywhere. |
| "I'm confident the rest is fine" | Confidence is not evidence. | Run the completion gate scan. |
| "Minor deviation from plan" | You don't decide what's minor. | Report it. Let user decide. |
| "The API isn't ready yet" | Valid blocker. But don't silently mock it. | Report the blocker, wait for guidance. |
| "This is just the UI layer" | UI with fake data is a fake UI. | Connect it to real state/data. |
| "I'll clean up the TODOs at the end" | TODOs accumulate and get forgotten. | Resolve each TODO as you go. |
| "The user won't notice" | The user WILL notice. That's why this skill exists. | Build it right the first time. |

---

## Integration with Other Skills

### Upstream (provides input to this skill)

| Skill | What It Provides |
|-------|-----------------|
| `gaspol-plan` | The implementation plan in `docs/plans/` |
| `gaspol-brainstorm` | Design decisions and component specifications |

### Downstream (triggered after this skill completes)

| Skill | When Triggered | Purpose |
|-------|---------------|---------|
| `gaspol-verify` | After completion gate passes | Type checking, linting, build verification |
| `gaspol-sync-docs` | After verification passes | Update CLAUDE.md with new code artifacts |
| `gaspol-review` | After docs sync | Code quality and consistency review |
| `gaspol-finish` | After review passes | Merge, PR creation, cleanup |

### Parallel Execution (optional)

When used with `gaspol-parallel`, this skill dispatches implementer subagents using the template in `implementer-prompt.md`. Each subagent receives:

- Full task description from the plan
- Relevant CLAUDE.md context
- Anti-placeholder rules
- Self-review checklist

---

## Quick Reference Card

```
BEFORE CODING:
  1. Read plan file completely
  2. Read CLAUDE.md completely
  3. Create TodoWrite (1:1 with plan phases)
  4. List all files to be modified
  5. Identify reusable code from CLAUDE.md

DURING EACH PHASE:
  1. Mark phase in_progress
  2. Trace every data source before implementing
  3. If about to hardcode → STOP → ask user
  4. Follow CLAUDE.md design system
  5. Mark phase completed
  6. Present checkpoint report
  7. Wait for approval

AFTER ALL PHASES:
  1. Run completion gate scan
  2. Fix or report all issues
  3. Auto-invoke: verify → sync-docs → review
  4. Only THEN claim complete
```

---

## Failure Recovery

If a phase fails mid-execution:

1. **Do not undo completed work** unless it caused the failure
2. **Report exactly what failed** — error messages, file locations, expected vs. actual
3. **Propose a fix** — but wait for user approval before implementing
4. **If the fix requires plan changes** — flag this as plan drift
5. **After fixing, re-run the phase checkpoint** — do not skip verification

If the completion gate fails:

1. **List all blocking issues** with file paths and line numbers
2. **Categorize each issue** — placeholder, TODO, dead code, console.log, etc.
3. **Propose fixes for each** — but wait for user to prioritize
4. **After fixes, re-run the completion gate** — must pass clean

---

*This skill is the difference between "it compiles" and "it works as planned." Treat every phase as if the user is watching over your shoulder — because they are.*
