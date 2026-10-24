---
name: gaspol-brainstorm
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior."
---

## Overview

Help turn ideas into fully formed, implementation-ready designs through collaborative dialogue. CLAUDE.md-first approach eliminates redundant codebase exploration.

## Announce at Start

> "I'm using the gaspol-brainstorm skill to explore this idea."

## HARD-GATE (MANDATORY -- applies to EVERY request)

```
Do NOT invoke any implementation skill (gaspol-plan, gaspol-execute, gaspol-tdd,
gaspol-parallel), write any code, or scaffold anything until a design has been
presented AND the user has approved it.
```

This applies to **every** project regardless of perceived simplicity. "This is too
simple to need a design" is exactly where unexamined assumptions cause the most wasted
work — a config toggle, a one-line util, a rename all go through this. The design can be
short (a few sentences for a truly trivial change), but you MUST present it and get
approval before any implementation action. The ONLY terminal state of this skill is
invoking `gaspol-plan` after the design is approved (architectural path) or the user's
explicit go-ahead on the in-chat design (spike/bounded paths — see Phase 1's Three Paths
classification). The gate never weakens across paths: only the WEIGHT of the artifact
you present scales down (spec file → short in-chat design → probe plan), never whether
approval is required before you touch code.

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
3. **Read the second brain, if one is configured** (IDS-8). Where the knowledge store resolves
   inside a personal vault, that vault holds the *why* — decisions, project state, identity — that
   no codebase records. Read in this order and **stop as soon as you have enough**; progressive
   disclosure is the point, and reading a whole vault every brainstorm is precisely the token cost
   this phase exists to avoid:
   `INDEX.md` (master map) → `hot.md` (what changed lately) → `10-Identity/` (identity, voice and
   positioning work only) → `20-Projects/<name>/README.md` (the project at hand) →
   `30-Knowledge/` (cross-project standards).
   **No vault configured is not a failure.** Say so, name `kb_local` in
   `~/.claude/gaspol-config.json`, and continue — the same soft-reference the plugin already applies
   to `ui-ux-pro-max`. Never hardcode a vault path here: this plugin is public and agnostic, and the
   store's location is resolved, never assumed.
4. ONLY THEN explore codebase for details NOT covered in CLAUDE.md
5. Reference CLAUDE.md sections in proposals

Saves 10-50k tokens per brainstorm session.

## Phase 0.5: Precedent Query (architectural AND bounded — AFTER CLAUDE.md, before questions)

```
BEFORE asking clarifying questions, query the knowledge store for precedent.
Runs on the ARCHITECTURAL and BOUNDED paths. Only "kb_mode": "off" disables it.
```

**Why bounded now runs it too (IDS-8).** This phase used to be architectural-only. Bounded fixes are
the majority of day-to-day work and are exactly where a documented gotcha gets re-hit — the
mechanism behind "we solved this already and did it wrong again". A grep over an index-free set of
notes is cheap; re-making a recorded mistake is not.

**Spike stays exempt**, deliberately. A feasibility probe answers a question and keeps no code, so
there is no precedent to apply to it. Widening this gate to *every* path would be a different,
unrequested change.

> **`<KB_ROOT>`** is the resolved knowledge-base root. Resolve it with `skills/_shared/kb-path.md` (`$GASPOL_KB_LOCAL` → `kb_local` in `~/.claude/gaspol-config.json` → default), and honour its three states — `available` / `none` / `UNKNOWN`. Never spell the default path here: doing so is why a correct setting still wrote to the old folder.

0. **Resolve the store** via `skills/_shared/kb-path.md`. `"kb_mode":"off"` → skip silently. Otherwise honour the three states: `available` → proceed; `none` → record `knowledge-store: none — not configured`, say what a store would give them, **continue** (not a failure — a public plugin cannot require one); `UNKNOWN` → **STOP and ask**, never treat an unreadable store as an empty one.
   **Create the directory only, never `git init`.** The store may live inside a repository gaspol does not own — a vault, a monorepo — and initialising a repo inside someone else's is the write-side hazard the ownership guard exists to prevent (`skills/_shared/kb-path.md`).
