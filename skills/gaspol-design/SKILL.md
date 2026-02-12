---
name: gaspol-design
description: "Use for frontend design tasks - creating distinctive, production-grade interfaces. Combines data-driven design search, bold aesthetic philosophy, and project design system awareness. Auto-triggered by gaspol-brainstorm for UI work, or invoke standalone for pure design tasks."
---

## Overview

Create distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Combines three sources of design intelligence:

1. **Data-driven search** -- BM25 search across style, color, typography, UX, landing, product domains
2. **Bold aesthetic philosophy** -- anti-AI-slop rules, distinctive choices
3. **Project design system** -- reads CLAUDE.md for project-specific tokens and constraints

## When to Use

- **Standalone:** pure design tasks ("design a dashboard", "pick colors for this feature")
- **Auto-triggered:** by gaspol-brainstorm Phase 3 when UI work detected

## Design Thinking Process

1. **Purpose** -- What problem? Who's the audience?
2. **Aesthetic Direction** -- Choose BOLD direction (minimalism, maximalism, retro-futuristic, brutalist, etc.)
3. **Constraints** -- Framework, performance, accessibility, project design system
4. **Differentiation** -- What makes this UNFORGETTABLE?

## Design Search Integration

Run searches across relevant domains:

- `style` -- 140+ style categories (Minimalism, Glassmorphism, etc.)
- `color` -- Product-type specific palettes
- `typography` -- Font pairings with mood keywords
- `landing` -- Landing page patterns & conversion optimization
- `product` -- SaaS/e-commerce specific recommendations
- `ux` -- Usability & accessibility guidelines
- `chart` -- Data visualization best practices
- `icons` -- Icon library recommendations

Usage: `python design/search.py "<query>" --domain <domain>`

## Anti-AI-Slop Rules (CRITICAL)

### NEVER use:

- Generic fonts: Inter, Roboto, Arial, system-ui as primary
- Purple gradients on white backgrounds
- Predictable symmetric layouts
- Cookie-cutter card grids
- Default shadows without intentional depth hierarchy
- Emojis as icons (use lucide-react or similar)

### ALWAYS choose:

- Distinctive display fonts + refined body fonts
- Color palettes with sharp accent contrast
- Asymmetric or grid-breaking layouts when appropriate
- Intentional motion (CSS-only for HTML, Framer Motion for React)
- Layered backgrounds (gradients, noise, patterns)

## Project Design System Awareness

Read CLAUDE.md for:

- Color tokens (primary, accent, surface, text colors)
- Typography scale (headings, body, labels)
- Component patterns (card, button, input, badge styles)
- Animation library (Framer Motion vs CSS vs GSAP)
- Icon library preference
- Layout constraints (desktop-first, responsive breakpoints)
- Dark/light mode support

Constrain ALL designs to documented tokens. If CLAUDE.md has no design system, propose one.

## Output Format

For each design task, provide:

### 1. Aesthetic Direction

The chosen style + reasoning for why it fits the project and task.

### 2. Color Palette

Specific hex codes with usage mapping:

```
| Token     | Hex     | Usage                    |
|-----------|---------|--------------------------|
| bg-base   | #XXXXXX | App background           |
| surface   | #XXXXXX | Card/panel backgrounds   |
| accent    | #XXXXXX | Primary actions, highlights |
| text-pri  | #XXXXXX | Primary text             |
| text-sec  | #XXXXXX | Secondary text           |
```

### 3. Typography

Font pairing with sizes/weights:

```
Display:  <font-name> — headings, hero text
Body:     <font-name> — paragraphs, UI labels
Mono:     <font-name> — code, technical data
```

### 4. Component Examples

Code snippets using Tailwind/CSS matching the project's stack:

```tsx
// Card example
<div className="...">

// Button example
<button className="...">

// Input example
<input className="..." />
```

### 5. Layout Blueprint

Wire description or ASCII layout showing spatial relationships:

```
+--sidebar--+------main-content------+--panel--+
|            |                        |         |
|  nav       |  header                | details |
|  items     |  content area          | actions |
|            |                        |         |
+------------+------------------------+---------+
```

### 6. Motion Plan

Key animations with timing:

```
| Element       | Animation        | Duration | Easing          |
|---------------|------------------|----------|-----------------|
| Page enter    | fade + slide up  | 300ms    | ease-out        |
| Card hover    | scale + shadow   | 200ms    | ease-in-out     |
| Modal open    | backdrop + scale | 250ms    | spring(0.5)     |
```

## Variation Rule

No two designs should look the same. Avoid convergence on common choices. Each design should explore a different aesthetic space.

When designing multiple features for the same project:

- Maintain design system consistency (tokens, spacing, typography)
- Vary layout patterns (avoid repeating the same grid everywhere)
- Use different interaction patterns where appropriate
- Each feature should have a distinct spatial personality within the system

## Integration

- **Called by:** gaspol-brainstorm Phase 3 (auto-trigger for UI)
- **Standalone:** user invokes `/gaspol-design` directly
- **Feeds into:** gaspol-plan (design spec becomes plan input)
