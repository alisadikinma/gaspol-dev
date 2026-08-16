> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.

## Goal

Ship 9 hardening items to the gaspol-dev plugin itself (source repo
`/Users/alisadikin/Drive-D/Projects/claude-plugin/gaspol-dev`): a skill-description
compliance audit, a three-path brainstorm ceremony router, two gaspol-write-skill
authoring upgrades, a post-plan design-artifact confirmation gate, a **tiered** split of
gaspol-review (Tier 0 unchanged / Tier 1 adds one plan+artifact lane / Tier 2 opt-in) with
plan+artifact cross-check, a hard-wired mandatory code-review+security-review gate in
gaspol-finish, a ticket-numbered collision-safe execution ledger, and a proactive
context-budget checkpoint (offer a clean session breakpoint every 3 phases, on top of the
existing reactive `/compact`-survival ledger). Full design, vault precedent, and the
2026-08-16 token-efficiency research trail (which is why item 7 is tiered instead of a flat
multi-agent fan-out):
[2026-08-16-gaspol-workflow-hardening.md](2026-08-16-gaspol-workflow-hardening.md).

Every phase edits markdown skill files (and two small shell scripts) inside the
plugin source itself — no application code, no UI, no external project touched.

## Architecture Context

- Plugin root: `/Users/alisadikin/Drive-D/Projects/claude-plugin/gaspol-dev` (current version 1.10.1 per git; `CLAUDE.md` header is stale at 1.9.1 — Phase 1 fixes this)
- Skill files: `skills/gaspol-<name>/SKILL.md`
- Ledger convention (v1.9.1 handoff-cursor, v1.10 per-plan path): `.gaspol/progress/<slug>.md`, gitignored working-tree scratch. Phase 2 replaces `<slug>` with `<PREFIX>-<N>`.
- Test harness: `tests/skill-triggering/` (cold-prompt auto-trigger, `run-all.sh`) and `tests/pressure/` (rationalization resistance, `run-all.sh`) — both real, runnable bash suites already in the repo.
- Contributor convention (`CLAUDE.md` "Conventions for Contributors"): editing a skill requires re-testing with a pressure scenario; description/trigger changes require a `tests/skill-triggering/prompts/<skill>.txt` case.

## Tech Stack

Bash (existing test harness style, `set -euo pipefail`, matches `skills/gaspol-parallel/scripts/dag-lanes` conventions — stdlib only, no new dependency, `--self-test` flag pattern for new scripts), Markdown/YAML frontmatter for skill files.

## Data Integration Map

| Item | "Data" (source of truth read/written) | Existing? | Action |
|---|---|---|---|
| Description text | `skills/gaspol-*/SKILL.md` frontmatter | Yes | Edit in place |
| CLAUDE.md version line | `CLAUDE.md` footer | Yes | Edit in place |
| Ticket counter | New `## gaspol Ticket Counter` section in target project's `CLAUDE.md` | No | Create |
| Ledger active/done state | `.gaspol/progress/progress-*.md` last-line handoff cursor | Yes (format) | Read-only scan, new script |
| Plan header fields (ledger path, ticket, artifact path) | Plan file's own header, written by `gaspol-plan` | Partial (ledger path exists; ticket + artifact path are new) | Extend header template |
| Design artifact | `Artifact` tool output (HTML/mermaid) | No | Create via existing `Artifact` tool — no new plumbing |
| Review lane findings | In-memory subagent outputs, merged before Step 2.5 refutation | Existing mechanism (Step 2.5 already merges) | Extend to tiered set of lanes |
| PR existence | `gh pr view` exit code | Yes | Bash gate, no agent call when absent |

---

## Implementation Plan

### Phase 1: Description compliance audit

**Estimated time:** 20 minutes

**Files:**
- Modify: `skills/gaspol-parallel/SKILL.md`, `skills/gaspol-review/SKILL.md`, `skills/gaspol-finish/SKILL.md`, `skills/gaspol-learn/SKILL.md`, `skills/gaspol-sync-docs/SKILL.md`, `skills/gaspol-adr/SKILL.md` (frontmatter `description` only — confirmed violations)
- Modify: `skills/gaspol-*/SKILL.md` (remaining 16 — audit pass, edit only if violating)
- Modify: `CLAUDE.md` (version line, and any Skill Routing row quoting an old description verbatim)
- Create: `tests/description-audit.sh`