1. **Pull latest KB (synced mode only)** — if a remote is configured (`kb_remote` / `$GASPOL_KB_REMOTE`): `git -C <KB_ROOT> pull --quiet` (skip gracefully if offline). In local-only mode there is no remote to pull — skip straight to the grep.
2. **Extract tags from user intent** — domain keywords (auth, image-gen, dashboard, state-mgmt, etc.)
3. **Grep the notes** — `KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")" || exit 1` then `grep -rilE "<tag1>|<tag2>" "$KB"/*.md`. Assign `$KB` first: unassigned it expands to `/*.md`, scanning the filesystem root. There is no index: gaspol writes flat notes carrying their own `# Title` and `tags: [...]`, and an index nothing writes is worse than none.
4. **Filter by status** — show `proposed` **and** `accepted`. `proposed` is not a lesser tier here: gaspol writes `proposed` exclusively (promotion belongs to the human gate), so filtering it out would hide every capture from the query built to find it. Mark the tier when surfacing so the user can weigh a promoted note above a pending one.
5. **Freshness check** — for research/ entries, check age tier (🟢 FRESH / 🟡 AMBER / 🟠 STALE / 🔴 EXPIRED)
6. **Surface to user via AskUserQuestion** (if matches found):

```
Found relevant past work:
  • [image-generation-ui](ui-patterns/image-generation-ui.md)
    Tags: [image-gen, gallery, 3-pane]
    Source: <project> 2026-03 — 🟢 accepted
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

### Batch Gate (BLOCKING — before classifying, before any question)

```
A request carrying MORE THAN ONE item is ONE ticket by default.
Splitting needs a reason from the closed list. The ceiling is two.
```

Full rule, thresholds, and Red Flags: `skills/_shared/batch-gate.md`. Read it whenever a
request carries more than one item; do not restate its numbers here.

State the ruling out loud before anything else — *"Five items, one ticket: same subsystem"* —
then classify that ONE piece of work through the Three Paths below. Every item becomes its own
phase of the one plan, ordered by severity, each keeping its own regression test.

If the rule says split, say which reason applies. If you want a third ticket, you do not get
one: ask via **AskUserQuestion**.

### Three Paths: Classify Before Asking

```
Classify every request into one of three paths BEFORE asking any clarifying question,
and state the classification to the user.
```

- **Spike** — a feasibility question ("can we...", "is it possible...") whose output is
  an answer, not code to keep. No spec file. Present the question plus a 2-3 sentence
  probe plan, get a nod, investigate cheaply, report a recommendation.
- **Bounded** — a well-scoped change to code that ALREADY EXISTS in the repo (a flag, a
  small endpoint, a one-file fix). "Bounded" measures whether the flow being touched
  already exists to read — if there's no existing flow to point at, it isn't bounded.
  Ask the clarifying questions that matter, present a SHORT design IN CHAT (a few
  sentences to a short paragraph — architecture, files touched, testing approach), then
  STOP and wait for explicit approval. No spec file, no implementation plan document.
  Phase 0.5 (KB query), Phase 1.5 (novelty assessment), and Phase 2.5/3 (design gate /
  design-skill invocation) do NOT run for this path.
- **Architectural** — new subsystems, interface changes other code depends on, or
  anything that doesn't cleanly fit spike/bounded. Full EXISTING pipeline, unchanged:
  Phase 0.5 through Phase 6 all run as they do today, including the spec-file write.

**One-way ratchet:** hidden complexity discovered mid-task upgrades the path (spike →
bounded, bounded → architectural) — stop, say so, and step up. Nothing ever downgrades
mid-task; once a heavier path is warranted you don't talk yourself back down.

**Red flags (classification-dodging):**

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple to need a design" | Simple means a short design, not no design. |
| "I'll call it bounded and skip the spec" | Reaching for a label to dodge the spec IS the doubt — take the heavier path instead. |
| "I understand this kind of app so it's bounded" | Bounded measures the repo in front of you, not your familiarity with the pattern. |

The HARD-GATE above applies to **all three paths** without exception — it scales in
artifact weight (spec file / short in-chat design / probe plan), never in whether
approval is required before implementation.

- Check project state (branch, recent commits)
- **Decompose gate (AFTER the Batch Gate, BEFORE refining details):** this gate is for a
  request that is genuinely several *projects* — "build a platform with chat, file storage,
  billing, and analytics" — never for a request that is several *items of one job*. The Batch
  Gate above has already ruled on that, and its ruling stands: a list of defects in one
  subsystem reaches this gate as ONE piece of work and passes straight through.
  When it really is multi-project: flag it immediately — do NOT spend clarifying questions on a
  project that must be decomposed first. Help the user split it into sub-projects: what are the
  independent pieces, how do they relate, what build order? Then brainstorm the FIRST
  sub-project through the normal flow. Each sub-project gets its own spec → plan → implement
  cycle.
- Ask questions ONE at a time using the **AskUserQuestion** tool (MANDATORY)
- EVERY clarifying question MUST use `AskUserQuestion` with selectable options — this shows an interactive popup modal for the user to pick from
- Format: provide a clear question text + 3-5 option strings (include "Something else" as last option for custom input)
- Only one question per message — wait for user's selection before asking the next
- Understand: what problem, who benefits, what exists already (from CLAUDE.md + KB from Phase 0.5)
- NEVER ask questions as plain text output — always use the AskUserQuestion tool so the user gets the interactive selection UI

## Phase 1.5: Novelty Assessment (architectural path only — before proposing approaches)

```
Classify task novelty to decide research level:

  PRECEDENT: KB hit (Phase 0.5 surfaced match) AND project CLAUDE.md has similar pattern
    → Skip research, use precedent as baseline for approaches

  SEMI-NEW: KB hit but no project pattern, OR project pattern but no KB validation
    → Light research (2-3 `firecrawl_search` queries, ~5 min) to verify industry current state
    → Inline in Phase 2

  NEW: No KB hit AND no project pattern
    → Prior-art probe FIRST (cheap, ~30s): `npx skills find "<domain> <task>"`
      (skills.sh). No precedent anywhere in-house is exactly when somebody
      else's packaged, battle-tested skill is the better answer than a design
      you invent. NEVER auto-install what it returns — the install rules live
      in `skills/_shared/prior-art-gate.md` and apply here unchanged.
    → Then invoke gaspol-research skill (deep research, ~20 min, cached to KB)
    → Wait for research output before Phase 2
