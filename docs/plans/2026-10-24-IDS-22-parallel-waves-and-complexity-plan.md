> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-22.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` block, (b) append a `## Log` line ending with the handoff cursor. Blocking, like a test gate. Never batch updates at the end. Update ONLY this file, never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec for execution. Every path, contract and line format the executor needs is written here verbatim.

**Ticket:** IDS-22
**Ledger:** .gaspol/progress/PROGRESS-IDS-22.md
**Spec:** docs/plans/2026-10-24-IDS-22-parallel-waves-and-complexity-spec.md
**Format:** waves-v1

## Goal

Make `gaspol-plan` decide, per phase, which phases may run in parallel (`Deps`) and how hard each
phase is (`Complexity`), compute the execution waves with the existing `dag-lanes` scheduler, and
let `gaspol-auto` run multi-phase waves concurrently while the orchestrator dispatches every
sub-agent with the `model` and `effort` the plan assigned. Today none of this exists: the plan
carries no dependencies or complexity, `gaspol-auto` is sequential (`skills/gaspol-auto/SKILL.md`
"For each phase in plan (sequential)"), and every implementer is hardcoded `sonnet`.

This plan is itself written in the `waves-v1` format, as the worked example and as a live fixture
for the new script.

## Architecture Context

Read from `CLAUDE.md` (repo root) and the files below.

- `skills/gaspol-parallel/scripts/dag-lanes` (Python, stdlib) already schedules
  `{"tasks":[{"id","deps","files"}]}` into waves and file-isolated lanes. It prints a matrix, a
  dispatch plan, then a line `JSON` followed by `{"waves": [[["A"],["B"]],[["C"]]]}` (wave →
  lanes → task ids). It rejects cycles, self-deps, unknown deps and duplicate ids with exit 1.
- `skills/gaspol-verify/scripts/model-gate` scans `agents/` and `skills/` markdown for `model:`
  declarations. It never reads a plan, so the plan check cannot live there. **This amends spec
  section 3** (see Phase A step 1).
- The four-exit-state contract (0 ok / 1 BLOCKING / 3 UNKNOWN / 4 not applicable, one
  `<name>: <verdict>` line on stdout on every path, detail on stderr) is the house contract of
  `ledger-gate`, `regression-gate`, `spec-pointer`, `model-gate`. Follow it.
- Scripts are invoked as `"$CLAUDE_PLUGIN_ROOT/skills/..."` with `${CLAUDE_PLUGIN_ROOT:?…}`, never
  by a relative path; `tests/ticket-scripts/test-kb-no-hardcoded-path.sh` gates this.
- `core.fileMode = false` in this repo: `chmod +x` never reaches the index. Use
  `git update-index --chmod=+x <file>` for every new executable and list it in
  `tests/ticket-scripts/test-scripts-executable.sh` `DIRECT`.
- Model rule (IDS-20, unchanged here): Opus judges, Sonnet works. Complexity changes **effort and
  review**, not tier.

## Tech Stack

bash + python3 stdlib scripts, bash tests under `tests/ticket-scripts/`, markdown skills.
`detect-stack` prints nothing for this repo (no stack markers), so verification is plan-declared:
`bash tests/ticket-scripts/<test>.sh` per phase and, at the end of each phase,
`for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done`.
Baseline recorded in the ledger: 52 tests pass, 0 fail, at `b92bf9c`.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| Wave scheduling | `skills/gaspol-parallel/scripts/dag-lanes` | stdout `JSON` block | Yes | Call from the new script; never reimplement the scheduler |
| Phase deps/files/complexity | the plan file itself (`### Phase X:` blocks) | parsed by new `plan-waves` | No | Create `skills/gaspol-plan/scripts/plan-waves` |
| complexity to model/effort/review | table inside `plan-waves` (single source) | `phase X complexity=… model=… effort=… review=…` lines | No | Create; skills read these lines, never restate the table |
| Wave table consumed by auto | `plan-waves` stdout | `wave N lane M: ids` lines | No | Create; `gaspol-auto` pre-flight reads it |
| Worktree isolation for waves | `gaspol-worktree` skill | Skill tool | Yes | Invoke from `gaspol-auto` before the first multi-lane wave |
| Review of complex phases | `gaspol-dev:code-reviewer` agent (opus) + `review-package` | Agent tool | Yes | Dispatch per complex phase from `gaspol-auto` |
| Fix-round bound | `skills/_shared/fix-loop.md` | text | Yes | Reference; do not restate the cap number |