**Steps:**
1. Write failing test `tests/description-audit.sh`: for each `skills/gaspol-*/SKILL.md`, extract the YAML `description`, strip the leading `"Use when ..."` clause, and fail if the remainder contains any of the known mechanism-narration markers (`Dispatches`, `Guides completion with`, `Distills`, `two-stage review`, `DAG lane scheduling`, `adversarial refutation pass`, `enhanced placeholder detection`). Expected error: script exits non-zero, printing the 6 confirmed-violating skill names.
2. Run it, confirm it fails listing exactly the 6 confirmed violators (plus any newly-found ones from the full-22 audit).
3. Edit each flagged `description` to end after the trigger-condition clause; move the removed mechanism text into the skill body (a new one-line intro sentence under the first `##` heading) if that detail isn't already stated there.
4. Update `CLAUDE.md` version footer `1.9.1` → the version this batch ships as (coordinate with final phase number, e.g. `1.11.0`); fix any routing-table row quoting an old description.
5. Re-run `tests/description-audit.sh`, confirm exit 0.
6. Commit: "fix(skills): trim descriptions to trigger-conditions-only, sync CLAUDE.md version"

**Verification:**
- [ ] `tests/description-audit.sh` exits 0
- [ ] No skill's description word count regressed below its documented CSO budget (specialized skills < 500 chars)
- [ ] `CLAUDE.md` version line matches `.claude-plugin/plugin.json`
- [ ] `tests/skill-triggering/run-all.sh` still passes (trigger conditions preserved, only mechanism prose removed)

---

### Phase 2: Ticket counter + collision-safe ledger scripts

**Estimated time:** 30 minutes

**Files:**
- Create: `skills/gaspol-execute/scripts/next-ticket`
- Create: `skills/gaspol-execute/scripts/scan-active-ledgers`
- Test: `tests/ticket-scripts/test-next-ticket.sh`, `tests/ticket-scripts/test-scan-active-ledgers.sh`

**Steps:**
1. Write failing test `tests/ticket-scripts/test-next-ticket.sh`: given a fixture `CLAUDE.md` containing `## gaspol Ticket Counter\n\nPrefix: IND\nLast ticket: IND-80\n`, running `next-ticket <fixture-CLAUDE.md>` must print `IND-81` and rewrite the fixture's `Last ticket:` line to `IND-81`. Expected error: `next-ticket: command not found` (script doesn't exist yet).
2. Run it, confirm it fails with "command not found".
3. Implement `skills/gaspol-execute/scripts/next-ticket` (bash, stdlib only): read the target `CLAUDE.md` path as `$1`; if no `## gaspol Ticket Counter` section exists, exit 2 with a message telling the caller to prompt the user for a prefix and create the section starting at `<PREFIX>-1`; otherwise parse `Prefix:` and `Last ticket:`, increment the numeric suffix, rewrite the line in place, print the new ticket to stdout. Add `--self-test` (matches `dag-lanes` convention) covering: fresh section creation path, normal increment, malformed section (missing `Last ticket:` line → exit 2 with clear error).
4. Run test, confirm pass. Run `next-ticket --self-test`, confirm pass.
5. Write failing test `tests/ticket-scripts/test-scan-active-ledgers.sh`: given a fixture `.gaspol/progress/` dir with `progress-IND-79.md` (last line ends `— NEXT: Phase 3`) and `progress-IND-80.md` (last line ends `— NEXT: DONE`), running `scan-active-ledgers <fixture-dir>` must print only `progress-IND-79.md`. Expected error: command not found.
6. Run it, confirm it fails.
7. Implement `skills/gaspol-execute/scripts/scan-active-ledgers` (bash): glob `progress-*.md` in the given directory, read each file's last line, regex-extract the trailing `NEXT: ...` cursor, print the filename if the cursor is not exactly `DONE`. Add `--self-test`.
8. Run test, confirm pass. Run `scan-active-ledgers --self-test`, confirm pass.
9. Commit: "feat(execute): add next-ticket and scan-active-ledgers scripts"

**Verification:**
- [ ] `tests/ticket-scripts/test-next-ticket.sh` exits 0
- [ ] `tests/ticket-scripts/test-scan-active-ledgers.sh` exits 0
- [ ] `next-ticket --self-test` exits 0
- [ ] `scan-active-ledgers --self-test` exits 0
- [ ] Both scripts are `chmod +x` AND committed with the executable bit in git's index (`git update-index --chmod=+x` — the repo has `core.fileMode=false`)

