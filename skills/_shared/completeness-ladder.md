# Completeness Ladder — gaspol default coding stance

> Do the complete thing. Completeness is cheap now; the shortcut is the expensive one.
> This is the COVERAGE governor. It sits ALONGSIDE the 3 Iron Laws (the FIDELITY
> governor). Iron Laws guarantee what you build is REAL; this ladder guarantees it is
> WHOLE. Neither one licenses the other to be skipped.

## Why this replaced the Laziness Ladder (v1.20, IDS-10)

v1.9 made a scope-cutting ladder the always-on default: its first rung asked *"does this
need to exist at all?"*, and its rules were *"fewest files possible, shortest working
diff wins."* It carried a fidelity boundary — never a placeholder, never a skipped test —
and that boundary held. It kept the output real. It did nothing to keep the output
**complete**, and shallow work breaches no boundary: the error path nobody handled, the
edge case nobody enumerated, the concurrency case nobody thought about. Every task began
by looking for a reason to do less.

The economics that justified the old caution are gone:

| Task type | Human team | AI-assisted | Compression |
|---|---|---|---|
| Boilerplate / scaffolding | 2 days | 15 min | ~100x |
| Test writing | 1 day | 15 min | ~50x |
| Feature implementation | 1 week | 30 min | ~30x |
| Bug fix + regression test | 4 hours | 15 min | ~20x |
| Architecture / design | 2 days | 4 hours | ~5x |

(Source: `gstack/ETHOS.md` §1 "Boil the Ocean".) The last 10% of completeness that teams
used to skip costs seconds now. "Don't boil the ocean" was correct while engineering time
was the bottleneck. It has quietly become an excuse.

## The Ladder

Before you write code, and again before you call a phase done, **walk down** the ladder and
do every rung that applies. This ladder is not stopped at the first rung that holds — that
was the old one's control flow, and it is exactly what changed.

1. **The happy path** — the real integration. Real data source, no placeholder (Iron Law 1).
2. **Every error path that can actually happen** — network failure, permission denied,
   malformed response, partial write, timeout. Named, handled, and reachable in a test.
   Not "log and rethrow" unless that genuinely is the right behaviour.
3. **Every edge case the input space allows** — empty, null, zero, one, max, duplicate,
   out-of-order, concurrent, unicode, malformed. Enumerate them; do not sample them.
4. **The tests that prove rungs 1-3** — written FIRST. The TDD hard gate is unchanged:
   step 1 of every phase is still `"Write failing test for [behavior]. Expected error: [error]."`
5. **The observability someone debugging this at 3am needs** — the log line, the error
   message that names the input, the metric. Whatever turns a support ticket into a grep.
6. **The one comment or doc line that stops the next reader re-deriving it** — the *why*,
   never the *what*.

**The only legitimate stop is genuinely unrelated work** — a rewrite, a multi-quarter
migration, a subsystem the task does not touch. Flag that as **separate scope**, in one
line, and keep going. It is never a reason to ship the shortcut on the work you are
actually doing.

## The Reuse Rule (kept from the old ladder's rungs 2-4)

Completeness is about coverage, not about volume of code you personally author. Before
writing a mechanism, prefer what already exists — this is the same instinct as
"search before building", and it never argues for less coverage:

- **stdlib** does it → use it.
- **Native platform / framework feature** does it → use it. DB constraint over app code,
  CSS over JS, `<input type="date">` over a picker library.
- **An already-installed dependency** does it → use it. Never add a new dependency for
  what a few lines do.

And the anti-abstraction rules, kept for the same reason — they cut *cleverness*, never
*coverage*:

- No interface with one implementation, no factory for one product, no config key for a
  value that never changes.
- Boring over clever. Clever is what someone decodes at 3am.

Reuse and completeness point the same way. Writing your own retry loop when the HTTP
client ships one is not more complete — it is less complete, with more code.

## Red Flags (scope-cutting rationalizations)

| Rationalization | Why it is wrong |
|---|---|
| "Approach B covers 90% with less code" | The delta costs seconds with AI coding. Take the full one. |
| "Tests in a follow-up PR" | Tests are the cheapest rung on this ladder (~50x compression). There is no follow-up. |
| "The user didn't ask for the error path" | Users state WHAT. Error paths are HOW — the same reason they don't ask for TDD. |
| "YAGNI" | YAGNI applies to unrequested **features**. It never applies to the completeness of a requested one. |
| "Shortest diff wins" | Deleted rule. The **correct** diff wins. |
| "That's boiling the ocean" | Boiling the ocean is the goal; you get there one lake at a time. Only unrelated work is out of scope. |
| "This would take two weeks" | Say "two weeks human / about an hour AI-assisted", then do it. |

## The FIDELITY boundary is unchanged

Completeness governs coverage. It does not license anything the Iron Laws forbid, and it
is not an excuse to expand what the user asked for:

- **Never a placeholder / mock / dummy where the plan specifies a real integration** —
  Iron Law 1, untouched. `const data = []` awaiting an API is a placeholder whether the
  file is short or long.
- **Never a skipped plan step** (Iron Law 2) or a completion claim without evidence
  (Iron Law 3).
- **Completeness is depth on the requested work, not new features.** Handling every error
  path of the endpoint you were asked for is completeness. Adding a second endpoint
  nobody asked for is scope creep — flag it as separate scope, same as unrelated work.

## Reports

Structured reports (checkpoints, data-source tables, plan-verifier evidence, edge-case
matrices) are safety artifacts — their content is the point. Write them without filler,
preamble, or restatement, and never at the cost of a row.
