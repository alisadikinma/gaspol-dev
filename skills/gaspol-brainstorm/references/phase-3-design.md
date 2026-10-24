# Phase 3 detail: design intelligence

Moved verbatim from `SKILL.md`. Read it when the body sends you here.

## Ui-ux-pro-max layers and invocation

Design intelligence is delegated to the `ui-ux-pro-max` plugin (84 styles, 192 palettes, 74 font pairings, 98 UX guidelines, 25 chart types across 22 stacks). gaspol no longer forks that data.


**Two gaspol-specific layers survive the delegation** and still apply on top of whatever `ui-ux-pro-max` returns — `ui-ux-pro-max` has no equivalent for either:
- `skills/gaspol-verify/rules/anti-ai-slop.md` — banned-vs-use-instead tables for typography, colour, layout, motion
- `skills/gaspol-verify/rules/reasoning-gaspol.md` — respect the target project's CLAUDE.md tokens, query the KB for precedent


Invocation:

```
Invoke ui-ux-pro-max with:
  - Task description (from Phase 1-2 understanding)
  - Project CLAUDE.md path
  - Stack (detected from package.json or CLAUDE.md)
  - User constraints (from Phase 1 questions)
```

Expected back:
1. Aesthetic direction (with sources from its style database)
2. Color palette (respecting CLAUDE.md tokens)
3. Typography (from its font-pairing database or CLAUDE.md)
4. Component examples (code in detected stack)
5. Layout blueprint (ASCII or spec)
6. Motion plan
7. Accessibility notes
8. Anti-AI-slop self-check confirmed

Present design recommendations 200-300 word sections, AskUserQuestion confirm after each.

## DESIGN.md freeze

### Freeze the approved palette into DESIGN.md (v1.17)

Once the user has **approved** the palette and typography, offer to write them to `DESIGN.md`
at the project root. This is the point where the design is agreed and no code exists yet — the
cheapest possible moment to fix the contract. **One** reason implementations drift from the
mockup is that the palette never got written down anywhere a tool could read.

**Scope boundary:** this pins TOKENS — colour and typography — not layout geometry. The
wrong-layout half of mockup drift is not addressed by a DESIGN.md and stays open (IDS-6's
deferred Part B). Do not present a DESIGN.md as solving mockup mismatch.

Format — YAML frontmatter, then whatever prose you want below it:

```markdown
---
colors:
  primary: "#2563EB"
  text:    "#1F2937"
  surface: "#FFFFFF"
fonts:
  heading: "Poppins"
  body:    "Inter"
---
```

Name at least one foreground token (`text`, `ink`, `body`, `foreground`) and one background
token (`surface`, `background`, `canvas`) — that pairing is what lets `gaspol-verify` grade
WCAG AA contrast instead of reporting `no declared pairing`.

`gaspol-verify` Layer 4 reads this file and blocks on off-contract structural colours. Format
origin: Google Stitch DESIGN.md; 73 worked examples at
<https://github.com/voltagent/awesome-design-md> — **referenced, never vendored** (see the
v1.14 fork deletion).


## Visual companion

### Visual Companion (just-in-time — v1.7)

A browser-based companion for showing mockups, diagrams, and visual options during
brainstorming/design. It is a **tool, not a mode** — see
[visual-companion.md](../visual-companion.md) for the full guide.

- **Offer just-in-time, NEVER upfront.** Wait until a question would genuinely be clearer
  *shown* than *told* — a real mockup/layout/diagram question, not merely a UI topic. The
  first time that happens, offer it as **its own message** (nothing else): "This next part
  might be easier if I show you — I can put mockups/diagrams in a browser tab as we go. It's
  token-intensive. Want me to?" If no visual question ever arises, never offer it.
- **On approval:** start the server with
  `skills/gaspol-brainstorm/visual-companion/scripts/start-server.sh --project-dir <repo> --open`
  (it backgrounds itself, writes session files under `.gaspol/brainstorm/`, and returns a JSON
  line with the keyed URL — always share the COMPLETE URL incl. `?key=…`). Add `.gaspol/` to
  `.gitignore` if absent.
- **Per-question decision** (even after acceptance): use the browser only when the content IS
  visual (mockups, wireframes, layout/style comparisons, diagrams); use the terminal for
  conceptual/tradeoff/requirements questions. "A UI topic" ≠ "a visual question".
- **Design fusion:** feed `ui-ux-pro-max`'s output (aesthetic direction, palette,
  layout blueprint, 162+ rules) into the mockup HTML you write to the screen dir — gaspol has
  both the design *knowledge* and the interactive *loop*.
