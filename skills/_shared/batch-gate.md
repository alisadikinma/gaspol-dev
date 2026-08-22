# Batch Gate — one report, one ticket

> Stated once here and referenced by `gaspol-brainstorm` and `gaspol-debug`. The threshold is
> deliberately not repeated in either caller: a constant copied into two skills is a constant that
> will disagree with itself — the lesson `skills/_shared/fix-loop.md` was extracted for.

## Why this gate exists (IDS-10)

Five defects reported in one message produced five tickets. Nothing in the plugin was counting.
Worse, the only rule on the topic pushed the other way — `gaspol-brainstorm`'s decompose gate says
*"Each sub-project gets its own spec → plan → implement cycle."*

The missing question sits **upstream** of decompose. Decompose asks *"is this one project or
several?"*; nothing first asked *"is this one piece of WORK or several?"*. Five bugs in one
subsystem are one piece of work. By the time decompose runs, the split has already happened.

## The gate

Runs on **any request carrying more than one item** — bugs, requests, findings, review comments —
before clarifying questions, before the decompose gate, before any ticket is minted.

**Default: ONE ticket.** Not a preference — the default. Splitting requires a reason from the
closed list below, stated out loud.

### May split into two when

| Reason | Test |
|---|---|
| **Disjoint subsystems AND oversized** | the items touch subsystems with no shared file or interface, **and** the combined plan needs more than 8 phases. Both halves, not either. |
| **One item blocks another** | item B cannot be verified until item A ships, so they must land in separate releases. |
| **The user explicitly asked** | they said "separate tickets". Their call, no argument needed. |

### Never split for

- "they are different bugs" — different bugs is the normal case for one ticket
- "they are in different files" — files are not subsystems
- "the ticket would be big" — a big ticket with phases beats five tickets with none
- "one is urgent, the others aren't" — that is a severity ordering inside the plan, not a split
- "one ticket per bug is tidier" — tidier for the tracker, five times the ceremony for the work

### Ceiling: two

**Never more than two tickets from one report, ever, automatically.** A third requires the user to
choose it, via `AskUserQuestion`, with the reason you would split and what each ticket would carry.

## What batching does NOT change

Batching changes the **container**, never the **coverage**. Inside the one ticket:

- Every reported item becomes its **own phase** in the one plan — never a bullet inside someone
  else's phase, never merged into "fix the reported issues".
- Phases are ordered by **severity** — the item that hurts most is phase 1.
- Every item keeps its **own regression test**, per the TDD gate. Five bugs means five failing
  tests written first.
- Every item is listed in the ledger checklist, so a partially-finished batch is visible.

An item that is quietly dropped because it shared a ticket is a Law 2 violation (a skipped step),
not a batching decision.

## Ticket minting

`skills/gaspol-execute/scripts/next-ticket` is called **once per batch**, not once per item. If the
gate ruled a split, it is called once per resulting ticket — at most twice.

## Red Flags

| Rationalization | Why it is wrong |
|---|---|
| "One ticket per bug is tidier" | Tidier for the tracker. Five specs, five plans, five verify chains, five finish chains for one afternoon of work. |
| "They're unrelated, so they're separate work" | Unrelated *files* are not disjoint *subsystems*. Apply the two-part test. |
| "The ticket is getting big" | Big is what phases are for. Size alone never splits. |
| "I'll split now and merge later if it's small" | Nothing merges tickets later. Split is one-way. |
| "The user listed them separately, so they want them separate" | A list is how people report things. Separate tickets is something they say. |
