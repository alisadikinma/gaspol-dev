> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-23.md` (created by `gaspol-plan` at plan-write time). After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end.** Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process. Every file path, contract, config key, and convention it needs is written here **verbatim**. The worktree is `.claude/worktrees/ids-23-skill-size-builder-check` on branch `ids-23-skill-size-builder-check`; run every command from its root.

**Ticket:** IDS-23
**Ledger:** .gaspol/progress/PROGRESS-IDS-23.md
**Spec:** docs/plans/2026-10-24-IDS-23-skill-size-builder-check-plan-verification-spec.md
**Format:** waves-v1

## Goal

Three changes to the gaspol-dev plugin itself, one ticket:

- **A. Skill size ceiling.** After `/compact`, Claude Code re-attaches each skill cut off at 20,000 characters. Six `SKILL.md` files exceed 20,000 bytes today (`gaspol-verify` 34,416; `gaspol-plan` 34,218; `gaspol-parallel` 30,057; `gaspol-execute` 29,286; `gaspol-brainstorm` 26,337; `gaspol-finish` 21,191), so gates at the bottom of those files can vanish in a long session. Move detail into `references/`, keep every gate in the body, target under 18,000 bytes each, and add tests that fail when any `SKILL.md` reaches 20,000 bytes.
- **B. Builder check.** Replace the author's own "Spec self-review" in `gaspol-brainstorm` Phase 6 with one fresh Opus subagent that reads the spec as the person who must build it and reports only the questions that would force a guess, plus anything that looks unnecessary. One round, no loop.
- **C. Phase-specific verification.** Today every phase's `**Verification:**` block repeats four generic lines. Write the `detect-stack` commands once in a plan-header block, keep per-phase blocks to checks specific to that phase, make `task-brief` carry the header block to implementers, and add a script that flags a phase with only generic lines.

Release as 1.32.0. IDS-22 (1.31.0) is already merged into `main`; this branch sits on top of it.

## Architecture Context

From `CLAUDE.md` (read in full before writing this plan):

- Skills live in `skills/<name>/SKILL.md`; a skill may carry `references/*.md` read at the step that needs them. `tests/ticket-scripts/*.sh` are deterministic bash tests; run all with `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. This repository has no `package.json`/`composer.json`, so `detect-stack` prints nothing for it (verified: exit 0, zero lines).
- House conventions for every new script: stdout carries exactly ONE `<name>: <verdict>` line on every path, detail on stderr; exit states 0 satisfied / 1 BLOCKING / 3 UNKNOWN (STOP and ask) / 4 not applicable (never counted as a pass). Scripts invoked from a SKILL.md go through `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/..."`, never a relative path. `tests/ticket-scripts/test-kb-no-hardcoded-path.sh` gates this (its `ANCHORED_SCRIPTS` regex around line 77 and its per-script loop around line 99). `tests/ticket-scripts/test-scripts-executable.sh` has a hardcoded `DIRECT=(` list (line 25) that must name every directly invoked script. This repo sets `core.fileMode = false`, so `chmod +x` never reaches the index: use `git update-index --chmod=+x <path>`.
- Model rule: Opus judges, Sonnet works. `skills/gaspol-verify/scripts/model-gate` reads `model-tier: judge|exec` (not `opus`) from the file that holds the `model:` line, and falls back to path keywords (`reviewer|verifier|simplifier|refuter` = judge, `implementer` = exec). `gaspol-brainstorm` is a judging skill, so it carries `model-tier: judge`. `model-gate` itself is NOT changed.
- `skills/gaspol-execute/scripts/detect-stack`, `skills/gaspol-plan/scripts/plan-waves` (Python, stdlib, four exit states, shells out to `dag-lanes`), `skills/gaspol-parallel/scripts/task-brief` (extracts ONE `### Phase` block into `.gaspol/tasks/<TICKET>/task-<N>-brief.md`, prints the path) already exist.
- Existing size guard to update: `tests/ticket-scripts/test-execute-trim.sh` line 23 sets `LIMIT=29400`.
- Tests that read each skill's `SKILL.md` (from `grep -l 'gaspol-X/SKILL.md' tests/ticket-scripts/*.sh`): verify — design-contract, finish-gates, geometry-diff, live-app-check, naming-convention, plan-verifier-spec, regression-gate, skill-delegation, wig-lane. plan — completeness-ladder, finish-gates, kb-no-hardcoded-path, ledger-template, logic-design-artifact, naming-convention, plan-waves-wiring, spec-pointer. parallel — dispatch-contract, finish-fix-loop, fix-loop, model-gate, model-rule, naming-convention, preflight-matrix. execute — completeness-ladder, execute-trim, logic-design-artifact, naming-convention, preflight-matrix, single-owner-gates, skill-delegation, verification-loop. brainstorm — batch-gate, logic-design-artifact, naming-convention, prior-art-gate, research-tools, skill-delegation, vault-read, wig-lane. finish — finish-fix-loop, finish-gates, fix-loop, naming-convention, regression-gate, single-owner-gates, skill-delegation.

## Tech Stack

Bash tests, Python 3 stdlib for the new script (same as `plan-waves`), markdown skills. No new dependencies.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| Size ceiling | `wc -c` of each `skills/*/SKILL.md` on disk | `tests/ticket-scripts/test-skill-size.sh` | No | Create |
| Reference resolution | files under `skills/<name>/references/` vs pointers in that skill's `SKILL.md` | `tests/ticket-scripts/test-skill-references.sh` | No | Create |
| Per-skill gate preservation | the real gate sentences in each trimmed `SKILL.md` | one `test-skill-trim-<skill>.sh` per skill (pattern: `test-execute-trim.sh`) | Pattern yes, files no | Create 6 |
| Builder check dispatch | the written spec file; Agent tool with `model: "opus"` | `skills/gaspol-brainstorm/references/builder-check-prompt.md` | No | Create |
| Builder check model tier | `model-tier:` line read by `model-gate` | `skills/gaspol-verify/scripts/model-gate` | Yes | Use existing, unchanged |
| Header verification commands | `detect-stack` output (or its UNKNOWN / no-markers lines) | `**Verification commands:**` block in the plan header | No | Create (template + parser) |
| Phase-specific verification lint | the plan file's phase blocks | `skills/gaspol-plan/scripts/verification-lint` | No | Create |
| Brief carries header block | the plan header | `skills/gaspol-parallel/scripts/task-brief` | Yes | Modify |
| Ledger template | `gaspol-plan/SKILL.md` template block, extracted by `test-ledger-template.sh` | existing test | Yes | Modify |

## Execution Waves

Computed by `plan-waves` (exit 0, 10 phases, 9 waves). Phases C to J are serialized on purpose: each one may repoint tests that other trims also read, so concurrent lanes would edit the same test files.

```text
wave 1 lane 1: A
wave 1 lane 2: B
wave 2 lane 1: C
wave 3 lane 1: D
wave 4 lane 1: E
wave 5 lane 1: F
wave 6 lane 1: G
wave 7 lane 1: H
wave 8 lane 1: I
wave 9 lane 1: J
phase A complexity=medium model=sonnet effort=medium review=none
phase B complexity=complex model=sonnet effort=high review=opus
phase C complexity=complex model=sonnet effort=high review=opus
phase D complexity=complex model=sonnet effort=high review=opus
phase E complexity=medium model=sonnet effort=medium review=none
phase F complexity=medium model=sonnet effort=medium review=none
phase G complexity=medium model=sonnet effort=medium review=none
phase H complexity=medium model=sonnet effort=medium review=none
phase I complexity=medium model=sonnet effort=medium review=none
phase J complexity=medium model=sonnet effort=medium review=none
```

### Phase A: Builder check replaces Phase 6 spec self-review

**Deps:** none
**Complexity:** medium — one skill edited, one prompt file and one test created, pattern borrowed from superpowers; the one trap is that `model-gate` accepts `model-tier: judge`, not `opus`.
**Estimated time:** 25 minutes

**Files:**
- Create: `skills/gaspol-brainstorm/references/builder-check-prompt.md`
- Modify: `skills/gaspol-brainstorm/SKILL.md`
- Create: `tests/ticket-scripts/test-builder-check.sh`

**Steps:**
1. Write failing test for the builder check wiring in `tests/ticket-scripts/test-builder-check.sh`. Expected error: `FAIL: skills/gaspol-brainstorm/references/builder-check-prompt.md missing`.
2. Run `bash tests/ticket-scripts/test-builder-check.sh` and confirm it fails with that exact error, not a syntax error. The test asserts: (a) the prompt file exists and contains the lines `model-tier: judge`, `nothing important left` and the words `looks unnecessary`; (b) `skills/gaspol-brainstorm/SKILL.md` Phase 6 names `builder-check-prompt.md`, `model: "opus"`, `model-tier: judge`, `nothing important left` and `one round`; (c) the phrase `Spec self-review` no longer appears in that `SKILL.md`; (d) a positive control: the assertion helper run on a temp file that lacks the strings must fail; (e) `skills/gaspol-verify/scripts/model-gate` exits 0 against this repository.
3. Find every other reader of the old text: search `skills/`, `tests/` and `docs/` (not `docs/plans/`) for `self-review`. Record each hit in the ledger under `## Keputusan saat jalan`. A test that asserts the old sentence is repointed to the new wording, never deleted.
4. Create `skills/gaspol-brainstorm/references/builder-check-prompt.md` with exactly this content (it is a plain markdown file, no frontmatter):

