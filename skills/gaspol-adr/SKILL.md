---
name: gaspol-adr
description: "Use when an architectural decision is made during brainstorm Phase 2 approach selection, plan architectural fork, or when diverging from precedent. Auto-captures decision as MADR-formatted Architecture Decision Record to knowledge base with supersession support and divergence logging."
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
- Pure styling pick (use gaspol-design for design decisions, not ADR)

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

Query `~/.claude/gaspol-knowledge/design-decisions/` for similar decisions:
- Grep by tags extracted from context
- Grep by domain (auth, state-mgmt, image-gen, etc.)

If precedent found:
- Consistent with precedent → capture as **confirming** ADR (status: accepted, supersedes: null, referencing precedent)
- Inconsistent with precedent → capture as **divergence** ADR (see Step 4)

If no precedent, proceed as fresh ADR.

### Step 3: Generate MADR File

Write to `~/.claude/gaspol-knowledge/design-decisions/YYYY-MM-DD-<slug>.md`:

```markdown
---
id: ADR-YYYY-MM-DD-<slug>
title: <Concise decision title>
date: YYYY-MM-DD
status: accepted              # proposed | accepted | superseded | deprecated
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
- [Precedent: ../design-decisions/YYYY-MM-DD-<slug>.md] (if following precedent)
```

### Step 4: Divergence Handling

If user chose `[Override with reason]` at precedent surface (in `gaspol-brainstorm` Phase 0.5):

1. Prompt user for divergence reason (1-2 sentences)
2. Create divergence ADR at `design-decisions/divergence-YYYY-MM-DD-<slug>.md`
3. Frontmatter:
   ```yaml
   status: accepted
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

### Step 6: Update INDEX.md + Git

Add to `~/.claude/gaspol-knowledge/INDEX.md`:

```markdown
- title: <Title>
  path: design-decisions/YYYY-MM-DD-<slug>.md
  tags: [<tag1>, <tag2>]
  status: 🟢 accepted
  project: <project>
  date: YYYY-MM-DD
```

Commit + push to KB repo.

### Step 7: Return to Caller

Notify caller skill (brainstorm/plan) that ADR is captured with id. Caller can reference ADR in their output artifacts.

---

## Cross-Brainstorm Surfacing

`gaspol-brainstorm` Phase 0.5 queries `design-decisions/` for similar past decisions. When match found, presents to user:

```
Found relevant past decisions:
  • ADR-2026-03-15-zustand-state-mgmt (project: sparkfluence, tags: state-management)
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
| `gaspol-brainstorm` Phase 0.5 | Grep design-decisions/ for precedent |
| `gaspol-plan` | Captures architectural forks within phases |
| `gaspol-research` | Research verdicts feed into ADR "References" section |
| `gaspol-kb-audit` | Flags stale ADRs (accepted >180 days without validation) |
| `gaspol-learn` | ADRs as captured patterns in KB |

---

## Verification Checklist

Before commit:

- [ ] MADR frontmatter complete (id, status, tags, project, date)
- [ ] ≥2 options considered (or justified skip if single-option)
- [ ] Decision reasoning references project constraints
- [ ] Consequences section (positive + negative + neutral)
- [ ] Supersession/divergence links bidirectional (if applicable)
- [ ] INDEX.md updated with entry
- [ ] Git commit message descriptive
- [ ] Push to KB repo succeeded
