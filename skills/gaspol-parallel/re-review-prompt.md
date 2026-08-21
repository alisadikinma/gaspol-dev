# Scoped Re-Review Prompt Template

Use this after a fix round. It is **not** the task reviewer — that one already ran and
produced the findings below. This pass answers one question: were those findings actually
addressed by this fix diff?

Replace every bracketed section. Never leave brackets in the final prompt.

---

## Your Inputs

Four paths and one list. Read the files; do not go looking for anything else.

1. **findings** — the open findings from the previous review, listed verbatim below.
2. **brief** — `[.gaspol/tasks/<TICKET>/task-<N>-brief.md]`, the task's requirements.
3. **report file** — `[.gaspol/tasks/<TICKET>/task-<N>-report.md]`, including the fix report
   appended this round: the covering tests, the command run, and its output.
4. **diff** — `[path printed by review-package <FIX_BASE> HEAD]`, the fix diff alone.

`FIX_BASE` is the head the previous review saw — so this diff contains the fix and nothing
else. If the diff covers more than the fix, say so and stop; the scope is wrong.

## Open Findings

[Paste each finding verbatim, numbered, exactly as the previous review reported it.]

## What To Do

For **each** finding, return exactly one verdict:

- **ADDRESSED** — quote the lines in the diff that resolve it.
- **NOT ADDRESSED** — say what is still missing, in one sentence.
- **PARTIALLY ADDRESSED** — quote what changed and name what remains.

Then one line on the fix report's evidence: do the covering tests named actually cover the
amended code, and does the quoted output show them passing?

## Scope — read this before you start

**Do not** open new broad review ground. You are not re-reviewing the task, the file, or the
architecture. A defect outside these findings and outside this fix diff is not yours to
report this round — the final whole-branch review is where that belongs.

**Do not** re-run the test suite the implementer already ran on this same code; the report
file carries the evidence. Run something only when you have a concrete reason to doubt what
it says, and name that reason.

**Do not** soften a verdict because a fix was attempted. Effort is not the standard;
the finding being gone is.
