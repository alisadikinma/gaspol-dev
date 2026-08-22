**Ticket:** IDS-12
**Artifact:** https://claude.ai/code/artifact/5f754e3f-a3df-40d9-ad3c-ed556e02ae98
**Spec:** [2026-08-22-IDS-12-per-phase-verification-loop-spec.md](2026-08-22-IDS-12-per-phase-verification-loop-spec.md)
**Ledger:** `.gaspol/progress/PROGRESS-IDS-12.md`
**Execute with:** `gaspol-execute`

# Plan — per-phase verification loop

## Goal

Make the in-session execution path run its checks instead of reading its code, without letting the
new gate become ceremony on phases that do not need it.

## Data Integration Map

| Feature | Data Source | Read by | Exists? | Action |
|---|---|---|---|---|
| Ladder rule | `skills/_shared/verification-loop.md` | execute + parallel | no | add, one source |
| Commands | `scripts/detect-stack` | the loop | yes | reuse, three states honoured |
| Baseline | ledger `verification-baseline:` | execute Step 7, per-phase judging | no | add |
| Round cap | `skills/_shared/fix-loop.md` | the loop | yes | reuse, never restate |
| Evidence | `checkpoint-template.md` Verification table | the human reading the checkpoint | no | add |

## Checklist

- [x] Phase A — failing test for the whole loop
- [x] Phase B — `_shared/verification-loop.md`
- [x] Phase C — execute Step 7 baseline + per-phase ladder; parallel defers
- [x] Phase D — checkpoint evidence table, ceiling, docs, 1.22.0

## Phase A: Failing test

1. `test-verification-loop.sh` asserts: the loop exists in `gaspol-execute`; `detect-stack` is
   invoked; a baseline precedes Phase A and a red baseline stops; L1-L3 named, fail-fast, restart
   from the failed level; proportionality for docs/config/rename; explicit skips; error text
   verbatim; the bound is borrowed from `fix-loop.md` and its number never restated; three
   detect-stack states; checkpoint records exit codes; a phase cannot be ticked without it.
   Expected error: no Verification Loop section.

**Verification:** the test fails on the first assertion before any edit.

## Phase B: The shared rule

1. Write `skills/_shared/verification-loop.md` — why it exists (with the grep), the three
   detect-stack states, the five levels, proportionality, the failure protocol, the baseline, the
   gate.

**Verification:** every assertion that targets the shared file passes.

## Phase C: Wire it

1. `gaspol-execute` Step 7 (end of Pre-Execution) — baseline, three states, red-baseline stop.
2. `gaspol-execute` new `## Verification Loop` section — compact, referencing the shared file, not
   restating its detail.
3. `gaspol-parallel` Validation Ladder — one note deferring to the shared file. Its per-task
   application stays; the levels and rules move to the single source.

**Verification:** `test-verification-loop.sh` green.

## Phase D: Evidence, ceiling, docs

1. `checkpoint-template.md` — Verification table above Auto-Review: level, command, exit code,
   result, new-failures-vs-baseline.
2. `test-execute-trim.sh` — ceiling 26200 → 29000 **with the added gates named in the comment**,
   and `Verification Loop` + `detect-stack` added to the obligation list so a later trim cannot
   quietly remove them.
3. CLAUDE.md section, CHANGELOG, `plugin.json` + marketplace 1.22.0.

**Verification:** whole suite green.

## Red Flags

- Raising the trim ceiling to fit prose would be the failure that gate exists to catch. It moves
  only because two gates were added, and both are named where it moved.
- Describing this as "verification" without stating that nothing is executed in a browser would
  make a partial gate read as a whole one, and stop anyone from closing the other half.