## The `waves-v1` contract (copied here so no phase needs to look it up)

Plan header gains one line: `**Format:** waves-v1`. Each phase block gains two lines, placed between
the `### Phase X:` heading and `**Files:**`:

```text
  **Deps:** none            (or: A, B   — phase ids, comma separated, case-sensitive)
  **Complexity:** medium — <one-sentence reason>
```

- `Complexity` is `light`, `medium` or `complex`. The separator is an em dash `—` (a spaced
  hyphen ` - ` is also accepted). The reason after it may not be empty. A bare label is BLOCKING.
- `**Files:**` bullets keep today's form: ``- Create: `path` ``, ``- Modify: `path` ``,
  ``- Test: `path` ``. The first backticked token of each bullet is the path.
- A line that looks like a phase heading inside a fenced code block is NOT a phase.

Rubric: light = one file, no design decision. medium = several files, pattern already in the repo.
complex = new logic; money, auth or security; many interlinked files; an interface other phases
consume.

Mapping (lives only in `plan-waves`; every other file refers to its output):

| complexity | model | effort | review |
|---|---|---|---|
| light | sonnet | low | none |
| medium | sonnet | medium | none |
| complex | sonnet | high | opus |

`plan-waves <plan-file>` contract:

| Exit | stdout line 1 | Meaning |
|---|---|---|
| 0 | `plan-waves: OK — <n> phase(s), <m> wave(s)` | valid `waves-v1` plan; more stdout lines follow |
| 1 | `plan-waves: BLOCKING — <first problem>` | missing/invalid `Deps` or `Complexity`, empty reason, duplicate phase id, unknown dep, cycle, self-dep |
| 3 | `plan-waves: UNKNOWN — <why>` | plan unreadable, `dag-lanes` missing or crashed, `waves-v1` header present but zero phases parsed. STOP and ask |
| 4 | `plan-waves: N/A — no waves-v1 format header; treat as sequential, all medium` | legacy plan. Never counted as a pass |

On exit 0 the remaining stdout lines are, in this order: one `wave <N> lane <M>: <id> <id>` line
per lane (waves and lanes numbered from 1; ids inside a lane in sequential order), then one
`phase <id> complexity=<c> model=<m> effort=<e> review=<r>` line per phase in plan order.

## Execution Waves (output of `plan-waves` for this plan once Phase B exists)

Wave 1: A · Wave 2: B · Wave 3: C, D, E (parallel, disjoint files) · Wave 4: F.

## Out of scope

- The `gaspol-one` marketplace repo entry and its README version table: updated at publish time,
  after `gaspol-finish`, per the owner's release rule. Not part of this branch.
- `gaspol-execute` (per-phase checkpoints) does not use waves.
- No check that a declared `complexity` matches the real diff size.

---

### Phase A: plan-waves — parse and validate

**Deps:** none
**Complexity:** complex — new parser with four exit states and a fenced-block edge case that every later phase depends on
**Estimated time:** 15 minutes

**Files:**
- Create: `skills/gaspol-plan/scripts/plan-waves`
- Create: `tests/ticket-scripts/test-plan-waves.sh`
- Modify: `tests/ticket-scripts/test-scripts-executable.sh`
- Modify: `docs/plans/2026-10-24-IDS-22-parallel-waves-and-complexity-spec.md`

