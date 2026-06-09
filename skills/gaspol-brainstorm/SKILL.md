---
name: gaspol-brainstorm
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Reads CLAUDE.md first, explores user intent through collaborative dialogue, auto-triggers design intelligence for UI work, and produces implementation-ready specifications with Data Integration Maps."
---

## Overview

Help turn ideas into fully formed, implementation-ready designs through collaborative dialogue. CLAUDE.md-first approach eliminates redundant codebase exploration.

## Announce at Start

> "I'm using the gaspol-brainstorm skill to explore this idea."

## Phase 0: CLAUDE.md-First (MANDATORY -- before ANY codebase exploration)

```
BEFORE exploring codebase, ALWAYS read CLAUDE.md first.
```

1. READ CLAUDE.md completely
2. EXTRACT relevant context:
   - Existing routes/components (do we already have something similar?)
   - Data sources (what hooks/APIs/edge functions exist?)
   - Design system tokens (colors, patterns, component styles)
   - Known gotchas (from Debugging Checklist)
3. ONLY THEN explore codebase for details NOT covered in CLAUDE.md
4. Reference CLAUDE.md sections in proposals

Saves 10-50k tokens per brainstorm session.

## Phase 0.5: KB Cross-Project Query (AFTER CLAUDE.md, before questions — local-only by default)

```
BEFORE asking clarifying questions, query cross-project KB for precedent.
KB works out of the box (local-only). It only disables on explicit "kb_mode": "off".
```

0. **Resolve KB mode** (see [docs/kb-setup.md](../../docs/kb-setup.md)): `off` (config has `"kb_mode":"off"`) → skip Phase 0.5 silently. Otherwise auto-init the local KB if missing (mkdir structure + `git init`) and proceed — no config needed.
1. **Pull latest KB (synced mode only)** — if a remote is configured (`kb_remote` / `$GASPOL_KB_REMOTE`): `git -C ~/.claude/gaspol-knowledge pull --quiet` (skip gracefully if offline). In local-only mode there is no remote to pull — skip straight to the grep.
2. **Extract tags from user intent** — domain keywords (auth, image-gen, dashboard, state-mgmt, etc.)
3. **Grep INDEX.md** — `grep -i "<tag1>|<tag2>" INDEX.md`
4. **Filter by status** — default show only `status: accepted` entries; optionally include `proposed`
5. **Freshness check** — for research/ entries, check age tier (🟢 FRESH / 🟡 AMBER / 🟠 STALE / 🔴 EXPIRED)
6. **Surface to user via AskUserQuestion** (if matches found):

```
Found relevant past work:
  • [image-generation-ui](ui-patterns/image-generation-ui.md)
    Tags: [image-gen, gallery, 3-pane]
    Source: sparkfluence 2026-03 — 🟢 accepted
    Hook: 3-pane layout (prompt + preview + history) works best

  • [ADR-2026-02-10: state-mgmt-zustand](design-decisions/...)
    Tags: [state-management, react]
    🟢 accepted, last_validated: 2026-03-15

[Apply precedent — use as reference]
[Override with reason — capture divergence ADR]
[Skip precedent — start fresh]
```

If user chooses "Override with reason":
- Prompt for 1-2 sentence reason
- Call `gaspol-adr` to capture divergence ADR with `diverges_from: <precedent-id>`
- Old precedent NOT superseded — both coexist

If user chooses "Skip precedent":
- Proceed without applying past patterns
- No ADR captured

If no KB matches, proceed silently to Phase 1.

Saves additional 10-30k tokens per session by avoiding re-exploration of solved problems.

## Phase 1: Understanding the Idea

## Phase 1: Understanding the Idea

- Check project state (branch, recent commits)
- Ask questions ONE at a time using the **AskUserQuestion** tool (MANDATORY)
- EVERY clarifying question MUST use `AskUserQuestion` with selectable options — this shows an interactive popup modal for the user to pick from
- Format: provide a clear question text + 3-5 option strings (include "Something else" as last option for custom input)
- Only one question per message — wait for user's selection before asking the next
- Understand: what problem, who benefits, what exists already (from CLAUDE.md + KB from Phase 0.5)
- NEVER ask questions as plain text output — always use the AskUserQuestion tool so the user gets the interactive selection UI

## Phase 1.5: Novelty Assessment (before proposing approaches)

```
Classify task novelty to decide research level:

  PRECEDENT: KB hit (Phase 0.5 surfaced match) AND project CLAUDE.md has similar pattern
    → Skip research, use precedent as baseline for approaches

  SEMI-NEW: KB hit but no project pattern, OR project pattern but no KB validation
    → Light research (2-3 WebSearch queries, ~5 min) to verify industry current state
    → Inline in Phase 2

  NEW: No KB hit AND no project pattern
    → Invoke gaspol-research skill (deep research, ~20 min, cached to KB)
    → Wait for research output before Phase 2
```

Classification questions (internal — not asked to user):
1. Did Phase 0.5 surface any KB matches? (if yes → PRECEDENT candidate)
2. Does project CLAUDE.md document a similar pattern? (if yes → PRECEDENT candidate)
3. Is this a familiar domain? (image-gen, auth, dashboard — low novelty)
4. Is this a rapidly-evolving tech space? (AI tooling, edge runtime, new framework — high novelty, prefer research)

If PRECEDENT: briefly note "Using precedent from [source]" and proceed to Phase 2 fast.
If SEMI-NEW: do 2-3 WebSearch queries about industry current state, include findings in Phase 2.
If NEW: AskUserQuestion "Deep research needed? (~20 min)" options: [Yes, research] / [Skip, use training memory — flag as potentially outdated] / [Ask more questions first].

## Phase 2: Exploring Approaches

