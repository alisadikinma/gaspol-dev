---
name: gaspol-debug
description: "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Requires systematic root cause investigation — no guessing, no quick fixes, no shotgun debugging."
---

# gaspol-debug

## Overview

Systematic debugging that traces root causes before proposing fixes. No guessing. No shotgun debugging.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

This means:
- You MUST understand WHY the bug exists before writing a single line of fix code
- You MUST be able to explain the causal chain from trigger to symptom
- If you cannot explain the root cause in one sentence, you have not found it yet

## Four Phases

### Phase 1: Root Cause Investigation

#### Batch Gate (BLOCKING — when more than one defect is reported)

```
N defects reported together are ONE ticket by default.
Splitting needs a reason from the closed list. The ceiling is two.
```

Full rule and thresholds: `skills/_shared/batch-gate.md`. This gate lives here as well as in
`gaspol-brainstorm` because bug reports route straight to debugging and never reach brainstorm —
a batching rule that existed only there would never fire for the case it was written for.

State the ruling before investigating: *"Five defects, one ticket."* Then investigate each one to
root cause **separately** — batching the ticket never batches the diagnosis. One shared root cause
across several symptoms is a finding you must prove, never an assumption that saves work.

#### Ledger — created HERE, because nothing else will (BLOCKING)

```
A bug fix gets a progress ledger too. gaspol-plan is not on this path.
```

**The bug this closes.** Phase 4 step 1 below tells you to write a `regression-test:` line into
`.gaspol/progress/PROGRESS-<TICKET>.md`, and `regression-gate` reads it. Until IDS-19 the debug
path **never created that file** — so the gate returned exit 3 (UNKNOWN, ledger unresolved) as its
*normal* outcome on the very path it was built for. Measured across all 18 IDS tickets in the
gaspol repository, a ledger existed if and only if a plan file did. An instruction pointing at a
file nothing creates is the same defect shape as a gate nothing reads.

1. **A ledger already there? Leave it alone.** If `.gaspol/progress/PROGRESS-<TICKET>.md` exists
   for this branch's ticket, it was written by `gaspol-plan` or an earlier debug session. Append
   to it; never overwrite it.
2. **Otherwise mint the ticket — once per batch.** The Batch Gate directly above has already
   ruled how many tickets this report is worth, and this step never re-opens that: five defects
   batched into one ticket call `next-ticket` **once**.
   ```bash
   : "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it this would run whatever
   script the target project happens to ship at a matching relative path}"
   "$CLAUDE_PLUGIN_ROOT/skills/gaspol-execute/scripts/next-ticket" <path to the target project's CLAUDE.md>
   ```
   - **Exit 0** — stdout is the new ticket id. Use it.
   - **Exit 2** — the project has no `## gaspol Ticket Counter` section. Use **AskUserQuestion**
     to ask for a prefix. **Never guess one**: a prefix invented here ends up in filenames,
     branch names and commit subjects, and nothing later corrects it.
3. **Write the ledger** in the format under "Progress Ledger Format" in
   `skills/gaspol-plan/SKILL.md` — the four mandatory sections (`## Pre-flight`,
   `## Keputusan saat jalan`, `## Phase log`, `## Utang terbuka`) above a `## Log` that stays the
   **last** block. A debugging session has no plan phases to copy, so its `## Checklist` carries
   the investigation's own steps: reproduce, root cause named, regression test RED, fix, regression
   test GREEN, no regression elsewhere.
4. `## Pre-flight` records the state you found, not the state you wish for: the failing command
   and its exact output, and whether the rest of the suite was already red **before** you touched
   anything. A pre-existing failure that goes unrecorded gets blamed on your fix.


**Read the error. The FULL error.**

Most debugging failures start here. Read the entire error message, not just the first line. Read the stack trace. Read the context around the error.

**Steps:**

1. **Capture the exact error** -- copy the full error message, stack trace, and any surrounding logs
2. **Reproduce consistently** -- can you trigger it every time? If not, identify the conditions
3. **Check recent changes** -- run `git log --oneline -20` and `git diff` to see what changed recently
4. **Isolate the component** -- which layer is the bug in?

```
Frontend (React/TS) → Edge Function (Deno) → Database (Supabase) → External API (fal.ai, OpenRouter)
```

5. **Trace the data flow** -- follow the data from source to symptom:
   - What input triggers the bug?
   - What function processes that input?
   - Where does the data transform incorrectly?
   - What output is wrong?

