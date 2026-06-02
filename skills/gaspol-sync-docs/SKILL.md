---
name: gaspol-sync-docs
description: "Use after implementing significant code changes to keep CLAUDE.md in sync with actual code. Also use standalone for quality audits or to capture session learnings. CLAUDE.md is the single source of truth — if it's outdated, the next session repeats mistakes. Three modes: post-implementation sync, quality audit, session learning capture."
---

# gaspol-sync-docs

## Overview

CLAUDE.md is the handoff document between sessions. If it's outdated, the next session wastes 10-50k tokens re-exploring the codebase. This skill ensures CLAUDE.md stays as the single source of truth.

## The Iron Law

```
NO COMPLETION WITHOUT CLAUDE.MD IN SYNC WITH ACTUAL CODE
```

## When to Trigger (MANDATORY)

- After implementing ANY plan phase that adds/modifies: tables, edge functions, routes, hooks, contexts, AI models, config
- After gaspol-execute completes all phases (before gaspol-finish)
- After gaspol-verify passes (part of completion chain)
- User can invoke standalone: `/gaspol-sync-docs`

## Three Modes

### Mode 1: Post-Implementation Sync (auto-triggered in chain)

1. **Scan changes:** Read git diff to identify what changed
2. **Map to CLAUDE.md sections:**

| Change Type | CLAUDE.md Section to Update |
|---|---|
| New DB table/column | "Key Tables" + "Database Conventions" |
| New Edge Function | "Key Directories" + "Generation Flow" |
| New frontend route | Route tables in relevant section |
| New hook/context | "Key Directories" + relevant section |
| AI model change | "AI Model Priority" + "Providers in Pool" |
| New config/env var | "Environment Variables" |
| New component pattern | Design system section |
| New Python feature | Relevant backend section |
| New dependency | Relevant technology section |
| Bug fix with learnings | "Debugging Checklist" |

3. **Generate update diff:** Show exactly what lines in CLAUDE.md need to change
4. **Apply updates:** After user approval, update CLAUDE.md
5. **Verify:** Confirm CLAUDE.md sections are internally consistent

### Mode 2: Quality Audit (`/gaspol-sync-docs audit`)

1. **Discover** all CLAUDE.md files (root, .claude.local.md, package-specific)
2. **Score** against 6 criteria (100 points total):

| Criteria | Points | What It Measures |
|---|---|---|
| Commands & Workflows | 20 | Key commands documented? Copy-paste ready? |
| Architecture Clarity | 20 | Can a new session understand the full stack? |
| Non-Obvious Patterns | 15 | Gotchas, conventions, "why X not Y" |
| Conciseness | 15 | No bloat -- every line earns its place |
| Currency | 15 | Does it match actual code? Stale references? |
| Actionability | 15 | Instructions are specific, not vague |

3. **Grade:** A (90+), B (75-89), C (60-74), D (45-59), F (<45)
4. **Recommend** targeted improvements per section
5. **Apply** after user approval

### Mode 3: Session Learning Capture (`/gaspol-sync-docs learn`)

1. **Reflect:** What context was missing at session start that caused wasted effort?
2. **Identify:** What did we discover mid-session that should be documented?
3. **Propose:** Concise one-liner additions to CLAUDE.md
4. **Show diff** before applying

## Execution Steps

### For Mode 1 (Post-Implementation Sync)

```
Step 1: Run `git diff --stat` to see changed files
Step 2: For each changed file, determine which CLAUDE.md section(s) it maps to
Step 3: Read the current CLAUDE.md section(s) that need updating
Step 4: Read the actual changed files to extract accurate details
Step 5: Draft precise edits (table rows, config entries, route entries)
Step 6: Present the diff to user for approval
Step 7: Apply edits to CLAUDE.md
Step 8: Re-read updated sections to verify internal consistency
```

### For Mode 2 (Quality Audit)

```
Step 1: Read CLAUDE.md top-to-bottom
Step 2: For each section, spot-check against actual code (read 2-3 referenced files)
Step 3: Score each of the 6 criteria with specific evidence
Step 4: Identify stale references (deleted files, renamed functions, wrong models)
Step 5: Identify missing documentation (new files not mentioned)
Step 6: Present scorecard + recommendations
Step 7: Apply approved changes
```

### For Mode 3 (Session Learning Capture)

```
Step 1: Review conversation history for moments of confusion or re-exploration
Step 2: Identify facts that were discovered mid-session but not in CLAUDE.md
Step 3: Draft one-liner additions (max 1-2 sentences each)
Step 4: Show diff before applying
Step 5: Apply approved additions
```

## Conciseness Rules

- CLAUDE.md is loaded into prompt -- every line costs tokens
- One-liners preferred over paragraphs
- Commands must be copy-paste ready
- No generic advice (only project-specific info)
- Remove stale references (deleted files, deprecated patterns)
- Tables over prose (scannable, dense)
- If a section exceeds 30 lines, consider splitting or condensing

## Quality Checks Before Completing

- [ ] No references to deleted files or deprecated functions
- [ ] All table entries match actual code (table names, function names, routes)
- [ ] No duplicate information across sections
- [ ] All commands are copy-paste ready (correct paths, correct syntax)
- [ ] Environment-specific details use Windows CMD syntax
- [ ] New additions follow existing formatting conventions

## Integration

- Called by: gaspol-execute (after all phases), gaspol-verify (after pass)
- Pairs with: gaspol-finish (CLAUDE.md must be synced before merge/PR)
- Standalone: user invokes any of the 3 modes directly
- Does NOT trigger: gaspol-verify (this skill is a leaf node in the chain)