---

### Phase 3: Wire ticket assignment + in-flight guard into gaspol-plan / gaspol-execute

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md` (Plan Document Header section — add ticket + ledger-path minting)
- Modify: `skills/gaspol-execute/SKILL.md` (new Step 0, before the existing ledger-resolution step)

**Steps:**
1. Write failing test: a pressure/manual scenario doc `tests/pressure/prompts/gaspol-execute-inflight.txt` — a fixture working tree with one active ledger (`progress-IND-79.md`, `NEXT: Phase 2`) and a prompt asking to execute a *different* plan. Expected failure (documented baseline, run once before the fix): agent proceeds straight into execute without checking for or surfacing the other active ledger.
2. Run the baseline scenario against the *current* `gaspol-execute/SKILL.md` with a subagent, confirm the documented failure (no AskUserQuestion offered).
3. Edit `skills/gaspol-plan/SKILL.md`: in the Plan Document Header section, add a step that calls `next-ticket` against the target project's `CLAUDE.md` before the plan file's header is finalized (creating the `## gaspol Ticket Counter` section via `AskUserQuestion` for the prefix if absent), then writes the resulting ticket + derived ledger path `.gaspol/progress/progress-<PREFIX>-<N>.md` into the plan header alongside the existing ledger field.
4. Edit `skills/gaspol-execute/SKILL.md`: add Step 0 (before the current ledger-resolution step) — run `scan-active-ledgers .gaspol/progress`; if it prints any file not belonging to the plan about to execute, `AskUserQuestion` with the 4 options from the design spec (new worktree / resume other / proceed anyway / something else). If empty, proceed to ticket resolution: read the plan header's ticket field, or (fallback, no plan file / older plan) call `next-ticket` directly.
5. Re-run the `gaspol-execute-inflight` scenario with the edited skill, confirm the agent now runs `scan-active-ledgers` and surfaces the `AskUserQuestion`.
6. Add `tests/pressure/prompts/gaspol-execute-inflight.txt` to `tests/pressure/run-all.sh`'s case list.
7. Commit: "feat(plan,execute): ticket-numbered ledgers, in-flight collision guard"

**Verification:**
- [ ] `tests/pressure/run-all.sh` includes and passes the new `gaspol-execute-inflight` case
- [ ] `next-ticket`/`scan-active-ledgers` invoked from `SKILL.md` prose match the scripts' actual `$1`/exit-code contract from Phase 2
- [ ] Plan header template in `gaspol-plan/SKILL.md` shows both the ledger-path and ticket fields with a concrete example

---

