---
title: Gaspol Plugin Improvements — Design Spec
date: 2026-04-17
owner: Ali Sadikin Ma
status: design-approved
source: brainstorm session via gaspol-brainstorm
target_plugin_version: 1.2.0
current_plugin_version: 1.1.0
next_step: gaspol-plan (append ## Implementation Plan section to this same file)
---

# Gaspol Plugin Improvements

## Context

Review plugin gaspol-dev v1.1.0 berdasarkan 5 pain point teridentifikasi user selama penggunaan real. Brainstorm session menghasilkan keputusan desain untuk tiap pain point dengan trade-off eksplisit. Spec ini jadi input untuk `gaspol-plan` yang akan append `## Implementation Plan` ke file yang sama (per keputusan Poin 1 — hybrid file structure).

## Referensi

- Plugin sumber: `d:\Projects\claude-plugin\gaspol-dev\`
- Existing architecture reference: `CLAUDE.md` (root plugin)
- Inspirasi eksternal: `obra/superpowers` (14 skills, overlap besar dengan gaspol, unggul di autonomous execution + multi-IDE)
- Personal infrastructure terkait (out-of-scope untuk plugin ini tapi sinergi): MASTER-PLAN-AI-BRAIN.md (standalone personal project)

## Decisions Summary

| # | Pain Point | Decision | Rationale |
|---|---|---|---|
| 1 | File design.md dan plan.md terpisah | **Hybrid single file**, split kalau >500 lines atau butuh stakeholder approval mid-way | Kurangi artifact orphan, satu source of truth, tetap allow split untuk large features |
| 2 | Review cuma di akhir execute | **Tiered auto review** per-phase kalau threshold terpenuhi | Catch bug dini tanpa token waste di phase trivial |
| 3 | Semua task pakai Opus → mahal | **Auto-rubric by task type** — Opus orchestrator, Sonnet impl/review, Haiku docs/rename | Hemat cost, match model ke kompleksitas actual |
| 4 | Knowledge hilang antar project | **File-based KB di GitHub private repo** — `alisadikinma/gaspol-knowledge` | Zero infra baru, version history free, git sync cross-device, backend-abstract untuk future upgrade |
| 5 | Plugin butuh lebih powerful | **3 skill baru**: `gaspol-research`, `gaspol-auto`, `gaspol-adr` | Isi gap vs superpowers + synergi penuh dengan Poin 4 KB |
| 6 | 6 skill jarang fire (kickstart/design/tdd/dispatch/worktree/write-skill) | **REMOVE kickstart** (fold ke brainstorm Phase 0), **DEVELOP design** (power peer ui-ux-pro-max v2.0 via hybrid fork + optional delegate, wired ke gaspol-plan/execute/verify), **HARD GATE tdd**, **MERGE dispatch→parallel**, **REMOVE worktree** (tidak realistis dipakai), keep write-skill. **Net: 16 → 13 skills.** | YAGNI untuk skill unused, INVEST di skill berkapabilitas tinggi (design) supaya power peer dengan ui-ux-pro-max + integrated across chain |
| 7 | Brainstorm kasih ide generic, tidak grounded di industry current state | **Tiered auto research** via Phase 1.5 Novelty Assessment — precedent/semi-new/new decision tree | Balance: tidak boros token di familiar domain, tidak generic di new domain |
| 8 | Implementation miss step karena no final review | **Mandatory step-level closure gate** — upgrade plan-verifier ke evidence-based, hard-gate di gaspol-execute end + gaspol-finish pre-chain | Blocking gate beats optional warning |
| 9 | Research output hilang antar session, tidak ada freshness tracking | **Research Cache Lifecycle** — TTL 180 hari default, freshness tier (fresh/amber/stale/expired), progressive refresh | Data stale auto-detected, re-research targeted not wholesale |
| 10 | KB accumulating jadi pollution (stale entries, bias precedent reinforcement, tidak ada self-maintenance) | **KB Lifecycle & Self-Maintenance** — status lifecycle all entries, `gaspol-kb-audit` skill, capture quality gate, anti-precedent mechanism | Plugin truly compounding (self-curating), bukan cuma akumulasi sampah |
| 11 | CLAUDE.md outdated post-refactor + README.md tidak convincing untuk adoption | **CLAUDE.md comprehensive update + README.md overhaul** — hero value prop, problem/solution framing, feature tour dengan real examples, comparison vs superpowers, quickstart, architecture diagram, roadmap | Plugin ready untuk shared/public adoption — documentation jadi growth lever |

## Detailed Design

### 1. Hybrid File Structure

**Current behavior:** `gaspol-brainstorm` → `YYYY-MM-DD-<topic>-design.md`. Lalu `gaspol-plan` → `YYYY-MM-DD-<topic>-implementation-plan.md`. Dua file terpisah.

**New behavior:** `gaspol-brainstorm` → `YYYY-MM-DD-<topic>.md` dengan section `## Design`. `gaspol-plan` **APPEND** section `## Implementation Plan` ke file yang sama.

**Split condition:** Hanya kalau salah satu dari:
- File size >500 lines setelah plan di-append
- User explicitly request split via option (`--split` flag atau modal choice)
- Design approved terpisah oleh stakeholder sebelum plan dimulai (eg. client sign-off UI mockup)

**Split format kalau dipicu:**
```
docs/plans/YYYY-MM-DD-<topic>-design.md
docs/plans/YYYY-MM-DD-<topic>-plan.md
```

**Perubahan skill:**
- `skills/gaspol-brainstorm/SKILL.md` Phase 6: write filename tanpa `-design` suffix
- `skills/gaspol-plan/SKILL.md`: cek apakah file `YYYY-MM-DD-<topic>.md` sudah ada → append; kalau tidak ada, create baru
- Add utility function `get_plan_file_path(topic, date)` dengan logic deteksi existing file
- Update referensi di CLAUDE.md tabel "Plans saved to" lokasi

### 2. Tiered Auto Review

**Threshold untuk trigger auto-review (any one triggers):**
- `files_changed > 3`
- `lines_of_code_changed > 100`
- Phase description contains keyword indicating new business logic: `implement`, `create`, `add feature`, `new component`, `introduce`, `build`

**Skip conditions (any one skips):**
- Docs-only: semua file yang diubah berupa `*.md`, `README*`, `CLAUDE.md`
- Config-only: semua file berupa `*.json`, `*.yaml`, `*.yml`, `*.toml`, `.env*`
- Rename/format only: diff purely whitespace, imports reorder, atau variable rename

**Implementation:**
- Add helper di `skills/gaspol-execute/SKILL.md`: `classify_phase_complexity(phase, diff)` returns `"review"` atau `"skip"`
- Saat phase checkpoint report di-generate, automatic dispatch `code-reviewer` agent kalau classify = `"review"`
- Show review summary langsung di checkpoint modal (brief, 3-5 bullet)
- Modal option user: `[Proceed]`, `[Address review feedback]`, `[Ignore review]`, `[Stop]`

**Output dari review muncul di checkpoint template:**
```markdown
### Auto-Review (Tier: [Triggered/Skipped])

Triggered because: [reason, e.g., "5 files changed, 230 LoC, new component"]

Findings:
- [finding 1]
- [finding 2]
- ...

OR: Skipped because: docs-only phase
```

### 3. Auto-Rubric Model Switching

**Rubric table:**

| Task kind | Model | Justification |
|---|---|---|
| Main orchestrator (current session) | Opus 4.7 | Strategic reasoning, workflow decisions |
| Architecture planning | Opus 4.7 | Deep multi-step analysis needed |
| Spec review (plan-verifier, spec-reviewer) | Opus 4.7 | Architectural judgment |
| Complex debug (systematic root-cause) | Opus 4.7 | Hypothesis branching |
| Feature implementation | Sonnet 4.6 | Execute well-defined tasks |
| Code review (code-reviewer) | Sonnet 4.6 | Pattern matching, style check |
| Test writing | Sonnet 4.6 | Mechanical but precise |
| Documentation sync | Haiku 4.5 | Template-driven, low reasoning |
| Rename / format / simple refactor | Haiku 4.5 | Mechanical |
| Simple research (fact lookup) | Haiku 4.5 | Bounded scope |

**Implementation:**
- Update `agents/code-reviewer.md`, `agents/code-simplifier.md`, `agents/plan-verifier.md`, `agents/spec-reviewer.md` frontmatter dengan `model` field
- `skills/gaspol-execute/implementer-prompt.md`: pass `model: sonnet` ke Agent dispatch (default implementation)
- `skills/gaspol-parallel/*.md`: model selection per task kind
- `skills/gaspol-dispatch/SKILL.md`: document rubric, apply di dispatch template
- `skills/gaspol-research/` (new): researcher subagent = Sonnet/Haiku, synthesizer = Opus
- Add rubric as reference table in CLAUDE.md

**No override mechanism in v1.2.0** (keputusan: auto-rubric by task type). Future: kalau butuh override, tambah `model_override` field di plan YAML phase.

### 4. Cross-Project Memory — GitHub-Based KB

**Repo setup (one-time):**
```bash
gh repo create alisadikinma/gaspol-knowledge --private \
  --description "Gaspol cross-project knowledge base"
```

**Local clone path (cross-platform):**
- Windows: `%USERPROFILE%\.claude\gaspol-knowledge\`
- Mac/Linux: `~/.claude/gaspol-knowledge/`

**Repo structure:**
```
gaspol-knowledge/
├── INDEX.md                     ← tagged index, grepped by Phase 0.5
├── ui-patterns/
│   ├── image-generation-ui.md
│   ├── dashboard-layout.md
│   └── editor-ui.md
├── architecture/
│   ├── auth-flow.md
│   └── state-management.md
├── design-decisions/            ← populated auto by gaspol-adr
│   └── YYYY-MM-DD-<slug>.md
├── research/                    ← populated auto by gaspol-research
│   └── <topic>.md
└── reusable-snippets/
    └── <snippet-name>.md
```

**INDEX.md entry format (one block per entry):**
```markdown
- title: Image Generation UI
  path: ui-patterns/image-generation-ui.md
  tags: [image-gen, gallery, prompt-input, variations]
  source: sparkfluence 2026-03
  hook: 3-pane layout (prompt + preview + history) works best for iterative workflows
  updated: 2026-03-15
```

**Phase 0.5 integration di `gaspol-brainstorm`:**
- Insert AFTER CLAUDE.md read (Phase 0), BEFORE codebase exploration (Phase 1)
- Steps:
  1. `cd ~/.claude/gaspol-knowledge/ && git pull --quiet` (silent, skip kalau offline)
  2. Extract tags dari user intent (e.g., "blog editor UI" → tags: [editor, blog, ui])
  3. Grep INDEX.md for tag matches
  4. If matches found: present to user "Found relevant past work: [list]. Use as reference?" via AskUserQuestion
  5. Read matched files, include as context di Phase 2 approach proposal

**`gaspol-learn` (new skill) flow:**
- Auto-triggered di `gaspol-finish` setelah verification chain pass
- Distill 1-3 patterns dari feature shipped (done oleh Sonnet subagent)
- Present via AskUserQuestion: "These patterns detected as reusable. Save to KB?"
- User confirm → write markdown file + update INDEX.md entry + `git add && commit && push`
- Offline handling: kalau push gagal, queue di `~/.claude/gaspol-knowledge/.pending-push`, retry next session online

**Offline resilience:**
- Semua query di Phase 0.5 pakai local clone → zero network dependency di hot path
- Push async → fail-safe (queue + retry)
- Kalau local clone tidak ada → skip Phase 0.5 graceful dengan log `KB not initialized, skipping`

**Backend abstraction (future-proof):**
- Skill code call `kb.query(tags, keywords)` dan `kb.capture(file_content, metadata)`
- Default implementation = filesystem + git (this spec)
- Future swap = Qdrant MCP (kalau AI Brain personal project live) tanpa ubah skill code

**Access dari device/platform lain:**
- Claude Desktop di PC/Mac: clone repo, optional Claude CLI MCP untuk query (future)
- Managed agents di VPS (n8n, Modal): clone repo via SSH or GitHub token, read files
- GitHub Actions (future): bisa run validation on push (lint INDEX.md, check broken paths)

### 5. Three Power-Up Skills

#### 5.1 `gaspol-research`

**Purpose:** Structured deep-dive untuk eksplor library/API/pattern dengan hasil di-cache ke KB research/.

**SKILL.md Iron Law:** `NO RESEARCH CLAIMS WITHOUT SOURCE CITATION + CACHE DECISION`

**Flow:**
1. User invoke (atau auto-trigger dari brainstorm Phase 2 saat approach tidak familiar)
2. **Scope**: ask user — what specific question? what decision akan di-inform? (via AskUserQuestion)
3. **Check cache first**: grep `gaspol-knowledge/research/` by tags — kalau match ada dan <30 hari, offer existing cache
4. **Parallel gather**: dispatch 3-5 subagents (Sonnet), masing-masing fetch dari: official docs, GitHub repos, benchmarks, Stack Overflow discussions, comparables
5. **Synthesize**: orchestrator (Opus) consolidate findings → structured summary dengan pros/cons/recommendation
6. **Cache**: write ke `gaspol-knowledge/research/<slug>.md` dengan metadata (tags, date, sources, verdict)
7. **Update INDEX.md** dengan entry baru
8. **Return** synthesis ke caller skill

**Output file format:**
```markdown
---
title: React Flow vs D3 for Node Editor
date: 2026-04-20
tags: [node-editor, visualization, react]
verdict: use-react-flow
sources:
  - https://reactflow.dev/docs
  - https://github.com/xyflow/xyflow
  - ...
---

## Context
## Options Considered
## Comparison Matrix
## Recommendation
## Open Questions
```

#### 5.2 `gaspol-auto` (Autonomous Execution)

**Purpose:** Skip per-phase checkpoint untuk familiar codebase + simple plan. Run full plan end-to-end with minimal interruption.

**SKILL.md Iron Law:** `NO AUTONOMOUS EXECUTION WITHOUT EXPLICIT UPFRONT PLAN APPROVAL + HARD STOP GUARDRAILS`

**Invocation:**
- Skill standalone: `/gaspol-auto` dengan plan file argument
- Flag di execute: `gaspol-execute --auto docs/plans/YYYY-MM-DD-<topic>.md`

**Flow:**
1. **Plan review gate** (MANDATORY): show full plan to user, AskUserQuestion "Approve autonomous run?" — `[Approve]`, `[Modify plan first]`, `[Run manually]`
2. **Pre-flight**:
   - Verify clean git state
   - Verify plan has phases structured per gaspol-plan spec
   - Verify test baseline (current tests pass)
3. **Execute loop**: for each phase
   - Dispatch implementer (Sonnet per rubric)
   - Run complexity classifier → auto-review if triggered
   - Continue to next phase automatically
4. **Hard stop conditions** (pause + AskUserQuestion):
   - Test failure
   - Placeholder trigger (anti-placeholder rule hit)
   - Destructive operation (DB drop, file delete, force push)
   - Ambiguity detected (plan step unclear)
   - Iron Law violation from any other skill
   - 3+ consecutive errors
5. **Post-run report**:
   - All phases completed with summaries
   - Auto-trigger `gaspol-verify` (all 4 layers)
   - Auto-trigger `gaspol-review` (tail review)
   - Present consolidated report

**NOT autonomous about:**
- Destructive git ops (push, force-push, reset --hard)
- Merge to main
- External API writes (Slack, email, PR creation)

Pattern reference: superpowers' "extended autonomous execution".

#### 5.3 `gaspol-adr` (Architecture Decision Record)

**Purpose:** Auto-capture architectural decisions ke KB tanpa effort manual. Prevent "kenapa dulu pilih X?" amnesia.

**SKILL.md Iron Law:** `NO ARCHITECTURAL FORK WITHOUT ADR CAPTURE`

**Trigger points:**
- `gaspol-brainstorm` Phase 2 finish: saat user pilih approach dari 2-3 options
- `gaspol-plan` saat phase punya explicit "Option A / Option B" decision

**Auto-flow (called by brainstorm/plan):**
1. Skill receive: context, options_considered, choice, reasoning (captured during brainstorm/plan)
2. Check KB `design-decisions/` untuk precedent: apa ada ADR serupa? Kalau ada, show user → "Supersede?" atau "Link as follow-up?"
3. Generate MADR-format markdown:
```markdown
---
id: ADR-YYYY-MM-DD-<slug>
status: accepted  # proposed | accepted | superseded
date: 2026-04-20
project: sparkfluence
domain: state-management
tags: [zustand, redux, state]
supersedes: null  # or ADR-YYYY-MM-DD-<old>
---

# <Decision Title>

## Context
<why we needed to decide this>

## Options Considered
- Option A: ...
- Option B: ...
- Option C: ...

## Decision
<what we chose and why>

## Consequences
- Positive: ...
- Negative: ...
- Neutral: ...

## Follow-up
<if any>
```
4. Write to `gaspol-knowledge/design-decisions/YYYY-MM-DD-<slug>.md`
5. Update INDEX.md
6. Git commit + push

**Cross-brainstorm surfacing:**
- `gaspol-brainstorm` Phase 2 otomatis grep `design-decisions/` dengan tag match dari user intent
- Show user: "Found 2 past ADRs on similar decision: [list]. Apply precedent?"
- Option kalau tidak apply: capture "divergence from ADR-XXX because ..." sebagai ADR baru

### 6. Skill Activation Fixes

Diagnosa akar per skill jarang fire (dari review session):

| Skill | Akar jarang fire | Fix |
|---|---|---|
| `gaspol-kickstart` | Content duplikat CLAUDE.md routing + brainstorm Phase 0 | **REMOVE** — fold ke brainstorm Phase 0/0.5 |
| `gaspol-design` | Phase 3 brainstorm heuristic sempit + tidak terlibat di planning/execute/verify | **DEVELOP ke power peer ui-ux-pro-max v2.0** — hybrid (fork data + optional v2.0 delegate) + wire ke gaspol-plan/execute/verify + KB pattern learning |
| `gaspol-tdd` | Execute tidak hard-gate TDD per phase | **HARD GATE** — execute refuse to run phase tanpa TDD step 1 |
| `gaspol-dispatch` | Overlap dengan `gaspol-parallel` | **REMOVE** — consolidate ke `gaspol-parallel` dengan mode field |
| `gaspol-worktree` | User realistis tidak pakai worktree di workflow | **REMOVE** — skip auto-offer, delete skill entirely |
| `gaspol-write-skill` | By-design occasional | **KEEP** — needed heavily untuk improvement round ini (3 skill baru + banyak modify) |

**Total skill count: 16 → 13** (remove kickstart, dispatch, worktree).

#### 6.1 gaspol-kickstart — REMOVE

**Decision:** Delete skill. Functionality folds into existing skills.

Rationale:
- 90% content duplikat CLAUDE.md skill routing table (no new value)
- Session-start hook sudah echo skill list — skill terpisah untuk re-list redundant
- Session context loading (baca CLAUDE.md, query KB) natural fit di `gaspol-brainstorm` Phase 0 + 0.5

Changes:
- Delete directory `skills/gaspol-kickstart/`
- `skills/gaspol-brainstorm/SKILL.md` Phase 0: expand untuk juga load KB INDEX.md snippet (bukan cuma CLAUDE.md)
- `skills/gaspol-brainstorm/SKILL.md` Phase 0.5 (new): query KB untuk precedent/patterns (already di-spec di Poin 4 + 7)
- `hooks/session-start.sh`: tetap echo skill list, remove gaspol-kickstart dari list
- `hooks/hooks.json`: no change (hook tetap fire, tapi tidak invoke skill yang sudah dihapus)
- Update CLAUDE.md:
  - Remove entries gaspol-kickstart dari Architecture table, Skill Routing table
  - Update skill count reference (16 → 13 setelah semua removal)
- Update `.claude-plugin/plugin.json` kalau list skills explicit
- Update `.claude-plugin/marketplace.json` kalau list skills explicit

**Impact:** plugin lebih ringkas. Functionality tidak hilang, fold ke brainstorm yang sudah aktif dipakai.

#### 6.2 gaspol-design — DEVELOP ke Power Peer ui-ux-pro-max v2.0

**Current issues:**
1. Phase 3 brainstorm heuristic sempit (7 keyword)
2. gaspol-design tidak punya data layer sendiri (reference ke external plugin)
3. Tidak terlibat di `gaspol-plan`, `gaspol-execute`, `gaspol-verify` (cuma aktif di brainstorm)
4. Tidak integrate dengan KB (Poin 4) — UI patterns tidak di-cache cross-project

**Reference:** https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (v2.0)

**Target:** gaspol-design jadi power peer dengan ui-ux-pro-max v2.0 (parity capabilities) + **additional gaspol-specific layers** (project context, KB integration, planning chain wiring) + **hybrid strategy** (fork data + optional v2.0 delegate).

##### 6.2.1 Capabilities Parity (match ui-ux-pro-max v2.0)

Fork stable data dari ui-ux-pro-max (with attribution, check MIT license compatibility):

| Data Asset | Target Location | Count Target |
|---|---|---|
| UI Styles | `skills/gaspol-design/data/styles.csv` | 67+ (match v2.0, extensible) |
| Color Palettes | `skills/gaspol-design/data/palettes.csv` | 161+ industry-aligned |
| Font Pairings | `skills/gaspol-design/data/typography.csv` | 57+ Google Fonts curated |
| Chart Types | `skills/gaspol-design/data/charts.csv` | 25+ with best practices |
| Reasoning Rules | `skills/gaspol-design/rules/reasoning-core.md` | 161+ industry-specific |
| UX Guidelines | `skills/gaspol-design/data/ux-guidelines.csv` | 99+ usability/a11y |
| Multi-framework Templates | `skills/gaspol-design/templates/{framework}/` | React, Vue, Next, Laravel, SwiftUI, Flutter, HTML+Tailwind, shadcn/ui, Astro, Svelte |

##### 6.2.2 Power BEYOND ui-ux-pro-max (gaspol-specific layers)

| Layer | Value |
|---|---|
| Project context integration | Reads CLAUDE.md, respects existing design tokens, prevents drift |
| KB cross-project learning | Query `gaspol-knowledge/ui-patterns/` untuk past project patterns (Poin 4 KB) |
| Anti-AI-slop enforcement | Hard rules: no Inter default, no purple gradient on white, no predictable symmetric |
| Planning integration | Active during `gaspol-plan` untuk per-UI-phase design deliverable |
| Execute fidelity check | Active during `gaspol-execute` untuk scan actual code vs design system |
| Verify compliance | Layer 4 sub-check: design system compliance |
| Design audit | Scan existing codebase vs current design system, flag drift |
| Component library stub | Generate starter code (card, button, form, modal) matching project stack |

##### 6.2.3 Hybrid Invocation Strategy

```
User request (UI work)
    ↓
gaspol-design orchestrator
    ↓
Check: is ui-ux-pro-max v2.0 installed?
    ├── YES → delegate advanced design system gen ke v2.0
    │         + apply gaspol-specific layers on top (project context, KB, anti-AI-slop)
    └── NO  → use own forked data + own reasoning engine
              + apply gaspol-specific layers
    ↓
Unified output: design-system.md + component-specs.md + code templates
```

Optional delegation bridge: `skills/gaspol-design/integration/ui-ux-pro-max-bridge.py` — detects v2.0 install, calls scripts, parses output, merges dengan gaspol layers.

##### 6.2.4 File Structure

```
skills/gaspol-design/
├── SKILL.md                           ← main orchestrator
├── data/
│   ├── styles.csv                     ← 67+ UI styles
│   ├── palettes.csv                   ← 161+ color palettes
│   ├── typography.csv                 ← 57+ font pairings
│   ├── charts.csv                     ← 25+ chart types
│   └── ux-guidelines.csv              ← 99+ UX guidelines
├── rules/
│   ├── reasoning-core.md              ← 161+ reasoning rules
│   ├── reasoning-gaspol.md            ← gaspol-specific (project context rules)
│   └── anti-ai-slop.md                ← hard enforcement rules
├── templates/
│   ├── react-tsx/
│   ├── vue/
│   ├── next/
│   ├── laravel-blade/
│   ├── swiftui/
│   ├── flutter/
│   ├── html-tailwind/
│   ├── shadcn-ui/
│   ├── astro/
│   └── svelte/
├── scripts/
│   ├── search.py                      ← core search (own impl)
│   ├── design-system-gen.py           ← generation engine
│   └── design-audit.py                ← scan codebase vs design system
└── integration/
    └── ui-ux-pro-max-bridge.py        ← optional delegate to v2.0
```

##### 6.2.5 Integration Across Skill Chain (NEW)

**`gaspol-brainstorm` Phase 3 (enhanced):**

Layer 1 — Keyword detection (expanded):
```
UI indicators: button, form, modal, card, view, screen, page, layout,
              dashboard, component, navbar, sidebar, menu, dropdown,
              tampilan, halaman, tombol, kartu, bentuk
Visual indicators: UX, style, color, warna, font, typography, animation,
                   animasi, responsive, mobile, desktop, dark mode,
                   light mode, theme, tema
```

Layer 2 — File extension detection:
Kalau user request mention create/edit file dengan ext: `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.sass`, `.module.css`, `.tailwind.config.*` → auto-trigger.

Layer 3 — Mandatory Phase 2.5 gate (kalau ambigu):
AskUserQuestion: "Apakah task ini butuh design UI/UX intelligence?" options: [Yes, include design phase] / [No, pure backend/logic] / [Minimal UI, no design needed].

Output: design spec yang masuk ke spec file.

**`gaspol-plan` integration (NEW):**

Plan template upgraded dengan design deliverable column:

```markdown
| Phase | Code Deliverable | Design Deliverable | Verification |
|-------|-----------------|-------------------|--------------|
| 1 | useAuth hook | n/a (pure backend) | Tests + types |
| 2 | Login page component | Design spec (tokens, layout, motion), component API, states (loading/error/empty) | Design system compliance + visual review |
| 3 | Profile page | Design spec, interaction states | Design system compliance |
```

Changes di `skills/gaspol-plan/SKILL.md`:
- Detect UI-related phases (from brainstorm design spec + code deliverable file ext)
- Per UI phase → invoke gaspol-design untuk produce "design deliverable spec":
  - Tokens used (from design system)
  - Layout structure (ASCII wireframe atau Figma-equivalent)
  - Motion plan (timing, easing)
  - Component API (props, states, variants)
  - Accessibility requirements
- Insert design-review mini-phase setelah major UI phase (optional, triggered kalau phase size >100 LoC UI)

**`gaspol-execute` integration (NEW):**

Per UI phase during execution:
- Read design deliverable dari plan
- After implementation, invoke gaspol-design untuk scan actual code vs design spec
- Output: compliance report (tokens match? layout match? motion match? a11y met?)
- Integrate dengan tiered auto-review (Poin 2) — design drift = auto-trigger review

**`gaspol-verify` Layer 4 extension (NEW):**

Layer 4 (Integration) sub-check:
- Design system compliance: all UI components use design tokens (no hardcoded colors/fonts/spacing)
- Responsive compliance: all layouts handle mobile + desktop per spec
- A11y compliance: semantic HTML, ARIA labels, keyboard nav, contrast ratios

**`gaspol-learn` integration (Poin 5):**

Setelah `gaspol-finish`, `gaspol-learn` extract UI patterns → `gaspol-knowledge/ui-patterns/<slug>.md`:
- Captured: component layout, interaction pattern, design tokens used, project stack
- Indexed by tags: [component-type, industry, stack, visual-style]
- Next project dengan domain/stack sama → Phase 3 brainstorm auto-surface

##### 6.2.6 Implementation Strategy (Phased)

| Phase | Scope | Deliverable |
|---|---|---|
| A | License check + fork stable data | CSV files in `data/`, attribution di SKILL.md |
| B | Build core reasoning engine | `scripts/search.py`, `scripts/design-system-gen.py`, own reasoning logic |
| C | Multi-framework templates | Templates directory for 10 frameworks |
| D | Gaspol-specific rules | `rules/reasoning-gaspol.md`, `rules/anti-ai-slop.md` |
| E | Optional v2.0 bridge | `integration/ui-ux-pro-max-bridge.py` dengan graceful fallback |
| F | Wire into gaspol-plan | Plan template + dispatch logic |
| G | Wire into gaspol-execute | Fidelity check per UI phase |
| H | Wire into gaspol-verify | Layer 4 design compliance sub-check |
| I | KB integration | `gaspol-learn` → `ui-patterns/` write + brainstorm Phase 3 query |
| J | Design audit tool | `scripts/design-audit.py` untuk existing codebase scan |

##### 6.2.7 License & Attribution

- Check ui-ux-pro-max license di `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` — assumed MIT atau permissive (common for skill repos)
- Kalau MIT → fork OK dengan attribution di SKILL.md + NOTICE.md
- Attribution format:
  ```
  This skill incorporates data and patterns adapted from ui-ux-pro-max-skill v2.0
  by nextlevelbuilder (https://github.com/nextlevelbuilder/ui-ux-pro-max-skill),
  licensed under MIT. Extended with gaspol-specific reasoning and integration layers.
  ```
- Kalau license restrictive (GPL, AGPL) → fallback ke pure gaspol-owned data (curate own 67 styles from public knowledge)

##### 6.2.8 Impact Summary

- gaspol-design fire 3-5x lebih sering (expanded triggers)
- Terlibat di 4 skill tambahan: plan, execute, verify, learn (bukan cuma brainstorm)
- Self-sufficient (fork) + optional upgrade via v2.0 (hybrid)
- Cross-project design pattern reuse (KB integration)
- Design fidelity audited, bukan cuma advisory

#### 6.3 gaspol-tdd Hard Gate

**Current:** `gaspol-execute` says "follow TDD" tapi tidak enforce. Agent tulis kode tanpa test.

**Target:** execute refuse to run phase tanpa TDD gate.

Changes:
- `skills/gaspol-plan/SKILL.md`: plan phase template WAJIB punya step 1 format: `"1. Write failing test for [specific behavior]. Expected error: [error class/message]."`
- `skills/gaspol-execute/SKILL.md` Step 2: sebelum implement phase, validasi phase description contains test step di step 1. Kalau tidak ada:
  - Stop
  - Emit error: `"Phase [X] missing TDD gate. Plan template violation."`
  - AskUserQuestion: [Update plan to add TDD step] / [Skip TDD for this phase (acknowledge technical debt)] / [Abort execution]
- `skills/gaspol-execute/implementer-prompt.md`: subagent dispatch include hard instruction "Step 1 of this phase MUST be writing a failing test. No production code until test fails as expected."
- Tiered auto-review (Poin 2) flag "no test file created" as critical finding

**Impact:** gaspol-tdd fire di 90%+ implementation phases (dari estimasi <20% sekarang).

#### 6.4 gaspol-dispatch → gaspol-parallel Consolidation

**Current:** dua skill overlap. User bingung pilih.

**Target:** satu `gaspol-parallel` dengan mode field.

Changes:
- Merge `skills/gaspol-dispatch/SKILL.md` content into `skills/gaspol-parallel/SKILL.md`
- Add `mode` parameter di parallel skill:
  - `mode: plan-phases` — execute plan with independent phases in parallel (current gaspol-parallel)
  - `mode: independent-domains` — solve 2+ unrelated problems in parallel (current gaspol-dispatch)
- Both modes share: conflict check, fresh subagent per task, two-stage review, anti-placeholder rules
- Delete directory `skills/gaspol-dispatch/`
- Update CLAUDE.md:
  - Remove row "2+ independent tasks, parallel work needed | `gaspol-dispatch`"
  - Update row: "Parallel execution (plan or ad-hoc) | `gaspol-parallel` (specify mode)"
- Update `hooks/session-start.sh` skill list (remove gaspol-dispatch)
- Update `.claude-plugin/plugin.json` + `marketplace.json` if they list skills

**Impact:** total skills 16 → 15. Reduce choice paralysis. Clearer border.

#### 6.5 gaspol-worktree — REMOVE

**Decision:** Delete skill entirely. User workflow realistis branch-only.

Rationale:
- Skill well-crafted tapi user workflow selama ini pakai git branches (checkout switch), bukan worktrees
- Auto-offer tidak akan mengubah habit kalau tidak realistis dipakai
- Plugin kompleksitas turun tanpa loss of actual capability

Changes:
- Delete directory `skills/gaspol-worktree/`
- Remove dari `skills/gaspol-brainstorm/SKILL.md` Phase 6 handoff
- Remove dari `skills/gaspol-plan/SKILL.md` end-of-plan (kalau sudah ada reference)
- Remove dari `skills/gaspol-finish/SKILL.md` worktree cleanup option
- Update CLAUDE.md:
  - Remove entries gaspol-worktree dari Architecture table, Skill Routing table
  - Remove from skill list dalam Debugging/Conventions sections
- Update `hooks/session-start.sh` skill list (remove gaspol-worktree)
- Update `.claude-plugin/plugin.json` + `marketplace.json` kalau list explicit

**Future:** kalau suatu saat workflow pindah ke worktree-based (contoh: multi-agent parallel work demanding isolation), skill bisa re-added via gaspol-write-skill RED-GREEN-REFACTOR. Untuk sekarang YAGNI.

**Impact:** plugin lebih ringkas. Zero loss karena skill ini memang tidak dipakai.

#### 6.6 gaspol-write-skill — Keep As-Is

Memang by design occasional. Tidak ada perubahan.

---

### 7. Industry Research Grounding

**Problem:** Brainstorm Phase 2 propose approaches berdasarkan training data (cutoff Jan 2026, biased ke pattern viral 2023-2024) + CLAUDE.md (project-specific only). Result: generic best practice yang mungkin sudah outdated di 2026.

**Target:** Tiered research dengan novelty gate supaya approach grounded di industry current state TANPA boros token di familiar domain.

#### 7.1 Phase 1.5 Novelty Assessment (baru di gaspol-brainstorm)

Inserted AFTER Phase 1 (understand problem), BEFORE Phase 2 (propose approaches):

```
1. Classify task domain (auth, state-management, image-gen, realtime, ...)
2. Query KB research/ + design-decisions/ for similar past work
3. Query project CLAUDE.md for existing patterns
4. Classify novelty:
   - PRECEDENT: KB hit + project hit → skip research, use precedent
   - SEMI-NEW: KB hit, no project hit → light WebSearch (2-3 query, ~5min)
   - NEW: no KB, no project hit → invoke gaspol-research (deep, ~20min, cached)
5. Feed findings into Phase 2
```

#### 7.2 Research Quality Gates (wajib di gaspol-research output)

| Gate | Rule |
|---|---|
| Multi-source | Min 4 sources: official docs + 2 GitHub repos (real usage) + 1 comparable/benchmark |
| Recency | Prefer sources <18 bulan. Flag sources >3 tahun sebagai "potentially outdated" |
| Signal filter | Include stars/downloads/last commit date → validate maintenance status |
| Anti-pattern check | Search "X vs Y" + "problems with X", bukan cuma "X is great" |
| Constraint fit | Framing: "given project constraints, what fits" NOT "which is objectively better" |
| Citation mandatory | Every claim needs URL or file:line reference |
| Anti-hallucination | WebFetch actual page untuk claim kritikal, bukan cite dari memory |

#### 7.3 Multi-Source Synthesis in Phase 2

Phase 2 approach proposal format upgraded:

```markdown
### Approach A: Use Zustand for state management

**Sources consulted:**
- https://zustand.docs.pmnd.rs (official, fetched 2026-04-17)
- Real-world: https://github.com/pmndrs/zustand (23k stars, maintained)
- Comparison: https://npmtrends.com/zustand-vs-redux

**Why fits this project:**
- Project stack (React + TypeScript) — compatible per CLAUDE.md line X
- Bundle size <1KB — matches project perf budget
- No boilerplate — team size 1-2 per CLAUDE.md

**Trade-offs (grounded, not generic):**
- Less tooling than Redux DevTools (gap: time-travel debugging)
- Smaller ecosystem of middlewares (gap: redux-saga equivalent limited)
```

Bukan generic "Zustand is simpler, Redux is more powerful."

---

### 8. Mandatory Step-Level Closure Gate

**Problem:** Plan detailed tapi implementation miss steps karena tidak ada blocking final review.

**Target:** Upgrade plan-verifier ke step-level + evidence-based + hard-gate di 2 titik.

#### 8.1 Upgrade `agents/plan-verifier.md`

Changes:
- Parse plan jadi granular item list (every bullet, not just phase header)
- Use Opus 4.7 (per Poin 3 rubric — spec-level verification)
- Per item, MUST produce: verdict + code evidence quote
- Verdict taxonomy:
  - `FOUND` — matching code exists, with file:line quote
  - `PARTIAL` — partial match, with gap explanation
  - `MISSING` — no matching code found, explicit
  - `DIVERGED` — different implementation than planned, with justification

Output format:

```markdown
## Plan Fidelity Audit (step-level)

### Phase 1: Auth setup
- [x] FOUND — "Create useAuth hook"
  Evidence: src/hooks/useAuth.ts:1-45
- [ ] MISSING — "Add logout confirmation modal"
  No matching code found. Search: modal*|confirm*|logout* → 0 hits.
- [~] PARTIAL — "Add error handling for expired tokens"
  Evidence: src/hooks/useAuth.ts:67-72 (catches 401 but no UI feedback)
  Gap: missing UI step from plan phase 1.4.b

### Summary
- FOUND: 14
- PARTIAL: 2
- MISSING: 1
- DIVERGED: 0
- VERDICT: BLOCKING
```

#### 8.2 Hard-Gate at End of `gaspol-execute`

After completion gate (placeholder scan), MUST run plan-verifier:
- `MISSING > 0` → BLOCKING
- `PARTIAL > 0` without explicit deferral → BLOCKING
- Present via AskUserQuestion:
  - `[Fix missing items now]` (default)
  - `[Defer X items with ADR capture]` (creates ADR via Poin 5 gaspol-adr)
  - `[Mark as diverged and close with justification]`

#### 8.3 Hard-Gate at `gaspol-finish` Pre-Chain

Same plan-verifier run as blocker before merge/PR options:
- Cannot present finish options kalau plan-verifier = BLOCKING
- Must go back to execute atau explicit override (logged as ADR)

#### 8.4 Anti-Hallucination Safeguards

Supaya agent tidak pura-pura FOUND tanpa evidence:
- Prompt explicit: "For every FOUND verdict, you MUST quote matching code from file:line. Verdicts without quotes are auto-downgraded to PARTIAL."
- Orchestrator post-audit: sample 3 random FOUND items, verify quote accuracy via Read
- Fabricated quote detected → auto-increment MISSING count + user notified

#### 8.5 Integration with Poin 2 (Tiered Review)

- Tiered auto-review at end of each phase → mini plan-fidelity check for that phase only (cheap, fast)
- Full plan-verifier at end of execute → cross-phase audit (expensive, rigorous)
- Two-layer: catch miss per phase + catch miss between phases

#### 8.6 Integration with Poin 6.3 (TDD Hard Gate)

Plan-verifier juga audit test file existence:
- Every phase yang implement production code → verify corresponding test file exists
- MISSING test file = BLOCKING (sama level sama miss implementation)

---

### 9. Research Cache Lifecycle

**Problem:** Research output hilang antar session, atau cached tapi tidak ada freshness tracking — data 1 tahun lalu dianggap "latest" padahal industry berubah.

**Target:** TTL-based cache lifecycle dengan progressive refresh, bukan wholesale re-research.

#### 9.1 Cache File Structure

Di `~/.claude/gaspol-knowledge/research/<topic>.md`:

```yaml
---
title: Zustand vs Redux for State Management
researched_at: 2026-03-15
expires_at: 2026-09-11          # researched_at + 180 days default
sources:
  - https://zustand.docs.pmnd.rs (fetched 2026-03-15)
  - https://github.com/pmndrs/zustand (23k stars, last commit 2026-03-10)
  - https://github.com/reduxjs/redux (60k stars, last commit 2026-02-20)
  - https://npmtrends.com/redux-vs-zustand (fetched 2026-03-15)
tags: [state-management, react, zustand, redux]
verdict: prefer-zustand-for-apps-under-10k-loc
project_fit: sparkfluence (React, small team)
supersedes: null
superseded_by: null
---

## Context
## Options Compared
## Benchmark
## Recommendation
## Open Questions
```

#### 9.2 Freshness Tier

Dihitung saat cache accessed (Phase 1.5 novelty assessment):

| Age | Tier | Behavior |
|---|---|---|
| 0-90 hari | 🟢 FRESH | Pakai as-is, no re-research |
| 90-180 hari | 🟡 AMBER | Show cache + offer "verify freshness" mini-research (2-3 WebSearch ~5 min) |
| 180-365 hari | 🟠 STALE | Offer "re-research" (full gaspol-research ~20 min) atau "use with warning" |
| >365 hari | 🔴 EXPIRED | Re-research mandatory; cache auto-archived ke `research/_archive/` |

#### 9.3 Freshness Verification Mini-Research (for AMBER)

Targeted, bukan full re-research:
1. WebSearch top sources dari cache → cek last-updated date
2. WebSearch "[topic] 2026" → cek breaking changes / new entrants
3. Auto-assess:
   - No significant change → bump `researched_at`, extend `expires_at`, keep cache
   - Significant change → trigger full re-research, old cache archived dengan `superseded_by` link

#### 9.4 INDEX.md Freshness Badge

```markdown
- title: Zustand vs Redux
  path: research/zustand-vs-redux.md
  tags: [state-management, react]
  researched: 2026-03-15 (32 days ago) 🟢 FRESH
  verdict: prefer-zustand-for-apps-under-10k-loc
```

User selalu lihat age sebelum decide pakai cached atau re-research.

#### 9.5 Audit Trail di Git

Setiap update research → commit ke `alisadikinma/gaspol-knowledge` dengan message pattern:
- `research: new [topic] (sparkfluence 2026-04)`
- `research: verified freshness [topic] (+180 days)`
- `research: superseded by [new-topic] [topic]`
- `research: archived [topic] (expired, 2026-01-15 to 2027-01-15)`

Traceable history — user bisa audit kapan last verified, melihat trend changes.

---

### 10. KB Lifecycle & Self-Maintenance

**Problem:** Poin 4 bikin KB tumbuh. Tanpa lifecycle management, KB berubah jadi pollution:
- Stale entries tanpa TTL (ui-patterns, ADR) — ADR 2 tahun lalu masih muncul sebagai precedent padahal sudah superseded
- Bias precedent reinforcement — pattern pertama di-cache, next project auto-follow, bad pattern propagated
- No capture quality gate — junk captures (one-off quirks, duplicates) polluting INDEX.md
- No audit mechanism — stagnant entries tidak pernah di-review

**Target:** Plugin truly compounding (self-curating), bukan sekadar accumulating. 4 mekanisme synergi:

#### 10.1 Status Lifecycle untuk SEMUA KB Entries

Extend beyond Poin 9 (yang hanya cover research). Apply ke:
- `ui-patterns/` — component patterns
- `design-decisions/` (ADR) — architectural decisions
- `architecture/` — system patterns
- `reusable-snippets/` — code snippets
- `research/` (sudah ada dari Poin 9, extend dengan status)

Status taxonomy (MADR-compliant):

| Status | Meaning | Visible di INDEX.md |
|---|---|---|
| `proposed` | Captured but not validated in production | 🟨 shown with warning |
| `accepted` | Validated, actively recommended | 🟢 shown normally |
| `superseded` | Replaced by newer entry (`superseded_by: <id>`) | 🟠 shown with pointer to replacement |
| `deprecated` | No longer recommended, kept for audit trail | 🔴 hidden from default query, opt-in view |

YAML frontmatter tiap entry wajib include:
```yaml
---
id: <entry-id>
status: accepted
superseded_by: null   # or <other-id>
supersedes: null      # or <other-id>
deprecated_at: null   # or ISO date
last_validated: 2026-04-17
---
```

Query default: only `accepted`. User bisa opt-in lihat `proposed` atau `superseded` via flag.

#### 10.2 `gaspol-kb-audit` Skill (Periodic Health Check)

New skill untuk scheduled KB maintenance.

**Trigger:**
- Manual: `/gaspol-kb-audit`
- Scheduled: quarterly (via user cron / reminder)
- Auto: saat KB >500 entries (size-based trigger)

**Process:**
1. Scan all KB entries
2. Identify issues:
   - **Stale**: `last_validated > 180 days` + status `accepted` → flag for review
   - **Conflicting**: 2+ entries dengan tag sama tapi verdict berbeda → flag untuk consolidation
   - **Orphan**: entries dengan tags yang no longer match any project → flag for deprecation
   - **Duplicate**: similar content (>80% overlap) → flag untuk merge
   - **Broken refs**: `supersedes` atau `superseded_by` pointing ke entry yang tidak exist
3. Generate `audit-report-<date>.md`:
   ```markdown
   ## KB Audit Report 2026-07-17

   ### Stale (need re-validation): 12 entries
   - [zustand-vs-redux](research/zustand-vs-redux.md) — last validated 2026-01 (6 months)
     Suggested action: [Verify freshness] [Mark deprecated] [Keep as-is]
   ...

   ### Conflicting: 2 entries
   - [image-gen-ui-a](ui-patterns/image-gen-ui-a.md) vs [image-gen-ui-b](ui-patterns/image-gen-ui-b.md)
     Both tagged [image-gen, gallery]. Verdicts differ.
     Suggested action: [Merge] [Supersede one] [Tag differentiation]
   ...

   ### Deprecation candidates: 5 entries
   ...

   ### Broken refs: 1 entry
   ...
   ```
4. AskUserQuestion per finding — user decide: fix now, defer, ignore
5. Apply fixes → git commit ke KB repo dengan audit trail

**Integration:** Run otomatis di `gaspol-kickstart` removal path (brainstorm Phase 0) kalau audit terakhir >90 hari.

#### 10.3 Capture Quality Gate di `gaspol-learn`

Gaspol-learn (Poin 4 new skill) sebelum commit ke KB, validate:

| Check | Rule | Action kalau fail |
|---|---|---|
| Minimum content | Body >200 kata (bukan stub) | Reject, suggest expand |
| Tag validation | Min 2 tags dari taxonomy | Reject, prompt user add tags |
| Duplicate detection | Grep semantic-adjacent title — kalau >80% title overlap, flag | AskUserQuestion: merge atau keep separate |
| Not restating CLAUDE.md | Content beyond yang sudah di CLAUDE.md project | Reject kalau cuma restate |
| Source citation | Kalau entry research/ → min 2 URLs | Reject kalau no source |
| User confirmation | Final AskUserQuestion sebelum commit | User can [Save] / [Edit] / [Discard] |

Rejected captures: log ke `~/.claude/gaspol-knowledge/.rejected-log` dengan reason — bukan hilang, tapi visible untuk audit kalau user mau reconsider.

#### 10.4 Anti-Precedent Mechanism di Phase 0.5 + 1.5

Saat brainstorm surface precedent dari KB, tambah option:

```
Found precedent:
  [image-gen-ui-a](ui-patterns/image-gen-ui-a.md)
  Tags: [image-gen, gallery, 3-pane]
  Verdict: prefer 3-pane layout

AskUserQuestion:
  [Apply precedent (default)]
  [Override — I have reason to diverge]        ← NEW
  [Skip precedent, start fresh]
```

Kalau user pilih "Override":
1. Prompt user untuk reason (brief, 1-2 sentences)
2. Log sebagai `divergence ADR` di `design-decisions/divergence-YYYY-MM-DD-<slug>.md`
3. Old precedent NOT superseded (both exist, tagged differently)
4. Future brainstorm akan surface BOTH — original + divergence — supaya next time user explicit decision

**Benefit:**
- Prevents blind precedent-following
- Makes divergences visible (audit trail)
- Forces user to articulate WHY diverging (builds better mental model)
- KB jadi kaya dengan context: "in situation X we did A, in situation Y we did B"

#### 10.5 Integration Summary

| Mechanism | Impacts | Invoked from |
|---|---|---|
| Status lifecycle | All KB entries | Auto pada every capture + manual via audit |
| gaspol-kb-audit skill | All KB entries | Scheduled quarterly + manual + size-triggered |
| Capture quality gate | gaspol-learn output | Every capture attempt |
| Anti-precedent mechanism | Brainstorm Phase 0.5 + 1.5 | Every precedent surface |

#### 10.6 Metric: KB Health Score

Track quarterly:
- Total entries
- % accepted vs superseded vs deprecated
- Avg age of accepted entries
- Duplicates detected
- Conflicts detected
- Divergence rate (user choosing override vs follow precedent)

Health thresholds:
- 🟢 Green: <10% stale, <5% duplicates, <2% broken refs
- 🟡 Yellow: 10-25% stale atau 5-15% duplicates → run audit
- 🔴 Red: >25% stale → mandatory audit blocks new captures until cleaned

---

---

### 11. CLAUDE.md Update + README.md Overhaul

**Problem:**
1. Setelah 10 improvement besar di round ini, CLAUDE.md existing tidak reflect state baru — tables outdated, workflow chains berubah (kickstart removed, dispatch merged, design jadi power peer, 3 skills baru), skill count salah (16 → 13)
2. README.md existing (kalau ada) kemungkinan thin — tidak convince user potensial untuk adopt gaspol dibanding alternatif (superpowers, dsb)

**Target:**
- CLAUDE.md jadi accurate source of truth pasca-refactor
- README.md jadi growth lever — compelling, concrete, differentiated

#### 11.1 CLAUDE.md Updates (Wajib)

Sections yang harus update:

| Section | Change |
|---|---|
| Architecture table | Remove kickstart, dispatch, worktree rows. Update gaspol-design row (power peer). Add 3 new rows: gaspol-research, gaspol-auto, gaspol-adr, gaspol-learn, gaspol-kb-audit |
| Skill Routing table | Remove 3 deleted skills, add 5 new skills, update routing for design (now active in plan/execute/verify) |
| Skill Types (Rigid/Flexible) | Recategorize updated skills |
| Workflow Chains | Update chain diagram: remove kickstart from startup, add Phase 0.5 KB query ke brainstorm, add plan-verifier hard-gate ke execute end |
| Anti-Placeholder Enforcement | No change (still core) |
| Data Source Classification table | No change |
| Per-Phase Checkpoints | Update with tiered auto-review (Poin 2) + TDD hard gate (Poin 6.3) |
| Brainstorming Flow | Add Phase 0.5 Novelty Assessment (Poin 7), Phase 0.5 KB query (Poin 4) |
| TDD Enforcement | Update dengan hard-gate di execute (Poin 6.3) |
| 4-Layer Verification | Update Layer 4 dengan design compliance (Poin 6.2) |
| Parallel Execution | Update dengan mode param (Poin 6.4) — plan-phases vs independent-domains |
| Agent Dispatch | Update — dispatch section folds into parallel |
| Receiving Review Feedback | No change |
| Finishing Work | Update pre-finish chain: add mandatory plan-verifier (Poin 8) |
| Sync Docs | No change |
| Git Worktree | REMOVE section (skill deleted) |
| Writing Skills | No change |
| **NEW sections:** | |
| Cross-Project Knowledge Base | Full section tentang Poin 4 architecture, `~/.claude/gaspol-knowledge/` structure, GitHub repo, auto-query di Phase 0.5 |
| Model Switching Rubric | Poin 3 rubric table (Opus/Sonnet/Haiku per task type) |
| Research Grounding | Poin 7 tiered novelty assessment + Poin 9 freshness lifecycle |
| Design Intelligence (power peer) | Poin 6.2 — capabilities parity, hybrid strategy, chain integration |
| Closure Gate | Poin 8 — step-level evidence-based plan-verifier |
| KB Self-Maintenance | Poin 10 — status lifecycle, audit skill, quality gate, anti-precedent |
| Red Flags updates | Add new rationalizations per new skill |
| Debugging table | Update "Skills not listed" check + new debugging rows for new skills |
| Version & Last Updated | Bump ke 1.2.0 + 2026-04 |

#### 11.2 README.md Overhaul (Growth Lever)

Target audience: developer yang sudah pakai Claude Code + tertarik improve workflow. Compare against decision to pick superpowers atau other plugin. Goal: **compelling enough untuk install dalam 30 detik setelah scan.**

Proposed structure:

```markdown
# gaspol-dev

**Process discipline for Claude Code — so AI writes real code, not fake placeholders.**

[![Version](https://img.shields.io/badge/version-1.2.0-blue)](...) [![License](https://img.shields.io/badge/license-MIT-green)](...)

---

## Why gaspol?

You plan a feature carefully. Claude executes it.
And then you find:
- A `const data = [...]` placeholder where a real API call should be
- Phase 3 completed "successfully" but 3 steps got skipped
- Tests written after implementation (or not at all)
- No memory of decisions made last month

gaspol-dev fixes this. 13 skills + 4 agents that enforce process discipline, catch placeholders, gate completion with evidence, and build a cross-project knowledge base that compounds over time.

---

## What makes it different

| Other plugins | gaspol-dev |
|---|---|
| Advisory rules ("write test first") | **Hard gates** (execute refuses to run phase without TDD step) |
| Code review at end | **Tiered auto-review** per phase based on complexity |
| Plan-level fidelity check | **Step-level evidence-based** plan verifier |
| Generic training-data suggestions | **Industry research grounding** dengan freshness-aware cache |
| Single-project context | **Cross-project KB** (GitHub-synced) — patterns learned once, reused forever |
| Fixed model | **Auto-rubric model switching** (Opus/Sonnet/Haiku per task) |
| Design as afterthought | **Power-peer design intelligence** wired into plan/execute/verify |

---

## Quick Start

```bash
# Install via Claude Code marketplace
claude plugin install gaspol-dev

# First run: kickstart auto-scans your project
# Phase 0.5 queries your knowledge base for relevant patterns
# Brainstorm suggests approaches grounded in industry current state
```

Start with: `/gaspol-brainstorm` for any new feature idea.

---

## The 13 skills (organized by workflow)

### Planning & Design
- **gaspol-brainstorm** — CLAUDE.md-first + novelty assessment + cross-project KB query
- **gaspol-design** — Power-peer design intelligence (67 styles, 161 palettes, 57 fonts, multi-framework)
- **gaspol-plan** — Implementation plan with Data Integration Map + TDD steps + design deliverables
- **gaspol-research** — Deep-dive external libs/APIs with freshness-aware cache
- **gaspol-adr** — Architecture Decision Records auto-captured

### Execution
- **gaspol-execute** — Plan execution with anti-placeholder enforcement + per-phase checkpoints
- **gaspol-parallel** — Multi-agent parallel (plan-phases OR independent-domains mode)
- **gaspol-auto** — Autonomous mode for familiar codebase (skip checkpoints, hard-stop on blockers)
- **gaspol-tdd** — RED-GREEN-REFACTOR hard-gated by execute
- **gaspol-debug** — Systematic root-cause debugging (no guessing)

### Verification & Closure
- **gaspol-verify** — 4-layer verification (technical, plan fidelity, placeholder scan, integration+design compliance)
- **gaspol-review** — Code review dispatch
- **gaspol-receive-review** — Technical response (no performative agreement)
- **gaspol-finish** — Step-level closure gate + merge/PR/cleanup

### Learning & Maintenance
- **gaspol-learn** — Auto-capture patterns from shipped features (with quality gate)
- **gaspol-sync-docs** — CLAUDE.md sync post-implementation
- **gaspol-kb-audit** — Periodic KB health check (stale, duplicates, conflicts)
- **gaspol-write-skill** — TDD applied to skill creation

---

## Real example: Compounding knowledge

```
[First project: Sparkfluence]
You: /gaspol-brainstorm image-generation UI
gaspol: [explores, decides 3-pane layout, captures decision]
...ships...
gaspol-learn: Pattern captured → ui-patterns/image-generation-ui.md

[3 months later: new project, same domain]
You: /gaspol-brainstorm AI video editor UI
gaspol: Phase 0.5 KB query found precedent:
  [image-generation-ui] — tags: [image-gen, 3-pane]
  Verdict: 3-pane (prompt + preview + history)
  Status: 🟢 accepted, last validated 42 days ago
  → Apply precedent, or override with reason?
```

No re-research. No re-exploration. Decisions made in Sparkfluence carry forward.

---

## Architecture

[Diagram showing skill chain, KB flow, agent dispatch, hard-gates]

---

## Roadmap

- ✅ v1.1 — Core skills, anti-placeholder, per-phase checkpoints
- ✅ v1.2 — Cross-project KB, power-peer design, tiered review, hard gates (THIS release)
- 🔜 v1.3 — Semantic KB search (Qdrant backend swap)
- 🔮 v2.0 — Multi-IDE support (Cursor, Codex)

---

## Comparison vs Superpowers

gaspol-dev overlaps 60% dengan superpowers (both inspired by structured workflow discipline). Key differentiators:

| | gaspol-dev | superpowers |
|---|---|---|
| Anti-placeholder rules | Explicit + enforced | Implicit |
| Cross-project memory | ✓ (KB + git sync) | ✗ |
| Research grounding | Tiered + cached + freshness | ✗ |
| Design intelligence | Power peer ui-ux-pro-max | ✗ |
| Model switching | Auto-rubric | ✗ |
| Step-level closure gate | ✓ Evidence-based | Phase-level |
| Multi-IDE | Claude Code only | 5 IDEs |

Pick gaspol if: deep integration with Claude Code + cross-project learning + process enforcement > breadth.
Pick superpowers if: multi-IDE is critical + you already have external KB.

---

## Credits

Design intelligence data partially forked dari [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (MIT).
Workflow patterns inspired by [superpowers](https://github.com/obra/superpowers).

---

## License

MIT © Ali Sadikin Ma
```

Key elements yang bikin convincing:
1. **Hero message** — langsung jabab "why should I care" dalam 1 kalimat
2. **Problem framing** — concrete pain points (placeholder, skipped steps, no memory) — user nod
3. **Differentiation table** — vs advisory/generic alternatives — jelas what's unique
4. **Skills organized by workflow** — bukan flat list (easier to scan)
5. **Real example** (compounding knowledge) — shows concrete value, bukan abstract
6. **Comparison vs superpowers** — honest framing (60% overlap, specific differentiators) — bikin trust
7. **Roadmap** — show velocity + direction
8. **Credits** — acknowledge forks/inspiration (builds credibility + good FOSS citizen)

#### 11.3 Implementation Strategy

Update ordering (dependencies):
1. **After all code changes** (Poin 1-10) → baru update CLAUDE.md karena harus reflect actual state
2. CLAUDE.md update via `gaspol-sync-docs` Mode 1 (post-implementation sync)
3. README.md overhaul manual/semi-automated — extract from CLAUDE.md + add marketing layer

Split jadi 2 PR / commits supaya bisa review separately:
- Commit A: CLAUDE.md updates (reflect code state)
- Commit B: README.md overhaul (new content, marketing angle)

#### 11.4 Impact

- **CLAUDE.md accurate** → next session (ou user) dapat context yang benar
- **README.md convincing** → growth lever, plugin adoptable by others beyond personal use
- **Credits proper** → OSS-friendly, builds community trust

---

## Data Integration Map

| Feature | Data Source | Hook/API/Tool | Exists? | Action Required |
|---|---|---|---|---|
| Plan file read/write | Filesystem | Read, Write, Edit tools | ✓ | Update naming convention |
| Plan detection (single file vs split) | Filesystem | Glob + file size check | ✓ | Add helper logic |
| Review dispatch | Subagent | Agent tool + code-reviewer.md | ✓ | Add complexity classifier + auto-trigger |
| Diff classification | Git | `git diff --stat` | ✓ | Parse output for files/LoC count |
| Model override | Agent tool | `model` param | ✓ (Claude Code supports) | Update frontmatter + dispatch calls |
| KB repo on GitHub | GitHub | `gh` CLI + git | Need `gh repo create` | One-time setup |
| KB local clone | Filesystem | git clone | Needs init | Script + gaspol-kickstart check |
| KB query (Phase 0.5) | Filesystem grep | Grep tool | ✓ | Add Phase 0.5 to brainstorm |
| KB capture (gaspol-learn) | Filesystem + git | Write, Bash (git add/commit/push) | ✓ | New skill |
| Research sources | Web | WebFetch, WebSearch | ✓ | Orchestrate in gaspol-research |
| Research cache | KB filesystem | Write + git | Needs KB ready | Part of gaspol-research skill |
| ADR capture | KB filesystem | Write + git | Needs KB ready | Part of gaspol-adr skill |
| Autonomous loop | Agent orchestration | Agent tool iterative | ✓ | Add loop + guard conditions in gaspol-auto |
| Checkpoint modal | AskUserQuestion | Modal tool | ✓ | Extend existing checkpoint template |
| Offline fallback | Filesystem queue | `.pending-push` dir | N/A | Simple FS + retry logic |
| Session context load (kickstart) | CLAUDE.md + KB INDEX.md | Read + Bash (git pull) | ✓ | Hook invoke trigger + skill rewrite |
| Design trigger (expanded) | Keyword list + file-ext patterns | Regex match on user message + plan output | ✓ | Update brainstorm Phase 3 logic |
| TDD gate validation | Plan phase text | Regex "Write failing test" in phase step 1 | ✓ | Update execute Step 2 + plan template |
| Worktree auto-offer | Plan phase count + keywords | Read plan + classify | ✓ | Update plan Phase 6 + brainstorm handoff |
| Consolidation (dispatch→parallel) | Skill directory | Filesystem delete + Edit SKILL.md | ✓ | Merge content, add mode param |
| Novelty assessment (Phase 1.5) | KB research/ + CLAUDE.md | Grep + Read | ✓ | New phase di brainstorm |
| Light WebSearch (semi-new tier) | Web | WebSearch (2-3 query) | ✓ | Inline di Phase 1.5 |
| Deep research dispatch | Web + subagents | Agent tool + gaspol-research skill | ✓ | New skill (Poin 5.1) |
| Research quality gate enforcement | Research output | Agent self-check + orchestrator audit | ✓ | Prompt constraints di gaspol-research |
| Step-level plan parse | Plan file | Read + regex | ✓ | Upgrade plan-verifier logic |
| Evidence quote verification | Diff + code files | Read + grep | ✓ | Plan-verifier prompt update |
| Freshness tier calculation | Research metadata | Date diff from researched_at | ✓ | Logic di Phase 1.5 + INDEX.md render |
| Mini-research (verify freshness) | Cache sources + web | WebSearch targeted | ✓ | Part of gaspol-research skill |
| Research superseding/archival | KB filesystem | Write + git commit | ✓ | Part of gaspol-research skill |
| Orchestrator FOUND audit | Plan-verifier output | Read random samples + verify quote | ✓ | Post-hoc Opus audit step |
| Design data (styles/palettes/fonts/charts/guidelines) | Forked CSV | Read + scripts/search.py | Need to create | One-time fork + attribution |
| Design system generation | Own engine + optional v2.0 bridge | `design-system-gen.py` + `ui-ux-pro-max-bridge.py` | Need to build | Phase B+E of impl strategy |
| Design deliverable per UI phase | Plan template extension | Plan YAML + invoke gaspol-design | ✓ | Phase F of impl strategy |
| Design fidelity scan | Codebase vs design spec | `design-audit.py` + AST/regex parse | Need to build | Phase G+J |
| Multi-framework templates | Forked + adapted templates | Template files + scripts | Need to create | Phase C |
| UI pattern learning | `gaspol-learn` output | Write to KB + INDEX.md | ✓ | Part of gaspol-learn (Poin 5) |
| KB entry status lifecycle | YAML frontmatter per entry | Read/Write frontmatter | ✓ | Add status field to all capture skills |
| KB audit | Filesystem scan | `gaspol-kb-audit` skill | Need to create | New skill (Poin 10.2) |
| Capture quality gate | Content rules | Gaspol-learn pre-commit validation | ✓ | Update gaspol-learn logic |
| Anti-precedent mechanism | User input | AskUserQuestion at precedent surface | ✓ | Update brainstorm Phase 0.5 |
| Divergence ADR | KB write | Part of gaspol-adr skill | ✓ | Extend gaspol-adr behavior |
| KB health metrics | Aggregate scan | Part of gaspol-kb-audit | Need to create | New skill (Poin 10.6) |
| CLAUDE.md sync post-refactor | CLAUDE.md file | Read + Edit | ✓ | Run gaspol-sync-docs Mode 1 (post-implementation) |
| README.md overhaul | README.md file | Write | ✓ | Manual draft + validate |

## Implementation Feasibility Check

**Yang sudah bisa dengan tools existing:**
- File read/write/edit → ✓
- Git operations via Bash → ✓
- Agent dispatch dengan model override → ✓
- Grep search in filesystem → ✓
- WebFetch + WebSearch untuk research → ✓
- AskUserQuestion modal → ✓

**Yang butuh setup eksternal:**
- GitHub repo `alisadikinma/gaspol-knowledge` → `gh repo create` one-time
- `gh` CLI tersedia di PATH → check `which gh`; kalau tidak ada, fallback instruction untuk manual create via web
- SSH key untuk GitHub → assumed existing (user sudah pakai git-based workflow)

**Yang butuh user decision during setup:**
- Apakah pakai SSH atau HTTPS untuk clone (preferensi user)
- Initial content KB (kosong) vs seed dari existing projects (bisa dibantu migrasi via future skill)

**Risiko implementasi:**
- ⚠️ Complexity classifier false positive/negative — mitigasi: adjustable threshold via config
- ⚠️ gaspol-auto hard-stop coverage incomplete — mitigasi: conservative trigger list, opt-in not default
- ⚠️ ADR auto-generation dari vague brainstorm input jadi noise — mitigasi: minimum criteria (2+ options considered, explicit reasoning given)
- ⚠️ KB grow tanpa batas — mitigasi: future `gaspol-prune` skill (out of scope v1.2.0)

## Out of Scope (Explicit)

Yang TIDAK dikerjakan di improvement round ini:

- **Full AI Brain stack** (Qdrant + Obsidian + Graphify + MCP HTTP) — separate standalone personal infrastructure project per MASTER-PLAN-AI-BRAIN.md
- **Semantic embedding search** — grep + tagged INDEX.md sufficient untuk Phase 1; future upgrade kalau grep terbukti insufficient
- **Multi-IDE support** (Cursor, Gemini, Copilot CLI, Codex) — separate effort, low priority untuk saat ini
- **n8n managed agent integration** — tergantung hasil AI Brain project
- **Real-time sync** (Syncthing peer-to-peer) — git async sync sudah sufficient, zero kompleksitas tambahan
- **Multi-tenant KB** (share dengan collaborator) — personal KB only untuk v1.2.0
- **KB pruning / archive / consolidation** — tumbuh dulu, prune nanti (YAGNI)
- **Automatic supersession detection antar ADR** — manual review by user

## Success Criteria (post-implementation)

- [ ] Single file hybrid default bekerja: brainstorm + plan append ke same file
- [ ] Split trigger berfungsi di >500 lines OR explicit flag
- [ ] Complexity classifier correctly identifies: docs-only skip, config-only skip, new feature trigger, rename skip
- [ ] Auto-review fires di phase yang benar, skip di trivial phase
- [ ] Model rubric applied: ≥80% dispatches pakai Sonnet/Haiku, ~20% Opus (verified via test run)
- [ ] KB repo live at `alisadikinma/gaspol-knowledge`, accessible from 2+ devices
- [ ] Phase 0.5 in brainstorm pulls KB, greps INDEX, surfaces matches
- [ ] `gaspol-learn` captures pattern → commit → push → visible at GitHub
- [ ] `gaspol-research` run produces cached file di `research/`
- [ ] `gaspol-auto` completes small feature plan end-to-end tanpa interrupt (success path)
- [ ] `gaspol-auto` hard-stops at test failure (sad path)
- [ ] `gaspol-adr` generates MADR-compliant file dengan link to supersede
- [ ] CLAUDE.md updated dengan rubric + new skills + KB architecture
- [ ] All existing skills backward-compatible (existing plan files still work)
- [ ] `hooks/session-start.sh` triggers gaspol-kickstart invocation properly
- [ ] gaspol-kickstart surfaces top-3 relevant KB entries at session start
- [ ] gaspol-design triggers on expanded keyword set (test: "update tombol form")
- [ ] gaspol-design self-sufficient dengan forked data (67+ styles, 161+ palettes, 57+ fonts, 25+ charts, 99+ UX guidelines)
- [ ] gaspol-design bridge ke ui-ux-pro-max v2.0 works kalau installed (graceful fallback kalau tidak)
- [ ] gaspol-design terlibat di gaspol-plan (plan template has design deliverable column)
- [ ] gaspol-design terlibat di gaspol-execute (fidelity check per UI phase)
- [ ] gaspol-design terlibat di gaspol-verify Layer 4 (design compliance sub-check)
- [ ] gaspol-learn extract UI patterns ke `gaspol-knowledge/ui-patterns/` setelah gaspol-finish
- [ ] Multi-framework templates exist untuk 10 frameworks (React, Vue, Next, Laravel, SwiftUI, Flutter, HTML+Tailwind, shadcn/ui, Astro, Svelte)
- [ ] License attribution proper di SKILL.md + NOTICE.md
- [ ] gaspol-execute refuses to run phase without TDD step 1
- [ ] gaspol-dispatch directory deleted, gaspol-parallel accepts mode param
- [ ] gaspol-plan auto-offers worktree with smart default
- [ ] gaspol-brainstorm Phase 1.5 classifies novelty (precedent/semi-new/new)
- [ ] gaspol-research output cached to KB dengan full metadata + TTL
- [ ] Phase 1.5 surfaces freshness tier (🟢🟡🟠🔴) saat cache hit
- [ ] AMBER tier offers verify-freshness mini-research
- [ ] plan-verifier step-level audit with code quote evidence
- [ ] plan-verifier BLOCKING at end of gaspol-execute (MISSING > 0 = fail)
- [ ] plan-verifier BLOCKING at gaspol-finish pre-chain
- [ ] Orchestrator spot-check sample 3 FOUND items per audit run
- [ ] INDEX.md entries include freshness badge (age + emoji tier)
- [ ] All KB entries have status field (proposed/accepted/superseded/deprecated)
- [ ] gaspol-kb-audit skill generates audit report on-demand
- [ ] Capture quality gate rejects junk captures (<200 words, no tags, duplicate, no source)
- [ ] Anti-precedent option visible di Phase 0.5 KB query surface
- [ ] Divergence ADR captured when user overrides precedent
- [ ] KB health metrics tracked (stale %, duplicates %, broken refs %)
- [ ] CLAUDE.md updated to reflect 13 skills (removed kickstart/dispatch/worktree)
- [ ] CLAUDE.md has new sections: Cross-Project KB, Model Switching Rubric, Research Grounding, Design Intelligence (power peer), Closure Gate, KB Self-Maintenance
- [ ] CLAUDE.md version bumped to 1.2.0
- [ ] README.md overhauled with: hero message, problem framing, differentiation table, skills-by-workflow, real compounding example, architecture diagram, roadmap, vs-superpowers comparison, credits
- [ ] License attribution proper for forked ui-ux-pro-max data

## Next Step

Ready untuk proceed ke `gaspol-plan` → append `## Implementation Plan` section ke file ini dengan:
- Phase breakdown (TDD-first, bite-sized 2-5 min steps)
- Per-phase verification criteria
- Data Integration Map confirmation per step
- Dependency graph antar skill changes
- Rollback plan per phase

---

## Implementation Plan

> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **ANTI-BOOTSTRAP NOTE:** This plan ITSELF implements Poin 1 (hybrid file structure),
> Poin 6.3 (TDD hard gate), Poin 8 (closure gate) — so during execution, existing
> gaspol-execute behavior applies, but the upgraded behavior only takes effect AFTER
> the phases that build them. Execute sequentially per dependency graph.

## Goal

Ship gaspol-dev v1.2.0 dengan 11 improvement areas implemented: remove 3 unused skills, add 5 new skills, upgrade gaspol-design to power peer, add cross-project KB, tiered auto-review, auto-rubric model switching, industry research grounding, step-level closure gate, KB lifecycle self-maintenance, plus comprehensive CLAUDE.md + convincing README.md. Final state: 13 skills (down from 16), 1 consolidated (parallel absorbs dispatch), 1 power-peer (design), 5 net new.

## Architecture Context (from CLAUDE.md)

- Plugin root: `d:\Projects\claude-plugin\gaspol-dev\`
- Skill directories: `skills/gaspol-<name>/SKILL.md` pattern
- Agents: `agents/<kebab-case>.md`
- Hooks: `hooks/session-start.sh` + `hooks/hooks.json`
- Plugin metadata: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Existing workflow chain: `brainstorm → plan → execute → verify → sync-docs → review → finish`
- Claude Code supports `model` param per Agent dispatch (Opus 4.7, Sonnet 4.6, Haiku 4.5)
- AskUserQuestion tool mandatory for confirmations (CLAUDE.md line ~45)

## Tech Stack

- Markdown (all SKILL.md, agents, docs)
- Bash (hook scripts, git operations)
- Python 3 (gaspol-design data search/generation scripts — new)
- JSON (plugin metadata, hooks config)
- Git + GitHub CLI (`gh`) for KB repo management
- No new runtime dependencies (all operations via existing Claude Code tools)

## Data Integration Map

See full table in spec above (Data Integration Map section). Plan references existing entries.

Critical contract points:
- **GitHub repo** `alisadikinma/gaspol-knowledge` — doesn't exist yet → Phase A creates via `gh repo create`
- **Agent model overrides** — Claude Code supports → Phase C updates frontmatter
- **Plan-verifier step-level parsing** — regex + Read on plan files → Phase D new logic
- **ui-ux-pro-max fork** — needs license verification → Phase M check first
- **Design audit codebase scan** — AST via regex/grep → Phase N build script

## Dependency Graph

```
A: KB Foundation ──┐
                   ├──► E: Hard Gates ──► F: Tiered Review
B: Skill Removals ─┤                          │
                   │                          ▼
C: Model Rubric ───┤                    G: Hybrid File Structure
                   │                          │
D: Plan-Verifier ──┘                          ▼
                                        H-L: 5 New Skills (TDD)
                                              │
                                              ▼
                              M-P: gaspol-design Power Peer
                                              │
                                              ▼
                              Q: Parallel Consolidation
                                              │
                                              ▼
                              R: Brainstorm Phase 0.5/1.5/2.5
                                              │
                                              ▼
                              S: KB Lifecycle
                                              │
                                              ▼
                              T: CLAUDE.md Update
                                              │
                                              ▼
                              U: README.md Overhaul
```

Phases A-D can run in parallel (no shared files, no state dep).
Phases H-L can run in parallel (independent new skills).
Phases M-P sequential (design builds on itself).
Q-U sequential (each depends on prior state).

---

### Phase A: KB Repo Foundation

**Estimated time:** 12 minutes
**Dependencies:** None
**Blocks:** H (gaspol-research), J (gaspol-learn), K (gaspol-kb-audit), R (Phase 0.5)

**Files:**
- Create (remote): `github.com/alisadikinma/gaspol-knowledge` (private)
- Create (local): `~/.claude/gaspol-knowledge/INDEX.md`
- Create (local): `~/.claude/gaspol-knowledge/{ui-patterns,architecture,design-decisions,research,reusable-snippets}/.gitkeep`
- Create (local): `~/.claude/gaspol-knowledge/README.md`
- Create (local): `~/.claude/gaspol-config.json` (kb_remote config)

**Steps:**
1. Run `gh auth status` to verify GitHub CLI auth (2 min)
2. Run `gh repo create alisadikinma/gaspol-knowledge --private --description "Gaspol cross-project knowledge base"` (2 min)
3. Create local directory `~/.claude/gaspol-knowledge/` and clone repo (2 min)
4. Write `INDEX.md` template dengan frontmatter schema + empty entries list (3 min)
5. Create 5 category subdirectories dengan `.gitkeep` placeholder (1 min)
6. Write `README.md` untuk KB repo explaining structure (3 min)
7. Write `~/.claude/gaspol-config.json` dengan `{"kb_remote": "git@github.com:alisadikinma/gaspol-knowledge.git", "kb_local": "~/.claude/gaspol-knowledge"}` (2 min)
8. Initial commit + push (2 min)

**Verification:**
- [ ] `gh repo view alisadikinma/gaspol-knowledge` returns repo
- [ ] Local clone exists at `~/.claude/gaspol-knowledge/`
- [ ] All 5 category directories present
- [ ] INDEX.md has valid frontmatter schema
- [ ] `git pull` from local clone succeeds

---

### Phase B: Remove 3 Deprecated Skills

**Estimated time:** 10 minutes
**Dependencies:** None
**Blocks:** T (CLAUDE.md update references)

**Files:**
- Delete: `skills/gaspol-kickstart/` (entire directory)
- Delete: `skills/gaspol-dispatch/` (entire directory — content will be absorbed by parallel in Phase Q)
- Delete: `skills/gaspol-worktree/` (entire directory)
- Modify: `hooks/session-start.sh` (remove 3 skill names from echo list)
- Modify: `.claude-plugin/plugin.json` (if lists skills explicitly)
- Modify: `.claude-plugin/marketplace.json` (if lists skills explicitly)

**Steps:**
1. Backup: `git checkout -b feat/v1.2-improvements` (2 min)
2. Delete `skills/gaspol-kickstart/` directory (1 min)
3. Delete `skills/gaspol-worktree/` directory (1 min)
4. Keep `skills/gaspol-dispatch/` content intact temporarily (will be absorbed in Phase Q, then deleted) (1 min)
5. Edit `hooks/session-start.sh`: remove `gaspol-kickstart` and `gaspol-worktree` from echoed list (2 min)
6. Read `.claude-plugin/plugin.json` — if skills listed, remove 2 entries (2 min)
7. Read `.claude-plugin/marketplace.json` — same check (1 min)
8. Commit: `chore: remove gaspol-kickstart and gaspol-worktree (YAGNI)` (1 min)

**Verification:**
- [ ] `skills/gaspol-kickstart/` does not exist
- [ ] `skills/gaspol-worktree/` does not exist
- [ ] Hook echo output has 14 skill names (16 - 2, dispatch still present)
- [ ] Plugin loads without error (test: `claude plugin list` shows gaspol-dev)

---

### Phase C: Model Rubric Rollout

**Estimated time:** 15 minutes
**Dependencies:** None
**Blocks:** D (plan-verifier uses rubric), H-L (new skills use rubric in dispatches)

**Files:**
- Modify: `agents/code-reviewer.md` (add `model: sonnet` frontmatter)
- Modify: `agents/code-simplifier.md` (add `model: haiku` — simple refactor)
- Modify: `agents/plan-verifier.md` (add `model: opus` — spec-level)
- Modify: `agents/spec-reviewer.md` (add `model: opus` — spec-level)
- Modify: `skills/gaspol-execute/implementer-prompt.md` (dispatch with `model: sonnet`)
- Modify: `skills/gaspol-parallel/spec-reviewer-prompt.md` (dispatch with `model: opus`)
- Modify: `skills/gaspol-parallel/code-quality-reviewer-prompt.md` (dispatch with `model: sonnet`)
- Create: `docs/rubric-model-switching.md` (reference table for future skill authors)

**Steps:**
1. Read each agent file, check for existing frontmatter (3 min)
2. Add `model: sonnet` to `code-reviewer.md` frontmatter (1 min)
3. Add `model: haiku` to `code-simplifier.md` frontmatter (1 min)
4. Add `model: opus` to `plan-verifier.md` frontmatter (1 min)
5. Add `model: opus` to `spec-reviewer.md` frontmatter (1 min)
6. Update implementer-prompt.md: dispatch call includes `model: sonnet` (2 min)
7. Update parallel prompts with appropriate models (2 min)
8. Write `docs/rubric-model-switching.md` with full rubric table from spec section 3 (3 min)
9. Commit: `feat: add auto-rubric model switching per agent/dispatch` (1 min)

**Verification:**
- [ ] All 4 agent files have `model` frontmatter
- [ ] implementer-prompt.md references sonnet
- [ ] Rubric doc exists and lists all 9 task types
- [ ] Test dispatch: run gaspol-review on a test commit — code-reviewer fires with Sonnet

---

### Phase D: Plan-Verifier Step-Level Upgrade

**Estimated time:** 14 minutes
**Dependencies:** C (model rubric for Opus)
**Blocks:** E (hard-gate uses upgraded verifier)

**Files:**
- Rewrite: `agents/plan-verifier.md` (step-level + evidence-based logic)

**Steps:**
1. Read existing `agents/plan-verifier.md` fully to understand current behavior (2 min)
2. Draft new verifier logic section: parse plan into granular items (every bullet, not phase) (3 min)
3. Add verdict taxonomy (FOUND/PARTIAL/MISSING/DIVERGED) with required code quote per FOUND (2 min)
4. Add output format template per spec 8.1 (3 min)
5. Add anti-hallucination instruction: "Orchestrator spot-checks 3 random FOUND items for quote accuracy" (2 min)
6. Commit: `feat: upgrade plan-verifier to step-level evidence-based audit` (2 min)

**Verification:**
- [ ] plan-verifier.md has `model: opus` frontmatter
- [ ] Output format template exists with all 4 verdicts
- [ ] Anti-hallucination instruction present
- [ ] Spot-check rule explicit (min 3 random FOUND items)

---

### Phase E: Hard Gates Integration

**Estimated time:** 15 minutes
**Dependencies:** D (upgraded plan-verifier)
**Blocks:** F (tiered review integrates), T (CLAUDE.md reflects)

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md` (Step 7 completion — add blocking plan-verifier)
- Modify: `skills/gaspol-execute/SKILL.md` (Step 2 — add TDD step 1 validation)
- Modify: `skills/gaspol-execute/implementer-prompt.md` (enforce TDD step 1)
- Modify: `skills/gaspol-finish/SKILL.md` (pre-chain — plan-verifier BLOCKING)
- Modify: `skills/gaspol-plan/SKILL.md` (plan phase template WAJIB punya test step 1)

**Steps:**
1. Read current gaspol-execute Step 2 logic (2 min)
2. Add TDD validation: check phase description contains `"Write failing test for..."` in step 1. If missing → emit error + AskUserQuestion (3 min)
3. Update Step 7 to run plan-verifier after completion gate; MISSING>0 or unapproved PARTIAL>0 = BLOCKING (3 min)
4. Update implementer-prompt.md with hard instruction: "Phase step 1 MUST be failing test" (2 min)
5. Update gaspol-finish pre-chain: add plan-verifier as blocker before presenting options (3 min)
6. Update gaspol-plan template: explicit phase step 1 format "1. Write failing test for [behavior]. Expected error: ..." (1 min)
7. Commit: `feat: add hard gates for TDD + plan-verifier in execute/finish` (1 min)

**Verification:**
- [ ] gaspol-execute Step 2 has TDD validation logic
- [ ] gaspol-execute Step 7 calls plan-verifier blocking
- [ ] gaspol-finish pre-chain calls plan-verifier blocking
- [ ] gaspol-plan template enforces TDD step 1
- [ ] Test scenario: phase without "Write failing test" → execute refuses to run (manual test in sandbox plan)

---

### Phase F: Tiered Auto-Review

**Estimated time:** 12 minutes
**Dependencies:** E (hard gates established)

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md` (add complexity classifier + auto-review per phase)
- Modify: `skills/gaspol-execute/checkpoint-template.md` (add Auto-Review section)

**Steps:**
1. Read current checkpoint-template.md (1 min)
2. Add classify_phase_complexity logic to execute: files_changed>3 OR LoC>100 OR new-feature-keyword → `review`; docs-only OR config-only OR rename → `skip` (3 min)
3. Update checkpoint template with Auto-Review block (2 min)
4. Add dispatch of code-reviewer when classify = `review`, inline review summary in checkpoint (3 min)
5. Update AskUserQuestion options di checkpoint modal: add "Address review feedback" (2 min)
6. Commit: `feat: tiered auto-review per-phase based on complexity` (1 min)

**Verification:**
- [ ] Classifier logic documented in SKILL.md
- [ ] Checkpoint template has Auto-Review section
- [ ] Modal options updated
- [ ] Manual test: simulate 2-file docs-only phase → classify = skip; simulate 5-file new component phase → classify = review

---

### Phase G: Hybrid File Structure for Plans

**Estimated time:** 10 minutes
**Dependencies:** None (structural change)

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md` (Phase 6 filename drop `-design` suffix)
- Modify: `skills/gaspol-plan/SKILL.md` (detect existing file + append logic)

**Steps:**
1. Read gaspol-brainstorm Phase 6 current text (1 min)
2. Change filename pattern from `YYYY-MM-DD-<topic>-design.md` to `YYYY-MM-DD-<topic>.md` (1 min)
3. Read gaspol-plan "Save Plans To" section (1 min)
4. Update gaspol-plan logic: before writing, check if `YYYY-MM-DD-<topic>.md` exists; if yes → append `## Implementation Plan` section; if no → create new file with full structure (3 min)
5. Add split condition documentation: file >500 lines OR user --split flag (2 min)
6. Commit: `feat: hybrid file structure for brainstorm+plan outputs` (2 min)

**Verification:**
- [ ] Brainstorm Phase 6 produces filename without -design suffix
- [ ] Plan skill appends to existing file if found
- [ ] Split condition documented
- [ ] Test: run brainstorm on dummy topic → plan appends to same file correctly

---

### Phase H: gaspol-research Skill (TDD: RED-GREEN-REFACTOR)

**Estimated time:** 20 minutes (3 sub-phases)
**Dependencies:** A (KB repo), C (model rubric)

**Files:**
- Create: `skills/gaspol-research/SKILL.md`
- Create: `skills/gaspol-research/research-template.md` (output format template)
- Create: `skills/gaspol-research/freshness-rules.md` (TTL lifecycle reference)

#### H.1 RED: Baseline Failure Documentation (5 min)

**Steps:**
1. Write pressure scenario: "Evaluate React state management libs for new project" (1 min)
2. Simulate agent response without skill — document failures: cites from training memory, no sources, no freshness check (2 min)
3. Save failure notes as working doc (for REFACTOR phase loopback) (2 min)

**Verification:**
- [ ] Failure modes documented: no citations, no cache check, no freshness lifecycle

#### H.2 GREEN: Write SKILL.md (12 min)

**Steps:**
1. Write frontmatter with `description` starting "Use when..." (2 min)
2. Write Iron Law + Core Principle (2 min)
3. Write research flow: scope → check cache → parallel dispatch (Sonnet) → synthesize (Opus) → cache → INDEX update (3 min)
4. Write research quality gates (multi-source, recency, signal filter, anti-pattern, citation mandatory) (3 min)
5. Write freshness lifecycle per spec 9.2 (TTL tiers) (2 min)

**Verification:**
- [ ] SKILL.md loads without error
- [ ] All quality gates documented
- [ ] Lifecycle section includes all 4 tiers

#### H.3 REFACTOR: Close Loopholes (3 min)

**Steps:**
1. Re-test with pressure scenario — does agent follow? (1 min)
2. Close loopholes: explicit "every FOUND claim needs URL" rule (1 min)
3. Commit: `feat: add gaspol-research skill with freshness-aware cache` (1 min)

**Verification:**
- [ ] Re-test produces sourced output
- [ ] No fabricated citations detected

---

### Phase I: gaspol-adr Skill

**Estimated time:** 14 minutes
**Dependencies:** A (KB repo)

**Files:**
- Create: `skills/gaspol-adr/SKILL.md`
- Create: `skills/gaspol-adr/madr-template.md` (MADR-compliant frontmatter + body template)

**Steps:**
1. RED: simulate decision capture without skill — document drift (3 min)
2. Write SKILL.md with trigger points (brainstorm Phase 2, plan architectural fork) (3 min)
3. Write MADR template file with status lifecycle + supersession + divergence support (3 min)
4. Add cross-brainstorm surfacing logic (grep design-decisions/ by tags) (2 min)
5. REFACTOR: test with pressure scenario, close loopholes (2 min)
6. Commit: `feat: add gaspol-adr skill for architectural decision capture` (1 min)

**Verification:**
- [ ] SKILL.md loads
- [ ] MADR template has all required fields (id, status, supersedes, superseded_by)
- [ ] Auto-trigger points documented

---

### Phase J: gaspol-learn Skill

**Estimated time:** 16 minutes
**Dependencies:** A (KB repo), I (ADR reference)

**Files:**
- Create: `skills/gaspol-learn/SKILL.md`
- Create: `skills/gaspol-learn/capture-quality-gate.md` (validation rules)

**Steps:**
1. RED: document how patterns lose without skill (3 min)
2. Write SKILL.md: capture flow triggered by gaspol-finish (3 min)
3. Write quality gate rules: min 200 words, min 2 tags, duplicate detection, source citation for research (3 min)
4. Add user confirmation step via AskUserQuestion before commit (2 min)
5. Write `.rejected-log` mechanism for failed captures (2 min)
6. REFACTOR + test (2 min)
7. Commit: `feat: add gaspol-learn skill with quality gate` (1 min)

**Verification:**
- [ ] SKILL.md loads
- [ ] Quality gate rules explicit
- [ ] AskUserQuestion pre-commit exists
- [ ] Rejected log mechanism documented

---

### Phase K: gaspol-kb-audit Skill

**Estimated time:** 15 minutes
**Dependencies:** A (KB repo), J (learn — audit validates learn output)

**Files:**
- Create: `skills/gaspol-kb-audit/SKILL.md`
- Create: `skills/gaspol-kb-audit/audit-report-template.md`

**Steps:**
1. RED: simulate KB with stale/duplicate entries — document issues unnoticed (3 min)
2. Write SKILL.md: audit triggers (manual, quarterly, size-based) (2 min)
3. Write audit checks: stale, conflicting, orphan, duplicate, broken refs (4 min)
4. Write report generation logic + AskUserQuestion per finding (3 min)
5. REFACTOR + commit: `feat: add gaspol-kb-audit skill for KB health maintenance` (3 min)

**Verification:**
- [ ] SKILL.md loads
- [ ] All 5 audit checks documented
- [ ] Report template exists

---

### Phase L: gaspol-auto Skill

**Estimated time:** 16 minutes
**Dependencies:** E (hard gates), F (tiered review)

**Files:**
- Create: `skills/gaspol-auto/SKILL.md`

**Steps:**
1. RED: simulate autonomous exec without guardrails — document drift/destruction (3 min)
2. Write SKILL.md: pre-flight (clean git, tests pass, plan approval) (3 min)
3. Write execution loop with hard-stop conditions (test fail, placeholder trigger, destructive op, ambiguity, Iron Law, 3+ consecutive errors) (4 min)
4. Write post-run consolidated report logic + auto-trigger verify + review (3 min)
5. REFACTOR + commit: `feat: add gaspol-auto skill for autonomous execution` (3 min)

**Verification:**
- [ ] SKILL.md loads
- [ ] Hard-stop conditions all 6 documented
- [ ] Pre-flight gate explicit (AskUserQuestion)

---

### Phase M: gaspol-design Foundation

**Estimated time:** 14 minutes
**Dependencies:** None (license-sensitive first step)

**Files:**
- Check: `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` LICENSE
- Create: `skills/gaspol-design/data/styles.csv` (forked)
- Create: `skills/gaspol-design/data/palettes.csv`
- Create: `skills/gaspol-design/data/typography.csv`
- Create: `skills/gaspol-design/data/charts.csv`
- Create: `skills/gaspol-design/data/ux-guidelines.csv`
- Create: `skills/gaspol-design/NOTICE.md` (attribution)

**Steps:**
1. WebFetch ui-ux-pro-max-skill LICENSE file to confirm MIT (2 min)
2. Fork CSV: styles.csv (2 min)
3. Fork CSV: palettes.csv (2 min)
4. Fork CSV: typography.csv (2 min)
5. Fork CSV: charts.csv (1 min)
6. Fork CSV: ux-guidelines.csv (1 min)
7. Write NOTICE.md dengan MIT attribution (2 min)
8. Commit: `feat(design): fork ui-ux-pro-max stable data with MIT attribution` (2 min)

**Verification:**
- [ ] License confirmed compatible (MIT or equivalent permissive)
- [ ] All 5 CSV files exist with non-empty content
- [ ] NOTICE.md has proper attribution format per spec 6.2.7

---

### Phase N: gaspol-design Engine

**Estimated time:** 22 minutes
**Dependencies:** M

**Files:**
- Create: `skills/gaspol-design/scripts/search.py`
- Create: `skills/gaspol-design/scripts/design-system-gen.py`
- Create: `skills/gaspol-design/scripts/design-audit.py`
- Create: `skills/gaspol-design/rules/reasoning-core.md` (fork + adapt)
- Create: `skills/gaspol-design/rules/reasoning-gaspol.md` (new: project-context rules)
- Create: `skills/gaspol-design/rules/anti-ai-slop.md` (hard rules)
- Create: `skills/gaspol-design/integration/ui-ux-pro-max-bridge.py` (optional delegate)

**Steps:**
1. Write `search.py` core: CSV read + filter by domain + score (5 min)
2. Write `design-system-gen.py`: full system generation from request + constraints (5 min)
3. Write `design-audit.py`: scan codebase vs design system, detect drift (4 min)
4. Fork + adapt reasoning-core.md from ui-ux-pro-max (3 min)
5. Write reasoning-gaspol.md: project-context rules (reads CLAUDE.md tokens) (2 min)
6. Write anti-ai-slop.md: hard enforcement rules (Inter ban, purple-gradient ban, dsb) (1 min)
7. Write bridge.py: detect v2.0 install, call scripts, fallback (1 min)
8. Commit: `feat(design): reasoning engine + rules + optional v2.0 bridge` (1 min)

**Verification:**
- [ ] All 3 scripts execute without syntax errors (`python3 script.py --help`)
- [ ] Rules files structured + enforce-able
- [ ] Bridge has graceful fallback (no crash if v2.0 absent)

---

### Phase O: gaspol-design Multi-Framework Templates

**Estimated time:** 20 minutes
**Dependencies:** N

**Files:**
- Create: `skills/gaspol-design/templates/react-tsx/component-template.tsx`
- Create: `skills/gaspol-design/templates/vue/component-template.vue`
- Create: `skills/gaspol-design/templates/next/page-template.tsx`
- Create: `skills/gaspol-design/templates/laravel-blade/component.blade.php`
- Create: `skills/gaspol-design/templates/swiftui/ComponentTemplate.swift`
- Create: `skills/gaspol-design/templates/flutter/component_template.dart`
- Create: `skills/gaspol-design/templates/html-tailwind/component-template.html`
- Create: `skills/gaspol-design/templates/shadcn-ui/component-template.tsx`
- Create: `skills/gaspol-design/templates/astro/ComponentTemplate.astro`
- Create: `skills/gaspol-design/templates/svelte/ComponentTemplate.svelte`

**Steps:**
1. Write react-tsx template with typed props + design tokens hooks (2 min)
2. Write vue template with composition API (2 min)
3. Write next template with server component option (2 min)
4. Write laravel blade component (2 min)
5. Write swiftui template (2 min)
6. Write flutter template (2 min)
7. Write html+tailwind template (2 min)
8. Write shadcn-ui template (variant system) (2 min)
9. Write astro template (2 min)
10. Write svelte template (1 min)
11. Commit: `feat(design): add multi-framework component templates` (1 min)

**Verification:**
- [ ] All 10 template files present
- [ ] Each template references design tokens (not hardcoded)
- [ ] Framework-specific idioms used (not copy-paste between)

---

### Phase P: gaspol-design SKILL.md + Chain Integration

**Estimated time:** 18 minutes
**Dependencies:** N, O

**Files:**
- Rewrite: `skills/gaspol-design/SKILL.md`
- Modify: `skills/gaspol-brainstorm/SKILL.md` (enhanced Phase 3 triggers + Phase 2.5 gate)
- Modify: `skills/gaspol-plan/SKILL.md` (design deliverable column in plan template)
- Modify: `skills/gaspol-execute/SKILL.md` (design fidelity check per UI phase)
- Modify: `skills/gaspol-verify/SKILL.md` (Layer 4 design compliance sub-check)
- Modify: `skills/gaspol-learn/SKILL.md` (UI patterns capture to ui-patterns/)

**Steps:**
1. Rewrite SKILL.md per spec 6.2.4 file structure + invocation strategy (4 min)
2. Update brainstorm Phase 3 with expanded keyword list + file-ext detection (3 min)
3. Add Phase 2.5 design gate (AskUserQuestion for ambiguous cases) (1 min)
4. Update gaspol-plan: plan template now has Design Deliverable column (2 min)
5. Update gaspol-execute: per-UI-phase invoke design-audit.py for fidelity (3 min)
6. Update gaspol-verify Layer 4: add design system compliance sub-check (2 min)
7. Update gaspol-learn: capture UI patterns to `gaspol-knowledge/ui-patterns/` with tags (2 min)
8. Commit: `feat(design): power peer SKILL.md + chain integration` (1 min)

**Verification:**
- [ ] gaspol-design SKILL.md references all forked data + rules + templates
- [ ] Brainstorm Phase 3 triggers expanded keywords
- [ ] Plan template shows design deliverable column
- [ ] Execute runs design-audit.py per UI phase
- [ ] Verify Layer 4 checks design compliance
- [ ] Learn writes to ui-patterns/

---

### Phase Q: gaspol-parallel Consolidation (Absorb dispatch)

**Estimated time:** 12 minutes
**Dependencies:** B (dispatch dir kept temporarily)

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md` (add mode param, absorb dispatch content)
- Delete: `skills/gaspol-dispatch/` (now can remove)

**Steps:**
1. Read gaspol-dispatch/SKILL.md fully (2 min)
2. Read gaspol-parallel/SKILL.md fully (2 min)
3. Add `mode` field documentation to parallel SKILL.md: `plan-phases` (current default) + `independent-domains` (from dispatch) (3 min)
4. Merge conflict check + dispatch rules from dispatch/SKILL.md into parallel/SKILL.md (2 min)
5. Delete `skills/gaspol-dispatch/` directory (1 min)
6. Update hooks/session-start.sh (remove gaspol-dispatch) (1 min)
7. Commit: `refactor: consolidate dispatch into parallel with mode param` (1 min)

**Verification:**
- [ ] gaspol-parallel SKILL.md has mode section
- [ ] gaspol-dispatch/ directory deleted
- [ ] Hook skill list updated (13 skills)
- [ ] Both modes documented with when-to-use

---

### Phase R: Brainstorm Phase 0.5 + 1.5 + 2.5

**Estimated time:** 14 minutes
**Dependencies:** A (KB), H (research), P (design chain)

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md` (add Phases 0.5, 1.5, 2.5)

**Steps:**
1. Write Phase 0.5 (KB query): `git pull --quiet` + grep INDEX.md by tags from user intent + AskUserQuestion surface (3 min)
2. Write Phase 1.5 (Novelty Assessment): classify domain → PRECEDENT/SEMI-NEW/NEW → decision tree for research level (4 min)
3. Write Phase 2.5 (Design Gate): AskUserQuestion for UI detection ambiguity (2 min)
4. Add anti-precedent option in Phase 0.5 surface: [Apply] [Override w/ reason] [Skip] (2 min)
5. Write divergence ADR trigger when Override chosen (integrate with gaspol-adr) (2 min)
6. Commit: `feat(brainstorm): add Phase 0.5 KB + 1.5 novelty + 2.5 design gate` (1 min)

**Verification:**
- [ ] All 3 new phases documented
- [ ] KB pull silent + fast (<3 sec)
- [ ] Novelty classification has 3 tiers
- [ ] Anti-precedent flow documented
- [ ] Divergence ADR trigger connects to gaspol-adr

---

### Phase S: KB Lifecycle Implementation

**Estimated time:** 13 minutes
**Dependencies:** H, I, J (all KB capture skills exist)

**Files:**
- Modify: `skills/gaspol-learn/SKILL.md` (add status: proposed default)
- Modify: `skills/gaspol-adr/SKILL.md` (status lifecycle + supersede logic)
- Modify: `skills/gaspol-research/SKILL.md` (status field)
- Modify: `skills/gaspol-kb-audit/SKILL.md` (status-aware audit)
- Modify: INDEX.md template (status column + freshness badge)

**Steps:**
1. Update INDEX.md entry format: add `status:` and freshness badge to template (2 min)
2. Update gaspol-learn: captures default to `status: proposed`, require user confirm promote to `accepted` (2 min)
3. Update gaspol-adr: on new ADR conflicting with existing, auto-mark old as `superseded_by` (3 min)
4. Update gaspol-research: all captures get status + TTL already (from Phase H) (1 min)
5. Update gaspol-kb-audit: scan for stale (last_validated >180d on accepted), orphans, conflicts (2 min)
6. Update query behavior: default query returns `accepted` only, opt-in shows `proposed`/`superseded` (2 min)
7. Commit: `feat: KB lifecycle — status, supersession, freshness-aware queries` (1 min)

**Verification:**
- [ ] All capture skills write `status` field
- [ ] INDEX.md entries show status + freshness
- [ ] Default query filters by status:accepted
- [ ] Audit detects stale accepted entries

---

### Phase T: CLAUDE.md Comprehensive Update

**Estimated time:** 18 minutes
**Dependencies:** ALL prior phases (reflects final state)

**Files:**
- Modify: `CLAUDE.md` (comprehensive update per spec 11.1)

**Steps:**
1. Invoke `gaspol-sync-docs` Mode 1 (post-implementation sync) to auto-detect changes (3 min)
2. Manual fill gap: Architecture table — remove 3 rows, update design row, add 5 new rows (research, auto, adr, learn, kb-audit) (3 min)
3. Update Skill Routing table with removals + additions (2 min)
4. Update Workflow Chains diagram (2 min)
5. Add new sections per spec 11.1 list: Cross-Project KB, Model Switching Rubric, Research Grounding, Design Intelligence (power peer), Closure Gate, KB Self-Maintenance (4 min)
6. Remove Git Worktree section entirely (1 min)
7. Bump version to 1.2.0 + date 2026-04 (1 min)
8. Commit: `docs: comprehensive CLAUDE.md update for v1.2.0` (2 min)

**Verification:**
- [ ] Skill count in CLAUDE.md reads 13 (not 16)
- [ ] No references to kickstart/dispatch/worktree
- [ ] All 6 new sections present
- [ ] Version header updated

---

### Phase U: README.md Overhaul

**Estimated time:** 16 minutes
**Dependencies:** T (CLAUDE.md is source of truth)

**Files:**
- Rewrite: `README.md` (per spec 11.2 template)

**Steps:**
1. Write hero section + tagline (2 min)
2. Write "Why gaspol?" problem framing (3 min)
3. Write differentiation table vs advisory plugins (2 min)
4. Write Quick Start section (1 min)
5. Write 13 skills organized by workflow (3 min)
6. Write real compounding example (2 min)
7. Write architecture diagram (ASCII atau SVG link) (2 min)
8. Write vs-superpowers comparison (1 min)
9. Write Credits + License sections (1 min)
10. Commit: `docs: overhaul README.md as growth lever v1.2.0` (1 min)

**Verification:**
- [ ] README has all 10 sections from spec 11.2
- [ ] Word count reasonable (<2000 words, scannable)
- [ ] Links work (marketplace, repos)
- [ ] Honest comparison (not hype)

---

## Post-Plan Completion Gate

After Phase U completes:

1. Run `gaspol-verify` across all 4 layers
2. Run upgraded `plan-verifier` agent (step-level audit of this plan vs actual state)
3. Run `gaspol-sync-docs` Mode 2 (quality audit CLAUDE.md)
4. Test plugin load: `claude plugin list` shows gaspol-dev v1.2.0
5. Smoke test: run `/gaspol-brainstorm` on dummy task — verify Phase 0.5 pulls KB, Phase 1.5 classifies novelty
6. Smoke test: run through a full chain on sandbox project (brainstorm → plan → execute → verify → finish)

## Rollback Plan per Phase

All phases committed individually → rollback via `git revert <sha>` per phase.
High-risk phases (skill deletions, structural changes):
- Phase B (skill removals): keep backup branch `pre-v1.2` before deletion
- Phase G (hybrid file structure): existing plan files must still readable → backward-compat check

## Execution Handoff

**Option 1: Execute in this session**
> "Ready to start Phase A? I'll use gaspol-execute to implement with per-phase checkpoints + tiered auto-review + TDD hard gates (but note: those enforcement mechanisms get BUILT by this plan, so early phases run under current enforcement, later phases benefit from new enforcement)."

**Option 2: Parallel execution (where safe)**
> "Phases A, B, C, D can run in parallel (no shared files). Phases H-L (5 new skills) can run in parallel. Use gaspol-parallel with mode:independent-domains."

**Option 3: Separate session**
> "Plan saved to `docs/plans/2026-04-17-gaspol-improvements.md` (single hybrid file per Poin 1). Start fresh session later with: 'Execute plan docs/plans/2026-04-17-gaspol-improvements.md Phase A'."
