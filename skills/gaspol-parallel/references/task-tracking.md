# gaspol-parallel — full Task Execution Tracking

Moved verbatim from `SKILL.md` (IDS-23). `SKILL.md` keeps the ledger gate and the session-length checkpoint as sentences in its body.

## Task Execution Tracking

**Durable ledger (survives `/compact`) — tick-then-append gate, BLOCKING:** alongside the
visual tracker below, after EACH task completes and BEFORE the next one starts, update the
plan's resolved ledger — `.gaspol/progress/PROGRESS-<TICKET>.md` when the plan header names it
(new plans, created by `gaspol-plan` at plan-write time), else an older ledger path
(`.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md`) per its backward-compat
rule (create the file, and its parent dir, if genuinely absent). This is blocking, like a test
gate: no next task until both steps are written, never batched at the end — a crash mid-run
must leave a truthful state, not a stale one:
- **(a) Tick the Checklist:** flip this task's `## Checklist` line — `- [ ]` → `- [>]` when the
  task starts, → `- [x] — DONE` on completion, or → `- [~] — <reason>` if cancelled/skipped
  (reason mandatory, detail in the Log). See `skills/gaspol-plan/SKILL.md` "Progress Ledger
  Format" for the exact four-state template.
- **(b) Append to the Log:**
  `Task [N] [title] — COMPLETE — <1-line summary> — NEXT: <next task, or "DONE">`. If a task
  is left unfinished (blocker or `/compact`), append instead:
  `Task [N] [title] — WIP — <what's done> — BLOCKER: <what's stuck> — NEXT: <exact resume action>`.
The trailing `NEXT:`/`BLOCKER:` fields are the handoff cursor a resumed session reads to know
where to continue and what's blocking (older lines without the suffix still parse). `## Log`
stays the last block in the file — `scan-active-ledgers` reads the file's last non-empty line.
The visual tracker is in-memory and is lost on compaction; the ledger is the durable record a
resumed session reads to know which tasks are done. **Never** write under `.git/` (protected
path — agent writes blocked). Ensure `.gaspol/` is in the project `.gitignore` (working-tree
scratch, never committed); `git clean -fdx` deletes it, recover from `git log`.

**Session-length checkpoint (context-budget nudge):** count waves completed (mode
`independent-domains`) or phases completed (mode `plan-phases`) in the **current run** —
not ones restored from the ledger on resume, only ones this run itself finishes. After every
**3rd** wave/phase completes — the 3rd, 6th, 9th, ... — use the **AskUserQuestion** tool:

> "N phases done this session. Continue here, or pick up fresh next session? The ledger
> (`.gaspol/progress/PROGRESS-<TICKET>.md`, or the plan's declared ledger path) has the exact
> resume point either way."

Options:
- **(a) Continue as normal** — proceed with the next wave/phase immediately
- **(b) Stop here** — report the resume point clearly (the last ledger line's `NEXT:` cursor)
  and end the session
- **(c) Raise the threshold for this run** — user specifies N; don't ask again until N more
  waves/phases complete

Do **not** fire on wave/phase 1 or 2 — only starting at the 3rd completed in this run,
repeating every 3rd thereafter unless raised. This is a bounded, explicit exception to
Continuous Execution Discipline, not a contradiction of it — see the added bullet there.

Track progress visually for the user:

```
Task 1/5: Build ChatSidebar component
  [x] Implementer dispatched
  [x] Implementation complete
  [x] Spec review: PASS
  [x] Quality review: PASS (1 minor noted)
  Status: COMPLETE

Task 2/5: Add session persistence hook
  [x] Implementer dispatched
  [x] Implementation complete
  [x] Spec review: FAIL (2 issues)
  [ ] Fix issues
  [ ] Re-run spec review
  [ ] Quality review
  Status: IN PROGRESS — fixing spec issues
```
