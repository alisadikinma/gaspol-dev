# Pre-Execution Protocol — detail

Read from `skills/gaspol-execute/SKILL.md` when running the Pre-Execution Protocol. The gates stay in SKILL.md; this file holds the full text of the steps.

### Step 0: Check for Other Active In-Flight Ledgers

Before reading the plan or touching any code, check whether another plan is already
mid-flight in this same working tree:

```bash
skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress
```

- **Prints nothing, or only the current plan's own ledger** (compare each printed filename
  against the current plan's own `Ledger:` header field) — proceed straight to ticket/ledger
  resolution below, then Step 1.
- **Prints one or more filenames that do NOT belong to the plan you're about to execute** —
  STOP. Use the **AskUserQuestion** tool with exactly these 4 options:
  - **(a) Create a new worktree for this task via `gaspol-worktree`** (recommended — isolates
    file edits from the in-flight ticket)
  - **(b) Resume the in-flight ticket instead** — switch to executing that other plan
  - **(c) Proceed here anyway** — accepts file-conflict risk with the in-flight ticket
  - **(d) Something else**
  Do not proceed into Step 1 until the user has chosen.

**Ticket/ledger resolution:** read this plan's ticket from its header's `Ticket:`/`Ledger:`
fields (written by `gaspol-plan`'s ticket-minting step) and use them directly. If the plan
predates this feature and has no `Ticket:` field, call
`skills/gaspol-execute/scripts/next-ticket <project-CLAUDE.md-path>` directly as a fallback —
same AskUserQuestion-for-prefix logic as `gaspol-plan` uses if it exits 2 (no
`## gaspol Ticket Counter` section yet).

### Step 1: Read the Plan

Read the plan file in `docs/plans/` completely — every section, every phase, every bullet.
Note the phase count, dependencies between phases, external integrations required (APIs,
hooks, contexts, tables), which files are created versus modified, and where each piece of
data originates and terminates. Gaps, contradictions, or unclear instructions get raised
NOW, before any code.

### Step 2: Read CLAUDE.md

Read the target project's `CLAUDE.md` in full, so you do not recreate what exists or guess
at what is already written down: existing routes and components, existing hooks and
contexts, database tables and their columns, design-system tokens, secret/API-key patterns,
and the project's Edge Function or backend conventions.

### Step 3: Create TodoWrite (+ resume from durable ledger)

**Ledger path.** Use the plan header's declared ledger — `.gaspol/progress/PROGRESS-<TICKET>.md`
for plans written after IDS-1 Phase D. **Backward compatibility:** older ledgers
(`.gaspol/progress/<slug>.md`, or the shared `.gaspol/progress.md` when the plan names none)
are still read when the plan's header names them; only NEW ledgers use `PROGRESS-<TICKET>.md`.
Resolve once, then read and write that same file throughout.

**Resume read first.** If the ledger exists, read it before creating TodoWrite — it is the
durable record of phases finished in a prior session or before a `/compact`. Restore those as
`completed`, then read the **last line's handoff cursor**: `NEXT:` says where to resume, and a
`WIP`/`BLOCKER:` line means the last phase was left unfinished — surface that blocker and pick
up from its `NEXT:` action instead of restarting the phase. No cursor (older ledger) → continue
from the first unfinished phase. TodoWrite is in-memory and dies on compaction; the ledger is
the source of truth for "where were we?".

**Initialize only as a fallback.** `gaspol-plan` creates the ledger at plan-write time, so this
is normally a no-op. For an older plan without one, use the format in
`skills/gaspol-plan/SKILL.md` "Progress Ledger Format" — four mandatory sections, a per-phase
`## Checklist` sub-block, then `## Log`, which is **always the last block** because
`scan-active-ledgers` reads the last non-empty line. **Older flat** ledgers (one line per
phase) are read as-is and never reshaped; that section states why.

TodoWrite maps **1:1** with the plan's phases — six phases, six items. Do not combine phases,
do not invent phases the plan does not have.

### Step 4: List Modified Files

Before touching any file, list ALL files that will be created or modified across ALL phases. This gives the user a clear picture of the blast radius.

### Step 5: Identify Reusable Code

From CLAUDE.md, list what already exists and will be reused rather than rebuilt — hooks,
contexts/stores, utilities, components and UI primitives, shared types, and design tokens.
Record which existing piece each phase will use. Anything you cannot find a home for in
CLAUDE.md is either genuinely new or a sign you have not finished reading it.

---

### Step 6 detail: the conflict-matrix table

| Kind | One row for | Columns |
|---|---|---|
| Cross-task | every pair of tasks that **share a file** or an interface | the two tasks · what one produces against what the other consumes · the finding |
| Self-consistency | every task — whether its own text **agrees with itself** | the task · its tests against the code it specifies, the files it creates against the files it later touches · the finding |

Also flag anything the plan explicitly mandates that the review rubric treats as a defect
(a test that asserts nothing, a verbatim-duplicated logic block).

### Step 7 detail: example and rationale

Run the ladder and write the result to the ledger, e.g.
`verification-baseline: L1 pass · L2 pass (142 tests) — captured at <SHA>`.

**If the baseline is already red, STOP and ask** (`AskUserQuestion`): `[Fix the baseline first]` /
`[Proceed, treating these N failures as pre-existing]` / `[Something else]`. On "proceed", record
the failing test names; phases are then judged against **new** failures only. Without this, a suite
that was red before you arrived is blamed on Phase A and the fix loop burns rounds on somebody
else's failure — the reason `gaspol-finish` gained its Step 0 in IDS-9.

## CLAUDE.md-First Rule

Pre-Execution Step 2 is not a formality. Reading the target project's CLAUDE.md before any
exploration is what prevents the four expensive mistakes: recreating a hook or context that
already exists, guessing at column names that are written down, inventing design tokens
beside a documented palette, and re-deriving a convention the project already settled. If
the plan names something you cannot find in CLAUDE.md, that is a question, not a licence to
invent.

## Why this skill exists

Execution is where plans die, in three ways this skill exists to make impossible:
**placeholder substitution** (plan says integrate, implementer hardcodes because it is faster),
**step skipping** (a hard phase gets folded into the next one and half its requirements vanish),
and **phantom completion** ("it's done" with nothing run and nothing checked).

### Step 6 detail: rationale and wording

Scan the plan once for conflicts **before Phase A runs**, writing down what you
checked as you check it. A contradiction found before task 1 costs a ruling; the same
contradiction found at Phase H costs everything built on top of it.

The scan's output is a **table, not a verdict**. Two kinds of row, both required:

Rule on every finding before execution begins: weigh it against the plan text with the spec
as the binding authority, and record the **ruling** beside its row. If the scan is genuinely
clean — rows written, nothing found — proceed without further comment. The review loop
remains the net for conflicts that only emerge from implementation.
