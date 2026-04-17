---
name: gaspol-design
description: "Use for frontend design tasks across planning, brainstorm, execute, verify, and learn phases. Power peer to ui-ux-pro-max v2.0 with own forked data (67+ styles, 161+ palettes, 57+ fonts, 25+ charts, 99+ UX guidelines, 161+ reasoning rules), project-context integration, KB cross-project pattern learning, anti-AI-slop enforcement, and multi-framework code generation."
---

# gaspol-design (Power Peer)

## Iron Law

```
NO UI OUTPUT WITHOUT PROJECT CONTEXT + KB QUERY + ANTI-AI-SLOP CHECK
```

Generic UI = AI slop. Real UI respects: project's existing design system (CLAUDE.md), past project patterns (KB), and explicit anti-slop rules. Every design output passes all three filters.

---

## Core Principle

Design intelligence should be self-sufficient (fork stable data) + project-aware (read CLAUDE.md tokens) + cross-project-learning (query KB) + enforceable (hard anti-slop rules). Each piece makes the output progressively better than generic AI output.

## When to Use

- **Brainstorm Phase 3 (auto-trigger)** — UI work detected via expanded keyword set or file extension
- **Brainstorm Phase 2.5 gate** — AskUserQuestion when UI detection ambiguous
- **Plan (new integration)** — per UI phase, produce design deliverable (tokens, layout, states, motion, a11y)
- **Execute (new integration)** — per UI phase, audit actual code vs design spec via `scripts/design_audit.py`
- **Verify Layer 4 (new integration)** — design system compliance sub-check
- **Learn (new integration)** — UI patterns auto-captured to `gaspol-knowledge/ui-patterns/` after gaspol-finish
- **Standalone** — user invokes `/gaspol-design` for pure design tasks

## When NOT to Use

- Pure backend/API work without UI surface
- Database schema design (not UI)
- Business logic without presentation layer
- Single-line CSS tweaks (over-engineered for trivial change)

---

## Capabilities (Power Peer to ui-ux-pro-max v2.0)

### Data (forked from ui-ux-pro-max v2.0, MIT — see NOTICE.md)

| Asset | Count | Location |
|---|---|---|
| UI Styles | 85+ | `data/styles.csv` |
| Color Palettes | via `data/colors.csv` | `data/colors.csv` |
| Font Pairings | 74+ | `data/typography.csv` |
| Chart Types | via `data/charts.csv` | `data/charts.csv` |
| UX Guidelines | 99+ | `data/ux-guidelines.csv` |
| Reasoning Rules | 162+ | `data/ui-reasoning.csv` |
| Product Patterns | via `data/products.csv` | `data/products.csv` |
| Landing Patterns | via `data/landing.csv` | `data/landing.csv` |
| Google Fonts | via `data/google-fonts.csv` | `data/google-fonts.csv` |
| Icons | via `data/icons.csv` | `data/icons.csv` |
| App Interface | via `data/app-interface.csv` | `data/app-interface.csv` |
| Stack-specific | via `data/stacks/` | `data/stacks/` |

### Scripts

| Script | Purpose |
|---|---|
| `scripts/search.py` | Core domain search (forked from v2.0) |
| `scripts/design_system.py` | Full design system generation (forked from v2.0) |
| `scripts/core.py` | Shared utilities (forked from v2.0) |
| `scripts/design_audit.py` | **NEW** — scan codebase for design compliance drift |

### Rules

| Rule File | Scope |
|---|---|
| `rules/anti-ai-slop.md` | Hard enforcement rules (banned defaults, required alternatives) |
| `rules/reasoning-gaspol.md` | Gaspol-specific rules (project context, KB integration, chain integration) |

### Integration Bridge

| File | Function |
|---|---|
| `integration/ui-ux-pro-max-bridge.py` | Optional delegation to ui-ux-pro-max v2.0 if installed (graceful fallback to own engine) |

### Templates

Multi-framework templates for code generation:
- `templates/base/` — base templates
- `templates/platforms/` — per-IDE platform configs + per-framework component templates

---

## Process Flow

### Step 1: Context Load (MANDATORY)

Per `rules/reasoning-gaspol.md` Rule G14 — never propose without context:

