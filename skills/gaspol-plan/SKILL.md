---
name: gaspol-plan
description: "Use when you have a spec or requirements for a multi-step task, before touching code. Creates comprehensive plans with mandatory Data Integration Maps and per-phase verification criteria."
---

# gaspol-plan

## Overview

Write comprehensive implementation plans assuming the executor has **zero context** and **questionable taste**. Every plan includes:

- A **Data Integration Map** (contract for real vs placeholder)
- **Per-phase verification criteria** (no phase ships without passing checks)
- **TDD-first steps** (write test, see fail, implement, see pass, commit)

Plans follow: DRY, YAGNI, TDD-first, frequent commits.

## Announce at Start

> "I'm using the gaspol-plan skill to create the implementation plan."

## CLAUDE.md-First (Before Writing ANY Plan)

Before writing a single line of the plan, you MUST:

1. **READ `CLAUDE.md`** to understand existing architecture, tables, hooks, contexts, routes
2. **IDENTIFY reusable** hooks, contexts, utilities, and patterns already in the codebase
3. **CHECK if similar features already exist** (avoid duplicating work)
4. **REFERENCE existing code in the plan** with full file paths (e.g., `src/contexts/WorkspaceContext.tsx`)

If you skip this step, the plan will inevitably reinvent existing abstractions.

## Save Plans To (Hybrid File Structure)

Single file default — brainstorm + plan live in the same document:

```
docs/plans/YYYY-MM-DD-<feature-name>.md
```

**Append behavior:** If a file with this name already exists (e.g., brainstorm already produced the design section), APPEND a new `## Implementation Plan` section to the same file. Do NOT create a separate `-plan.md` file.

**Split conditions** (create separate `-plan.md` file only when):
- Existing file would exceed 500 lines after appending
- User explicitly requests `--split` flag
- Design approved by stakeholder independently of plan (e.g., client sign-off)

Check file existence before writing:
```bash
# Pseudo-logic:
if [ -f "docs/plans/YYYY-MM-DD-<topic>.md" ]; then
  if [ $(wc -l < "docs/plans/YYYY-MM-DD-<topic>.md") -gt 500 ]; then
    # Split: write to YYYY-MM-DD-<topic>-plan.md
  else
    # Append ## Implementation Plan section
  fi
else
  # Create new file with full plan
fi
```

## Plan Document Header (MANDATORY)

Every plan document MUST start with this header:

```markdown
> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.

## Goal

[One paragraph describing what this plan achieves and why it matters]

## Architecture Context

[Key info pulled from CLAUDE.md: relevant tables, hooks, contexts, routes, design system tokens]

## Tech Stack

[Frameworks, libraries, patterns to use — reference existing choices from CLAUDE.md]
```

## Bite-Sized Task Granularity

Each step should be **one action** (2-5 minutes estimated):

1. Write one failing test
2. Run it, see it fail
3. Implement minimal code to pass
4. Run tests, see them pass
5. Commit

If a step takes longer than 5 minutes to describe, it is too large. Break it down further.

## Data Integration Map (MANDATORY in Every Plan)

Every plan MUST include a Data Integration Map table:

```markdown
## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| SegmentCard | WorkspaceContext.segments | useWorkspace() | Yes | Use existing |
| RetentionScore | scoringEngine | import from lib/knowledge | Yes | Import directly |
| VoicePreview | generate-tts edge fn | needs useVoicePreview | No | Create new hook |
| UserAvatar | Supabase auth | useAuth() | Yes | Use existing |
```

This table is the **CONTRACT** between planner and executor:

