---
name: gaspol-adr
description: "Use when an architectural decision is made during brainstorm Phase 2 approach selection, plan architectural fork, or when diverging from precedent."
---

# gaspol-adr

## Iron Law

```
NO ARCHITECTURAL FORK WITHOUT ADR CAPTURE
```

Decisions without ADR = amnesia. 6 months from now, "kenapa dulu pilih X?" has no answer. Every architectural choice with 2+ options considered MUST be captured.

---

## Core Principle

Architectural decisions live longer than memory. Consistency across projects requires precedent. Capture the *why* at decision-time — not after. Divergences from precedent are logged so future brainstorm sees the full decision history, not just the latest outcome.

## When to Use

- `gaspol-brainstorm` Phase 2 finished (user selected approach from 2-3 options)
- `gaspol-plan` encountered architectural fork within a phase (Option A vs Option B in implementation)
- User overrides precedent from KB (divergence logging required)
- Retroactive capture for decisions made without ADR (lower priority)

## When NOT to Use

- Trivial implementation choice (which variable name, formatting)
- Single-option obvious path (not really a "decision")
- Pure styling pick (use the ui-ux-pro-max skill for design decisions, not ADR)

---

## Process Flow

### Step 1: Receive Context from Calling Skill

Input:
- Context (what problem was being solved)
- Options considered (list of 2+ with brief pros/cons)
- Decision (chosen option)
- Reasoning (why chosen)
- Project context (which project, which domain)

### Step 2: Check KB for Precedent

Resolve KB mode first (see [docs/kb-setup.md](../../docs/kb-setup.md)): skip only on explicit `"kb_mode":"off"`; otherwise auto-init the local KB dir if missing and continue. **No GitHub config needed — local-only is the default.**

> **`<KB_ROOT>`** is the resolved knowledge-base root. Resolve it with `skills/_shared/kb-path.md` (`$GASPOL_KB_LOCAL` → `kb_local` in `~/.claude/gaspol-config.json` → default), and honour its three states — `available` / `none` / `UNKNOWN`. Never spell the default path here: doing so is why a correct setting still wrote to the old folder.

Query `<KB_ROOT>/` (flat quarantine notes) for similar decisions:
- Grep by tags extracted from context
- Grep by domain (auth, state-mgmt, image-gen, etc.)

If precedent found:
- Consistent with precedent → capture as **confirming** ADR (`status: proposed` — gaspol never writes `accepted`; the human gate promotes)
- Inconsistent with precedent → capture as **divergence** ADR (see Step 4)

If no precedent, proceed as fresh ADR.

### Step 3: Generate MADR File

Write to `<KB_ROOT>/YYYY-MM-DD-<slug>.md` — flat, no category directory. `status: proposed`, never `accepted`: promotion belongs to `superbrain-promote`, not to the skill that wrote the note. The frontmatter + `# Title` + `tags: [...]` shape is what the promoter's scan reads.

```markdown
---
id: ADR-YYYY-MM-DD-<slug>
title: <Concise decision title>
date: YYYY-MM-DD
status: proposed              # ALWAYS proposed from gaspol. Only the human gate
                              # (superbrain-promote) may set accepted/superseded/deprecated.
project: <project-name>
domain: <domain-tag>
tags: [<tag1>, <tag2>, ...]
supersedes: null              # or ADR-id
superseded_by: null           # or ADR-id
related: []                   # other ADR ids
---

# <Title>

## Context
<Why the decision needed to be made. Constraints, stakeholders, prior state.>

## Options Considered

### Option A: <name>
- Pros: ...
- Cons: ...
- Sources (if research-backed): [link](URL)

### Option B: <name>
- Pros: ...
- Cons: ...

### Option C: <name> (if applicable)
...

## Decision

**Chosen: Option [X]**

<Why this option fits. Reference project constraints from CLAUDE.md. Reference research cache if applicable.>

## Consequences

### Positive
- ...

### Negative
- ...

### Neutral
- ...

## Follow-up

<Future work enabled or required by this decision. Links to issues/tickets.>

## References

- [Research cache: ../research/<slug>.md] (if research informed this)
- [Precedent: the flat note tagged `design-decisions` this one follows] (if following precedent)
```

### Step 4: Divergence Handling

If user chose `[Override with reason]` at precedent surface (in `gaspol-brainstorm` Phase 0.5):

1. Prompt user for divergence reason (1-2 sentences)
2. Create the divergence ADR as a flat quarantine note: `<KB_ROOT>/YYYY-MM-DD-divergence-<slug>.md`, tagged `design-decisions` (no category directory — Phase C abolished them)
3. Frontmatter:
   ```yaml
   status: proposed
   supersedes: null                     # old precedent NOT superseded (both coexist)
   diverges_from: <precedent-ADR-id>    # NEW field: explicit divergence marker
   divergence_reason: "<1-2 sentence reason>"
   ```
4. Old precedent ADR is NOT superseded — both remain `accepted`. Future brainstorm surfaces BOTH with context tags distinguishing them.

### Step 5: Supersession Handling

If new ADR conflicts with existing accepted ADR on same tag/domain (not divergence — actual replacement):