### Phase 4: Three-path brainstorm router

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md` (new classification step at top of Phase 1; gate Phase 0.5/1.5/2.5/spec-file machinery to architectural-path only)
- Test: `tests/pressure/prompts/gaspol-brainstorm-bounded.txt`

**Steps:**
1. Write failing test `tests/pressure/prompts/gaspol-brainstorm-bounded.txt`: a one-file, well-scoped request against an existing repo ("add a `--verbose` flag to this existing CLI command"). Expected baseline failure (current skill): agent still runs full KB query + novelty classification + spec-file write for a task this small.
2. Run baseline scenario against current `gaspol-brainstorm/SKILL.md`, confirm the documented over-ceremony failure.
3. Edit `skills/gaspol-brainstorm/SKILL.md`: insert a "Three Paths" classification section before the existing Phase 1 — spike / bounded / architectural definitions, the one-way ratchet rule, and a Red-Flags table for classification-dodging. Mark Phase 0.5 (KB), Phase 1.5 (novelty), Phase 2.5/3 (design gate), and Phase 6's spec-file write as **architectural-path only**; bounded gets clarifying questions + short in-chat design + approval, no spec file; spike gets a 2-3 sentence probe + nod. HARD-GATE (approval before implementation) stated as applying to all three paths.
4. Re-run the `gaspol-brainstorm-bounded` scenario, confirm the agent now classifies the task as bounded, skips KB/novelty/spec-file, and stops for approval after a short in-chat design.
5. Add the new prompt to `tests/pressure/run-all.sh`.
6. Commit: "feat(brainstorm): three-path ceremony router (spike/bounded/architectural)"

**Verification:**
- [ ] `tests/pressure/run-all.sh` includes and passes `gaspol-brainstorm-bounded`
- [ ] Existing `tests/skill-triggering/prompts/gaspol-brainstorm.txt` (architectural-shaped prompt) still triggers full existing pipeline unchanged
- [ ] HARD-GATE language present and unchanged in meaning for all three paths

---

### Phase 5: gaspol-write-skill — Match-Form-to-Failure + micro-test wording

**Estimated time:** 20 minutes

**Files:**
- Modify: `skills/gaspol-write-skill/SKILL.md` (new section between "Bulletproofing" and "Skill Creation Checklist"; new subsection under RED-GREEN-REFACTOR)

**Steps:**
1. Write failing test: manual scenario — ask a subagent (skill loaded) "I have a discipline-skip failure where agents rationalize past a rule under pressure; what form should the guidance take, and how do I cheaply verify wording before running full pressure scenarios?" Expected baseline failure: skill has no explicit failure-type→form mapping and no micro-test methodology to point to; agent improvises.
2. Run baseline scenario, confirm the gap.
3. Edit `skills/gaspol-write-skill/SKILL.md`: add the "Match the Form to the Failure" table (4 failure types → right form / wrong form) plus the two wording rules (no nuance clauses; exemption clauses don't scope), positioned after "Bulletproofing". Add "Micro-Test Wording Before Full Pressure Scenarios" subsection under RED-GREEN-REFACTOR: 1 sample per variant, always a no-guidance control, 5+ reps, manual read of every flagged match, variance-as-metric. Add one checklist item to "Skill Creation Checklist" (GREEN phase): "Guidance form matches the classified failure type."
4. Re-run the scenario, confirm the agent now cites the table and proposes a micro-test pass before committing to full pressure scenarios.
5. Commit: "feat(write-skill): add match-form-to-failure framework and micro-test wording pass"

**Verification:**
- [ ] Both new sections present, cross-referenced from the Skill Creation Checklist
- [ ] No existing section removed or contradicted (self-review: rationalization-table guidance still applies to discipline-failure form, unchanged)

---

### Phase 6: Post-plan design-artifact gate

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md` (Execution Handoff section — new step before the existing 3 options)