```text
model-tier: judge

# Builder Check Prompt

Dispatch ONE fresh `general-purpose` subagent with `model: "opus"` once the spec file is written. Fill [DOMAIN] (the target project's stack, e.g. "Laravel and Vue engineer") and [DOCUMENT_PATH]. Give it nothing else: no conversation context.

---
You are a talented [DOMAIN]. You've been handed a design document and asked to put together a plan to build what it describes. You will not be able to talk to the person who wrote it.

Read [DOCUMENT_PATH].

Report only the questions you'd still need answered before you could plan this well: places where you'd have to guess and a wrong guess would matter. For each, give the question and why the answer changes the plan. Rank them by importance.

Also list, one line each with a reason, any part of the document that looks unnecessary for its stated goal.

Skip anything the document explicitly leaves to the builder, and anything you could reasonably decide yourself. Skip nitpicks about wording.

If nothing important is left and nothing looks unnecessary, say exactly: nothing important left
---
```

5. In `skills/gaspol-brainstorm/SKILL.md` Phase 6, replace the bullet that begins `**Spec self-review (before handing off):**` with this flow, in the file's own voice: after the spec file is written, dispatch the builder check (`general-purpose`, `model: "opus"` written at the call site, prompt from `references/builder-check-prompt.md`, only the spec path and domain given); add the line `model-tier: judge` next to the dispatch; the reply is ranked questions plus unnecessary-part lines, or exactly `nothing important left`; answer what the spec or CLAUDE.md already answers and fix the spec inline, decide minor points yourself and mark them as your own decisions, bring questions that change what gets built to the owner in ONE `AskUserQuestion`; **one round** only (no re-dispatch loop, per `skills/_shared/fix-loop.md`); runs on the architectural path only because only that path writes a spec; then the owner reads the written spec as before. State the cost: model judgement, not a guarantee. Keep the next bullet ("User reviews the written spec") unchanged.
6. Run `bash tests/ticket-scripts/test-builder-check.sh` until it passes, then run `skills/gaspol-verify/scripts/model-gate` and confirm exit 0. If it exits 3, the `model-tier: judge` line is in the wrong file: it must be in the file that holds the `model: "opus"` line.
7. Run the full suite: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. Fix any red test by repointing it to the new wording; record each in the ledger.
8. Commit: `feat(gaspol-dev): builder check replaces spec self-review in brainstorm Phase 6 (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `skills/gaspol-verify/scripts/model-gate` exits 0 and prints a `model-gate: OK` style verdict
- [ ] `grep -c "Spec self-review" skills/gaspol-brainstorm/SKILL.md` prints 0
- [ ] `skills/gaspol-brainstorm/references/builder-check-prompt.md` exists and contains `model-tier: judge` and `nothing important left`
- [ ] No placeholder/TODO comments in new code

### Phase B: Phase-specific verification blocks and the verification lint

**Deps:** none
**Complexity:** complex — changes the plan template every future plan follows, a new script with four exit states, an interface other code consumes (`task-brief`, the ledger copy), and four existing tests to repoint.
**Estimated time:** 60 minutes

**Files:**
- Create: `skills/gaspol-plan/scripts/verification-lint`
- Create: `tests/ticket-scripts/test-verification-lint.sh`
- Modify: `skills/gaspol-plan/SKILL.md`
- Modify: `skills/gaspol-parallel/scripts/task-brief`
- Modify: `tests/ticket-scripts/test-task-brief.sh`
- Modify: `tests/ticket-scripts/test-ledger-template.sh`
- Modify: `tests/ticket-scripts/test-scripts-executable.sh`
- Modify: `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`

**Steps:**
1. Write failing test for the four exit states of `verification-lint` in `tests/ticket-scripts/test-verification-lint.sh`, using fixture plans written into a `mktemp -d` directory. Expected error: `verification-lint: No such file or directory`.
2. Run the test and confirm it fails with that error. The fixtures: (exit 0) a plan with a `**Verification commands:**` header block where every phase has at least one phase-specific Verification line; (exit 1) the same plan where one phase's block has only generic lines, and a phase with no Verification lines at all; (exit 3) an unreadable path, an empty file, and a plan with the header block but zero `### Phase` headings; (exit 4) a legacy plan with no `**Verification commands:**` header, which must never be reported as a pass. Also assert stdout is exactly ONE line `verification-lint: <verdict>` on every path.
3. Implement `skills/gaspol-plan/scripts/verification-lint` (Python 3 stdlib, `#!/usr/bin/env python3`, same style as `skills/gaspol-plan/scripts/plan-waves`: plan text is only parsed and compared, never executed or interpolated; a phase id is printed only after matching `[A-Za-z0-9]+`). Rules, verbatim: the header block starts at the line `**Verification commands:**` and consists of the following consecutive lines starting with `- ` (ends at the first blank line or non-`- ` line). A phase is a block that starts at `### Phase <id>` and ends at the next `### ` heading, a `---` rule or end of file (fenced code blocks are not parsed as phases). Inside a phase, the Verification lines are the `- [ ]` / `- [x]` items after the `**Verification:**` line. A Verification line is GENERIC when, after stripping backticks, (i) it contains any command string listed in the header block, or (ii) its text after the checkbox begins with `static:`, `lint:`, `unit:`, `build:` or `detect-stack:`, or (iii) it contains `No placeholder` or `TODO comments`, or (iv) it contains `real data from [` (an unfilled bracketed source). Any other line is SPECIFIC. A phase with zero Verification lines, or only GENERIC ones, is a violation: exit 1, verdict `verification-lint: BLOCKING — phase <id> has no phase-specific verification`. Exit 0: `verification-lint: OK — <n> phase(s)`. Exit 3: `verification-lint: UNKNOWN — <why>`. Exit 4: `verification-lint: N/A — no Verification commands header; legacy plan, never a pass`.
4. Wire the script in: `git update-index --chmod=+x skills/gaspol-plan/scripts/verification-lint` (this repo has `core.fileMode = false`, so `chmod` alone never reaches the index); add `skills/gaspol-plan/scripts/verification-lint` to the `DIRECT=(` list in `tests/ticket-scripts/test-scripts-executable.sh`; add it to the `ANCHORED_SCRIPTS` regex and to the per-script loop with its positive control in `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`, so a relative invocation in any SKILL.md is caught.
5. Run `bash tests/ticket-scripts/test-verification-lint.sh`, `bash tests/ticket-scripts/test-scripts-executable.sh` and `bash tests/ticket-scripts/test-kb-no-hardcoded-path.sh`; confirm green. Run the lint's own `--self-test` if you gave it one.
6. Write failing test for the brief carrying the header block: extend `tests/ticket-scripts/test-task-brief.sh` with two cases. A plan whose header has a `**Verification commands:**` block: the brief must contain a section `## Verification commands (from the plan header)` followed by that block verbatim. A plan with no such header: the brief must be byte-identical to what `task-brief` produces today (legacy path unchanged). Expected error: `FAIL: brief lacks the plan-header Verification commands`.
7. Run it and confirm it fails for that reason, then implement in `skills/gaspol-parallel/scripts/task-brief`: extract the header block (the `**Verification commands:**` line plus its consecutive `- ` lines) and append it after the phase block under the heading above; when the header has none, append nothing.
8. Write failing test for the new ledger template shape in `tests/ticket-scripts/test-ledger-template.sh` (it extracts the template from `skills/gaspol-plan/SKILL.md`; keep its positive control that the extractor read a real template). New assertions: the template's example Phase A checklist no longer contains `npx tsc --noEmit passes`, `npm test passes` or `No placeholder/TODO comments in new code`; the `## Pre-flight` table still has the `detect-stack` row (this is where the commands are recorded once). Expected error: `FAIL: ledger template still copies generic verification lines`.
9. Update `skills/gaspol-plan/SKILL.md`: (a) in the Plan Document Header template add a `**Verification commands:**` block with the three variants (a `static:`/`unit:` list copied verbatim from `detect-stack`; `- <level>: UNKNOWN — ask user before Verification can run`; `- detect-stack: no stack markers for this project — verification is plan-declared only`), with the rule that it is written ONCE per plan; (b) change the Phase Structure example so its Verification block shows only phase-specific checks; (c) rewrite the "Verification Criteria per Phase" section: the per-phase block holds only checks specific to that phase, at least one; "real data from [source]" counts as specific only when it names a concrete source; the placeholder-comment line is dropped because `gaspol-verify` Layer 3 owns it; the `detect-stack` run, its UNKNOWN rule and its no-markers rule now apply to the header block; (d) update the ledger template's example Phase A checklist to phase-specific lines only, and say commands are recorded in `## Pre-flight`; (e) add a Red Flags row: generic lines repeated per phase; (f) in the "Execution Waves" section add the `verification-lint` call right after `plan-waves`, anchored with `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/verification-lint" <plan-file>` and a four-row exit table (0 continue, 1 fix the plan, 3 STOP and ask, 4 legacy plan: add the header block and re-run — exit 4 is never a pass). Do not edit `gaspol-verify` or `gaspol-execute`: their "plan-declared commands" wording stays true because the header block IS the plan-declared commands.
10. Run the four tests from steps 5-8 until green, then the full suite `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. Repoint any other red test to the new wording; record each in the ledger.
11. Dogfood and record: run the lint on this plan (it uses the legacy format, so expect exit 4 and record it as N/A, not a pass) and on the new-format fixture from step 2 (expect exit 0).
12. Commit: `feat(gaspol-dev): phase-specific verification, header commands and verification-lint (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `verification-lint` returns exit 1 on a fixture phase that has only generic lines, and exit 4 (not 0) on a legacy plan
- [ ] `task-brief` on a fixture plan with a header block writes a brief containing `## Verification commands (from the plan header)`; on a legacy plan the brief is unchanged
- [ ] `git ls-files -s skills/gaspol-plan/scripts/verification-lint` shows mode `100755`
- [ ] No placeholder/TODO comments in new code

### Phase C: Trim gaspol-verify under 18,000 bytes

**Deps:** A, B
**Complexity:** complex — largest overage (14.4 KB, 42%), more gates than any other skill (Layer 1 holds Live App Check, Regression, Ledger and Model Tier gates), and nine existing tests read it.
**Estimated time:** 60 minutes

**Files:**
- Modify: `skills/gaspol-verify/SKILL.md`
- Create: `skills/gaspol-verify/references/layer-1-gates.md`
- Create: `skills/gaspol-verify/references/layer-4-design.md`
- Create: `tests/ticket-scripts/test-skill-trim-verify.sh`

**Steps:**
1. Write failing test for the `gaspol-verify` size ceiling in `tests/ticket-scripts/test-skill-trim-verify.sh`. Expected error: `FAIL: skills/gaspol-verify/SKILL.md is 34416 bytes (limit: under 18000)`.
2. Run `bash tests/ticket-scripts/test-skill-trim-verify.sh` and confirm it fails for that reason (size assertion), not for a syntax error.
3. List the gates BEFORE moving anything: run `grep -nE 'BLOCKING|MUST|NEVER|STOP|Iron Law|HARD|exit [0-9]' skills/gaspol-verify/SKILL.md`. For each distinct gate (the Iron Law, the five-step Gate Function, `detect-stack` three states, Live App Check, Regression Gate, Ledger Gate, Model Tier Gate, plan-verifier BLOCKING condition, Spec Fidelity / Blast Radius lines, Layer 3 scan rules, Layer 4 `design-contract` / `visual-diff` / `wig-lane` states, the Red Flags and Rationalization sections), record in the test's `GATES` array: the gate name and ONE fixed string (at least 25 characters, matched with `grep -qF`) from the sentence that states its condition and consequence. Run the test: every gate assertion must PASS against today's text, and only the size assertion fails.
4. Move detail into `skills/gaspol-verify/references/`: the sub-sections of `## Layer 1: Technical Verification` (10,643 bytes; Live App Check, Regression Gate, Ledger Gate, Model Tier Gate, Evals, Evidence Format) into `layer-1-gates.md`; the sub-sections of `## Layer 4: Integration + Design Compliance Verification` (11,663 bytes; Design Compliance Sub-Check, Web Interface Guidelines lane, Evidence Format) into `layer-4-design.md`. Rules: a gate keeps ONE sentence in `SKILL.md` stating its condition and its consequence (for example "BLOCKING when X"); tables of states, line-format contracts, examples and rationale may move; tighten wording freely, never drop an obligation; each moved block leaves a pointer line `Read references/<file>.md when <the step that needs it>`; reference files carry no frontmatter; never point at a file that does not exist.
5. Run the new test until green (size under 18,000 and every gate string present). If a skill cannot reach 18,000 without moving a gate, raise this test's limit to 20,000 and write the reason under `## Keputusan saat jalan` in the ledger; if it cannot reach 20,000, STOP and ask the owner. Never move an obligation out of the body to make a number pass.
6. Run the full suite `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. For each red test, read what it asserts. If the asserted text moved into `references/`, repoint the test to read `SKILL.md` AND `skills/gaspol-verify/references/*.md` together; never delete or loosen an assertion. Expect these to need a look: design-contract, finish-gates, geometry-diff, live-app-check, naming-convention, plan-verifier-spec, regression-gate, skill-delegation, wig-lane. Record each repoint in the ledger.
7. Run `bash tests/ticket-scripts/test-skill-frontmatter.sh` and `skills/gaspol-verify/scripts/model-gate`; both must stay green.
8. Commit: `refactor(gaspol-dev): trim gaspol-verify under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-verify/SKILL.md` prints a number under 18000 (or under 20000 with the reason written in the ledger)
- [ ] every `GATES` string in `test-skill-trim-verify.sh` is found in `skills/gaspol-verify/SKILL.md`
- [ ] every `references/` file named in `skills/gaspol-verify/SKILL.md` exists
- [ ] No placeholder/TODO comments in new code

### Phase D: Trim gaspol-plan under 18,000 bytes

**Deps:** B, C
**Complexity:** complex — Phase B just rewrote the template this skill owns; the ledger template that `test-ledger-template.sh` extracts and the handoff offer both move, and eight tests read it.
**Estimated time:** 50 minutes

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md`
- Create: `skills/gaspol-plan/references/ledger-format.md`
- Create: `skills/gaspol-plan/references/execution-handoff.md`
- Create: `tests/ticket-scripts/test-skill-trim-plan.sh`
- Modify: `tests/ticket-scripts/test-ledger-template.sh`

**Steps:**
1. Write failing test for the `gaspol-plan` size ceiling in `tests/ticket-scripts/test-skill-trim-plan.sh`. Expected error: `FAIL: skills/gaspol-plan/SKILL.md is` followed by a byte count and `(limit: under 18000)`.
2. Run it and confirm it fails for the size assertion only.
3. List the gates BEFORE moving anything: `grep -nE 'BLOCKING|MUST|NEVER|STOP|Iron Law|HARD|exit [0-9]|MANDATORY' skills/gaspol-plan/SKILL.md`. Record in the test's `GATES` array one fixed string per gate (completeness gate, ticket resolution by glob and the "more than one match: STOP and ask" rule, header fields including `**Format:** waves-v1` and `**Verification commands:**`, ledger created at plan-write time, TDD step 1 hard gate and its self-check count, Data Integration Map mandatory, Deps/Complexity rules, `plan-waves` exit table, `verification-lint` exit table, the post-plan offer and the non-empty skip-reason rule, Red Flags). Run the test: gate assertions PASS, size FAILS.
4. Move detail into `skills/gaspol-plan/references/`: the ledger template and its four-mandatory-sections table and state markers (the `## Log` code block, 3,554 bytes, plus the prose around it) into `ledger-format.md`; the Execution Handoff section (5,123 bytes: option list, external executor resolution, recording an approved artifact) into `execution-handoff.md`. Keep in the body: the one-sentence obligation per gate, the header template, the phase template, the `plan-waves` and `verification-lint` calls. Same rules as Phase C step 4 (one sentence per gate stays, pointer lines, no frontmatter, no dangling pointers).
5. Repoint the extractor in `tests/ticket-scripts/test-ledger-template.sh` to the file where the ledger template now lives, keeping its positive control that the extractor read a real template, not an empty file. Run it, then the new trim test until green. Same limit-and-ask rule as Phase C step 5.
6. Run the full suite. Repoint each red test as in Phase C step 6 (this skill is read by completeness-ladder, finish-gates, kb-no-hardcoded-path, ledger-template, logic-design-artifact, naming-convention, plan-waves-wiring, spec-pointer); record each in the ledger.
7. Run `skills/gaspol-plan/scripts/plan-waves docs/plans/2026-10-24-IDS-23-skill-size-builder-check-verification-plan.md` and confirm exit 0 still (the plan file must still parse), and `test-skill-frontmatter.sh` and `model-gate` stay green.
8. Commit: `refactor(gaspol-dev): trim gaspol-plan under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-plan/SKILL.md` prints a number under 18000 (or under 20000 with the reason in the ledger)
- [ ] `test-ledger-template.sh` still extracts a real template (its positive control passes) from its new location
- [ ] the header template, the `plan-waves` call and the `verification-lint` call are still in `skills/gaspol-plan/SKILL.md`, not only in `references/`
- [ ] No placeholder/TODO comments in new code

### Phase E: Trim gaspol-parallel under 18,000 bytes

**Deps:** C, D
**Complexity:** medium — one skill, one dominant section (Process Flow, 14.9 KB); seven tests read it, and `test-model-gate` and `test-model-rule` read dispatch lines that must keep their tier text.
**Estimated time:** 40 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`
- Create: `skills/gaspol-parallel/references/process-flow.md`
- Create: `skills/gaspol-parallel/references/task-tracking.md`
- Create: `tests/ticket-scripts/test-skill-trim-parallel.sh`

**Steps:**
1. Write failing test for the `gaspol-parallel` size ceiling in `tests/ticket-scripts/test-skill-trim-parallel.sh`. Expected error: `FAIL: skills/gaspol-parallel/SKILL.md is 30057 bytes (limit: under 18000)`.
2. Run it and confirm it fails for the size assertion only.
3. List the gates BEFORE moving anything with the grep from Phase C step 3, adding `Phase 0` and `fix loop`. Record one fixed string per gate in the test's `GATES` array (mode field, pre-flight conflict matrix BLOCKING, Phase 0 worktree isolation, implementer Status routing, DAG lane scheduling BLOCKING, five-round fix loop pointer to `skills/_shared/fix-loop.md` without restating its number, anti-placeholder rules, Red Flags, handling failures). Run: gates PASS, size FAILS.
4. Move detail into `skills/gaspol-parallel/references/`: the long `## Process Flow` (14,915 bytes) into `process-flow.md`, `## Task Execution Tracking` (3,637 bytes) into `task-tracking.md`. Keep every dispatch line that carries a `model:` value or a tier statement in `SKILL.md` (the model-gate and model-rule tests read them). Same rules as Phase C step 4.
5. Run the new test until green; same limit-and-ask rule as Phase C step 5.
6. Run the full suite and repoint red tests as in Phase C step 6 (dispatch-contract, finish-fix-loop, fix-loop, model-gate, model-rule, naming-convention, preflight-matrix). Record each in the ledger.
7. Run `skills/gaspol-verify/scripts/model-gate` and `test-skill-frontmatter.sh`; both must stay green.
8. Commit: `refactor(gaspol-dev): trim gaspol-parallel under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-parallel/SKILL.md` prints a number under 18000 (or under 20000 with the reason in the ledger)
- [ ] `skills/gaspol-verify/scripts/model-gate` exits 0 after the trim
- [ ] the five-round fix-loop rule is still referenced through `skills/_shared/fix-loop.md` and its number is not restated
- [ ] No placeholder/TODO comments in new code

### Phase F: Trim gaspol-execute under 18,000 bytes

**Deps:** E
**Complexity:** medium — one skill, three large sections (Pre-Execution 7.3 KB, Execution Flow 6 KB, Per-Phase Checkpoint 3.8 KB); an existing trim test already asserts its obligations and holds the old size limit.
**Estimated time:** 40 minutes

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md`
- Create: `skills/gaspol-execute/references/pre-execution.md`
- Create: `skills/gaspol-execute/references/execution-flow.md`
- Create: `tests/ticket-scripts/test-skill-trim-execute.sh`
- Modify: `tests/ticket-scripts/test-execute-trim.sh`

**Steps:**
1. Write failing test for the `gaspol-execute` size ceiling in `tests/ticket-scripts/test-skill-trim-execute.sh`. Expected error: `FAIL: skills/gaspol-execute/SKILL.md is 29286 bytes (limit: under 18000)`.
2. Run it and confirm it fails for the size assertion only.
3. List the gates BEFORE moving anything with the grep from Phase C step 3. Also read `tests/ticket-scripts/test-execute-trim.sh`: it already asserts every gate name, all three Iron Laws and the exact TDD step-1 phrasing in `SKILL.md`; those strings are the minimum `GATES` set, add the rest (baseline before Phase A, per-phase Verification Loop gate, Completeness Gate, anti-placeholder rules, the four-state design-artifact ledger reading, finish offer at Step 8). Run: gates PASS, size FAILS.
4. Move detail into `skills/gaspol-execute/references/`: `## Pre-Execution Protocol` (7,346 bytes) into `pre-execution.md`; `## Execution Flow` (5,962 bytes) and the checkpoint report format from `## Per-Phase Checkpoint` (3,751 bytes) into `execution-flow.md`. Same rules as Phase C step 4. `skills/gaspol-execute/anti-placeholder-rules.md` and `checkpoint-template.md` already exist; point to them rather than duplicating.
5. In `tests/ticket-scripts/test-execute-trim.sh` change `LIMIT=29400` to `LIMIT=18000` and rewrite the comment above it to name IDS-23 and say why (the compaction cut), keeping every obligation assertion in that test. Run it and the new trim test until green; same limit-and-ask rule as Phase C step 5.
6. Run the full suite and repoint red tests as in Phase C step 6 (completeness-ladder, execute-trim, logic-design-artifact, naming-convention, preflight-matrix, single-owner-gates, skill-delegation, verification-loop). Record each in the ledger.
7. Run `test-skill-frontmatter.sh` and `model-gate`; both must stay green.
8. Commit: `refactor(gaspol-dev): trim gaspol-execute under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-execute/SKILL.md` prints a number under 18000 (or under 20000 with the reason in the ledger)
- [ ] `grep -n "LIMIT=" tests/ticket-scripts/test-execute-trim.sh` shows `LIMIT=18000` (or 20000 with the ledger reason)
- [ ] the exact TDD step-1 phrasing and all three Iron Laws are still in `skills/gaspol-execute/SKILL.md`
- [ ] No placeholder/TODO comments in new code

### Phase G: Trim gaspol-brainstorm under 18,000 bytes

**Deps:** A, F
**Complexity:** medium — one skill, Phase A just changed its Phase 6, and the largest section (Phase 3, 5.2 KB) holds the DESIGN.md freeze and visual companion detail; eight tests read it.
**Estimated time:** 40 minutes

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md`
- Create: `skills/gaspol-brainstorm/references/phase-3-design.md`
- Create: `skills/gaspol-brainstorm/references/phase-0-5-precedent.md`
- Create: `tests/ticket-scripts/test-skill-trim-brainstorm.sh`

**Steps:**
1. Write failing test for the `gaspol-brainstorm` size ceiling in `tests/ticket-scripts/test-skill-trim-brainstorm.sh`. Expected error: `FAIL: skills/gaspol-brainstorm/SKILL.md is` followed by a byte count and `(limit: under 18000)`.
2. Run it and confirm it fails for the size assertion only.
3. List the gates BEFORE moving anything with the grep from Phase C step 3. Record one fixed string per gate in `GATES`: HARD-GATE (no implementation before an approved design), CLAUDE.md-first, Phase 0.5 states (`available` / `none` / `UNKNOWN` and "STOP and ask"), Batch Gate ruling stated out loud and the ceiling of two, the three paths and the one-way ratchet, decompose gate, one question at a time through `AskUserQuestion`, Phase 1.5 novelty classes and "NEVER auto-install", Phase 2.5 routing, Phase 6 ticket minting once per batch, and the Phase 6 builder check from Phase A (`model: "opus"`, `model-tier: judge`, `one round`, `nothing important left`). Run: gates PASS, size FAILS.
4. Move detail into `skills/gaspol-brainstorm/references/`: `## Phase 3: Design Intelligence` (5,190 bytes: the DESIGN.md freeze, visual companion offer rules, expected returns from `ui-ux-pro-max`) into `phase-3-design.md`; the tag-extraction, freshness and surfacing template detail of `## Phase 0.5` (4,053 bytes) into `phase-0-5-precedent.md`. `skills/gaspol-brainstorm/visual-companion.md` already exists; point to it. The Phase 6 builder check flow stays in the body because it carries the dispatch's `model:` and `model-tier:` lines. Same rules as Phase C step 4.
5. Run the new test until green; same limit-and-ask rule as Phase C step 5.
6. Run the full suite and repoint red tests as in Phase C step 6 (batch-gate, logic-design-artifact, naming-convention, prior-art-gate, research-tools, skill-delegation, vault-read, wig-lane, and `test-builder-check.sh` from Phase A). Record each in the ledger.
7. Run `skills/gaspol-verify/scripts/model-gate` (it must still find `model-tier: judge` beside the `model: "opus"` dispatch) and `test-skill-frontmatter.sh`.
8. Commit: `refactor(gaspol-dev): trim gaspol-brainstorm under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-brainstorm/SKILL.md` prints a number under 18000 (or under 20000 with the reason in the ledger)
- [ ] `skills/gaspol-verify/scripts/model-gate` exits 0 and `skills/gaspol-brainstorm/SKILL.md` still holds `model: "opus"` and `model-tier: judge` together
- [ ] the HARD-GATE block is still in `skills/gaspol-brainstorm/SKILL.md`
- [ ] No placeholder/TODO comments in new code

### Phase H: Trim gaspol-finish under 18,000 bytes

**Deps:** G
**Complexity:** medium — one skill, smallest overage (3.2 KB) but a rigid skill whose four mandatory steps and BLOCKING conditions must stay in the body; seven tests read it.
**Estimated time:** 30 minutes

**Files:**
- Modify: `skills/gaspol-finish/SKILL.md`
- Create: `skills/gaspol-finish/references/offers.md`
- Create: `tests/ticket-scripts/test-skill-trim-finish.sh`

**Steps:**
1. Write failing test for the `gaspol-finish` size ceiling in `tests/ticket-scripts/test-skill-trim-finish.sh`. Expected error: `FAIL: skills/gaspol-finish/SKILL.md is 21191 bytes (limit: under 18000)`.
2. Run it and confirm it fails for the size assertion only.
3. List the gates BEFORE moving anything with the grep from Phase C step 3. Record one fixed string per gate in `GATES`: the four mandatory steps in order (verify, plan-verifier, review Tier 1, sync-docs), the `verified: PASS @ <sha>` and `plan-verifier: CLEAN @ <sha>` reuse rule (sha equals `HEAD` and a clean `git status --porcelain`), `plan-verifier` BLOCKING, Tier 1 BLOCKING on Critical findings after refutation, the ledger close (`— NEXT: DONE`), the four merge options and the typed `discard` confirmation. Run: gates PASS, size FAILS.
4. Move detail into `skills/gaspol-finish/references/offers.md`: the text of `## The Offers` (5,124 bytes) and the long tails of `## Present Options` (2,843 bytes). The four mandatory steps and every BLOCKING condition stay in `SKILL.md`. Same rules as Phase C step 4.
5. Run the new test until green; same limit-and-ask rule as Phase C step 5.
6. Run the full suite and repoint red tests as in Phase C step 6 (finish-fix-loop, finish-gates, fix-loop, naming-convention, regression-gate, single-owner-gates, skill-delegation). `test-finish-fix-loop.sh` fails if any mandatory step or either offer disappears: it must still pass, repointed to read `references/` where the offers moved. Record each in the ledger.
7. Run `test-skill-frontmatter.sh` and `model-gate`.
8. Commit: `refactor(gaspol-dev): trim gaspol-finish under the compaction cut, gates kept (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `wc -c < skills/gaspol-finish/SKILL.md` prints a number under 18000 (or under 20000 with the reason in the ledger)
- [ ] `tests/ticket-scripts/test-finish-fix-loop.sh` passes and still fails if a mandatory step is removed (confirm by deleting one step in a temp copy)
- [ ] the four mandatory steps are still in order in `skills/gaspol-finish/SKILL.md`
- [ ] No placeholder/TODO comments in new code

### Phase I: Global size and reference tests, no exemption list

**Deps:** C, D, E, F, G, H
**Complexity:** medium — two new test scripts with positive controls; they run against the whole repository, so they only go green once all six trims have landed.
**Estimated time:** 30 minutes

**Files:**
- Create: `tests/ticket-scripts/test-skill-size.sh`
- Create: `tests/ticket-scripts/test-skill-references.sh`

**Steps:**
1. Write failing test for the global size ceiling in `tests/ticket-scripts/test-skill-size.sh`, built around a `check_dir <skills-dir>` function that fails for any `<skills-dir>/*/SKILL.md` of 20,000 bytes or more (bytes, via `wc -c`). The script first runs two positive controls through `check_dir` on a `mktemp -d` tree: a `SKILL.md` of exactly 20,001 bytes must FAIL and one of 19,999 bytes must PASS. Expected error: `check_dir: command not found`, from calling the function before it is defined.
2. Run `bash tests/ticket-scripts/test-skill-size.sh` and confirm it fails with that error.
3. Define `check_dir` and run the real check on `skills/`. There is NO exemption list and NO per-skill override: the only parameter is the directory, used by the controls. Confirm it passes on the repository now that Phases C-H landed.
4. Write failing test for reference integrity in `tests/ticket-scripts/test-skill-references.sh`. Expected error: `FAIL: skills/gaspol-` followed by a skill name and `names references/` and a file that does not exist, produced first against a fixture. Fixtures in a `mktemp -d` tree: a `SKILL.md` naming `references/missing.md` (dangling pointer, must FAIL) and a `references/orphan.md` that no `SKILL.md` names (orphan, must FAIL), plus a clean skill that must PASS.
5. Implement it for the real tree: every `references/<file>.md` named in a skill's `SKILL.md` exists in that skill's `references/` directory, and every file under a skill's `references/` directory is named by that skill's `SKILL.md`. Run it; both fixtures behave as stated and the real repository passes.
6. Run `skills/gaspol-verify/scripts/model-gate`, `bash tests/ticket-scripts/test-skill-frontmatter.sh`, `git ls-files -s tests/ticket-scripts/test-skill-size.sh` (any mode is fine for tests invoked with `bash`), and the full suite.
7. Mutation proof, recorded in the ledger: copy `skills/gaspol-verify/SKILL.md` to a temp skills tree, append bytes until it reaches 20,000, run `check_dir` on it and see FAIL.
8. Commit: `test(gaspol-dev): skill size ceiling and reference integrity, no exemption list (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `bash tests/ticket-scripts/test-skill-size.sh` exits 0 on the repository, and its 20,001-byte control FAILS and 19,999-byte control PASSES
- [ ] `bash tests/ticket-scripts/test-skill-references.sh` exits 0 on the repository, and its dangling-pointer and orphan controls both FAIL as intended
- [ ] `grep -nE "exempt|allowlist|SKIP_" tests/ticket-scripts/test-skill-size.sh` prints nothing
- [ ] No placeholder/TODO comments in new code

### Phase J: Release 1.32.0, docs and metadata

**Deps:** I
**Complexity:** medium — several documentation surfaces (plugin metadata, CLAUDE.md, README, the marketplace repo), none new logic, but version drift across them is a known defect class here.
**Estimated time:** 35 minutes

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Steps:**
1. Write failing test for version consistency across surfaces. First run `ls tests/ticket-scripts | grep -iE "version|release|manifest"`; extend the existing version test if one exists, otherwise create `tests/ticket-scripts/test-version-consistency.sh` asserting that `.claude-plugin/plugin.json` `version`, the `**Version:**` footer in `CLAUDE.md` and the README version badge all read `1.32.0`. Expected error: `FAIL: plugin.json version is 1.31.0, expected 1.32.0`.
2. Run it and confirm it fails for that reason.
3. Set `.claude-plugin/plugin.json` `version` to `1.32.0`.
4. Update `CLAUDE.md`: footer `**Version:** 1.32.0` and `Last Updated`; Architecture rows for `skills/gaspol-plan/scripts/verification-lint`, `skills/gaspol-brainstorm/references/builder-check-prompt.md`, the new `references/` directories, `tests/ticket-scripts/test-skill-size.sh`, `test-skill-references.sh`, `test-builder-check.sh`, `test-verification-lint.sh`; change Brainstorming Flow item 10 so Phase 6 names the builder check instead of "spec self-review (v1.5)"; fix the v1.27 section sentence that says Phase 6's spec self-review "still grades itself"; add a section `### Skill Size Ceiling + Builder Check + Phase-Specific Verification (NEW in v1.32, IDS-23)` that states the defect with its evidence (the six byte counts), what changed, what each part gives up (scope-creep check weaker, detail one read away, builder check is model judgement, `task-brief` covers the subagent path only), and what is not closed (an agent that skips a `references/` pointer; skills under 20,000 bytes are not trimmed; Review Focus / Interfaces / `Ruling:` ideas from superpowers not adopted). Keep the `Last ticket: IDS-23` counter. If the architecture table row for `test-execute-trim.sh` or a size figure elsewhere now disagrees with the trimmed files, correct it.
5. Update `README.md`: the version badge to `1.32.0`, add a `| **1.32.0** (current) | ... |` row to the changelog table and drop `(current)` from the 1.31.0 row.
6. Prepare, but do NOT commit or push, the matching changes in the separate repository `/Users/alisadikin/Drive-D/claude-plugin/gaspol-one`: its README version table and the `gaspol-dev` entry in its `.claude-plugin/marketplace.json` set to 1.32.0. Leave them as uncommitted working-tree edits and record in the ledger `## Utang terbuka` that committing and pushing that repository is the owner's call after this branch merges. Cross-check `plugin.json`, `marketplace.json` and both READMEs all read 1.32.0.
7. Run `skills/gaspol-verify/scripts/model-gate`, the full suite `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`, and `skills/gaspol-verify/scripts/blast-radius-diff` against the plan (a WARN is acceptable, record it).
8. Commit: `chore(gaspol-dev): release 1.32.0 — skill size ceiling, builder check, phase-specific verification (IDS-23)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `.claude-plugin/plugin.json`, the `CLAUDE.md` footer and the README badge all say `1.32.0`
- [ ] the `gaspol-one` repository's README and `marketplace.json` say `1.32.0` as uncommitted edits, and `git -C /Users/alisadikin/Drive-D/claude-plugin/gaspol-one log -1 --format=%H` is unchanged from before this phase
- [ ] `grep -c "spec self-review" CLAUDE.md` prints 0 for the live-behaviour sentences (only the historical IDS-23 description may mention the old name)
- [ ] No placeholder/TODO comments in new code

## Out of scope

Review Focus / `Interfaces: Consumes/Produces` in plans, `Ruling:` ledger entries and a session-diagnosis skill (superpowers ideas, not adopted); trimming skills already under 20,000 bytes; committing or pushing the `gaspol-one` repository; a second builder-check round on the spec's Part C (the `plan-verifier` audit at finish covers spec fidelity).

## Red Flags checked

Data Integration Map present; every phase has Verification; CLAUDE.md read; no vague data sources; test steps in every phase; every phase estimated at or under 60 minutes (Phase B is the largest); no placeholder language; plan inlines every contract it needs.
