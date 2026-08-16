---
name: gaspol-review
description: "Use when completing tasks, implementing major features, or before merging to verify work meets requirements."
---

# Sparkfluence Code Review

## Core Principle

Review early, review often. Catching issues in review is 10x cheaper than catching them in production.

## When to Use

### Required
- After each task in `gaspol-parallel` (quality review stage)
- After implementing a major feature (multi-file changes)
- Before merging any branch to main
- Before deploying edge functions or migrations

### Optional (but recommended)
- When you're stuck and want a second perspective
- Before a significant refactor (review current state first)
- After fixing a complex bug (verify the fix doesn't introduce new issues)
- When inheriting unfamiliar code (review to understand before modifying)

## How to Use

### Step 1: Determine Review Scope

Get the git SHAs that define the range of changes to review:

```bash
# For a single task:
git log --oneline -5  # find the base SHA (before task started)

# For a full branch:
git merge-base main HEAD  # base SHA
git rev-parse HEAD         # head SHA

# For specific commits:
git log --oneline main..HEAD  # all commits on this branch
```

### Step 2: Dispatch Code Reviewer

Use the `code-reviewer.md` template in this skill's directory. Provide:
- BASE_SHA and HEAD_SHA for the review range
- Relevant project context from CLAUDE.md
- Any specific areas of concern

### Step 2.5: Adversarial Refutation (Critical / Important findings only)

AI reviewers hallucinate findings — a confidently-tagged "Critical" is often a false positive,
and "fixing" a non-bug can inject a real one into working code. Before any Critical or Important
finding is treated as real, dispatch **one refuter subagent per finding whose only job is to
disprove it.** Minor / Recommendation findings skip refutation (overhead not worth it).

For each Critical/Important finding, dispatch a refuter (model: Sonnet — judgment, not mechanical):

```
You are refuting a code-review finding. Your job is to PROVE IT WRONG.

Finding: [verbatim finding + file:line + severity + reviewer's reasoning]
Code under review: [review-package path, or BASE_SHA..HEAD_SHA]

Read the ACTUAL code at the cited location AND its callers/callees. Try hard to show the
finding is a false positive — already handled upstream, guarded by an existing check,
impossible given the types, or a misread of control flow.

Default to REFUTED if you cannot build a concrete, code-quoted case that the bug is REAL.
Use UNVERIFIABLE **only** when the finding is about runtime/environmental behavior you
cannot decide from source either way (not "I'm unsure" — that's REFUTED).
Return exactly:
  VERDICT: CONFIRMED | REFUTED | UNVERIFIABLE
  EVIDENCE: <code quote + 1-2 line reason>
```

Run refuters **concurrently** (single message, multiple Agent calls) — they're independent.

Resolve each:
- **REFUTED** → drop the finding. Record it as review noise; do NOT fix.
- **CONFIRMED** → survives to Step 3 with the refuter's evidence attached (now high-trust).
- **Unverifiable** (refuter could neither confirm nor cleanly refute) → treat as **CONFIRMED**
  — fail safe. An unverifiable high-severity finding is not silently dropped.

**Blocking rule:** only a CONFIRMED (or unverifiable) Critical finding blocks. Refuted findings
are advisory noise. This is the difference between a review you trust and one you second-guess.

### Step 3: Act on Feedback

Categorize each **surviving (confirmed)** issue from the reviewer:

| Category | Action | Timeline |
|----------|--------|----------|
| **Critical** | Fix immediately | Before any other work |
| **Important** | Fix before proceeding | Before next task or merge |
| **Minor** | Fix if quick, otherwise note | Before merge or in follow-up |
| **Recommendation** | Consider and decide | Your judgment call |

### Step 4: Verify Fixes

After fixing issues:
- Run `tsc --noEmit` to verify types
- Run tests to verify no regressions
- If fixes were significant, consider a focused re-review

## When the Reviewer is Wrong

Reviewers — human or AI — can be wrong. If you disagree:

1. **Don't silently ignore the feedback** — always respond
2. **Push back with technical reasoning**: "This pattern is correct because [specific technical reason]. The alternative would cause [specific problem]."
3. **Cite project conventions**: "CLAUDE.md specifies [pattern]. The reviewer's suggestion contradicts this."
4. **Provide evidence**: Show that the current code works correctly (test output, runtime behavior)
5. **Ask for clarification**: "I'm not sure I understand the concern. Can you elaborate on what problem this would cause?"

## Red Flags

| Red Flag | Consequence |
|----------|-------------|
| Skipping review entirely | Bugs ship to production; technical debt accumulates |
| Ignoring Critical issues | System instability; data loss; security vulnerabilities |
| Proceeding with unfixed Important issues | Growing technical debt; harder to fix later |
| Rubber-stamping review ("looks fine") | Defeats the entire purpose of code review |
| Accepting Critical/Important findings without refutation (Step 2.5) | Wasted effort "fixing" hallucinated bugs; a wrong fix can break working code |
| Dropping an unverifiable high-severity finding as "refuted" | Fail-open on a real risk — unverifiable counts as CONFIRMED |
| Only reviewing your own code (no subagent) | Blind spots; confirmation bias |
| Reviewing before spec review passes | Wasted effort reviewing code that doesn't meet requirements |

## Integration

- **gaspol-parallel**: Uses this skill for the quality review stage (after spec review)
- **gaspol-receive-review**: Use when YOU receive review feedback from others
- **gaspol-finish**: Final review before marking work as complete

## Quick Reference

```
1. Get SHAs:  git merge-base main HEAD && git rev-parse HEAD
2. Dispatch:  code-reviewer subagent with code-reviewer.md template
2.5 Refute:   one refuter per Critical/Important finding (default REFUTED) → drop false positives
3. Read:      Every SURVIVING issue, categorize severity
4. Fix:       Critical → Important → Minor
5. Verify:    tsc --noEmit && tests pass
6. Done:      Proceed to next task or merge
```
