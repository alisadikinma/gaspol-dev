> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-6.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. Blocking, like a test gate. Never batch updates at the end. Update ONLY this file.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with no other context.

**Ticket:** IDS-6
**Ledger:** .gaspol/progress/PROGRESS-IDS-6.md
**Spec:** docs/plans/2026-08-21-IDS-6-execution-hygiene-and-visual-contract-spec.md
**Artifact:** https://claude.ai/code/artifact/b8792896-4099-4399-a9e9-76c4779efab9

## Goal

Stop the controller's context from degrading across a long build, and cut the three
measured pieces of standing overhead in the plugin itself. Part A installs task-scoped
brief files, report files, a five-round fix loop with model escalation, scoped
re-reviews, and a pre-flight plan conflict matrix. Part C applies the findings of the
2026-08-21 token audit. Both halves lower the token cost of every run that follows —
this ticket makes gaspol cheaper, not heavier. The visual contract designed in the spec
is deferred to a later ticket, because Part A is what makes it cheap to build.

## Architecture Context

Pulled from this repo's `CLAUDE.md`:

- Skills live at `skills/<name>/SKILL.md`; reference files are kebab-case siblings.
- Existing scripts: `skills/gaspol-execute/scripts/detect-stack`,
  `.../next-ticket`, `.../scan-active-ledgers`,
  `skills/gaspol-parallel/scripts/review-package` (takes `<BASE> <HEAD>`, rejects
  `HEAD~1`), `skills/gaspol-parallel/scripts/dag-lanes`.
- Dispatch templates: `skills/gaspol-parallel/implementer-prompt.md`,
  `.../spec-reviewer-prompt.md`, `.../code-quality-reviewer-prompt.md`.
- Ledger convention: `.gaspol/progress/PROGRESS-<TICKET>.md`, `## Log` always last.
- Design assets kept after the v1.14 delegation:
  `skills/gaspol-verify/scripts/design_audit.py` (static, offline),
  `skills/gaspol-verify/rules/anti-ai-slop.md`, `.../reasoning-gaspol.md`.
- Deterministic tests: `tests/ticket-scripts/test-*.sh`, run individually with
  `bash`, `set -euo pipefail`, exit 0 means pass. `tests/ticket-scripts/test-prior-art-gate.sh`
  is the precedent for asserting on SKILL.md prose; `tests/ticket-scripts/test-skill-delegation.sh`
  is the precedent for asserting cross-skill routing.
- Trigger tests: `tests/skill-triggering/prompts/<skill>.txt` listed in that
  directory's `run-all.sh`.
- Routing lives in three places that must stay in sync: this repo's `CLAUDE.md`,
  `hooks/session-start.sh`, and `skills/using-gaspol/SKILL.md`.

## Tech Stack

Bash (POSIX-ish, `set -euo pipefail`) for scripts, Markdown for skills, Python 3
stdlib only where a script needs more than bash (matching `design_audit.py`'s
existing constraint). No new runtime dependency is added to this repo.

`detect-stack .` prints **zero lines** for this repo (no stack markers). Every
phase's Verification block therefore uses plan-declared commands, per the
`gaspol-plan` rule for that case.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---|---|---|---|---|
| task brief extraction | plan `-plan.md` in `docs/plans/` | new `scripts/task-brief` | No | Create — parse markdown headings, same conventions as `review-package` |
| brief + report files | `.gaspol/tasks/<TICKET>/` | filesystem | No | Create dir at dispatch time; gitignored |
| fix-loop round state | `.gaspol/progress/PROGRESS-<TICKET>.md` | existing ledger | Yes | Append round lines to `## Log` |
| conflict matrix | same ledger | existing ledger | Yes | New table written above `## Log` |
| scoped re-review diff | git | existing `scripts/review-package <BASE> <HEAD>` | Yes | Reuse with `FIX_BASE`; no script change |
| audit measurements | 2026-08-21 token audit, quoted in Part C | none — figures inlined below | Yes | Use the inlined numbers; do not re-measure |

Nothing in this table is allowed to become a placeholder. Every row is produced by a
real script or a real skill step.

---

# PART A — Execution Hygiene

**Sequencing constraint: every Part A phase must be complete and verified before
Phase C1 starts.** Part C trims prose in skills Part A also edits; trimming first would
force the same files to be reworked twice.

### Phase A1: `task-brief` script

**Estimated time:** 12 minutes

**Files:**
- Create: `skills/gaspol-parallel/scripts/task-brief`
- Test: `tests/ticket-scripts/test-task-brief.sh`

