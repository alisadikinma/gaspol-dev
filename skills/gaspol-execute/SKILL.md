---
name: gaspol-execute
description: "Use when you have a written implementation plan to execute. Enforces anti-placeholder rules, per-phase checkpoints, CLAUDE.md-first approach, and mandatory completion gates. NEVER silently substitute placeholders for real integrations."
---

# gaspol-execute

> "What gets planned gets built — with real data, real integrations, real verification."

## Overview

The execution engine. Given a plan in `docs/plans/`, it implements every integration point, data source, and component with real working code — full fidelity, no substitutions.

**Announce at start:**
> "I'm using the gaspol-execute skill to implement the plan at `[plan path]`. Every phase will have a checkpoint report and no placeholders will be substituted for real integrations without your explicit approval."

Execution is where plans die, in three ways this skill exists to make impossible:
**placeholder substitution** (plan says integrate, implementer hardcodes because it is faster),
**step skipping** (a hard phase gets folded into the next one and half its requirements vanish),
and **phantom completion** ("it's done" with nothing run and nothing checked).

---

## The Iron Laws

These are non-negotiable. No rationalization overrides them.

```
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

Every decision during execution must pass through these three laws. If a decision violates any law, STOP and ask the user.

---

## Pre-Execution Protocol

**MANDATORY before writing ANY code.** Do not skip any step.

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
is normally a no-op. For an older plan without one, create it in the format in
`skills/gaspol-plan/SKILL.md` "Progress Ledger Format" — a `## Checklist` line per phase (all
`[ ]`; states are `[ ]` todo / `[>]` doing / `[x]` done / `[~]` cancelled with a mandatory
reason) above a `## Log`. **`## Log` is always the last block** — `scan-active-ledgers` reads
the file's last non-empty line, so nothing may be appended below it.

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

### Step 6: Pre-Flight Conflict Matrix (BLOCKING — before Phase A runs)

Scan the plan once for conflicts **before Phase A runs**, writing down what you
checked as you check it. A contradiction found before task 1 costs a ruling; the same
contradiction found at Phase H costs everything built on top of it.

The scan's output is a **table, not a verdict**. Two kinds of row, both required:

| Kind | One row for | Columns |
|---|---|---|
| Cross-task | every pair of tasks that **share a file** or an interface | the two tasks · what one produces against what the other consumes · the finding |
| Self-consistency | every task — whether its own text **agrees with itself** | the task · its tests against the code it specifies, the files it creates against the files it later touches · the finding |

Also flag anything the plan explicitly mandates that the review rubric treats as a defect
(a test that asserts nothing, a verbatim-duplicated logic block).

**"The scan is clean" without those rows is not a scan that ran.** Write the table to the
ledger — **above `## Log`**, never below it, because `scan-active-ledgers` reads the file's
last non-empty line and anything under `## Log` breaks active-vs-done detection.

Rule on every finding before execution begins: weigh it against the plan text with the spec
as the binding authority, and record the **ruling** beside its row. If the scan is genuinely
clean — rows written, nothing found — proceed without further comment. The review loop
remains the net for conflicts that only emerge from implementation.

## CLAUDE.md-First Rule

Pre-Execution Step 2 is not a formality. Reading the target project's CLAUDE.md before any
exploration is what prevents the four expensive mistakes: recreating a hook or context that
already exists, guessing at column names that are written down, inventing design tokens
beside a documented palette, and re-deriving a convention the project already settled. If
the plan names something you cannot find in CLAUDE.md, that is a question, not a licence to
invent.

## Design Artifact Gate (BLOCKING — before Phase A, before any code)

Read the ledger before starting. `gaspol-plan` Step 0 records one line above `## Log`:

| Ledger line | Action |
|---|---|
| `design-artifact: approved — <url>` | proceed |
| `design-artifact: pending — <url>` | **STOP and ask** — it was published and never approved |
| no such line | **STOP and ask** — return to `gaspol-plan` Step 0; do not write code |

Counterpart of the TDD gate: TDD refuses a phase with no failing test, this refuses a plan no
human has seen rendered. It applies to logic-only work too — that was the gap. There is no "not
applicable" verdict: an absent line means the artifact was not made, not that none was owed.

## Completeness Gate (before writing code for any phase, and again before calling it done)

Anti-placeholder guarantees the code is REAL; the Completeness Ladder guarantees it is WHOLE.
Both fire. Walk the ladder from `skills/_shared/completeness-ladder.md` — **down**, doing every
rung, not stopping at the first that holds:

1. happy path, real integration; 2. every error path that can actually happen; 3. every edge
case the input space allows — enumerate them, don't sample; 4. the tests that prove 1-3,
written first; 5. the observability a 3am debugger needs; 6. the one comment explaining WHY.

