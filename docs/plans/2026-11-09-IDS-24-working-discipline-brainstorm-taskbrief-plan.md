> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-<TICKET>.md` (TICKET = this plan's ticket, from the header below; created by `gaspol-plan` at plan-write time — see Plan Document Header step 7). After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md` (that keeps concurrent plans from clobbering each other). **Backward compatibility:** older ledgers at `.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md` are STILL READ when a plan's header names them — only NEW plans write the `PROGRESS-<TICKET>.md` path.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat or read a linked PDF. Every file path, contract, config key, and convention it needs is written here **verbatim**, not merely referenced. If it lives only in the conversation, copy it in.

**Ticket:** IDS-24
**Ledger:** .gaspol/progress/PROGRESS-IDS-24.md
**Spec:** docs/plans/2026-11-09-IDS-24-working-discipline-brainstorm-taskbrief-spec.md
**Format:** waves-v1

**Verification commands:**
- detect-stack: no stack markers for this project — verification is plan-declared only

## Goal

Adopt two things into `gaspol-dev` 1.34.0. (1) Karpathy's Surgical Changes and Think Before Coding, as an always-on shared rule file, with a short summary in the session hook and a pointer from the implementer dispatch template. (2) From superpowers 7.0.2, a fence-aware `task-brief` and `verification-lint`: one fence rule used by both scripts, so a plan that quotes a template (a `---` line, a `### Phase` heading, a nested fence) is no longer cut short or mis-numbered. This closes the IDS-23 open debt "`task-brief` cuts a phase at the first `---` line even inside a fenced code block". Brainstorm question-reduction from superpowers 7.0.2 and Karpathy's Simplicity First are NOT adopted (owner decisions, spec "Prior-art verdict").

Test command for every phase, which runs each script with the shell named on its first line (`tests/ticket-scripts/test-stop-done-gate.sh` is a zsh script and fails under `bash`):

```bash
for t in tests/ticket-scripts/*.sh; do case "$(head -1 "$t")" in *zsh*) sh=zsh;; *) sh=bash;; esac; $sh "$t" || exit 1; done
```

Below, "the full suite" means that loop. At the start of this ticket there are 67 scripts: 66 pass, and `test-release-1-33-0.sh` fails only inside a worktree because it reads `../gaspol-one` relative to the repository root (Phase D fixes this). One script is added in Phase C and one is renamed in Phase D. Work happens in the worktree `/Users/alisadikin/Drive-D/claude-plugin/gaspol-dev/.claude/worktrees/ids-24-working-discipline`, branch `ids-24-working-discipline`, on top of `main` `2df6ec2` (v1.33.2).

## Architecture Context

- This repository is a Claude Code plugin made of markdown skills, bash scripts, one Python script and bash tests under `tests/ticket-scripts/`. `core.fileMode = false`, so a new executable needs `git update-index --chmod=+x <path>`.
- Hard budgets from IDS-23: `tests/ticket-scripts/test-skill-size.sh` fails any `skills/*/SKILL.md` of 20,000 bytes or more, and every `test-skill-trim-*.sh` pins an 18,000-byte ceiling. `gaspol-execute/SKILL.md` has 9 bytes of headroom and `gaspol-plan/SKILL.md` 21, so **no `SKILL.md` body is edited by this ticket**. `test-skill-references.sh` fails a `references/` file that no SKILL.md points at and a pointer to a missing file.
- `skills/gaspol-plan/scripts/verification-lint` (Python 3 stdlib) has `is_fence()` at line 111, a naive "any line starting with three backticks or three tildes flips a boolean" test, used by `read_header()` and `parse_phases()`.
- `skills/gaspol-parallel/scripts/task-brief` (bash + POSIX awk, BSD-safe) extracts the Nth `### Phase ` block: it counts every `/^### Phase /` line and ends the block at `/^### /` or `/^---[[:space:]]*$/`, ignoring fences; its `HEADER_BLOCK` awk (reads `**Verification commands:**`) uses the same naive fence toggle. Its stdout contract is the written path only; usage errors exit 2.
- `hooks/session-start.sh` prints one heredoc injected in every session (4,357 bytes before this ticket) and ends with KB-status echo lines.
- `skills/gaspol-execute/implementer-prompt.md` (14,145 bytes) has a `## Completeness Ladder (write the COMPLETE thing)` section at line 136 whose last paragraph is `**Boundary:** ...`, followed by `## Validation Ladder`.
- `CLAUDE.md` "Interactive Confirmation Rule" is NOT edited by this ticket (owner decision).

