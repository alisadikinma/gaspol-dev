---
name: gaspol-execute
description: "Use when you have a written implementation plan to execute. Enforces anti-placeholder rules, per-phase checkpoints, CLAUDE.md-first approach, and mandatory completion gates. NEVER silently substitute placeholders for real integrations."
---

# gaspol-execute

## Overview

The execution engine. Given a plan in `docs/plans/`, it implements every integration point, data source, and component with real working code — full fidelity, no substitutions.

**Announce at start:**
> "I'm using the gaspol-execute skill to implement the plan at `[plan path]`. Every phase will have a checkpoint report and no placeholders will be substituted for real integrations without your explicit approval."

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

Read `references/pre-execution.md` when running Steps 0-5: it holds their full text, the conflict-matrix table, and the CLAUDE.md-First Rule.

- **Step 0:** run `skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress`. Filenames printed that do NOT belong to the plan you're about to execute → STOP and ask with **AskUserQuestion** (4 options, in the reference). Do not proceed into Step 1 until the user has chosen.
- **Step 1:** read the plan in `docs/plans/` completely. Gaps, contradictions, or unclear instructions get raised NOW, before any code.
- **Step 2:** read the target project's `CLAUDE.md` in full.
- **Step 3:** older ledgers (`.gaspol/progress/<slug>.md`, or the shared `.gaspol/progress.md` when the plan names none) are still read when the plan's header names them; only NEW ledgers use `PROGRESS-<TICKET>.md`. Resume from the durable ledger's last-line `NEXT:` cursor, then create TodoWrite. TodoWrite maps **1:1** with the plan's phases — six phases, six items. Do not combine phases, do not invent phases the plan does not have. **Older flat** ledgers (one line per
  phase) are read as-is and never reshaped.
- **Steps 4-5:** list ALL files that will be created or modified across ALL phases, and what already exists and will be reused rather than rebuilt.

### Step 6: Pre-Flight Conflict Matrix (BLOCKING — before Phase A runs)

Scan the plan once for conflicts **before Phase A runs**, writing down what you
checked as you check it.

The scan's output is a **table, not a verdict**. Two kinds of row, both required: cross-task, one row for every pair of tasks that **share a file** or an interface; and self-consistency, one row per task — whether its own text **agrees with itself**.

**"The scan is clean" without those rows is not a scan that ran.** Write the table to the
ledger — **above `## Log`**, never below it, because `scan-active-ledgers` reads the file's
last non-empty line and anything under `## Log` breaks active-vs-done detection.

Rule on every finding before execution begins: weigh it against the plan text with the spec
as the binding authority, and record the **ruling** beside its row.

### Step 7: Verification Baseline (BLOCKING — before Phase A runs)

Derive the commands, then run them **once, before any phase**:

```bash
skills/gaspol-execute/scripts/detect-stack <project-root>
```

Three states, never blurred: `<level>: <command>` → run it; `<level>: UNKNOWN` (marker present,
tool missing) → **STOP and ask**; **no stack markers / zero lines** → fall back to the
plan-declared commands, recorded as `detect-stack: no stack markers, using plan-declared commands`.

Run the ladder and write the result to the ledger.

**If the baseline is already red, STOP and ask** (`AskUserQuestion`): `[Fix the baseline first]` /
`[Proceed, treating these N failures as pre-existing]` / `[Something else]`. On "proceed", record
the failing test names; phases are then judged against **new** failures only.

## Verification Loop (per phase — the checkpoint's evidence comes from here)

Full rule: **[skills/_shared/verification-loop.md](../_shared/verification-loop.md)**. Same ladder
the implementer dispatch templates have carried since v1.8; one source, do not restate its detail.

After the code of a phase is written and **before its checkpoint**, run the ladder **fail-fast**,
cheapest first — **L1** static (typecheck + lint) → **L2** unit → **L3** build → L4 integration →
L5 edge. Stop at the first failure.

- **Proportionality:** a `docs-only` / `config-only` / `rename-only` phase — the classes the
  complexity classifier already knows — skips L2 and L3, and still runs L1 where a linter covers
  those files. A level that does not apply is skipped **explicitly, with the reason**; a silent
  skip is a placeholder-grade lie.
- **On failure:** feed the failing command's **actual output, verbatim** into the fix — never a
  paraphrase; you already hold the fact. Fix the cause, then **re-run from the failed level**.
  Three failed attempts on one error is a `gaspol-debug` problem, not a retry problem.
- **Bounded** by [skills/_shared/fix-loop.md](../_shared/fix-loop.md). The round cap lives there
  and is deliberately not repeated here.

**The gate:** a phase **may not be ticked** `[x]` until its ladder ran and every applicable level
passed or was explicitly skipped with a reason. "The code looks right" and "the review found
nothing" are opinions; an exit code is evidence. This is the TDD gate's mirror — TDD refuses a
phase with no failing test before, this refuses one with no passing run after.

## Design Artifact Check (before Phase A, before any code)

Read the ledger before starting. `gaspol-plan`'s post-plan offer records one line above `## Log`:

| Ledger line | Action |
|---|---|
| `design-artifact: approved — <url>` | proceed |
| `design-artifact: pending — <url>` | **STOP and ask** — published, never approved |
| `design-artifact: skipped — <reason>` | proceed; the decision is recorded |
| no such line | proceed, recording `design-artifact: none — no offer was made` |

