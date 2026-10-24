# Plan details: reasons, examples and tables

`SKILL.md` states each gate's condition and consequence. This file holds the reasons, examples, tables and notes that were cut or moved out of it. Fragments are given with the words they followed in `SKILL.md`.

## Overview and Completeness Gate

Followed the Overview opening sentence ("questionable taste."):

Every plan includes:

- A **Data Integration Map** (contract for real vs placeholder)
- **Per-phase verification criteria** (no phase ships without passing checks)
- **TDD-first steps** (write test, see fail, implement, see pass, commit)

Opened the Completeness Gate section, before "For each phase, before you write it":

Coverage is born in the plan. A phase that never enumerated its error paths ships without them, and no downstream gate can recover what the plan never asked for.

Followed "never left blank":

because a blank reads as "covered" to the executor

Followed "also registers it, in the same phase.":

Scheduling "register everything" for the last phase leaves
every phase before it red, and the run burns a fix round on a failure the plan itself caused.

## CLAUDE.md-First

Followed "CHECK if similar features already exist":

(avoid duplicating work)

Followed "REFERENCE existing code in the plan with full file paths":

(e.g., `src/contexts/WorkspaceContext.tsx`)

Closed the section:

If you skip this step, the plan will inevitably reinvent existing abstractions.

## Save Plans To

Followed the plan filename code block:

