---
name: gaspol-auto
description: "Use when executing an implementation plan on a familiar codebase where per-phase checkpoint fatigue outweighs safety benefit."
---

# gaspol-auto

## Iron Law

```
NO AUTONOMOUS EXECUTION WITHOUT EXPLICIT UPFRONT PLAN APPROVAL + HARD STOP GUARDRAILS
```

Autonomous ≠ unsafe. User approves the WHOLE plan once upfront. Execution proceeds phase-by-phase without per-phase prompts. But hard-stop conditions ALWAYS pause — no bypass.

---

## Core Principle

For familiar codebases, per-phase checkpoint creates fatigue ("Proceed?" 10x per feature). When plan is solid + codebase known + user confident, autonomous execution saves significant time. Safety maintained via hard-stop triggers, not constant approval.

## When to Use

- Plan is detailed, verified, approved
- Codebase is familiar to user (not first time editing this project)
- Task is substantial enough (≥5 phases) that per-phase prompts become overhead
- User has reviewed plan and confirms "go end-to-end"

## When NOT to Use

- First time in this codebase (prefer `gaspol-execute` with per-phase checkpoints)
- Plan is speculative or unverified
- Task involves destructive irreversible operations (auto-mode pauses on those anyway, but better to not start)
- Multiple architectural forks within plan (each fork needs ADR + decision — breaks flow)
- Plan contains placeholders or unresolved dependencies

---

## Process Flow

### Pre-Flight Gate (MANDATORY)

Before ANY phase executes:

1. **Plan review** — Present full plan summary to user:
   ```
   Plan: <path>
   Phases: N
   Est. total time: <sum>
   Files to modify: <list>
   Dependencies: <external services, APIs>

   [Approve autonomous run — proceed end-to-end]
   [Modify plan first — return to gaspol-plan]
   [Run manually — switch to gaspol-execute per-phase]
   [Abort]
   ```

   AskUserQuestion — MUST be answered before proceeding.

2. **Clean git state** — Verify no uncommitted changes that could confuse plan-verifier later:
   ```bash
   git status --porcelain
   # If output non-empty, warn user, offer stash or abort
   ```

3. **Test baseline** — Run existing test suite. Must pass.
   ```bash
   <project test command from CLAUDE.md>
   # If failures, autonomous mode refuses to start
   ```

4. **Plan TDD gate** — Verify every phase in plan has "Write failing test..." as step 1 (same check gaspol-execute enforces).

Only after all 4 pre-flight checks pass, proceed.

### Execution Loop

For each phase in plan (sequential):

1. **Dispatch implementer** (model: sonnet per rubric) with phase text + CLAUDE.md context + anti-placeholder rules + TDD step 1 hard gate
2. **Wait for completion** — implementer runs RED → GREEN → REFACTOR → commit
3. **Post-phase silent check**:
   - Run tiered auto-review classifier (from Phase F logic)
   - If REVIEW and findings surfaced → mini-pause (see Hard Stop below if Critical)
