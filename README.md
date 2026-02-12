# gaspol-dev

> Battle-tested Claude Code skills born from building a real AI-powered SaaS platform.

**18 skills + 4 agents** for execution fidelity, anti-placeholder enforcement, and design intelligence.

---

## The Problem

After months of building [Sparkfluence](https://github.com/alisadikinma) — an AI-powered viral video generation platform — we discovered a pattern:

**Claude Code's planning is excellent. Its execution is not.**

| What happens | How often |
|-------------|-----------|
| Plan says "integrate with backend" — implementation ships hardcoded data | Very common |
| 8-phase plan — 6 phases implemented, 2 quietly skipped | Common |
| "Done!" — actually has 5 `// TODO`s and 3 hardcoded arrays | Common |
| New hook created — identical one already exists in codebase | Occasional |
| Review agents available — never invoked | Always |

These aren't bugs in Claude. They're gaps in the **skill framework** that guides Claude's behavior.

---

## The Solution

**gaspol-dev** fixes execution with three core innovations:

### 1. Anti-Placeholder Iron Law
```
NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
```
Every component's data source is traced during implementation. If the plan says "connect to WorkspaceContext" but the code writes `const data = []`, execution **stops and asks** — never silently substitutes.

### 2. Per-Phase Checkpoints
Instead of batch-executing 3 tasks then reporting, each phase gets a structured checkpoint:
- What was implemented
- Data sources (real vs placeholder — table format)
- Files modified
- Deviations from plan
- **Waits for user approval** before proceeding

### 3. Plan Verification Agent
Post-implementation agent that compares the plan file against `git diff`:
- Per-step status: implemented / different / skipped / unplanned
- Data integration verification (planned source vs actual)
- Placeholder scan (TODO comments, hardcoded arrays, missing imports)
- File coverage (planned vs actually modified)

---

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace:
```
/plugin marketplace add alisadikinma/gaspol-dev
```

Install the plugin:
```
/plugin install gaspol-dev@gaspol-dev
```

### Manual Installation

Clone and add as local plugin:
```bash
git clone https://github.com/alisadikinma/gaspol-dev.git
# Then in Claude Code:
/plugin install /path/to/gaspol-dev
```

### Verify Installation

Start a new Claude Code session and ask:
```
Help me plan a new feature
```
Claude should announce: "I'm using the gaspol-brainstorm skill..."

---

## The Workflow

```
gaspol-brainstorm    Read CLAUDE.md first, explore idea, design with data-driven aesthetics
        |
        v
gaspol-plan          Write implementation plan with Data Integration Map
        |
        v
gaspol-execute       Execute per-phase with anti-placeholder enforcement
        |
        v
gaspol-verify        Technical check + plan fidelity + placeholder scan
        |
        v
gaspol-sync-docs     Update CLAUDE.md with changes (single source of truth)
        |
        v
gaspol-review        Code quality review with enhanced checklist
        |
        v
gaspol-finish        Merge, PR, or cleanup with pre-flight verification
```

The agent checks for relevant skills **before any task**. Mandatory workflows, not suggestions.

---

## Skill Catalog

### Core Execution Chain

| Skill | Purpose | Key Innovation |
|-------|---------|---------------|
| `gaspol-execute` | Execute implementation plans | Anti-placeholder Iron Law, per-phase checkpoints, completion gate |
| `gaspol-verify` | Verify work before claiming done | 4-layer verification: technical, plan fidelity, placeholder scan, integration |
| `gaspol-plan` | Write implementation plans | Mandatory Data Integration Maps, per-phase verification criteria |
| `gaspol-sync-docs` | Keep CLAUDE.md in sync | 3 modes: post-implementation sync, quality audit, session learning capture |

### Design & Discovery

| Skill | Purpose | Key Innovation |
|-------|---------|---------------|
| `gaspol-brainstorm` | Turn ideas into designs | CLAUDE.md-first (saves 10-50k tokens), design intelligence auto-trigger |
| `gaspol-design` | Frontend design intelligence | Data-driven search + bold aesthetics + anti-AI-slop rules |

### Development

| Skill | Purpose | Key Innovation |
|-------|---------|---------------|
| `gaspol-parallel` | Parallel subagent execution | Anti-placeholder in implementer prompts, spec reviewer checks data flow |
| `gaspol-review` | Code review dispatch | Enhanced checklist with placeholder detection |
| `gaspol-receive-review` | Handle review feedback | Technical rigor over performative agreement |
| `gaspol-dispatch` | Parallel agent dispatch | One agent per independent problem domain |

### Quality & Process

| Skill | Purpose | Key Innovation |
|-------|---------|---------------|
| `gaspol-tdd` | Test-driven development | RED-GREEN-REFACTOR with rationalization prevention |
| `gaspol-debug` | Systematic debugging | 4-phase root cause investigation, no guessing |
| `gaspol-worktree` | Git worktree management | Smart directory selection, safety verification |
| `gaspol-finish` | Branch completion | Mandatory verification chain before merge/PR |

### Meta

| Skill | Purpose | Key Innovation |
|-------|---------|---------------|
| `gaspol-kickstart` | Session startup | Skill discovery and invocation rules |
| `gaspol-write-skill` | Create new skills | TDD applied to process documentation |

### Agents

| Agent | Purpose |
|-------|---------|
| `plan-verifier` | Compare plan file vs git diff, report discrepancies |
| `code-reviewer` | Enhanced code review with placeholder detection |
| `spec-reviewer` | Spec compliance verification |
| `code-simplifier` | Auto-refine code for clarity |

---

## Philosophy

### CLAUDE.md is the Single Source of Truth
Every session starts by reading CLAUDE.md. If it's outdated, the session wastes tokens re-exploring what should already be documented. `gaspol-sync-docs` ensures it stays current.

### Real Data, Not Placeholders
The #1 complaint about AI-generated code: "it compiles but uses fake data." Our anti-placeholder system traces every data source and blocks silent substitution.

### Evidence Before Claims
No "should work now." No "I'm confident." Run the verification. Read the output. Only then claim success.

### Plans Are Contracts
The Data Integration Map in every plan is a contract between planner and executor. Each data source is specified. Each phase has verification criteria. Deviations require explanation.

### Design Should Be Bold, Not Generic
Generic AI output (Inter font, purple gradients, symmetric layouts) is the enemy. Our design skills use data-driven search and anti-AI-slop rules to produce distinctive interfaces.

---

## Design Search Engine

The plugin includes a BM25-based design search engine across 8 domains:

| Domain | Content |
|--------|---------|
| `style` | 140+ style categories (Minimalism, Glassmorphism, Brutalism...) |
| `color` | Product-type specific palettes |
| `typography` | Font pairings with mood keywords |
| `landing` | Landing page patterns & conversion |
| `product` | SaaS/e-commerce specific recommendations |
| `ux` | Usability & accessibility guidelines |
| `chart` | Data visualization best practices |
| `icons` | Icon library recommendations |

```bash
# Search for design recommendations
python design/search.py "minimalist dashboard" --domain style

# Generate full design system
python design/search.py "SaaS dashboard" --design-system -p "MyProject"
```

Requires Python 3.8+ with dependencies in `design/requirements.txt`.

---

## Project Structure

```
gaspol-dev/
├── .claude-plugin/           Plugin configuration
├── hooks/                    Session start hooks
├── agents/                   4 specialized agents
│   ├── plan-verifier.md
│   ├── code-reviewer.md
│   ├── spec-reviewer.md
│   └── code-simplifier.md
├── skills/                   18 skills
│   ├── gaspol-execute/       Core execution with anti-placeholder
│   ├── gaspol-verify/        4-layer verification
│   ├── gaspol-plan/          Plans with Data Integration Maps
│   ├── gaspol-sync-docs/     CLAUDE.md maintenance
│   ├── gaspol-brainstorm/    CLAUDE.md-first ideation
│   ├── gaspol-design/        Design intelligence
│   ├── gaspol-parallel/      Parallel subagent execution
│   ├── gaspol-review/        Enhanced code review
│   ├── gaspol-receive-review/ Technical feedback handling
│   ├── gaspol-dispatch/      Parallel agent dispatch
│   ├── gaspol-tdd/           Test-driven development
│   ├── gaspol-debug/         Systematic debugging
│   ├── gaspol-worktree/      Git worktree management
│   ├── gaspol-finish/        Branch completion
│   ├── gaspol-kickstart/     Session startup
│   └── gaspol-write-skill/   Skill creation (meta)
├── design/                   UI/UX design search engine
├── README.md
├── LICENSE                   MIT
└── CHANGELOG.md
```

---

## Origin Story

This plugin was born from real frustration while building **Sparkfluence** — an AI-powered viral video generation platform with:
- React 18 + TypeScript + Vite frontend
- Supabase backend (PostgreSQL + Edge Functions)
- Python FastAPI + FFmpeg video processing
- Multi-model AI pipeline (Gemini, fal.ai, Groq)

After hundreds of plan-then-execute cycles, we identified the patterns where Claude Code consistently fails — and built skills to fix them. Every Iron Law, every Red Flag table, every Rationalization Prevention entry comes from a real incident where execution fell short.

**If you build complex software with Claude Code, these skills will save you hours of debugging placeholder implementations and hunting for skipped steps.**

---

## Contributing

Contributions welcome! When adding or modifying skills:

1. Follow TDD for skills (see `gaspol-write-skill`)
2. Test with pressure scenarios before submitting
3. Include rationalization prevention for discipline skills
4. Keep descriptions under 1024 characters with "Use when..." trigger format

---

## License

MIT License - see [LICENSE](LICENSE) for details.

Built with frustration and determination by [Ali Sadikin](https://github.com/alisadikinma).
