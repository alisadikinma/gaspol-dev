# Execution Flow — detail

Read from `skills/gaspol-execute/SKILL.md` when writing the ledger after a checkpoint, classifying a phase for auto-review, or recovering from a failure. The gates stay in SKILL.md; this file holds the detail.

### Checkpoint Rule 6 detail: the three ledger places

   - **(a) Tick the Checklist, in place:** `- [x] Phase [X]: [name] — DONE`, `- [>] … — DOING`
     at start, or `- [~] … — <short reason>` if cancelled/skipped (reason MANDATORY, detail in the Log).
   - **(b) Set the phase's `## Phase log` row:** status (`DONE`/`DOING`/`WIP`/`DIBATALKAN`) and
     the real commit SHA **in backticks, short form** (`` `86f058d` ``), never bare, never `—`; until committed the cell reads `` `<no commit>` ``. A finished phase still at `TODO`, or with a bare or missing SHA, fails the gate.
   - **(c) Append one Log line:**
     `Phase [X] [name] — COMPLETE (`<sha>`) — <1-line summary> — NEXT: <next phase, or "DONE">`. The SHA is in backticks here too.
     If the phase is left unfinished (a blocker, an approaching `/compact`, a pause), append
     instead: `Phase [X] [name] — WIP — <done so far> — BLOCKER: <what is stuck> — NEXT: <exact resume action>`.

   The trailing `NEXT:`/`BLOCKER:` fields are the **handoff cursor**: a resumed session reads the
   last line to know where to continue, instead of inferring "first unfinished phase". Older lines
   without them still parse. **Never** write the ledger under `.git/` (agent writes are blocked
   there); keep `.gaspol/` in `.gitignore`. `git clean -fdx` deletes it — then recover phase state
   from `git log`.

### Session-Length Checkpoint (Context-Budget Nudge)

