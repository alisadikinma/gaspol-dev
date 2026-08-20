# Changelog

## [1.14.0] - 2026-08-21

### Changed — two skills deleted in favour of tooling every user already has (IDS-2)

gaspol carried a 1.7MB fork of the ui-ux-pro-max design database and a 12KB security checklist.
Both duplicated something already installed: the ui-ux-pro-max plugin itself, and
`/security-review`, which is compiled into the Claude Code CLI binary. Forks drift; the
originals do not. Both were deleted, and the parts with no equivalent upstream were kept.

- **`gaspol-design` deleted.** Design intelligence now comes from the `ui-ux-pro-max` plugin,
  referenced **softly** — there is deliberately no `dependencies` key in `plugin.json`, because
  that field is all-or-nothing and a yanked third-party marketplace entry would disable every
  remaining gaspol skill. If the plugin is missing, say so, point at
  `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`, and carry on.
- **Three parts survived the deletion**, each because ui-ux-pro-max has no equivalent:
  `design_audit.py` (a stdlib-only STATIC source lint; the upstream audit needs Playwright and a
  running URL, so it cannot serve `gaspol-verify` Layer 4, which runs offline and pre-merge),
  `anti-ai-slop.md`, and `reasoning-gaspol.md`. All three now live under `skills/gaspol-verify/`.
  The plan had claimed CLAUDE.md already duplicated the anti-slop rules; it holds a two-line
  summary against 119 lines of source, so execution paused and the premise was corrected rather
  than followed.
- **`gaspol-security-review` deleted.** `gaspol-finish` Step 4 and `gaspol-execute` Step 3.6 now
  run the built-in `/security-review`. The gate is unchanged: Step 4 still ALWAYS runs on every
  branch and still blocks merge options on any finding, and Step 3.6 keeps its full trigger list.
  New clause: if `/security-review` is unavailable, walk the same ground by hand and never record
  the step as passed when it did not run.
- **The security pressure test was kept, not deleted.** It tests whether the agent refuses to
  bless string-concatenated SQL and a JWT in `localStorage` under time pressure — discipline that
  did not move to the built-in, which only fires when explicitly invoked. Retargeted at
  `gaspol-execute`; fixture renamed `security-ship-pressure.txt`.

### Added — gaspol-review absorbs the two mechanics it was missing

`gaspol-review` was measured against Anthropic's official `code-review` plugin and **kept**. That
plugin is PR-only (all its tools are `gh pr ...`, it posts to a GitHub comment) so it cannot gate
a local branch before merge, and gaspol-review already runs all five of its review lanes plus
tiering and an adversarial refutation pass it lacks. Two things it did better are now absorbed:

- **Confidence rubric.** Each refuter returns `CONFIDENCE: 0-100` against a written five-point
  scale; below 80 a finding is recorded as noise rather than fixed.
- **False-positive catalogue.** Seven score-0 categories, including anything a linter or
  typechecker catches — with an explicit instruction not to run builds during review.
- **The verdict outranks the score.** REFUTED drops a finding at any score; an UNVERIFIABLE
  Critical still blocks regardless of score. The threshold can only demote a CONFIRMED finding to
  noise, never promote a REFUTED one or rescue a blocked one. Two Red Flags rows guard each
  direction.
- `/code-review ultra` documented as the deeper pass — user-triggered and billed, with an
  explicit "Claude cannot launch it".

### Changed — gaspol-finish gains three gates, gaspol-eval renamed (IDS-3)

Shipped in the same unreleased version as IDS-2.

- **`gaspol-eval` renamed to `gaspol-llm-test`.** "eval" reads as a shell builtin or a generic
  word outside ML; the skill tests LLM, prompt, and agent features whose output varies run to
  run. Ten files updated. Nothing downstream breaks — the old name survives only in historical
  plan documents. Deletion was proposed and withdrawn on evidence: it looked unused because
  usage was measured in THIS repo, which has no LLM feature; three other projects carry 1,080
  lines of real eval specs under `docs/evals/`.
- **The ledger lifecycle now ends.** `gaspol-plan` created `PROGRESS-<TICKET>.md` and
  `gaspol-execute` ticked it, but `gaspol-finish` mentioned it zero times against 23 mentions in
  execute. Being gitignored, a finished ticket's ledger never showed up in `git status` and just
  accumulated with a cursor still claiming work in flight. Finish now writes the closing
  `— NEXT: DONE` line, refuses to silently tick a `[ ]`/`[>]` entry, and runs
  `scan-active-ledgers` to surface any other open ledger.
- **`npm test` no longer hardcoded in finish.** IDS-1 added `detect-stack` to stop assuming npm;
  verify, parallel, plan, and execute all used it and finish was the last holdout, printing a
  command a Laravel or Go project cannot run.
- **Merging is not publishing.** "Merge locally" ended at `git branch -d`. Finish now requires
  `git push`, and for a plugin repo `claude plugin marketplace update` +
  `claude plugin update <plugin>@<marketplace>` (the full id — the bare name fails with
  `Plugin "<name>" not found`) plus a restart. This is how v1.13.0 sat inert on one machine
  while the repo claimed it had shipped.
- **Step 5 is evidence-gated.** `[x] Step 5 gaspol-sync-docs: COMPLETED` was self-reported and
  unverified. CLAUDE.md must now appear in the branch diff whenever the branch changed anything
  structural; a branch with no structural change must say so rather than record a bare COMPLETED.
- **`gaspol-receive-review` compliance is now observable.** It produces no artifact, so commits
  touching it proved maintenance, not obedience — the only skill whose compliance could not be
  measured. A pressure case feeds it review feedback that is wrong in three ways, wrapped in
  seniority and deadline pressure; it passes only if the agent refutes rather than complies.

