# The Finish Offer — shared by `gaspol-execute`, `gaspol-parallel` and `gaspol-auto`

Finishing a ticket is an **offer**, not an obligation. When the work of a ticket is done —
the last phase of a plan, the last task of a parallel run, the end of an autonomous run —
present this offer and let the user decide when the branch gets merged, reviewed, or left alone.

**The text lives here and only here.** A caller references this file; it never restates the
options. A modal copied into three skills is three modals that will disagree with each other —
the same reason `fix-loop.md` holds the round cap in one place.

## The offer

Present it with **AskUserQuestion**, exactly these three options:

```text
[Finish sekarang]  [Nanti — branch dibiarkan]  [Cuma verify dulu]
```

| Choice | What happens |
|--------|--------------|
| **Finish sekarang** | Invoke `gaspol-finish`. Its own chain takes over from there. |
| **Nanti** | Write the deferral cursor to the ledger (below) and stop. The branch is left exactly as it is — nothing merged, nothing deleted. |
| **Cuma verify dulu** | Run `gaspol-verify` only. On success, present this same offer again. On failure, see *Verify failed* below. |

## The deferral cursor

"Nanti" appends one line to the ticket's ledger `## Log` block, ending with this cursor
**spelled exactly this way**:

```text
- <YYYY-MM-DD> <what was completed> — NEXT: gaspol-finish — deferred: <reason>
```

`skills/gaspol-execute/scripts/scan-active-ledgers` reads each ledger's last non-empty line and
prints every ticket whose `NEXT:` marker is not `DONE`. Writing the cursor in this form is
therefore the entire reminder mechanism — no new code, no new file, no scheduled check. A
deferral spelled any other way is a deferral nothing surfaces, and a finished branch that never
merges is exactly the failure this line prevents.

`## Log` must remain the **last** block in the ledger file. Appending anything below it breaks
`scan-active-ledgers`' last-line detection.

## The reason after `deferred:` may not be empty

An empty reason is refused: **ask again**. A bare label documents the wish to defer without
documenting why deferring was acceptable — which is `(if possible)` wearing a new name, the
escape hatch this repository has already had to close once elsewhere.

Good: `deferred: menunggu review desain dari klien`. Not good: `deferred:` or `deferred: nanti`.

## Error paths

**No ledger.** A branch with no plan has no ledger — no `.gaspol/progress/PROGRESS-<TICKET>.md`. Do **not**
create one to hold a deferral line — a progress file where no progress was ever tracked is a
record of nothing. Say so in the reply instead ("branch ini nggak punya ledger, jadi nggak ada
yang aku catat"), report the branch name and what was completed, and stop. The offer is still
valid; only the record is unavailable.

**Verify failed under "Cuma verify dulu".** Report the failing command and its output verbatim,
and **do NOT re-present the offer**. Work that does not pass its own suite is not work the user
should be asked how to finish; the next action is fixing the failure, not choosing a merge
strategy.

**The chain already ran this session.** Present the offer anyway. `gaspol-finish` decides what
to re-run; this file only decides whether the user is asked.

## Where it is presented

| Caller | Point |
|--------|-------|
| `gaspol-execute` | after the final phase's checkpoint is recorded |
| `gaspol-parallel` | Phase 3, after the final review and integration |
| `gaspol-auto` | in the post-run consolidated report, **after** the autonomous run has ended |

In `gaspol-auto` this is **not a mid-run checkpoint** — the run is already over when it appears,
so autonomous mode's no-pause-between-phases guarantee is untouched.
