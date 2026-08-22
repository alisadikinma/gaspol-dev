**Ticket:** IDS-12

# The hot path runs code, it does not only read it

## The question that produced this ticket

*"kalau tidak tambah pintar jadi percuma kita kembangkan lagi? apa yg bisa kita lakukan supaya
tambah pintar dalam hal coding?"*

The honest answer is that model capability is fixed and system capability is not. What raises
system capability is not better instructions — IDS-10 and IDS-11 were both instruction work — it is
**closing the loop between writing code and finding out whether it works.**

## The defect

```
grep -n "detect-stack|npm test|Validation Ladder" skills/gaspol-execute/SKILL.md   →  0 hits
```

`gaspol-execute` runs on almost every job and executed **nothing**. Per phase it:

| Did | Did not |
|---|---|
| TDD step 1 — write a failing test, run it, confirm the expected failure | run the suite after the phase |
| "Auto-Review" — dispatch a model to **read** the diff | typecheck, lint, or build |
| Write a checkpoint report | execute anything else at all |

The Validation Ladder (L1 static → L5 edge) has existed since v1.8, but only in
`implementer-prompt.md` (for subagents dispatched *out* of the session) and in `gaspol-parallel`.
The in-session path — the most-used one — had no equivalent. Everything executable was deferred to
`gaspol-verify` at the very end.

Three costs, in order of severity:

1. **Errors are found far from their cause.** A type error introduced in Phase B surfaces after
   Phase F, on top of four phases of work built on it. Fixing it is archaeology.
2. **The checkpoint is an opinion.** "Auto-Review found nothing" means a model read the code and
   did not object. Iron Law 3 demands evidence; a model's reading is not evidence.
3. **The expensive gate does the cheap gate's work.** `gaspol-verify` and `gaspol-finish` dispatch
   agents; `npx tsc --noEmit` costs seconds and finds a different, larger class of defect.

## Resolution

`skills/_shared/verification-loop.md` — one source, read by `gaspol-execute` and deferred to by
`gaspol-parallel`'s Validation Ladder, which was the same ladder written twice.

**Baseline before Phase A.** Commands derived from `detect-stack`, three states kept apart, result
recorded in the ledger. A red baseline **STOPS and asks**. Without it the first phase inherits
somebody else's failures and the fix loop burns its rounds on them — the exact lesson `gaspol-finish`
learned in IDS-9, applied one layer earlier where it is cheaper.

**Per-phase ladder, fail-fast, cheapest first.** L1 → L5, stopping at the first failure. The failing
command's output goes into the fix **verbatim**; a paraphrase converts a fact you already hold into
a guess. Re-run from the failed level. Bounded by `skills/_shared/fix-loop.md`.

**Proportionality.** `docs-only` / `config-only` / `rename-only` phases skip L2 and L3. IDS-10
removed the scope governor when it replaced the Laziness Ladder, and a full build after a one-line
docs edit is exactly where that absence would show first. Skips are always **explicit, with the
reason** — a silent skip is a placeholder-grade lie.

**The gate.** A phase may not be ticked `[x]` until its ladder ran. The TDD gate's mirror: TDD
refuses a phase with no failing test *before*, this refuses one with no passing run *after*.

## Scope boundary — this is the half that matters most, not the whole

This verifies code **compiles, passes its tests, and builds**. It does **not** verify that the
running product behaves correctly — no browser, no real request, no rendered page. That is the open
`/qa` lane and IDS-6's deferred Part B.

Stating this plainly is the point: a partial gate described as a whole one is worse than no gate,
because it stops anyone looking for the missing half.

## Definition of done

- `gaspol-execute` derives its commands, captures a baseline before Phase A, and runs the ladder
  before every checkpoint.
- The checkpoint template records command + **exit code**, never the word "passed" alone.
- `gaspol-parallel` defers to the shared ladder instead of restating it.
- A phase cannot be ticked without its ladder having run.
- Deterministic suite green.
