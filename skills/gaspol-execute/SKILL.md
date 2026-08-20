---
name: gaspol-execute
description: "Use when you have a written implementation plan to execute. Enforces anti-placeholder rules, per-phase checkpoints, CLAUDE.md-first approach, and mandatory completion gates. NEVER silently substitute placeholders for real integrations."
---

# gaspol-execute

> "What gets planned gets built — with real data, real integrations, real verification."

## Overview

This is the execution engine for Sparkfluence. When a plan exists in `docs/plans/`, this skill ensures it gets implemented with **FULL FIDELITY** — meaning every integration point, data source, and component described in the plan is built with real, working code.

**Announce at start:**
> "I'm using the gaspol-execute skill to implement the plan at `[plan path]`. Every phase will have a checkpoint report and no placeholders will be substituted for real integrations without your explicit approval."

### Why This Skill Exists

Execution is where plans die. The three most common failure modes are:

1. **Placeholder Substitution** — Plan says "integrate with WorkspaceContext" but implementer writes `const segments = [{id: 1, text: 'Sample'}]` because it's faster.
2. **Step Skipping** — Phase 3 is "hard" so it gets combined with Phase 4, and half the requirements disappear.
3. **Phantom Completion** — "It's done!" but nobody ran the code, checked for TODOs, or verified data flows.

This skill makes all three impossible through enforcement rules, checkpoint gates, and mandatory verification.

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

Read the plan file from `docs/plans/` completely. Not skimming — read every section, every phase, every bullet point. Identify:

- Total number of phases
- Dependencies between phases
- External integrations required (APIs, hooks, contexts, tables)
- Files that will be created vs. modified
- Data flow: where does each piece of data originate and terminate?

If the plan has gaps, contradictions, or unclear instructions — raise them NOW, before writing code.

### Step 2: Read CLAUDE.md

Read `CLAUDE.md` in its entirety to understand:

- Existing routes and components (do NOT recreate what exists)
- Existing hooks and contexts (do NOT write new ones that duplicate existing)
- Database tables and their schemas (do NOT guess column names)
- Design system tokens (do NOT invent new colors or patterns)
- API key patterns (pool vs. env secrets)
- Edge Function conventions (CORS, response format, error handling)

### Step 3: Create TodoWrite (+ resume from durable ledger)

**Ledger path.** Use the plan's declared **Progress ledger** — its header names a per-plan
path, `.gaspol/progress/PROGRESS-<TICKET>.md` for plans written after IDS-1 Phase D. **Backward
compatibility:** older ledgers (`.gaspol/progress/<slug>.md`, or the shared
`.gaspol/progress.md` when the plan names no ledger at all) are STILL READ when the plan's
header names them — only NEW ledgers (from `gaspol-plan` step 7) use the `PROGRESS-<TICKET>.md`
path. Resolve this path once; read AND write the same file throughout.

**Resume read first.** If the resolved ledger exists, read it before
creating TodoWrite — it is the durable record of phases already completed in a prior
session or before a `/compact`. Restore those phases as `completed`. Then read the **LAST
line's handoff cursor**: `NEXT:` tells you exactly where to resume, and a `WIP`/`BLOCKER:`
line means the last phase was left unfinished — surface that blocker to the user and pick up
from its `NEXT:` action rather than blindly restarting the phase. Absent a cursor (older
ledger), fall back to continuing from the first unfinished phase. TodoWrite is in-memory and
is lost on compaction; the ledger is the source of truth for "where were we?".

**Initialize on first write (fallback only).** Plans written after IDS-1 Phase D already have
their ledger created by `gaspol-plan` at plan-write time — it exists before execute ever runs,
so this step is normally a no-op. For an older plan whose ledger does not exist yet, create it
(and its parent dir) with the same format `gaspol-plan` uses — see
`skills/gaspol-plan/SKILL.md` "Progress Ledger Format" for the exact template and the four
checklist states (`[ ]` todo / `[>]` in progress / `[x]` done / `[~]` cancelled, reason
mandatory) — a `## Checklist` line for every phase from the plan (all `[ ]`), and a `## Log`
with one line noting the plan/ticket. **`## Log` is always the last block** — never append a
section below it; `scan-active-ledgers` reads the file's last non-empty line to detect
active-vs-done. Skip this init step on resume — an existing ledger's checklist already
reflects prior progress.