**Steps:**
1. Write failing test for plan-waves rejecting a waves-v1 plan whose phase has no Complexity line. Expected error: `plan-waves: No such file or directory` (script absent), then exit 1 BLOCKING once created.
2. Run the test, confirm it fails for that reason.
3. Amend the spec so the record matches the plan (a deliberate scope change must be written back to the spec): in section 3 replace the `model-gate` sentence with "A new script `skills/gaspol-plan/scripts/plan-waves` validates the `waves-v1` fields, because `model-gate` scans `skills/` and `agents/` and never reads a plan"; in section 4 replace "merge lanes" with "one isolation worktree; lanes touch disjoint files; the orchestrator, not the sub-agents, commits each phase by its declared files"; add to "Accepted costs": "full static/build ladder runs once per wave, after the wave, because lanes share one tree".
4. Create `plan-waves` (python3, stdlib, shebang `#!/usr/bin/env python3`) implementing the contract above for exits 0/1/4 only in this phase: find `**Format:** waves-v1`; parse phases (track ``` fences; heading regex `^### Phase ([A-Za-z0-9]+):`; block ends at next `^### ` or `^## `); parse `Deps`, `Complexity`, `Files`; validate; on exit 0 print only the `phase …` lines (waves arrive in Phase B). Read the file with explicit utf-8; print only fixed strings plus parsed values, never execute or interpolate plan text.
5. Cover every case in the test file, each in a throwaway temp dir: valid plan (exit 0, three `phase` lines with the mapping); no Format header (exit 4); header but phase without `Deps` (exit 1); phase without `Complexity` (exit 1); bare label `**Complexity:** complex —` with empty reason (exit 1); bare label with no dash (exit 1); value `hard` (exit 1); duplicate phase id (exit 1); phase heading only inside a fenced block (ignored, not counted); header present, zero phases (exit 3); nonexistent path (exit 3); `Deps: none` and `Deps: A, B` parse; spaced-hyphen separator accepted; run from a subdirectory (path resolution uses the argument, not `$PWD`).
6. Run the test, confirm all green.
7. `git update-index --chmod=+x skills/gaspol-plan/scripts/plan-waves tests/ticket-scripts/test-plan-waves.sh`; add `skills/gaspol-plan/scripts/plan-waves` to `DIRECT` in `test-scripts-executable.sh`.
8. Commit: "feat(gaspol-dev): plan-waves validates waves-v1 phase fields (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-plan-waves.sh` passes
- [ ] `bash tests/ticket-scripts/test-scripts-executable.sh` passes
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] `git ls-files -s skills/gaspol-plan/scripts/plan-waves` shows mode `100755`
- [ ] Spec file contains the three amendments from step 3
- [ ] No placeholder/TODO comments in new code
- [ ] Error paths: unreadable file, empty file, non-UTF-8 bytes each exit 3 with a one-line reason (covered by a test case); not applicable: network, concurrency
- [ ] Observability: every non-zero exit names the first offending phase id on stdout line 1

### Phase B: plan-waves — wave scheduling via dag-lanes

**Deps:** A
**Complexity:** medium — one integration with an existing scheduler, same file as Phase A so it follows it
**Estimated time:** 12 minutes

**Files:**
- Modify: `skills/gaspol-plan/scripts/plan-waves`
- Modify: `tests/ticket-scripts/test-plan-waves.sh`

