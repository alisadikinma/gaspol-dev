**Ticket:** IDS-10
**Artifact:** https://claude.ai/code/artifact/6406c99d-0427-4634-abb4-c74089d20f30
**Spec:** [2026-08-22-IDS-10-completeness-batching-logic-design-spec.md](2026-08-22-IDS-10-completeness-batching-logic-design-spec.md)
**Execute with:** `gaspol-execute`

# Plan — completeness stance, report batching, logic design artifact

## Goal

Replace the scope-cutting default stance with a completeness stance, make one report mint one
ticket, and give logic-only work a reviewable design artifact — with a deterministic test for each
rule, in a suite that is green.

## Architecture Context

Skills repository. The "code" is markdown that an agent executes, so the executed surface is prose
and the tests are `bash` assertions over that prose (`tests/ticket-scripts/*.sh`, 30 at IDS-9).
Three live enforcement points for any always-on stance: `hooks/session-start.sh` (ambient),
`skills/gaspol-plan` + `skills/gaspol-execute` (gates), `skills/gaspol-execute/implementer-prompt.md`
(subagent dispatch).

## Tech Stack

bash (tests + scripts), markdown (skills), no runtime deps. `detect-stack` reports no stack markers
for this repo; the suite is the gate.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---|---|---|---|---|
| Batch gate | user's report text, in-session | brainstorm Phase 1 / debug Phase 1 | no | add |
| Ticket id | `skills/gaspol-execute/scripts/next-ticket` | reads CLAUDE.md counter | yes | reuse, one call per batch |
| Logic design artifact | the written `-plan.md` + real code quotes | `Artifact` tool | no | add |
| Completeness stance | `skills/_shared/completeness-ladder.md` | session hook + 3 gates | no | replaces laziness-ladder.md |
| Suite gate | `tests/ticket-scripts/*.sh` | bash | yes | repair 4, add 5 |

## Progress Ledger

`.gaspol/progress/PROGRESS-IDS-10.md`

## Checklist

- [x] Phase A — repair the red baseline
- [x] Phase B — Completeness Ladder replaces Laziness Ladder
- [x] Phase C — Batch Gate (brainstorm + debug + ticket minting)
- [x] Phase D — Logic Design Artifact (blocking gate)
- [x] Phase E — remove the Sparkfluence leak from gaspol-debug
- [x] Phase F — docs sync, version bump, full suite green

---

## Phase A: Repair the red baseline

1. Write failing test for "the marketplace-version gate resolves against a manifest that exists".
   Expected error: `grep: .claude-plugin/marketplace.json: No such file or directory` (the current
   failure in 4 tests).
2. Decide the manifest of record: this repo no longer ships one (commit `50fbbb1`); the version of
   record is `.claude-plugin/plugin.json`. Point the four assertions at it and at `CLAUDE.md`.
3. Files: `tests/ticket-scripts/test-ids8-docs.sh`, `test-naming-convention.sh`,
   `test-prior-art-gate.sh`, `test-skill-delegation.sh`.
4. Keep the assertion's *intent* (version strings agree across manifests) — do not delete the check.

**Verification:** all four scripts exit 0; suite reports 30/30.

## Phase B: Completeness Ladder replaces Laziness Ladder

1. Write failing test `test-completeness-ladder.sh` for: the shared file exists, carries all six
   rungs, carries the Reuse Rule, carries the five Red Flags, and — the regression that matters —
   **no live file mentions `laziness` or `ponytail`**. Expected error: file not found.
2. Create `skills/_shared/completeness-ladder.md`; delete `skills/_shared/laziness-ladder.md`.
3. Rewrite the hook block in `hooks/session-start.sh` (lines ~45-53).
4. Rewrite `## Laziness Gate (scope is decided HERE)` in `gaspol-plan/SKILL.md` → **Completeness
   Gate (coverage is decided HERE)**: per phase, ask what error paths and edge cases this phase
   owes, not whether it can be cut.