Create a TodoWrite entry for EVERY phase in the plan. The mapping must be 1:1 — if the plan has 6 phases, the TodoWrite has 6 items. Do not combine phases. Do not add phases the plan doesn't have.

### Step 4: List Modified Files

Before touching any file, list ALL files that will be created or modified across ALL phases. This gives the user a clear picture of the blast radius.

### Step 5: Identify Reusable Code

From CLAUDE.md, extract everything that already exists and can be reused:

- Hooks: `useAuth`, `useChatSessions`, `useSessionPersistence`, etc.
- Contexts: `WorkspaceContext`, `AuthContext`, `OnboardingContext`, etc.
- Utilities: `apiKeyRotation.ts`, `orderIdGenerator.ts`, `supabase.ts`, etc.
- Components: Shadcn UI primitives, layout components, feature components
- Types: existing interfaces in `src/types/`
- Design tokens: color palette, component patterns, typography scales

Document which existing code will be used in each phase.

---

## CLAUDE.md-First Rule

Before starting ANY phase, consult CLAUDE.md. This is not optional.

### What to Extract

| Category | What to Look For | Why |
|----------|-----------------|-----|
| Routes | Existing route structure in `index.tsx` | Avoid route conflicts |
| Hooks | Listed hooks and their signatures | Use existing, don't duplicate |
| Contexts | Provider hierarchy and available state | Access data correctly |
| Tables | Schema, columns, RLS policies | Query correctly |
| API Endpoints | Edge Functions and their I/O format | Call correctly |
| Design Tokens | Colors, spacing, component patterns | Match existing UI |
| Conventions | Naming, file organization, patterns | Stay consistent |

### What This Prevents

- Creating `useSegmentData()` when `useWorkspace()` already provides segments
- Adding a new route that conflicts with existing redirects
- Using `#7C3AED` (purple) instead of `#10B981` (emerald)
- Calling `Deno.env.get('OPENROUTER_API_KEY')` when OpenRouter keys are in the pool table
- Creating `src/utils/helpers.ts` when utilities belong in `src/lib/`

---

## Laziness Gate (before writing code for any phase)

Anti-placeholder guarantees the code is REAL; the laziness ladder guarantees it is MINIMAL. Both fire, they do not conflict. Before implementing a phase, run the ladder from `skills/_shared/laziness-ladder.md`:

1. Does this need to exist? YAGNI → skip, one-line why.
2. Stdlib → native platform feature → already-installed dep → one line → only then minimum code.
3. No unrequested abstraction, no scaffolding "for later." Fewest files, shortest diff.

**Boundary (critical, do not misread):** the ladder cuts SCOPE, never FIDELITY. It NEVER excuses a placeholder when the plan specifies a real integration, nor skipping validation/security/tests. `const data = []` awaiting an API is a PLACEHOLDER (Iron Law 1), not a lazy one-liner — see the Data Source Classification below. If a "lazy" move would cross into fake data or a skipped safety check, it is negligent, not lazy: do the real thing. Mark deliberate simplifications with a `ponytail:` comment naming the upgrade path.

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

| Data Source | Status | Example Code |
|------------|--------|--------------|
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
6. **The tick-then-append gate (BLOCKING).** After presenting the checkpoint, and BEFORE the next
   phase starts, update the plan's resolved ledger (`.gaspol/progress/PROGRESS-<TICKET>.md`
   for new plans; older ledgers per the backward-compat rule in Step 3 above) in two places —
   this is blocking, like a test gate: no next phase until BOTH are written, never batched at
   the end, because a crash mid-run must leave a truthful state, not a stale one:
   - **(a) Tick the Checklist (in-place edit):** flip this phase's `## Checklist` line from
     `- [ ] Phase [X]: [name]` to `- [x] Phase [X]: [name] — DONE` on completion; to
     `- [>] Phase [X]: [name] — DOING` when the phase starts; or to
     `- [~] Phase [X]: [name] — <short reason>` if the phase is cancelled/skipped (a reason is
     MANDATORY on the line, with detail in the Log). This is the at-a-glance progress
     view — open the file, see what's done, without reading the whole log.
   - **(b) Append to the Log:** add one line —
     `Phase [X] [name] — COMPLETE — <1-line summary> — NEXT: <phase X+1 name, or "DONE" if last phase>`.
     If a phase is left **unfinished** (a blocker, an approaching `/compact`, or you pause mid-phase), append instead:
     `Phase [X] [name] — WIP — <what's done so far> — BLOCKER: <what's stuck / why paused> — NEXT: <the exact action to resume>`.
   The trailing `NEXT:`/`BLOCKER:` fields are the **handoff cursor** — a resumed session reads the LAST log line to
   know precisely where to continue and what's blocking, instead of inferring "first unfinished phase". Older
   lines without the suffix still parse (backward-compatible; NEXT/BLOCKER are additive).
   This survives `/compact` and session restart, so a resumed session knows exactly which
   phases are done (see Step 3 resume read + checklist state). **Never** write the ledger under `.git/` —
   Claude Code treats `.git/` as a protected path and blocks agent writes there. Ensure the
   project `.gitignore` contains `.gaspol/` (it is working-tree scratch, never committed).
   Caveat: `git clean -fdx` deletes it — recover phase state from `git log` if that happens.

