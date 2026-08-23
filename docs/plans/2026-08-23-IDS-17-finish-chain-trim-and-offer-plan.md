> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-17.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end.** Update ONLY this file.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context**.

**Ticket:** IDS-17
**Ledger:** .gaspol/progress/PROGRESS-IDS-17.md
**Spec:** docs/plans/2026-08-23-IDS-17-finish-chain-trim-and-offer-spec.md

## Goal

Cut `gaspol-finish`'s mandatory chain from six steps plus a Step 0 preamble down to four
mandatory steps, move `/security-review` and `gaspol-learn` to recordless offers, and turn
finishing itself from an implied obligation into an explicit three-way offer presented at the
end of `gaspol-execute`, `gaspol-parallel` and `gaspol-auto`. A deferred finish leaves a ledger
cursor so `scan-active-ledgers` resurfaces it without any new machinery.

## Architecture Context

Pulled from this repository's `CLAUDE.md` and read directly from the files:

- `skills/gaspol-finish/SKILL.md` (450 lines) holds the chain. Step 0 sits above Step 1 and runs
  `detect-stack` plus `regression-gate`. Steps 1-6 are `gaspol-verify`, `plan-verifier`,
  `gaspol-review` Tier 1, `/security-review`, `gaspol-sync-docs`, `gaspol-learn`.
- `skills/gaspol-verify/SKILL.md` Layer 1 already runs both Step 0 commands: `detect-stack` at
  line 61, `regression-gate` at line 135 anchored as
  `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-debug/scripts/regression-gate"`.
- `skills/_shared/` already holds shared-text files read by several skills: `fix-loop.md`,
  `batch-gate.md`, `completeness-ladder.md`, `verification-loop.md`, `live-app-check.md`. The new
  `finish-offer.md` follows that established pattern exactly.
- `skills/gaspol-execute/scripts/scan-active-ledgers` prints one basename per ledger whose last
  `NEXT:` marker is not `DONE`. Reused as-is for the deferral reminder — no new code.
- Ledger format: `.gaspol/progress/PROGRESS-<TICKET>.md`, a `## Checklist` block above a
  `## Log` block that is ALWAYS the last block in the file.
- Three call sites end a ticket today: `skills/gaspol-execute/SKILL.md:516` (a downstream list,
  no choice offered), `skills/gaspol-parallel/SKILL.md:361` ("Run `gaspol-finish` to finalize"),
  `skills/gaspol-auto/SKILL.md:142` (a `[Proceed to gaspol-finish]` button).

## Tech Stack

Markdown skill files plus POSIX shell tests. `skills/gaspol-execute/scripts/detect-stack .`
prints **zero lines** for this repository — there are no language stack markers. The whole test
suite is therefore plan-declared:

```bash
for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done
```

Every phase's Verification block uses that command verbatim, plus the single new/changed test
file for that phase run on its own for a faster red/green loop.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-------------|----------|---------|--------|
| Finish offer text | `skills/_shared/finish-offer.md` | read by three SKILL.md files | **No** | Create it; it is the single source, never restated in a caller |
| Deferral reminder | `.gaspol/progress/PROGRESS-<TICKET>.md` `## Log` cursor | `skills/gaspol-execute/scripts/scan-active-ledgers` | Yes | Reuse — write `— NEXT: gaspol-finish — deferred: <reason>`, the script already surfaces it |
| Cheap-checks-first ordering | `gaspol-verify` Layer 1 | `detect-stack` + `regression-gate` | Yes | Reuse — Step 0 deleted, Layer 1 at chain position 1 preserves the ordering |
| Divergence record for `/security-review` | ADR under the resolved KB root | `gaspol-adr` skill | Yes | Invoke it; never hand-write an ADR file |
| Mandatory-chain contract | `tests/ticket-scripts/test-finish-*.sh` | `bash` | Yes | Rewrite assertions to the 4-mandatory + 2-offered contract |

Nothing in this plan is a placeholder. Every artifact is text that is read at runtime by a skill
or by a test.

## Completeness notes carried into the phases

- **Error paths that can actually happen:** the branch has no ledger at all (ad-hoc work, no
  plan) when "Nanti" is chosen; the user gives an empty deferral reason; `gaspol-verify` fails
  under "Cuma verify dulu". All three are steps, not footnotes.
- **Edge cases enumerated:** offer presented when the chain already ran this session; offer
  presented inside `gaspol-auto`, which must not re-introduce a mid-run checkpoint; a ledger
  whose `## Log` is not the last block; `[~]` cancelled phases still open at finish time.