```

Classification questions (internal — not asked to user):
1. Did Phase 0.5 surface any KB matches? (if yes → PRECEDENT candidate)
2. Does project CLAUDE.md document a similar pattern? (if yes → PRECEDENT candidate)
3. Is this a familiar domain? (image-gen, auth, dashboard — low novelty)
4. Is this a rapidly-evolving tech space? (AI tooling, edge runtime, new framework — high novelty, prefer research)

If PRECEDENT: briefly note "Using precedent from [source]" and proceed to Phase 2 fast.
If SEMI-NEW: do 2-3 `firecrawl_search` queries about industry current state, include findings in Phase 2.
If NEW: run the prior-art probe, report what it found (or that it found nothing), then AskUserQuestion "Deep research needed? (~20 min)" options: [Yes, research] / [Skip, use training memory — flag as potentially outdated] / [Ask more questions first].

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

## Phase 2.5: Design Gate (architectural path only — which design lane, never whether)

```
This gate routes; it decides WHICH design lane, not whether one exists.
gaspol-plan then OFFERS the artifact once the plan is written — declining is
allowed and writes its reason to the ledger.

If Phase 3 design triggers fire from Phase 1 intent keywords OR file extension hints OR approach involves UI:
  → Phase 3 auto-triggers (UI lane: ui-ux-pro-max)

If Phase 3 triggers are AMBIGUOUS (mixed signals — some UI, some backend):
  → AskUserQuestion explicitly:
     "Apakah task ini butuh design UI/UX intelligence?"
     [Yes, include design phase]                    → UI lane
     [No UI — logic design artifact at plan stage]  → logic lane
     [Minimal UI, tokens only]                      → UI lane, tokens scope only

If clearly non-UI (pure backend/API/DB/business logic):
  → Skip Phase 3 and proceed to Phase 4 — the LOGIC lane, not "no design".
    gaspol-plan will OFFER the logic design artifact
    (`skills/gaspol-plan/logic-design-artifact.md`) once the plan is written.
    It is an offer, not a gate: declining writes the reason to the ledger.