### Checkpoint Template Summary

```
## Phase [X] Complete: [Phase Name]

### Implemented:
- [feature] with [real data source]

### Data Sources:
| Component | Data Source | Type |
|-----------|-----------|------|
| [name] | [source] | Real / Placeholder |

### Files Modified:
- [file path] (created/modified)

### Deviations from Plan:
- None / [description + justification]

### Next Phase: [X+1] — [description]
-> Waiting for approval before proceeding.
```

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

- Read the plan file from `docs/plans/`
- Read CLAUDE.md for architecture context
- Identify all phases, dependencies, and data flows
- Raise any concerns about gaps or contradictions
- Create TodoWrite with 1:1 phase mapping

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

Before generating the checkpoint, run the **complexity classifier**:

```
Classify this phase:
- Count files changed in this phase: git diff --stat <phase-start-sha>..HEAD -- <phase-files>
- Count LoC changed: sum of additions + deletions from git diff --stat
- Detect phase kind from description keywords:
  - docs-only: all changed files match *.md OR README* OR CLAUDE.md
  - config-only: all changed files match *.json OR *.yaml OR *.yml OR *.toml OR .env*
  - rename-only: diff is purely whitespace OR imports reorder OR variable rename
  - new-feature: description contains "implement", "create", "add feature", "new component", "introduce", "build"
  - refactor: description contains "refactor", "restructure", "reorganize"

Result:
- REVIEW if: files_changed > 3 OR LoC > 100 OR kind == new-feature
- SKIP if: docs-only OR config-only OR rename-only (regardless of size)
```

If result = `REVIEW`:
- Dispatch `code-reviewer` agent (Sonnet per rubric) for the phase's changes only
- Include review summary in checkpoint (3-5 bullets, criticality counts)
- Review findings influence checkpoint options

If result = `SKIP`:
- Note in checkpoint: "Auto-review skipped — [reason]"
- Proceed to Step 4

**Step 3.5: Design Fidelity Audit (for UI phases only)**

If the phase involves UI work (detected by: file extensions changed include `.tsx/.jsx/.vue/.svelte/.astro/.css/.scss`, OR phase description mentions UI component/layout/design):

```bash
python3 skills/gaspol-verify/scripts/design_audit.py <project-root> --json
```

Output analyzed for:
- Hardcoded colors (should use design tokens from CLAUDE.md)
- Hardcoded fonts (should use design system)
- Missing responsive breakpoints
- Missing component states (loading/error/empty)
- Accessibility gaps (ARIA, semantic HTML, keyboard nav)

Include Design Audit section in checkpoint:
```markdown
### Design Fidelity Audit (Phase X — UI work detected)
Hardcoded colors: N violations
Hardcoded fonts: N violations
Missing states: [list]
A11y gaps: [list]
Verdict: 🟢 COMPLIANT / 🟡 PARTIAL / 🔴 NON-COMPLIANT
```

If NON-COMPLIANT → treat as critical review finding (blocks phase approval unless user override with documented reason).
If PARTIAL → include in checkpoint as review finding for user decision.
If COMPLIANT → note pass, proceed.

Skip Step 3.5 entirely for non-UI phases (backend, config, docs).

**Step 3.6: Security Review (for security-sensitive phases only)**

If the phase touched **auth/authorization, secrets/credentials, user input or file
uploads, a new API endpoint, payment, or sensitive data** (detected from the phase
description or changed files), run the built-in **`/security-review`** slash command against
the phase's changes. It ships with the Claude Code CLI — no plugin, no install.