Before ticking the phase, state which rungs it owed and where each is covered. A rung that does
not apply is skipped **explicitly** — a silent skip is a placeholder-grade lie.

**Reuse, not volume:** prefer stdlib → native feature → already-installed dep over code you
author; no interface with one implementation. Reuse cuts cleverness, never coverage.

**Boundary:** completeness is depth on the REQUESTED work. It never licenses a placeholder where
the plan specifies a real integration (`const data = []` awaiting an API is an Iron Law 1
violation however thorough the rest is), and it is not licence to add features nobody asked for —
that is scope creep, flagged as separate scope. Only genuinely unrelated work stops the ladder.

## Anti-Placeholder Rules

**This is the most critical section of this skill.** Read `anti-placeholder-rules.md` for the full reference.

### The Core Rule

Before implementing ANY component that displays, processes, or transforms data:

1. **TRACE the data source.** Where does this data come from? A hook? A context? An API call? A prop?
2. **CHECK the plan.** Does the plan specify a real integration for this data?
3. **If YES** — implement the real integration. Period.
4. **If about to write hardcoded data** — STOP. You are about to create a placeholder.

### Decision Gate

If the plan says "integrate with X" but you are about to write `const data = [...]`:

**STOP.** Use the **AskUserQuestion** tool to present the user with three options (interactive popup modal):

- **(a) Implement real integration now** — the correct default
- **(b) Skip this step entirely** — user decides it's not needed yet
- **(c) Use placeholder with explicit TODO** — user accepts technical debt knowingly

**NEVER choose option (c) silently.** That is the entire point of this skill.

### Data Source Classification

The REAL-vs-PLACEHOLDER table lives in [anti-placeholder-rules.md](anti-placeholder-rules.md).
Shape of it: anything that arrives through a hook, context, edge function, real-sourced prop,
or a computation over those is REAL; a hardcoded array, an empty array awaiting an API, a
string literal standing in for dynamic content, a commented-out fetch, or a mock function is
a PLACEHOLDER. When a case is not obvious, open the reference — do not guess.

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

---

## Per-Phase Checkpoint

After completing EACH phase (not a batch of phases — EACH one), present a structured checkpoint report. See `checkpoint-template.md` for the exact format.

### Checkpoint Rules

1. **One phase, one checkpoint.** Never batch-complete multiple phases.
2. **Wait for approval.** Do not proceed to the next phase until the user says to continue.
3. **Report deviations.** If anything differs from the plan, explain what and why.
4. **Classify data sources.** Every component that handles data must list its source and whether it is real or placeholder.
5. **List all file changes.** Every file created or modified in the phase.
6. **The tick-then-append gate (BLOCKING).** After presenting the checkpoint and BEFORE the
   next phase starts, update the plan's resolved ledger in two places. This is blocking, like
   a test gate: no next phase until both are written, and never batched at the end — a crash
   mid-run must leave a truthful state, not a stale one.
   - **(a) Tick the Checklist, in place:** `- [x] Phase [X]: [name] — DONE` on completion,
     `- [>] … — DOING` when the phase starts, or `- [~] … — <short reason>` if cancelled or
     skipped (a reason on the line is MANDATORY, with detail in the Log).
   - **(b) Append one Log line:**
     `Phase [X] [name] — COMPLETE — <1-line summary> — NEXT: <next phase, or "DONE">`.
     If the phase is left unfinished (a blocker, an approaching `/compact`, a pause), append
     instead: `Phase [X] [name] — WIP — <done so far> — BLOCKER: <what is stuck> — NEXT: <exact resume action>`.

   The trailing `NEXT:`/`BLOCKER:` fields are the **handoff cursor** — a resumed session reads
   the last line to know where to continue and what is blocking, instead of inferring "first
   unfinished phase". Older lines without them still parse. **Never** write the ledger under
   `.git/` (a protected path — agent writes are blocked there), and keep `.gaspol/` in the
   project `.gitignore`; it is working-tree scratch. `git clean -fdx` deletes it, in which case
   recover phase state from `git log`.

### Checkpoint Template

The exact format is [checkpoint-template.md](checkpoint-template.md): Implemented · Data
Sources table (Real/Placeholder per component) · Files Modified · Deviations from Plan ·
Auto-Review · Next Phase, ending "Waiting for approval before proceeding."

### Session-Length Checkpoint (Context-Budget Nudge)