### Fixed

- CLAUDE.md documented the finish chain as five steps; it has been six since v1.8. `gaspol-review`
  (Step 3) and the security review (Step 4) were missing from the documented chain entirely.
- Skill count corrected to 20 across CLAUDE.md, README.md, and marketplace.json, and the new
  `test-skill-delegation.sh` derives it from `ls` so it cannot silently drift again.

## [1.13.0] - 2026-08-20

### Added — output naming standard: dated spec/plan files, PROGRESS-<TICKET>.md ledger, detect-stack (IDS-1)

Field report: plan/spec filenames collided across tickets sharing a topic slug, the ledger's
`.gaspol/progress/<slug>.md` path gave no per-phase checklist a human could scan at a glance, and
Layer 1 / Validation Ladder verification hardcoded `npm run build` / `npx tsc --noEmit` even on
non-Node projects. Seven phases close all three gaps (A-F as planned, plus G adding the same conventions to
`gaspol-worktree`).

**Suite status, measured not assumed:** ticket-scripts 4/4, skill-triggering 6/6,
pressure 3/9 (exit 1). The pressure suite spawns real `claude` CLI runs and is stochastic —
two measurements on this branch both scored 3/9 but with different failure composition, one
with zero capitulations and one with two. Its redness predates this release: `tests/pressure/`
is untouched here, no skill `description:` frontmatter changed (frontmatter drives triggering),
and a baseline measurement at cd8bd1a scored 1/9. Repairing that suite is its own ticket.

- **Dated spec/plan filenames.** `gaspol-brainstorm` and `gaspol-plan` now write
  `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-{spec,plan}.md`. `gaspol-plan` locates its spec by
  glob (`docs/plans/*-<TICKET>-*-spec.md`) instead of reconstructing the filename, and STOPs to
  ask the user if more than one file matches. Seven pre-ticket files in `docs/plans/` predate the
  convention and are deliberately not renamed.
- **Case-insensitive ledger scan.** `scan-active-ledgers` now globs `PROGRESS-*.md` as well as
  lowercase `progress-*.md`.
- **`PROGRESS-<TICKET>.md` ledger with a per-phase checklist.** `gaspol-plan` creates
  `.gaspol/progress/PROGRESS-<TICKET>.md` at plan-write time: a `## Checklist` block (`[ ]` todo /
  `[>]` doing / `[x]` done / `[~]` cancelled-with-mandatory-reason) above a `## Log` block that is
  ALWAYS last. `gaspol-execute` and `gaspol-parallel` gain a BLOCKING per-phase gate — tick the
  checklist AND append the Log line with its `— NEXT:` cursor before the next phase starts. Older
  ledger paths are still read for backward compatibility.
- **`detect-stack`** (`skills/gaspol-execute/scripts/detect-stack`) — reads stack marker files at
  a project root and prints `<level>: <command>` lines (static/lint/unit/build); prints `UNKNOWN`
  when a marker exists but its backing command doesn't (`command -v` checks for
  python/go/rust/flutter too); prints nothing when there are no markers.
- **Verification commands are derived, not hardcoded.** `gaspol-verify` Layer 1 and
  `gaspol-parallel`'s Validation Ladder L1–L3 now run `detect-stack` instead of assuming npm;
  `gaspol-plan` copies its output verbatim into each phase's Verification block, and
  `implementer-prompt.md` carries it verbatim to dispatched subagents. Three documented result
  cases: a command line → run it; `UNKNOWN` → STOP and ask the user; zero lines → fall back to the
  plan-declared commands, recorded explicitly rather than silently skipped.

## [1.10.1] - 2026-07-11

### Changed — ledger update is now a hard per-phase gate

Field report: an external executor filled the per-plan ledger only once at the end of the run
(or not visibly during it), so mid-run it still read all-`todo` and a crash would have recorded
zero progress. The contract wording was too soft ("update after each phase"). Strengthened the
plan header (`gaspol-plan`) to state the ledger write is **blocking, like a test gate**: after
each phase and BEFORE the next, append the line (`doing` on start → `done` + command/result on
green); never batch at the end. No API change — wording/enforcement only.

## [1.10.0] - 2026-07-11

### Added — two-lane execution (plan-once, run-anywhere)

The plan artifact is now identical whether executed **in-session** or handed to a **separate
executor process** — the lane is chosen by one optional config, not by two plan formats. Planning
and review stay in the (expensive) main session; heavy codegen can run in a cheaper executor,
saving tokens. Works fully with zero config (pure in-session).

- **`gaspol-plan` — self-contained plan header.** Every plan now declares a `Progress ledger:`
  path and a `Self-contained:` contract: the plan must be executable by an agent with no other
  context (a fresh post-`/compact` session, or an external executor that can't see the chat or a
  linked PDF) — every path, contract, config key, and convention written verbatim, not linked.
- **`gaspol-plan` — Execution Handoff Option 4: External executor.** Surfaces **only if**
  `$GASPOL_EXECUTOR` or a `.gaspol/executor` file is set (a command template with `{plan}`/`{ledger}`
  placeholders, e.g. `aider --file {plan}`). Unset → hidden → Options 1–3 work exactly as before.
  gaspol-dev ships **no executor of its own** and never invents one; the external tool implements +
  tests to green but **never commits** — the diff returns for review + commit.
- **Per-plan progress ledger.** `gaspol-execute`/`gaspol-parallel` now read/write the plan's declared
  `.gaspol/progress/<slug>.md`, so concurrent plans no longer overwrite each other's ledger. Falls
  back to the shared `.gaspol/progress.md` when a plan names none (backward-compatible).
- **New Red Flags:** plan that only makes sense with chat context; missing `Progress ledger:` header.

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
