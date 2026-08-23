> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-18.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat.

**Ticket:** IDS-18
**Ledger:** .gaspol/progress/PROGRESS-IDS-18.md
**Spec:** docs/plans/2026-08-23-IDS-18-spec-fidelity-gate-spec.md

## Goal

Two links of the `spec → plan → code` chain are unguarded. `gaspol-plan` writes a `**Spec:** <path>`
pointer into every plan header and nothing reads it, so a requirement the plan drops is never
detected. The artifact's mandatory blast-radius section is never compared to the diff. This plan
adds two deterministic scripts and one new verdict to the agent that already runs on every
completion claim, closing both without adding a single step or agent dispatch to any chain.

## Architecture Context

Pulled from `CLAUDE.md` and verified by reading the files:

- **`agents/plan-verifier.md`** (251 lines) — the step-level audit. Six process steps, a verdict
  taxonomy (`FOUND` / `PARTIAL` / `MISSING` / `DIVERGED`), an evidence-quote rule, and a `BLOCKING`
  verdict computed as `MISSING > 0 OR unapproved PARTIAL > 0 OR placeholders > 0`. Invoked BLOCKING
  from `gaspol-execute` Step 7, `gaspol-auto` Step 111, and `gaspol-finish` step 2.
- **`skills/gaspol-verify/SKILL.md`** (601 lines) — Layer 2 "Plan Fidelity Check" at line 175, with
  a `Deliverable Status Codes` table and an `Evidence Format` block at line 207.
- **`skills/gaspol-plan/SKILL.md:126`** — the header template that writes `**Spec:**`, including a
  trailing HTML comment on the same line.
- **Phase Structure template** (`skills/gaspol-plan/SKILL.md`) — every phase declares its files as
  `- Create: \`path\`` / `- Modify: \`path\`` / `- Test: \`path\`` bullets under a `**Files:**`
  heading. This is the shape `blast-radius-diff` parses.
- **`skills/gaspol-debug/scripts/regression-gate`** — the script convention to copy: `#!/usr/bin/env
  bash`, `set -euo pipefail`, a header docstring stating the full contract and every exit code, one
  stdout report line on **every** exit path, and a built-in `--self-test`.
- **`skills/_shared/kb-root`** — the exit-code contract this repository already uses: `0` available
  / `3` UNKNOWN / `4` none.
- **`tests/ticket-scripts/test-kb-no-hardcoded-path.sh`** — the anchored-invocation gate. Its regex
  is hardcoded to `skills/_shared/kb-root` and must be widened. It also demonstrates the mandatory
  **positive control**: an assertion that "nothing matches" passes trivially when the search itself
  is broken, and this repository has shipped that vacuous green before.
- **`tests/ticket-scripts/test-gate-mutations.sh`** — the table of planted lines with expected
  caught/allowed verdicts. Adding an exemption means adding its attack row first.

## Tech Stack