## Tech Stack

bash, POSIX awk (BSD awk on macOS: no gawk-only functions such as `match(s, re, arr)`), Python 3 stdlib, markdown. No new dependencies.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| Fence rule in `verification-lint` | the plan file text | `is_fence()` in `skills/gaspol-plan/scripts/verification-lint` | Yes, naive | Replace with a matching-fence tracker |
| Fence rule in `task-brief` | the plan file text | awk in `skills/gaspol-parallel/scripts/task-brief` | Yes, naive | Replace with the same rule, add refusal |
| Working-discipline rule text | Karpathy `CLAUDE.md` (MIT), read 2026-11-09 | `skills/_shared/working-discipline.md` | No | Create |
| Hook summary | the rule file | `hooks/session-start.sh` heredoc | Yes | Add a block and a pointer |
| Implementer pointer | the rule file | `skills/gaspol-execute/implementer-prompt.md` | Yes | Add a section |
| Caller behaviour for `task-brief` non-zero exit | the script's exit contract | `skills/gaspol-parallel/references/process-flow.md` | Yes | Add one paragraph |
| Release metadata | version 1.34.0 | `.claude-plugin/plugin.json`, `plugin.json`, `CHANGELOG.md`, `README.md`, `CLAUDE.md` footer, `gaspol-one` README + `marketplace.json` | Yes, 1.33.2 | Bump |

### Phase A: One fence rule in verification-lint

