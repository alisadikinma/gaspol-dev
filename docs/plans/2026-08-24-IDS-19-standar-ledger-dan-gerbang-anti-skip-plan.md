> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-19.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` boxes, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat. Every file path, contract, config key, and convention it needs is written here **verbatim**.

**Ticket:** IDS-19
**Ledger:** .gaspol/progress/PROGRESS-IDS-19.md
**Spec:** docs/plans/2026-08-24-IDS-19-standar-ledger-dan-gerbang-anti-skip-spec.md

## Goal

Make the ledger format IND-117 grew by hand into the gaspol standard, and stop the ledger from
being skipped. Measured across all 18 IDS tickets in this repository, the ledger exists if and
only if a plan file exists — IDS-3, IDS-5, IDS-9 and IDS-15 have neither. The cause is that the
ledger has exactly **one creator**, `gaspol-plan` step 7, and **no reader that checks it exists**.
Two halves close it: a richer template whose content is copied from the plan rather than authored
fresh, and a second creator plus a deterministic gate. This is the seventh instance in this
repository of the same defect shape — a rule stated in prose with nothing reading the record the
rule produces (IDS-7, IDS-8, IDS-12, IDS-13, IDS-14, IDS-18 were the first six).

## Architecture Context

Read from this repository's `CLAUDE.md` and the files themselves — all line numbers verified at
plan-write time against commit `331fbca`:

- **`skills/gaspol-plan/SKILL.md`** — "Plan Document Header" step 7 (line ~105) creates the
  ledger; the "Progress Ledger Format" section (line ~144) holds the template; the per-phase
  template lives at lines ~217-238 and already emits a numbered `**Steps:**` block plus a
  `**Verification:**` block **already written as `- [ ]` checkboxes**.
- **`skills/gaspol-execute/SKILL.md`** — Step 3 (line ~101) has an "Initialize only as a fallback"
  branch that defers to `gaspol-plan`'s format section.
- **`skills/gaspol-debug/SKILL.md`** — Phase 1 starts at line ~25 with a Batch Gate; Phase 4
  step 1 (line ~145) tells the agent to write a `regression-test:` line into a ledger the debug
  path never creates. `grep -n next-ticket skills/gaspol-debug/SKILL.md` returns **zero hits**.
- **`skills/gaspol-verify/SKILL.md`** — Layer 1 "Regression Gate" block at lines ~125-140 is the
  insertion model: an anchored `"$CLAUDE_PLUGIN_ROOT/..."` invocation with a `: "${CLAUDE_PLUGIN_ROOT:?...}"`
  guard above it, followed by prose naming each exit code.
- **`skills/gaspol-verify/scripts/spec-pointer`** — the exit-contract model (0 / 3 / 4, exit 1
  unused), path resolution against `git rev-parse --show-toplevel` and never `$PWD`.
- **`skills/gaspol-verify/scripts/blast-radius-diff`** — carries the ignore list this plan reuses
  verbatim at its lines 50-51.
- **`skills/gaspol-execute/scripts/scan-active-ledgers`** — reads a ledger's **last non-empty
  line** to decide active-vs-done. This is why `## Log` must stay the last block.
