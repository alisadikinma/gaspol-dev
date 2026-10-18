# Verification Loop — the hot path runs code, it does not only read it

> Stated once here. Read by `gaspol-execute` (per phase, in session) and by the implementer
> dispatch templates, which have called the same thing a "Validation Ladder" since v1.8.
> Same ladder, one source.

## Why this exists (IDS-12)

`gaspol-execute` runs on almost every job, and on 1.21.0 it never executed anything:

```
grep -n "detect-stack|npm test|Validation Ladder" skills/gaspol-execute/SKILL.md   →  0 hits
```

Its per-phase "Auto-Review" dispatched a model to **read** the code. Nothing **ran** it.
Everything executable was deferred to `gaspol-verify` at the very end — the slowest and most
expensive place to discover a type error, and far enough from the cause that the fix is
archaeology.

A gate that reads produces an opinion. A gate that runs produces evidence. The Iron Laws already
demand evidence; this is where it comes from.

## The commands are derived, never hardcoded

```bash
skills/gaspol-execute/scripts/detect-stack <project-root>
```

It prints `<level>: <command>` lines. Three states, kept apart — the house rule this repo applies
to `DESIGN.md` and to the KB root:

| detect-stack says | Meaning | Do |
|---|---|---|
| `static: npx tsc --noEmit` etc. | commands found | run them |
| `<level>: UNKNOWN` | marker file present, backing command missing | **STOP and ask.** A missing tool is not a passing level |
| nothing at all | no stack markers (a docs or prose repo) | fall back to the **plan-declared** commands, recorded as `detect-stack: no stack markers, using plan-declared commands` — never silently skipped |

## The ladder

Cheapest first, **fail-fast**: stop at the first level that fails.

| Level | What | When it runs |
|---|---|---|
| **L1 static** | typecheck + lint | every phase that touches code |
| **L2 unit** | targeted tests: the files the phase touches plus the cheap contract group they belong to | every phase that touches code |
| **L2 full** | the full suite | once, in the last phase, before the final review; and at a *shared-surface* phase (see Cadence) |
| **L3 build** | the production build | the last phase, and any phase touching build config, dependencies, or entry points |
| **L4 integration** | data actually flows end to end | phases wiring a real integration |
| **L5 edge** | the non-happy paths actually executed | phases whose Completeness Ladder rungs 2-3 produced cases |

**Proportionality.** A `docs-only`, `config-only` or `rename-only` phase — the same classes the
complexity classifier already recognises — skips L2 and L3. It still runs L1 where a linter covers
those files. This is deliberate: IDS-10 removed the scope governor, and "run a full build after a
one-line docs edit" is exactly the over-application that leaves behind.

**Cadence — the full suite is a final gate, not a per-phase tax.** Each TDD step runs only the
tests it touches (one file or case: seconds). At phase end run the *targeted* group: the test
files of the modules the phase changed, plus the project's fast contract checks (the ones that
finish in seconds, e.g. a consistency or registry validator). The **full suite runs once, in the
last phase**, before the final review, and again only when a phase touches a *shared surface*:
a module many groups import, a registry/index every tool must appear in, build or dependency
config, or a scaffold/template that is copied into other projects. A full suite after every phase
multiplies its runtime by the phase count; later phases build on earlier ones, so a regression in
another group surfaces at the final run, where the fix is still one `git bisect` away. A failure
in the full run is fixed and then re-run from that failing group (On failure, point 3), not from
the whole suite. The checkpoint states which group ran and why the full suite was or was not due.

**A level that does not apply is skipped EXPLICITLY, with the reason, in the checkpoint.** A silent
skip is a placeholder-grade lie — the rule the Validation Ladder has carried since v1.8.

## On failure

1. **Read the actual output.** The failing command's real stderr/stdout goes into the fix,
   **verbatim** — not a paraphrase, not a summary. You already have the fact; restating it in your
   own words converts it into a guess.
2. Fix the cause, not the symptom. Three failed attempts on one error → this is a `gaspol-debug`
   problem, not a retry problem.
3. **Re-run from the failed level**, not from the top (wasteful) and not from the next one
   (the whole point of stopping was that this level is broken).
4. The loop is **bounded** by `skills/_shared/fix-loop.md`. Its round cap lives there and is
   deliberately not repeated here: a constant copied into two files is a constant that will
   disagree with itself.

## The baseline, captured before phase 1

Run the ladder **once, before any phase starts**, and record the result in the ledger:

```
verification-baseline: L1 pass · L2 pass (142 tests, 3m10s) · L3 not run — captured at <SHA>
```

Capture it **once per run** and reuse it; never re-run the baseline to get counts per group or a
second opinion — read them from the first run's output. Record the suite's runtime: it tells the
plan what one full-suite run costs, so a phase estimate counts it once, not per step or per phase.

Without it, a suite that was **already red** gets blamed on the first phase, and the fix loop
burns its rounds on somebody else's failure. `gaspol-finish` learned this in IDS-9 (its Step 0
runs the deterministic checks before dispatching any agent); the same reasoning applies one layer
earlier, where it is cheaper still.

**If the baseline is already red:** STOP and ask, via `AskUserQuestion` —
`[Fix the baseline first]` / `[Proceed, and treat these N failures as pre-existing]` /
`[Something else]`. On "proceed", the failing test names are recorded in the ledger, and a phase
is judged against **new** failures only. Never let a red baseline pass as green, and never let it
silently absorb a failure this work caused.

## The gate

**A phase may not be ticked `[x]` until its ladder has run and every applicable level passed
or was explicitly skipped with a reason.** Not "the code looks right", not "the review found
nothing" — the commands ran and their exit codes are recorded.

This is the same shape as the TDD gate: TDD refuses a phase with no failing test first, this
refuses a phase with no passing run after.
