---
name: gaspol-review
description: "Use when completing tasks, implementing major features, or before merging to verify work meets requirements."
---

# gaspol-review

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

### Step 2: Dispatch Code Reviewer (Tiered, Not Flat Fan-Out)

**Why tiered:** research cited in `docs/plans/2026-08-16-gaspol-workflow-hardening.md`'s
"Token-Efficiency Validation" section found that flat multi-agent fan-out is the **most costly**
pattern for code review specifically, and multi-agent systems generally run ~15x the tokens of a
single-agent interaction. A single well-scoped agent already covers most review scenarios, so
extra lanes are added only when the trigger actually warrants the cost — never as a flat 5-way
split. See that section (and its "Item 7" section) for the full citation trail.

**Cost table (state this explicitly — it's the whole point of tiering):**

| Tier | Lanes dispatched | Agent calls | Trigger |
|------|-------------------|--------------|---------|
| **Tier 0** (default, every review) | `agents/code-reviewer.md` only | **1** (same as before this change) | Always |
| **Tier 1** | Tier 0 + `plan-artifact-reviewer.md` | **2** | Called from `gaspol-finish`, OR the plan is architectural-path per `gaspol-brainstorm`'s three-path classification |
| **Tier 2** (opt-in) | Tier 1 + `git-history-reviewer.md` + `code-comment-reviewer.md` | **up to 4** (+1 conditionally, see PR-comments lane below) | A Tier 1 finding is contested/ambiguous, OR the user explicitly asks for a deeper review |

**Tier 0 (always):** dispatch the (now-trimmed — its old "Requirements" checklist subsection was
removed, that's now owned by Tier 1) `agents/code-reviewer.md` template. Provide:
- BASE_SHA and HEAD_SHA for the review range
- Relevant project context from CLAUDE.md
- Any specific areas of concern

Exactly as today — this is the unchanged default cost floor.

**Tier 1 (add `plan-artifact-reviewer.md`):** triggered when this review is called from
`gaspol-finish`, OR the plan is architectural-path per `gaspol-brainstorm`'s three-path
classification (spike / bounded / architectural). Dispatch Tier 0 + `plan-artifact-reviewer.md`
**concurrently** — single message, multiple Agent calls, both agents given the same
review-package path (plus the plan file path for the plan-artifact lane). This is exactly 2
agent calls total, never a flat 5-way split.

**Tier 2 (opt-in only):** triggered when a Tier 1 finding is contested/ambiguous, or the user
explicitly asks for a deeper review. Additionally dispatch `git-history-reviewer.md` and
`code-comment-reviewer.md` — concurrently with the Tier 0/1 lanes if Tier 1 hasn't run yet, or as
a follow-up concurrent wave if Tier 1 already ran and returned.

**PR-comments lane (`pr-comments-reviewer.md`):** before any tier's dispatch, run a plain bash
`gh pr view` existence check. Only include this lane in the current tier's concurrent dispatch if
it succeeds (exit 0 — a PR exists for the current branch). No PR → no agent call at all, not a
dispatch-then-report-N/A. This is the "+1 conditionally" in the Tier 2 cost row above (it can
also apply at Tier 1 if a PR already exists at that point).

**Concurrency rule:** all lanes active within one tier-dispatch run **concurrently** — a single
message, multiple Agent calls — mirroring `gaspol-parallel`'s dispatch convention (each wave is
one batch of concurrent Agent calls). Never dispatch lanes for the same tier-run sequentially.

**Merge before refutation:** findings from whichever lanes ran MERGE into one list before Step
2.5's adversarial refutation runs. Step 2.5's own text and logic are completely unchanged — it
now simply receives a merged multi-lane list instead of a single-agent list.

### Step 2.5: Adversarial Refutation (Critical / Important findings only)

AI reviewers hallucinate findings — a confidently-tagged "Critical" is often a false positive,
and "fixing" a non-bug can inject a real one into working code. Before any Critical or Important
finding is treated as real, dispatch **one refuter subagent per finding whose only job is to
disprove it.** Minor / Recommendation findings skip refutation (overhead not worth it).

For each Critical/Important finding, dispatch a refuter (model: opus — a refuter JUDGES a
finding, and judging it wrongly produces a wrong fix, which costs more than the model does):

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

Score your confidence 0-100 against this rubric, verbatim:
  0   Not confident at all. A false positive that does not survive light scrutiny,
      or a pre-existing issue this change did not introduce.
  25  Somewhat confident. Might be real, might be a false positive; you could not
      verify it. If stylistic, CLAUDE.md does not explicitly call it out.
  50  Moderately confident. Verified real, but possibly a nitpick or rare in
      practice. Relative to the rest of the change, not important.
  75  Highly confident. Double-checked and very likely to be hit in practice. The
      current approach is insufficient, or CLAUDE.md names this issue directly.
  100 Certain. Double-checked and confirmed; will happen frequently. The evidence
      directly confirms it.

Return exactly:
  VERDICT: CONFIRMED | REFUTED | UNVERIFIABLE
  CONFIDENCE: <0-100>
  EVIDENCE: <code quote + 1-2 line reason>
```

**False-positive catalogue — score these 0 by definition.** Absorbed from Anthropic's
official `code-review` plugin, which filters exactly these before posting:

- Pre-existing issues this change did not introduce
- Something that looks like a bug but is not
- Pedantic nitpicks a senior engineer would not raise
- Anything a linter, typechecker, or compiler catches (missing imports, type errors,
  formatting). Assume CI runs those separately — **do not run builds during review**
- General quality complaints (test coverage, documentation) unless CLAUDE.md requires them
- Issues explicitly silenced in code (a lint-ignore comment)
- Real issues on lines this change did not modify

Run refuters **concurrently** (single message, multiple Agent calls) — they're independent.

Resolve each:
- **REFUTED** → drop the finding. Record it as review noise; do NOT fix.
- **CONFIRMED** → survives to Step 3 with the refuter's evidence attached (now high-trust).
- **Unverifiable** (refuter could neither confirm nor cleanly refute) → treat as **CONFIRMED**
  — fail safe. An unverifiable high-severity finding is not silently dropped.

**Threshold 80.** A surviving finding scoring **below 80** is review noise: record it, do not
fix it, do not block on it. Above 80 it is actionable.

**The verdict outranks the score — this rule wins on conflict.** The numeric rubric ranks
*among* surviving findings; it never converts a fail-safe into a fail-open:

- `REFUTED` drops the finding **whatever** the score says.
- `UNVERIFIABLE` on a **Critical** finding is still treated as CONFIRMED and still blocks
  **regardless of score**. A high-severity finding nobody could decide from source is not
  silently discarded because a refuter typed a low number.
- The threshold only ever *demotes* a CONFIRMED finding to noise. It never promotes a REFUTED
  one, and never rescues a blocked one.

**Blocking rule:** only a CONFIRMED (or unverifiable) Critical finding blocks. Refuted findings
are advisory noise. This is the difference between a review you trust and one you second-guess.

### Escalation — `/code-review ultra` (user-triggered only)

For the deepest available review, the **user** can run `/code-review ultra` — a multi-agent
cloud review. With no argument it reviews the current local branch (no GitHub remote needed);
`/code-review ultra <PR#>` reviews a specific pull request. It is **billed**, and
**Claude cannot launch it**. Offer it; never attempt it, and never claim its output.

Note the separate `/code-review` plugin command is **PR-only** — its tools are all `gh pr …`,
it needs an open pull request, and it posts its result as a GitHub comment. That is why it does
not replace this skill: `gaspol-finish` Step 3 gates a **local branch before merge**, which
`/code-review` structurally cannot do. This skill already runs all five of that plugin's review
lanes (CLAUDE.md compliance, bug scan, git history, prior PR comments, code comments) plus
tiering and the refutation pass above.

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
| Treating a sub-80 finding as blocking | Wastes a fix cycle on noise — below threshold means record, not fix |
| Using a low score to drop an UNVERIFIABLE Critical finding | Fail-open on a real risk — the verdict outranks the score |
| Running builds or typechecks as part of review | CI already does it; those findings are score-0 by the false-positive catalogue |
| Only reviewing your own code (no subagent) | Blind spots; confirmation bias |
| Reviewing before spec review passes | Wasted effort reviewing code that doesn't meet requirements |

## Integration

- **gaspol-parallel**: Uses this skill for the quality review stage (after spec review)
- **gaspol-receive-review**: Use when YOU receive review feedback from others
- **gaspol-finish**: Final review before marking work as complete

## Quick Reference

```
1. Get SHAs:  git merge-base main HEAD && git rev-parse HEAD
2. Dispatch:  Tier 0 (1 call, always) → +plan-artifact-reviewer at Tier 1 (2 calls) → +git-history/code-comment at Tier 2 (up to 4) → +pr-comments if `gh pr view` succeeds. All lanes in one tier run concurrently.
2.5 Refute:   one refuter per Critical/Important finding from the merged lane list (default REFUTED)
              → each returns VERDICT + CONFIDENCE 0-100; drop REFUTED, demote <80 to noise.
              Verdict outranks score: UNVERIFIABLE Critical still blocks at any score.
              Deeper pass available to the USER only: /code-review ultra (billed).
3. Read:      Every SURVIVING issue, categorize severity
4. Fix:       Critical → Important → Minor
5. Verify:    tsc --noEmit && tests pass
6. Done:      Proceed to next task or merge
```