Count phases completed in the **current execute run** (phases restored from a prior session's ledger on resume do not count — only ones this run itself finishes). After presenting the checkpoint report for the **6th** phase completed in this run — and every 6th subsequent one (12th, 18th, ...) — use the **AskUserQuestion** tool:

> "N phases done this session. Continue here, or pick up fresh next session? The ledger (`.gaspol/progress/PROGRESS-<TICKET>.md`, or the plan's declared ledger path) has the exact resume point either way."

Options:
- **(a) Continue as normal** — proceed to the next phase immediately
- **(b) Stop here** — report the resume point clearly (the last ledger line's `NEXT:` cursor) and end the session
- **(c) Raise the threshold for this run** — user specifies N; don't ask again until N more phases complete

Do **not** fire before the 6th completed phase of the run. The first prompt fires only at the 6th completed phase, and repeats every 6th phase thereafter unless the user raised the threshold via (c).

---

## Execution Flow

### Step 1: Load and Review Plan

Pre-Execution Protocol Steps 1-3 and 6, already done: plan read, CLAUDE.md read, TodoWrite
created 1:1 with the phases, conflict matrix written to the ledger and ruled on.

### Step 2: Execute Phase (TDD Hard Gate)

**TDD Hard Gate (BLOCKING):** Before implementing anything, validate that the phase description contains a failing-test step as step 1. Required format:

```
1. Write failing test for [specific behavior]. Expected error: [error class/message].
```

If phase description does NOT have this as step 1:
- STOP execution
- Emit error: `"Phase [X] missing TDD gate. Plan template violation."`
- Use AskUserQuestion to present:
  - `[Update plan to add TDD step]` (default)
  - `[Skip TDD for this phase — acknowledge technical debt]` (creates ADR via gaspol-adr)
  - `[Abort execution]`
- Do NOT proceed without resolution

If phase description HAS the TDD step, proceed:
- Mark the current phase as `in_progress` in TodoWrite
- Execute step 1 FIRST (write failing test, run it, verify expected failure)
- Only then implement production code to pass the test
- Follow RED-GREEN-REFACTOR per `gaspol-tdd`
- For every data-displaying component, trace the data source
- For every integration point, implement the real connection
- If blocked on a real integration, STOP and ask — do not substitute
- Follow CLAUDE.md design system, naming conventions, and patterns

### Step 3: Phase Checkpoint Report (with Tiered Auto-Review)

Before generating the checkpoint, run the **complexity classifier** over this phase's changes
(`git diff --stat <phase-start-sha>..HEAD`):

- **SKIP** the review when every changed file is docs (`*.md`, `README*`, `CLAUDE.md`),
  config (`*.json`, `*.yaml`, `*.yml`, `*.toml`, `.env*`), or the diff is purely a rename,
  import reorder, or whitespace — regardless of size. Note it in the checkpoint:
  "Auto-review skipped — [reason]".
- **REVIEW** otherwise, and always when more than 3 files changed, more than 100 lines
  changed, or the phase describes new work ("implement", "create", "add feature", "new
  component", "introduce", "build").

On REVIEW: dispatch the `code-reviewer` agent (Sonnet per rubric) scoped to this phase's
changes only, and put 3-5 bullets plus criticality counts in the checkpoint. The findings
shape the checkpoint's options.

**Step 3.5: Design Fidelity Audit (UI phases only)**

If the phase changed `.tsx/.jsx/.vue/.svelte/.astro/.css/.scss` files, or its description
names a UI component, layout, or design:

```bash
python3 skills/gaspol-verify/scripts/design_audit.py <project-root> --json
```

Report hardcoded colours and fonts (should be design tokens), missing responsive breakpoints,
missing loading/error/empty states, and a11y gaps (ARIA, semantic HTML, keyboard nav) in a
**Design Fidelity Audit** checkpoint section with a verdict: 🟢 COMPLIANT / 🟡 PARTIAL /
🔴 NON-COMPLIANT. 🔴 is a critical finding and blocks phase approval unless the user overrides
with a documented reason; 🟡 goes to the user as a checkpoint finding. Skip this step entirely
for non-UI phases.

**Step 3.6: Security Review (security-sensitive phases only)**

If the phase touched **auth/authorization, secrets/credentials, user input or file uploads, a
new API endpoint, payment, or sensitive data**, run the built-in **`/security-review`** command
against the phase's changes (it ships with the Claude Code CLI — no plugin, no install). Record
what triggered it, the findings, and a verdict: 🟢 PASS / 🟡 ISSUES / 🔴 FAIL. A 🔴 (a
string-concatenated SQL query, a JWT in `localStorage`) is critical and blocks phase approval
unless the user explicitly accepts the risk with a reason. Skip entirely for non-security
phases.

Then:
- Present the structured checkpoint report (see `checkpoint-template.md`)
- List all components and their data sources with real/placeholder classification
- List all files created or modified
- Report any deviations from the plan with justification
- Include Auto-Review section with classifier result and findings
- Mark the phase as `completed` in TodoWrite

### Step 4: Wait for User Approval

- Use the **AskUserQuestion** tool (MANDATORY) to get approval — this shows an interactive popup modal
- Provide options: `[Approved — proceed to next phase]`, `[Address review feedback first]` (only if auto-review surfaced findings), `[Changes needed (I'll explain)]`, `[Skip this phase]`, `[Stop execution]`
- Do NOT proceed until the user explicitly approves via the popup
- If the user requests changes, implement them before moving on
- If auto-review findings exist and user proceeds without addressing, log as technical debt (candidate for gaspol-adr capture)
- If the user skips a phase, acknowledge and note the skip

### Step 5: Repeat

- Return to Step 2 for the next phase
- Continue until all phases are complete

### Step 6: Completion Gate

- Scan ALL changed files for placeholder indicators (see below)
- Scan for unused functions, orphaned imports, console.log statements
- Report findings — do NOT claim complete if issues exist

### Step 7: Auto-Invoke Verification Chain (Plan-Verifier BLOCKING)

Once all phases pass the completion gate, in order:

1. **plan-verifier** agent — **BLOCKING**, step-level and evidence-based (see
   `agents/plan-verifier.md`). It parses the plan into granular items and returns FOUND (with a
   code quote) / PARTIAL / MISSING / DIVERGED per item; you spot-check 3 random FOUND items for
   quote accuracy. Verdict `BLOCKING` (any MISSING, any unapproved PARTIAL, any placeholder) →
   STOP, do not claim completion, present each finding via AskUserQuestion, fix or defer with an
   ADR, then re-run it. Verdict `CLEAN` → continue.
2. **gaspol-verify** — type check, lint, build.
3. **gaspol-sync-docs** — update CLAUDE.md with new routes, hooks, tables.
4. **gaspol-review** — code quality and consistency.

---

## Completion Gate

**MANDATORY before claiming the implementation is done.** Scan every changed file for
`TODO` / `FIXME` / `placeholder` / `mock` / `dummy` / `temp` / `hack` (either case), and for
the seven things a grep will not catch:

- hardcoded arrays or objects where the plan says hook, context, or API;
- components importing no hook or context while the plan says they show dynamic data;
- functions defined and never called — dead ends from an unfinished integration;
- `console.log` outside a dev guard;
- empty handlers (`onClick={() => {}}`) that should carry real logic;
- commented-out blocks standing in for the implementation;
- magic numbers and strings that belong in config or constants.

Any hit and the gate is **BLOCKED**. Report each as `[file:line] — <the offending code> —
<why it fails>`, then either fix them or get explicit user approval to ship with them. Do NOT
claim completion and do NOT enter the verification chain while the gate is blocked.

---

## When to Stop Executing

Stop and consult the user on: a **blocker** (dependency, API, or credential not available —
report it, suggest alternatives, wait); a **gap in the plan** (quote the unclear section,
propose your reading, wait for confirmation); **repeated failure** (the same verification
failing after two attempts — report what was tried with the errors); **plan drift** (what you
are building no longer matches the plan — stop and report the divergence); **scope creep**
(you want to add something the plan does not mention — ask first; the plan is the spec); and
an **architecture conflict** (the plan contradicts CLAUDE.md — report it, recommend the
CLAUDE.md approach, wait for the decision).

---

## Red Flags and Rationalizations

The full table — every excuse that produces a placeholder-riddled codebase, what it really
is, and the correct action — lives in
[anti-placeholder-rules.md](anti-placeholder-rules.md). It is consulted, not read start to
finish. The four that catch most of them:

- About to write `const data = [...]` → trace the source, implement the real integration.
- "I'll connect it later" / "temporary" → later never comes; connect now or get an explicit
  user deferral.
- "This is basically done" / "I'm confident" → confidence is not evidence; run the
  Completion Gate scan.
- Batch-completing phases, or skipping one without asking → Law 2 and the checkpoint rules;
  one phase, one checkpoint, one approval.

---

## Integration with Other Skills

**Upstream:** `gaspol-plan` provides the plan in `docs/plans/`; `gaspol-brainstorm` provides
the design decisions behind it.

**Downstream, in order:** `gaspol-verify` (once the completion gate passes) → `gaspol-sync-docs`
→ `gaspol-review` → `gaspol-finish`.

**With `gaspol-parallel`:** implementer subagents are dispatched using
[implementer-prompt.md](implementer-prompt.md) — each gets its task-scoped brief path, the
relevant CLAUDE.md context, the anti-placeholder rules, and the self-review checklist.

---

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

---

*This skill is the difference between "it compiles" and "it works as planned." Treat every phase as if the user is watching over your shoulder — because they are.*
