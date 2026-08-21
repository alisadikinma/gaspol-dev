---
name: gaspol-sync-docs
description: "Use after implementing significant code changes to keep CLAUDE.md in sync with actual code. Also use standalone for quality audits or to capture session learnings."
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

---

## Code Index Lane — keep the HOW brain current (IDS-8)

Documentation is not only prose. Where a project maintains a code graph, that index is
documentation too, and it goes stale on exactly the branches this skill already runs on. This
skill owns "refresh what describes the code after the code changed", and `gaspol-finish` already
calls it at Step 5 — so this adds **no new gate**.

**Detection carries no configuration.** A `graphify-out/` directory at the project root **is** the
opt-in: somebody ran the indexer on purpose. gaspol never creates one.

| State | Condition | Behaviour |
|---|---|---|
| **updated** | `graphify-out/` present **and** `graphify` on `PATH` | Run `graphify update .`; record `graphify: updated` |
| **UNKNOWN** | `graphify-out/` present, `graphify` **not installed** | Record `graphify: UNKNOWN — index present, CLI missing` and **STOP and ask.** |
| **skipped** | no `graphify-out/` | Skip. **Not a failure** — the repo opted out. Record `graphify: skipped — no graphify-out/ (repo not indexed)`; never record it as passed. |
- **The command ran and REFUSED** — record `graphify: not updated — <the CLI's own reason>` and
  continue. Observed on this repo: *"new graph has 1792 nodes but existing graph.json has 2132.
  Refusing to overwrite … Pass --force to override."* This is a fourth state, found by running the
  lane rather than by reading it, and it is the one most easily mis-recorded: the CLI exists, the
  marker exists, the command exited — everything looks like a pass except the outcome. **Never
  pass `--force` to make the line look green.** A refusal protects an index that may be more
  complete than the one about to replace it; overriding it is the user's decision, so surface the
  message and let them make it.

```bash
if [ -d graphify-out ]; then
  if command -v graphify >/dev/null 2>&1; then
    graphify update .            # AST-only, no API cost — safe to run unattended
    echo "graphify: updated"
  else
    echo "graphify: UNKNOWN — index present, CLI missing"   # STOP and ask
  fi
else
  echo "graphify: skipped — no graphify-out/ (repo not indexed)"
fi
```

`graphify update` is AST-only and costs no API calls, which is why it can run unattended where a
model-driven step could not.

**Why UNKNOWN stops instead of skipping.** A marker directory proves the project *type*, never that
the tool is installed — the rule `detect-stack` already follows for build commands. A stale index
that reports clean is worse than an absent one, because a stale index still answers questions.

### The federated brain is offered, never taken

Refreshing the cross-project graph writes **outside** the current repository, into `~/.graphify/`:

```bash
graphify global add <project>/graphify-out/graph.json --as <tag>
```

That crosses a boundary `graphify update .` does not, so it is an **AskUserQuestion**, never
automatic — the same boundary `extract-design-tokens` respects when it prints a `DESIGN.md` instead
of writing one.

### On suggesting the tool when it is absent

`ui-ux-pro-max` gets a pointed suggestion when missing because this repo knows its exact install
command. **graphify does not get one, deliberately: this repo does not know how it is installed.**
A fabricated command is worse than silence — it looks authoritative and sends the reader nowhere.

Where a branch changed **code files** and no `graphify-out/` exists, one line is warranted, naming
what is missing and what it would buy — a queryable code graph instead of grep — and nothing more.
Do not repeat it within a session, and do not raise it on a docs-only branch: absence of an index
usually means the repo deliberately opted out, and nagging turns a useful note into noise.