- **Observability:** the ledger lines ARE the observability here — a deferred ticket that leaves
  no cursor is invisible, which is the failure this ticket's own reminder mechanism prevents.
- **Not applicable:** no runtime logging, no metrics, no non-deterministic behaviour — this
  repository ships markdown and shell, so `docs/evals/` is not applicable (reason: nothing here
  produces LLM output that needs pass@k scoring).

---

### Phase A: The shared offer file

**Estimated time:** 12 minutes

**Files:**
- Create: `skills/_shared/finish-offer.md`
- Create: `tests/ticket-scripts/test-finish-offer.sh`

**Steps:**
1. Write failing test for the shared offer file's contract in
   `tests/ticket-scripts/test-finish-offer.sh`. Expected error:
   `test-finish-offer: skills/_shared/finish-offer.md does not exist` and exit 1.
   The test asserts: the file exists; it names all three options
   (`Finish sekarang`, `Nanti`, `Cuma verify dulu`); it spells the deferral cursor literally as
   `— NEXT: gaspol-finish — deferred:`; it states that an empty reason is refused and the
   question re-asked; it documents the no-ledger case; it documents the verify-failed case.
2. Run `bash tests/ticket-scripts/test-finish-offer.sh`, confirm it fails for the expected reason
   (missing file), not a shell syntax error.
3. Write `skills/_shared/finish-offer.md` covering, in this order: the three options; a table of
   what each does; the deferral cursor written verbatim; the rule that the reason after
   `deferred:` may not be empty and an empty one means asking again; the no-ledger case (say so
   in the reply and record nothing — never invent a ledger for a branch that has no plan); the
   verify-failed case (report the failure, do NOT re-present the offer, the work is not
   finishable yet); and the rule that a caller references this file rather than restating the
   modal.
4. Run `bash tests/ticket-scripts/test-finish-offer.sh`, confirm pass.
5. Run the full suite: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`
6. Commit: "feat(IDS-17): shared finish-offer contract"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-finish-offer.sh` passes
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` passes
- [ ] `skills/_shared/finish-offer.md` documents all three options, the deferral cursor, the
      empty-reason refusal, the no-ledger case, and the verify-failed case
- [ ] No placeholder/TODO comments in the new file

---

### Phase B: Wire the offer into the three call sites

**Estimated time:** 12 minutes

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md` (Integration section, currently line ~516)
- Modify: `skills/gaspol-parallel/SKILL.md` (Phase 3, currently line ~361)
- Modify: `skills/gaspol-auto/SKILL.md` (post-run report, currently line ~142)
- Modify: `tests/ticket-scripts/test-finish-offer.sh`

**Steps:**
1. Write failing test for the three call sites in `tests/ticket-scripts/test-finish-offer.sh`.
   Expected error: `skills/gaspol-execute/SKILL.md does not reference _shared/finish-offer.md`
   and exit 1. The test asserts each of the three files references `_shared/finish-offer.md`,
   and that none of them restates the option strings itself (the modal text appears in exactly
   one file across `skills/`).
2. Run `bash tests/ticket-scripts/test-finish-offer.sh`, confirm it fails for the expected reason.
3. Edit `skills/gaspol-execute/SKILL.md`: after the final phase completes, present the offer from
   `skills/_shared/finish-offer.md`. Replace the bare downstream mention of `gaspol-finish`.
4. Edit `skills/gaspol-parallel/SKILL.md` Phase 3: "Run `gaspol-finish` to finalize" becomes
   presenting the offer from `skills/_shared/finish-offer.md`.
5. Edit `skills/gaspol-auto/SKILL.md`: the post-run report's `[Proceed to gaspol-finish]` button
   becomes the same three-option offer, with a sentence stating that this sits AFTER the
   autonomous run ends and is therefore not a mid-run checkpoint — autonomous mode's no-pause
   guarantee is untouched.
6. Run `bash tests/ticket-scripts/test-finish-offer.sh`, confirm pass.
7. Run the full suite.
8. Commit: "feat(IDS-17): finishing becomes an offer at all three end-of-ticket call sites"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-finish-offer.sh` passes
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` passes
- [ ] All three callers reference `_shared/finish-offer.md`; the option strings appear in exactly
      one file under `skills/`
- [ ] `gaspol-auto` states the offer is post-run, not a mid-run checkpoint
- [ ] No placeholder/TODO comments in new text

---

### Phase C: Move the existing tests to the new contract (RED on purpose)