Bash (stdlib only, no dependencies), matching every existing script in `skills/*/scripts/`. Tests
are bash files in `tests/ticket-scripts/`, run with
`for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. Python3 is available and used by
one existing test for block parsing; prefer bash unless a parser genuinely needs it.

`skills/gaspol-execute/scripts/detect-stack <repo-root>` printed **zero lines** for this repository
— it carries no stack markers (markdown and bash only). Per `gaspol-plan`'s rule, every Verification
block below is therefore **plan-declared only**, and no `tsc`/`npm`/`pytest` command may be invented
for it.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-------------|----------|---------|--------|
| Spec path resolution | `**Spec:** <path>` line in the plan header | `spec-pointer` (new script) | Line: **Yes** (written by `gaspol-plan` since IDS-1). Script: **No** | Create the script; read the existing line |
| Spec requirements | bullets + Data Integration Map in `docs/plans/*-spec.md` | read directly by the `plan-verifier` agent | Yes | Read directly, no new machinery |
| Planned file list | `- Create:` / `- Modify:` / `- Test:` bullets under `**Files:**` in the plan | `blast-radius-diff` (new script) | Bullets: **Yes** (Phase Structure template). Script: **No** | Create the script; parse the existing shape |
| Files actually changed | `git diff --name-only <BASE>..HEAD` | plain git | Yes | Use directly |
| Artifact blast-radius list | `design-artifact: <url>` in the ledger | `Artifact action:"read"` | Yes | Cross-check **only when readable**; disagreement is exit 3 |
| Verdict recording | `## Log` / gate lines in `.gaspol/progress/PROGRESS-IDS-18.md` | ledger file | Yes | Append lines |

**Zero placeholder risk.** Every source above is already written today by existing skills; nothing
has to be invented or stubbed. The two "No" rows are the scripts this plan creates as real, working
code.

## Out of scope

The artifact's other four sections (before/after behaviour, mermaid flow, data-flow table,
edge-case matrix); grading spec *quality* rather than spec *retention*; adding any spec step to
`gaspol-debug`. All four are recorded in the spec's "What this does NOT close".

---

### Phase A: `spec-pointer` — resolve the spec path, three states

**Estimated time:** 12 minutes

**Files:**
- Create: `skills/gaspol-verify/scripts/spec-pointer`
- Test: `tests/ticket-scripts/test-spec-pointer.sh`

**Completeness ladder for this phase:**
1. *Happy path* — a plan header naming a readable spec with parseable content prints the resolved
   absolute path and exits 0.
2. *Error paths that can actually happen* — plan file missing or unreadable; more than one
   `**Spec:**` line; the spec path does not exist; the spec file is empty or carries no structure.
3. *Edge cases, enumerated* — `**Spec:**` present with an empty value; value that is only
   whitespace; a **trailing HTML comment on the same line** (`gaspol-plan`'s own template ships
   one, so this is the common case, not an exotic one); a repo-relative path resolved while CWD is
   the target project; an absolute path; a path containing spaces; a spec file of exactly one line;
   a spec that is non-empty but has no bullet, table row, or heading.
4. *Tests* — one case per row of the state table below, written first.
5. *Observability* — one `spec-pointer: <verdict>` line on stdout on **every** exit path, so a
   caller can capture it unconditionally for a ledger line.

**Steps:**
1. Write failing test for `spec-pointer --self-test`. Expected error: `bash: .../spec-pointer: No such file or directory` (exit 127).
2. Run `bash tests/ticket-scripts/test-spec-pointer.sh`, confirm it fails for that reason and not a syntax error in the test.
3. Create `spec-pointer` with the header docstring stating the full contract and all four exit codes verbatim, `set -euo pipefail`, and `main()` handling `--self-test` first.
4. Implement header parsing: strip a trailing `<!-- ... -->` comment, trim whitespace, reject an empty value, reject more than one `**Spec:**` line.
5. Implement path resolution against `git rev-parse --show-toplevel`, never `$PWD`.
6. Implement the content check: the spec must have at least three non-blank lines and at least one line beginning with `-`, `*`, `|`, or `#`. Fewer means no parseable requirements — exit 3, never a silent pass.
7. Implement the built-in `--self-test` covering every row of the state table, using a temp directory and a real `git init` so path resolution is exercised, not mocked.
8. Run `bash tests/ticket-scripts/test-spec-pointer.sh`, confirm all cases pass.
9. Commit: `feat(IDS-18): spec-pointer resolves the plan header's spec path in three states`.

**State table (implement exactly this):**

| Exit | State | Condition |
|---|---|---|
| 0 | resolved | pointer present, file exists, content parseable. Absolute path on stdout |
| 3 | UNKNOWN | plan unreadable · >1 `**Spec:**` line · empty/whitespace value · path does not exist · spec has no parseable content |
| 4 | none | no `**Spec:**` line in the plan header. **Not a failure** |

Exit 1 is deliberately unused: this script resolves, it does not judge.

**Verification:**
- [ ] `bash tests/ticket-scripts/test-spec-pointer.sh` exits 0
- [ ] `bash skills/gaspol-verify/scripts/spec-pointer --self-test` exits 0
- [ ] every one of the eleven enumerated edge cases has a named test case
- [ ] a trailing `<!-- ... -->` comment is stripped — assert against the literal line from `skills/gaspol-plan/SKILL.md:126`
- [ ] path resolution uses `git rev-parse --show-toplevel`; `grep -c '\$PWD' skills/gaspol-verify/scripts/spec-pointer` returns 0
- [ ] a `spec-pointer:` line is printed on all four exit paths
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] No placeholder/TODO comments in new code

---

### Phase B: `blast-radius-diff` — planned files vs the real diff

**Estimated time:** 15 minutes

**Files:**
- Create: `skills/gaspol-verify/scripts/blast-radius-diff`
- Test: `tests/ticket-scripts/test-blast-radius-diff.sh`

**Completeness ladder for this phase:**
1. *Happy path* — every changed file appears in some phase's `**Files:**` block; exit 0.
2. *Error paths* — plan missing or unreadable; BASE ref invalid or unreachable; not inside a git repository.
3. *Edge cases, enumerated* — no changes at all; a planned file deleted in the diff; a renamed file (git prints both paths); a changed file inside the ignore list; a plan naming a glob or a trailing-slash directory; a path containing spaces; a plan with no `**Files:**` block at all; a plan naming a file that is never touched (must **not** be reported here — that is `plan-verifier`'s `MISSING`, and duplicating it would produce two findings for one fact).
4. *Tests* — one case per row of the verdict table, written first.
5. *Observability* — a `blast-radius:` summary line plus one indented line per unplanned file, so the reviewer sees *which* files, not just a count.

**Steps:**
1. Write failing test for `blast-radius-diff --self-test`. Expected error: `bash: .../blast-radius-diff: No such file or directory` (exit 127).
2. Run `bash tests/ticket-scripts/test-blast-radius-diff.sh`, confirm it fails for that reason.
3. Create the script with the header docstring, `set -euo pipefail`, and `--self-test` handled first in `main()`.
4. Implement plan parsing: lines matching `^- (Create|Modify|Test|Delete): \`<path>\`` under a `**Files:**` heading. A path containing `*` or ending in `/` is reported UNKNOWN rather than silently ignored.
5. Implement the diff read: `git diff --name-only <BASE>..HEAD`, capturing output into a variable **before** any `grep` touches it — the `SIGPIPE`-under-`pipefail` race documented in `regression-gate`'s own header cost one run in six there, and the same shape would do it here.
6. Implement the ignore list as a built-in default: `.gaspol/`, `docs/plans/`, `CLAUDE.md`, and the common lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `composer.lock`, `poetry.lock`, `Cargo.lock`).
7. Implement the verdict table below, including the deliberate non-blocking exit 1.
8. Implement `--self-test` using a temp git repository with real commits, so the diff is real rather than mocked.
9. Run `bash tests/ticket-scripts/test-blast-radius-diff.sh`, confirm all cases pass.
10. Commit: `feat(IDS-18): blast-radius-diff compares the plan's file list to the real diff`.

**Verdict table (implement exactly this):**

| Exit | Verdict | Condition |
|---|---|---|
| 0 | clean | every changed file is planned or ignored |
| 1 | findings, **WARN-level, non-blocking** | one or more changed files are neither planned nor ignored |
| 3 | UNKNOWN | plan unreadable · BASE invalid · not a git repository · the plan names a glob or directory |
| 4 | none | the plan has no parseable `**Files:**` block. **Not a failure** |

**Exit 1 does not block, deliberately.** Collateral edits are legitimate and a per-file BLOCK would
fire on most branches; a gate that cries wolf gets switched off. Accountability moves to the
recorded `blast-radius:` line instead. This is weaker than Phase C's `DROPPED` and the spec says so
— do not describe the two as equivalent.

**Verification:**
- [ ] `bash tests/ticket-scripts/test-blast-radius-diff.sh` exits 0
- [ ] `bash skills/gaspol-verify/scripts/blast-radius-diff --self-test` exits 0
- [ ] every one of the eight enumerated edge cases has a named test case
- [ ] a planned-but-untouched file produces **no** finding here (that fact belongs to `plan-verifier`)
- [ ] the git output is captured into a variable before any `grep` reads it
- [ ] the self-test builds a real git repository, not a mocked diff
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] No placeholder/TODO comments in new code

---

### Phase C: `plan-verifier` reads the spec — Step 1b and the `DROPPED` verdict

**Estimated time:** 12 minutes

**Files:**
- Modify: `agents/plan-verifier.md`
- Test: `tests/ticket-scripts/test-plan-verifier-spec.sh`

**Completeness ladder for this phase:**
1. *Happy path* — spec items join the plan items in one audit list, each tagged with its origin.
2. *Error paths* — `spec-pointer` exit 3 must STOP and ask, exit 4 must record and continue. Neither may be collapsed into the other; collapsing exit 3 into exit 4 is the exact control-flow bug `test-kb-state4-continues.sh` exists to catch.
3. *Edge cases* — a spec requirement present in the plan but absent from the code (that is `MISSING`, not `DROPPED`); a requirement the plan explicitly lists under "Out of scope" (still `DROPPED` — the spec is the contract, and narrowing belongs in the spec); a standalone plan with no spec at all.
4. *Tests* — text assertions on the agent file, since an agent is prose the harness executes.
5. *Observability* — the report gains a `Spec Fidelity` section and a `spec:` state line.

**Steps:**
1. Write failing test for `test-plan-verifier-spec.sh` asserting `agents/plan-verifier.md` contains `DROPPED`. Expected error: `FAIL: agents/plan-verifier.md does not define the DROPPED verdict`.
2. Run `bash tests/ticket-scripts/test-plan-verifier-spec.sh`, confirm it fails for that reason.
3. Add **Step 1b** to the Process section, after "Step 1: Parse Plan Into Granular Items": invoke `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/spec-pointer" <plan-file>` and branch on exit 0 / 3 / 4 with the three behaviours written out in full.
4. Add `DROPPED` to the Verdict Taxonomy table: *requirement present in the spec, absent from the plan* — evidence required is the search performed over the plan text.
5. Update the Verdict rule to `BLOCKING (MISSING > 0 OR DROPPED > 0 OR unapproved PARTIAL > 0 OR placeholders > 0)` everywhere it appears, including the Output Format block and the Summary counts.
6. Add a `### Spec Fidelity` section to the Output Format showing the `spec:` state line and per-requirement verdicts.
7. Add **Step 2b** invoking `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/blast-radius-diff"` and recording its output; state explicitly that exit 1 is reported, not blocking.
8. State in Important Rules that a deliberate scope reduction must be written back into the spec file — narrowing in the plan alone BLOCKS.
9. Run `bash tests/ticket-scripts/test-plan-verifier-spec.sh`, confirm all assertions pass.
10. Commit: `feat(IDS-18): plan-verifier audits the spec and blocks on DROPPED`.

**Verification:**
- [ ] `bash tests/ticket-scripts/test-plan-verifier-spec.sh` exits 0
- [ ] `DROPPED` appears in the Verdict Taxonomy, the BLOCKING rule, the Summary counts, and the Output Format
- [ ] both script invocations are anchored with `$CLAUDE_PLUGIN_ROOT` — zero relative call sites
- [ ] exit 3 and exit 4 have visibly different documented behaviour (STOP-and-ask vs record-and-continue)
- [ ] the test carries a positive control proving its own greps can match
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] No placeholder/TODO comments in new prose

---

### Phase D: `gaspol-verify` Layer 2 records both states

**Estimated time:** 8 minutes

**Files:**
- Modify: `skills/gaspol-verify/SKILL.md`
- Test: `tests/ticket-scripts/test-plan-verifier-spec.sh` (extended, same file — the two changes assert one behaviour across two files)

**Completeness ladder for this phase:**
1. *Happy path* — Layer 2 records `spec-fidelity:` and `blast-radius:` beside the existing plan-fidelity evidence block.
2. *Error paths* — an unresolved spec pointer records UNKNOWN and STOPs; it is never recorded as passed. This is the rule `gaspol-finish` already applies to an unavailable `/security-review`.
3. *Edge cases* — a standalone plan records `spec: none — standalone plan`, which is explicitly **not** a failure; a plan with no `**Files:**` block records `blast-radius: none`.
4. *Tests* — text assertions, extended in the Phase C test file.
5. *Observability* — both lines live beside `design-contract:` and `visual-diff:`, so one place carries every gate state.

**Steps:**
1. Write failing test for Layer 2 recording a `spec-fidelity:` state line. Expected error: `FAIL: gaspol-verify Layer 2 records no spec-fidelity line`.
2. Run `bash tests/ticket-scripts/test-plan-verifier-spec.sh`, confirm it fails for that reason.
3. Add to Layer 2 the `spec-fidelity:` three-state line and the `blast-radius:` line, each with its state vocabulary written out.
4. Extend the Layer 2 `Evidence Format` block (currently at line 207) with both lines, so the example shows the real output shape.
5. State that a `not run` state is never recorded as passed.
6. Run `bash tests/ticket-scripts/test-plan-verifier-spec.sh`, confirm all assertions pass.
7. Commit: `feat(IDS-18): gaspol-verify Layer 2 records spec-fidelity and blast-radius`.

**Verification:**
- [ ] `bash tests/ticket-scripts/test-plan-verifier-spec.sh` exits 0
- [ ] both lines appear in the Evidence Format example, not only in prose
- [ ] the `none` state is documented as not-a-failure for both lines
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] No placeholder/TODO comments in new prose

---

### Phase E: widen the anchored-invocation gate and add attack rows

**Estimated time:** 12 minutes

**Files:**
- Modify: `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`
- Modify: `tests/ticket-scripts/test-gate-mutations.sh`

**Completeness ladder for this phase:**
1. *Happy path* — the gate rejects a relative invocation of either new script.
2. *Error paths* — the gate's own positive control must prove the widened search still matches; a widened regex that matches nothing passes vacuously, and this repository has shipped exactly that.
3. *Edge cases, enumerated* — a relative invocation inside a variable assignment; inside a bare command position; the same string appearing in **prose** wrapped in backticks (must be **allowed** — the existing gate is line-start anchored precisely because prose describing the hazard tripped it, five times on one branch).
4. *Tests* — the attack rows in `test-gate-mutations.sh` are themselves the test; each is added and watched to fail before the gate is widened.
5. *Observability* — the failure message names the required anchor, not merely "a path appears".

**Steps:**
1. Write failing test for the gate catching a relative invocation of either new script — four attack rows in `test-gate-mutations.sh`: a relative `spec-pointer` and a relative `blast-radius-diff` invocation, both expected **caught**; plus one prose mention of each in backticks, expected **allowed**. Expected error: `FAIL: planted line was NOT caught` on the two "caught" rows.
2. Run `bash tests/ticket-scripts/test-gate-mutations.sh`, confirm the two "caught" rows FAIL — the gate does not yet see the new scripts.
3. Generalise the regex in `test-kb-no-hardcoded-path.sh` from the literal `skills/_shared/kb-root` to a set covering `_shared/kb-root`, `gaspol-verify/scripts/spec-pointer`, and `gaspol-verify/scripts/blast-radius-diff`, keeping the line-start anchoring unchanged.
4. Raise the positive-control threshold to account for the new anchored invocations, so a broken search cannot pass as clean.
5. Run `bash tests/ticket-scripts/test-gate-mutations.sh`, confirm every row now matches its expected verdict.
6. Run the full suite: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`.
7. Commit: `test(IDS-18): the anchored-invocation gate covers both new scripts`.

**Verification:**
- [ ] `bash tests/ticket-scripts/test-gate-mutations.sh` exits 0 with all four new rows matching their expected verdicts
- [ ] the two "caught" rows were observed FAILING at step 2 before the gate was widened — a gate never seen red proves nothing
- [ ] prose mentions in backticks remain allowed
- [ ] the positive control was raised, not left at its old threshold
- [ ] full suite green: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only

---

### Phase F: documentation sync and release

**Estimated time:** 10 minutes

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude-plugin/plugin.json`

**Completeness ladder for this phase:**
1. *Happy path* — the Architecture table gains both scripts; a new section documents the gate.
2. *Error paths* — none; this phase is documentation and a version string.
3. *Edge cases* — the marketplace entry lives in a **separate repository** (`gaspol-one`) and is not editable from here; say so rather than silently skipping it.
4. *Tests* — the existing suite must stay green; `test-skill-frontmatter.sh` must still parse every skill.
5. *Observability* — not applicable, documentation phase. Written down rather than left blank.

**Steps:**
1. Write failing test for CLAUDE.md documenting both new scripts. Expected error: `FAIL: CLAUDE.md does not document spec-pointer`.
2. Run the assertion, confirm it fails.
3. Add both scripts to the Architecture table with a one-line purpose each.
4. Add a section documenting the gate: the defect and its grep evidence, the three precedent notes applied, the seam between script and judgement, the `DROPPED` rule and its consequence for scope narrowing, and the four things this does NOT close.
5. Update the Skill Routing / verification descriptions where Layer 2 is described.
6. Bump the version in `.claude-plugin/plugin.json` to `1.27.0` and update the version footer in `CLAUDE.md`.
7. Note in the phase report that the `gaspol-one` marketplace entry is a separate repository and was **not** updated from here.
8. Run the full suite: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`.
9. Commit: `docs(IDS-18): release 1.27.0 — the spec link of the chain is guarded`.

**Verification:**
- [ ] both scripts appear in the Architecture table
- [ ] the new section names all four not-closed items from the spec
- [ ] `.claude-plugin/plugin.json` and the `CLAUDE.md` footer state the same version
- [ ] full suite green: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`
- [ ] `bash tests/ticket-scripts/test-skill-frontmatter.sh` exits 0
- [ ] the marketplace deferral is stated in the phase report, not silently skipped
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
