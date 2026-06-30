# Changelog

## [1.8.0] - 2026-06-30

### Added — ECC-adoption (3 selective ports from a local kitchen-sink toolkit; rest rejected as bloat)

- **DAG lane scheduling** (`skills/gaspol-parallel/scripts/dag-lanes`) — a deterministic Python3
  stdlib-only (`graphlib`) scheduler that turns `gaspol-parallel` mode `independent-domains`'
  binary conflict-check ("can all run parallel? y/n") into dependency **waves** (topological
  layers) + file-isolated **lanes** (within a wave, tasks sharing any file → one sequential lane
  via union-find; no overlap → concurrent). A single dependency no longer forces the whole batch
  sequential. Prints a LANE VERIFICATION MATRIX proving no two concurrently-dispatched tasks
  touch the same file. Rejects cycles / unknown deps / duplicate + missing ids with clean errors
  (no traceback); has `--self-test` (7 cases). Zero new dependencies.
- **Adversarial refutation** (`gaspol-review` Step 2.5) — before any Critical/Important finding
  is acted on, one refuter subagent per finding (default REFUTED, verdict
  `CONFIRMED | REFUTED | UNVERIFIABLE`) tries to disprove it. Kills hallucinated findings before
  a wrong "fix" breaks working code; `UNVERIFIABLE` (runtime-only) fails safe → CONFIRMED. Only
  confirmed/unverifiable Critical findings block. Wired into `gaspol-parallel` Step 6.
- **Per-task Validation Ladder** (`gaspol-parallel` Step 4 + `implementer-prompt.md`) — an
  implementer may not report `DONE` until an ordered fail-fast ladder passes: L1 Static (tsc +
  lint) → L2 Unit → L3 Build → L4 Integration → L5 Edge (non-happy paths actually run). Cheap
  levels gate expensive ones; fail → fix → restart from L1; an N/A level is skipped *explicitly*
  (silent skip = placeholder-grade lie). Does NOT replace the independent spec + quality reviews
  (Steps 5–6) — self-validation and independent review are different guarantees.
- **Pressure test** (`tests/pressure/prompts/gaspol-parallel-skipladder.txt`) — verifies an
  implementer resists "skip the build/integration/edge levels, mark it DONE."

### Why

- Compared `gaspol-parallel`/`gaspol-execute` against a local 200-skill / 70-agent toolkit
  ("ECC"). Verdict: not strictly better, different axes — ECC had 3 real ideas worth porting
  (parallel throughput, review trust, verification depth); the rest (200+ skills, multi-IDE,
  external-model subagent zoo, per-language reviewers) is surface area, not value, and was
  deliberately NOT adopted (ponytail: focus + Iron Laws beat breadth). Self-reviewed via
  `gaspol-review`; the review's own Critical was refuted (Step 2.5 dogfood), 2 Important +
  minors fixed.

## [1.7.0] - 2026-06-30

### Added — superpowers-adoption Phase 3 (#1 visual brainstorm companion, flagship; from superpowers MIT)

- **Visual companion** (`skills/gaspol-brainstorm/visual-companion/`) — a browser-based loop
  for showing mockups, diagrams, and side-by-side options during brainstorming/design. A local
  Node server (zero npm deps) watches a screen dir, serves the newest HTML to the user's
  browser (auto-wrapping content fragments in a frame), and records click/selection events to a
  state dir the orchestrator reads next turn. Offered **just-in-time** (never upfront) and wired
  into `gaspol-brainstorm` Phase 3; `visual-companion.md` is the operator guide.
- **gaspol-design fusion** — the companion renders `gaspol-design` output (palette, layout
  blueprint, 162+ rules) into the mockups: gaspol now has both the design *knowledge* and the
  interactive *loop* (superpowers had the loop, gaspol adds the knowledge).
- **Vendored + rebranded from obra/superpowers (MIT)** — see `NOTICE.md`. Privacy/brand strip:
  removed the remote brand-image fetch to primeradiant.com and the telemetry plumbing (**the
  server now makes zero outbound requests**); session files moved to `.gaspol/brainstorm/`;
  brand is local text-only; version reads the gaspol manifest.