```

**Skipping Phase 3 is not skipping design.** Phase 3 is the *UI* design phase; the logic lane's
artifact is offered later, at plan stage, because it describes the flow the plan lays out.

**Phase 3 produces design DECISIONS as text** — palette, font pairing, layout blueprint, motion,
accessibility. It does not render the mockup file. That happens once, later, in `gaspol-plan`'s
post-plan offer, which mounts it as the artifact's Design tab. One render point, so the same
question cannot get three different answers.

Design triggers (Phase 3 fires if any match):

**UI keyword detection:**
- button, form, modal, card, view, screen, page, layout, dashboard, component, navbar, sidebar, menu, dropdown
- tampilan, halaman, tombol, kartu, bentuk (Indonesian)

**Visual indicator detection:**
- UX, style, color, warna, font, typography, animation, animasi, responsive, mobile, desktop, dark mode, light mode, theme, tema

**File extension detection (from approach/plan):**
- `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.module.css`, `.tailwind.config.*`

## Phase 3: Design Intelligence (AUTO-TRIGGERED for UI work)

**Detection:** Phase 2.5 gate determined UI work needed → invoke the **`ui-ux-pro-max`** skill.

Design intelligence is delegated to the `ui-ux-pro-max` plugin (84 styles, 192 palettes, 74 font pairings, 98 UX guidelines, 25 chart types across 22 stacks). gaspol no longer forks that data.

**If it is not installed:** tell the user to run `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`, then continue the brainstorm without it — design quality degrades, nothing breaks. gaspol declares **no** hard dependency on it, deliberately: `plugin.json`'s `dependencies` field is all-or-nothing, and a yanked third-party entry would disable every other gaspol skill.

**Two gaspol-specific layers survive the delegation** and still apply on top of whatever `ui-ux-pro-max` returns — `ui-ux-pro-max` has no equivalent for either:
- `skills/gaspol-verify/rules/anti-ai-slop.md` — banned-vs-use-instead tables for typography, colour, layout, motion
- `skills/gaspol-verify/rules/reasoning-gaspol.md` — respect the target project's CLAUDE.md tokens, query the KB for precedent

**Skip Phase 3 for:** backend/API logic, database schema, Edge Functions, business logic without UI (determined by Phase 2.5 gate).

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

Offer it with **AskUserQuestion**: `[Write DESIGN.md]` / `[Not now — keep the gate off]` /
`[I'll write it myself]`. Never write
it without asking, and never write it before the palette is approved — a contract frozen around
a design the user has not agreed to is worse than none.

### Visual Companion (just-in-time — v1.7)

A browser-based companion for showing mockups, diagrams, and visual options during
brainstorming/design. It is a **tool, not a mode** — see
[visual-companion.md](visual-companion.md) for the full guide.

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

## Phase 6: Documentation (Spec File)

- (architectural path only) Mint this feature's ticket before writing the file. **once per batch** — the Batch Gate in Phase 1 already decided how many tickets exist, and this step
  never re-opens that. Five reported items that batched into one ticket call `next-ticket`
  exactly once:
  1. Run `skills/gaspol-execute/scripts/next-ticket <path to the target project's CLAUDE.md>`.
  2. **Exit 0** — stdout is the new ticket id (e.g. `IND-85`). Use it below.
  3. **Exit 2** — no `## gaspol Ticket Counter` section exists yet. Use **AskUserQuestion**
     to ask the user for a ticket prefix (no default guess). With the answer `<PREFIX>`,
     append this section to the project's CLAUDE.md:
     ```markdown
     ## gaspol Ticket Counter

     Prefix: <PREFIX>
     Last ticket: <PREFIX>-1
     ```
     Use `<PREFIX>-1` as this feature's ticket.
  Spike/bounded paths stop at in-chat approval and skip ticket-minting and this file write
  entirely — see Phase 1's Three Paths classification.
- Write to `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md`, where `YYYY-MM-DD` is
  today's date (the day this file is created, not the day the ticket was minted) — the
  `-spec.md` suffix marks this as brainstorm output, distinct from the `-plan.md` file
  `gaspol-plan` writes next. Date + `<TICKET>` + suffix make the file self-identifying at a
  glance: when it was written, which ticket, which stage.
- File starts with a `**Ticket:** <TICKET>` line, then the `## Design` section (from this
  brainstorm).
- `gaspol-plan` reads this file's `**Ticket:**` field and reuses it — it writes a SEPARATE
  `<TICKET>-<kebab-topic>-plan.md` file; it does not append to this one.
- **Builder check (before handing off):** the author cannot see the holes in its own spec, so a
  fresh reader looks for them. Once the spec file is written, dispatch ONE `general-purpose`
  subagent with `model: "opus"` written at the call site (`model-tier: judge`). Its prompt is
  `references/builder-check-prompt.md`; give it only the spec path and the target project's
  domain, no conversation context. The reply is either ranked questions plus one-line
  "looks unnecessary" parts, or exactly `nothing important left`. Answer what the spec or
  CLAUDE.md already answers and fix the spec inline. Decide minor points yourself and mark them
  as your own decisions. Bring questions that change what gets built to the owner in ONE
  `AskUserQuestion`. Run **one round** only: no re-dispatch loop (`skills/_shared/fix-loop.md`).
  This runs on the architectural path only, because only that path writes a spec. The cost:
  this is model judgement, not a guarantee.
- **User reviews the written spec:** ask the user to read the spec file before proceeding
  ("I've written the design to `<path>` — take a look before we plan"). Revise on requested
  changes; only proceed to gaspol-plan once they approve the written spec.
- Ask: "Ready to set up for implementation?"
- If yes --> use gaspol-plan to create the implementation plan (separate `-plan.md` file,
  same ticket)

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