4. **Continue to next phase** (NO per-phase user prompt — that's the autonomous part)

### Hard Stop Conditions (ALWAYS pause)

Execution pauses and prompts user via AskUserQuestion on ANY of:

| Condition | Detection | Action |
|---|---|---|
| Test failure | implementer reports test fail OR subsequent phase reveals regression | Pause — present error + options: [Fix and continue] [Abort] [Skip phase with ADR] |
| Placeholder detected | Anti-placeholder rule triggers (hardcoded array, empty state, etc.) | Pause — present placeholder + options |
| Destructive operation | rm -rf, git reset --hard, DROP TABLE, file overwrite without backup | Pause — require explicit confirm |
| Ambiguity in plan | Phase text unclear, multiple valid interpretations | Pause — request clarification |
| Iron Law violation | TDD gate bypass attempted, completion claim without evidence | Pause — refuse to proceed |
| 3+ consecutive errors | Same failure mode 3x in a row | Pause — architectural issue likely |
| External API failure | Service unavailable, auth expired | Pause — wait for user resolution |
| Git conflict | Merge conflict, unpushable state | Pause — require manual resolution |

Pause state = full context visible to user + options to continue/abort/adjust.

### Post-Run Consolidated Report

After ALL phases complete (or aborted):

1. **Auto-invoke verification chain**:
   - `gaspol-verify` (all 4 layers)
   - `plan-verifier` agent (BLOCKING — if not CLEAN, report but don't present "success")
2. **Compile report**:
   ```markdown
   ## Autonomous Run Report

   **Plan:** <path>
   **Started:** <ISO timestamp>
   **Completed:** <ISO timestamp>
   **Duration:** <elapsed>
   **Phases:** <completed>/<total>

   ### Completed Phases
   - Phase A: <name> — <1-line summary>
   - Phase B: <name> — <1-line summary>
   - ...

   ### Hard Stops Encountered
   - Phase C @ 14:23: test failure → user fixed → resumed
   - Phase F @ 15:01: placeholder detected → user approved real integration → resumed

   ### Plan Verifier Verdict
   Summary: FOUND=N PARTIAL=M MISSING=X DIVERGED=Y
   Verdict: CLEAN / BLOCKING

   ### gaspol-verify Results
   - Technical: PASS
   - Plan fidelity: PASS (from plan-verifier)
   - Placeholder scan: PASS
   - Integration: PASS

   ### Next Step
   <the finish offer — see below>
   ```
3. **Surface report to user** — autonomous doesn't mean invisible.
4. **Present the finish offer** per [_shared/finish-offer.md](../_shared/finish-offer.md). It
   holds the three options and their outcomes; do not restate them here. Where the run left
   issues open, offer `[Fix remaining issues]` alongside them.

   This is **not a mid-run checkpoint** — the autonomous run has already ended when the offer
   appears, so the no-pause-between-phases guarantee above is untouched. The offer is about what
   happens to the branch, not about whether execution continues.

### Rollback on Abort

If user aborts mid-run:
- Current phase changes NOT committed (pending)
- User chooses: `[Keep partial work]` / `[Discard partial, revert to pre-phase state]` / `[Commit partial with WIP marker]`
- Previously-completed phases remain committed (already shipped)

---

## What Autonomous DOES NOT Do

Even in autonomous mode, these ALWAYS need explicit user action (no auto-execute):

- Merge to main / master branch
- Git push --force
- PR creation (gh pr create)
- External messaging (Slack, email, comment on GH issue)
- Destructive ops on shared state (DB drop, file delete outside project)
- Plan modifications (can't silently adjust plan during auto run)
- ADR creation for architectural forks (user confirms decision)

If execution would require any of these, hard-stop pauses and prompts.

---

## Autonomous Mode vs gaspol-execute

| Aspect | gaspol-execute | gaspol-auto |
|---|---|---|
| Checkpoint per phase | Yes (user approves each) | No (user approves plan once) |
| Prompts during execution | Many | Only on hard-stop |
| Hard-stop conditions | Same | Same |
| Plan-verifier at end | BLOCKING | BLOCKING |
| Auto-review tiered | Yes (per phase) | Yes (per phase, but no checkpoint prompt unless Critical) |
| TDD hard gate | Yes | Yes |
| Best for | Unfamiliar codebase, first-time feature | Familiar codebase, verified plan |

---

## Red Flags

| Red Flag | Fix |
|---|---|
| Skipping pre-flight gate | Reject — always run all 4 checks |
| Bypassing hard-stop condition | No override — hard-stop is absolute |
| Silent failure (error not surfaced) | Always surface in post-run report |
| Merging to main autonomously | Blocked — always manual |
| Autonomous mode without prior `gaspol-execute` experience in same codebase | Warn user — recommend execute-mode first time |
| Plan-verifier verdict ignored post-run | Never — verdict must be presented |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-plan` | Source of plan; auto verifies plan format before starting |
| `gaspol-execute` | Alternative execution mode (user picks) |
| `plan-verifier` agent | Same BLOCKING post-run audit |
| `gaspol-verify` | Auto-invoked at end, all 4 layers |
| `gaspol-review` | Code review invoked tiered per complexity (from Phase F) |
| `gaspol-finish` | Next step after CLEAN verdict |
| `gaspol-adr` | Captures decisions at hard-stop "ambiguity" pauses |

---

## Verification Checklist

Pre-flight:
- [ ] Plan review presented to user, approved
- [ ] Git state clean (or stashed)
- [ ] Baseline tests pass
- [ ] Plan TDD gate: every phase has "Write failing test for..." step 1

During execution:
- [ ] Hard-stop conditions monitored every phase
- [ ] TDD gate enforced per phase
- [ ] Auto-review classifier runs per phase
- [ ] No destructive ops without pause

Post-run:
- [ ] gaspol-verify all 4 layers executed
- [ ] plan-verifier BLOCKING audit executed
- [ ] Consolidated report presented to user
- [ ] Hard-stops logged in report
- [ ] Next-step options offered (finish / fix / review)