- **Security-reviewed (🟢 PASS)** — session-key auth is constant-time on HTTP (403 unkeyed) and
  on the WebSocket upgrade (key + origin allow-list); `/files/` serving has a `realpath`
  containment guard against path traversal; binds loopback by default; `X-Frame-Options: DENY`
  + `CSP frame-ancestors 'none'`; session key + server-info are owner-only (umask 077 / 0o600).
- **`smoke-test.sh`** — proves the server boots, serves the keyed bootstrap (200), rejects
  unkeyed requests (403), and stops clean (screen render itself is WebSocket+browser, validated
  live).

### Why

- Phase 3 (flagship) of `docs/plans/2026-06-30-superpowers-adoption.md` — the last and heaviest
  of the four adopted mechanisms. Completes the roadmap (v1.5 #3+#4, v1.6 #2, v1.7 #1). The
  `indusia-image-gen` fusion (real preview images vs HTML wireframes) is noted as a future v1.8
  stretch, not built here.

## [1.6.0] - 2026-06-30

### Added — superpowers-adoption Phase 2 (#2 SDD per-task review harness, from superpowers v6 MIT)

- **Status protocol** (`gaspol-parallel`) — the implementer subagent now reports one explicit
  terminal status: `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
  (`implementer-prompt.md` §0). The orchestrator routes on it — `NEEDS_CONTEXT` → provide
  context + re-dispatch; `BLOCKED` → assess, **never** blind-retry the same model — instead of
  treating every return as "done".
- **`review-package` script** (`skills/gaspol-parallel/scripts/review-package`) — deterministic
  task-diff artifact: `review-package <BASE> HEAD` writes commits + stat + patch to
  `.gaspol/review/<base>-<head>.diff` and prints the path, so the spec/quality reviewers audit
  one stable artifact. Records the superpowers gotcha as a hard guard: **rejects `HEAD~1` as
  BASE** (it silently drops all but the last commit of a multi-commit task). Ships a
  `--self-test`.
- **Per-task model dispatch** (`gaspol-parallel`) — "always specify the model explicitly,"
  scaled by task class (mechanical→cheap, integration→standard, architecture/review→capable,
  per `docs/rubric-model-switching.md`). Principle: **turn count beats token price**.
- **Fix → re-review loop** — Critical/Important review findings now dispatch a fix then
  **re-run the review** until clean, rather than "fix and move on."
- Pressure test `tests/pressure/prompts/gaspol-parallel-skipreview.txt` (resists "skip the
  review, just mark all tasks done"), registered in the pressure aggregator.

### Why

- Phase 2 of `docs/plans/2026-06-30-superpowers-adoption.md`. gaspol-parallel already had
  fresh-subagent-per-task + two-stage review; this closes the gaps vs superpowers v6's
  `subagent-driven-development` rewrite (explicit status, deterministic review package,
  per-task model choice, enforced re-review). #1 (visual brainstorm companion) remains for v1.7.

## [1.5.0] - 2026-06-30

### Added — selective adoption from superpowers v6 (MIT)

- **Brainstorm hardening** (`gaspol-brainstorm`) — three gates ported from superpowers'
  `brainstorming` skill: a **HARD-GATE** (no implementation skill / code / scaffold until a
  design is presented AND user-approved, every project regardless of perceived simplicity);
  a **decompose gate** in Phase 1 (flag multi-subsystem requests, split into sub-projects,
  each with its own spec→plan→implement cycle); and **spec self-review + user-reviews-spec**
  in Phase 6 (scan the written design for placeholder/contradiction/ambiguity/scope, then
  the user approves the written spec before planning). Also fixed a pre-existing duplicate
  `## Phase 1` header. Pressure test added (`tests/pressure/prompts/gaspol-brainstorm-hardgate.txt`).
- **Durable progress ledger** (`gaspol-execute`, `gaspol-parallel`) — phase/task state is now
  appended to a `.gaspol/progress.md` working-tree file that **survives `/compact` and session
  restart** (TodoWrite is in-memory and lost on compaction). `gaspol-execute` Step 3 reads the
  ledger on start to resume from the first unfinished phase. Written under `.gaspol/` (gitignored
  scratch), **never** under `.git/` — Claude Code treats `.git/` as a protected path and blocks
  agent writes there (lesson from superpowers v6.0.3). Caveat documented: `git clean -fdx`
  deletes it, recover from `git log`.
- **`tests/pressure/run-all.sh`** — new aggregator that runs every pressure case
  (tdd-skip, placeholder, security-review, brainstorm-hardgate) with its forbidden-capitulation
  regex; previously pressure cases could only be run one at a time.

### Why

- This is **Phase 1 of the superpowers-adoption roadmap** (see
  `docs/plans/2026-06-30-superpowers-adoption.md`): the two cheapest-highest-leverage gaps —
  pure-additive, no new skill, no dependency. #2 (SDD per-task review harness) is queued for
  v1.6; #1 (visual brainstorm companion) for v1.7.

## [1.4.0] - 2026-06-09

### Added — selective adoption from ECC (Everything Claude Code)
- **`gaspol-security-review`** — new rigid skill. Security checklist across 9 categories
  (secrets, input validation, SQL injection, auth/authz, XSS, CSRF, rate limiting,
  sensitive-data exposure, dependency security) plus a Supabase Row-Level-Security
  section and a 16-item Pre-Deployment Security Checklist. Ported and adapted from the
  ECC `security-review` skill (MIT); the blockchain/Solana section was dropped as
  out-of-stack. Auto-triggered by `gaspol-execute` (Step 3.6) on security-sensitive
  phases and gated by `gaspol-finish` before merge/PR. Pressure test added (it is a
  second-order skill — auto-triggered downstream, so it is not cold-prompt
  triggering-tested, like `gaspol-design`/`adr`/`learn`).
- **`gaspol-eval`** — new flexible skill. Eval-driven development for non-deterministic /
  LLM features (classification, extraction, generation, RAG, agents): capability +
  regression evals, three grader types (code / model-as-judge / human), and pass@k /
  pass^k metrics. Ported from the ECC `eval-harness` skill (MIT); eval definitions live
  in `docs/evals/` (project-local — regression baselines are codebase-specific) rather
  than the cross-project KB. Defined at plan time, run by `gaspol-verify`. Complements
  `gaspol-tdd` (TDD for deterministic code, eval for non-deterministic behavior); does
  not replace it. Second-order skill (auto-triggered via plan/verify wiring), so not
  cold-prompt triggering-tested.

### Why

- **security-review:** gaspol-review covers general quality but had no security-specific
  lens (secrets, SQLi, authz, RLS). Closes a real gap with a stack-fit checklist rather
  than adopting ECC's broad library wholesale.
- **eval:** gaspol-tdd asserts deterministic code, but a prompt edit is a behavior change
  with no compiler and no single `expect()` to catch regressions. Most of gaspol's own
  surface and Ali's content suite are LLM/prompt systems — this closes the
  non-deterministic verification gap.

## [1.3.1] - 2026-06-03

### Changed — KB works out of the box (local-only default)
- The cross-project Knowledge Base no longer requires a GitHub repo or `gaspol-config.json`. On first use the local KB auto-inits at `~/.claude/gaspol-knowledge/` and `gaspol-adr` / `gaspol-learn` start capturing immediately. GitHub sync is now an **optional upgrade**.
- New canonical doc **[docs/kb-setup.md](docs/kb-setup.md)** — 3-mode resolution: `local-only` (default), `synced` (remote configured), `off` (explicit `"kb_mode":"off"`).
- Reworked KB mechanics in `gaspol-brainstorm` (Phase 0.5), `gaspol-adr`, `gaspol-learn`, `gaspol-research`, `gaspol-kb-audit`: pull/push are now **conditional on synced mode**; commits always happen locally; missing remote is no longer a fail-loud condition. The old "no config → skip" behavior is replaced by "no config → local-only".
- `session-start.sh` now prints the active KB mode (local-only / synced / off) so the user can see the flywheel is live.

### Why
adr & learn were effectively dormant for any user who never did the manual GitHub setup (silent-skip). This makes the KB flywheel — the headline "compounding knowledge" differentiator vs superpowers — active by default, with zero onboarding friction.

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
