---
name: gaspol-plan
description: "Use when you have a spec or requirements for a multi-step task, before touching code. Creates comprehensive plans with mandatory Data Integration Maps and per-phase verification criteria."
---

# gaspol-plan

## Overview

Write comprehensive implementation plans assuming the executor has **zero context** and **questionable taste**.

Plans follow: DRY, YAGNI, TDD-first, frequent commits. Read `references/plan-details.md` when a gate below needs its reasoning.

## Completeness Gate (coverage is decided HERE)

For each phase, before you write it, walk the ladder from `skills/_shared/completeness-ladder.md` and answer what this phase **owes**:

1. **Happy path** — which real integration does it deliver? (It must appear in the Data Integration Map.)
2. **Error paths** — which failures can actually happen here? Name them. Each becomes a step, not a footnote.
3. **Edge cases** — enumerate the input space: empty, null, zero, one, max, duplicate, out-of-order, concurrent, malformed. Sampling is not enumerating.
4. **Tests** — step 1 of the phase is still the failing test; rungs 2 and 3 each need a covering case.
5. **Observability** — what does a 3am debugger need to see?

Every phase carries the answers as steps. A rung that genuinely does not apply is written down as **not applicable, with the reason** — never left blank.

**Repo gates go in the phase that triggers them.** Before writing phases, list the project's
own checks that fire on a NEW file — a registry or index that must name every tool, a docs table
generated from code, a coverage gate refusing an unused module. Any phase that creates such a file
also registers it, in the same phase.

**Reuse, not volume:** prefer stdlib → native platform feature → already-installed dependency over new code, and plan no interface with one implementation. Reuse cuts cleverness, never coverage.

**Boundary:** completeness is depth on what the spec asked for. It is not licence to plan features the spec does not contain — work outside the spec is listed under "Out of scope" in one line, never absorbed silently. And it never softens FIDELITY: the Data Integration Map stays the contract, and no phase turns a real data source into a placeholder.

## Announce at Start

> "I'm using the gaspol-plan skill to create the implementation plan."

## CLAUDE.md-First (Before Writing ANY Plan)

Before writing a single line of the plan, you MUST:

1. **READ `CLAUDE.md`** to understand existing architecture, tables, hooks, contexts, routes
2. **IDENTIFY reusable** hooks, contexts, utilities, and patterns already in the codebase
3. **CHECK if similar features already exist**
4. **REFERENCE existing code in the plan** with full file paths

## Save Plans To (Ticket-Prefixed, Spec/Plan Split)

Every plan is its own file, always separate from the spec:

```
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md
```

**Ticket resolution (before writing anything) — find the spec by GLOB, never by
reconstructing a filename from a date:**
- Glob `docs/plans/*-<TICKET>-*-spec.md`. Zero matches → standalone plan, no preceding
  spec; mint a fresh ticket per the header step below.
- Exactly one match (this plan follows a `gaspol-brainstorm` architectural-path session) —
  read its `**Ticket:**` header field and reuse that ticket. Do not mint a new one.
- **More than one match → STOP and ask the user which spec this plan continues. Never pick
  one silently** — a wrong guess ties the plan to the wrong ticket/spec permanently.

`YYYY-MM-DD` is the date this file is created — not the date the ticket was minted.

Read `references/plan-details.md` when you need the seven pre-ticket files that keep their names.

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
   the four mandatory sections, a `### [ ] Phase <N>: <name>` **sub-block per phase** whose body
   is that phase's `**Steps:**` rendered as checkboxes followed by its `**Verification:**` block
   verbatim, a `## Phase log` table with **one row per phase, every phase, from the start**, and a `## Log` with exactly one line:
   `- <YYYY-MM-DD> plan ditulis — NEXT: Phase A` (or whatever the first phase is named).
   **Copy, do not summarise.** Both blocks already exist in the plan you just wrote, and
   `**Verification:**` is already `- [ ]` checkboxes — so the richer ledger costs nothing to
   produce and cannot drift from the plan it came from. A phase with **no** `**Verification:**`
   block means the plan is incomplete: **STOP and ask**, never invent one to fill the gap.

Every plan MUST start with the header in `references/plan-header.md`, copied verbatim. Read `references/plan-header.md` when you write the header.

- The four blockquote paragraphs at the top of the template (`**For Claude:**`, `**CRITICAL:**` — NEVER substitute placeholders for real data sources without explicit user approval, the **Progress ledger — HARD PER-PHASE GATE**, and `**Self-contained:**`) are copied verbatim into every plan.
- `**Ticket:**` and `**Ledger:**` are always written.
- `**Spec:**` only when a spec preceded this plan; omit the line entirely when the plan is standalone.
- `**Artifact:**` only once the post-plan offer's `[Render design artifact dulu]` option was taken and the artifact was approved; omit the whole line otherwise, and never write "n/a".
- `**Format:** waves-v1` is always present in a new plan.
- `**Verification commands:**` is written once per plan, as below.

