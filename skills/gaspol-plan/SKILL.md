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

## Completeness Gate (coverage is decided HERE)

Coverage is born in the plan. A phase that never enumerated its error paths ships without them, and no downstream gate can recover what the plan never asked for. For each phase, before you write it, walk the ladder from `skills/_shared/completeness-ladder.md` and answer what this phase **owes**:

1. **Happy path** — which real integration does it deliver? (It must appear in the Data Integration Map.)
2. **Error paths** — which failures can actually happen here? Name them. Each becomes a step, not a footnote.
3. **Edge cases** — enumerate the input space: empty, null, zero, one, max, duplicate, out-of-order, concurrent, malformed. Sampling is not enumerating.
4. **Tests** — step 1 of the phase is still the failing test; rungs 2 and 3 each need a covering case.
5. **Observability** — what does a 3am debugger need to see?

Every phase carries the answers as steps. A rung that genuinely does not apply is written down as **not applicable, with the reason** — never left blank, because a blank reads as "covered" to the executor.

**Reuse, not volume:** prefer stdlib → native platform feature → already-installed dependency over new code, and plan no interface with one implementation. Reuse cuts cleverness, never coverage.

**Boundary:** completeness is depth on what the spec asked for. It is not licence to plan features the spec does not contain — work outside the spec is listed under "Out of scope" in one line, never absorbed silently. And it never softens FIDELITY: the Data Integration Map stays the contract, and no phase turns a real data source into a placeholder.

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
   the four mandatory sections, a `### [ ] Phase <N>: <name>` **sub-block per phase** whose body
   is that phase's `**Steps:**` rendered as checkboxes followed by its `**Verification:**` block
   verbatim, and a `## Log` with exactly one line:
   `- <YYYY-MM-DD> plan ditulis — NEXT: Phase A` (or whatever the first phase is named).
   **Copy, do not summarise.** Both blocks already exist in the plan you just wrote, and
   `**Verification:**` is already `- [ ]` checkboxes — so the richer ledger costs nothing to
   produce and cannot drift from the plan it came from. A phase with **no** `**Verification:**`
   block means the plan is incomplete: **STOP and ask**, never invent one to fill the gap. Rationale: at plan-write time the phase names are already known,
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
**Artifact:** https://claude.ai/public/artifacts/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx <!-- present ONLY when the post-plan offer's [Render design artifact dulu] option was taken and the artifact was approved; omit the whole line otherwise, and never write "n/a" -- a declined artifact is recorded in the LEDGER as `design-artifact: skipped — <reason>`, not here -->

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
**Spec:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-spec.md

## Pre-flight

| Gate | Result |
|---|---|
| Git clean | PASS — baseline `331fbca` |
| Baseline suite | PASS — `<command from detect-stack>`, 44 lulus / 0 gagal |
| detect-stack | `unit: npm test` (atau "no stack markers") |

## Keputusan saat jalan

(kosong sampai ada keputusan; tiap butir: apa, siapa yang memutuskan, tanggal)

## Checklist

### [x] Phase A: script detect-stack
- [x] Write failing test for detect-stack on a Node project. Expected error: `command not found`
- [x] Run test, confirm it fails for the expected reason
- [x] Implement the marker-file reader
- [x] `npx tsc --noEmit` passes
- [x] `npm test` passes
- [x] No placeholder/TODO comments in new code

### [>] Phase B: glob ledger case-insensitive
- [ ] Write failing test for a lowercase-prefixed ledger being found. Expected error: `not found`
- [ ] ...

### [ ] Phase C: konvensi nama file spec & plan

### [~] Phase D: contoh fase dibatalkan — DIBATALKAN (YAGNI, alasan di Log)

## Phase log

| Phase | Status | Commit |
|---|---|---|
| A — script detect-stack | DONE | `4f2a1c9` |
| B — glob ledger | DOING | — |

## Utang terbuka

(kosong sampai ada yang sengaja ditinggal; tiap butir bernama)

