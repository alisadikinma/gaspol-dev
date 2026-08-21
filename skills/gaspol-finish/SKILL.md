---
name: gaspol-finish
description: "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work."
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

Before presenting any options, complete this chain **in order, all six steps**. Do not skip
steps. None of the six is optional or conditional on the diff's contents — steps 3 and 4 run on
every finish pass exactly like steps 1, 2, 5, and 6 always have.

### Step 0: Run the deterministic checks first — before dispatching any agent

The chain's cheapest gate runs first, always. Derive the command with
`"$CLAUDE_PLUGIN_ROOT/skills/gaspol-execute/scripts/detect-stack" <project-root>` and run what
it prints.

**Two rails on that line, both learned the hard way.** The script is reached through
`$CLAUDE_PLUGIN_ROOT`, never relatively: this skill runs with the **target project** as its
working directory, so a relative path executes whatever a repo carrying that path happens to
ship — and `detect-stack`'s stdout is then executed, so a substituted script both runs and
chooses the next command. And **never go looking for a checker to run.** An earlier draft of this
step said "where the repository keeps a mutation harness over its own gates, run that too", which
instructs an agent to discover and execute an arbitrary script out of the working repository —
Step 0 runs *before* `/security-review`, so nothing would have looked at it first. A repository's
extra checks belong in the plan's declared verification commands, or named literally in its own
`CLAUDE.md`, where a human wrote them down. In THIS repository that is
`tests/ticket-scripts/test-gate-mutations.sh`.

**Why this is Step 0 and not a footnote.** In IDS-8 an eight-minute Opus audit was dispatched
over a tree whose two-second suite was already red, and three of that ticket's five gate
regressions would have been caught in seconds. An audit of code that is about to change is
worse than no audit: it costs the time AND produces a verdict nobody can rely on.

Red here means **fix before dispatching anything**. This is not a BLOCKING gate in the
merge-refusing sense — it is an ordering rule, and it applies again inside every fix round
(see The Fix Loop below).

### Step 1: Run gaspol-verify (all 4 layers)

If you haven't already run verification in this session, invoke gaspol-verify now.

This ensures:
- All tests pass
- No lint errors or warnings
- Build succeeds
- No unintended changes

If gaspol-verify was already run and passed in this session, you may skip this step.

### Step 2: Run plan-verifier agent BLOCKING (step-level, evidence-based, spot-check 3 random FOUND items)

**The one conditional gate in this chain.** `plan-verifier` audits the implementation against
a plan; with no plan, there is nothing to audit against and the agent — an Opus, step-level
pass — returns nothing for real cost. Skip it **only when the branch provably references no
plan**: no `**Plan:**` header in a ledger for this branch, **and** no `docs/plans/*-plan.md`
touched by the diff. Provably absent, not "looks like it doesn't need one".

When you skip it, record `plan-verifier: skipped — no plan referenced by this branch` in the
ledger and continue. A silent omission is indistinguishable from a gate that ran and passed.

Every other step in this chain is unconditional, `/security-review` above all: security
defects hide in diffs that look boring, and in a skills repository markdown **is** the
executed surface, so "docs only" never means "cannot introduce a vulnerability".

In every other case, dispatch the upgraded `plan-verifier` agent (step-level, evidence-based)
to audit the implementation against the plan. See `agents/plan-verifier.md`.

**This step is BLOCKING.** You CANNOT present merge/PR options until the verdict is `CLEAN`.

Input:
- Plan file path (from `docs/plans/YYYY-MM-DD-<TICKET>-<topic>-plan.md`)
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

**If plan-verifier returned BLOCKING**, return to execute/fix the issues, then re-run
plan-verifier. Do NOT proceed to Step 3 — don't waste a review pass on code that's about to
change. **The re-run is bounded and scoped — see The Fix Loop below.**

### Step 3: Run gaspol-review AT TIER 1 -- BLOCKING on any surviving Critical finding

Run `gaspol-review`, dispatched at **Tier 1** per its own Step 2 tiered-dispatch table
(`skills/gaspol-review/SKILL.md`): Tier 0 (`agents/code-reviewer.md`, 1 call) plus the
`plan-artifact-reviewer.md` lane (2 agent calls total, run concurrently). `gaspol-finish` is one
of the two named Tier 1 triggers in that table — do NOT escalate to Tier 2 from this call site;
Tier 2 stays opt-in (contested finding or explicit user request), not part of this mandatory
chain.

Findings must clear gaspol-review's own Step 2.5 adversarial refutation before they count.

**This step is BLOCKING.** Any surviving (post-refutation, CONFIRMED or unverifiable) Critical
finding STOPS the chain here.

- If plan-verifier (Step 2) is BLOCKING, return to execute/fix first — don't waste a review pass
  on code that's about to change.