**Verification commands — written ONCE per plan, never per phase.** Run
`skills/gaspol-execute/scripts/detect-stack <project-root>` once and copy its `static:`/`lint:`/
`unit:`/`build:` lines **verbatim** as `- ` lines directly under the `**Verification commands:**`
line (no comments on those lines, no blank line inside the block). Three variants, no others:

- `detect-stack` prints commands → the `static:`/`unit:` list, copied verbatim.
- `detect-stack` prints `<level>: UNKNOWN` → write `- <level>: UNKNOWN — ask user before Verification can run`
  for that level and resolve it with AskUserQuestion before the plan is presented as final.
- `detect-stack` prints nothing → write `- detect-stack: no stack markers for this project — verification is plan-declared only`.

## Progress Ledger Format

The ledger created in step 7 MUST use exactly the template in `references/ledger-format.md`. Read `references/ledger-format.md` when you write the ledger in step 7.

**Four mandatory sections, all ABOVE `## Log`:** `## Pre-flight`, `## Keputusan saat jalan`,
`## Phase log`, `## Utang terbuka`. **Every other section is added when it has content, never as an empty heading.**

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

An **older flat** ledger — one `## Checklist` line per phase, no sub-blocks, none of the four sections — is still read exactly as it is: tick its line, append to its `## Log`, and leave its shape alone. Only a ledger you CREATE uses the new shape.

## Bite-Sized Task Granularity

Each step should be **one action** (2-5 minutes estimated):

1. Write one failing test
2. Run it, see it fail
3. Implement minimal code to pass
4. Run tests, see them pass
5. Commit

If a step takes longer than 5 minutes to describe, it is too large. Break it down further. A phase estimated over 15 minutes is too large: break it into smaller phases.

## Data Integration Map (MANDATORY in Every Plan)

Every plan MUST include a Data Integration Map table:

```markdown
## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| SegmentCard | WorkspaceContext.segments | useWorkspace() | Yes | Use existing |
```

This table is the **CONTRACT** between planner and executor:

- **Yes (exists):** Executor uses it directly. No reinvention.
- **No (doesn't exist):** Executor creates it as a real, working integration. NOT a placeholder.
- **If not possible:** Executor STOPS and asks the user. Never silently stub it out.

A plan without a Data Integration Map is **INCOMPLETE**. Do not proceed to phases without it.

## Phase Structure

Each phase MUST follow the exact structure in `references/phase-template.md`, copied verbatim. Read `references/phase-template.md` when you write a phase.

**Deps and Complexity (MANDATORY, `waves-v1`):** every phase declares what it waits for and how
hard it is, between the heading and `**Files:**`.

- `**Deps:**` is `none` or the ids of the phases that must finish first. Declare a dependency
  when a phase calls, imports or tests something another phase creates or changes.
- `**Complexity:**` is `light`, `medium` or `complex`, then an em dash `—` (a spaced hyphen ` - `
  is also accepted) and a one-sentence reason. Rubric:
  - light = one file, no design decision
  - medium = several files, pattern already in the repo
  - complex = new logic; money, auth or security; many interlinked files; an interface other phases consume
- Rule: a bare label with no reason is refused. `plan-waves` exits 1 on it.
- Complexity is a judgement by the planner, not a measurement. At dispatch time the orchestrator reads the `phase …` lines
  that `plan-waves` prints and passes each phase's assignment on; this skill does not restate
  what each label maps to, so there is one place to change it.

**TDD Step 1 Hard Gate (MANDATORY):** Every phase MUST have step 1 in this exact format:
```
1. Write failing test for [specific behavior]. Expected error: [error class/message].
```

`gaspol-execute` enforces this — phase without proper TDD step 1 will be refused at execution time (Step 2 hard gate). Plans violating this template are rejected before execution starts.

**Self-check before the plan is presented:** the number of lines matching
`^1\. Write failing test for .+ Expected error: ` must equal the number of `### Phase` headings.
Count both; also count the `**Deps:**` lines and the `**Complexity:**` lines, which must each
equal the number of `### Phase` headings too. Fix any phase whose step 1 drifted before the offer.

**Design Deliverable Column (for UI-related phases):** When phase involves UI work (detected via file ext `.tsx/.jsx/.vue/.svelte/.astro/.css/.scss/.sass`), the Phase table MUST include a Design Deliverable column. `ui-ux-pro-max` is invoked at most once per ticket. Read `references/plan-details.md` when a phase involves UI work: it holds the table.

**Security-Sensitive Phases:** When a phase touches **auth/authorization, secrets,
user input or file uploads, a new API endpoint, payment, or sensitive data**, the
phase's Verification block MUST include a security line.

**Non-Deterministic / LLM Phases:** When a phase implements LLM/prompt/agent behavior, define evals at plan time via
**evals, not unit tests** — write `docs/evals/<feature>.md` (capability + regression + real
fixtures) as the phase's success contract.

## Verification Criteria per Phase (MANDATORY)

Every phase MUST end with a Verification block, and the block holds **only checks specific to
that phase** — at least one:

```markdown
**Verification:**
- [ ] Component renders with real data from WorkspaceContext
- [ ] [specific functional check for this phase]
```

- A phase with no Verification lines, or only generic ones, is **INCOMPLETE**: the executor will
  not know when the phase is done. `verification-lint` (see Execution Waves) enforces this.
- An unfilled `real data from [specific source]` is generic and is refused.

Read `references/plan-details.md` when you write a phase's Verification block or fill the `**Verification commands:**` block.

## Execution Waves (MANDATORY)

After writing all phases, and **before** the offer below is presented, compute the schedule, and never hand-schedule it: the same script that checks the fields builds the
waves, so the table cannot disagree with the plan.

```bash
"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan-file>
```

The path goes through `${CLAUDE_PLUGIN_ROOT:?…}`, never a relative path. Read the exit code (on exit 3, STOP and ask):

| Exit | Stdout line 1 | Do this |
|---|---|---|
| 0 | `plan-waves: OK — <n> phase(s), <m> wave(s)` | paste its `wave` / `lane` lines as an `## Execution Waves` section in the plan, and the same lines as a `## Waves` section in the ledger **above** `## Log` (`## Log` stays last) |
| 1 | `plan-waves: BLOCKING — <problem>` | fix the plan and re-run |
| 3 | `plan-waves: UNKNOWN — <why>` | **STOP and ask.** The script or the plan could not be read; do not schedule by hand |
| 4 | `plan-waves: N/A — no waves-v1 format header …` | the `**Format:** waves-v1` line is missing from a new plan: add it and re-run. Exit 4 is never a pass |

Then check that no phase's Verification block is only boilerplate:

```bash
"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/verification-lint" <plan-file>
```

Same anchoring rule as above. Read the exit code:

| Exit | Stdout line 1 | Do this |
|---|---|---|
| 0 | `verification-lint: OK — <n> phase(s)` | continue |
| 1 | `verification-lint: BLOCKING — phase <id> has no phase-specific verification` | fix the plan: add a check specific to that phase, then re-run |
| 3 | `verification-lint: UNKNOWN — <why>` | **STOP and ask.** The plan could not be read or parsed; do not skip the lint |
| 4 | `verification-lint: N/A — no Verification commands header …` | the `**Verification commands:**` header block is missing from a new plan: add it and re-run. Exit 4 is never a pass |

## Execution Handoff

**Step 0 — the post-plan offer** — presented once, right here, and nowhere else:

The plan file and its ledger are written FIRST. Then present exactly one `AskUserQuestion` carrying
both the artifact and the execution choices together — not an artifact gate followed by a separate
execution modal, which is two questions for one decision:

```text
[Render design artifact dulu]   → render it, then present this same modal without this option
[Eksekusi di sesi ini]          → gaspol-execute, per-phase checkpoints
[Eksekusi otomatis]             → gaspol-auto, autonomous with hard-stop guardrails — ALWAYS offered
[Eksekusi parallel]             → gaspol-parallel, only when `plan-waves` printed a wave with two or more lanes
[Simpan buat sesi lain]         → stop here
[Serahkan ke executor luar]     → only when an executor resolves (see below this block)
```

Read `references/execution-handoff.md` when you present this offer.

`[Serahkan ke executor luar]` is shown only when an executor resolves: `$GASPOL_EXECUTOR`, then the first line of `.gaspol/executor`; **neither set → leave this option out of the modal entirely.** Present the concrete command for approval before running. The external tool **NEVER commits/pushes** — the finished diff returns to this session (or the human) for review + commit — and review is never skipped.

When `[Render design artifact dulu]` is chosen and the artifact is approved, record it in **two** places: `**Artifact:** <url>` in this plan file's header, and `design-artifact: approved — <url>` in the ledger, above `## Log`.

### Declining costs a reason, and the reason may not be empty

The four options that START EXECUTION — `[Eksekusi di sesi ini]`, `[Eksekusi otomatis]`,
`[Eksekusi parallel]`, `[Serahkan ke executor luar]` — write one line to the ledger before handing
off:

```text
design-artifact: skipped — <reason>
```

An empty reason is refused: ask again.

`[Simpan buat sesi lain]` writes **NO line at all**. Nothing was skipped, because nothing executed.

## Red Flags (Self-Check Before Finishing)

Before presenting the plan, verify none of these red flags are present:

Read `references/plan-details.md` when you run this self-check: it holds the table.

## Integration with Other Skills

Read `references/plan-details.md` when you need how this skill relates to the others.