**This skill never presents the offer** — it lives in `gaspol-plan` alone. A missing line therefore
proceeds: stopping would send the user back for a question nobody asks here.

**An empty reason is not a decision.** A `skipped` line with nothing after the dash is treated as
`pending` — **STOP and ask**.

## Completeness Gate (before writing code for any phase, and again before calling it done)

Anti-placeholder guarantees the code is REAL; the Completeness Ladder guarantees it is WHOLE.
Both fire. Walk the ladder from `skills/_shared/completeness-ladder.md` — **down**, doing every
rung, not stopping at the first that holds:

Read `references/execution-flow.md` when walking the rungs: it holds the six of them.

Before ticking the phase, state which rungs it owed and where each is covered. A rung that does
not apply is skipped **explicitly** — a silent skip is a placeholder-grade lie.

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

The REAL-vs-PLACEHOLDER table lives in [anti-placeholder-rules.md](anti-placeholder-rules.md).
When a case is not obvious, open the reference — do not guess.

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
   next phase starts, the orchestrating session (never a dispatched implementer) updates the
   plan's resolved ledger in three places. Blocking like a test gate: no next phase until all
   three are written, never batched at the end — a crash must leave a truthful state.
   Read `references/execution-flow.md` when writing the ledger: it holds the three places
   (Checklist tick, `## Phase log` row with the real SHA, `## Log` line with the handoff cursor).

After the **6th** phase completed in this run, and every 6th after it, Read
`references/execution-flow.md` when that checkpoint is presented: it holds the Session-Length Checkpoint.

---

## Execution Flow

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

If phase description HAS the TDD step, execute step 1 FIRST (write failing test, run it, verify expected failure), and only then implement production code to pass the test. If blocked on a real integration, STOP and ask — do not substitute. Read `references/execution-flow.md` when starting a phase: it holds the full proceed list.

### Step 3: Phase Checkpoint Report (with Tiered Auto-Review)

Before generating the checkpoint, run the **complexity classifier** over this phase's changes
(`git diff --stat <phase-start-sha>..HEAD`):

- **SKIP** the review when every changed file is docs (`*.md`, `README*`, `CLAUDE.md`),
  config (`*.json`, `*.yaml`, `*.yml`, `*.toml`, `.env*`), or the diff is purely a rename,
  import reorder, or whitespace — regardless of size. Note it in the checkpoint:
  "Auto-review skipped — [reason]".
- **REVIEW** only when a trigger fires: more than 3 files changed, more than 100 lines
  changed, or the phase describes new work ("implement", "create", "add feature", "new
  component", "introduce", "build"). Anything else is SKIP, noted in the checkpoint as
  "Auto-review skipped — below the review triggers"; `gaspol-finish` reads the whole branch later.

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

Then present the structured checkpoint report (see `checkpoint-template.md`) with every
component's data source classified, all files, any deviations, and the Auto-Review section.

### Step 4: Wait for User Approval

- Use the **AskUserQuestion** tool (MANDATORY) to get approval — this shows an interactive popup modal
- Do NOT proceed until the user explicitly approves via the popup

### Step 5: Repeat

Return to Step 2 for the next phase until all phases are complete.

### Step 6: Completion Gate

- Scan ALL changed files for placeholder indicators (see below)
- Scan for unused functions, orphaned imports, console.log statements
- Report findings — do NOT claim complete if issues exist

### Step 7: Hand Off to gaspol-finish

Once all phases pass the completion gate, stop gating here. `gaspol-finish` owns the
end-of-ticket gates and runs each once: the full `gaspol-verify`, `plan-verifier`,
`gaspol-review` and `gaspol-sync-docs`. This skill keeps the per-phase ladder and the Completion
Gate; it does not repeat the owner's gates. Until `gaspol-finish` runs, the work is not verified.

### Step 8: Present the Finish Offer

Finishing is an offer, not the automatic next step. Present it exactly as
[_shared/finish-offer.md](../_shared/finish-offer.md) states — options, deferral cursor,
non-empty-reason rule, error paths. Never restate it here; a copy drifts.

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

## Integration with Other Skills

**Downstream:** the finish offer ([_shared/finish-offer.md](../_shared/finish-offer.md)), which
the user may decline. `gaspol-finish` owns `gaspol-verify`, `plan-verifier`, `gaspol-review` and
`gaspol-sync-docs`.

**With `gaspol-parallel`:** implementer subagents are dispatched using
[implementer-prompt.md](implementer-prompt.md) — each gets its task-scoped brief path, the
relevant CLAUDE.md context, the anti-placeholder rules, and the self-review checklist.

---

## Failure Recovery

If a phase fails mid-execution, Read `references/execution-flow.md` when recovering: it holds the
recovery steps. If the completion gate fails:

1. **List all blocking issues** with file paths and line numbers
2. **Categorize each issue** — placeholder, TODO, dead code, console.log, etc.
3. **Propose fixes for each** — but wait for user to prioritize
4. **After fixes, re-run the completion gate** — must pass clean

*This skill is the difference between "it compiles" and "it works as planned." Treat every phase as if the user is watching over your shoulder — because they are.*