**Estimated time:** 14 minutes

**Files:**
- Modify: `tests/ticket-scripts/test-finish-fix-loop.sh` (step list, line ~86)
- Modify: `tests/ticket-scripts/test-finish-gates.sh` (lines ~150 and ~156)
- Modify: `tests/ticket-scripts/test-regression-gate.sh` (lines ~167 and ~186)

This phase deliberately ends RED. The tests encode the OLD six-step contract; rewriting them to
the new contract is the failing test for Phase D. Do not touch `skills/gaspol-finish/SKILL.md`
here.

**Steps:**
1. Write failing test by rewriting `tests/ticket-scripts/test-finish-fix-loop.sh` to assert the
   new contract. Expected error: `gaspol-finish still carries a Step 0 preamble` and exit 1.
   Assert: the four mandatory steps `gaspol-verify`, `plan-verifier`, `gaspol-review`,
   `gaspol-sync-docs` are all still named (so a future trim of the mandatory four fails);
   `/security-review` and `gaspol-learn` appear as offered, not as chain steps; no `Step 0`
   heading remains; the Fix Loop text no longer says "Step 0's checks run again".
2. Run `bash tests/ticket-scripts/test-finish-fix-loop.sh`, confirm it fails for the expected
   reason (the old text is still there), not a shell syntax error.
3. Edit `tests/ticket-scripts/test-finish-gates.sh`: delete the assertion at line ~150 that no
   rule makes `/security-review` skippable, replacing it with a comment naming IDS-17, the owner
   decision, and the knowledge note `narrow-and-record-conditional-audit-gates` it overrides —
   a deleted assertion with no explanation is how the next person restores it by accident.
   Remove `gaspol-learn` from the unconditional-steps loop at line ~156.
4. Edit `tests/ticket-scripts/test-regression-gate.sh`: delete the two assertions that
   `gaspol-finish` Step 0 runs `regression-gate` (lines ~167 and ~186) and their `$FINISH_SKILL`
   variable if it becomes unused. Keep both `gaspol-verify` assertions (lines ~178 and ~183)
   untouched — they are now the only wiring for that script and must not weaken.
5. Run the full suite; confirm the ONLY failures are the ones this phase created against
   `skills/gaspol-finish/SKILL.md`, and record which they are.
6. Commit: "test(IDS-17): move finish tests to the four-mandatory contract (RED)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-finish-fix-loop.sh` fails for the stated reason, not a
      syntax error
- [ ] `bash tests/ticket-scripts/test-regression-gate.sh` passes (its remaining assertions cover
      `gaspol-verify` only)
- [ ] The deleted `/security-review` assertion is replaced by a comment naming IDS-17 and the
      overridden note
- [ ] No test file silently lost coverage of the four mandatory steps

---

### Phase D: Trim gaspol-finish to four mandatory steps (GREEN)

**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-finish/SKILL.md`

**Steps:**
1. Write failing test — already written in Phase C. Re-run
   `bash tests/ticket-scripts/test-finish-fix-loop.sh` and confirm it still fails for the
   expected reason before editing anything. Expected error: `gaspol-finish still carries a
   Step 0 preamble`.
2. Delete the whole `### Step 0` block from `skills/gaspol-finish/SKILL.md`. In its place, one
   sentence recording WHY it went: its two commands are run by `gaspol-verify` Layer 1
   (`detect-stack`, and `regression-gate` anchored via `$CLAUDE_PLUGIN_ROOT`), which is now
   chain step 1, so cheap-checks-first is preserved by position instead of by repetition.
3. Renumber the chain to four mandatory steps: 1 `gaspol-verify`, 2 `plan-verifier`,
   3 `gaspol-review` Tier 1, 4 `gaspol-sync-docs`. Update the "Verify Chain Complete" checklist
   block, the "Pre-Finish Verification Chain (MANDATORY)" preamble that currently says "all six
   steps", the Red Flags entry that lists all six, and the Integration table at the file's end.
4. Revoke the skip permission on `gaspol-verify`: delete "If gaspol-verify was already run and
   passed in this session, you may skip this step" and state that it runs every time, with the
   reason — with Step 0 gone this is the only step that runs the suite, and an
   optional-and-duplicated pair collapses into nothing running at all.
5. Add the offers block after step 4: one `AskUserQuestion` carrying both `/security-review` and
   `gaspol-learn`, each `[Run it]` / `[Skip]`. State explicitly that declining records nothing —
   both are recordless, symmetrically, by owner decision. Keep the existing rule that when
   `/security-review` IS run and reports a finding, it BLOCKS until resolved.