**Steps:**
1. Write failing test for plan-waves printing wave and lane lines for a three-phase plan where B depends on A and C is independent. Expected error: stdout lacks the line `wave 1 lane 2: C` (phase A output has no wave lines yet).
2. Run the test, confirm it fails for that reason.
3. In `plan-waves`, build `{"tasks":[{"id","deps","files"}]}` from the parsed phases and call `skills/gaspol-parallel/scripts/dag-lanes` through `subprocess`, resolving its path from `os.path.realpath(__file__)` (`../../gaspol-parallel/scripts/dag-lanes`), never from `$PWD`. Parse its `{"waves": …}` JSON line (the line after the line `JSON`). Pass argv as a list, `shell=False`.
4. Map outcomes: dag-lanes exit 1 with a cycle, unknown dep, self-dep or duplicate message, which the script must pre-empt where cheap (duplicate ids are already caught in Phase A) → exit 1 BLOCKING quoting the dag-lanes message; dag-lanes missing, not executable, crashed, or printing no parseable JSON → exit 3 UNKNOWN. Print `plan-waves: OK — <n> phase(s), <m> wave(s)` then the `wave`/`lane` lines, then the `phase` lines.
5. Add test cases: dependency chain (3 waves); two phases sharing a file in the same wave land in one lane, ordered; cycle A↔B (exit 1); unknown dep (exit 1); self-dep (exit 1); `dag-lanes` made unreachable by running a copy of `plan-waves` in a temp tree with no sibling `dag-lanes` (exit 3); empty `Files` allowed; a plan with 12 phases schedules without error.
6. Add the live fixture: run `plan-waves` on this plan file (`docs/plans/2026-10-24-IDS-22-parallel-waves-and-complexity-plan.md`). Assert exit 0, six `phase` lines, and a wave containing three lanes (C, D, E). A fixture green only on synthetic plans proves nothing about the plan it ships with.
7. Run the full test file, confirm green.
8. Commit: "feat(gaspol-dev): plan-waves schedules waves through dag-lanes (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-plan-waves.sh` passes, including the live fixture
- [ ] `skills/gaspol-parallel/scripts/dag-lanes --self-test` still prints PASS (untouched)
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] No placeholder/TODO comments in new code
- [ ] Error paths covered: cycle, unknown dep, self-dep, scheduler missing, scheduler garbage output
- [ ] Run output for this plan shows Wave 3 with lanes for C, D and E

### Phase C: gaspol-plan writes the three fields and the wave table

**Deps:** B
**Complexity:** medium — edits one skill file following an established template, plus its anchoring gate
**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md`
- Create: `tests/ticket-scripts/test-plan-waves-wiring.sh`
- Modify: `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`

**Steps:**
1. Write failing test for the gaspol-plan skill carrying the waves-v1 contract. Expected error: `FAIL: skills/gaspol-plan/SKILL.md does not mention **Complexity:**`.
2. Run the test, confirm it fails for that reason.
3. In `skills/gaspol-plan/SKILL.md`: add `**Format:** waves-v1` to the Plan Document Header template (after `**Spec:**`/`**Artifact:**`); add `**Deps:**` and `**Complexity:**` lines to the Phase Structure template; add the complexity rubric and the rule "a bare label with no reason is refused" to the Completeness Gate or Phase Structure section; add a new section "Execution Waves (MANDATORY)": after writing all phases, run `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan-file>`; exit 0 → paste its `wave`/`lane` lines as an `## Execution Waves` section in the plan and as a `## Waves` section in the ledger above `## Log`; exit 1 → fix the plan and re-run; exit 3 → STOP and ask; never hand-schedule. Add `Deps:`/`Complexity:` counts to the existing self-check (equal to the number of `### Phase` headings).
4. Replace the parallel offer's condition text "only when the plan has independent phases" with "only when `plan-waves` printed a wave with two or more lanes".
5. Keep the numbers out of the skill: the model/effort/review table stays only in `plan-waves` and the rubric doc; the skill says "the orchestrator reads the `phase …` lines".
6. Widen `ANCHORED_SCRIPTS` in `test-kb-no-hardcoded-path.sh` with `gaspol-plan/scripts/plan-waves`, and add it to the per-script positive-control loop (it now has a real invocation in the skill). This is the same phase as the first invocation on purpose: adding the control earlier would be red.
7. Run the wiring test and the anchor test, confirm green.
8. Commit: "feat(gaspol-dev): gaspol-plan writes Deps/Complexity and computes waves (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-plan-waves-wiring.sh` passes
- [ ] `bash tests/ticket-scripts/test-kb-no-hardcoded-path.sh` passes
- [ ] `bash tests/ticket-scripts/test-ledger-template.sh` and `test-skill-frontmatter.sh` still pass
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] `grep -c "plan-waves" skills/gaspol-plan/SKILL.md` is at least 3, and every invocation uses `$CLAUDE_PLUGIN_ROOT`
- [ ] No placeholder/TODO comments

