# Changelog

## [1.3.0] - 2026-06-03

### Added (superpowers-parity hardening)
- **`gaspol-worktree`** — isolated git worktree skill: Step 0 existing-isolation detection (with submodule guard), native-tool-first (`EnterWorktree`) then safe `git worktree` fallback, mandatory gitignore safety verification, clean-baseline gate. Adapted from superpowers `using-git-worktrees` (MIT).
- **`using-gaspol`** — bootstrap meta-skill: the 1% rule, full routing table, instruction-priority hierarchy, and rationalization Red Flags. The auto-trigger backbone. Adapted from superpowers `using-superpowers` (MIT).
- **`tests/skill-triggering/`** — auto-trigger test harness (`run-test.sh`, `run-all.sh`, naive intent prompts): skills must fire from intent alone, not from a slash command.
- **`tests/pressure/`** — pressure tests: rigid skills (`gaspol-tdd`, anti-placeholder) must hold under "skip the test" / "just hardcode it" pressure.

### Changed
- **`hooks/session-start.sh`** — upgraded from a passive echo into a forceful bootstrap directive (1% rule + compact routing table + Iron Law reminders) injected into every session, so skills auto-trigger reliably in any project.
- **`gaspol-parallel`** — added Phase 0 worktree isolation (required before concurrent dispatch) and a continuous-execution discipline (no per-task check-ins; bounded always-pause conditions).
- **`gaspol-finish`** — documents worktree teardown ownership (`git worktree remove` after the merge/PR decision, never before).
- **README comparison table** — corrected the outdated "superpowers design intelligence ✗" claim (superpowers shipped a visual brainstorm loop); added worktree / bootstrap / test-harness parity rows.

## [1.2.0] - 2026-04

### Added
- Cross-project knowledge base (GitHub-synced, per-user private, freshness-aware)
- Power-peer design intelligence (`gaspol-design`: 85+ styles, 162+ reasoning rules, multi-framework)
- Auto-rubric model switching (Opus / Sonnet / Haiku per task type)
- Step-level evidence-based plan-verifier (BLOCKING)
- Industry research grounding with TTL cache (`gaspol-research`)
- 5 new skills: `gaspol-research`, `gaspol-adr`, `gaspol-learn`, `gaspol-kb-audit`, `gaspol-auto`
- Tiered auto-review per phase + KB lifecycle management

## [1.0.0] - 2026-02-11

### Added
- **18 skills** for execution fidelity, anti-placeholder enforcement, and design intelligence
- **4 agents** (plan-verifier, code-reviewer, spec-reviewer, code-simplifier)
- **Anti-Placeholder Iron Law** — enforced throughout execution chain
- **Per-Phase Checkpoints** — structured reports with user approval gates
- **Plan Verification Agent** — compares plan vs git diff post-implementation
- **CLAUDE.md-First Rule** — read project docs before exploring codebase
- **gaspol-sync-docs** — 3-mode CLAUDE.md maintenance (sync, audit, session learning)
- **gaspol-design** — frontend design intelligence with anti-AI-slop rules
- **Design Search Engine** — BM25 search across 8 design domains
- **Data Integration Maps** — mandatory in every plan, contract between planner and executor

### Skills
- `gaspol-brainstorm` — CLAUDE.md-first ideation with design intelligence auto-trigger
- `gaspol-design` — data-driven frontend design with bold aesthetics
- `gaspol-plan` — implementation plans with Data Integration Maps
- `gaspol-execute` — anti-placeholder execution with per-phase checkpoints
- `gaspol-parallel` — subagent-driven development with placeholder detection
- `gaspol-verify` — 4-layer verification (technical, plan fidelity, placeholder, integration)
- `gaspol-sync-docs` — CLAUDE.md maintenance and quality audit
- `gaspol-review` — enhanced code review with data integrity checks
- `gaspol-receive-review` — technical rigor over performative agreement
- `gaspol-dispatch` — parallel agent dispatch for independent problems
- `gaspol-tdd` — RED-GREEN-REFACTOR with rationalization prevention
- `gaspol-debug` — systematic 4-phase root cause investigation
- `gaspol-worktree` — git worktree management with safety checks
- `gaspol-finish` — branch completion with mandatory verification chain
- `gaspol-kickstart` — session startup and skill discovery
- `gaspol-write-skill` — TDD applied to skill creation

### Absorbed
- `claude-md-management` functionality (now in gaspol-sync-docs)
- `code-simplifier` functionality (now in code-simplifier agent)
