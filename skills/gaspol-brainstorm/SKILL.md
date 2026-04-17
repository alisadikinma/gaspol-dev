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

## Phase 1: Understanding the Idea

- Check project state (branch, recent commits)
- Ask questions ONE at a time using the **AskUserQuestion** tool (MANDATORY)
- EVERY clarifying question MUST use `AskUserQuestion` with selectable options — this shows an interactive popup modal for the user to pick from
- Format: provide a clear question text + 3-5 option strings (include "Something else" as last option for custom input)
- Only one question per message — wait for user's selection before asking the next
- Understand: what problem, who benefits, what exists already (from CLAUDE.md)
- NEVER ask questions as plain text output — always use the AskUserQuestion tool so the user gets the interactive selection UI

## Phase 2: Exploring Approaches

- Propose 2-3 approaches with trade-offs
- Lead with your recommendation
- Keep YAGNI -- ruthlessly cut unnecessary complexity
- Reference existing code from CLAUDE.md: "Per CLAUDE.md, we already have WorkspaceContext..."

## Phase 3: Design Intelligence (AUTO-TRIGGERED for UI work)

**Detection:** new pages, components, visual redesigns, layouts, dashboards, animations, themes --> trigger Phase 3

**Skip Phase 3 for:** backend/API logic, database schema, Edge Functions, business logic without UI

Steps:

1. Run design search (ui-ux-pro-max) for data-driven style/color/typography recommendations
2. Apply bold aesthetic choices -- NOT generic AI output (no Inter font, no purple gradients, no predictable layouts)
3. Constrain with project's design system from CLAUDE.md (if documented)
4. Present design recommendations with code examples

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

- **Triggered by:** gaspol-kickstart (when creative work detected)
- **Auto-triggers:** gaspol-design (for UI work, in Phase 3)
- **Leads to:** gaspol-plan (after design approved)
