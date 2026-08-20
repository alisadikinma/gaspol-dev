# Anti-AI-Slop Hard Rules (gaspol)

> Relocated here from the deleted `gaspol-design` skill (IDS-2). Design *data* now comes
> from the `ui-ux-pro-max` plugin; this taste layer does not, because `ui-ux-pro-max`
> ships no anti-slop opinion at all. Apply these on top of whatever it returns.

These are NON-NEGOTIABLE enforcement rules. Apply to ALL design outputs. Override-able only with explicit project-specific justification documented in CLAUDE.md.

## Typography — NEVER Use as Primary

| Banned | Why | Use Instead |
|---|---|---|
| Inter | AI default, overused | Distinctive display (e.g., Instrument Serif, Fraunces, General Sans, Söhne, Neue Montreal) |
| Roboto | Google default, generic | Any font with personality (consult `data/typography.csv`) |
| Arial | System default, lazy | Any well-paired font system |
| -apple-system only | Not distinctive | Real font-family declaration with fallback |
| system-ui only | Not distinctive | Real font-family with character |

Exception: body text can use a refined sans (Söhne, Inter Tight) if paired with distinctive display for headings.

## Color — NEVER Use

| Banned | Why | Use Instead |
|---|---|---|
| Purple gradient on white (#7C3AED → #A78BFA) | Absolute AI giveaway | Sharp accent color with intentional contrast (consult `data/colors.csv` for curated palettes) |
| Random neon on dark | Cheap maximalism | Curated accent pair with hierarchy |
| Pure black (#000000) as primary bg | Harsh | Off-black (#0B0E14, #0F0F0F, #111111) |
| Pure white (#FFFFFF) with zero warmth | Sterile | Off-white with subtle warmth (#FAFAF9, #F8F7F4) |

Respect project design system from CLAUDE.md first. Only propose new palette if CLAUDE.md has none.

## Layout — NEVER Produce

| Banned | Why | Use Instead |
|---|---|---|
| Predictable symmetric 3-column card grid | Cookie-cutter | Asymmetric bento, masonry, or intentionally varied |
| Hero-features-CTA landing page template | Generic SaaS | Distinctive narrative structure per brand voice |
| Centered modal with 2-button footer | Default | Context-aware placement, single-CTA where possible |
| Sidebar-left + main-right only | No surprise | Consider sidebar-hidden, floating, or contextual |

Exception: dashboards + data tables legitimately need structured grids. Use when DATA requires it, not as default.

## Shadows — NEVER Use

| Banned | Why | Use Instead |
|---|---|---|
| Default Tailwind shadow on everything | Lazy | Intentional depth hierarchy, use sparingly |
| Drop shadow on text | Unreadable, dated | Color/weight contrast |
| Heavy blur shadow (>20px blur) | Bloat | Sharper, smaller shadows (2-8px blur) |

## Icons — NEVER Use

| Banned | Why | Use Instead |
|---|---|---|
| Emoji as functional icons (🚀 → "Fast") | Unprofessional | Lucide, Heroicons, Phosphor, or custom SVG |
| Inconsistent icon library mix | Disjointed | Single icon library per project |

## Animation — NEVER Apply

| Banned | Why | Use Instead |
|---|---|---|
| Bounce on every hover | Cartoonish | Subtle scale (0.95-1.05) or translate |
| Spin on loading everywhere | Overused | Varied states — skeleton, shimmer, pulse, fade |
| 500ms+ durations default | Sluggish | 150-300ms for most UI, 300-500ms only for significant transitions |
| Elastic easing on serious interfaces | Playful-wrong | ease-out, cubic-bezier with intent |

## Backgrounds — NEVER Use

| Banned | Why | Use Instead |
|---|---|---|
| Solid single color everywhere | Flat, boring | Layered: gradient + noise + subtle pattern |
| Stock gradient Tailwind classes | Default-y | Custom multi-stop gradient with brand colors |
| Hero video background by default | Bandwidth waste | Static hero, animate only on interaction |

## Microcopy — NEVER Write

| Banned | Why | Use Instead |
|---|---|---|
| "Get started" as primary CTA | Generic | Specific action ("Claim your account", "See it in action") |
| "Learn more" on every secondary | Vague | Specific ("Read the guide", "Watch the demo") |
| "Coming soon" without context | Meaningless | Specific ("Ships 2026-Q2", "Sign up for early access") |
| Every heading in Title Case | Corporate | Sentence case where appropriate (friendlier) |

## CTAs — NEVER Design

| Banned | Why | Use Instead |
|---|---|---|
| Two equally-weighted buttons side-by-side | Indecisive | Clear primary + secondary with visual hierarchy |
| "Submit" as button label | Robotic | Action verb matching intent ("Send", "Create", "Post") |

## Forms — NEVER Present

| Banned | Why | Use Instead |
|---|---|---|
| All fields visible on screen at once | Overwhelming | Progressive disclosure, group logically |
| Inline error validation with every keystroke | Annoying | Validate on blur or submit |
| Reset button next to Submit | Dangerous mis-click | Don't include reset; let user clear manually |

## Self-Check Before Output

Before any design recommendation is returned to the caller (brainstorm/plan/execute):

- [ ] No banned typography defaults
- [ ] No purple gradient on white
- [ ] Layout has intentional asymmetry or data-driven structure
- [ ] Shadows used sparingly with hierarchy
- [ ] Icons from single library (no emoji mix)
- [ ] Animation durations in 150-300ms range (exceptions justified)
- [ ] Backgrounds have layers (not flat)
- [ ] Microcopy is specific, not generic
- [ ] CTAs have clear hierarchy
- [ ] Form UX respects progressive disclosure

If any rule fails → revise before outputting.

## Override Mechanism

Override a rule ONLY if:
1. CLAUDE.md of target project explicitly documents the deviation with reasoning
2. Design decision captured as ADR via `gaspol-adr` (e.g., "chose Inter primary because rebrand matches corporate identity")
3. User acknowledges override in current session

Otherwise: rules are absolute.
