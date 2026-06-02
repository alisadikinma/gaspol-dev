# gaspol-dev

**Process discipline for Claude Code — so AI writes real code, not fake placeholders.**

[![Version](https://img.shields.io/badge/version-1.3.0-blue)](https://github.com/alisadikinma/gaspol-dev) [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![Skills](https://img.shields.io/badge/skills-20-purple)](#the-20-skills-organized-by-workflow) [![Agents](https://img.shields.io/badge/agents-4-orange)](#agents)

---

## Why gaspol?

You plan a feature carefully. Claude executes it. And then you find:

- A `const data = [...]` placeholder where a real API call should be
- Phase 3 completed "successfully" but 3 steps got skipped
- Tests written after implementation (or not at all)
- A new hook created, when an identical one already exists in the codebase
- No memory of decisions made last month — same debates every session

**gaspol-dev fixes this.** 20 skills + 4 agents that enforce process discipline, catch placeholders, gate completion with evidence, ground approaches in industry-current research, isolate parallel work in git worktrees, auto-trigger the right skill at the right moment, and build a cross-project knowledge base that **compounds over time**.

---

## What makes it different

| Other plugins | gaspol-dev |
|---|---|
| Advisory rules ("write test first") | **Hard gates** — execute refuses to run phase without TDD step 1 |
| Code review at end | **Tiered auto-review** per phase based on complexity classifier |
| Plan-level fidelity check | **Step-level evidence-based** plan-verifier with code quote per FOUND |
| Generic training-data suggestions | **Industry research grounding** with freshness-aware cache (🟢🟡🟠🔴) |
| Single-project context | **Cross-project KB** (GitHub-synced) — patterns learned once, reused forever |
| Fixed model | **Auto-rubric model switching** (Opus/Sonnet/Haiku per task type) |
| Design as afterthought | **Power-peer design intelligence** wired across plan/execute/verify/learn |
| KB accumulates junk | **Periodic KB audit** — stale, duplicates, conflicts auto-flagged |
| Autonomous = unsafe | **Autonomous with hard-stop guardrails** — 8 always-pause conditions |

---

## Quick Start

```bash
# Install via Claude Code marketplace (once published)
claude plugin install gaspol-dev

# Or clone directly:
git clone https://github.com/alisadikinma/gaspol-dev ~/.claude/plugins/gaspol-dev

# First-time KB setup (one-time, required for cross-project features)
# IMPORTANT: KB is PER-USER — create YOUR OWN private repo, do NOT share!
gh repo create <your-github-username>/gaspol-knowledge --private
git clone ssh://git@github.com/<your-github-username>/gaspol-knowledge ~/.claude/gaspol-knowledge

# Write config file with YOUR remote URL:
cat > ~/.claude/gaspol-config.json <<EOF
{
  "kb_remote": "git@github.com:<your-github-username>/gaspol-knowledge.git",
  "kb_local": "~/.claude/gaspol-knowledge",
  "kb_owner": "<your-github-username>"
}
EOF
```

Start with `/gaspol-brainstorm` for any new feature idea. The skill chain takes over from there.

---

## The 20 skills (organized by workflow)

### Planning & Design
- **gaspol-brainstorm** — CLAUDE.md-first + KB precedent query (Phase 0.5) + novelty assessment (Phase 1.5) + design gate (Phase 2.5)
- **gaspol-design** — Power-peer design intelligence (85+ styles, 162+ reasoning rules, 99+ UX guidelines, multi-framework)
- **gaspol-plan** — Implementation plan with Data Integration Map + TDD step 1 mandatory + design deliverable column
- **gaspol-research** — Deep-dive external libs/APIs with freshness-aware cache, quality gates, anti-hallucination spot-check
- **gaspol-adr** — Architecture Decision Records auto-captured at forks (MADR format, supersession + divergence support)

### Execution
- **gaspol-execute** — Per-phase checkpoints + TDD hard gate + tiered auto-review + plan-verifier BLOCKING
- **gaspol-worktree** — Isolated git worktree (native-tool-first, Step 0 detection + safety verification) so parallel work never collides
- **gaspol-parallel** — Multi-agent parallel (`mode: plan-phases` OR `mode: independent-domains`) with worktree isolation + continuous execution
- **gaspol-auto** — Autonomous mode for familiar codebase (hard-stop guardrails on 8 conditions)
- **gaspol-tdd** — RED-GREEN-REFACTOR hard-gated by execute (no production code before failing test)
- **gaspol-debug** — Systematic root-cause debugging (no guessing, backward tracing)

### Verification & Closure
- **gaspol-verify** — 4-layer verification (technical, plan fidelity BLOCKING, placeholder scan, integration + design compliance)
- **gaspol-review** — Code review dispatch with code-reviewer subagent
- **gaspol-receive-review** — Technical response (no performative agreement)
- **gaspol-finish** — BLOCKING plan-verifier pre-chain + merge/PR/cleanup options

### Learning & Maintenance
- **gaspol-learn** — Quality-gated auto-capture post-finish (6 validation checks, user confirms)
- **gaspol-sync-docs** — CLAUDE.md sync (3 modes: post-implementation / audit / session learning)
- **gaspol-kb-audit** — Periodic KB health check (stale / duplicates / conflicts / orphans / broken refs / unpromoted)
- **gaspol-write-skill** — TDD applied to skill creation (RED-GREEN-REFACTOR)

### Bootstrap
- **using-gaspol** — Auto-trigger backbone: loaded at session start, enforces the 1% rule (invoke the matching skill BEFORE responding), routing table, instruction priority, and rationalization Red Flags

### Agents
- **code-reviewer** (Sonnet) — Quality review between commits
- **code-simplifier** (Haiku) — Refine for clarity without behavior change
- **plan-verifier** (Opus) — **Step-level evidence-based** audit, BLOCKING verdict
- **spec-reviewer** (Opus) — Verify implementation matches spec exactly

---

## Real example: Compounding knowledge

```
[First project: Sparkfluence — 2026-03]
You: /gaspol-brainstorm image-generation UI
gaspol: Phase 0 reading CLAUDE.md... Phase 0.5 querying KB... no precedent yet.
gaspol: Phase 1.5 classified NEW (no KB, no project pattern). Invoking gaspol-research...
[20 min of research — Zustand vs Redux, Flux Image Gen APIs, 3-pane layouts]
gaspol: Approach chosen: 3-pane (prompt + preview + history). ADR-2026-03-15 captured.
...feature ships via gaspol-finish...
gaspol-learn: Candidate pattern "image-gen-3-pane-layout". Capture? [Yes with tags: image-gen, gallery, 3-pane]
gaspol-learn: Saved to ui-patterns/image-generation-ui.md (status: proposed)
gaspol-adr: Research cache + ADR committed to <your-username>/gaspol-knowledge (your private KB).

[3 months later: new project, same domain — 2026-06]
You: /gaspol-brainstorm AI video editor UI
gaspol: Phase 0 reading CLAUDE.md... Phase 0.5 querying KB...
gaspol: Found relevant past work:
  • [image-generation-ui] — tags: [image-gen, gallery, 3-pane]
    Source: sparkfluence 2026-03 — 🟢 accepted
    Hook: 3-pane layout (prompt + preview + history) works best
    last_validated: 2026-03-15 (88 days ago)

  [Apply precedent] [Override with reason] [Skip — fresh design]

You: Apply precedent
gaspol: Phase 1.5 classified PRECEDENT. Skipping research. Proceeding to Phase 2 with 3-pane as baseline.
[brainstorm continues 5x faster — no re-exploration, no re-research]
```

**Compounding:** First project paid the research cost. Next 10 projects with similar domain reuse the learning.

---

## Architecture

```
Target Project
  └─ CLAUDE.md ──────┐
                     │
~/.claude/gaspol-knowledge/    (GitHub private repo, synced)
  ├─ INDEX.md        │
  ├─ ui-patterns/    │   populated by gaspol-learn
  ├─ architecture/   │   populated by gaspol-learn
  ├─ design-decisions/ ← populated by gaspol-adr (MADR)
  ├─ research/       ← populated by gaspol-research (TTL + freshness)
  └─ reusable-snippets/ ← populated by gaspol-learn
                     │
        Chain:       ↓
  brainstorm → plan → execute → verify → sync-docs → review → finish → learn
       ↓        ↓        ↓         ↓                              ↓
     Phase0.5  TDD       TDD     plan-verifier                  quality
     KB query  step 1  hard      BLOCKING                        gate
       ↓       valid    gate        ↑
     Phase1.5   ↓        ↓       step-level
     novelty  design  tiered    evidence
     classif  deliv   auto-       based
       ↓     column   review       ↑
     Phase2.5    ↓      ↓        Opus 4.7
     design    plan     ↑
     gate    template sonnet
       ↓             (rubric)
     Phase3
     gaspol-design
     (power peer)
       ↓
     CSV data + scripts + rules + templates
     + optional ui-ux-pro-max v2.0 bridge
```

---

## Model rubric (auto-switching)

Orchestrator (main session) = Opus 4.7 always. Subagent dispatch picks by task:

| Task | Model | Cost |
|---|---|---|
| Architecture planning, spec review, plan-verifier, research synthesis | **Opus 4.7** | high |
| Implementation, code review, test writing, research gathering, ADR, learn | **Sonnet 4.6** | medium |
| Docs sync, rename/format, simple fact lookup | **Haiku 4.5** | low |

Target cost mix: ~15% Opus, ~60% Sonnet, ~25% Haiku. See [docs/rubric-model-switching.md](docs/rubric-model-switching.md).

---

## The 3 Iron Laws

Non-negotiable. Apply to all skills.

```
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

Skill-specific Iron Laws extend these with context (see individual SKILL.md files).

---

## Anti-AI-slop design rules

gaspol-design **never** produces:
- Inter/Roboto/Arial as primary font
- Purple gradient on white background
- Predictable symmetric card grid
- Cookie-cutter SaaS hero layout
- Emoji as functional icons

gaspol-design **always** chooses:
- Distinctive display fonts (Instrument Serif, Fraunces, General Sans, etc.)
- Sharp accent contrast
- Asymmetric or data-driven layouts
- Intentional motion (150-300ms)
- Layered backgrounds with depth

Full rules: `skills/gaspol-design/rules/anti-ai-slop.md`.

---

## Roadmap

- ✅ v1.0 — Core skills, anti-placeholder, per-phase checkpoints
- ✅ v1.1 — Better docs, improved brainstorm flow
- ✅ v1.2 — Cross-project KB, power-peer design, tiered review, hard gates, research grounding, step-level closure, KB lifecycle, 5 new skills (research/adr/learn/kb-audit/auto)
- ✅ v1.3 (current) — superpowers-parity hardening: `gaspol-worktree` (isolated parallel work), `using-gaspol` bootstrap + forceful session-start directive (reliable auto-trigger), continuous-execution mode in gaspol-parallel, and a `tests/` harness (skill-triggering + pressure tests)
- 🔜 v1.4 — Visual brainstorm companion (browser mockup loop wired to gaspol-design's anti-AI-slop knowledge), Semantic KB search, research freshness auto-sweep
- 🔮 v2.0 — Multi-IDE support (Cursor, Codex, Gemini) following superpowers' portability pattern

---

## Comparison vs Superpowers

gaspol-dev overlaps ~60% with [superpowers](https://github.com/obra/superpowers) (both inspired by structured workflow discipline). Differences:

| | gaspol-dev | superpowers |
|---|---|---|
| Anti-placeholder rules | Explicit + enforced at hard gate | Implicit |
| Cross-project memory | ✓ (GitHub-synced KB, 5 categories, freshness-aware) | ✗ |
| Research grounding | Tiered novelty + deep research + cache + TTL | ✗ |
| Design **knowledge** engine | Power peer (85+ styles, 162+ rules, multi-framework) | ✗ |
| Design **interaction** loop (visual brainstorm) | ✗ (roadmap v1.4) | ✓ browser companion |
| Model switching | Auto-rubric per task type | ✗ |
| Step-level closure gate | ✓ Evidence-based, BLOCKING | Phase-level |
| Autonomous / continuous exec | ✓ gaspol-auto (8 hard-stops) + parallel continuous mode | ✓ subagent-driven |
| Git worktree isolation | ✓ gaspol-worktree (Step 0 detect + safety) — v1.3 | ✓ |
| Auto-trigger bootstrap | ✓ using-gaspol + session-start directive — v1.3 | ✓ using-superpowers |
| Skill-trigger + pressure tests | ✓ tests/ harness — v1.3 | ✓ |
| Multi-IDE | Claude Code only (for now) | 5+ IDEs |
| KB self-maintenance | ✓ (gaspol-kb-audit, status lifecycle) | N/A |

> **Honest note:** superpowers shipped a *visual* brainstorming companion (browser mockup loop). gaspol has the design **knowledge** (anti-AI-slop rules, 162+ reasoning rules) but not yet the interactive loop — that's v1.4. Conversely, gaspol's worktree, bootstrap, and test-harness gaps vs superpowers were closed in v1.3 (this release).

**Pick gaspol-dev if:** deep integration with Claude Code + cross-project learning + process enforcement + anti-AI-slop design + model cost optimization matter more than IDE breadth.

**Pick superpowers if:** multi-IDE is critical, you want the visual brainstorm loop, you already have external KB infrastructure, or you want a simpler surface area.

---

## Installation Details

### Prerequisites

- Claude Code (CLI, Desktop, or IDE extension)
- Git + GitHub CLI (`gh`) installed (for KB sync)
- Python 3.8+ (for gaspol-design scripts)

### Plugin Install

```bash
# Option A: marketplace (once published)
claude plugin install gaspol-dev

# Option B: manual
git clone https://github.com/alisadikinma/gaspol-dev ~/.claude/plugins/gaspol-dev
```

### KB Setup (one-time, required for cross-project features)

> ⚠️ **Per-User Repo — Critical:** gaspol-dev is a public plugin, but the knowledge base is **private per user**. Each user creates their OWN repo under THEIR OWN GitHub account. Never share a KB repo across users — it mixes personal project patterns, leaks work, and breaks permission boundaries.

Replace `<your-github-username>` with your actual GitHub handle in all commands below.

```bash
# Authenticate gh CLI
gh auth login

# Create private KB repo UNDER YOUR OWN ACCOUNT
gh repo create <your-github-username>/gaspol-knowledge --private \
  --description "My personal gaspol-dev cross-project knowledge base"

# Clone locally (standard path, same on every user's machine)
git clone ssh://git@github.com/<your-github-username>/gaspol-knowledge \
  ~/.claude/gaspol-knowledge

# Write config file so skills know YOUR remote URL
cat > ~/.claude/gaspol-config.json <<EOF
{
  "kb_remote": "git@github.com:<your-github-username>/gaspol-knowledge.git",
  "kb_local": "~/.claude/gaspol-knowledge",
  "kb_owner": "<your-github-username>"
}
EOF

# Initialize structure
cd ~/.claude/gaspol-knowledge
mkdir -p ui-patterns architecture design-decisions research reusable-snippets
echo "# gaspol-knowledge INDEX (personal)" > INDEX.md
git add . && git commit -m "init: KB structure" && git push
```

### Alternative: Skip KB Setup

KB features are **optional**. Plugin works without KB — you lose cross-project learning (gaspol-learn, gaspol-research cache, Phase 0.5 precedent surfacing, gaspol-kb-audit) but all per-project features (brainstorm, plan, execute, verify, finish, design, TDD, debug, review) work fine.

To skip: just don't create the config file. Skills that touch KB will silent-skip with a brief warning.

### Verify

```bash
claude plugin list | grep gaspol-dev
# Should show: gaspol-dev (v1.2.0)

ls ~/.claude/gaspol-knowledge/
# Should show: INDEX.md ui-patterns/ architecture/ design-decisions/ research/ reusable-snippets/
```

---

## Contributing

See [CLAUDE.md](CLAUDE.md) "Conventions for Contributors" section.

Key rules:
1. New skill → use `gaspol-write-skill` (TDD: RED-GREEN-REFACTOR for skills)
2. Update CLAUDE.md Architecture + Skill Routing tables
3. Test against pressure scenario before submitting
4. Follow existing SKILL.md structure (Iron Law, Core Principle, Process, Red Flags, Rationalization Table, Integration)

---

## Credits

- **Design intelligence data** partially forked from [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) by Next Level Builder (MIT). See [NOTICE.md](skills/gaspol-design/NOTICE.md).
- **Workflow patterns** inspired by [superpowers](https://github.com/obra/superpowers) by Jesse Vincent (obra). The v1.3 `gaspol-worktree`, `using-gaspol` bootstrap, and `tests/` skill-triggering harness adapt patterns from superpowers' `using-git-worktrees`, `using-superpowers`, and `tests/skill-triggering` (MIT).
- **Iron Law discipline** influenced by Kent Beck's XP practices.

---

## License

MIT © [Ali Sadikin Ma](https://github.com/alisadikinma)

See [LICENSE](LICENSE) for full text.