### Phase D: gaspol-auto runs waves

**Deps:** B
**Complexity:** complex — changes the autonomous execution loop: concurrency, commit ownership, hard-stop behaviour, per-phase review
**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-auto/SKILL.md`
- Create: `tests/ticket-scripts/test-auto-waves.sh`

**Steps:**
1. Write failing test for the gaspol-auto skill reading the wave table. Expected error: `FAIL: skills/gaspol-auto/SKILL.md does not invoke plan-waves`.
2. Run the test, confirm it fails for that reason.
3. Add pre-flight check 5 to `skills/gaspol-auto/SKILL.md`, invoked as `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan>`: exit 0 → keep the wave and `phase` lines; exit 1 → refuse to start and show the line; exit 3 → STOP and ask; exit 4 → legacy plan, run sequentially with every phase treated as medium, and record `waves: none — legacy plan` in the ledger.
4. Rewrite the Execution Loop to iterate **waves**, not phases. A wave with one lane of one phase behaves as today. A wave with two or more lanes: invoke `gaspol-worktree` once (Step 0 detection decides whether a worktree already exists), dispatch one implementer per lane concurrently in a single message; phases inside one lane run one after another. Dispatch rules: pass `model` and `effort` exactly as the plan's `phase` line gives; a `complexity=complex` phase is always dispatched, never done in-session; a `light` or `medium` phase in a single-phase wave keeps today's "in-session unless large" rule; every phase in a multi-lane wave is dispatched.
5. Commit ownership in a multi-lane wave: sub-agents write code and tests, run only the tests for their own files, and **do not commit**. After all lanes return, the orchestrator commits one commit per phase in plan order, staging only that phase's declared `Files:`. Then `git status --porcelain` must be empty. Anything left over is a file no phase declared: hard-stop under "Ambiguity in plan". Then run the full ladder (static, unit, build per `detect-stack`, per `skills/_shared/verification-loop.md`) once for the whole wave.
6. Complex-phase review: after the phase's commit and a green ladder, dispatch `gaspol-dev:code-reviewer` with `model: "opus"` scoped by `review-package <phase base sha> HEAD`. Critical or Important findings go through `skills/_shared/fix-loop.md` (the cap lives there; do not restate it). The ledger tick for that phase waits until the review is clean.
7. Hard-stop behaviour for a failed lane: lanes already in flight finish and their results are kept uncommitted; the wave stops; nothing from the next wave starts; the pause message lists each lane as completed, failed or not started. Ledger rows follow plan order after the wave: `## Phase log` row, checklist tick, one `## Log` line per phase with its `NEXT:` cursor.
8. Run the new test and the existing `test-finish-offer.sh`, `test-single-owner-gates.sh`, `test-verification-loop.sh`; fix any text assertion the rewrite legitimately changes, keeping the obligation it guarded.
9. Commit: "feat(gaspol-dev): gaspol-auto executes plan waves concurrently (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-auto-waves.sh` passes; it asserts: anchored `plan-waves` call; all four exit states handled by name; `gaspol-worktree` named; "do not commit" and "orchestrator commits" for multi-lane waves; `git status --porcelain` empty-after-commits rule; `gaspol-dev:code-reviewer` with opus for `complexity=complex`; `fix-loop.md` referenced with no cap number repeated; legacy fallback line `waves: none — legacy plan`
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] Hard-stop table in the skill is unchanged except for the new lane-failure sentence
- [ ] No placeholder/TODO comments
- [ ] Not applicable with reason: this phase edits instructions, so there is no runtime error path to test beyond the text assertions above

