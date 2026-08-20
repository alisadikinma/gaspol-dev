---
name: gaspol-plan
description: "Use when you have a spec or requirements for a multi-step task, before touching code. Creates comprehensive plans with mandatory Data Integration Maps and per-phase verification criteria."
---

# gaspol-plan

## Overview

Write comprehensive implementation plans assuming the executor has **zero context** and **questionable taste**. Every plan includes:

- A **Data Integration Map** (contract for real vs placeholder)
- **Per-phase verification criteria** (no phase ships without passing checks)
- **TDD-first steps** (write test, see fail, implement, see pass, commit)

Plans follow: DRY, YAGNI, TDD-first, frequent commits.

## Laziness Gate (scope is decided HERE)

Scope is born in the plan — pruning it here saves every downstream token. For each phase before you write it, run the ladder from `skills/_shared/laziness-ladder.md`:

1. Does this phase/step need to exist at all? Speculative → cut it, note why in one line.
2. Stdlib / native platform feature / already-installed dep already does it? → plan that, not new code.
3. Can the phase be one line or one file fewer? Do that.

Prefer the fewest phases and the shortest diff that satisfies the spec. No phase for a speculative "we might need it." **Boundary:** this prunes SCOPE, never FIDELITY — a phase that a real integration genuinely requires stays (the Data Integration Map is the contract; the ladder never turns a real data source into a placeholder). Mark any deliberate simplification the plan bakes in with a `ponytail:` note so the executor keeps it lazy on purpose.

## Announce at Start

> "I'm using the gaspol-plan skill to create the implementation plan."

## CLAUDE.md-First (Before Writing ANY Plan)

Before writing a single line of the plan, you MUST:

1. **READ `CLAUDE.md`** to understand existing architecture, tables, hooks, contexts, routes
2. **IDENTIFY reusable** hooks, contexts, utilities, and patterns already in the codebase
3. **CHECK if similar features already exist** (avoid duplicating work)
4. **REFERENCE existing code in the plan** with full file paths (e.g., `src/contexts/WorkspaceContext.tsx`)

If you skip this step, the plan will inevitably reinvent existing abstractions.

## Save Plans To (Ticket-Prefixed, Spec/Plan Split)

Every plan is its own file, always separate from the spec:

```
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md
```

`YYYY-MM-DD` is the date this file is created — not the date the ticket was minted; a plan
can be written days after its spec. Date + `<TICKET>` prefix + `-plan.md` suffix make the
file self-identifying at a glance — when it was written, which ticket, and that this is the
plan stage (not `-spec.md`, brainstorm's output). No hybrid append, no line-count split
logic — one plan, one file, always.

**Ticket resolution (before writing anything) — find the spec by GLOB, never by
reconstructing a filename from a date:**
- Glob `docs/plans/*-<TICKET>-*-spec.md`. Zero matches → standalone plan, no preceding
  spec; mint a fresh ticket per the header step below.
- Exactly one match (this plan follows a `gaspol-brainstorm` architectural-path session) —
  read its `**Ticket:**` header field and reuse that ticket. Do not mint a new one.
- **More than one match → STOP and ask the user which spec this plan continues. Never pick
  one silently** — a wrong guess ties the plan to the wrong ticket/spec permanently.

**Migration note:** seven files in `docs/plans/` predate ticket-minting and are NOT
renamed to this convention — `2026-04-17-gaspol-improvements.md`,
`2026-06-09-ecc-adoption-p0-security-eval.md`, `2026-06-30-superpowers-adoption.md`,
`2026-06-30-v1.6-sdd-review-harness.md`, `2026-06-30-v1.7-visual-companion.md`,
`2026-08-16-gaspol-workflow-hardening.md`, `2026-08-16-gaspol-workflow-hardening-plan.md`.
They have no ticket to insert into the new form; inventing one would put false data in a
filename. The `*-<TICKET>-*-spec.md` glob above is automatically safe against them — no
ticket in the name means it never matches.

## Plan Document Header (MANDATORY)

**Resolve this plan's ticket before the header is finalized and written** (see Ticket
resolution above — reuse the spec file's ticket if one exists):

1. If no spec file ticket was found, run
   `skills/gaspol-execute/scripts/next-ticket <path to the target project's CLAUDE.md>`.
2. **Exit 0** — stdout is the new ticket id (e.g. `IND-81`). Use it as this plan's ticket.
3. **Exit 2** — no `## gaspol Ticket Counter` section exists in that CLAUDE.md yet. Use
   **AskUserQuestion** to ask the user for a ticket prefix (no default guess — never invent
   one). With the answer `<PREFIX>`, append this section to the project's CLAUDE.md:
   ```markdown
   ## gaspol Ticket Counter

   Prefix: <PREFIX>
   Last ticket: <PREFIX>-1
   ```
   Use `<PREFIX>-1` as this plan's ticket (the counter now points at it — no need to
   re-run `next-ticket`).