**Deps:** none
**Complexity:** medium — one Python script and its test change, but the new fence rule is shared with Phase B and must be exact
**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-plan/scripts/verification-lint`
- Modify: `tests/ticket-scripts/test-verification-lint.sh`

**Steps:**
1. Write failing test for a plan whose phase quotes a template inside a four-backtick fence that itself contains a three-backtick fence. Expected error: `FAIL: nested fence` (today the inner three-backtick line closes the outer fence, so the quoted `### Phase X` heading inside it is parsed as a real phase and the lint reports a different phase count or verdict than the fixture's expected `verification-lint: OK — 1 phase(s)`). Add the fixture to `tests/ticket-scripts/test-verification-lint.sh` in the file's own style (fixture plans written into a `mktemp -d` directory, one assertion helper, stdout must be exactly one `verification-lint: <verdict>` line).
2. Add three more failing cases to the same test: (a) a tilde fence `~~~` closed by a backtick run does NOT close (stays open); (b) a closing line with trailing text (` ```ts`) does NOT close a fence; (c) a fence indented by up to three spaces is a fence and four spaces is not. Run `bash tests/ticket-scripts/test-verification-lint.sh` and confirm each new case fails for the stated reason and every old case still passes.
3. Implement the shared rule in `verification-lint`. Replace `is_fence(line)` with a small tracker used by BOTH `read_header()` and `parse_phases()`. Rule, verbatim: a fence **opens** on a line that, after at most three leading spaces, starts with a run of three or more backticks, or a run of three or more tildes; remember the character and the run length. A fence **closes** on a later line that, after at most three leading spaces, starts with the same character in a run at least as long as the opener's, followed by nothing except spaces, tabs or CR. Any other line inside a fence, including a shorter run or the other character, is plain text. An unclosed fence stays open to the end of the file. Keep `BLANKS = " \t\r"`. Keep the docstring accurate: replace the line `Fenced code blocks are skipped, so a template quoted in a fence is not a phase.` with the exact rule above in two lines, and say it is the same rule `task-brief` uses.
4. Keep the existing behaviour of `read_header()` on a fence: a fence line that appears after the header was found still ends the block (`break`); a fence line before the header toggles state. The tracker must report "is this line a fence delimiter, and is the state now inside a fence" without changing that control flow.
5. Run `bash tests/ticket-scripts/test-verification-lint.sh` until it passes, then run the lint's own `--self-test` if it has one (it does not today: do not add one), then the full suite. Fix any red test by reading what it asserts.
6. Commit: `fix(gaspol-dev): verification-lint matches fence length and character, nested fences (IDS-24)`.

**Verification:**
- [ ] a plan quoting a template in a four-backtick fence that contains a three-backtick fence yields `verification-lint: OK — 1 phase(s)` and does not count the quoted phase
- [ ] a tilde-opened fence is not closed by a backtick run, and a closing line with trailing text does not close a fence
- [ ] every pre-existing `test-verification-lint.sh` case still passes unchanged, including the malformed-heading and NBSP cases
- [ ] stdout is still exactly one `verification-lint: ` line on every exit path

### Phase B: Fence-aware task-brief

**Deps:** A
**Complexity:** complex — new refusal exit code that other skills' callers consume, a BSD-awk fence parser, and a rule that must agree with the lint from Phase A
**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-parallel/scripts/task-brief`
- Modify: `tests/ticket-scripts/test-task-brief.sh`
- Modify: `skills/gaspol-parallel/references/process-flow.md`

**Steps:**
1. Write failing test for `task-brief` on a plan whose phase quotes a `---` line and a `### Phase` heading inside a fenced code block. Expected error: `FAIL: brief stops at a --- inside a fence` (today the brief for that phase ends at the quoted `---`, and the quoted `### Phase Z` is counted so phase 2 resolves to the wrong block). Add fixtures to `tests/ticket-scripts/test-task-brief.sh` in the file's own style. Assert on the written brief's contents and on stdout being exactly the written path.
2. Add the remaining failing cases: (a) nested fence (four backticks around three) with `---` and `### ` inside; (b) an unclosed fence that opens inside the requested phase and hides a later `### Phase` heading: expect **exit 1**, stdout empty, stderr naming the line number the fence opened on, and no brief file written; (c) an unclosed fence that opens in an EARLIER phase and hides a `### Phase` heading, while a later phase is requested: expect exit 1 with the same message (not the misleading `no phase N` exit 2); (d) a stray unclosed fence at the very end of the plan that hides no `### Phase` heading: brief is written, exit 0, a `task-brief: warning:` line on stderr; (e) a plan with no fences at all: the brief is byte-identical to what the pre-change script wrote (store the expected bytes from the committed script before editing, for example by generating the brief with `git show HEAD:skills/gaspol-parallel/scripts/task-brief` into a temp file and comparing with `cmp`); (f) usage errors (missing args, non-integer N, missing file) still exit 2.
3. Run the test and confirm every new case fails for its stated reason while the old cases pass.
4. Implement in `task-brief`. Use the SAME fence rule as Phase A, written in POSIX awk: opener = line matching `^ {0,3}(`{3,}|~{3,})`; remember the opener character and run length; closer = a later line, after at most three leading spaces, starting with the same character in a run of length >= the opener's and nothing but spaces, tabs or CR after the run. Use `substr`, `length`, `match` (BSD-safe forms, no capture arrays). Apply the rule in the phase-extraction awk and in the `HEADER_BLOCK` awk. Strip a trailing CR before testing a line, as the header awk already does.
5. In the phase-extraction awk: a line inside a fence never counts as a `### Phase` heading and never ends the block; `/^### /` and `/^---[[:space:]]*$/` only end the block when outside a fence. Record, while scanning, the line number where each fence opened and whether the fence hid a `### Phase` line or a `### ` / `---` line while the block was being captured. At end of file, if a fence is still open and it hid a `### Phase` heading (anywhere in the file) or hid the end of the captured block, print to stderr `task-brief: the code fence opened at line <L> of <plan basename> never closes, so a later phase heading cannot be seen; close that fence in the plan and rerun` and exit 1 without writing any brief. If the fence hid nothing relevant, print `task-brief: warning: the code fence opened at line <L> never closes; it hides no phase heading, so this brief is complete` to stderr and continue. The awk cannot exit the shell script directly: have it print a marker on a second channel (for example a final line `__FENCE_REFUSE__ <L>` that the shell strips and tests) and make the shell `exit 1` before creating `$DIR` or `$OUT`. The plan's basename is the only plan-derived text printed, and the line number is an integer produced by awk.
6. Keep every existing contract: stdout is the written path and nothing else; exit 2 for usage errors including `no phase N` when N exceeds the number of phase headings OUTSIDE fences and no refusal applies; the `## Verification commands (from the plan header)` section is appended exactly as before; a plan with no fences produces a byte-identical brief.
7. Update the script's header comment: replace the "Phase boundaries" paragraph with the fence-aware rule, list the exit codes (0 written, 1 refused because an unclosed fence hides a phase heading, 2 usage or no such phase), and state the caller rule: any non-zero exit means stop, do not dispatch, show stderr.
8. Edit `skills/gaspol-parallel/references/process-flow.md`: directly after the paragraph that ends `The brief is the single source of the implementer's requirements.` (around line 96-98) add one paragraph: `If task-brief exits non-zero, do not dispatch. Stop, show its stderr, and fix the plan (an unclosed code fence is the usual cause) or ask the owner. Never dispatch with a brief you did not see written.` Do NOT edit `skills/gaspol-parallel/SKILL.md`.
9. Run `bash tests/ticket-scripts/test-task-brief.sh` until green, then `bash tests/ticket-scripts/test-skill-trim-parallel.sh`, `bash tests/ticket-scripts/test-skill-size.sh` and `bash tests/ticket-scripts/test-skill-references.sh` (the reference file gained a paragraph, not a file, but confirm), then the full suite.
10. Add one cross-script test in `tests/ticket-scripts/test-task-brief.sh`: run `verification-lint` and `task-brief` on the SAME fixture plan (a quoted template with a `---`, a `### Phase`, and a nested fence), and assert the lint reports N phases and `task-brief` resolves exactly N phase numbers (phase N+1 exits 2), so the two scripts agree on which lines are fenced.
11. Commit: `fix(gaspol-dev): task-brief is fence-aware and refuses an unclosed fence that hides a phase (IDS-24)`.