6. Repoint the Fix Loop block: "Step 0's checks run again before each fix round's dispatch"
   becomes `gaspol-verify` Layer 1's checks.
7. Run `bash tests/ticket-scripts/test-finish-fix-loop.sh`, confirm pass.
8. Run the full suite, confirm every test passes.
9. Commit: "feat(IDS-17): gaspol-finish chain drops to four mandatory steps"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` passes
- [ ] `grep -c 'Step 0' skills/gaspol-finish/SKILL.md` returns 0
- [ ] The four mandatory steps are named; `/security-review` and `gaspol-learn` appear only as
      offers
- [ ] The `gaspol-verify` skip permission is gone and the reason is written down
- [ ] The Step 0 deletion carries its reason in the file, not only in this plan
- [ ] No placeholder/TODO comments in changed text

---

### Phase E: Record the /security-review divergence as an ADR

**Estimated time:** 8 minutes

**Files:**
- Create: an ADR under the resolved knowledge-base root, written by `gaspol-adr`

**Steps:**
1. Write failing test for the ADR's existence is **not applicable** — the KB root is resolved per
   machine (`skills/_shared/kb-root`, three states) and may legitimately be absent, so a test
   asserting a file there would fail on any machine without a store. Reason recorded here rather
   than left blank. The check is instead the manual verification line below.
2. Resolve the store: `KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")"`. Exit 4 (none
   configured) → record `knowledge-store: none — not configured` in the ledger and skip this
   phase as `[~]` with that reason. Exit 3 (UNKNOWN) → STOP and ask; never treat an unreadable
   store as empty.
3. Invoke `gaspol-adr` to capture the divergence: gaspol-finish no longer runs `/security-review`
   unconditionally; it is offered, and declining records nothing. Include the overridden note's
   name (`narrow-and-record-conditional-audit-gates`), its stated reason (in a skills repository
   markdown is the executed surface, so a boring-looking diff can still carry a hole), the
   owner's decision, and the fact that `gaspol-execute` Step 3.6 still runs `/security-review` on
   its own triggers.
4. Confirm the old note is NOT marked superseded — both coexist, per the divergence rule.
5. Commit any in-repo change this produced (there may be none if the ADR lands outside the repo).

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` passes
- [ ] The ADR exists at the resolved KB root with `status: proposed`, OR the phase is `[~]` with
      `knowledge-store: none — not configured` recorded
- [ ] The overridden note still carries `status: proposed` — not edited, not superseded
- [ ] Automated test: not applicable — the KB root is machine-dependent and may be absent

---

### Phase F: Documentation and version

**Estimated time:** 10 minutes

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `tests/ticket-scripts/test-finish-offer.sh`

**Steps:**
1. Write failing test in `tests/ticket-scripts/test-finish-offer.sh` asserting `CLAUDE.md` no
   longer claims `/security-review` runs "ALWAYS" from the finish chain, and that it names the
   four mandatory steps. Expected error: `CLAUDE.md still claims /security-review ALWAYS runs
   from the finish chain` and exit 1.
2. Run the test, confirm it fails for the expected reason.
3. Edit `CLAUDE.md`: rewrite the `gaspol-finish` section to four mandatory steps plus two
   offers; state the `/security-review` override and that `gaspol-execute` Step 3.6 is
   unaffected; add `skills/_shared/finish-offer.md` to the Architecture table; update the
   Skill Routing / workflow-chain description so finishing reads as offered, not implied;
   update the "six steps" wording wherever it appears.
4. Bump `.claude-plugin/plugin.json` to `1.26.0`.
5. Add the `CHANGELOG.md` entry for 1.26.0.
6. Run the test, confirm pass. Run the full suite.
7. Commit: "docs(IDS-17): release 1.26.0 — finish chain trimmed, finishing becomes an offer"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` passes
- [ ] `CLAUDE.md` names four mandatory steps, two offers, and the `/security-review` override
- [ ] `CLAUDE.md` states `gaspol-execute` Step 3.6 still runs `/security-review`
- [ ] `.claude-plugin/plugin.json` reads `1.26.0` and `CHANGELOG.md` has the matching entry
- [ ] No placeholder/TODO comments in changed text

---

## Out of scope

- `gaspol-execute` Step 3.6's own `/security-review` trigger — the request named `gaspol-finish`.
- The marketplace manifest in the separate `gaspol-one` repository — updated when this release is
  published, not by this plan.