1. **Read target project CLAUDE.md** — extract design tokens, typography, color palette, layout conventions
2. **Detect stack** — from `package.json` or CLAUDE.md stack section
3. **Query KB** — `cd ~/.claude/gaspol-knowledge/ && git pull --quiet && grep -i "<domain>" INDEX.md`
4. **Check for precedent** — filter by status=accepted, surface to user via AskUserQuestion

### Step 2: Design Reasoning

Based on context + user request:

1. **Purpose** — What problem? Who's the audience?
2. **Aesthetic Direction** — Choose BOLD from `data/styles.csv` (avoid defaults per `rules/anti-ai-slop.md`)
3. **Constraints** — Framework (from stack), performance (from CLAUDE.md), accessibility (always), project design system (respect existing tokens)
4. **Differentiation** — What makes this UNFORGETTABLE within project constraints?

### Step 3: Invocation Strategy

```
Check: is ui-ux-pro-max v2.0 installed? (via integration/ui-ux-pro-max-bridge.py)

IF YES and task is "full design system generation":
  - Delegate to v2.0: `python3 bridge.py --design-system "<request>"`
  - Take v2.0 output, apply gaspol layers on top:
    - Constrain to CLAUDE.md tokens
    - Apply anti-AI-slop filter
    - Reconcile with KB precedent
  - Return unified recommendation

IF NO or task is domain-specific:
  - Use own engine:
    - `python3 scripts/search.py "<query>" --domain <domain>` for targeted
    - `python3 scripts/design_system.py "<request>"` for full system
  - Apply same gaspol layers

EITHER WAY:
  - Self-check against rules/anti-ai-slop.md before output
```

### Step 4: Output Format

Deliver structured design output:

```markdown
### Design for [Task/Component Name]

#### Aesthetic Direction
[Chosen style + reasoning — references data/styles.csv]

#### Color Palette
| Token | Hex | Usage |
|---|---|---|
| bg-base | #0B0E14 | App background |
| accent | #10B981 | Primary actions |
| ... | ... | ... |

(Either from CLAUDE.md existing tokens OR proposed new set with justification.)

#### Typography
| Role | Font | Source |
|---|---|---|
| Display | <font-name> | data/typography.csv |
| Body | <font-name> | data/typography.csv |

#### Layout Blueprint
[ASCII wireframe or Figma-equivalent spec]

#### Component States
- Default
- Hover
- Active
- Focus (keyboard)
- Loading
- Error
- Empty
- Disabled

#### Motion Plan
| Element | Animation | Duration | Easing |
|---|---|---|---|
| ... | ... | ... | ... |

#### Accessibility
- Semantic HTML tags used
- ARIA labels specified
- Keyboard navigation paths
- Focus management
- Color contrast ratios (WCAG AA minimum)

#### Code Template
[From templates/platforms/<detected-stack>/ — actual code, not pseudo-code]

#### Anti-AI-Slop Self-Check
- [x] No Inter/Roboto/Arial as primary
- [x] No purple gradient on white
- [x] Asymmetric or data-driven layout
- [x] Intentional motion (150-300ms)
- [x] Layered backgrounds
- [x] Icons from single library
- [x] Specific microcopy
- [x] CTA hierarchy clear
```

### Step 5: Chain Integration Outputs

Depending on caller skill, format output differently:

#### For gaspol-brainstorm Phase 3

Full design proposal in 200-300 word sections. After each section, AskUserQuestion confirm.

#### For gaspol-plan

Per-UI-phase Design Deliverable (condensed spec for plan table):

```markdown
Phase X Design Deliverable:
  Component: LoginForm
  Stack: React + TypeScript + Tailwind + shadcn/ui
  Tokens: #0B0E14 bg / #10B981 accent / Instrument Serif display / System UI body
  Layout: vertical stack, max-w-md, centered
  States: default | loading (spinner on button) | error (inline message below field) | success
  Motion: button press 150ms ease-out, error shake 200ms
  A11y: form role, aria-invalid on error, keyboard submit on Enter
  Template: templates/platforms/react-tsx/form-template.tsx
```

#### For gaspol-execute (fidelity check)

Run `scripts/design_audit.py <project-path>`. Report findings to checkpoint:

```markdown
Design Audit (Phase X):
  Hardcoded colors: 3 violations (src/LoginForm.tsx:12, 18, 24 — should use #10B981 token)
  Hardcoded fonts: 0
  Missing states: error state not implemented
  A11y gaps: aria-invalid missing on error, focus not trapped in modal
  Verdict: 🟡 PARTIAL COMPLIANCE (72/100)
```