4. Derive this plan's ledger path from the ticket: `.gaspol/progress/PROGRESS-<TICKET>.md`.
5. Derive the plan filename from the ticket and today's date: `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md`.
6. Write the ticket, ledger, and (if a spec preceded this plan) spec path into the header
   below as `**Ticket:**`, `**Ledger:**`, and `**Spec:**` fields.
7. **Create the ledger file now, at plan-write time** — do not defer this to the executor.
   Write `.gaspol/progress/PROGRESS-<TICKET>.md` (and its parent dir) with the header fields,
   a `## Checklist` line for EVERY phase this plan just defined (all starting `[ ]`), and a
   `## Log` with exactly one line: `- <YYYY-MM-DD> plan ditulis — NEXT: Phase A` (or whatever
   the first phase is named). Rationale: at plan-write time the phase names are already known,
   so the executor only has to tick boxes rather than re-derive the phase list. Accepted side
   effect: a plan that is written but never executed shows up as active work in
   `scan-active-ledgers` — that is honest, and `gaspol-execute` Step 0 already has a 4-option
   modal for it.

Every plan document MUST start with this header:

```markdown
> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-<TICKET>.md` (TICKET = this plan's ticket, from the header below; created by `gaspol-plan` at plan-write time — see Plan Document Header step 7). After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md` (that keeps concurrent plans from clobbering each other). **Backward compatibility:** older ledgers at `.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md` are STILL READ when a plan's header names them — only NEW plans write the `PROGRESS-<TICKET>.md` path.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat or read a linked PDF. Every file path, contract, config key, and convention it needs is written here **verbatim**, not merely referenced. If it lives only in the conversation, copy it in.

**Ticket:** IND-81
**Ledger:** .gaspol/progress/PROGRESS-IND-81.md
**Spec:** docs/plans/2026-08-20-IND-81-<topic>-spec.md <!-- omit entirely if this plan is standalone (no preceding brainstorm spec file) -->
**Artifact:** https://claude.ai/public/artifacts/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx <!-- optional — present ONLY when the Execution Handoff artifact offer was accepted and rendered; omit entirely otherwise, never write "n/a" -->

## Goal

[One paragraph describing what this plan achieves and why it matters]

## Architecture Context

[Key info pulled from CLAUDE.md: relevant tables, hooks, contexts, routes, design system tokens]

## Tech Stack

[Frameworks, libraries, patterns to use — reference existing choices from CLAUDE.md]
```

## Progress Ledger Format

The ledger `gaspol-plan` creates at `.gaspol/progress/PROGRESS-<TICKET>.md` (step 7 above) MUST
use exactly this template:

```markdown
# PROGRESS — IDS-1: gaspol output naming standard

**Ticket:** IDS-1
**Plan:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-plan.md

## Checklist
- [x] Phase A: script detect-stack — DONE
- [>] Phase B: glob ledger case-insensitive — DOING
- [ ] Phase C: konvensi nama file spec & plan
- [~] Phase D: contoh fase dibatalkan — DIBATALKAN (YAGNI, alasan di Log)

## Log
- 2026-08-20 Phase A done — `bash tests/ticket-scripts/test-detect-stack.sh` exit 0 — NEXT: Phase B
```

Four checklist states:

| Marker | Meaning | Condition |
|---|---|---|
| `[ ]` | todo | — |
| `[>]` | in progress | set when the phase starts |
| `[x]` | done | that phase's tests are green |
| `[~]` | cancelled / skipped | a short reason is MANDATORY on the line + detail in the Log |

**Structural rule — `## Log` is ALWAYS the last block in the file.** `scan-active-ledgers`
reads the file's last non-empty line to decide active-vs-done; if any block sits below
`## Log`, that detection breaks. This is a hard formatting requirement, not a style preference
— never append a section after `## Log`.

## Bite-Sized Task Granularity

Each step should be **one action** (2-5 minutes estimated):

1. Write one failing test
2. Run it, see it fail
3. Implement minimal code to pass
4. Run tests, see them pass
5. Commit

If a step takes longer than 5 minutes to describe, it is too large. Break it down further.

## Data Integration Map (MANDATORY in Every Plan)

Every plan MUST include a Data Integration Map table:

```markdown
## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| SegmentCard | WorkspaceContext.segments | useWorkspace() | Yes | Use existing |
| RetentionScore | scoringEngine | import from lib/knowledge | Yes | Import directly |
| VoicePreview | generate-tts edge fn | needs useVoicePreview | No | Create new hook |
| UserAvatar | Supabase auth | useAuth() | Yes | Use existing |
```

This table is the **CONTRACT** between planner and executor:

- **Yes (exists):** Executor uses it directly. No reinvention.
- **No (doesn't exist):** Executor creates it as a real, working integration. NOT a placeholder.
- **If not possible:** Executor STOPS and asks the user. Never silently stub it out.

A plan without a Data Integration Map is **INCOMPLETE**. Do not proceed to phases without it.

## Phase Structure

Each phase MUST follow this exact structure:

```markdown
### Phase A: [Phase Name]

**Estimated time:** [X minutes]

**Files:**
- Create: `src/components/SegmentCard.tsx`
- Modify: `src/screens/Workspace/ScriptStep.tsx`
- Test: `src/__tests__/SegmentCard.test.tsx`

**Steps:**
1. Write failing test for SegmentCard rendering. Expected error: `ReferenceError: SegmentCard is not defined`
2. Run test, confirm it fails for the expected reason
3. Implement SegmentCard with real data from useWorkspace()
4. Run tests, confirm all pass
5. Commit: "feat: add SegmentCard with workspace integration"

**Verification:**
- [ ] `npx tsc --noEmit` passes            <!-- the static: line detect-stack printed for THIS project -->
- [ ] `npm test` passes                    <!-- the unit: line detect-stack printed for THIS project -->
- [ ] SegmentCard renders with real data from WorkspaceContext
- [ ] No placeholder/TODO comments in new code
```

The two command lines above are what `detect-stack` happens to print for a Node/TypeScript
project. They are **filled in from its output**, never typed from memory — on a Laravel repo the
same block reads `php artisan test`, on a Python repo `pytest`, and where `detect-stack` prints
`UNKNOWN` the plan must STOP and ask rather than guess.

**TDD Step 1 Hard Gate (MANDATORY):** Every phase MUST have step 1 in this exact format:
```
1. Write failing test for [specific behavior]. Expected error: [error class/message].
```

`gaspol-execute` enforces this — phase without proper TDD step 1 will be refused at execution time (Step 2 hard gate). Plans violating this template are rejected before execution starts.

**Design Deliverable Column (for UI-related phases):** When phase involves UI work (detected via file ext `.tsx/.jsx/.vue/.svelte/.astro/.css`), the Phase table MUST include a Design Deliverable column:

```markdown
| Phase | Code Deliverable | Design Deliverable | Verification |
|-------|-----------------|-------------------|--------------|
| 1 | useAuth hook | n/a (backend) | Tests + types |
| 2 | LoginForm component | Design spec (tokens, layout, motion, states) | Design system compliance |
```

Design deliverable is produced by invoking the `ui-ux-pro-max` skill during plan creation for each UI phase.

**Security-Sensitive Phases:** When a phase touches **auth/authorization, secrets,
user input or file uploads, a new API endpoint, payment, or sensitive data**, the
phase's Verification block MUST include a security line (e.g. "inputs validated,
queries parameterized, authz server-side, no secrets in source"). `gaspol-execute`
auto-runs the built-in `/security-review` for these phases (Step 3.6), and
`gaspol-finish` runs it again on the whole branch before merge.

**Non-Deterministic / LLM Phases:** When a phase implements LLM/prompt/agent behavior
(classification, extraction, generation, RAG, routing), define evals at plan time via
`gaspol-eval` — write `docs/evals/<feature>.md` (capability + regression + real
fixtures) as the phase's success contract. Deterministic unit tests alone do not
verify non-deterministic output; `gaspol-verify` runs these evals and reports pass@k.

## Verification Criteria per Phase (MANDATORY)

Every phase MUST end with a Verification block. At minimum, include:

```markdown
**Verification:**
- [ ] [static: command from detect-stack — e.g. `npx tsc --noEmit`, `mypy .`, `go vet ./...`] passes
- [ ] [unit: command from detect-stack] passes
- [ ] Component renders with real data from [specific source]
- [ ] No placeholder/TODO comments in new code
- [ ] [specific functional check for this phase]
```

The bracketed command slots above are placeholders **in the template only** — fill them from
`detect-stack` output when writing the plan, never ship a plan with the brackets intact and
never hardcode `tsc`/`npm` on a project that does not use them.

**Fill the technical-check line from `detect-stack`, not a guessed command.** Before writing
each phase's Verification block, run `skills/gaspol-execute/scripts/detect-stack
<project-root>` (once per plan is enough — the stack doesn't change phase to phase) and copy
the resulting `static:`/`lint:`/`unit:`/`build:` lines **verbatim** into that phase's block
(e.g. `- [ ] static: npx tsc --noEmit passes`). Rationale: the plan must be self-contained for
an executor with **no other context** — a fresh post-`/compact` session or an external
executor in a separate process can't run `detect-stack` itself or read this skill file, so the
resolved commands have to live in the plan text, not only in the script.
- `detect-stack` prints `<level>: UNKNOWN` for a level → do not write that command into the
  plan. Instead write the verification line as an explicit open question: `- [ ]
  <level> command: UNKNOWN — ask user before Verification can run`, and resolve it with
  AskUserQuestion before the plan is presented as final.
- `detect-stack` prints zero lines (no stack markers, e.g. a docs-only or pure-markdown
  project) → the Verification block has no automated technical check to derive; write the
  phase's own functional/manual checks and note `- [ ] detect-stack: no stack markers for
  this project — verification is plan-declared only` so the executor doesn't go looking for
  a script that will never fire.

A phase without verification criteria is **INCOMPLETE**. The executor will not know when the phase is done.

## Execution Handoff

**Step 0 — Post-Plan Artifact Offer (always, every plan file, unconditional):**

Every time a plan file finishes being written, offer to render it as a visual artifact —
no path gate, no silent skip. A written plan document only exists because the work already
cleared the spike/bounded/architectural funnel (see `gaspol-brainstorm`'s "Three Paths"
classification in its Phase 1), so there is no case where this offer should be skipped
without asking.

Use **AskUserQuestion**:

> "Before execution starts, want me to render a design artifact of this plan's flow so you
> can see it rendered — not just read the plan text — before code starts?"
> - **Yes, render it** — produce the artifact (see below), then continue to the options.
> - **Skip** — proceed straight to the execution options, no artifact.

**On "Yes, render it":**
- If the plan has UI phases (per the "Design Deliverable Column" convention above), render
  an HTML mockup with the `Artifact` tool. Follow the pattern already established in
  `skills/gaspol-brainstorm/visual-companion.md` for how the mockup is built and iterated —
  that file is the source of truth for the pattern; don't duplicate its content here.
- If the plan is backend/data-flow-heavy instead, render a mermaid diagram (sequence, flow,
  or state — whichever fits the plan) embedded in an HTML page via the `Artifact` tool.
- Once rendered and the user has looked at it and approved, record the artifact's URL/path
  in the plan file's header as a new `**Artifact:**` field, positioned alongside the
  existing `**Ticket:**` / `**Ledger:**` fields.

**On "Skip" (or the step was silently skipped per the path gate above):** proceed straight
to the three options below, unchanged. Do NOT add an `**Artifact:**` field to the header —
omit it entirely rather than writing an "n/a" placeholder; absence of the field already
means "not rendered."

**Respects the Laziness Gate:** this step is opt-in, not a new mandatory ceremony step — it
surfaces the pruning question ("does a human need to see this rendered before code starts?")
as a real choice instead of silently skipping or silently forcing it either way.

After the plan is written and saved, and the artifact offer above is resolved, offer the user three options:

**Option 1: Execute in this session**
> "Ready to start Phase A? I'll use gaspol-execute to implement with per-phase checkpoints."

**Option 2: Parallel execution**
> "Want to use gaspol-parallel for independent phases? Phases [X, Y] can run in parallel."

**Option 3: Separate session**
> "Save plan for a new session? The plan file at `docs/plans/...` has everything needed."

**Option 4: External executor** — offer this **only if** an executor is configured (see below):
> "Hand off to your external executor? I'll run `<resolved command>` — it implements **blind** from this self-contained plan and its per-plan ledger, then you return here for review + commit."

This is the two-lane, token-saving path: planning + review stay in this session; the heavy codegen runs in a separate, cheaper executor process. **gaspol-dev ships no executor of its own** — this option surfaces a command *you* wired up, and never invents one.

**Resolving the executor command (in order, first hit wins):**
1. `$GASPOL_EXECUTOR` environment variable.
2. First line of a `.gaspol/executor` file in the project root (lets a repo commit its own executor).
3. **Neither set → do not show Option 4 at all.** The plugin works fully with Options 1–3 (pure in-session, zero setup).

The value is a **command template** with `{plan}` and `{ledger}` placeholders, e.g. `aider --file {plan}`, `opencode run {plan}`, `cursor-agent {plan}`. Substitute the plan path and the resolved per-plan ledger path, then present the concrete command for approval before running.

**Invariants regardless of executor:** the external tool implements + runs tests to green but **NEVER commits/pushes** — the finished diff returns to this session (or the human) for review + commit. Review is never skipped.

## Red Flags (Self-Check Before Finishing)

Before presenting the plan, verify none of these red flags are present:

| Red Flag | Problem | Fix |
|----------|---------|-----|
| No Data Integration Map | Executor will guess at data sources | Add the map table |
| Phase without Verification | Executor won't know when phase is done | Add verification block |
| No reference to CLAUDE.md | Planner didn't read existing architecture | Re-read CLAUDE.md, update plan |
| Vague data sources ("connect to backend") | Executor will create placeholders | Specify which hook, API, context, table |
| No test steps | No TDD cycle, bugs ship silently | Add write-test/run-test steps |
| Phase too large (>15 min estimated) | Executor loses focus, skips verification | Break into smaller phases |
| Placeholder language ("TODO: wire up later") | Violates anti-placeholder contract | Specify the real integration now |
| Plan only makes sense with the chat context | A fresh-session or external executor runs blind and will guess | Inline every contract/convention verbatim — the plan alone must suffice |
| No `Progress ledger:` line in the header | Executor writes the shared global ledger, colliding with concurrent plans | Add `Progress ledger: .gaspol/progress/PROGRESS-<TICKET>.md` to the header |
| Ledger not created at plan-write time | Executor has to re-derive the phase list instead of ticking boxes | Create `.gaspol/progress/PROGRESS-<TICKET>.md` with the full `## Checklist` before presenting the plan |

## Integration with Other Skills

| Trigger | Skill | Relationship |
|---------|-------|-------------|
| Before this skill | `gaspol-brainstorm` | Brainstorm produces the design section in same file; plan appends |
| During this skill | `ui-ux-pro-max` (plugin) | Invoked for each UI phase to produce design deliverable |
| During this skill | `gaspol-adr` | Capture architectural decisions at fork points in the plan |
| After this skill | `gaspol-execute` | Execute the plan with per-phase checkpoints + TDD hard gate |
| After this skill | `gaspol-parallel` | Execute independent phases in parallel (mode: plan-phases) |