**Steps:**
1. Write failing test: manual scenario — an architectural-path plan (per Phase 4's classification) finishes; check whether the current skill offers to render a flow artifact before presenting execute options. Expected baseline failure: skill goes straight from "plan written" to the 3 execution-handoff options, no artifact offer.
2. Run baseline scenario, confirm the gap.
3. Edit `skills/gaspol-plan/SKILL.md`: add a step in "Execution Handoff", before the 3 existing options, gated on the plan's path classification (from Phase 4 — architectural only, bounded/spike plans skip this silently). `AskUserQuestion`: offer to render a design artifact (HTML mockup via `Artifact` tool for UI-flow-heavy plans, reusing the `gaspol-design`/visual-companion pattern; mermaid diagram embedded in an artifact for backend/data-flow-heavy plans) representing the plan's flow. On accept: render it, record the artifact URL/path in the plan header as a new `Artifact:` field (alongside `Ledger:` and `Ticket:` from Phase 3). On decline: proceed straight to the 3 options, unchanged.
4. Re-run the scenario, confirm the offer appears for an architectural-path plan and the artifact path lands in the plan header on accept.
5. Commit: "feat(plan): post-plan design-artifact confirmation gate"

**Verification:**
- [ ] Offer only fires for architectural-path plans (bounded/spike plans from Phase 4 skip silently — confirmed by re-running Phase 4's bounded scenario end-to-end and seeing no artifact offer)
- [ ] Plan header shows the `Artifact:` field with a concrete example when accepted, and is simply absent (not `Artifact: n/a`) when declined or skipped

---

### Phase 7: Tiered gaspol-review lanes + plan/artifact cross-check

**Estimated time:** 35 minutes

**Files:**
- Modify: `skills/gaspol-review/SKILL.md` (Step 2 — tiered dispatch instead of single dispatch)
- Modify: `agents/code-reviewer.md` (drop standalone "Requirements" bullet — now owned by Tier 1's lane)
- Create: `skills/gaspol-review/plan-artifact-reviewer.md` (Tier 1)
- Create: `skills/gaspol-review/git-history-reviewer.md`, `skills/gaspol-review/code-comment-reviewer.md` (Tier 2, opt-in)
- Create: `skills/gaspol-review/pr-comments-reviewer.md` (dispatched only after a bash `gh pr view` existence check)

**Steps:**
1. Write failing test: manual scenario — a diff that matches its text plan but visibly diverges from an approved design artifact (fixture: plan says "list view", artifact shows "grid view", implementation is a list). Expected baseline failure: current single-lane `code-reviewer.md` checklist's one "Requirements" bullet doesn't check the artifact at all (artifact field doesn't exist pre-Phase-6, and even plan-text-divergence gets one shallow checklist line, not a dedicated pass).
2. Run baseline scenario against current `gaspol-review/SKILL.md`, confirm the artifact divergence is missed or only vaguely flagged.
3. Create `skills/gaspol-review/plan-artifact-reviewer.md` (Tier 1): reads the plan file and, if the plan header has an `Artifact:` field (Phase 6), the artifact too; reports FOUND/PARTIAL/MISSING/DIVERGED per plan item using `plan-verifier`'s existing vocabulary.
4. Create `skills/gaspol-review/git-history-reviewer.md` and `skills/gaspol-review/code-comment-reviewer.md` (Tier 2, opt-in only): git log/blame reintroduced-bug check; in-file-comment-compliance check.
5. Create `skills/gaspol-review/pr-comments-reviewer.md`; document in `gaspol-review/SKILL.md` that it is dispatched **only** after a plain `gh pr view` bash check succeeds — no PR, no agent call.
6. Edit `agents/code-reviewer.md`: remove the "Requirements" checklist bullet (now the Tier 1 lane's job); everything else (quality, architecture, testing, production-readiness, data-integrity) unchanged — this is Tier 0, cost stays exactly as today.
7. Edit `skills/gaspol-review/SKILL.md` Step 2: implement the 3-tier dispatch logic from the design spec — Tier 0 always; Tier 1 adds `plan-artifact-reviewer.md` when called from `gaspol-finish` or when the plan is architectural-path; Tier 2 adds the two opt-in lanes only on a contested Tier 1 finding or explicit user request. Lanes active in a tier dispatch concurrently (single message, multiple Agent calls). Findings merge into the existing Step 2.5 refutation pass, unchanged.
8. Re-run the artifact-divergence scenario at Tier 1, confirm the Plan+Artifact lane now flags DIVERGED with file:line evidence, and it survives refutation (it's a real finding). Confirm Tier 0 alone (no finish-time / non-architectural context) does NOT dispatch the extra lane — cost check.
9. Commit: "feat(review): tiered lane dispatch (Tier 0 unchanged, Tier 1 +plan/artifact, Tier 2 opt-in), drop flat fan-out"

**Verification:**
- [ ] Tier 0 dispatch is a single agent call, identical cost to pre-Phase-7 behavior
- [ ] Tier 1 dispatch is exactly 2 concurrent agent calls (core + plan-artifact), not 5
- [ ] Tier 2 lanes only dispatch when their trigger condition (contested finding / explicit request) is documented in the transcript, never by default
- [ ] `pr-comments-reviewer.md` is never dispatched when `gh pr view` fails (no PR) — verified by a scenario with no PR present
- [ ] Artifact-divergence scenario's finding survives adversarial refutation (Step 2.5) as CONFIRMED

---

### Phase 8: Mandatory code-review + security-review gate in gaspol-finish

**Estimated time:** 20 minutes

**Files:**
- Modify: `skills/gaspol-finish/SKILL.md` (pre-finish verification chain — insert 2 explicit steps)
- Modify: `skills/gaspol-verify/SKILL.md` (Layer 1 — clarify "run the app" requirement for UI/behavior-visible changes)

**Steps:**
1. Write failing test `tests/pressure/prompts/gaspol-finish-review-gate.txt`: a scenario where `gaspol-verify` and `plan-verifier` both pass clean but the diff has an obvious security issue (fixture: unparameterized query string concatenation) and a Critical code-quality issue. Expected baseline failure: current `gaspol-finish/SKILL.md` chain (verify → plan-verifier → sync-docs → learn) has no explicit step that would catch either, and proceeds to present merge/PR options.
2. Run baseline scenario against current `gaspol-finish/SKILL.md`, confirm it reaches the merge/PR options without either review running.
3. Edit `skills/gaspol-finish/SKILL.md`: rewrite the pre-finish chain to the 6-step sequence from the design spec — `gaspol-verify` → `plan-verifier` BLOCKING → `gaspol-review` at **Tier 1** (Phase 7) BLOCKING on any surviving Critical → `gaspol-security-review` (always runs, checklist result attached to the finish report, no longer conditional-trigger-only) → `gaspol-sync-docs` → `gaspol-learn`.
4. Edit `skills/gaspol-verify/SKILL.md` Layer 1 ("Technical"): add a clause — for changes touching UI or user-visible behavior, Layer 1 must include invoking the `run` skill to observe the feature live, not only `npm test`/`tsc`/lint (one-line rationale: a passing per-phase gate is not by itself a quality claim).
5. Re-run the `gaspol-finish-review-gate` scenario, confirm the agent now runs `gaspol-review` (Tier 1) and `gaspol-security-review` and surfaces both the Critical finding and the security issue before offering merge/PR options.
6. Add the new prompt to `tests/pressure/run-all.sh`.
7. Commit: "feat(finish,verify): hard-wire mandatory code-review + security-review gate"

**Verification:**
- [ ] `tests/pressure/run-all.sh` includes and passes `gaspol-finish-review-gate`
- [ ] `gaspol-finish/SKILL.md`'s chain is a literal numbered list matching Phase 8's step 3 exactly (no more "use before merging" implication-only language)
- [ ] `gaspol-verify` Layer 1 change does not alter Layers 2-4
- [ ] Confirm `gaspol-finish`'s call into `gaspol-review` is Tier 1 (2 agents), not Tier 2 — cost check consistent with Phase 7

---

### Phase 9: Proactive context-budget checkpoint

**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md` (per-phase checkpoint section)
- Modify: `skills/gaspol-parallel/SKILL.md` (durable-ledger check-in section)

**Steps:**
1. Write failing test: manual scenario — run 3 phases of a fixture plan through `gaspol-execute` in one continuous session; expected baseline failure (current skill): no checkpoint offers a session breakpoint, execution proceeds straight to phase 4 unprompted.
2. Run baseline scenario (or reason through the current `SKILL.md` text — no code path exists for this check), confirm the gap.
3. Edit `skills/gaspol-execute/SKILL.md`: after the checkpoint report for the 3rd (and every 3rd subsequent) phase completed in the current run, add `AskUserQuestion` — "N phases done this session. Continue here, or pick up fresh next session? The ledger has the exact resume point either way." Options: continue / stop here (report resume point) / raise threshold for this run.
4. Edit `skills/gaspol-parallel/SKILL.md`: same check after every 3rd wave in the durable-ledger check-in section.
5. Re-run the 3-phase scenario, confirm the checkpoint question now appears after phase 3, and that choosing "stop here" produces a clear, correct resume-point report referencing the ticket-numbered ledger (Phase 3's work).
6. Commit: "feat(execute,parallel): proactive context-budget checkpoint every 3 phases"

**Verification:**
- [ ] Question appears after phase 3, not before (phases 1-2 unaffected)
- [ ] "Stop here" path reports the exact ledger path and next-phase cursor, matching Phase 3's ticket-numbered format
- [ ] "Raise threshold" path correctly suppresses the question for the stated number of additional phases
- [ ] `gaspol-parallel`'s version fires on wave boundaries, not mid-wave

---

## Execution Handoff

Dependency order: Phases 1, 2, 4, 5, 9 are independent of everything else and each other —
candidates for `gaspol-parallel` (mode: independent-domains). Phase 3 depends on Phase 2
(uses its scripts). Phase 6 depends on Phase 4 (uses its path classification). Phase 7
depends on Phase 6 (artifact field) for its Tier 1 lane's artifact-check sub-feature — the
plan-only part of Tier 1 could ship without item 6, but building them together avoids a
second pass through the same file. Phase 8 depends on Phase 7 (calls `gaspol-review` at
Tier 1 as a hard gate).

Suggested sequencing: `{1, 2, 4, 5, 9}` parallel → `3` → `6` → `7` → `8`. This plan is a
live example of Item 9's own recommendation: 9 phases across a dependency chain is exactly
the shape that benefits from a checkpoint at the phase-3 mark — expect that question to
fire partway through the sequential `3 → 6 → 7 → 8` chain.

Ready to start Phase 1? `gaspol-execute` will run it with per-phase checkpoints, or use
`gaspol-parallel` for the independent-domains batch `{1, 2, 4, 5, 9}` first.
