# Phase 1 to 2.5 detail

Moved verbatim from `SKILL.md`. Read it when the body sends you here.

## Phase 1: classification red flags

**Red flags (classification-dodging):**

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple to need a design" | Simple means a short design, not no design. |
| "I'll call it bounded and skip the spec" | Reaching for a label to dodge the spec IS the doubt — take the heavier path instead. |
| "I understand this kind of app so it's bounded" | Bounded measures the repo in front of you, not your familiarity with the pattern. |


## Phase 1.5: classification questions

Classification questions (internal — not asked to user):
1. Did Phase 0.5 surface any KB matches? (if yes → PRECEDENT candidate)
2. Does project CLAUDE.md document a similar pattern? (if yes → PRECEDENT candidate)
3. Is this a familiar domain? (image-gen, auth, dashboard — low novelty)
4. Is this a rapidly-evolving tech space? (AI tooling, edge runtime, new framework — high novelty, prefer research)

If PRECEDENT: briefly note "Using precedent from [source]" and proceed to Phase 2 fast.
If SEMI-NEW: do 2-3 `firecrawl_search` queries about industry current state, include findings in Phase 2.
If NEW: run the prior-art probe, report what it found (or that it found nothing), then AskUserQuestion "Deep research needed? (~20 min)" options: [Yes, research] / [Skip, use training memory — flag as potentially outdated] / [Ask more questions first].

## Phase 2: reference examples and source citation

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

## Phase 2.5: design lane notes

**Skipping Phase 3 is not skipping design.** Phase 3 is the *UI* design phase; the logic lane's
artifact is offered later, at plan stage, because it describes the flow the plan lays out.

**Phase 3 produces design DECISIONS as text** — palette, font pairing, layout blueprint, motion,
accessibility. It does not render the mockup file. That happens once, later, in `gaspol-plan`'s
post-plan offer, which mounts it as the artifact's Design tab. One render point, so the same
question cannot get three different answers.

## Phase 2.5: design triggers

Design triggers (Phase 3 fires if any match):

**UI keyword detection:**
- button, form, modal, card, view, screen, page, layout, dashboard, component, navbar, sidebar, menu, dropdown
- tampilan, halaman, tombol, kartu, bentuk (Indonesian)

**Visual indicator detection:**
- UX, style, color, warna, font, typography, animation, animasi, responsive, mobile, desktop, dark mode, light mode, theme, tema

**File extension detection (from approach/plan):**
- `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.module.css`, `.tailwind.config.*`

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
  - `ui-ux-pro-max` plugin skill (Phase 2.5/3 for UI work)
  - `gaspol-adr` (Phase 2 when user picks approach from 2+ options)
- **Reads from KB:** `<KB_ROOT>` via Phase 0.5 (ui-patterns, design-decisions, research, reusable-snippets)
- **Writes to KB:** via `gaspol-adr` (decisions) and `gaspol-research` (research verdicts)
- **Leads to:** `gaspol-plan` (after design approved — writes a separate `-plan.md` file, same ticket)