### Phase E: rubric, implementer prompt and parallel skill read the plan's assignment

**Deps:** B
**Complexity:** medium — three documents that must stop contradicting the new rule; no new logic
**Estimated time:** 12 minutes

**Files:**
- Modify: `docs/rubric-model-switching.md`
- Modify: `skills/gaspol-execute/implementer-prompt.md`
- Modify: `skills/gaspol-parallel/SKILL.md`
- Modify: `tests/ticket-scripts/test-model-rule.sh`

**Steps:**
1. Write failing test for the rubric recording complexity-driven effort. Expected error: `FAIL: docs/rubric-model-switching.md has no complexity/effort table`.
2. Run the test, confirm it fails for that reason.
3. `docs/rubric-model-switching.md`: add a section "Complexity sets effort and review, not tier" with the mapping table (light/medium/complex → sonnet, low/medium/high, review none/none/opus) and one sentence naming `plan-waves` as the single source of truth, plus the statement that the orchestrator passes `model` and `effort` from the plan and never infers them. State the cost: a complex phase now pays an Opus review each.
4. `skills/gaspol-execute/implementer-prompt.md`: replace "Override to `opus` when: architectural decisions inside the task, complex debugging, or spec-level reasoning required." with the rule that the model is `sonnet`, the `effort` comes from the plan's `phase` line, and an override above Sonnet needs a written reason at the call site (the rubric's existing override rule). Keep the Agent call example and add `effort` to it.
5. `skills/gaspol-parallel/SKILL.md` ("Always specify the model explicitly" paragraph, and Plan Intake step 2): when the plan is `waves-v1`, take deps, files, model and effort from `plan-waves` output instead of re-deriving them; the class-based guessing sentence applies only to legacy plans and independent-domains mode.
6. Run `test-model-rule.sh`, `test-dispatch-contract.sh`, and `skills/gaspol-verify/scripts/model-gate`; confirm green and that `model-gate` still exits 0.
7. Commit: "docs(gaspol-dev): complexity drives effort and review, tier stays two (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-model-rule.sh` passes with the new assertions
- [ ] `skills/gaspol-verify/scripts/model-gate` exits 0
- [ ] `grep -n "Override to .opus." skills/gaspol-execute/implementer-prompt.md` prints nothing
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] No placeholder/TODO comments
- [ ] Not applicable with reason: documentation phase, no runtime behaviour

### Phase F: release notes and CLAUDE.md sync

**Deps:** C, D, E
**Complexity:** light — documentation and a version bump over finished work
**Estimated time:** 8 minutes

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`
- Create: `tests/ticket-scripts/test-release-1-31.sh`

**Steps:**
1. Write failing test for the 1.31.0 release record. Expected error: `FAIL: plugin.json version is not 1.31.0`.
2. Run the test, confirm it fails for that reason. Mirror the structure of `tests/ticket-scripts/test-release-1-30.sh`.
3. Bump `.claude-plugin/plugin.json` to `1.31.0`; update the version line in `CLAUDE.md` footer and the README version line and changelog entry.
4. `CLAUDE.md`: add the `plan-waves` row to the Architecture table, a short "Parallel Waves + Complexity (NEW in v1.31, IDS-22)" section (the problem with its evidence, the `waves-v1` fields, the 3-row mapping stated once, the accepted costs and the does-not-close list copied from the spec), and update the `gaspol-auto` and `gaspol-plan` rows. Leave `Last ticket: IDS-22` as already set.
5. Run the release test and the full suite.
6. Commit: "chore(gaspol-dev): release 1.31.0 — parallel waves and per-phase complexity (IDS-22)".

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-release-1-31.sh` passes
- [ ] `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || exit 1; done` passes
- [ ] `CLAUDE.md` appears in the branch diff (evidence gate for `gaspol-sync-docs`)
- [ ] No placeholder/TODO comments