**Verification:**
- [ ] `task-brief` on a plan whose phase quotes `---` inside a fence writes the whole phase, ending only at the next real heading or rule
- [ ] an unclosed fence that hides a later `### Phase` heading exits 1 with the fence's opening line number on stderr, writes no brief, and also fires when an earlier phase is requested
- [ ] a stray trailing fence that hides no phase heading writes the brief, exits 0 and warns on stderr
- [ ] a plan with no fences produces a brief byte-identical (`cmp`) to the pre-change script's output
- [ ] `task-brief` and `verification-lint` agree on the number of phases in a nested-fence fixture
- [ ] `skills/gaspol-parallel/references/process-flow.md` states that a non-zero exit means stop and do not dispatch, and `skills/gaspol-parallel/SKILL.md` is byte-identical to `main`

### Phase C: Working discipline rule, hook summary and implementer pointer

**Deps:** none
**Complexity:** medium — one new shared rule file plus three small edits to files read in every session, with a byte budget and a test that pins the wiring
**Estimated time:** 20 minutes

**Files:**
- Create: `skills/_shared/working-discipline.md`
- Create: `tests/ticket-scripts/test-working-discipline.sh`
- Modify: `hooks/session-start.sh`
- Modify: `skills/gaspol-execute/implementer-prompt.md`

**Steps:**
1. Write failing test for the wiring in `tests/ticket-scripts/test-working-discipline.sh` (bash, `set -uo pipefail`, `REPO_ROOT` from `BASH_SOURCE`, `fail`/`pass` helpers in the style of `tests/ticket-scripts/test-completeness-ladder.sh`). Expected error: `FAIL: skills/_shared/working-discipline.md missing`. It asserts: (a) the file exists; (b) it contains the headings `Surgical changes` and `Think before coding`, the rule that only imports, variables and functions **your own change** orphaned are removed, the sentence that unrelated dead code is reported and not deleted, the instruction to stop and ask through `AskUserQuestion`, and a boundary sentence naming `skills/_shared/completeness-ladder.md` and saying Surgical limits code OUTSIDE the task while the Ladder demands depth INSIDE it; (c) it does NOT contain the words `Simplicity First`; (d) `hooks/session-start.sh` contains `skills/_shared/working-discipline.md`; (e) `skills/gaspol-execute/implementer-prompt.md` contains `skills/_shared/working-discipline.md`; (f) the byte size of `hooks/session-start.sh` is at most 4,357 + 450 bytes (record the pre-change size 4,357 in a comment); (g) `skills/_shared/completeness-ladder.md` is byte-identical to `git show HEAD:skills/_shared/completeness-ladder.md`; (h) a positive control: the same assertion helper run on a temp file lacking the strings must fail; (i) `bash -n hooks/session-start.sh` passes and running the hook prints the new block exactly once.
2. Run the test and confirm it fails with that error, not a syntax error.
3. Create `skills/_shared/working-discipline.md`, plain markdown, no frontmatter, under 2,500 bytes, in the voice of `completeness-ladder.md`. Contents, in this order: a one-paragraph purpose ("two rules for how to behave around code that is not yours to change, and around a request that is not yet clear; adapted from Andrej Karpathy's observations on LLM coding pitfalls via github.com/multica-ai/andrej-karpathy-skills, MIT"); `## Surgical changes` with the rules: every changed line traces to the request; do not tidy adjacent code, comments or formatting; match the existing style even if you would do it differently; remove only the imports, variables and functions that YOUR change left unused; unrelated dead code is reported in the hand-off, never deleted; `## Think before coding` with the rules: state your assumptions before writing code; when a request has two readings name both instead of picking one silently; say so when a simpler way exists; when confused, stop, name what is unclear and ask through `AskUserQuestion`; `## Boundary with the Completeness Ladder` with the exact idea that Surgical changes limits code OUTSIDE the task, the ladder in `skills/_shared/completeness-ladder.md` demands depth INSIDE it, and the two never conflict; and a final line that trivial changes (a typo, an obvious one-liner) need judgement, not the full ceremony.
4. Edit `hooks/session-start.sh`: inside the heredoc, directly after the `Full text: skills/_shared/completeness-ladder.md.` line and before the closing `═══` line, add a block of at most 6 lines titled `WORKING DISCIPLINE (always-on):` carrying the two rules in one sentence each (every changed line traces to the request, remove only what your own change orphaned, report other dead code; state assumptions, name two readings, stop and ask when confused) and the pointer `Full text: skills/_shared/working-discipline.md.`. Keep the heredoc quoted (`<<'EOF'`) and do not touch the KB-status lines.
5. Edit `skills/gaspol-execute/implementer-prompt.md`: insert a new section `## Working Discipline (do not touch what you were not asked to)` after the Completeness Ladder section's `**Boundary:** ...` paragraph and before `## Validation Ladder`. Body: two sentences summarising Surgical changes and Think before coding, and `Full text: skills/_shared/working-discipline.md.` Do not edit any other part of the template.
6. Run `bash tests/ticket-scripts/test-working-discipline.sh` until green. Then run `bash tests/ticket-scripts/test-completeness-ladder.sh`, `bash tests/ticket-scripts/test-skill-size.sh`, `bash tests/ticket-scripts/test-skill-references.sh`, `bash tests/ticket-scripts/test-hooks-executable.sh`, `skills/gaspol-verify/scripts/model-gate` (exit 0), and the full suite.
7. Commit: `feat(gaspol-dev): working-discipline rule file, hook summary and implementer pointer (IDS-24)`.