5. Rewrite `## Laziness Gate` in `gaspol-execute/SKILL.md` (line ~158) → Completeness Gate.
6. Rewrite `## Laziness Ladder (write MINIMAL code)` in `implementer-prompt.md` (line ~133).
7. Fix the stale cross-reference in `skills/_shared/kb-path.md:5`.

**Verification:** `grep -ri "laziness\|ponytail" hooks/ skills/ README.md` returns nothing;
`test-completeness-ladder.sh` exits 0.

## Phase C: Batch Gate

1. Write failing test `test-batch-gate.sh` for: brainstorm AND debug both carry a Batch Gate that
   runs before the decompose gate, default is one ticket, the split table has exactly the three
   listed reasons, the ceiling of 2 is stated, exceeding 2 requires `AskUserQuestion`, and each
   batched item becomes a phase with its own regression test. Expected error: no `Batch Gate`
   heading in either skill.
2. `gaspol-brainstorm/SKILL.md` Phase 1 — insert the Batch Gate immediately **above** the Decompose
   gate, and amend the decompose gate so it reads "sub-projects" as a *last* resort after batching.
3. `gaspol-debug/SKILL.md` — add the Batch Gate at the top of Phase 1, since bug reports land here.
4. `gaspol-brainstorm` Phase 6 — one `next-ticket` call per **batch**, stated explicitly.
5. Add the two rationalizations to both skills' Red Flags tables.

**Verification:** `test-batch-gate.sh` exits 0.

## Phase D: Logic Design Artifact

1. Write failing test `test-logic-design-artifact.sh` for: the five mandatory sections, the BLOCKING
   wording in `gaspol-execute`, the three states with `not applicable` explicitly absent, and the
   removal of brainstorm's `[No, pure backend/logic]` skip-design branch. Expected error: no
   `logic-design` reference anywhere.
2. New reference `skills/gaspol-plan/logic-design-artifact.md` — the five-section contract plus the
   mermaid + HTML publishing instructions.
3. `gaspol-plan/SKILL.md` — new final step **Design Artifact (BLOCKING)** after the plan file is
   written: UI work → `ui-ux-pro-max`; otherwise → the logic artifact. Publish via `Artifact`,
   approve via `AskUserQuestion`, record the verdict in the ledger.
4. `gaspol-brainstorm/SKILL.md` Phase 2.5 — replace `[No, pure backend/logic]` (skip design) with
   `[No UI — logic design artifact at plan stage]`.
5. `gaspol-execute/SKILL.md` — pre-execution gate: refuse a plan whose ledger has no
   `design-artifact: approved` line; `pending` → STOP and ask.

**Verification:** `test-logic-design-artifact.sh` exits 0.

## Phase E: Remove the Sparkfluence leak

1. Write failing test: no skill mentions a project name. Add the assertion to
   `test-gate-mutations.sh`'s table so the gate itself stays under test. Expected error: the string
   is present in `gaspol-debug/SKILL.md`.
2. Replace `## Sparkfluence-Specific Debugging` with an agnostic `## Project-Specific Debugging`
   section that reads the target project's CLAUDE.md instead of naming one.

**Verification:** `grep -ri sparkfluence skills/` returns nothing.

## Phase F: Docs sync + version

1. `CLAUDE.md` — replace the Laziness Ladder section with the Completeness Ladder; add the Batch
   Gate and the Logic Design Artifact; bump to 1.20.0; the counter already reads `IDS-10`.
2. `README.md:227` — same replacement.
3. `CHANGELOG.md` — 1.20.0 entry.
4. `.claude-plugin/plugin.json` — version bump.
5. Run the whole suite.

**Verification:** `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0, with
35 scripts present.

## Red Flags (self-check)

- A phase that only edits prose without a test asserting the prose is a phase that will silently
  regress — every phase here ships its assertion.
- Deleting the marketplace assertions instead of repointing them would remove a real gate to make a
  number go green. Repoint, never delete.