6. **Use backward tracing** -- start at the symptom and work backwards:
   ```
   Symptom: "Image generation returns 500"
   → Immediate cause: Edge function throws
   → What called it? Frontend fetch to generate-images
   → What data? The prompt was malformed
   → Why malformed? Script segment had empty visual_direction
   → Why empty? Script generation skipped B-ROLL segments
   → ROOT CAUSE: Duration filter excluded B-ROLL from 5s scripts
   ```

See [root-cause-tracing.md](./root-cause-tracing.md) for detailed backward tracing technique.

### Phase 2: Pattern Analysis

**Find working examples first.**

Before you try to fix broken code, find similar code that DOES work. This is the fastest path to understanding.

**Steps:**

1. **Find working examples** -- search the codebase for similar patterns that work correctly
   ```
   Example: If generate-images fails, look at generate-videos (similar pattern, might work)
   ```

2. **Read the working version COMPLETELY** -- do not skim. Read every line. Understand every parameter.

3. **Compare systematically** -- what is different between working and broken?
   - Different parameters?
   - Different error handling?
   - Different data shape?
   - Missing null check?
   - Different API endpoint or model?

4. **Check dependencies** -- what else relies on the broken code?
   - Will fixing it break something else?
   - Are there consumers of this output?
   - Is there a cache that needs invalidating?

5. **Check the docs** -- for external APIs (fal.ai, OpenRouter, Supabase):
   - Read the API documentation for the specific endpoint
   - Check if the API changed (version, parameters, response format)
   - Check rate limits and quotas

### Phase 3: Hypothesis and Testing

**One hypothesis. One change. One test.**

**Steps:**

1. **Form a SINGLE hypothesis** -- "The bug occurs because X"
   - The hypothesis must explain ALL observed symptoms
   - If it only explains some symptoms, it is incomplete

2. **Design a minimal test** -- change ONE variable to test the hypothesis
   - Add a single log statement
   - Change a single parameter
   - Comment out a single block
   - Do NOT change multiple things at once

3. **Run the test** -- execute and observe
   - Does the behavior change as predicted?
   - Yes → hypothesis confirmed, proceed to Phase 4
   - No → hypothesis rejected, return to Phase 1

4. **Escalation rule:**
   - Attempt 1 failed → return to Phase 1 with new evidence
   - Attempt 2 failed → return to Phase 1, broaden investigation scope
   - Attempt 3 failed → **STOP. Question the architecture.**
     - Is the overall approach wrong?
     - Is there a fundamental misunderstanding?
     - Should you ask the user for context?

### Phase 4: Implementation

**Fix it once. Fix it right.**

**Steps:**

1. **Regression test — three states, no silent default**

   `(if possible)` is gone. It was a default nobody had to defend; every fix now records
   ONE of three states in the ledger's `regression-test:` line, checked by
   `skills/gaspol-debug/scripts/regression-gate`:

   | State | Ledger line |
   |---|---|
   | written | `regression-test: <path>::<name> — RED at <sha>, GREEN after fix` |
   | genuinely not testable | `regression-test: N/A — <reason>` |
   | not written | `regression-test: not run — <reason>` |

   **RED before GREEN is not optional inside the written state.** A test added after the
   fix, never observed failing, proves only that it passes now. Confirm the test fails for
   the expected reason BEFORE implementing the fix, and record the SHA it was red at — a
   fact that can be checked, not a claim.

   `N/A` and `not run` both require an actual reason after the dash. A bare label with
   nothing after it is `(if possible)` wearing a new name, and `regression-gate` treats it
   as BLOCKING for exactly that reason.

2. **Implement the single fix**
   - Change the minimum amount of code to fix the root cause
   - Do NOT add "while I'm here" improvements
   - Do NOT refactor surrounding code

3. **Verify the fix resolves the original symptom**
   - Run the exact same reproduction steps
   - Confirm the error is gone
   - Confirm the expected behavior is restored

4. **Check for regressions**
   - Did fixing X break Y?
   - Run related tests
   - Check dependent components
   - Check the fix against the OTHER callers of the code you changed — the project's CLAUDE.md lists the variants (session types, tenants, modes) that share this path

5. **Document the fix** (if it reveals a non-obvious pattern)
   - Add to CLAUDE.md "Debugging Checklist" if applicable
   - Add inline comment explaining WHY (not what) the fix does

## Red Flags