**Steps:**
1. Write failing test for `task-brief` extracting a single task's text from a plan file. Expected error: `bash: skills/gaspol-parallel/scripts/task-brief: No such file or directory`.
2. Run test, confirm it fails for the expected reason.
3. Implement `task-brief <PLAN_FILE> <N>`: locate the Nth `### Phase ` heading, write everything up to the next `### ` or `---` into `.gaspol/tasks/<TICKET>/task-<N>-brief.md` (TICKET read from the plan's `**Ticket:**` header line), print the written path on stdout, create parent dirs.
4. Extend the test: usage error with no args (exit 2), a plan whose `**Ticket:**` line is missing (exit 2, message names the missing field), N out of range (exit 2), and that stdout is exactly one path line.
5. Run tests, confirm all pass.
6. Commit: "feat(parallel): task-brief extracts one task to a file (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-task-brief.sh` exits 0
- [ ] `skills/gaspol-parallel/scripts/task-brief` is executable (`test -x`)
- [ ] Stdout is exactly one line — the brief path — so a caller can consume it directly
- [ ] No placeholder/TODO comments in new code
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase A2: Dispatch contract — brief path in, report file out

**Estimated time:** 14 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`
- Modify: `skills/gaspol-parallel/implementer-prompt.md`
- Test: `tests/ticket-scripts/test-dispatch-contract.sh`

**Steps:**
1. Write failing test asserting `skills/gaspol-parallel/SKILL.md` contains the narrowed rule (never reference the plan; always reference the task-scoped brief) and names `scripts/task-brief`. Expected error: test assertion failure, `expected SKILL.md to reference scripts/task-brief`.
2. Run test, confirm it fails for the expected reason.
3. Edit `SKILL.md`: replace the blanket `NEVER reference a file` wording with the narrowed rule, and specify the five dispatch contents verbatim — (a) one line of project context, (b) the brief path introduced as the requirements to use verbatim, (c) interfaces and decisions from earlier tasks, (d) the controller's resolution of ambiguity it spotted, (e) the report-file path. State that exact values (numbers, magic strings, signatures, test cases) live only in the brief.
4. Edit `implementer-prompt.md`: the implementer writes its full report to `.gaspol/tasks/<TICKET>/task-<N>-report.md` and returns only status, commit list, one-line test summary, and concerns. Add the no-subagents clause: the implementer never dispatches subagents, and never a reviewer.
5. Extend the test to assert the report-file contract and the no-subagents clause are both present.
6. Run tests, confirm all pass.
7. Commit: "feat(parallel): file-based dispatch handoff, report file per task (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-dispatch-contract.sh` exits 0
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` still exits 0 (no routing regression)
- [ ] The old blanket phrase `NEVER reference a file` no longer appears in `skills/gaspol-parallel/SKILL.md`
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase A3: Five-round fix loop with model escalation

**Estimated time:** 14 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`
- Create: `skills/gaspol-parallel/re-review-prompt.md`
- Test: `tests/ticket-scripts/test-fix-loop.sh`

**Steps:**
1. Write failing test asserting `SKILL.md` describes five fix rounds, resume-same-implementer for rounds 1-3, and fresh-implementer-one-tier-up for rounds 4-5. Expected error: test assertion failure, `expected SKILL.md to describe rounds 4-5 escalation`.
2. Run test, confirm it fails for the expected reason.
3. Edit `SKILL.md`: replace the "3 attempts then escalate to user" rule. Rounds 1-3 resume the same implementer with the open findings verbatim. Rounds 4-5 dispatch a fresh implementer one model tier above the stuck one, framed as "a prior implementer attempted this task N times; you own it now — read the report file for what was tried." Every round: the implementer fixes, re-runs the tests covering the amended code, appends its fix report to the same report file; the controller confirms covering tests, the command run, and the output are all present before dispatching the re-review. State the round-5 breaker: adjudicate each open finding rather than looping forever.
4. Create `re-review-prompt.md`: inputs are the findings list, the brief path, the report file, and the scoped diff path; the re-reviewer verdicts each finding as addressed or not, and does not open new broad review ground.
5. Extend the test to assert `re-review-prompt.md` exists and names all four inputs.
6. Run tests, confirm all pass.
7. Commit: "feat(parallel): 5-round fix loop with tier escalation + re-review prompt (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-fix-loop.sh` exits 0
- [ ] `skills/gaspol-parallel/re-review-prompt.md` exists and is non-empty
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase A4: Scoped re-review wiring

**Estimated time:** 8 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`
- Test: `tests/ticket-scripts/test-fix-loop.sh` (extend)

**Steps:**
1. Write failing test asserting `SKILL.md` instructs `review-package <PLAN_FILE> <FIX_BASE> HEAD` where `FIX_BASE` is the head the previous review saw. Expected error: test assertion failure, `expected SKILL.md to define FIX_BASE`.
2. Run test, confirm it fails for the expected reason.
3. Edit `SKILL.md`: define `FIX_BASE`, state that the re-review reads only the fix diff, and keep the existing prohibition on `HEAD~1` visible in the same paragraph.
4. Run tests, confirm all pass.
5. Commit: "feat(parallel): scoped re-review against FIX_BASE (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-fix-loop.sh` exits 0
- [ ] `skills/gaspol-parallel/scripts/review-package` is unchanged (`git diff --stat` shows no edit to it)
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase A5: Pre-flight plan conflict matrix (BLOCKING gate)

**Estimated time:** 12 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`
- Modify: `skills/gaspol-execute/SKILL.md`
- Test: `tests/ticket-scripts/test-preflight-matrix.sh`

**Steps:**
1. Write failing test asserting both SKILL.md files require a pre-flight conflict matrix written to the ledger before the first dispatch. Expected error: test assertion failure, `expected SKILL.md to require a pre-flight conflict matrix`.
2. Run test, confirm it fails for the expected reason.
3. Edit both files: before the first dispatch, scan the plan and write a table to the ledger with one row per pair of tasks sharing a file or interface (the two tasks, what one produces against what the other consumes, the finding) and one row per task for self-consistency (its tests against its code, the files it creates against the files it later touches). State explicitly that "the scan is clean" without those rows is not a scan that was run. Every finding is ruled on before execution begins and the ruling is recorded in the ledger.
4. Confirm the table is written **above** `## Log` so the "Log is always last" structural rule still holds — state this in the prose.
5. Extend the test to assert the "above `## Log`" requirement appears.
6. Run tests, confirm all pass.
7. Commit: "feat(execute,parallel): blocking pre-flight conflict matrix (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-preflight-matrix.sh` exits 0
- [ ] `bash tests/ticket-scripts/test-scan-active-ledgers.sh` still exits 0 (Log-last rule intact)
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

# PART C — Measured Trims

Three findings from the 2026-08-21 token audit of this plugin. Measured facts the
audit established, so the executor does not re-derive them:

- Fixed per-session tax in a consumer project is ~1.9k tokens (session-start block
  ~969, twenty skill descriptions ~907). Not worth touching.
- One full cycle loads ~26k tokens of skill text. `gaspol-execute` is the single
  largest at ~7.7k and fires on nearly every job.
- Zero duplicated prose blocks across all twenty skills and every reference file.
  There is nothing to de-duplicate.

### Phase C1: Trim `gaspol-execute` SKILL.md

**Estimated time:** 14 minutes

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md`
- Test: `tests/ticket-scripts/test-execute-trim.sh`

**Steps:**
1. Write failing test asserting `skills/gaspol-execute/SKILL.md` is under 24000 bytes while still containing every gate name it owns (`TDD`, `anti-placeholder`, `plan-verifier`, `security-review`, `ledger`, `checkpoint`). Expected error: test assertion failure, `expected SKILL.md under 24000 bytes`.
2. Run test, confirm it fails for the expected reason.
3. Trim prose only: collapse restated rationale, fold repeated examples into one, and move any block longer than 20 lines that is consulted rather than read straight through into an existing reference file in the same directory. **Every gate, every Iron Law, every step number stays.** Cut words, never obligations.
4. Run tests, confirm all pass.
5. Commit: "refactor(execute): trim SKILL.md prose, gates unchanged (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-execute-trim.sh` exits 0
- [ ] Every gate name listed in step 1 still appears in the file
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` exits 0 (no routing regression)
- [ ] `bash tests/skill-triggering/run-all.sh` exits 0 (the skill still triggers)
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase C2: `gaspol-write-skill` references become on-demand

**Estimated time:** 10 minutes

**Files:**
- Modify: `skills/gaspol-write-skill/SKILL.md`
- Test: `tests/ticket-scripts/test-reference-loading.sh`

**Steps:**
1. Write failing test asserting `gaspol-write-skill/SKILL.md` marks its three heavy references as read-when-needed and states what question each one answers. Expected error: test assertion failure, `expected SKILL.md to mark references as on-demand`.
2. Run test, confirm it fails for the expected reason.
3. Edit `SKILL.md`: `testing-skills-with-subagents.md` (~4.4k tok), `anthropic-best-practices.md` (~4.1k tok), and `persuasion-principles.md` (~3.4k tok) total ~11.9k — the heaviest reference set in the plugin, for a meta-skill used rarely. Replace any instruction that reads them up front with a one-line pointer naming the question each answers, read only when that question is live.
4. Run tests, confirm all pass.
5. Commit: "refactor(write-skill): heavy references read on demand (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-reference-loading.sh` exits 0
- [ ] All three reference files still exist and are unmodified (`git diff --stat` shows no edit to them)
- [ ] `bash tests/ticket-scripts/test-prior-art-gate.sh` exits 0 (Step 0 gate intact)
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase C3: `gaspol-finish` — skip only what is provably inapplicable

**Estimated time:** 10 minutes

**Files:**
- Modify: `skills/gaspol-finish/SKILL.md`
- Test: `tests/ticket-scripts/test-finish-gates.sh` (extend)

**Scope boundary — read before editing.** `/security-review` stays
**unconditional on every branch**. Security defects hide in diffs that look
boring, and in a skills repository markdown *is* the executed surface, so
"docs only" does not mean "cannot introduce a vulnerability". `gaspol-verify`,
`gaspol-review`, `gaspol-sync-docs`, and `gaspol-learn` also stay. The single
change is a gate whose precondition can be **proven absent**, not judged safe.

**Steps:**
1. Write failing test asserting `gaspol-finish/SKILL.md` skips the `plan-verifier` step when the branch references no plan file, records the skip with its reason, and still runs `/security-review` unconditionally. Expected error: test assertion failure, `expected SKILL.md to define the no-plan skip`.
2. Run test, confirm it fails for the expected reason.
3. Edit `SKILL.md` step 2: when no plan file is referenced by the branch — no `**Plan:**` header in a ledger, no `docs/plans/*-plan.md` touched by the diff — there is nothing for `plan-verifier` to audit against. Record `plan-verifier: skipped — no plan referenced by this branch` in the ledger and continue. Any other case runs it, BLOCKING, unchanged. State plainly in the same paragraph that this is the only conditional gate and that `/security-review` is never conditional.
4. Extend `test-finish-gates.sh` to assert the unconditional `/security-review` requirement is still present — the trim must not weaken it.
5. Run tests, confirm all pass.
6. Commit: "refactor(finish): skip plan-verifier only when no plan exists (IDS-6)"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-finish-gates.sh` exits 0
- [ ] The file still requires `/security-review` on every branch (asserted by the test)
- [ ] The skip writes a reason to the ledger — never a silent omission
- [ ] No placeholder/TODO comments in new prose
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase D1: Docs sync + merge gate (final phase)

**Estimated time:** 10 minutes

**Files:**
- Modify: `CLAUDE.md`
- Modify: `hooks/session-start.sh` (only if routing text changed)
- Modify: `skills/using-gaspol/SKILL.md` (only if routing text changed)

**Steps:**
1. Write failing test asserting `CLAUDE.md` documents `scripts/task-brief`, the five-round fix loop, and the three Part C trims. Expected error: test assertion failure, `expected CLAUDE.md to document task-brief`. (Add to `tests/ticket-scripts/test-dispatch-contract.sh`.)
2. Run test, confirm it fails for the expected reason.
3. Update `CLAUDE.md`: add `task-brief` and `re-review-prompt.md` to the Architecture table, describe the fix loop and pre-flight matrix in the parallel-execution section, and record the three Part C trims with the audit figures that motivated them.
4. Run every ticket-script test.
5. Commit: "docs: CLAUDE.md documents Part A execution hygiene (IDS-6)"
6. **Merge gate:** run `gaspol-verify`, then STOP and ask the user before merging to `main`. A merge is never autonomous.

**Verification:**
- [ ] Every `bash tests/ticket-scripts/test-*.sh` exits 0
- [ ] `bash tests/skill-triggering/run-all.sh` exits 0
- [ ] `CLAUDE.md` Architecture table lists both new files
- [ ] Merge to `main` was explicitly approved by the user, not performed autonomously
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

---

## Deferred to a Later Ticket

Part B — the visual contract (`canvas.html`, the visual lock, `gaspol-visual-verify`,
the runner probe and geometry diff, `ui-mockup-fidelity` routing) — is **not** in this
ticket. Its design is complete in the spec and is carried forward unchanged. It was
deferred because Part A lowers the cost of building it: the dispatch and report
handoff this ticket installs is what makes the next ticket cheaper to run.

## Laziness Notes

- `review-package` is reused unchanged for scoped re-reviews; `FIX_BASE` is just a
  different `BASE`. No script edit.
- Part C cuts words, never obligations. Every gate, Iron Law, and step number in a
  trimmed file survives the trim, asserted by test.
- The audit's figures are inlined in Part C so the executor does not re-measure them.
- The 1.9k per-session fixed tax is deliberately left alone — measured, and too small
  to be worth touching. `ponytail:` revisit only if the skill count doubles.