1. AskUserQuestion: "New decision conflicts with ADR-YYYY-MM-DD-<old>. Supersede (mark old as superseded)?" options: [Yes supersede] / [Divergence instead] / [Keep both]
2. If supersede:
   - Old ADR: update `status: superseded`, `superseded_by: <new-id>`
   - New ADR: `supersedes: <old-id>`
3. Commit with clear message: `adr: supersede <old-id> with <new-id> — <reason>`

### Step 6: Commit (no INDEX.md)

**gaspol writes no index.** An index inside a quarantine folder is a non-note where the promoter
scans notes, and one gaspol must keep in sync is a drift source with no reader. The flat note
carries `status`, `date`, `source`, `# Title` and `tags: [...]`, so a grep over the notes answers
what the index used to.


Commit locally (always), push only in synced mode — see [docs/kb-setup.md](../../docs/kb-setup.md):

**Ownership guard (IDS-8):** before these git commands run, compare `$KB` against
`git -C "$KB" rev-parse --show-toplevel`. A mismatch means the store is a guest inside a repo
gaspol **does not own** — a vault, a monorepo — so the write-side git operations are refused with
`kb-sync: skipped — KB lives inside a repo gaspol does not own (<toplevel>)` and reads continue.
Full snippet and rationale: `skills/_shared/kb-path.md`.

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it the resolver would be taken from whatever repo happens to be open, and its stdout becomes the path gaspol commits}"
KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root" --init)"; rc=$?
# --init: state 4 (nothing configured, fresh machine) CREATES the default store
# and returns 0, so a first-run capture has somewhere to go. State 3 is untouched
# and still stops: an empty store reads as "no precedent exists", which is exactly
# when a documented mistake gets repeated.
case $rc in
  0) : ;;
  3) echo "knowledge-store: UNKNOWN — configured path unreadable"; exit 1 ;;
  *) echo "kb-root: unexpected exit $rc — see skills/_shared/kb-path.md"; exit 1 ;;
esac
# Never continue with an empty $KB: git -C "" is a silent wrong answer.
[ -n "$KB" ] || exit 1
REMOTE="${GASPOL_KB_REMOTE:-$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/gaspol-config.json"))).get("kb_remote",""))' 2>/dev/null)}"
NOTE="$KB/$(date +%F)-<slug>.md"        # the file this ADR just wrote
TOP="$(git -C "$KB" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" != "$(cd "$KB" && pwd -P)" ]; then
  echo "kb-sync: skipped — KB lives inside a repo gaspol does not own ($TOP)"
else
  # PATHSPEC, never `add .` — see skills/_shared/kb-path.md (IDS-8, /security-review)
  git -C "$KB" add -- "$NOTE" && git -C "$KB" commit -q -m "adr: <id> — <title>" -- "$NOTE" || true
  [ -n "$REMOTE" ] && git -C "$KB" push --quiet || true   # synced mode only; no error if local-only
fi
```

### Step 7: Return to Caller

Notify caller skill (brainstorm/plan) that ADR is captured with id. Caller can reference ADR in their output artifacts.

---

## Cross-Brainstorm Surfacing

`gaspol-brainstorm` Phase 0.5 greps the flat notes for the `design-decisions` tag. When match found, presents to user:

```
Found relevant past decisions:
  • ADR-2026-03-15-zustand-state-mgmt (project: <project>, tags: state-management)
    Verdict: chose Zustand over Redux for small apps
  • ADR-2026-01-08-react-query-vs-swr (project: portfolio-v2, tags: data-fetching)
    Verdict: chose React Query for SSR support

[Apply precedent]  [Override with reason]  [Skip — fresh decision]
```

---

## Red Flags

| Red Flag | Fix |
|---|---|
| Single-option "decision" captured as ADR | Not a real fork — skip ADR |
| Missing "Options Considered" section | Incomplete; capture alternatives even if rejected |
| No reasoning for chosen option | Incomplete; add why this fits |
| Supersession without reasoning | Reject — add explicit `reason` in commit message |
| Fake divergence (actually same decision, different wording) | Reject — canonicalize to same ADR |
| Missing tags | Auto-reject — grep precedent-surfacing breaks without tags |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-brainstorm` Phase 2 | Auto-invoked when approach selected from 2+ options |
| `gaspol-brainstorm` Phase 0.5 | Grep the notes for the `design-decisions` tag |
| `gaspol-plan` | Captures architectural forks within phases |
| `gaspol-research` | Research verdicts feed into ADR "References" section |
| the store's own promoter (outside gaspol) | Promotes and retires ADRs; gaspol writes `proposed` and records `last_validated`, it does not police staleness |

---

## Verification Checklist

Before commit:

- [ ] MADR frontmatter complete (id, status, tags, project, date)
- [ ] ≥2 options considered (or justified skip if single-option)
- [ ] Decision reasoning references project constraints
- [ ] Consequences section (positive + negative + neutral)
- [ ] Supersession/divergence links bidirectional (if applicable)
- [ ] No index written — the flat note carries its own frontmatter and tags
- [ ] Git commit message descriptive
- [ ] Push to KB repo succeeded