Stop immediately if you catch yourself doing any of these:

| Red Flag | What It Means | What To Do |
|---|---|---|
| "Quick fix for now" | You haven't found root cause | Go back to Phase 1 |
| "Just try changing X" | You're guessing, not investigating | Go back to Phase 1 |
| "Add multiple changes at once" | You can't tell what fixed it | Revert, change ONE thing |
| "Skip the test" | You'll regress later | Write the test first |
| "I don't fully understand but this might work" | You MUST understand first | Go back to Phase 1 |
| Proposing solutions before tracing data flow | Phase 1 not complete | Trace the full data flow |
| "One more fix attempt" after 2+ failures | Step back entirely | Question the architecture |
| Changing error handling to suppress errors | Hiding symptoms, not fixing cause | Find the actual root cause |
| Adding try-catch around the symptom | Masking the bug | Trace upstream to the cause |

## Rationalization Prevention Table

Your brain will try to justify shortcuts. Do not let it.

| Excuse | Reality | Action |
|---|---|---|
| "I have a hunch" | Hunches require evidence | Find evidence first |
| "It worked before so it must be X" | Verify, don't assume | Test the assumption |
| "This is a known issue" | Still needs root cause for THIS instance | Investigate THIS instance |
| "Let me just try this real quick" | Quick tries compound into wasted hours | Follow the 4 phases |
| "The error message is misleading" | Read it again. Carefully. All of it. | Re-read the full error |
| "It's probably a race condition" | Prove it with logging/timing data | Add timestamps, reproduce |
| "Too complex to trace" | Break it down. Trace one component. | Isolate one layer |
| "I've seen this before" | THIS occurrence may have different cause | Investigate fresh |
| "The docs are wrong" | More likely your understanding is wrong | Re-read the docs |
| "It works on my machine" | Environment difference IS the bug | Compare environments |

## Supporting Techniques

### Root Cause Tracing
Backward tracing from symptom through call stack to original trigger.
See [root-cause-tracing.md](./root-cause-tracing.md) for:
- Stack trace instrumentation patterns
- Data flow logging examples
- "Find the polluter" bisection approach for test pollution

### Defense in Depth
Validate at 4 layers to catch bugs early and prevent propagation.
See [defense-in-depth.md](./defense-in-depth.md) for:
- Entry point validation (input sanitization, type checks)
- Business logic validation (invariant checks, domain rules)
- Environment guards (NODE_ENV=test safety, dangerous operation prevention)
- Debug instrumentation (stack trace logging, data flow snapshots)

### Condition-Based Waiting
Replace arbitrary timeouts with condition polling to eliminate timing bugs.
See [condition-based-waiting.md](./condition-based-waiting.md) for:
- Generic polling function with timeout
- Quick patterns for common waits
- Common timing-related mistakes

## Project-Specific Debugging

gaspol is agnostic; the bug table for the codebase you are in belongs to that codebase. Build it
from the **target project's CLAUDE.md** — its "Debugging Checklist" / "Known gotchas" section is
written for exactly this moment — and never from a table hardcoded here for someone else's stack.

**Step 1 — read the target project's CLAUDE.md** and extract, before you form a hypothesis:

| Extract | Use it for |
|---|---|
| Known gotchas / debugging checklist | symptoms this codebase has produced before |
| Data sources (hooks, APIs, functions) | where the payload can be logged at each hop |
| Database tables + policies | whether the row is missing or merely invisible |
| Secrets / env conventions | a 500 that is really an unset key |
| Conventions and naming | which layer a stack frame belongs to |

If the project has no CLAUDE.md, say so and build the trace from the code — never substitute a
remembered table from a different project.

**Step 2 — trace across every boundary the request crosses.** The boundaries are whatever this
stack actually has (client → server → datastore → external API, or fewer); at each one, ask the
same three questions:

- Is the request shape correct? Log the payload.
- Is the response shape what the caller expects? Log the response.
- Are errors caught and propagated, or swallowed and reshaped into a lie?

**Step 3 — capture what you learned.** A gotcha you had to rediscover is a gotcha the project's
CLAUDE.md was missing: offer to add it via `gaspol-sync-docs`.

## Integration

- Triggered by: any error, test failure, unexpected behavior
- May lead to: gaspol-verify (verify fix after implementation)
- Pairs with: gaspol-sync-docs (if fix reveals a non-obvious pattern worth documenting)
- Does NOT replace: reading error messages carefully and thinking