## Log
- 2026-08-20 Phase A done — `bash tests/ticket-scripts/test-detect-stack.sh` exit 0 — NEXT: Phase B
```

**The Checklist body is COPIED from the plan, never summarised.** Each phase's `**Steps:**` become
checkboxes and its `**Verification:**` block is appended verbatim — it is already `- [ ]`. Nothing
is authored twice, so the ledger cannot drift from the plan it came from.

**The accepted consequence, stated rather than discovered later:** ledger quality is now bound to
plan quality. A plan whose Steps are lazy produces a lazy ledger. That coupling is the point. The
alternative — a fixed generic checkbox set — can never produce a box like *"RED seen: `'   '` plus
a signature stores `''`, expected `null`"*, because that box is specific to one phase of one
ticket, and boxes like that are the entire reason this format is worth copying.

**Four mandatory sections, all ABOVE `## Log`:** `## Pre-flight`, `## Keputusan saat jalan`,
`## Phase log`, `## Utang terbuka`.

| Section | What it holds | Why it is mandatory |
|---|---|---|
| `## Pre-flight` | git state, the baseline suite run and its counts, `detect-stack` output | a red baseline nobody recorded gets blamed on the new phase, and the fix loop burns its rounds on somebody else's failure |
| `## Keputusan saat jalan` | each mid-run choice, who decided it, the date | the only record of what is neither in the plan nor in the code |
| `## Phase log` | phase → status → **real commit SHA** | a SHA can be re-checked; the word "DONE" cannot |
| `## Utang terbuka` | what was deliberately left undone, each item named | what is not written down becomes a *"nanti"* that never arrives |

**Every other section is added when it has content, never as an empty heading.** IND-117's ledger
grew nine — evidence-quality notes, open items for a later phase, the plan-verifier round table,
post-run gates, deploy steps, leftovers found after close. Mandating all nine would fill most
ledgers with "N/A", and an empty label reads as *checked and clear*, which is worse than a section
that is simply absent.

**Backward compatibility — READ the old shape, WRITE the new one.** An **older flat** ledger —
one `## Checklist` line per phase, no sub-blocks, none of the four sections — is still read
exactly as it is: tick its line, append to its `## Log`, and leave its shape alone. Rewriting a
ledger mid-ticket destroys the record of what was actually observed and replaces it with what
somebody infers now, which is the opposite of what a ledger is for. Only a ledger you CREATE uses
the new shape. `scan-active-ledgers` reads both, because both end with `## Log`.

The state markers apply to a **phase heading** and to an individual **checkbox** alike: a single
step that was genuinely not done gets `[~]` with its reason on the line, rather than a tick it
did not earn or a blank that reads as forgotten.

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

**Design Deliverable Column (for UI-related phases):** When phase involves UI work (detected via file ext `.tsx/.jsx/.vue/.svelte/.astro/.css/.scss/.sass`), the Phase table MUST include a Design Deliverable column:

```markdown
| Phase | Code Deliverable | Design Deliverable | Verification |
|-------|-----------------|-------------------|--------------|
| 1 | useAuth hook | n/a (backend) | Tests + types |
| 2 | LoginForm component | Design spec (tokens, layout, motion, states) | Design system compliance |
```

The Design Deliverable cell **cites** the design decisions `gaspol-brainstorm` Phase 3 already
produced — palette, font pairing, layout blueprint, motion, accessibility — rather than invoking
`ui-ux-pro-max` again here. That skill is called **at most once per ticket**: at Phase 3 where a
brainstorm ran, or at the post-plan offer where none did. It was previously reachable from three
separate places for one feature, which is three answers to the same question and no rule for which
one wins.

**Security-Sensitive Phases:** When a phase touches **auth/authorization, secrets,
user input or file uploads, a new API endpoint, payment, or sensitive data**, the
phase's Verification block MUST include a security line (e.g. "inputs validated,
queries parameterized, authz server-side, no secrets in source"). `gaspol-execute`
auto-runs the built-in `/security-review` for these phases (Step 3.6), and
`gaspol-finish` runs it again on the whole branch before merge.

