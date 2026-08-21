# Gaspol-Specific Reasoning Rules

Extensions to the reasoning rules the `ui-ux-pro-max` plugin provides. These add project-context
awareness and KB integration that are **not present** in that plugin — which is why they survived
the deletion of `gaspol-design` in IDS-2 and live here instead.

## Project Context Rules

### Rule G1: Respect Existing Design Tokens

**IF** target project has `CLAUDE.md` with documented design system tokens
**THEN** the design output MUST use those exact tokens
**UNLESS** user explicitly requests new design system (captured as ADR)

Example:
- CLAUDE.md: `"accent: #10B981 (emerald)"`
- User: "design a new dashboard"
- Output MUST use #10B981 as accent, not invent new color

### Rule G2: Stack-Specific Templates

**IF** target project stack detected from CLAUDE.md or package.json
**THEN** the design output uses that specific stack
- React + TypeScript → `templates/platforms/react-tsx/`
- Vue 3 → `templates/platforms/vue/`
- Next.js App Router → `templates/platforms/next/`
- Laravel Blade → `templates/platforms/laravel-blade/`
- SwiftUI → `templates/platforms/swiftui/`
- Flutter → `templates/platforms/flutter/`
- HTML + Tailwind → `templates/platforms/html-tailwind/`
- shadcn/ui → `templates/platforms/shadcn-ui/`
- Astro → `templates/platforms/astro/`
- Svelte → `templates/platforms/svelte/`

Never output React code for a Vue project.

### Rule G3: Dark/Light Mode Parity

**IF** CLAUDE.md indicates dark mode support
**THEN** every color palette proposal must include both dark and light variants
**AND** both variants must pass WCAG AA contrast for text

### Rule G4: Performance Budget Awareness

**IF** CLAUDE.md documents bundle size or performance budget
**THEN** prefer:
- Tailwind over large CSS-in-JS libraries
- Lucide over full Material Icons
- CSS animations over Framer Motion for simple transitions
- Server components over client components (Next.js) where applicable

## KB Integration Rules

### Rule G5: Query KB Before Proposing

> **`<KB_ROOT>`** is the resolved knowledge-base root. Resolve it with `skills/_shared/kb-path.md` (`$GASPOL_KB_LOCAL` → `kb_local` in `~/.claude/gaspol-config.json` → default), and honour its three states — `available` / `none` / `UNKNOWN`. Never spell the default path here: doing so is why a correct setting still wrote to the old folder.

**BEFORE** proposing any UI pattern, query the store for notes tagged `ui-patterns`:

```bash
KB="$(skills/_shared/kb-root)" || exit 1   # unassigned $KB expands to /*.md — the filesystem root
grep -rilE "<domain>|ui-patterns" "$KB"/*.md   # flat notes; gaspol writes no index
# Read matched patterns
```

**IF** past pattern found:
- Surface to user via AskUserQuestion
- Options: [Apply precedent] [Override with reason] [Skip — fresh design]
- If override → capture divergence ADR via gaspol-adr

### Rule G6: Status-Aware Precedent Filtering

When querying KB, filter by `status`:
- `accepted` → apply as precedent (default)
- `proposed` → show with note "not yet validated in production"
- `superseded` → don't surface as primary precedent, note "superseded by <newer-id>"
- `deprecated` → don't surface at all

### Rule G7: Learn After Ship

After the design output ships via gaspol-finish, gaspol-learn captures the pattern to ``ui-patterns` tag with:
- Tags extracted from decision context
- Status: `proposed` (until validated in future project)
- Source: current project name + component path

## Anti-AI-Slop Integration

### Rule G8: Hard-Enforcement via Self-Check

Every design output must pass the Self-Check Before Output checklist in `rules/anti-ai-slop.md`. This is NOT optional — any violation requires revision before return.

### Rule G9: Override Requires ADR

Overriding anti-AI-slop rule requires:
1. CLAUDE.md deviation note OR
2. ADR captured via gaspol-adr OR
3. User acknowledgment in current session

Silent override = rejection.

## Chain Integration Rules

### Rule G10: Plan Deliverable Shape

When invoked by gaspol-plan for a UI phase, the design output is:

```markdown
### Design Deliverable for Phase [X]

**Component:** [ComponentName]
**Stack:** [detected from CLAUDE.md]
**Tokens Used:** [list from CLAUDE.md design system]
**Layout:** [ASCII wireframe or description]
**States:** default | loading | error | empty | success
**Interaction:** [hover/focus/active states]
**Motion:** [transitions with timing + easing]
**Accessibility:** [ARIA, keyboard nav, focus management]
**Anti-AI-Slop Self-Check:** [all checkboxes passed]
```

### Rule G11: Execute Fidelity Check

When invoked by gaspol-execute per UI phase:
1. Read actual implemented code
2. Run `scripts/design-audit.py` to detect:
   - Hardcoded colors (should use tokens)
   - Hardcoded fonts (should use design system)
   - Non-responsive layout (missing breakpoints)
   - Missing states (loading/error/empty not implemented)
   - Missing a11y (no ARIA, no keyboard support)
3. Report drift findings to execute checkpoint

### Rule G12: Verify Layer 4 Sub-Check

When invoked by gaspol-verify Layer 4:
- Design system compliance: all UI components use design tokens
- Responsive: layouts handle mobile + desktop per spec
- A11y: semantic HTML, ARIA labels, keyboard nav, contrast ratios

Pass/fail per file, aggregate verdict.

## Meta-Rules

### Rule G13: Fallback When Bridge Absent

**IF** ui-ux-pro-max v2.0 detected installed (`/c/Users/alisa/.claude/plugins/cache/ui-ux-pro-max-skill/...`)
**THEN** optional delegation to v2.0 `--design-system` flag available
**ELSE** use own engine (`scripts/design-system-gen.py`)

Neither path breaks; just capability differs.

### Rule G14: Never Propose Without Context

Never output design recommendations without having read:
1. Target project CLAUDE.md
2. Relevant KB entries in ui-patterns/ (if any)
3. Design system existing tokens

If any of these can't be read → AskUserQuestion to clarify before proceeding.

## Applied Precedence Order

When rules conflict:

1. Anti-AI-slop hard rules (absolute)
2. CLAUDE.md design system tokens (project-specific truth)
3. KB accepted precedent (cross-project consistency)
4. Base ui-reasoning rules (general best practices)
5. Fresh design judgment (fallback)

Higher-priority rules override lower-priority when in conflict.