**Verification:**
- [ ] `skills/_shared/working-discipline.md` exists, carries both rules and the boundary sentence, and does not contain `Simplicity First`
- [ ] running `bash hooks/session-start.sh` prints the `WORKING DISCIPLINE` block exactly once, and the file stays within 4,357 + 450 bytes
- [ ] `skills/gaspol-execute/implementer-prompt.md` names the rule file and every other line of it is unchanged (`git diff` shows additions only)
- [ ] `skills/_shared/completeness-ladder.md`, `CLAUDE.md` and every `skills/*/SKILL.md` are byte-identical to the previous commit in this phase's diff
- [ ] `skills/gaspol-verify/scripts/model-gate` still exits 0

### Phase D: Release 1.34.0, docs and metadata

**Deps:** A, B, C
**Complexity:** medium — several documentation and metadata files across two repositories, with a version pin test to replace
**Estimated time:** 25 minutes

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Rename and modify: `tests/ticket-scripts/test-release-1-33-0.sh` to `tests/ticket-scripts/test-release-1-34-0.sh`
- Modify (separate repository, uncommitted): `/Users/alisadikin/Drive-D/claude-plugin/gaspol-one/README.md`
- Modify (separate repository, uncommitted): `/Users/alisadikin/Drive-D/claude-plugin/gaspol-one/.claude-plugin/marketplace.json`

