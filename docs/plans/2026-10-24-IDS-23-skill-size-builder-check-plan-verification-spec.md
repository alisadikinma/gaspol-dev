**Ticket:** IDS-23

# Skill size ceiling + builder check + phase-specific verification — Design Spec

## Why

Three items: two from reading `superpowers` v7.0.1 against gaspol-dev, batched into one ticket (same
subsystem, `skills/`; Batch Gate: one piece of work).

**Item 1 — a real defect.** After `/compact`, Claude Code re-attaches each invoked skill cut off
at 20,000 characters (superpowers #2481). Everything past the cut is gone for the rest of the
session unless the agent re-reads the file. In superpowers one skill lost its round cap that way
and ran 18 fix rounds. Measured on gaspol-dev `main` (bytes, `wc -c`):

| Skill | Bytes | Over 20,000 |
|---|---|---|
| gaspol-verify | 34,416 | 14,416 |
| gaspol-plan | 30,530 | 10,530 |
| gaspol-parallel | 29,397 | 9,397 |
| gaspol-execute | 29,286 | 9,286 |
| gaspol-brainstorm | 26,337 | 6,337 |
| gaspol-finish | 21,191 | 1,191 |

Six skills, not seven (an earlier count included the `total` line). `gaspol-execute` was trimmed to
25.1 KB in v1.16 and has grown back to 29.3 KB: nothing guards the size. This is the same defect
shape the repository has fixed seven times: a rule in prose, no machine enforcing it.

**Item 2 — a weaker gate.** `gaspol-brainstorm` Phase 6 "spec self-review" has the author scan its
own spec for placeholders, contradictions, ambiguity and scope. An author cannot see the gap they
filled in their head. superpowers v7.0.0 replaced it with a *builder check*: a fresh subagent reads
the design as the person who must build it, cannot ask the author, and reports only the questions
it would still need answered.

## Ordering constraint

IDS-22 (`ids-22-parallel-waves`, released 1.31.0 on its own branch, not yet merged) changes
`gaspol-plan` (to 34,218 bytes), `gaspol-parallel` (30,057) and `gaspol-auto`. Two of the six files
are therefore moving. **Decision (owner): IDS-22 merges first; this ticket's trimming phases start
after IDS-22 merges and this branch is rebased onto the updated `main`.** Version becomes 1.32.0. Sizes in this
spec are `main` today; the plan re-measures after the rebase and the numbers above are a baseline,
not a promise.

## Design

### Part A — size ceiling

**Rule.** Truncation happens at the end of the file. Every gate, Iron Law and BLOCKING condition
stays in the `SKILL.md` body. Only detail moves to `skills/<name>/references/`: worked examples,
long tables, report formats, historical rationale. In its place, one pointer line:
`Read references/<file>.md when <step>`.

**What may happen to a gate (owner decision).** Many tables are gates themselves: the
`design-artifact:` four states, the `regression-test:` / `spec-fidelity:` / `blast-radius:` line
contracts, the exit 0/1/3/4 tables. A phase may (a) tighten the wording of a gate and (b) move its
state table, line-format contract and examples to `references/`. It may **not** remove the
obligation: each gate leaves one sentence in `SKILL.md` stating the condition and the consequence
("BLOCKING when X"). Precedent: the v1.16 `gaspol-execute` trim, "words cut, obligations kept". No
skill is split in this ticket.

**Target.** Under 18,000 bytes per `SKILL.md` (2 KB headroom; a target of 19,999 cracks again on the
next edit). Fallback if a skill cannot reach 18,000 under the rule above: under 20,000, with the
reason written in the ledger. If a skill cannot reach 20,000 under the rule above, the phase
**stops and asks the owner**; it never moves an obligation out of the body to make the test pass.

**Guard for the sentence rule.** Each phase lists, before it moves anything, the gates in that
skill (name + the one obligation sentence it keeps). A test asserts each listed sentence is still in
`SKILL.md`. Without that list, "kept one sentence" is unverifiable.

**Tests (both new, no exemption list).**

1. `tests/ticket-scripts/test-skill-size.sh` — fails for any `skills/*/SKILL.md` of 20,000 bytes or
   more. Positive control: a synthetic 20,001-byte file must fail, a 19,999-byte file must pass.
   Measures bytes (stricter than characters for non-ASCII).
2. `tests/ticket-scripts/test-skill-references.sh` — every `references/<file>` named in a
   `SKILL.md` exists, and every file under a skill's `references/` is named by that skill's
   `SKILL.md` (no orphans; `gaspol-write-skill` shipped three).

**Existing tests.** Each of the six skills is read by 6 to 9 existing tests that match text in
`SKILL.md`. Moving text breaks them. Every phase runs the full `tests/ticket-scripts/*.sh`. A test
that looks for text that moved is repointed to read `SKILL.md` **and** that skill's `references/`.
No assertion is deleted or weakened; where a gate name must be asserted, it stays in `SKILL.md`.

**Frontmatter.** `test-skill-frontmatter.sh` must stay green; `references/` files carry no
frontmatter.

### Part B — builder check

**Replaces** the Phase 6 "spec self-review" bullet entirely (owner decision). Flow, architectural
path only (the only path that writes a spec):

1. After the spec file is written, dispatch one fresh subagent: `general-purpose`, **`model:
   "opus"`** written at the call site (owner decision; the check judges a spec, same tier as
   `spec-reviewer`). It receives only the prompt in `references/builder-check-prompt.md` with
   `[DOMAIN]` and `[DOCUMENT_PATH]` filled. No conversation context.
2. It replies with the questions it would still need answered, ranked, each with why the answer
   changes the plan; or exactly `nothing important left`.
3. The orchestrator answers what the spec or CLAUDE.md already answers and fixes the spec inline,
   decides minor points itself and marks them as its own decisions, and brings questions that
   change what gets built to the owner in **one** `AskUserQuestion`.
4. **One round.** No re-dispatch loop, per `skills/_shared/fix-loop.md`'s bound.
5. The owner then reads the written spec, as today, before `gaspol-plan`.

**Model gate.** `model-gate` accepts only `model-tier: judge|exec` and reads it from the file that
holds the `model:` line, so `model-tier: opus` would be ignored and the new dispatch would return
exit 3 (UNKNOWN). Decision (builder-check finding, verified against `model-gate` lines 80-91):
`gaspol-brainstorm` is a judging skill under the model rule, so `skills/gaspol-brainstorm/SKILL.md`
carries a `model-tier: judge` line next to the `model: "opus"` dispatch, and
`references/builder-check-prompt.md` carries the same line. `model-gate` itself is **not** changed.
`model-gate` must exit 0 on the branch.

**Test.** `tests/ticket-scripts/test-builder-check.sh`: Phase 6 names the dispatch, the model
`opus`, and the `nothing important left` exit; the old self-review sentence is gone; the prompt file
exists and declares `model-tier: judge`; and a live run of `model-gate` on this repository exits 0
(a gate green only on synthetic trees proves nothing, per `test-model-gate.sh`). A positive control
proves the assertion can fail.

**Scope creep (owner request, kept).** The old self-review checked scope; dropping it would lose
that. `references/builder-check-prompt.md` adds one instruction beyond the superpowers original:
*also list any part of the document that looks unnecessary for its stated goal, one line each, with
why.* The orchestrator treats these like the other questions: answer, cut from the spec, or take
to the owner in the same single `AskUserQuestion`. `test-builder-check.sh` asserts the line is in
the prompt.

### Part C — plan Verification blocks carry only phase-specific checks

**Finding (verified):** `skills/gaspol-plan/SKILL.md` "Verification Criteria per Phase" (lines
373-383 on `main`) makes every phase's `**Verification:**` block carry five lines. Four are the
same in every phase: `static:` and `unit:` copied from `detect-stack`, "Component renders with real
data from [source]", "No placeholder/TODO comments in new code". Only the last,
`[specific functional check for this phase]`, is specific. The generic ones are already executed by
`gaspol-execute`'s Verification Loop and `gaspol-verify` Layer 3. Lines 391-405 copy the
`detect-stack` output into every phase so the plan is self-contained for an executor with no other
context (a fresh post-`/compact` session, an external executor). That reason is sound; repeating
the lines per phase is not needed to satisfy it.

**Change:**

1. The `detect-stack` output (`static:` / `lint:` / `unit:` / `build:`, or the `UNKNOWN` and
   no-markers lines the skill already defines) is written **once**, in a `**Verification
   commands:**` block in the plan header. Self-containment is kept: an executor reads the header.
2. A phase's `**Verification:**` block holds only checks specific to that phase, at least one.
   Example: "input `'   '` stored as `null`". The "real data from [source]" line counts as
   specific only when it names a concrete source; the placeholder-comment line is dropped
   (`gaspol-verify` Layer 3 owns it).
3. A phase whose block has only generic lines is INCOMPLETE. This is enforced by a **script**, not
   prose (a rule with no machine is the defect shape this repository keeps fixing): exit states on
   the existing contract (0 ok / 1 BLOCKING / 3 UNKNOWN / 4 not applicable). Whether it extends
   `plan-waves` (IDS-22, which already validates per-phase fields) or is a new script is decided in
   the plan, after the rebase.
4. **`task-brief` must carry the header block.** `skills/gaspol-parallel/scripts/task-brief`
   extracts ONE phase into a brief; an implementer sees only the brief. If the commands move to the
   header and the brief omits them, the implementer loses them. `task-brief` appends the header
   `**Verification commands:**` block to every brief, with a test.

**Tests touched:** `test-ledger-template.sh` (extracts the ledger template; the ledger copies each
phase's Verification block verbatim, so ledgers get shorter) and `test-task-brief.sh` read this
format and are repointed, not weakened. New assertions: header block present in the plan template;
the per-phase template no longer carries the generic lines; the lint script's states (positive
control: a phase with only generic lines must exit 1).

**Gives up:** a reader who opens one phase out of context without the header misses the commands.
`task-brief` covers the subagent path; a human or external executor reading a lone phase does not
get that cover.

## What this gives up

- **Scope-creep check is weaker, not gone.** One prompt line asks the reader to flag what looks
  unnecessary. A builder can say a part seems unneeded; it cannot know a feature nobody asked for
  that sounds reasonable. The owner's read of the spec remains the final guard.
- **Detail is one read away.** An agent that ignores a pointer works without that detail. Gates stay
  in the body, so what is lost is depth, never an obligation.
- **The builder check is model judgement, not a guarantee.** A question the reader never thinks of
  never appears. It runs on the architectural path only.
- **Opus cost per brainstorm:** one extra dispatch that reads a single spec file.

## Data Integration Map

Not applicable: no data display, no runtime integration. All changes are prose, tests and one
prompt file inside `skills/` and `tests/`.

## Blast radius

`skills/gaspol-parallel/scripts/task-brief`, the plan-verification lint (new script or
`plan-waves`), `skills/gaspol-{verify,plan,parallel,execute,brainstorm,finish}/SKILL.md`, new
`skills/gaspol-*/references/*.md`, `skills/gaspol-brainstorm/references/builder-check-prompt.md`,
repointed assertions in existing `tests/ticket-scripts/*.sh`, two new tests plus
`test-builder-check.sh`, `CLAUDE.md`, plugin README and `gaspol-one` version table,
`.claude-plugin/plugin.json`.

## Not closed here

- `gaspol-auto` (13 KB) and the other skills under 20,000 bytes are untouched; the ceiling test
  protects them from now on but does not shrink them.
- The mid-run edit guard (a skill that grows past 20,000 between releases) is the new test, which
  runs in the suite; nothing blocks a commit if the suite is not run.
- **An agent that skips a `references/` pointer** works without that detail. The pointer sits at
  the step that needs it and the obligation stays in the body, but no mechanism forces the read.
  This is runtime behaviour, not something a file test can prove.
- **Builder check is model judgement.** A question the reader never thinks of never appears.
- Other superpowers items (Review Focus and Interfaces in plans, `Ruling:` ledger entries, session
  diagnosis) are not part of this ticket.
