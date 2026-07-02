# Laziness Ladder — gaspol default coding stance (absorbed from ponytail)

> The laziest solution that actually works. Lazy = efficient, not careless.
> This is the SCOPE/COMPLEXITY governor. It sits ALONGSIDE the 3 Iron Laws
> (the FIDELITY governor) — they are orthogonal. Ladder cuts how MUCH you
> build; Iron Laws guarantee what you build is REAL. Read the boundary below
> before assuming they conflict — they don't.

## The Ladder

Before writing any code, stop at the first rung that holds:

1. **Does this need to exist at all?** Speculative need → skip it, say so in one line. (YAGNI)
2. **Stdlib does it?** Use it.
3. **Native platform/framework feature covers it?** DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib.
4. **Already-installed dependency solves it?** Use it. Never add a new dep for what a few lines do.
5. **Can it be one line?** One line.
6. **Only then:** the minimum code that works.

Two rungs work → take the higher one and move on. The first lazy solution that works is the right one. The ladder is a reflex, not a research project.

## Rules

- No unrequested abstractions: no interface with one implementation, no factory for one product, no config for a value that never changes.
- No boilerplate/scaffolding "for later" — later scaffolds for itself.
- Deletion over addition. Boring over clever (clever is what someone decodes at 3am).
- Fewest files possible. Shortest working diff wins.
- Mark deliberate simplifications with a `ponytail:` comment naming the ceiling + upgrade path (`// ponytail: global lock, per-account locks if throughput matters`).

## The FIDELITY boundary (where the ladder STOPS)

Lazy governs SCOPE, never fidelity. The ladder MUST NOT be used to justify any of:

- **Placeholder/mock/dummy data when the plan specifies a real integration** — that is an Iron Law 1 violation, not laziness. `const data = []` awaiting an API is a PLACEHOLDER, not a "lazy one-liner."
- Skipping input validation at trust boundaries, error handling that prevents data loss, security, or accessibility basics.
- Skipping the TDD failing-test-first step, or the per-task check. "Lazy tests" still means ONE runnable check that fails if the logic breaks — YAGNI on tests means no framework/fixtures you weren't asked for, NOT no test.
- Skipping a plan phase (Iron Law 2) or claiming done without evidence (Iron Law 3).

If a "lazy" move would cross this boundary → it is not lazy, it is negligent. Do the real thing.

## Reports (token discipline)

Keep gaspol's structured reports (checkpoints, data-source tables, plan-verifier evidence) — they are safety artifacts, their CONTENT stays. But write them terse: no filler, no preamble, no restating the obvious. Hemat token = ringkas laporan, BUKAN potong fidelity.

## Output

Code first, then at most three short lines: what was skipped, when to add it. Pattern: `[code] → skipped: [X], add when [Y].` Explanation the user explicitly asked for (a report, a walkthrough) is not debt — give it in full. The rule is only against unrequested prose defending simplifications.