`YYYY-MM-DD` is the date this file is created — not the date the ticket was minted; a plan
can be written days after its spec. Date + `<TICKET>` prefix + `-plan.md` suffix make the
file self-identifying at a glance — when it was written, which ticket, and that this is the
plan stage (not `-spec.md`, brainstorm's output). No hybrid append, no line-count split
logic — one plan, one file, always.

**Migration note:** seven files in `docs/plans/` predate ticket-minting and are NOT
renamed to this convention — `2026-04-17-gaspol-improvements.md`,
`2026-06-09-ecc-adoption-p0-security-eval.md`, `2026-06-30-superpowers-adoption.md`,
`2026-06-30-v1.6-sdd-review-harness.md`, `2026-06-30-v1.7-visual-companion.md`,
`2026-08-16-gaspol-workflow-hardening.md`, `2026-08-16-gaspol-workflow-hardening-plan.md`.
They have no ticket to insert into the new form; inventing one would put false data in a
filename. The `*-<TICKET>-*-spec.md` glob above is automatically safe against them — no
ticket in the name means it never matches.

## Plan Document Header

Followed "a `## Phase log` table with **one row per phase, every phase, from the start**" in step 7:

(`| A — <name> | TODO | `` `<no commit>` `` |`), and a `## Log`

Followed "**Verification commands — written ONCE per plan, never per phase.**":

The block is the plan's one
statement of the generic checks (compile, lint, unit, build) that apply to every phase.

Followed "no blank line inside the block).":

The example above is what
`detect-stack` prints for a Node/TypeScript project; on a Laravel repo it reads `php artisan test`,
on a Python repo `pytest`.

Followed the three `detect-stack` variants:

`task-brief` copies this block into every phase brief, because a dispatched implementer is handed
the brief and never the plan. `gaspol-verify` and `gaspol-execute` keep reading "plan-declared
commands": this block IS the plan-declared commands.

## Data Integration Map

Example rows that followed the SegmentCard row in the template:

| RetentionScore | scoringEngine | import from lib/knowledge | Yes | Import directly |
| VoicePreview | generate-tts edge fn | needs useVoicePreview | No | Create new hook |
| UserAvatar | Supabase auth | useAuth() | Yes | Use existing |

## Phase Structure

Followed the phase template:

The block holds only checks specific to this phase. The compile and unit commands are not
repeated here: they live once in the plan header's `**Verification commands:**` block.

Followed "Declare a dependency when a phase calls, imports or tests something another phase creates or changes.":

Files are
  checked by the scheduler, but a semantic dependency is caught only if you declare it.

Followed "`plan-waves` exits 1 on it":

, the same way a state
  label with nothing after the dash is `(if possible)` wearing a new name. The label decides how much
  effort and review the phase gets, so the reason is the part a human can check.

Followed "before the offer.":

Catching it at execution pre-flight costs a plan edit mid-run.

Followed "Fix any phase whose step 1 drifted":

("Write failing check", "Write failing consistency
test ...")

Followed the Design Deliverable line:

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

Followed "MUST include a security line":

(e.g. "inputs validated,
queries parameterized, authz server-side, no secrets in source")

Followed "When a phase implements LLM/prompt/agent behavior":

(classification, extraction, generation, RAG, routing)

Followed "no secrets in source").":

`gaspol-execute`
auto-runs the built-in `/security-review` for these phases (Step 3.6), and
`gaspol-finish` runs it again on the whole branch before merge.

Followed "as the phase's success contract.":

Deterministic unit tests alone do not
verify non-deterministic output; `gaspol-verify` runs these evals and reports pass@k.

## Verification Criteria per Phase

What counts as specific, and what does not:

- **Generic, so it does not belong here:** the compile/lint/unit/build commands (they are in the
  header's `**Verification commands:**` block), `static:`/`unit:` lines, and any "no placeholder
  or TODO comments" line — `gaspol-verify` Layer 3 owns that check.
- **Specific:** a behaviour, an exit code, a value, or an edge case only this phase introduces.
  "real data from [source]" counts only when it names a concrete source (`useWorkspace()`, the
  `segments` table). An unfilled `real data from [specific source]` is generic and is refused.

Followed the lint rule:

**Fill the header block from `detect-stack`, not a guessed command.** Run
`skills/gaspol-execute/scripts/detect-stack <project-root>` once per plan (the stack doesn't change
phase to phase) and write its lines into the `**Verification commands:**` header block, verbatim.
Rationale: the plan must be self-contained for an executor with **no other context** — a fresh
post-`/compact` session or an external executor in a separate process can't run `detect-stack`
itself or read this skill file, so the resolved commands have to live in the plan text, not only
in the script.
- `detect-stack` prints `<level>: UNKNOWN` for a level → do not write that command into the
  plan. Write `- <level>: UNKNOWN — ask user before Verification can run` in the header block,
  and resolve it with AskUserQuestion before the plan is presented as final.
- `detect-stack` prints zero lines (no stack markers, e.g. a docs-only or pure-markdown
  project) → there is no automated technical check to derive; write
  `- detect-stack: no stack markers for this project — verification is plan-declared only` in the
  header block so the executor doesn't go looking for a script that will never fire. Each phase's
  own functional/manual checks still go in that phase's Verification block.

## Execution Waves

Followed "fix the plan" in the plan-waves exit 1 row:

(missing `Deps`/`Complexity`, bare label, unknown dep, cycle, duplicate id)

Followed the plan-waves exit table:

The `phase …` lines in the same output are what the executors read for each phase's assignment.

Followed "never a relative path":

: a skill runs with the
target project as its working directory, and a project that ships its own `plan-waves` would
otherwise answer in place of ours.

## Red Flags

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
| A phase lacks `**Deps:**` or `**Complexity:**`, or the complexity has no reason | `plan-waves` refuses the plan, and executors get no assignment | Add both lines; give the reason after the dash |
| The same compile/unit/placeholder lines repeated in every phase's Verification block | The phase-specific checks drown in boilerplate and a phase can pass with nothing of its own | Write the commands once in the header's `**Verification commands:**` block; keep only phase-specific lines per phase, then run `verification-lint` |
| Waves written by hand, or `plan-waves` never run | The table can disagree with the phases and nothing notices | Run `plan-waves`, paste its lines |
| Ledger not created at plan-write time | Executor has to re-derive the phase list instead of ticking boxes | Create `.gaspol/progress/PROGRESS-<TICKET>.md` with the full `## Checklist` before presenting the plan |

## Integration with Other Skills

| Trigger | Skill | Relationship |
|---------|-------|-------------|
| Before this skill | `gaspol-brainstorm` | Brainstorm produces the design section in same file; plan appends |
| During this skill | `ui-ux-pro-max` (plugin) | At most ONCE per ticket, and only where no brainstorm ran — otherwise Phase 3's decisions are cited |
| During this skill | `gaspol-adr` | Capture architectural decisions at fork points in the plan |
| After this skill | `gaspol-execute` | Execute the plan with per-phase checkpoints + TDD hard gate |
| After this skill | `gaspol-parallel` | Execute independent phases in parallel (mode: plan-phases) |