- If gaspol-review (this step) is BLOCKING, fix and re-run gaspol-review before proceeding. Do
  not proceed to Step 4 until it is clean.

### Step 4: Run the built-in `/security-review` -- ALWAYS runs from this chain

Run the **`/security-review`** slash command. It is a Claude Code built-in — compiled into the
CLI itself, no plugin and no install — and it reviews the pending changes on the current branch.
gaspol used to ship its own forked checklist here; the built-in supersedes it, so the fork was
deleted in v1.14.0 rather than left to drift.

**From this finish chain it ALWAYS runs**, on every branch, regardless of whether the diff appears
security-sensitive. It is not conditional-trigger-only here. Its result gets attached to the
finish report.

- If it reports an insecure pattern (string-concatenated SQL, JWT in `localStorage`, secrets in
  source, missing server-side authz), treat it like a BLOCKING finding: STOP and use
  AskUserQuestion — `[Fix now]` / `[Accept risk with documented reason]`.
  Never present merge options with an unresolved security finding.
- Report the result even when it is clean, e.g. "Security review: PASSED (`/security-review`, no
  findings)."
- If `/security-review` is unavailable in this environment, say so explicitly and walk the same
  ground by hand — secrets in source, unparameterized queries, missing server-side authz, XSS
  sinks, CSRF, rate limiting. **Never record the step as passed when it did not run.**

### Step 5: Run gaspol-sync-docs (update CLAUDE.md) -- now evidence-gated

Update CLAUDE.md and any other documentation with changes from this work.

**Evidence required — this step used to be a self-reported checkbox.** Nothing verified
that CLAUDE.md had actually changed, so `[x] Step 5: COMPLETED` could be written over a
branch that never touched it. That is a completion claim without evidence, which Iron
Law 3 forbids everywhere else in this plugin.

If the branch made a **structural change** — added, removed, or renamed anything under
`skills/`, `agents/`, `hooks/`, or `scripts/`, or altered a routing table, a chain step,
or a documented command — then **CLAUDE.md must appear in the branch diff**:

```bash
git diff --name-only <BASE>..HEAD | grep -q '^CLAUDE.md$'
```

If that check fails on a structural change, Step 5 is NOT complete: run `gaspol-sync-docs`
for real, then re-check. Only a branch with no structural change may record Step 5 as
"no doc-visible change", and it must say which — never a bare COMPLETED.

This ensures:
- New tables, functions, routes, or components are documented
- Changed configurations are reflected
- Removed features are cleaned up from docs
- The next session has accurate context

### Step 6: Trigger gaspol-learn (pattern capture) -- unchanged

Invoke `gaspol-learn` for quality-gated pattern capture into the cross-project knowledge base
(user confirms before write).

### The Fix Loop — every BLOCKING gate in this chain is bounded

**Canonical rule: [skills/_shared/fix-loop.md](../_shared/fix-loop.md).** `gaspol-parallel`
applies it per task; this chain applies it per gate. Read it there — it is stated once so the
two cannot drift.

What it means at each of the gates above:

- **The round cap applies per gate.** A round is one fix plus one scoped re-review. Early
  rounds resume the fixer that already has the context; later ones dispatch fresh, one model
  tier above. The final round **adjudicates** the still-open findings against the plan and
  continues — stop and ask the user only when every path forward is a guess. **The cap's number
  is deliberately not repeated here**: a constant copied into two skills is a constant that will
  disagree with itself, which is the same defect as the duplicated knowledge pipeline IDS-8
  removed. Read it in the shared file.
- **When a gate returns BLOCKING, record the SHA that verdict saw** — the HEAD it actually
  audited. Whatever re-runs a gate scopes to that SHA: the re-review reads `<SHA>..HEAD`, the
  fix diff and nothing else. Re-auditing the whole branch after every fix is how IDS-8's chain
  reached roughly eleven agent dispatches.
- **Cheap before expensive, every round.** Step 0's checks run again before each fix round's
  dispatch. Adding an exemption to a gate means adding its attack row to the mutation harness
  **first**, and watching it fail — five separate times in IDS-8, closing one finding loosened
  the gate beside it, and every one of those was found by an expensive audit rather than by the
  harness that existed to catch it.

**The bound shortens rounds, never the chain.** All six steps stay. In IDS-8 each one found a
real defect, including a skill that had silently stopped loading and a first capture that
aborted on any fresh machine — a chain that feels slow argues for scoping its re-runs, not for
trusting a diff nobody audited.

### Verify Chain Complete

All six steps must be completed (or explicitly skipped with a documented reason) before
proceeding.

