# gaspol-dev

**Process discipline for Claude Code — so AI writes real code, not fake placeholders.**

![gaspol-dev — the seven-stage chain: brainstorm, plan, execute, verify, review, finish, learn. Verify, review, and finish are blocking gates.](assets/image/gaspol-dev-hero.png)

[![Version](https://img.shields.io/badge/version-1.15.0-blue)](https://github.com/alisadikinma/gaspol-dev) [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![Skills](https://img.shields.io/badge/skills-20-orange)](#the-20-skills-organized-by-workflow) [![Agents](https://img.shields.io/badge/agents-4-orange)](#agents) [![Gates](https://img.shields.io/badge/blocking%20gates-3-red)](#the-finish-chain-six-steps-three-of-them-block)

---

## Why gaspol?

You plan a feature carefully. Claude executes it. And then you find:

- A `const data = [...]` placeholder where a real API call should be
- Phase 3 completed "successfully" but 3 steps got skipped
- Tests written after implementation (or not at all)
- A new hook created, when an identical one already exists in the codebase
- A step reported as done that nothing ever checked
- No memory of decisions made last month — same debates every session

**gaspol-dev fixes this.** 20 skills + 4 agents that enforce process discipline, catch placeholders, gate completion with evidence, ground approaches in industry-current research, isolate parallel work in git worktrees, auto-trigger the right skill at the right moment, and build a cross-project knowledge base that **compounds over time**.

---

## What makes it different

| Other plugins | gaspol-dev |
|---|---|
| Advisory rules ("write test first") | **Hard gates** — execute refuses to run a phase whose step 1 isn't a failing test |
| Code review at the end | **Tiered auto-review** per phase, sized by a complexity classifier |
| Plan-level fidelity check | **Step-level evidence-based** plan-verifier — a code quote per FOUND item, BLOCKING on any MISSING |
| Review findings taken at face value | **Adversarial refutation** — one refuter per Critical finding, defaulting to REFUTED, plus a 0–100 confidence rubric |
| "Done" is self-reported | **Evidence-gated** — sync-docs must show CLAUDE.md in the branch diff, not a ticked box |
| Merge = shipped | **Publication gate** — a local merge publishes nothing, and finish says so |
| Generic training-data suggestions | **Industry research grounding** with a freshness-aware cache (🟢🟡🟠🔴) |
| Single-project context | **Cross-project KB** — works offline out of the box, GitHub sync optional |
| Fixed model | **Auto-rubric model switching** per task type |
| Reinvents what the platform already ships | **Delegates** — design to `ui-ux-pro-max`, security to the CLI built-in |
| KB accumulates junk | **Periodic KB audit** — stale, duplicates, conflicts auto-flagged |
| Autonomous = unsafe | **Autonomous with hard-stop guardrails** — 8 always-pause conditions |

---

## Quick Start

```bash
claude plugin install gaspol-dev

# Or clone directly:
git clone https://github.com/alisadikinma/gaspol-dev ~/.claude/plugins/gaspol-dev
```

That's it. The cross-project KB works out of the box — local-only, auto-created on first use. No GitHub repo required; sync is an optional upgrade.

Start with `/gaspol-brainstorm` for any new feature idea. The skill chain takes over from there.

---

## The finish chain: six steps, three of them block

This is the part most plugins don't have. When you say "I'm done", `gaspol-finish` runs six steps **in order**, and none of them is conditional on how the diff looks:

| # | Step | Blocking? |
|---|---|---|
| 1 | `gaspol-verify` — 4 layers (technical, plan fidelity, placeholder scan, integration) | — |
| 2 | `plan-verifier` agent — step-level, evidence-based, 3 random FOUND items spot-checked | **BLOCKS** |
| 3 | `gaspol-review` at Tier 1 — findings must survive adversarial refutation to count | **BLOCKS** on Critical |
| 4 | `/security-review` — the CLI built-in, on **every** branch | **BLOCKS** on any finding |
| 5 | `gaspol-sync-docs` — CLAUDE.md must appear in the branch diff, not just be claimed | — |
| 6 | `gaspol-learn` — quality-gated pattern capture to the KB | — |

Then the ledger is closed with a truthful cursor, other open ledgers are surfaced, and — because **merging is not publishing** — you're told to push, and for a plugin repo to run `claude plugin update <plugin>@<marketplace>` and restart.

Three of these gates exist because their absence caused a real, observed failure. Step 4 always runs because "this diff doesn't look security-sensitive" is a judgement call nobody should make under deadline. Step 5 demands evidence because a self-reported checkbox once shipped a release whose changelog never mentioned half of what was in it.

---

## The 17 skills (organized by workflow)

### Planning
- **gaspol-brainstorm** — CLAUDE.md-first + KB precedent query (Phase 0.5) + novelty assessment (Phase 1.5) + three-path classification (spike / bounded / architectural)
- **gaspol-plan** — Implementation plan with Data Integration Map + TDD step 1 mandatory + per-phase verification + creates the ticket ledger
- **gaspol-research** — Deep-dive external libs/APIs with freshness-aware cache, quality gates, anti-hallucination spot-check
- **gaspol-adr** — Architecture Decision Records auto-captured at forks (MADR format, supersession + divergence support)

### Execution
- **gaspol-execute** — Per-phase checkpoints + TDD hard gate + tiered auto-review + plan-verifier BLOCKING
- **gaspol-worktree** — Isolated git worktree (native-tool-first, Step 0 detection + safety verification) so parallel work never collides
- **gaspol-parallel** — Multi-agent parallel (`mode: plan-phases` or `mode: independent-domains`) with worktree isolation, **DAG lane scheduling** (dependency waves + file-isolated lanes), and a per-task **Validation Ladder** (static→unit→build→integration→edge)
- **gaspol-auto** — Autonomous mode for a familiar codebase, with hard-stop guardrails on 8 conditions
- **gaspol-tdd** — RED-GREEN-REFACTOR, hard-gated by execute: no production code before a failing test
- **gaspol-debug** — Systematic root-cause debugging: no guessing, backward tracing, stop after 3 failed hypotheses

### Verification & Closure
- **gaspol-verify** — 4-layer verification; commands are **derived** from the project's stack markers, never hardcoded to npm
- **gaspol-review** — Tiered review lanes + adversarial refutation + 0–100 confidence rubric with an 80 threshold and an explicit false-positive catalogue
- **gaspol-receive-review** — Verify feedback before implementing it; no performative agreement, and push back when the reviewer is wrong
- **gaspol-finish** — The six-step chain above, plus ledger close and the publication gate

### Learning & Maintenance
- **gaspol-learn** — Quality-gated auto-capture post-finish (6 validation checks, user confirms)
- **gaspol-sync-docs** — CLAUDE.md sync (3 modes: post-implementation / audit / session learning)

### Bootstrap
- **using-gaspol** — Auto-trigger backbone: loaded at session start, enforces the 1% rule (invoke the matching skill BEFORE responding), routing table, instruction priority, and rationalization Red Flags

### Agents
- **code-reviewer** (Sonnet) — Quality review between commits
- **code-simplifier** (Haiku) — Refine for clarity without behaviour change
- **plan-verifier** (Opus) — **Step-level evidence-based** audit, BLOCKING verdict
- **spec-reviewer** (Opus) — Verify implementation matches spec exactly

---

## What gaspol deliberately does *not* own

A plugin that reimplements what the platform already ships is a fork waiting to drift. Two capabilities are delegated on purpose:

**Design intelligence → the [`ui-ux-pro-max`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) plugin.** gaspol used to vendor a 1.4MB fork of its style, palette, and typography data. The fork drifted; upstream didn't. Install it with `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`.

The reference is **soft — there is deliberately no `dependencies` key in `plugin.json`.** That field is all-or-nothing: if the third-party entry were renamed or yanked, *every* gaspol skill would disable, including `tdd`, `debug`, `verify`, and `finish`. If the plugin is missing, gaspol says so and continues. Design quality degrades; nothing breaks.

**Security review → the built-in `/security-review`.** It's compiled into the Claude Code CLI, so every user already has it — no plugin, no marketplace, no install.

Both of those delegations were deletions — two skills built in-house that never should have been. So v1.15.0 added the gate that would have caught them: `skills/_shared/prior-art-gate.md`, **BLOCKING**, three lookups before any skill is written, because each is blind where the others see. Is it *installed* already? Is it a **built-in `/command`** — those appear in no skill listing, which is exactly how `/security-review` was missed? Is it on the **marketplace** (`npx skills find`, [skills.sh](https://skills.sh)) — one command away from finding `ui-ux-pro-max`? The verdict is recorded as `NONE` / `EXISTS` / `DELTA`, and `DELTA` must **name** the delta. Installing is never automatic: a skill is a prompt that runs inside your agent, so the candidate's own SKILL.md gets read and the user decides.

Three things did **not** delegate, because no upstream equivalent exists:

| Kept | Why |
|---|---|
| `skills/gaspol-verify/scripts/design_audit.py` | A stdlib-only **static source** lint. The upstream audit drives Chromium via Playwright against a **running URL** — it can't serve verify's Layer 4, which runs offline and pre-merge |
| `skills/gaspol-verify/rules/anti-ai-slop.md` | `ui-ux-pro-max` ships no anti-slop opinion layer at all — zero "never use" lists |
| `skills/gaspol-verify/rules/reasoning-gaspol.md` | Respect the target project's CLAUDE.md tokens, query the KB for precedent |

---

## Real example: Compounding knowledge

```
[First project: Sparkfluence — 2026-03]
You: /gaspol-brainstorm image-generation UI
gaspol: Phase 0 reading CLAUDE.md... Phase 0.5 querying KB... no precedent yet.
gaspol: Phase 1.5 classified NEW (no KB, no project pattern). Invoking gaspol-research...
[20 min of research — Zustand vs Redux, image-gen APIs, 3-pane layouts]
gaspol: Approach chosen: 3-pane (prompt + preview + history). ADR-2026-03-15 captured.
...feature ships via gaspol-finish...
gaspol-learn: Candidate pattern "image-gen-3-pane-layout". Capture? [Yes with tags: image-gen, gallery, 3-pane]
gaspol-learn: Saved to ui-patterns/image-generation-ui.md (status: proposed)

[3 months later: new project, same domain — 2026-06]
You: /gaspol-brainstorm AI video editor UI
gaspol: Phase 0.5 querying KB... Found relevant past work:
  • [image-generation-ui] — tags: [image-gen, gallery, 3-pane]
    Source: sparkfluence 2026-03 — 🟢 accepted
    Hook: 3-pane layout (prompt + preview + history) works best
    last_validated: 2026-03-15 (88 days ago)

  [Apply precedent] [Override with reason] [Skip — fresh design]

You: Apply precedent
gaspol: Phase 1.5 classified PRECEDENT. Skipping research. Proceeding with 3-pane as baseline.
[brainstorm continues 5x faster — no re-exploration, no re-research]
```

**Compounding:** the first project pays the research cost. The next ten in the same domain reuse the learning.

---

## Architecture

```
Target Project
  └─ CLAUDE.md ──────┐
                     │
<KB_ROOT>/          (resolved by skills/_shared/kb-root — env > kb_local > default)
  └─ YYYY-MM-DD-<slug>.md   ← flat notes, status: proposed, category is the first tag
                     │
        Chain:       ↓
  brainstorm → plan → execute → verify → review → finish → learn
       ↓        ↓        ↓         ↓        ↓        ↓
   Phase 0.5   TDD      TDD    commands  adversarial  6-step
   KB query   step 1   hard    DERIVED   refutation   chain,
       ↓      required  gate   from the   + 0-100     3 gates
   Phase 1.5     ↓        ↓    stack, not  rubric      BLOCK
   novelty    ledger   tiered  hardcoded      ↓          ↓
   classify   created  auto-      ↓        threshold   ledger
       ↓         ↓     review  plan-verifier   80      closed
   Phase 2.5     ↓        ↓     BLOCKING              + publish
   design gate   ↓        ↓     step-level             reminder
       ↓         └────────┴──── evidence-based
   Phase 3
   ui-ux-pro-max  (plugin, soft reference — no hard dependency)
       +
   gaspol anti-slop rules  (kept: no upstream equivalent)
```

---

## Model rubric (auto-switching)

Subagent dispatch picks a tier by task type. Skills write **unversioned aliases** — `opus`, `sonnet`, `haiku` — which always resolve to the newest model in each family, so the rubric doesn't go stale when a new model ships.

| Task | Tier | Cost |
|---|---|---|
| Architecture planning, spec review, plan-verifier, research synthesis, autonomous orchestration | **opus** | high |
| Implementation, code review, test writing, research gathering, ADR capture, learn capture | **sonnet** | medium |
| Docs sync, rename/format, simple fact lookup | **haiku** | low |

Target cost mix: ~15% opus, ~60% sonnet, ~25% haiku. See [docs/rubric-model-switching.md](docs/rubric-model-switching.md) — note that document still names specific model versions and is due a refresh.

---

## The 3 Iron Laws

Non-negotiable. They apply to every skill.

```
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

Paired with an always-on **Completeness Ladder** that governs coverage rather than fidelity: happy path → every error path that can actually happen → every edge case the input space allows → the tests that prove them → observability → the comment explaining why. Walked down in full; the only legitimate stop is genuinely unrelated work, flagged as separate scope. A Reuse Rule (stdlib → native feature → already-installed dependency, no interface with one implementation) keeps completeness from meaning more code than the job needs.

The two governors are orthogonal. The Iron Laws cut *incorrectness*; the ladder cuts *bloat*. The ladder never excuses a placeholder, a skipped test, or a missing validation — a "lazy" move that crosses into fake data is negligent, not lazy.

---

## Anti-AI-slop design rules

gaspol design output **never** contains:
- Inter/Roboto/Arial as primary font
- Purple gradient on white background
- Predictable symmetric card grid
- Cookie-cutter SaaS hero layout
- Emoji as functional icons

gaspol design output **always** chooses:
- Distinctive display fonts (Instrument Serif, Fraunces, General Sans, etc.)
- Sharp accent contrast
- Asymmetric or data-driven layouts
- Intentional motion (150–300ms)
- Layered backgrounds with depth

Full rules: [`skills/gaspol-verify/rules/anti-ai-slop.md`](skills/gaspol-verify/rules/anti-ai-slop.md). This is gaspol's own taste layer, applied on top of whatever `ui-ux-pro-max` returns — that plugin supplies design *data*, not opinions about what to avoid.

---

## Release history

| Version | What landed |
|---|---|
| **1.15.0** (current) | Prior-art gate is BLOCKING — installed / built-in / marketplace, verdict `NONE` · `EXISTS` · `DELTA`; probes wired into `gaspol-brainstorm` Phase 1.5 (`NEW` only) and `gaspol-research` lane 6, every reference soft |
| 1.14.0 | Two in-house skills deleted in favour of tooling every user already has — design intelligence to the `ui-ux-pro-max` plugin, security review to the CLI built-in; confidence rubric + false-positive catalogue in `gaspol-review`; `gaspol-finish` gains ledger close, derived test commands, and a publication gate; the eval skill renamed `gaspol-llm-test` |
| 1.13.0 | Dated `YYYY-MM-DD-<TICKET>-<topic>` spec/plan filenames, `PROGRESS-<TICKET>.md` ledger with per-phase checklist, and `detect-stack` — verification commands derived from the project's stack instead of assuming npm |
| 1.10.x | Two-lane execution: self-contained plans, per-plan progress ledger as a hard per-phase gate, pluggable external executor |
| 1.8.0 | DAG lane scheduling (stdlib `graphlib`, zero deps), adversarial refutation in review, per-task Validation Ladder |
| 1.7.0 | Visual brainstorm companion — browser mockup loop |
| 1.5.0–1.6.0 | Selective adoption from superpowers: SDD per-task review harness, worktree patterns |
| 1.4.0 | Eval-driven development and a security checklist, ported from Everything Claude Code |
| 1.3.x | `gaspol-worktree`, `using-gaspol` bootstrap, `tests/` harness; KB works out of the box (local-only) |
| 1.2.0 | Cross-project KB, tiered review, hard gates, research grounding, step-level closure |
| 1.0.0 | Core skills, anti-placeholder enforcement, per-phase checkpoints |

Next: multi-IDE support (Cursor, Codex, Gemini).

---

## Installation Details

### Prerequisites

- Claude Code (CLI, Desktop, or IDE extension)
- Git
- Python 3.8+ — only for [`skills/gaspol-verify/scripts/design_audit.py`](skills/gaspol-verify/scripts/design_audit.py)
- GitHub CLI (`gh`) — **optional**, only if you want cross-machine KB sync or PR creation

### Plugin Install

```bash
# Option A: the gaspol-one marketplace (gaspol-dev + gaspol-pitch + gaspol-catalog)
claude plugin marketplace add alisadikinma/gaspol-one
claude plugin install gaspol-dev@gaspol-one

# Option B: manual
git clone https://github.com/alisadikinma/gaspol-dev ~/.claude/plugins/gaspol-dev
```

### KB: zero setup (local-only default)

Since **v1.3.1 the KB works out of the box.** On first use, `gaspol-adr` / `gaspol-learn` auto-create `~/.claude/gaspol-knowledge/` locally and start capturing — no GitHub repo, no config file. Cross-project learning works on this machine immediately. Full reference: [docs/kb-setup.md](docs/kb-setup.md).

| Mode | When | Behaviour |
|---|---|---|
| **local-only** (default) | no config, or config without `kb_remote` | auto-init local dir, read/write locally, no remote |
| **synced** | `kb_remote` set (config or `$GASPOL_KB_REMOTE`) | adds `git pull`/`push` for cross-machine sync |
| **off** | `"kb_mode": "off"` in config | KB disabled, skills skip silently |

### Optional upgrade: GitHub sync (cross-machine)

Want your KB on more than one machine? Promote local-only → synced. The KB is **private per user** — create your own repo, never share it.

```bash
gh auth login
gh repo create <your-github-username>/gaspol-knowledge --private
git -C ~/.claude/gaspol-knowledge remote add origin \
  git@github.com:<your-github-username>/gaspol-knowledge.git
git -C ~/.claude/gaspol-knowledge push -u origin main   # everything captured locally comes along

cat > ~/.claude/gaspol-config.json <<EOF
{
  "kb_remote": "git@github.com:<your-github-username>/gaspol-knowledge.git",
  "kb_local": "~/.claude/gaspol-knowledge",
  "kb_owner": "<your-github-username>"
}
EOF
```
Resolution order and the three states live in `skills/_shared/kb-path.md` and are executed by
`skills/_shared/kb-root` (exit **0** available / **3** UNKNOWN / **4** none). Prefer this file over
the `GASPOL_KB_LOCAL` environment variable: a shell export only exists for processes that
inherited that shell, and everywhere else resolution falls through to the default and recreates
the store you moved away from.




### Verify

```bash
claude plugin list | grep gaspol-dev
# Should show: gaspol-dev@gaspol-dev, version 1.18.0

ls "$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")"   # the RESOLVED root — not a fixed path. Created on first capture.
# flat notes: YYYY-MM-DD-<slug>.md (no index, no category dirs since v1.18)
```

**Updating:** a plugin update needs a restart to take effect, and the update command wants the **full id** — the bare name fails with `Plugin "gaspol-dev" not found`.

```bash
claude plugin marketplace update gaspol-one
claude plugin update gaspol-dev@gaspol-one
# then restart Claude Code
```

---

## Testing

```bash
# Deterministic — fast, no API calls. Run these first.
for t in tests/ticket-scripts/test-*.sh; do bash "$t"; done

# Stochastic — these spawn real `claude` CLI runs.
bash tests/skill-triggering/run-all.sh    # naive intent prompts must fire the right skill
bash tests/pressure/run-all.sh            # rigid skills must resist rationalization
```

The stochastic suites are **samples, not verdicts**. A single run's score proves nothing on its own — compare against a baseline run on the previous commit before calling anything a regression, and always eyeball the saved log, because capitulation detection is heuristic.

---

## Contributing

See [CLAUDE.md](CLAUDE.md), "Conventions for Contributors".

Key rules:
1. New skill → run `skills/_shared/prior-art-gate.md` first, then apply RED-GREEN-REFACTOR to the skill itself
2. Update the CLAUDE.md Architecture + Skill Routing tables, `hooks/session-start.sh`, and `skills/using-gaspol/SKILL.md` — all four, or the skill won't auto-trigger
3. Add a deterministic test under `tests/ticket-scripts/`; add a pressure case for rigid skills
4. Follow the existing SKILL.md structure (Iron Law, Core Principle, Process, Red Flags, Rationalization Table, Integration)

---

## Credits

- **Design intelligence** is delegated to [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) by Next Level Builder (MIT). Earlier versions vendored a fork of its data; v1.14.0 removed the fork in favour of the upstream plugin. See [NOTICE.md](NOTICE.md).
- **Workflow patterns** inspired by [superpowers](https://github.com/obra/superpowers) by Jesse Vincent (obra). `gaspol-worktree`, the `using-gaspol` bootstrap, and the `tests/` skill-triggering harness adapt patterns from `using-git-worktrees`, `using-superpowers`, and `tests/skill-triggering` (MIT).
- **The confidence rubric and false-positive catalogue** in `gaspol-review` are absorbed from Anthropic's official `code-review` plugin.
- **Iron Law discipline** influenced by Kent Beck's XP practices.

---

## License

MIT © [Ali Sadikin Ma](https://github.com/alisadikinma)

See [LICENSE](LICENSE) for full text.
