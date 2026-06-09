---
name: gaspol-finish
description: "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work. Guides completion with mandatory verification chain: plan-verifier, sync-docs, then presents structured merge/PR/cleanup options."
---

# Finishing a Development Branch

## Core Principle

Verify first. Sync docs. Then present options. Never skip the verification chain.

Finishing is not just merging. It is the final quality gate that ensures the work is correct, documented, and safely integrated. Rushing this step is how bugs reach production.

---

## When to Use

- Implementation is complete
- All tests pass locally
- You need to decide: merge, PR, keep, or discard
- You're done working on a feature branch or worktree

## When NOT to Use

- Tests are still failing (fix them first)
- Implementation is partial (finish the work first)
- You haven't verified the work (run gaspol-verify first)

---

## Pre-Finish Verification Chain (MANDATORY)

Before presenting any options, complete this chain in order. Do not skip steps.

### Step 1: Run gaspol-verify

If you haven't already run verification in this session, invoke gaspol-verify now.

This ensures:
- All tests pass
- No lint errors or warnings
- Build succeeds
- No unintended changes

If gaspol-verify was already run and passed in this session, you may skip this step.

### Step 1.5: Security Pre-Deployment Checklist (conditional gate)

If the work touched **auth, secrets, user input, file uploads, API endpoints,
payment, or sensitive data**, run the Pre-Deployment Security Checklist from
`gaspol-security-review` before presenting any merge/PR options.

- If a checklist item fails on an insecure pattern (string-concatenated SQL, JWT in
  `localStorage`, secrets in source, missing server-side authz), treat it like a
  BLOCKING finding: STOP and use AskUserQuestion — `[Fix now]` / `[Accept risk with
  documented reason]`. Never present merge options with an unresolved security FAIL.
- If the work did not touch any security-sensitive surface, note "Security gate: N/A
  (no security-sensitive changes)" and proceed.

### Step 2: Run Plan Verifier (BLOCKING)

Dispatch the upgraded `plan-verifier` agent (step-level, evidence-based) to audit the implementation against the plan. See `agents/plan-verifier.md`.

**This step is BLOCKING.** You CANNOT present merge/PR options until the verdict is `CLEAN`.

Input:
- Plan file path (from `docs/plans/YYYY-MM-DD-<topic>.md`)
- Base SHA and HEAD SHA (diff scope)

Output — if verdict is:
- **CLEAN** — all items FOUND with code evidence, 0 placeholders → proceed to Step 3
- **BLOCKING** — MISSING > 0 OR unapproved PARTIAL > 0 OR placeholders > 0 → STOP

For BLOCKING, use AskUserQuestion to present per-issue resolution:
- Per MISSING item: `[Implement now]` / `[Defer with ADR capture]` / `[Remove from plan]`
- Per PARTIAL item: `[Complete implementation]` / `[Accept as-is with documented gap]`
- Per DIVERGED item: `[Revert to plan]` / `[Update plan to match implementation with justification]`
- Per placeholder: `[Implement real source]` / `[Explicit user approval to ship with placeholder]`

**Anti-hallucination spot-check (mandatory):** After plan-verifier reports, sample 3 random FOUND items and Read the quoted file:line to verify quote accuracy. Fabricated quotes → auto-downgrade to MISSING + re-evaluate verdict.

If no plan exists (ad-hoc implementation), skip this step with documented reason.

### Step 3: Run gaspol-sync-docs

Update CLAUDE.md and any other documentation with changes from this work.

This ensures:
- New tables, functions, routes, or components are documented
- Changed configurations are reflected
- Removed features are cleaned up from docs
- The next session has accurate context

### Step 4: Verify Chain Complete

All three steps must be completed (or explicitly skipped with reason) before proceeding.

```
Verification Chain Status:
[x] gaspol-verify: PASSED (or: passed earlier this session)
[x] Security checklist: PASSED (or: N/A — no security-sensitive changes)
[x] Plan verifier: CLEAN (BLOCKING gate passed) (or: no plan exists, documented skip)
[x] gaspol-sync-docs: COMPLETED
```

