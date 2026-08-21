---
name: gaspol-learn
description: "Use when feature implementation ships successfully (auto-triggered from gaspol-finish after verification chain passes)."
---

# gaspol-learn

## Iron Law

```
NO CAPTURE WITHOUT QUALITY GATE + USER CONFIRMATION
```

Junk captures pollute KB. Every entry must pass content/tag/duplicate/source validation AND get explicit user confirmation before commit. Rejected captures logged to `.rejected-log` for audit but not added to INDEX.

---

## Core Principle

Shipped features contain patterns worth reusing — but only if captured cleanly. Auto-capture after `gaspol-finish` extracts candidate patterns, user confirms which are genuinely reusable (vs project-specific quirks). Quality gate prevents the KB from becoming a "notes dump".

## When to Use

- Auto-triggered by `gaspol-finish` after verification chain returns CLEAN
- Manual invocation: `/gaspol-learn` to capture pattern outside normal flow (retroactive learning)

## When NOT to Use

- Implementation incomplete (gaspol-verify not passed)
- Pattern is trivial (1-line fix, rename, obvious code)
- Pattern is project-specific (tightly coupled to single project's quirks — not reusable)
- User indicates no reusable patterns in this feature

---

## Process Flow

### Step 1: Analyze Shipped Feature

Input: branch/commits that just shipped (base SHA + HEAD SHA).

Sub-agent dispatch (model: sonnet) analyzes diff + final code for:
- UI patterns (new component patterns, layout approaches, interaction flows)
- Architecture patterns (hook compositions, context usage, data flow)
- Code snippets (reusable utilities, hooks, helpers)
- Design decisions already captured via gaspol-adr (reference, don't duplicate)

Output: candidate list (1-3 patterns max).

### Step 2: User Confirmation (MANDATORY per candidate)

For EACH candidate, use `AskUserQuestion`:

```
Candidate pattern detected:
  Type: UI pattern
  Title: Image generation 3-pane layout
  Location: src/pages/ImageGen.tsx:12-89
  Reusable because: prompt + preview + history common in AI generation UIs
  Proposed tags: [image-gen, gallery, 3-pane, ai-generation]

Capture to KB?
  [Yes, capture as proposed]
  [Yes, but edit title/tags/description]
  [No, project-specific quirk]
  [No, already captured elsewhere]
```

Without user confirm, no capture. Silent skip.

### Step 3: Quality Gate Validation

Before writing to KB, validate:

| Check | Rule | Action if fail |
|---|---|---|
| Min content | Body ≥200 words describing pattern | Reject, prompt user to expand |
| Tag validation | ≥2 tags from allowed taxonomy | Reject, prompt to add tags |
| Duplicate detection | `grep -ril "<key phrase>" "$KB"/*.md` over the flat notes' `# Title` and `tags:` lines (>80% overlap) | Surface duplicate, ask merge/keep-separate |
| Not CLAUDE.md restate | Content must go beyond what's already in project CLAUDE.md | Reject if pure restate |
| Source citation (research type) | ≥2 URLs if entry type is `research` | Reject, demand sources |
| Body structure | Has sections: Context, Pattern, When to Use, Example, Variations | Reject if bare dump |

> **`<KB_ROOT>`** is the resolved knowledge-base root. Resolve it with `skills/_shared/kb-path.md` (`$GASPOL_KB_LOCAL` → `kb_local` in `~/.claude/gaspol-config.json` → default), and honour its three states — `available` / `none` / `UNKNOWN`. Never spell the default path here: doing so is why a correct setting still wrote to the old folder.

Failed quality gate → log to `<KB_ROOT>/.rejected-log`:

```
[2026-04-17 14:32] Rejected: "Image generation 3-pane layout"
  Reason: body only 89 words, tags insufficient
  Path: d:/Projects/sparkfluence/src/pages/ImageGen.tsx
  User can reconsider — view: .rejected-log
```

### Step 4: Category Routing

Determine target directory:

| Pattern Type | Target |
|---|---|
| UI component layout, interaction pattern | tag `ui-patterns` |
| System-level architecture (auth, data flow, state) | tag `architecture` |
| Reusable code snippet (hook, utility, helper) | tag `reusable-snippets` |
| (ADRs go via gaspol-adr, not gaspol-learn) | tag `design-decisions` |
| (Research goes via gaspol-research, not gaspol-learn) | tag `research` |

### Step 5: Write the quarantine note

**One flat file. No category directories.** File: `<KB_ROOT>/YYYY-MM-DD-<slug>.md`

gaspol does not own a knowledge store any more — it feeds the quarantine that
`superbrain-promote` (or the equivalent human gate) reads. That promoter's scan keys on
**frontmatter + H1**, so the shape below is a contract, not a style. A note in a different shape is
silently skipped: it looks captured and is unreachable, which is worse than not capturing it.

```markdown
---
status: proposed
date: YYYY-MM-DD
source: gaspol-learn (<project> <TICKET>)
---

# <Title>
tags: [<category>, <tag1>, <tag2>]

<body>
```

**`status` is always `proposed`, and never `accepted`.** Promotion belongs to the human gate. A
skill that grades its own capture as accepted has removed the gate it was told to feed — the same
reason `plan-verifier` is a separate agent rather than a self-assessment.

The old category directories (`ui-patterns/`, `architecture/`, `reusable-snippets/`) survive as the
**first tag**, not as folders. Routing a note to its final home is the promoter's job and it already
has a routing table; a second routing scheme in gaspol is exactly the duplication this ticket
removes.

**gaspol writes no index.** Writing one into a quarantine folder puts a non-note where the
promoter scans notes, and an index gaspol has to keep in sync is a drift source with no reader —
the flat notes carry their own frontmatter and tags, so a grep over them answers the same question.


## Context
<Original problem this pattern solved.>

## Pattern
<Description of the reusable pattern itself — decoupled from source project specifics.>

## When to Use
<Conditions where this pattern fits future projects.>

## When NOT to Use
<Anti-patterns or contexts where this doesn't fit.>

## Example (from source)
<Code snippet or layout reference — anonymized if needed.>

## Variations
<Variations considered, alternatives that would also work.>

## Related
<Links to other KB entries, ADRs, research.>
```

### Step 6: (removed — no index)

The index step is gone. gaspol writes flat quarantine notes that carry their own `status`, `date`,
`source`, `# Title` and `tags: [...]`, so the question an index answered is answered by grepping the
notes. An index that gaspol maintains but no promoter reads is a second source of truth that can
only drift — and it would put a non-note into the folder the promoter scans.

### Step 7: Commit (+ Push if synced)

See [docs/kb-setup.md](../../docs/kb-setup.md) for mode resolution. Auto-init the local KB dir if missing. **Always commit locally; push only in synced mode.**

**Ownership guard (IDS-8):** before these git commands run, compare `$KB` against
`git -C "$KB" rev-parse --show-toplevel`. A mismatch means the store is a guest inside a repo
gaspol **does not own** — a vault, a monorepo — so the write-side git operations are refused with
`kb-sync: skipped — KB lives inside a repo gaspol does not own (<toplevel>)` and reads continue.
Full snippet and rationale: `skills/_shared/kb-path.md`.

```bash
KB="$(skills/_shared/kb-root)" || {   # 0=available 3=UNKNOWN(STOP+ask) 4=none(report+continue)
  # Never continue with an empty $KB: git -C "" is a silent wrong answer.
  echo "see skills/_shared/kb-path.md for the three states"; return 2>/dev/null || exit 1; }
git -C "$KB" add . && git -C "$KB" commit -q -m "learn: capture <pattern> from <project>" || true
# push ONLY if a remote is configured (kb_remote / $GASPOL_KB_REMOTE):
[ -n "$REMOTE" ] && git -C "$KB" push --quiet || true
```

In **local-only mode** (default) there is no remote — the local commit IS the capture. No push, no offline queue, no error. In **synced mode**, if push fails (offline) queue in `.pending-push` for retry next session.

---

## Quality Gate — Capture Rejection Log

Path: `<KB_ROOT>/.rejected-log`

Contents: chronological rejected captures with reasons. NOT indexed, NOT committed to git (user can gitignore or not).

Purpose: allow user to reconsider rejected captures later without losing proposal context.

---

## Anti-Pollution Measures

1. **User confirmation mandatory** per candidate — no bulk auto-capture
2. **Max 3 candidates per feature** — prevents noise flood
3. **Quality gate with 6 checks** — reject junk before it enters KB
4. **Status: proposed by default** — user promotes to `accepted` via gaspol-kb-audit after validation in future project
5. **Duplicate detection before write** — prevents near-duplicates
6. **Source location anchored** — every entry points to source code, traceable

---

## Red Flags

| Red Flag | Fix |
|---|---|
| Auto-capture without user confirm | Reject — always prompt |
| >3 candidates from single feature | Prune — pick best 3, log rest to .rejected-log |
| Tags missing or generic ("code", "ui") | Reject — demand specific tags |
| Body <200 words | Reject — demand expansion |
| Pattern description IS the code (no abstraction) | Reject — pattern needs decoupling from source |
| Skipping capture entirely because "no KB configured" | Wrong — KB is local-only by default. Auto-init the dir and capture locally. Only skip on explicit `kb_mode: off` |
| Fail-loud on missing remote in local-only mode | A missing remote is the expected default — commit locally, no error. Fail loud only if a *configured* push fails in synced mode |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-finish` | Auto-triggers gaspol-learn after CLEAN verification |
| `gaspol-adr` | Architectural decisions captured separately (not by learn) |
| `gaspol-research` | Research entries captured separately (by research skill) |
| `gaspol-kb-audit` | Validates proposed entries for promotion to accepted |
| `gaspol-brainstorm` Phase 0.5 | Queries captured patterns for future reuse |

---

## Verification Checklist

Before commit:

- [ ] User confirmed capture (AskUserQuestion response = yes)
- [ ] All 6 quality gate checks passed
- [ ] File written to correct category directory
- [ ] Frontmatter complete (id, title, tags, status, source_project, source_location)
- [ ] Body has all 6 sections (Context, Pattern, When to Use, When NOT, Example, Variations)
- [ ] No index written — the flat note carries its own frontmatter and tags
- [ ] Git committed + pushed
- [ ] Status = `proposed` (not `accepted`) until validated in future project
