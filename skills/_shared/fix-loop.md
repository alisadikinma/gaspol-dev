# The Fix Loop — shared by `gaspol-parallel` and `gaspol-finish`

A review that reports findings needs a bounded way to close them. Without a bound, "fix and
re-run" is an invitation to loop: IDS-8's finish chain ran roughly eleven agent dispatches,
five of them on the **same class of finding**, because nothing in the chain ever said *this is
a pattern, stop repeating the round*.

This file is the single source for that bound. `gaspol-parallel` applies it per task;
`gaspol-finish` applies it per BLOCKING gate. **The rule is stated once, here** — a second copy
is a copy that will disagree with the first.

---

## The round

A fix round is **one fix plus one scoped re-review**. **Five rounds maximum.**

**Rounds 1-3 — resume the fixer that already has the context.** Send it the open findings
verbatim; it knows the work, the code, and its own choices. If the harness cannot message a
live subagent, dispatch a fresh one carrying the persistent artifacts (the brief path and the
report file in `gaspol-parallel`; the plan, the ledger and the failing gate's output in
`gaspol-finish`).

**Rounds 4-5 — dispatch a fresh fixer one model tier above** the one that got stuck (see
[docs/rubric-model-switching.md](../../docs/rubric-model-switching.md)), framed as: *"a prior
attempt worked this N times; you own it now — read the report for what was tried."* A loop that
survives three resumes usually means the fixer cannot see its own problem. Fresh eyes and a
capability bump, in one move.

**Every round, either way:** the fixer fixes, re-runs the tests covering the amended code, and
records what it did. Before re-dispatching the reviewer, confirm the fix report carries **the
covering tests, the command run, and its output** — all three. Name the covering tests in the
fix message; a one-line fix does not need the whole suite.

## The re-review is scoped

Re-review the **fix diff**, never the whole branch again. `FIX_BASE` is **the head the previous
review saw**; the re-reviewer gets `FIX_BASE..HEAD` and nothing else.

- `gaspol-parallel`: `scripts/review-package <FIX_BASE> HEAD`, dispatched with
  [gaspol-parallel/re-review-prompt.md](../gaspol-parallel/re-review-prompt.md).
- `gaspol-finish`: record the SHA each gate verdicted; the re-run scopes to that SHA.

**Never pass `HEAD~1` as a base.** A multi-commit fix has more than one commit, and `HEAD~1`
silently drops all but the last — a base that looks right and reviews the wrong thing.

Scale the re-reviewer to the **diff**, not to the original task: a small fix diff takes a
cheap-to-mid tier.

## Cheap gates before expensive ones

**Before dispatching any agent in a fix round, run the deterministic checks.** A suite that
takes seconds must never be skipped ahead of a review that takes minutes, and a red tree makes
the review worthless anyway — it audits code that is about to change.

Where a repository keeps a **mutation harness** over its own gates (this one keeps
`tests/ticket-scripts/test-gate-mutations.sh`), it is part of that cheap pass. IDS-8's
governing lesson is why: **five separate times, closing one finding loosened the gate next to
it**, and each regression was found by an expensive audit that a two-second harness run would
have caught at commit time. Adding an exemption to a gate means adding its attack row to the
harness **first**, and watching it fail.

## Round 5 is the breaker, not a wall

When it trips, **adjudicate** each still-open finding yourself: weigh it against the governing
document — the plan, with the spec as binding authority — record the ruling, and continue.
**Stop and ask the user only when every path forward is a guess.**

**A finding that conflicts with what the plan mandates is yours to rule on** before you act on
it. Do not dismiss the finding because the plan mandates it, and do not dispatch a fix that
contradicts the plan without a recorded ruling.

## What the bound is not

It is not permission to drop a gate. Bounding the loop shortens the *rounds*, never the
*chain*: in IDS-8 every one of the six finish steps found a real defect, including a skill that
had silently stopped loading and a first capture that aborted on any fresh machine. A chain
that feels slow is an argument for scoping its re-runs, not for trusting a diff nobody audited.