Include a Security Review section in the checkpoint:
```markdown
### Security Review (Phase X — security-sensitive change detected)
Triggered by: [auth | secrets | user-input | endpoint | payment | sensitive-data]
Findings: [secrets/SQLi/authz/XSS/etc. — pass or specific issue]
Verdict: 🟢 PASS / 🟡 ISSUES (list) / 🔴 FAIL (insecure pattern shipped)
```

A 🔴 FAIL (e.g. string-concatenated SQL, JWT in `localStorage`) is a critical finding
and blocks phase approval unless the user explicitly accepts the risk with a reason.
Skip Step 3.6 entirely for non-security phases (UI-only, docs, config).

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

After all phases pass the completion gate:

1. **plan-verifier** agent (BLOCKING) — Step-level evidence-based audit. See `agents/plan-verifier.md`.
   - Parse plan into granular items
   - Verdict per item: FOUND (with code quote) / PARTIAL / MISSING / DIVERGED
   - Orchestrator spot-checks 3 random FOUND items for quote accuracy
   - If verdict = `BLOCKING` (MISSING > 0 OR unapproved PARTIAL > 0 OR placeholders > 0):
     - STOP. Do NOT claim implementation complete.
     - Present issues via AskUserQuestion per finding
     - Fix or defer with ADR, then re-run plan-verifier
   - If verdict = `CLEAN`, proceed to remaining chain.
2. **gaspol-verify** — Run type checking, linting, build verification
3. **gaspol-sync-docs** — Update CLAUDE.md with new routes, hooks, tables, etc.
4. **gaspol-review** — Code quality review for consistency and best practices

---

## Completion Gate

**MANDATORY before claiming the implementation is done.**

### Scan All Changed Files For:

```
// TODO
// FIXME
// placeholder
// mock
// dummy
// temp
// hack
// PLACEHOLDER
// MOCK
// DUMMY
// TEMP
// HACK
```

### Also Check For:

- **Hardcoded arrays/objects** that the plan says should come from hooks, context, or API calls
- **Components that import zero hooks/context** but the plan says they should display dynamic data
- **Functions defined but never called** — dead code from incomplete integration
- **`console.log` statements** left in production code (not inside `if (import.meta.env.DEV)`)
- **Empty event handlers** — `onClick={() => {}}` that should have real logic
- **Commented-out code blocks** — real implementation replaced with comments
- **Magic numbers/strings** — hardcoded values that should come from config or constants

### If ANY Issues Found:

Report them in a structured list:

```
## Completion Gate: BLOCKED

### Issues Found:
1. [file:line] — `// TODO: connect to API` — placeholder comment
2. [file:line] — `const segments = []` — empty array, plan says use WorkspaceContext
3. [file:line] — `console.log('debug')` — remove before completion