Count phases completed in the **current execute run** (phases restored from a prior session's ledger on resume do not count — only ones this run itself finishes). After presenting the checkpoint report for the **6th** phase completed in this run — and every 6th subsequent one (12th, 18th, ...) — use the **AskUserQuestion** tool:

> "N phases done this session. Continue here, or pick up fresh next session? The ledger (`.gaspol/progress/PROGRESS-<TICKET>.md`, or the plan's declared ledger path) has the exact resume point either way."

Options:
- **(a) Continue as normal** — proceed to the next phase immediately
- **(b) Stop here** — report the resume point clearly (the last ledger line's `NEXT:` cursor) and end the session
- **(c) Raise the threshold for this run** — user specifies N; don't ask again until N more phases complete

Do **not** fire before the 6th completed phase of the run. The first prompt fires only at the 6th completed phase, and repeats every 6th phase thereafter unless the user raised the threshold via (c).

### Step 1: Load and Review Plan

Pre-Execution Protocol Steps 1-3 and 6, already done: plan read, CLAUDE.md read, TodoWrite
created 1:1 with the phases, conflict matrix written to the ledger and ruled on.

### Step 3 detail: checkpoint contents

Then:
- Present the structured checkpoint report (see `checkpoint-template.md`)
- List all components and their data sources with real/placeholder classification
- List all files created or modified
- Report any deviations from the plan with justification
- Include Auto-Review section with classifier result and findings
- Mark the phase as `completed` in TodoWrite

### Step 4 detail

- Use the **AskUserQuestion** tool (MANDATORY) to get approval — this shows an interactive popup modal
- Provide options: `[Approved — proceed to next phase]`, `[Address review feedback first]` (only if auto-review surfaced findings), `[Changes needed (I'll explain)]`, `[Skip this phase]`, `[Stop execution]`
- Do NOT proceed until the user explicitly approves via the popup
- If the user requests changes, implement them before moving on
- If auto-review findings exist and user proceeds without addressing, log as technical debt (candidate for gaspol-adr capture)
- If the user skips a phase, acknowledge and note the skip

### Step 5: Repeat

- Return to Step 2 for the next phase
- Continue until all phases are complete

## Failure Recovery

If a phase fails mid-execution: leave completed work alone unless it caused the failure;
report exactly what failed (error, file, expected vs actual); propose a fix and wait for
approval; flag it as plan drift if the fix needs the plan changed; and re-run the phase
checkpoint afterwards — never skip the verification because the fix "obviously" worked.

If the completion gate fails:

1. **List all blocking issues** with file paths and line numbers
2. **Categorize each issue** — placeholder, TODO, dead code, console.log, etc.
3. **Propose fixes for each** — but wait for user to prioritize
4. **After fixes, re-run the completion gate** — must pass clean

### Completeness Gate detail

**Reuse, not volume:** prefer stdlib → native feature → already-installed dep over code you
author; no interface with one implementation. Reuse cuts cleverness, never coverage.

## Red Flags and Rationalizations

The full table — every excuse that produces a placeholder-riddled codebase, what it really
is, and the correct action — lives in
[anti-placeholder-rules.md](../anti-placeholder-rules.md). It is consulted, not read start to
finish. The four that catch most of them:

- About to write `const data = [...]` → trace the source, implement the real integration.
- "I'll connect it later" / "temporary" → later never comes; connect now or get an explicit
  user deferral.
- "This is basically done" / "I'm confident" → confidence is not evidence; run the
  Completion Gate scan.
- Batch-completing phases, or skipping one without asking → Law 2 and the checkpoint rules;
  one phase, one checkpoint, one approval.

### Overview tagline

> "What gets planned gets built — with real data, real integrations, real verification."

### Integration — upstream

**Upstream:** `gaspol-plan` provides the plan in `docs/plans/`; `gaspol-brainstorm` provides
the design decisions behind it.

### Step 2 detail: when the phase HAS the TDD step

If phase description HAS the TDD step, proceed:
- Mark the current phase as `in_progress` in TodoWrite
- Execute step 1 FIRST (write failing test, run it, verify expected failure)
- Only then implement production code to pass the test
- Follow RED-GREEN-REFACTOR per `gaspol-tdd`
- For every data-displaying component, trace the data source
- For every integration point, implement the real connection
- If blocked on a real integration, STOP and ask — do not substitute
- Follow CLAUDE.md design system, naming conventions, and patterns

### Completeness Gate — the six rungs

1. happy path, real integration; 2. every error path that can actually happen; 3. every edge
case the input space allows — enumerate them, don't sample; 4. the tests that prove 1-3,
written first; 5. the observability a 3am debugger needs; 6. the one comment explaining WHY.

## Data Source Classification and Checkpoint Template pointers

### Data Source Classification

The REAL-vs-PLACEHOLDER table lives in [anti-placeholder-rules.md](../anti-placeholder-rules.md).
Shape of it: anything that arrives through a hook, context, edge function, real-sourced prop,
or a computation over those is REAL; a hardcoded array, an empty array awaiting an API, a
string literal standing in for dynamic content, a commented-out fetch, or a mock function is
a PLACEHOLDER. When a case is not obvious, open the reference — do not guess.

### Checkpoint Template

The exact format is [checkpoint-template.md](../checkpoint-template.md): Implemented · Data
Sources table (Real/Placeholder per component) · Files Modified · Deviations from Plan ·
Auto-Review · Next Phase, ending "Waiting for approval before proceeding."

### Orphaned table rows (stray fragment in the original SKILL.md)

------------|--------|--------------|
| Supabase query via hook | REAL | `const { data } = useSegments()` |
| Context state | REAL | `const { segments } = useWorkspace()` |
| Edge function response | REAL | `const result = await supabase.functions.invoke(...)` |
| Props from parent (with real source) | REAL | `function Card({ segment }: Props)` |
| Computed from real data | REAL | `const total = segments.reduce(...)` |
| Hardcoded array in component | PLACEHOLDER | `const data = [{id:1, name:'test'}]` |
| Empty array awaiting API | PLACEHOLDER | `const data: Segment[] = []` |
| String literals for dynamic content | PLACEHOLDER | `const title = "Sample Title"` |
| Commented-out API call | PLACEHOLDER | `// TODO: fetch from API` |
| Mock function returning static data | PLACEHOLDER | `const fetchData = () => mockData` |