```
Verification Chain Status:
[x] Step 1 gaspol-verify: PASSED (or: passed earlier this session)
[x] Step 2 Plan verifier: CLEAN (BLOCKING gate passed) (or: no plan exists, documented skip)
[x] Step 3 gaspol-review (Tier 1): CLEAN (BLOCKING gate passed, 0 surviving Critical findings)
[x] Step 4 Security review (built-in /security-review): PASSED
[x] Step 5 gaspol-sync-docs: COMPLETED
[x] Step 6 gaspol-learn: COMPLETED (or: user declined capture)
```

**If plan-verifier (step 2) returned BLOCKING**, the chain is incomplete. Do NOT present options.
Return to execute/fix the issues, then re-run from Step 2.

**If gaspol-review (step 3) is BLOCKING**, the chain is incomplete. Fix, re-run gaspol-review, and
do not proceed to step 4 until clean.

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

# Verify tests still pass after merge. DERIVE the command -- never assume npm.
# detect-stack prints "<level>: <command>" lines for whatever this project
# actually is; run the unit line. No stack markers -> use the commands the plan
# declared, and say so explicitly rather than skipping the run.
skills/gaspol-execute/scripts/detect-stack .

# Delete feature branch
git branch -d feature/my-feature

# Remove the worktree if one was created by gaspol-worktree (AFTER merge is confirmed)
git worktree remove .worktrees/my-feature 2>/dev/null || true
```

**Use when:** Small changes, sole developer, no review needed.

**Merging is not publishing.** A local merge leaves the work on this machine only.
Before reporting the branch as shipped:

```bash
git push origin main
```

If this repository is a Claude Code **plugin**, pushing still is not enough -- the
installed copy is a cached version, not the checkout:

```bash
claude plugin marketplace update <marketplace>
claude plugin update <plugin>@<marketplace>   # the full id; the bare name fails
                                              # with: Plugin "<name>" not found
```

Restart Claude Code afterwards; an updated plugin does not take effect in the
running session. Skipping this is how a merged, tagged, correct version sits inert
while the repo claims it shipped.

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

## Close the Ledger (after the chosen option is executed)

The per-ticket ledger `.gaspol/progress/PROGRESS-<TICKET>.md` is created by
`gaspol-plan` and ticked by `gaspol-execute` / `gaspol-parallel` after every phase.
**Nothing closed it.** It is gitignored, so a stale one never shows up in
`git status` and never gets noticed -- ledgers from finished tickets pile up
carrying a cursor that still claims work is in flight.

Finish owns the end of that lifecycle:

1. Append a final `## Log` line recording the outcome, ending with the cursor
   `— NEXT: DONE`. State which option was taken and the merge/PR reference, e.g.
   `— merged to main as <sha> — NEXT: DONE`. If the branch was kept or discarded,
   say that instead -- a truthful cursor beats a tidy one.
2. Confirm every `## Checklist` line is `[x]` or `[~]`. A `[ ]` or `[>]` left at
   finish time means the work is not actually done, or the ledger lied during
   execution. Either way, resolve it before claiming completion -- do not tick it
   silently to make the file look finished.
3. Surface any OTHER ledger still open, so the pile is visible rather than growing:

```bash
skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress
```

   It prints one basename per ledger whose last `NEXT:` marker is not `DONE`.
   Empty output means nothing else is in flight. Report what it prints; do not
   act on other tickets' ledgers from here.

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
2. **Never skip the verification chain** -- verify, plan-check, review (Tier 1), security-review, sync-docs, learn. All six.
3. **Never force-push without explicit user request** -- Force-push rewrites history and can destroy others' work.
4. **Never merge without knowing the base branch** -- Merging into the wrong branch causes cascading problems.
5. **Never discard without typed confirmation** -- Accidental discards destroy work permanently.
6. **Never clean up worktree before confirming the merge succeeded** -- If the merge fails, you need the worktree to fix it.

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-verify` | Step 1 of verification chain |
| `plan-verifier` agent | Step-level evidence-based BLOCKING audit (Step 2 of chain) |
| `gaspol-review` | Tier 1 dispatch, BLOCKING on surviving Critical findings (Step 3 of chain) |
| `/security-review` (CLI built-in) | Always runs from this call site, gates on any finding (Step 4 of chain) |
| `gaspol-sync-docs` | Step 5 of verification chain |
| `gaspol-learn` | Step 6 of verification chain (pattern capture) |
| `gaspol-execute` | Finish is the final step of execute workflow |
| `gaspol-tdd` | Tests must pass before finishing |
| `gaspol-worktree` | Created the isolated workspace upstream; finish owns teardown — `git worktree remove` runs here AFTER the merge/PR decision, never before |
| `gaspol-adr` | Capture ADRs for deferred MISSING items and DIVERGED items |