### Action Required:
Fix these issues or get explicit user approval to ship with them.
```

Do NOT claim the implementation is complete. Do NOT move to the verification chain.

---

## When to Stop Executing

Stop execution and consult the user when:

| Situation | Action |
|-----------|--------|
| **Blocker** — dependency not available, API not ready, missing credentials | Report the blocker, suggest alternatives, wait for guidance |
| **Gap in plan** — instructions unclear, contradictory, or missing detail | Quote the unclear section, propose interpretation, wait for confirmation |
| **Repeated failure** — same verification failing after 2 attempts | Report what was tried, share error details, ask for help |
| **Plan drift** — what you are building no longer matches the plan | Stop, compare plan vs. reality, report the divergence |
| **Scope creep** — you want to add something the plan does not mention | Ask first. The plan is the spec. |
| **Architecture conflict** — plan contradicts CLAUDE.md conventions | Report the conflict, recommend the CLAUDE.md approach, wait for decision |

---

## Red Flags

If you observe any of these during execution, STOP and reassess.

| Red Flag | What It Means | Correct Action |
|----------|--------------|----------------|
| About to write `const data = [...]` | PLACEHOLDER — check plan for real source | Trace data source, implement real integration |
| "I'll connect this to the API later" | Deferring real work | Connect NOW or ask user for explicit skip |
| Skipping a plan phase without asking | VIOLATION of Law 2 | Ask user before skipping any phase |
| "This is basically done" without running code | VIOLATION of Law 3 | Run completion gate scan first |
| Creating a new hook that CLAUDE.md already lists | Didn't read CLAUDE.md | Use the existing hook |
| Batch-completing 3+ phases without checkpoints | VIOLATION of checkpoint rules | One phase, one checkpoint, one approval |
| "Close enough to the plan" | Plan drift without acknowledgment | Compare explicitly, report deviations |
| Component has no imports from hooks/context | Likely using hardcoded data | Verify data source against plan |
| File has more than 3 TODO comments | Incomplete implementation | Resolve TODOs or flag to user |
| Test file created but no assertions written | Phantom test coverage | Write real assertions or flag as incomplete |

---

## Rationalization Prevention

These are the excuses that lead to placeholder-riddled codebases. None of them are valid.

| Excuse | Reality | Correct Action |
|--------|---------|----------------|
| "I'll add real data later" | "Later" never comes. | Add it now or ask user to explicitly defer. |
| "The plan didn't specify exact implementation" | The Data Integration Map IS the specification. | Trace the data flow and implement it. |
| "This placeholder is temporary" | Placeholders become permanent. | Ask user before adding any placeholder. |
| "The hook doesn't exist yet" | That's your job to create it. | Create the hook or flag as a blocker. |
| "It works the same with mock data" | Works does not equal Complete. | Plan says real integration. Do real integration. |
| "Just this one component" | One placeholder leads to many. No exceptions. | Apply the same standard everywhere. |
| "I'm confident the rest is fine" | Confidence is not evidence. | Run the completion gate scan. |
| "Minor deviation from plan" | You don't decide what's minor. | Report it. Let user decide. |
| "The API isn't ready yet" | Valid blocker. But don't silently mock it. | Report the blocker, wait for guidance. |
| "This is just the UI layer" | UI with fake data is a fake UI. | Connect it to real state/data. |
| "I'll clean up the TODOs at the end" | TODOs accumulate and get forgotten. | Resolve each TODO as you go. |
| "The user won't notice" | The user WILL notice. That's why this skill exists. | Build it right the first time. |

---

## Integration with Other Skills

### Upstream (provides input to this skill)

| Skill | What It Provides |
|-------|-----------------|
| `gaspol-plan` | The implementation plan in `docs/plans/` |
| `gaspol-brainstorm` | Design decisions and component specifications |

### Downstream (triggered after this skill completes)

| Skill | When Triggered | Purpose |
|-------|---------------|---------|
| `gaspol-verify` | After completion gate passes | Type checking, linting, build verification |
| `gaspol-sync-docs` | After verification passes | Update CLAUDE.md with new code artifacts |
| `gaspol-review` | After docs sync | Code quality and consistency review |
| `gaspol-finish` | After review passes | Merge, PR creation, cleanup |

### Parallel Execution (optional)

When used with `gaspol-parallel`, this skill dispatches implementer subagents using the template in `implementer-prompt.md`. Each subagent receives:

- Full task description from the plan
- Relevant CLAUDE.md context
- Anti-placeholder rules
- Self-review checklist

---

## Quick Reference Card

```
BEFORE CODING:
  1. Read plan file completely
  2. Read CLAUDE.md completely
  3. Create TodoWrite (1:1 with plan phases)
  4. List all files to be modified
  5. Identify reusable code from CLAUDE.md

DURING EACH PHASE:
  1. Mark phase in_progress
  2. Trace every data source before implementing
  3. If about to hardcode → STOP → ask user
  4. Follow CLAUDE.md design system
  5. Mark phase completed
  6. Present checkpoint report
  7. Wait for approval

AFTER ALL PHASES:
  1. Run completion gate scan
  2. Fix or report all issues
  3. Auto-invoke: verify → sync-docs → review
  4. Only THEN claim complete
```

---

## Failure Recovery

If a phase fails mid-execution:

1. **Do not undo completed work** unless it caused the failure
2. **Report exactly what failed** — error messages, file locations, expected vs. actual
3. **Propose a fix** — but wait for user approval before implementing
4. **If the fix requires plan changes** — flag this as plan drift
5. **After fixing, re-run the phase checkpoint** — do not skip verification

If the completion gate fails:

1. **List all blocking issues** with file paths and line numbers
2. **Categorize each issue** — placeholder, TODO, dead code, console.log, etc.
3. **Propose fixes for each** — but wait for user to prioritize
4. **After fixes, re-run the completion gate** — must pass clean

---

*This skill is the difference between "it compiles" and "it works as planned." Treat every phase as if the user is watching over your shoulder — because they are.*
