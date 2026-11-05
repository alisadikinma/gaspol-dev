---
name: gaspol-dbpatch
description: "Use when fixing data already stored in a database: wrong, duplicated or orphaned rows, a bulk correction, or a one-off backfill. Not for fixing the code that produced the bad data."
---

# gaspol-dbpatch

## Iron Law

`NO WRITE TO STORED DATA WITHOUT A REPORT, A BACKUP, AND A DRY RUN ON A COPY FIRST`

A data patch cannot be reverted by `git revert`. Treat every write as irreversible until the backup proves otherwise.

## Core Principle

Bad rows are a symptom with two separate fixes: the code that produced them (see Step 6) and the rows already stored. This skill covers only the rows. Measure first, write once, prove the result.

**Announce at start:** "Using gaspol-dbpatch to correct stored data safely."

## Process

### 1. Investigate with read-only queries first

Run only `SELECT`. Write down two things before any patch exists:

- the root cause (why these rows are wrong), and
- the number of affected rows, plus the exact `WHERE` that selects them.

No root cause or no count: stop. A patch written from a guess edits rows it never understood.

### 2. One patch script, report mode by default

- One script, one purpose.
- Default run is REPORT: it prints what would change (count, sample of old and new values) and writes nothing.
- Only an explicit `--apply` flag writes.
- All writes happen in one transaction: all rows change or none do.
- Idempotent: a second `--apply` finds nothing left to change and writes nothing.
- Set an explicit statement and transaction timeout. A default timeout that is too short dies halfway on a large batch; no timeout can hold locks for hours.

### 3. Back up the rows that will change

Before `--apply`, save the current values of exactly the rows the patch will touch (a copy table, or a dump of those rows) and its location in the report. Restoring from this backup must be possible without the patch script.

### 4. Run on a copy of the data first

Run report and then `--apply` against a clone or staging copy of the data. Compare: the count in the report must equal the rows changed. A mismatch means the `WHERE` or the assumptions are wrong. Fix the script, not the numbers.

### 5. Before/after evidence with the SAME query

Pick one query that exposes the defect. Run it before the patch and after, unchanged, and record both outputs. A different query after the patch proves nothing.

### 6. Fix the cause through gaspol-debug

If code produced the bad data, a patch alone only cleans up until the next bad write. Fix that code through `gaspol-debug` (root cause, regression test), not in this skill. Do the code fix first or in the same release, otherwise the rows come back.

### 7. Production only on explicit instruction

Never run `--apply` against production on your own initiative, or because a copy run went well. Production runs only when the owner says so, naming the environment. Report mode against production is allowed (read-only).

### 8. Common traps

- **Empty id hits every row.** An `UPDATE` or `DELETE` whose `WHERE id = ?` receives `undefined` or `NULL` from code can match all rows (or, in some ORMs, drops the condition entirely). Guard empty ids before the query runs and assert the row count equals the expected count.
- **Time zone of date columns.** A date or timestamp column read in one time zone and written in another shifts values by hours or a whole day. State the zone of every date comparison and check boundary rows.
- **Application caches.** A service that reads values at boot (config, lookup tables) keeps serving the old value after the patch. Check whether a restart or cache flush is needed, and do it.
- **Stale clients.** A long-running process holding an old schema or model can fail on a changed table. Know what is running before you patch.

## Red Flags

| Thought | Reality |
|---|---|
| "It is only a few rows, skip the backup" | A few rows is still unrecoverable once written wrong. Back up. |
| "The report looks right, go straight to production" | The report ran on production data you have not yet changed. Rehearse on a copy. |
| "I will fix the code later" | The bad rows return. Do Step 6. |
| "Run it again to be sure" | If the script is not idempotent, the second run corrupts. Make it idempotent first. |

## Integration

- `gaspol-debug`: owns the fix for the code that produced the data.
- `gaspol-verify`: the before/after evidence feeds the completion claim.
- `gaspol-finish`: production write only after the owner's explicit instruction.