**Steps:**
1. Write failing test for the release: `git mv tests/ticket-scripts/test-release-1-33-0.sh tests/ticket-scripts/test-release-1-34-0.sh`, change `V="1.33.2"` to `V="1.34.0"`, update its header comment (the version, and that it supersedes `test-release-1-33-0.sh`), keep every other assertion (the `gaspol-dbpatch` registration and generic-ness ones included), make the `gaspol-one` lookup worktree-safe (replace each `../gaspol-one` with a `GASPOL_ONE` variable resolved as `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/../gaspol-one`, which is the sibling of the MAIN checkout from any worktree; if that directory does not exist, skip the `gaspol-one` assertions with a printed `SKIP:` line and do not count it as a pass), and add: `CLAUDE.md` mentions `IDS-24`, `skills/_shared/working-discipline.md` and `fence`; `CHANGELOG.md` has a `1.34.0` entry. Expected error: `FAIL: .claude-plugin/plugin.json version is 1.33.2, expected 1.34.0`.
2. Run it and confirm it fails for that reason.
3. Set `version` to `1.34.0` in `.claude-plugin/plugin.json` and in root `plugin.json` (a second copy of the version; the release test pins both).
4. Add a `## 1.34.0` entry at the top of `CHANGELOG.md` in the file's existing style: working discipline (Surgical changes, Think before coding), fence-aware `task-brief` and `verification-lint`, closes the IDS-23 `task-brief` debt, and what was not adopted.
5. Update `README.md`: the version badge to `1.34.0`, add a changelog table row `| **1.34.0** (current) | ... |` and drop `(current)` from the previous row; if a tests-count badge exists, set it to the new count of `tests/ticket-scripts/*.sh`.
6. Update `CLAUDE.md`: footer `**Version:** 1.34.0` and `Last Updated`; keep `Last ticket: IDS-24`; Architecture rows for `skills/_shared/working-discipline.md`, `tests/ticket-scripts/test-working-discipline.sh`, and an update to the `skills/gaspol-parallel/scripts/task-brief` row and the `skills/gaspol-plan/scripts/verification-lint` row (fence rule, refusal exit 1); update the `tests/ticket-scripts/` row's script count; add a section `### Working Discipline + Fence-Aware Briefs (NEW in v1.34, IDS-24)` stating the defect with its evidence (the `grep` that found no Surgical-Changes equivalent, and the IDS-23 `task-brief` truncation), what changed, what each part gives up (Part A is model judgement and grows the hook by about 450 bytes in every session; a plan that passed `verification-lint` only because a stray fence flipped its state may now be judged differently; brainstorm keeps asking every clarifying question) and what is NOT adopted or closed (Simplicity First, with the reason that it contradicts the Completeness Ladder; superpowers 7.0.2 brainstorming question-reduction, by owner decision to keep the mandatory `AskUserQuestion` rule; the Windows and no-bash hook fixes and the Hermes, Devin, OpenCode V2 platform support; no `tests/pressure` measurement of whether agents obey Part A). Also tighten the IDS-23 section's open-debt bullet about `task-brief` to say it was closed by IDS-24.
7. Prepare, but do NOT add, commit or push, the matching changes in `/Users/alisadikin/Drive-D/claude-plugin/gaspol-one`: the `gaspol-dev` row of its `README.md` version table and the `gaspol-dev` entry's `version` in `.claude-plugin/marketplace.json`, both set to `1.34.0`. First run `git -C /Users/alisadikin/Drive-D/claude-plugin/gaspol-one status --short` and `git -C /Users/alisadikin/Drive-D/claude-plugin/gaspol-one log -1 --format=%H` and record both; the status must be clean and the SHA must be unchanged at the end. Record in the ledger `## Utang terbuka` that committing and pushing that repository is the owner's call.
8. Run `bash tests/ticket-scripts/test-release-1-34-0.sh` until green, then `skills/gaspol-verify/scripts/model-gate` (exit 0), the full suite, and `skills/gaspol-verify/scripts/blast-radius-diff` against this plan (a WARN is acceptable, record it).
9. Commit: `chore(gaspol-dev): release 1.34.0 — working discipline, fence-aware task-brief and verification-lint (IDS-24)`.

**Verification:**
- [ ] `.claude-plugin/plugin.json`, root `plugin.json`, the `CLAUDE.md` footer, the README badge, the `CHANGELOG.md` top entry and the `gaspol-one` README and `marketplace.json` all read `1.34.0`
- [ ] `git -C /Users/alisadikin/Drive-D/claude-plugin/gaspol-one log -1 --format=%H` is unchanged from before this phase, and its only changes are two uncommitted modified files
- [ ] `grep -c "Simplicity First" skills/_shared/working-discipline.md` prints 0 and `CLAUDE.md` records Simplicity First as not adopted with its reason
- [ ] `tests/ticket-scripts/test-release-1-33-0.sh` no longer exists and `test-release-1-34-0.sh` passes
- [ ] the full suite exits 0 (inside the worktree, with `test-release-1-34-0.sh` finding `gaspol-one`) and `skills/gaspol-verify/scripts/model-gate` exits 0

## Out of scope

Brainstorm question-reduction (superpowers 7.0.2), Karpathy's Simplicity First, hook fixes for Windows or a missing bash, other-harness support (Hermes, Devin, OpenCode V2, Grok), the remaining IDS-23 open debts (`verification-lint` Minor 3 to 6, `gaspol-plan` Phase D Minors, the REAL/PLACEHOLDER rows living only in a reference), and any measurement of agent behaviour with `tests/pressure` or `tests/skill-triggering`.