**Non-Deterministic / LLM Phases:** When a phase implements LLM/prompt/agent behavior
(classification, extraction, generation, RAG, routing), define evals at plan time via
**evals, not unit tests** — write `docs/evals/<feature>.md` (capability + regression + real
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

**Step 0 — the post-plan offer** — presented once, right here, and nowhere else:

The plan file and its ledger are written FIRST. Then present exactly one `AskUserQuestion` carrying
both the artifact and the execution choices together — not an artifact gate followed by a separate
execution modal, which is two questions for one decision:

```text
[Render design artifact dulu]   → render it, then present this same modal without this option
[Eksekusi di sesi ini]          → gaspol-execute, per-phase checkpoints
[Eksekusi otomatis]             → gaspol-auto, autonomous with hard-stop guardrails — ALWAYS offered
[Eksekusi parallel]             → gaspol-parallel, only when the plan has independent phases
[Simpan buat sesi lain]         → stop here
[Serahkan ke executor luar]     → only when an executor resolves (see below)
```

`gaspol-auto` is offered on **every** plan. It is a documented execution mode that this skill
previously never surfaced, so the only way to reach it was to already know it existed. Its own
pre-flight gate — plan approval, clean git state, a passing baseline, the per-phase TDD check — is
unchanged and still refuses to start when any of those fail. Those are `gaspol-auto`'s refusals to
run, not reasons to hide the door.

**What the artifact contains** is the tab-count rule in
`skills/gaspol-plan/logic-design-artifact.md`: the Logic tab always, plus a Design tab holding the
mockup when the plan touches UI files. That file also carries the page skeleton to copy, the
`srcdoc` escaping rule, and the requirement that the prose is plain Indonesian.

**`ui-ux-pro-max` is invoked at most once per ticket.** Where `gaspol-brainstorm` Phase 3 already
ran, its design decisions are reused here and the skill is not called again. Where brainstorm never
ran and the plan touches UI, this is the single point it is called.

### Declining costs a reason, and the reason may not be empty

The four options that START EXECUTION — `[Eksekusi di sesi ini]`, `[Eksekusi otomatis]`,
`[Eksekusi parallel]`, `[Serahkan ke executor luar]` — write one line to the ledger before handing
off:

```text
design-artifact: skipped — <reason>
```

An empty reason is refused: ask again. A bare label with nothing after the dash documents the wish
to skip without documenting why skipping was acceptable, which is the escape hatch this repository
has already had to close once elsewhere.

`[Simpan buat sesi lain]` writes **NO line at all**. Nothing was skipped, because nothing executed,
and demanding a justification for a decision the user has not yet made teaches people to type
anything to get past the prompt.

**The cost of that, stated rather than glossed:** this offer exists only here. A later session that
resumes the plan through `gaspol-execute` will not be asked again — it reads a ledger with no line,
proceeds, and records `design-artifact: none — no offer was made`. Re-entering `gaspol-plan` for
that plan is the only way to reach the offer a second time.

### Recording an approved artifact

When `[Render design artifact dulu]` is chosen and the artifact is approved, record it in **two**
places:

- `**Artifact:** <url>` in this plan file's header, beside `**Ticket:**` / `**Ledger:**`
- `design-artifact: approved — <url>` in the ledger, above `## Log`

| Ledger line | What `gaspol-execute` does |
|---|---|
| `design-artifact: approved — <url>` | proceed |
| `design-artifact: pending — <url>` | **STOP and ask** — published, never approved |
| `design-artifact: skipped — <reason>` | proceed |
| no line | proceed, recording `design-artifact: none — no offer was made` |


### `[Serahkan ke executor luar]` — shown only when an executor is configured
> "Hand off to your external executor? I'll run `<resolved command>` — it implements **blind** from this self-contained plan and its per-plan ledger, then you return here for review + commit."

This is the two-lane, token-saving path: planning + review stay in this session; the heavy codegen runs in a separate, cheaper executor process. **gaspol-dev ships no executor of its own** — this option surfaces a command *you* wired up, and never invents one.

**Resolving the executor command (in order, first hit wins):**
1. `$GASPOL_EXECUTOR` environment variable.
2. First line of a `.gaspol/executor` file in the project root (lets a repo commit its own executor).
3. **Neither set → leave this option out of the modal entirely.** The plugin works fully with the
   in-session options above; there is nothing to configure to use it.

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
| During this skill | `ui-ux-pro-max` (plugin) | At most ONCE per ticket, and only where no brainstorm ran — otherwise Phase 3's decisions are cited |
| During this skill | `gaspol-adr` | Capture architectural decisions at fork points in the plan |
| After this skill | `gaspol-execute` | Execute the plan with per-phase checkpoints + TDD hard gate |
| After this skill | `gaspol-parallel` | Execute independent phases in parallel (mode: plan-phases) |