- **Yes (exists):** Executor uses it directly. No reinvention.
- **No (doesn't exist):** Executor creates it as a real, working integration. NOT a placeholder.
- **If not possible:** Executor STOPS and asks the user. Never silently stub it out.

A plan without a Data Integration Map is **INCOMPLETE**. Do not proceed to phases without it.

## Phase Structure

Each phase MUST follow this exact structure:

```markdown
### Phase A: [Phase Name]

**Estimated time:** [X minutes]

**Files:**
- Create: `src/components/SegmentCard.tsx`
- Modify: `src/screens/Workspace/ScriptStep.tsx`
- Test: `src/__tests__/SegmentCard.test.tsx`

**Steps:**
1. Write failing test for SegmentCard rendering. Expected error: `ReferenceError: SegmentCard is not defined`
2. Run test, confirm it fails for the expected reason
3. Implement SegmentCard with real data from useWorkspace()
4. Run tests, confirm all pass
5. Commit: "feat: add SegmentCard with workspace integration"

**Verification:**
- [ ] tsc --noEmit passes
- [ ] SegmentCard renders with real data from WorkspaceContext
- [ ] No placeholder/TODO comments in new code
- [ ] Test suite passes
```

**TDD Step 1 Hard Gate (MANDATORY):** Every phase MUST have step 1 in this exact format:
```
1. Write failing test for [specific behavior]. Expected error: [error class/message].
```

`gaspol-execute` enforces this — phase without proper TDD step 1 will be refused at execution time (Step 2 hard gate). Plans violating this template are rejected before execution starts.

**Design Deliverable Column (for UI-related phases):** When phase involves UI work (detected via file ext `.tsx/.jsx/.vue/.svelte/.astro/.css`), the Phase table MUST include a Design Deliverable column:

```markdown
| Phase | Code Deliverable | Design Deliverable | Verification |
|-------|-----------------|-------------------|--------------|
| 1 | useAuth hook | n/a (backend) | Tests + types |
| 2 | LoginForm component | Design spec (tokens, layout, motion, states) | Design system compliance |
```

Design deliverable is produced by invoking `gaspol-design` during plan creation for each UI phase.

## Verification Criteria per Phase (MANDATORY)

Every phase MUST end with a Verification block. At minimum, include:

```markdown
**Verification:**
- [ ] tsc --noEmit passes
- [ ] Component renders with real data from [specific source]
- [ ] No placeholder/TODO comments in new code
- [ ] [specific functional check for this phase]
```

A phase without verification criteria is **INCOMPLETE**. The executor will not know when the phase is done.

## Execution Handoff

After the plan is written and saved, offer the user three options:

**Option 1: Execute in this session**
> "Ready to start Phase A? I'll use gaspol-execute to implement with per-phase checkpoints."

**Option 2: Parallel execution**
> "Want to use gaspol-parallel for independent phases? Phases [X, Y] can run in parallel."

**Option 3: Separate session**
> "Save plan for a new session? The plan file at `docs/plans/...` has everything needed."

## Red Flags (Self-Check Before Finishing)

Before presenting the plan, verify none of these red flags are present:

| Red Flag | Problem | Fix |
|----------|---------|-----|
| No Data Integration Map | Executor will guess at data sources | Add the map table |
| Phase without Verification | Executor won't know when phase is done | Add verification block |
| No reference to CLAUDE.md | Planner didn't read existing architecture | Re-read CLAUDE.md, update plan |
| Vague data sources ("connect to backend") | Executor will create placeholders | Specify which hook, API, context, table |
| No test steps | No TDD cycle, bugs ship silently | Add write-test/run-test steps |
| Phase too large (>15 min estimated) | Executor loses focus, skips verification | Break into smaller phases |
| Placeholder language ("TODO: wire up later") | Violates anti-placeholder contract | Specify the real integration now |

## Integration with Other Skills

| Trigger | Skill | Relationship |
|---------|-------|-------------|
| Before this skill | `gaspol-brainstorm` | Brainstorm produces the design section in same file; plan appends |
| During this skill | `gaspol-design` | Invoked for each UI phase to produce design deliverable |
| During this skill | `gaspol-adr` | Capture architectural decisions at fork points in the plan |
| After this skill | `gaspol-execute` | Execute the plan with per-phase checkpoints + TDD hard gate |
| After this skill | `gaspol-parallel` | Execute independent phases in parallel (mode: plan-phases) |
