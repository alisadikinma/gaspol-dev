# gaspol-finish: detail moved out of SKILL.md

Text moved verbatim from `SKILL.md` to keep that file under the compaction cut. Every gate, step, and BLOCKING condition stays in `SKILL.md`.

## Where Step 0 went

**Where Step 0 went (IDS-17).** This chain used to open with a Step 0 that ran `detect-stack`
and `regression-gate` before any agent was dispatched. `gaspol-verify` Layer 1 runs both of
those already, and `gaspol-verify` is step 1 — so cheap-checks-first is **preserved by position**
rather than by repetition. Nothing about the ordering rule changed; only the duplicate went. If a
future edit makes step 1 conditional, that ordering is lost and Step 0 has to come back.

## The Offers: rationale

### `/security-review` (built-in)

**Why it is an offer.** Not every ticket changes anything security-related, so running it on
every branch spends time on branches where there is nothing to find. This overrides the earlier
rule that it must run unconditionally; the reason that rule existed — in a skills repository
markdown IS the executed surface — is recorded in the ADR, not deleted.


**Not affected by this change:** `gaspol-execute` Step 3.6 still runs `/security-review`
automatically on its own triggers — a phase touching auth, secrets, user input, a new endpoint,
payment, or sensitive data. Making the finish-time pass an offer did not turn the check off; it
removed the second, unconditional run.

## Option 2: Push and Create PR (detail)

Push the branch to remote and create a pull request.

```bash
# Push branch to remote
git push -u origin feature/my-feature

# Create PR (using gh CLI)
gh pr create --title "feat: description" --body "## Summary\n..."
```

**Use when:** Team review needed, CI/CD pipeline should run, documentation trail desired.

## Option 3: Keep As-Is (detail)

Leave the branch and worktree in place. Continue work later.

No git commands needed. Simply inform the user:
- Current branch name
- Worktree location (if applicable)
- What's been completed so far
- What remains to be done

**Use when:** Work is paused, not complete, or waiting on external dependency.

## Option 4: Discard (commands)

```bash
# Switch to base branch
git checkout main

# Delete the branch (force, since it's not merged)
git branch -D feature/my-feature

# Remove worktree if exists
git worktree remove .worktrees/my-feature --force
```

**Use when:** Approach was wrong, work is obsolete, starting over.

## Post-Finish Summary

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

## Step 1: what the pass ensures

This ensures:
- All tests pass
- No lint errors or warnings
- Build succeeds
- No unintended changes
- The deterministic checks Step 0 used to duplicate: `detect-stack`'s commands and
  `regression-gate` (Layer 1)

## Step 2: why /security-review left the chain

Every other **mandatory** step in this chain is unconditional. `/security-review` is no longer
one of them — it is offered after step 4 (IDS-17). The argument for keeping it unconditional was
real and is preserved rather than deleted: security defects hide in diffs that look boring, and
in a skills repository markdown **is** the executed surface, so "docs only" never means "cannot
introduce a vulnerability". It now lives as a divergence note in the knowledge store, and
`gaspol-execute` Step 3.6 still runs the review unconditionally on its own triggers.

## Step 4: why the evidence gate exists

**Evidence required — this step used to be a self-reported checkbox.** Nothing verified
that CLAUDE.md had actually changed, so `[x] COMPLETED` could be written over a
branch that never touched it. That is a completion claim without evidence, which Iron
Law 3 forbids everywhere else in this plugin.

## Step 4: what the sync ensures

This ensures:
- New tables, functions, routes, or components are documented
- Changed configurations are reflected
- Removed features are cleaned up from docs
- The next session has accurate context

## Fix Loop: the mutation harness

Adding an exemption to a gate means adding its attack row to the mutation harness
  **first**, and watching it fail — five separate times in IDS-8, closing one finding loosened
  the gate beside it, and every one of those was found by an expensive audit rather than by the
  harness that existed to catch it. In THIS repository that harness is
  `tests/ticket-scripts/test-gate-mutations.sh`.

## Fix Loop: why the chain stays

In IDS-8 each of
the then-six found a real defect, including a skill that had silently stopped loading and a first
capture that aborted on any fresh machine — a chain that feels slow argues for scoping its
re-runs, not for dropping a gate that audits the diff.