- Propose 2-3 approaches with trade-offs
- Lead with your recommendation
- Keep YAGNI -- ruthlessly cut unnecessary complexity
- Reference existing code from CLAUDE.md: "Per CLAUDE.md, we already have WorkspaceContext..."
- Reference research cache: "Per research/zustand-vs-redux.md (🟢 FRESH 32d), Zustand recommended for apps <10k LoC..."
- Reference KB precedent: "Per [precedent ADR-2026-02-10], project uses Zustand..."

**Source citation MANDATORY** per approach (when research done):
```markdown
### Approach A: Use Zustand

Sources:
- Official docs: https://zustand.docs.pmnd.rs (fetched YYYY-MM-DD)
- Real-world: https://github.com/pmndrs/zustand (23k stars, maintained)
- Research cache: ../research/<slug>.md (verdict: prefer-zustand-for-small-apps)

Fit for this project:
- [Reference CLAUDE.md constraint]
- [Reference project stack]

Trade-offs:
- Grounded in research, not generic
```

## Phase 2.5: Design Gate (if UI work detected)

```
If Phase 3 design triggers fire from Phase 1 intent keywords OR file extension hints OR approach involves UI:
  → Phase 3 auto-triggers (proceed)

If Phase 3 triggers are AMBIGUOUS (mixed signals — some UI, some backend):
  → AskUserQuestion explicitly:
     "Apakah task ini butuh design UI/UX intelligence?"
     [Yes, include design phase]
     [No, pure backend/logic]
     [Minimal UI, no design needed]

If clearly non-UI (pure backend/API/DB/business logic):
  → Skip Phase 3, proceed to Phase 4
```

Design triggers (Phase 3 fires if any match):

**UI keyword detection:**
- button, form, modal, card, view, screen, page, layout, dashboard, component, navbar, sidebar, menu, dropdown
- tampilan, halaman, tombol, kartu, bentuk (Indonesian)

**Visual indicator detection:**
- UX, style, color, warna, font, typography, animation, animasi, responsive, mobile, desktop, dark mode, light mode, theme, tema

**File extension detection (from approach/plan):**
- `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.module.css`, `.tailwind.config.*`

## Phase 3: Design Intelligence (AUTO-TRIGGERED for UI work)

**Detection:** Phase 2.5 gate determined UI work needed → invoke `gaspol-design` skill.

`gaspol-design` is now a power peer (Phase 6.2 of v1.2 spec) — self-sufficient with forked data (67+ styles, 161+ palettes, 57+ fonts, 25+ charts, 162+ reasoning rules, 99+ UX guidelines), integrated across plan/execute/verify/learn chain.

**Skip Phase 3 for:** backend/API logic, database schema, Edge Functions, business logic without UI (determined by Phase 2.5 gate).

Invocation:

```
Invoke gaspol-design with:
  - Task description (from Phase 1-2 understanding)
  - Project CLAUDE.md path
  - Stack (detected from package.json or CLAUDE.md)
  - User constraints (from Phase 1 questions)
```

gaspol-design returns:
1. Aesthetic direction (with sources from data/styles.csv)
2. Color palette (respecting CLAUDE.md tokens)
3. Typography (from data/typography.csv or CLAUDE.md)
4. Component examples (code in detected stack)
5. Layout blueprint (ASCII or spec)
6. Motion plan
7. Accessibility notes
8. Anti-AI-slop self-check confirmed

Present design recommendations 200-300 word sections, AskUserQuestion confirm after each.

## Phase 4: Implementation Feasibility Check (NEW)

Before finalizing:

- Can this be built with REAL data from existing backend?
- What hooks/APIs/edge functions are needed?
- Are there existing patterns to reuse? (from CLAUDE.md)
- Flag anything that would require placeholder implementation

## Phase 5: Presenting the Design

- Present in 200-300 word sections
- After each section, use **AskUserQuestion** tool to confirm: provide options like "Looks good, continue", "Needs changes (I'll explain)", "Skip this section", "Start over"
- Cover: architecture, components, data flow, error handling
- Include Data Integration Map:

```
## Data Integration Map

| Component | Data Source | Existing? | Notes |
|-----------|-----------|-----------|-------|
```

## Phase 6: Documentation (Hybrid File)

- Write to `docs/plans/YYYY-MM-DD-<topic>.md` (NO `-design` suffix — hybrid file)
- Structure: start with `## Design` section (from this brainstorm)
- `gaspol-plan` will APPEND `## Implementation Plan` section to the same file later
- Ask: "Ready to set up for implementation?"
- If yes --> use gaspol-plan to create implementation plan (appends to this file)

## Key Principles

- One question at a time — ALWAYS via **AskUserQuestion** tool (popup modal, not plain text)
- Multiple choice with selectable options (3-5 options, always include "Something else")
- YAGNI ruthlessly
- CLAUDE.md-first (saves tokens)
- Data-driven aesthetics for UI (use design search)
- Anti-generic (no AI slop)
- Project-constrained (respect documented design system)
- Implementation feasibility (flag placeholders early)

## Integration

- **Triggered by:** User message indicating creative work (replaces old kickstart — skill removed in v1.2)
- **Auto-triggers:** 
  - `gaspol-research` (Phase 1.5 when novelty = NEW)
  - `gaspol-design` (Phase 2.5/3 for UI work)
  - `gaspol-adr` (Phase 2 when user picks approach from 2+ options)
- **Reads from KB:** `gaspol-knowledge/` via Phase 0.5 (ui-patterns, design-decisions, research, reusable-snippets)
- **Writes to KB:** via `gaspol-adr` (decisions) and (after gaspol-finish) `gaspol-learn` (patterns)
- **Leads to:** `gaspol-plan` (after design approved — appends to same file per hybrid file structure)