- **`tests/ticket-scripts/`** — 44 shell tests, run with
  `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. No API calls.
- **`tests/ticket-scripts/test-kb-no-hardcoded-path.sh`** — gates anchored `$CLAUDE_PLUGIN_ROOT`
  invocation. IDS-18 widened it from `kb-root` alone to three scripts; this plan widens it to four.
- **`tests/ticket-scripts/test-scripts-executable.sh`** — asserts scripts are committed `100755`.

## Tech Stack

POSIX-ish bash with `set -euo pipefail`, stdlib only, no dependencies. Markdown for every skill
file. Tests are plain bash scripts with an `assert`-style helper, matching the 44 already in
`tests/ticket-scripts/`.

`skills/gaspol-execute/scripts/detect-stack .` exits **0 and prints nothing** for this
repository — there are no stack markers (no `package.json`, no `pyproject.toml`, no `go.mod`).
Per the plan skill's own rule, every Verification block below therefore carries
`detect-stack: no stack markers for this project — verification is plan-declared only` plus the
real commands. **Do not write `npm test` or `npx tsc` into any phase of this plan.**

## Two portability traps, named because this repository has been bitten by both

1. **BSD `sed` rejects `\|` alternation in a basic regex.** IDS-18's `blast-radius-diff` parser
   silently found **zero** paths because of it and reported "the plan declares no files" on a plan
   full of them. Use `grep -E` or separate `sed` expressions; never `\|`.
2. **`chmod +x` must run BEFORE `git add`.** IDS-18's Phase A files were committed `100644`
   because the order was reversed; `test-scripts-executable.sh` caught it. Every phase that
   creates a script below has the `chmod` as an explicit numbered step ahead of the commit.

## Data Integration Map

Nothing here reads runtime data — the "data sources" are files and scripts. The contract is the
same: **Yes** means use it as it is, **No** means build the real thing, never a stub.

| Feature | Data Source | Reader/Caller | Exists? | Action |
|---|---|---|---|---|
| Ticket from a plan header | `**Ticket:** <ID>` line in `docs/plans/*-plan.md` | `ledger-gate` | Yes | Parse it; `spec-pointer` already parses `**Spec:**` the same way |
| Ticket from a branch name | `git rev-parse --abbrev-ref HEAD` | `ledger-gate` | Yes | Match `[A-Z][A-Z0-9]*-[0-9]+` |
| Changed-file list | `git diff --name-only <BASE>..HEAD` | `ledger-gate` | Yes | Use directly |
| Ignore list (what is not code) | `IGNORE_PREFIXES` / `IGNORE_EXACT`, `blast-radius-diff` lines 50-51 | `ledger-gate` | Yes | **Copy the values verbatim** into `ledger-gate`; see Phase A step 5 for why it is copied, not sourced |
| Ledger file | `.gaspol/progress/PROGRESS-<TICKET>.md` | `ledger-gate`, `scan-active-ledgers` | Yes | Read; never write |
| Legacy ledger | `.gaspol/progress/<slug>.md`, `.gaspol/progress.md` | `ledger-gate` | Yes | Accept when its body carries `**Ticket:** <TICKET>` |
| Repo root | `git rev-parse --show-toplevel` | `ledger-gate` | Yes | Resolve every path against it, **never `$PWD`** |
| Phase steps for the ledger checklist | the plan's own `**Steps:**` + `**Verification:**` blocks | `gaspol-plan` step 7 | Yes | Copy verbatim into the ledger |
| The gate script itself | `skills/gaspol-verify/scripts/ledger-gate` | `gaspol-verify` Layer 1 | **No** | Build it (Phase A) |
| Gate tests | `tests/ticket-scripts/test-ledger-gate.sh` | the suite loop | **No** | Build it (Phase A) |
| Template tests | `tests/ticket-scripts/test-ledger-template.sh` | the suite loop | **No** | Build it (Phase C) |

## The `ledger-gate` contract — written here in full so the executor needs no other file

```text
Usage:  ledger-gate <BASE>
        ledger-gate --self-test

$1      BASE git ref. The diff examined is <BASE>..HEAD.
stdout  ONE "ledger-gate: <verdict>" line on EVERY exit path, so a caller can
        capture the state unconditionally for a ledger line. stdout rather than
        stderr because this script has NO bare-value contract on stdout to
        protect — it follows regression-gate and blast-radius-diff, not
        spec-pointer (whose stdout carries a bare path and whose report is
        therefore on stderr). That split is deliberate and already recorded in
        spec-pointer's own header; a helper that captures "a gate script's
        report line" uniformly will be wrong about one of them.

exit 0  ledger found and structurally valid.
exit 1  BLOCKING — a ticket resolved, the branch changed code, and no ledger
        exists for that ticket.
exit 3  UNKNOWN — STOP and ask. Covers: BASE is not a valid ref; no BASE given;
        two plans in the diff naming different tickets; the ledger exists but is
        empty, or has no "## Checklist" line, or has a "## " heading after
        "## Log"; the ledger exists but cannot be read.
exit 4  not applicable — NOT a failure, and never counted as a pass. Two
        situations, told apart by the reason text:
          "ledger-gate: N/A — no ticket on this branch"
          "ledger-gate: N/A — docs-only branch, no code commits"
```

**Why exit 3 is not merged into exit 1.** A malformed ledger must degrade to neither "missing" nor
"fine". A ledger carrying a block below `## Log` still exists, so `scan-active-ledgers` reads the
wrong last line and reports the ticket's state incorrectly — strictly worse than an absent file,
which at least reports nothing.

**Why exit 4 exists at all.** Without it every typo fix on an unticketed branch gets blocked, the
gate cries wolf, and somebody switches it off — the same reasoning that made `blast-radius-diff` a
WARN rather than a BLOCK. The reason after the dash is **mandatory**; a bare `N/A` is `(if
possible)` wearing a new name.

**What counts as a code commit.** A changed path counts as code unless it is on the ignore list:

```text
IGNORE_PREFIXES=".gaspol/ docs/plans/ .git/"
IGNORE_EXACT="CLAUDE.md package-lock.json pnpm-lock.yaml yarn.lock composer.lock poetry.lock Cargo.lock"
```

Markdown is **not** on that list, deliberately. In a skills repository a `skills/*.md` file IS the
executed surface — the same reasoning `CLAUDE.md` records for running `/security-review` on
markdown diffs. Letting markdown count as "docs" would hand this repository a permanent exemption
from its own gate.

**Ticket resolution order** (first hit wins, deterministic, never inferred by a model):

1. a `**Ticket:** <ID>` line inside any `docs/plans/*-plan.md` present in `git diff --name-only <BASE>..HEAD`;
2. failing that, `[A-Z][A-Z0-9]*-[0-9]+` matched against `git rev-parse --abbrev-ref HEAD`;
3. failing that, no ticket → exit 4.

Two plans in the diff naming **different** tickets → exit 3, never pick the first silently.
Two plans naming the **same** ticket is fine — exit 0/1 as normal.

**Ledger resolution for a resolved `<TICKET>`:**

1. `.gaspol/progress/PROGRESS-<TICKET>.md` — the current form;
2. failing that, any `.gaspol/progress/*.md` or `.gaspol/progress.md` whose body contains
   `**Ticket:** <TICKET>` — the legacy forms, still read.

## The new ledger template — written here in full

`gaspol-plan` step 7 writes this. The Checklist body is **copied from the plan**, not authored:
the phase's numbered `**Steps:**` become checkboxes, then its `**Verification:**` block is
appended verbatim (it is already `- [ ]`).

```markdown
# PROGRESS — IDS-19: standar ledger dan gerbang anti-skip

**Ticket:** IDS-19
**Plan:** docs/plans/2026-08-24-IDS-19-standar-ledger-dan-gerbang-anti-skip-plan.md
<!-- the example's Spec line is indented so it is not mistaken for THIS plan's own
     header: spec-pointer reads any line starting `**Spec:**` and refuses when it
     finds two, which is what it did here -->
  **Spec:** docs/plans/2026-08-24-IDS-19-standar-ledger-dan-gerbang-anti-skip-spec.md

## Pre-flight

| Gate | Result |
|---|---|
| Git clean | [PASS/FAIL — sha] |
| Baseline suite | [PASS/FAIL — command, counts] |
| detect-stack | [output, or "no stack markers"] |

## Keputusan saat jalan

(kosong sampai ada keputusan; tiap butir: apa, siapa yang memutuskan, tanggal)

## Checklist

### [ ] Phase A: script ledger-gate
- [ ] <step 1 of Phase A, verbatim from the plan>
- [ ] <step 2 …>
- [ ] <the plan's Verification lines for Phase A, verbatim>

### [ ] Phase B: …

## Phase log

| Phase | Status | Commit |
|---|---|---|

## Utang terbuka

(kosong sampai ada yang sengaja ditinggal; tiap butir bernama)

## Log
- 2026-08-24 plan ditulis — NEXT: Phase A
```

**Four state markers, unchanged, now carried on the phase heading:**

| Marker | Meaning | Condition |
|---|---|---|
| `[ ]` | todo | — |
| `[>]` | in progress | set when the phase starts |
| `[x]` | done | that phase's checks are green |
| `[~]` | cancelled / skipped | a short reason is MANDATORY on the heading + detail in the Log |

**Four mandatory sections**, all **above `## Log`**: `## Pre-flight`, `## Keputusan saat jalan`,
`## Phase log`, `## Utang terbuka`. Everything else IND-117's ledger grew — evidence-quality
notes, open items for a later phase, the plan-verifier round table, post-run gates, deploy steps,
leftovers found after close — is **added when it has content**, never as an empty heading. Nine
mandatory sections would be filled with "N/A", and an empty label reads as *checked and clear*.

**`## Log` stays the last block.** `scan-active-ledgers` reads the last non-empty line. The new
`###` sub-headings live **inside** `## Checklist`, above `## Log`, so its behaviour is untouched.

---

## Phase A: the `ledger-gate` script

**Estimated time:** 15 minutes

**Completeness ladder for this phase.** Happy path: a valid ledger resolves and exits 0. Error
paths that can actually happen: invalid/absent BASE, two plans naming different tickets,
unreadable ledger. Edge cases enumerated (each is a test case below): empty ledger file, ledger
with no `## Checklist`, a `## ` heading after `## Log`, `.gaspol/progress/` absent entirely,
legacy ledger path, docs-only diff, unticketed branch, lowercase/mixed-case branch names that must
**not** match the ticket pattern. Observability: the single `ledger-gate:` report line on every
exit path. Rung 6 (the WHY comment): the script header explains why exit 3 is not exit 1.

**Files:**
- Create: `skills/gaspol-verify/scripts/ledger-gate`
- Create: `tests/ticket-scripts/test-ledger-gate.sh`

**Steps:**
1. Write failing test for `ledger-gate` resolving a ticket from a plan header and exiting 0 when the ledger exists. Expected error: `bash: skills/gaspol-verify/scripts/ledger-gate: No such file or directory`
2. Run `bash tests/ticket-scripts/test-ledger-gate.sh`, confirm it fails for that reason and not a syntax error in the test itself
3. Write the script header comment block: the full contract above, plus the two paragraphs explaining why exit 3 is not exit 1 and why exit 4 exists
4. Implement `set -euo pipefail`, `--self-test`, and repo-root resolution via `git rev-parse --show-toplevel` (never `$PWD`) — resolve it once, before anything can `cd`
5. Implement `is_ignored()` with `IGNORE_PREFIXES` / `IGNORE_EXACT` **copied verbatim** from `blast-radius-diff` lines 50-51. Copy rather than source: sourcing a sibling script makes each gate's behaviour depend on the other's load order and turns one script's bug into two. Add a comment naming `blast-radius-diff` as the origin so the two can be diffed by hand
6. Implement ticket resolution (plan header, then branch name, then none), using `grep -E` and never `sed` `\|` alternation
7. Implement ledger resolution including the two legacy paths
8. Implement structural validation: non-empty, has a `## Checklist` line, and no `## ` heading appears after `## Log`
9. Run `bash tests/ticket-scripts/test-ledger-gate.sh`, confirm every case passes
10. Run `bash skills/gaspol-verify/scripts/ledger-gate --self-test`, confirm exit 0
11. `chmod +x skills/gaspol-verify/scripts/ledger-gate` — **before** `git add`, or it commits `100644` and `test-scripts-executable.sh` fails
12. Run the full suite: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`
13. Commit: "feat(IDS-19): ledger-gate — the ledger finally has a reader"

**The test cases `test-ledger-gate.sh` must contain** (each builds a throwaway git repo under
`mktemp -d` and removes it; none touches the real repository):

| # | Setup | Expected |
|---|---|---|
| 1 | plan in diff with `**Ticket:** IDS-99`, ledger `PROGRESS-IDS-99.md` valid | exit 0 |
| 2 | same, ledger absent, a `.sh` file changed | exit 1 |
| 3 | branch `IDS-99-foo`, no plan in diff, ledger valid | exit 0 |
| 4 | branch `feature/cleanup`, no plan in diff | exit 4, reason `no ticket on this branch` |
| 5 | ticket resolves, only `CLAUDE.md` and `docs/plans/x.md` changed | exit 4, reason `docs-only branch, no code commits` |
| 6 | ticket resolves, only a `skills/foo/SKILL.md` changed | exit 1 — markdown IS code here |
| 7 | ledger exists, 0 bytes | exit 3 |
| 8 | ledger exists, no `## Checklist` | exit 3 |
| 9 | ledger exists with `## Utang terbuka` **after** `## Log` | exit 3 |
| 10 | two plans in diff naming IDS-98 and IDS-99 | exit 3 |
| 11 | two plans in diff both naming IDS-99 | exit 0 |
| 12 | `.gaspol/progress/` does not exist at all, ticket resolves, code changed | exit 1, no crash |
| 13 | legacy `.gaspol/progress/some-slug.md` whose body has `**Ticket:** IDS-99` | exit 0 |
| 14 | legacy shared `.gaspol/progress.md` whose body has `**Ticket:** IDS-99` | exit 0 |
| 15 | BASE is `nonexistent-ref` | exit 3 |
| 16 | no argument at all | exit 3 |
| 17 | branch `ids-99-lowercase` | exit 4 — the pattern is uppercase-anchored, so this must NOT resolve a ticket |
| 18 | every exit path above | stdout carries exactly one line starting `ledger-gate: ` |

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-ledger-gate.sh` exits 0 with all 18 cases passing
- [ ] `bash skills/gaspol-verify/scripts/ledger-gate --self-test` exits 0
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `git ls-files -s skills/gaspol-verify/scripts/ledger-gate` shows mode `100755`
- [ ] `grep -cF '\|' skills/gaspol-verify/scripts/ledger-gate` returns 0 — no BSD-hostile alternation
- [ ] No placeholder/TODO comments in new code

---

## Phase B: wire the gate into `gaspol-verify` Layer 1

**Estimated time:** 10 minutes

**Completeness ladder for this phase.** Happy path: Layer 1 invokes the gate anchored and records
a `ledger:` line. Error paths: `CLAUDE_PLUGIN_ROOT` unset must stop loudly, not fall back to the
working directory. Edge cases: all four exit codes need prose telling the reader what to do. Rung
5 (observability): the recorded `ledger:` line is the durable evidence. Rung 3 note: there is no
input space to enumerate here — this phase edits prose, and its edge cases ARE the four exit
codes, all four covered.

**Files:**
- Modify: `skills/gaspol-verify/SKILL.md` (Layer 1, immediately after the "Regression Gate" block at lines ~125-140)
- Modify: `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`

**Steps:**
1. Write failing test for `test-kb-no-hardcoded-path.sh` covering `ledger-gate`. Expected error: assertion message `ledger-gate: expected >=1 anchored invocation, found 0`
2. Run `bash tests/ticket-scripts/test-kb-no-hardcoded-path.sh`, confirm it fails for that reason
3. Widen that test's script list from three entries to four, adding `ledger-gate`; keep its **per-script** positive control (a combined count stays healthy on `kb-root`'s eight matches while a new pattern matches nothing — the exact trap IDS-18 recorded)
4. Add a `### Ledger Gate` block to `gaspol-verify` Layer 1, modelled line-for-line on the Regression Gate block above it: the `: "${CLAUDE_PLUGIN_ROOT:?...}"` guard, then `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/ledger-gate" <BASE>`
5. Write the prose naming all four exits and what each obliges: 0 pass; 1 **BLOCKING**; 3 **STOP and ask**; 4 not applicable, **never counted as a pass**, reason mandatory
6. Add `ledger:` to Layer 1's evidence format block, beside `live-app-check:` and the regression verdict
7. Run `bash tests/ticket-scripts/test-kb-no-hardcoded-path.sh`, confirm it passes
8. Run the full suite
9. Commit: "feat(IDS-19): gaspol-verify Layer 1 reads the ledger gate"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-kb-no-hardcoded-path.sh` exits 0
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `grep -c 'skills/gaspol-verify/scripts/ledger-gate' skills/gaspol-verify/SKILL.md` returns >= 1, and every occurrence is prefixed `"$CLAUDE_PLUGIN_ROOT/`
- [ ] All four exit codes (0, 1, 3, 4) appear by number in the new Layer 1 prose
- [ ] No placeholder/TODO comments in new code

---

## Phase C: the new ledger template in `gaspol-plan`

**Estimated time:** 15 minutes

**Completeness ladder for this phase.** Happy path: step 7 copies Steps + Verification per phase.
Error paths: a plan phase with no Verification block (the plan skill already refuses that — the
ledger writer must not invent one to fill the gap, it must stop). Edge cases: a `[~]` cancelled
phase still needs its reason on the heading; a plan with a single phase; a phase whose Steps
contain a colon or backtick that must survive the copy unaltered. Observability: the `## Pre-flight`
table is what a later reader uses to tell a pre-existing red baseline from one this branch caused.

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md` — "Progress Ledger Format" section (line ~144) and "Plan Document Header" step 7 (line ~105)
- Create: `tests/ticket-scripts/test-ledger-template.sh`

**Steps:**
1. Write failing test for the template carrying the four mandatory section headings and keeping `## Log` last. Expected error: assertion message `missing mandatory section: ## Pre-flight`
2. Run `bash tests/ticket-scripts/test-ledger-template.sh`, confirm it fails for that reason
3. Replace the "Progress Ledger Format" template block with the full template written out above in this plan
4. Add the prose stating that the Checklist body is copied from the plan's `**Steps:**` and `**Verification:**` blocks, and that a phase with no Verification block means STOP and ask — never invent one
5. Add the prose stating the four mandatory sections, and that every other section is added only when it has content
6. Keep the four-marker table and the "`## Log` is always the last block" rule verbatim — they are unchanged rules, restated not rewritten
7. Rewrite step 7 to say "a `### [ ] Phase <N>: <name>` sub-block per phase, whose body is that phase's Steps as checkboxes followed by its Verification block verbatim", replacing "a `## Checklist` line for EVERY phase"
8. Run `bash tests/ticket-scripts/test-ledger-template.sh`, confirm it passes
9. Run the full suite
10. Commit: "feat(IDS-19): ledger checklist is copied from the plan, not summarised"

**The assertions `test-ledger-template.sh` must contain**, all read against
`skills/gaspol-plan/SKILL.md`:

| # | Assertion |
|---|---|
| 1 | all four mandatory headings appear: `## Pre-flight`, `## Keputusan saat jalan`, `## Phase log`, `## Utang terbuka` |
| 2 | `## Log` appears **after** all four in the template block |
| 3 | the four-marker table still lists `[ ]`, `[>]`, `[x]`, `[~]` |
| 4 | the `[~]` row still says a reason is MANDATORY |
| 5 | the "`## Log` is ALWAYS the last block" rule is still present |
| 6 | step 7 no longer says "a `## Checklist` line for EVERY phase" |
| 7 | step 7 names both `**Steps:**` and `**Verification:**` as the copy source |
| 8 | the template contains a `### [ ] Phase ` sub-heading example |

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-ledger-template.sh` exits 0 with all 8 assertions passing
- [ ] `bash tests/ticket-scripts/test-scan-active-ledgers.sh` exits 0 — the `## Log`-last contract still holds
- [ ] `bash tests/ticket-scripts/test-skill-frontmatter.sh` exits 0 — `gaspol-plan` still parses as a skill
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] No placeholder/TODO comments in new code

---

## Phase D: `gaspol-debug` becomes the second ledger creator

**Estimated time:** 10 minutes

**Completeness ladder for this phase.** Happy path: a bug with no ledger gets one at Phase 1.
Error paths that can actually happen: `next-ticket` exit 2 (no `## gaspol Ticket Counter` section
in the target CLAUDE.md) must ask for a prefix, never invent one; a ledger that already exists must
be left alone, not overwritten. Edge cases: a batch of N defects mints **one** ticket, because the
Batch Gate directly above already ruled; work on a branch that already has a plan-created ledger.
Observability: this is what makes `regression-gate` able to find its `regression-test:` line at
all — the phase's real payoff.

**Files:**
- Modify: `skills/gaspol-debug/SKILL.md` — Phase 1, immediately after the Batch Gate block (lines ~27-40)
- Modify: `tests/ticket-scripts/test-regression-gate.sh` (add one assertion; do not restructure it)

**Steps:**
1. Write failing test for `gaspol-debug` Phase 1 instructing ledger creation. Expected error: assertion message `gaspol-debug: expected a ledger-creation step in Phase 1, found none`
2. Run `bash tests/ticket-scripts/test-regression-gate.sh`, confirm it fails for that reason
3. Add a "Ledger — created here, because nothing else will" step to Phase 1, stating: if `.gaspol/progress/PROGRESS-<TICKET>.md` exists, leave it alone; otherwise mint the ticket with `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-execute/scripts/next-ticket" <target CLAUDE.md>` and create the ledger in `gaspol-plan`'s format
4. Write the exit-2 branch explicitly: no `## gaspol Ticket Counter` section → **AskUserQuestion** for a prefix, never a guessed default
5. Write one sentence naming the bug this closes: Phase 4 step 1 has been telling the agent to write `regression-test:` into a ledger this path never created, so `regression-gate` returned exit 3 as its normal outcome on the path it was built for
6. State that one batch mints one ticket — the Batch Gate immediately above already ruled, and this step never re-opens it
7. Run `bash tests/ticket-scripts/test-regression-gate.sh`, confirm it passes
8. Run the full suite
9. Commit: "fix(IDS-19): the debug path creates the ledger its own Phase 4 writes to"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-regression-gate.sh` exits 0
- [ ] `bash tests/ticket-scripts/test-batch-gate.sh` exits 0 — the Batch Gate ruling is untouched
- [ ] `bash tests/ticket-scripts/test-skill-frontmatter.sh` exits 0
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `grep -c 'next-ticket' skills/gaspol-debug/SKILL.md` returns >= 1 and every occurrence is prefixed `"$CLAUDE_PLUGIN_ROOT/`
- [ ] No placeholder/TODO comments in new code

---

## Phase E: the two loose ends

**Estimated time:** 8 minutes

**Completeness ladder for this phase.** Happy path: `gaspol-execute`'s fallback initializer and
`gaspol-worktree`'s teardown both point at the truth. Error paths: none new — both edits are
pointers. Edge cases: an older ledger in the flat one-line-per-phase form must still be READ
without complaint; only NEW ledgers use the new shape. Rungs 2, 3 and 5 are **not applicable**
here, and the reason is written down rather than left blank: this phase adds no branch, no input
parsing and no runtime — it only redirects two references.

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md` — Step 3, "Initialize only as a fallback" (line ~101)
- Modify: `skills/gaspol-worktree/SKILL.md` — the teardown section

**Steps:**
1. Write failing test for backward compatibility being stated in `gaspol-execute` Step 3. Expected error: assertion message `gaspol-execute: expected the old flat ledger form to be named as still-readable, found no mention`
2. Run `bash tests/ticket-scripts/test-execute-trim.sh`, confirm it fails for that reason
3. Update Step 3's fallback prose to name the new sub-block shape, and to state explicitly that an older flat one-line-per-phase ledger is still READ unchanged — only new ledgers are written in the new shape
4. Add the `worktree-ledgers-are-ephemeral` reminder to `gaspol-worktree`'s teardown: `.gaspol/` is gitignored, so copy `.gaspol/progress/PROGRESS-<TICKET>.md` into the main checkout **BEFORE** `git worktree remove`, never after — IND-98's ledger had to be reconstructed from session context because it was done after
5. Run `bash tests/ticket-scripts/test-execute-trim.sh`, confirm it passes
6. Run the full suite
7. Commit: "docs(IDS-19): execute fallback and worktree teardown point at the new ledger shape"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-execute-trim.sh` exits 0 — every gate name and all three Iron Laws still present
- [ ] `bash tests/ticket-scripts/test-skill-frontmatter.sh` exits 0
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `gaspol-worktree`'s teardown names the copy-before-remove order explicitly
- [ ] No placeholder/TODO comments in new code

---

## Phase F: documentation and release

**Estimated time:** 12 minutes

**Completeness ladder for this phase.** Happy path: `CLAUDE.md` gains a section and three
Architecture rows. Error paths: a version bumped in `plugin.json` but not in the marketplace repo
leaves the two disagreeing — named as a manual step, not silently skipped. Edge cases: the
Architecture table must gain a row for each of the three NEW files and no more. Rung 6: the
section states what the gate does NOT close, so nobody later reads it as a completeness guarantee.

**Files:**
- Modify: `CLAUDE.md` — new section, three Architecture rows, version and date
- Modify: `.claude-plugin/plugin.json` — version bump to 1.28.0

**Steps:**
1. Write failing test for `CLAUDE.md` documenting the ledger gate. Expected error: assertion message `CLAUDE.md: expected a ledger-gate section, found none`
2. Run `bash tests/ticket-scripts/test-ids8-docs.sh`, confirm it fails for that reason
3. Add Architecture rows for `skills/gaspol-verify/scripts/ledger-gate`, `tests/ticket-scripts/test-ledger-gate.sh` and `tests/ticket-scripts/test-ledger-template.sh`
4. Write the new `CLAUDE.md` section: the measured 4-of-18 evidence, the single-creator cause, both halves of the fix, and the four-state contract table
5. Write the "what this does NOT close" paragraph verbatim from the spec: the gate checks existence and shape and **never honesty**; the bounded brainstorm path still creates no ledger and lands on exit 4; `.gaspol/` stays gitignored; no back-fill for IDS-3/5/9/15, because a ledger written months later is fiction
6. Bump `.claude-plugin/plugin.json` to `1.28.0` and update `CLAUDE.md`'s version footer
7. Update `## gaspol Ticket Counter` — `Last ticket: IDS-19` (already bumped when the ticket was minted; confirm rather than re-bump)
8. Run `bash tests/ticket-scripts/test-ids8-docs.sh`, confirm it passes
9. Run the full suite
10. Commit: "docs(IDS-19): release 1.28.0 — the ledger has a standard and a reader"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-ids8-docs.sh` exits 0
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0 — all 46 scripts
- [ ] `.claude-plugin/plugin.json` reads `1.28.0` and `CLAUDE.md`'s footer matches
- [ ] `CLAUDE.md` carries the "what this does NOT close" paragraph
- [ ] No placeholder/TODO comments in new code

---

## Phase dependency order

Strictly sequential — **not** a candidate for `gaspol-parallel`:

```text
A (the machine)
  └─> B (wires the machine)
        └─> C (the template the machine checks)
              └─> D (second creator, writes that template)
                    └─> E (pointers to the template)
                          └─> F (docs describing all of it)
```

A must precede B because a wiring that names a non-existent script is the exact defect shape this
ticket exists to end. C must precede D because D writes the format C defines. F is last because it
describes what the others built.

## Out of scope

One line each, listed so nothing is absorbed silently:

- Back-filling ledgers for IDS-3, IDS-5, IDS-9, IDS-15.
- Making `gaspol-brainstorm`'s bounded path mint a ticket.
- Tracking `.gaspol/` in git.
- Grading ledger content honesty — the gate checks existence and shape only.
- Any change to `scan-active-ledgers` itself.

## Security note

No phase touches auth, secrets, user input, an API endpoint, payment, or sensitive data.
`/security-review` is therefore not auto-triggered by `gaspol-execute` Step 3.6 here. One rail
does apply and is written into Phase A: `ledger-gate` reads ledger and plan files and **compares**
their content — it never executes them and never interpolates their content into a command. The
`--self-test` output is a fixed literal, never constructed from an argument.