Findings integrate with tiered auto-review.

#### For gaspol-verify Layer 4

Full design compliance sub-check across all UI files in changeset:

```markdown
Layer 4 — Design Compliance Sub-Check:
  [x] All UI components use design tokens (no hardcoded colors)
  [ ] Responsive breakpoints present in all layouts (2 files missing)
  [x] Semantic HTML used
  [x] ARIA labels on interactive elements
  [ ] Contrast ratios WCAG AA (1 violation: text #737373 on #0B0E14 fails for body size <14px)

Verdict: FAIL (2 issues blocking)
```

#### For gaspol-learn

After gaspol-finish CLEAN, invoke gaspol-learn. Candidate UI patterns:

```markdown
Candidate UI pattern from shipped feature:
  Type: ui-pattern
  Title: [auto-extracted from feature name]
  Location: <file:line-range>
  Tokens used: [list]
  Stack: [detected]
  Tags: [auto + user-edit]
  Source project: [current]

  Capture? [Yes / Yes with edits / No / Already captured]
```

---

## Anti-AI-Slop Enforcement

MUST run `rules/anti-ai-slop.md` Self-Check Before Output checklist before returning. Any violation → revise.

Enforcement integrates with:
- `gaspol-plan` design deliverable (checklist visible in plan)
- `gaspol-execute` fidelity check (audit script detects violations)
- `gaspol-verify` Layer 4 (compliance sub-check fails on violation)

---

## KB Cross-Project Learning

Before proposing any pattern, query `~/.claude/gaspol-knowledge/ui-patterns/`:

```bash
grep -i "<domain>|<stack>" INDEX.md
```

If precedent found (status=accepted):
1. Surface to user with age + source project
2. Options: [Apply] [Override with reason] [Skip — fresh]
3. If override → capture divergence ADR via gaspol-adr

After ship via gaspol-finish:
- gaspol-learn captures pattern (user confirms)
- Pattern saved to `ui-patterns/<slug>.md` with tags + source

---

## Red Flags

| Red Flag | Fix |
|---|---|
| Output without reading CLAUDE.md | Reject — mandatory context load |
| Generic Inter/Roboto recommendation | Reject — anti-AI-slop violation |
| Purple gradient on white | Reject — banned pattern |
| Ignoring KB precedent | Surface precedent, user decides |
| No anti-slop self-check | Reject — required before output |
| Code snippet in wrong stack | Reject — match project stack |
| Missing states (loading/error/empty) | Add to spec |
| No accessibility notes | Reject — always include a11y |
| Direct v2.0 delegation without gaspol layers | Reject — always apply project context on top |

---

## Integration Summary

| Skill | Interaction |
|---|---|
| `gaspol-brainstorm` Phase 2.5 | Design gate (AskUserQuestion if ambiguous UI detection) |
| `gaspol-brainstorm` Phase 3 | Auto-triggered for UI work (expanded triggers) |
| `gaspol-plan` | Per UI phase, produces Design Deliverable column content |
| `gaspol-execute` | Per UI phase, runs design_audit.py for fidelity check |
| `gaspol-verify` Layer 4 | Design compliance sub-check |
| `gaspol-learn` | UI patterns auto-captured after gaspol-finish |
| `gaspol-adr` | Divergences from KB precedent captured as ADR |
| `gaspol-research` | Research verdicts on design tools/libs |
| `gaspol-kb-audit` | UI patterns entries audited periodically |

---

## Verification Checklist

Before returning design output:

- [ ] Target project CLAUDE.md read
- [ ] Stack detected
- [ ] KB queried, precedent surfaced (if any)
- [ ] Aesthetic direction chosen with justification
- [ ] Color palette respects CLAUDE.md tokens
- [ ] Typography respects CLAUDE.md fonts
- [ ] Layout has intentional asymmetry or data-driven structure
- [ ] Component states (loading/error/empty) specified
- [ ] Motion plan with timing + easing
- [ ] Accessibility specified (semantic HTML, ARIA, keyboard, contrast)
- [ ] Code template matches detected stack
- [ ] Anti-AI-slop self-check all passed
- [ ] Output formatted appropriately for calling skill