**If plan-verifier returned BLOCKING**, the chain is incomplete. Do NOT present options. Return to execute/fix the issues, then re-run verification.

---

## Determine Base Branch

Before presenting options, identify the correct base branch:

```bash
# Check if the branch tracks a remote
git rev-parse --abbrev-ref @{upstream} 2>/dev/null

# Check the likely base branch
git log --oneline --merges -1  # recent merge from?
git merge-base main HEAD       # divergence point from main
```

Common base branches:
- `main` -- for feature branches
- `develop` -- for projects using gitflow
- Parent feature branch -- for sub-feature branches

---

## Present Options

After the verification chain passes, use the **AskUserQuestion** tool (MANDATORY) to present exactly these 4 options as an interactive popup modal:

### Option 1: Merge Locally

Merge the feature branch into the base branch locally.

```bash
# Switch to base branch
git checkout main

# Merge feature branch
git merge feature/my-feature --no-ff

# Verify tests still pass after merge
npm test  # or project-specific test command

# Delete feature branch
git branch -d feature/my-feature

# Remove the worktree if one was created by gaspol-worktree (AFTER merge is confirmed)
git worktree remove .worktrees/my-feature 2>/dev/null || true
```

**Use when:** Small changes, sole developer, no review needed.

### Option 2: Push and Create PR

Push the branch to remote and create a pull request.

```bash
# Push branch to remote
git push -u origin feature/my-feature

# Create PR (using gh CLI)
gh pr create --title "feat: description" --body "## Summary\n..."
```

**Use when:** Team review needed, CI/CD pipeline should run, documentation trail desired.

### Option 3: Keep As-Is

Leave the branch and worktree in place. Continue work later.

No git commands needed. Simply inform the user:
- Current branch name
- Worktree location (if applicable)
- What's been completed so far
- What remains to be done

**Use when:** Work is paused, not complete, or waiting on external dependency.

### Option 4: Discard

Delete all work on this branch. This is destructive and irreversible.

**Requires explicit confirmation:** The user must type "discard" to confirm.

```bash
# Switch to base branch
git checkout main

# Delete the branch (force, since it's not merged)
git branch -D feature/my-feature

# Remove worktree if exists
git worktree remove .worktrees/my-feature --force
```

**Use when:** Approach was wrong, work is obsolete, starting over.

---

## Post-Finish Summary

After executing the chosen option, provide a summary:

```
## Finish Summary

Branch: feature/my-feature
Base: main
Option: [Merged locally / PR created / Kept / Discarded]
Verification: All passed

Changes:
- [List of key changes]

[If PR]: PR URL: https://github.com/...
[If kept]: Resume with: cd .worktrees/feature-name
[If discarded]: Branch and worktree deleted
```

---

## Red Flags

1. **Never merge with failing tests** -- Fix the tests first. No exceptions.
2. **Never skip the verification chain** -- verify, plan-check, sync-docs. All three.
3. **Never force-push without explicit user request** -- Force-push rewrites history and can destroy others' work.
4. **Never merge without knowing the base branch** -- Merging into the wrong branch causes cascading problems.
5. **Never discard without typed confirmation** -- Accidental discards destroy work permanently.
6. **Never clean up worktree before confirming the merge succeeded** -- If the merge fails, you need the worktree to fix it.

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-verify` | Step 1 of verification chain |
| `gaspol-sync-docs` | Step 3 of verification chain |
| `gaspol-execute` | Finish is the final step of execute workflow |
| `plan-verifier` agent | Step-level evidence-based BLOCKING audit (Step 2 of chain) |
| `gaspol-tdd` | Tests must pass before finishing |
| `gaspol-worktree` | Created the isolated workspace upstream; finish owns teardown — `git worktree remove` runs here AFTER the merge/PR decision, never before |
| `gaspol-adr` | Capture ADRs for deferred MISSING items and DIVERGED items |
