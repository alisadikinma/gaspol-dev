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

1. **Create a failing test case** (if possible)
   - Write a test that reproduces the bug
   - Confirm it fails before implementing the fix
   - This becomes a regression test

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
   - For Sparkfluence: check if the fix affects other session types (script_gen, creator_lab, ad_studio)

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

## Sparkfluence-Specific Debugging

### Common Bug Locations

| Symptom | Likely Location | Check |
|---|---|---|
| Edge Function 500 | `Deno.env.get()` secrets | Are secrets set? Is key format correct? |
| CORS error | Edge Function OPTIONS handler | Is corsHeaders applied to all responses? |
| RLS blocking | Supabase policies | Is there a policy for authenticated users? |
| Image generation fail | fal.ai API key | Format must be `key_id:key_secret` |
| "No OpenRouter API key" | `api_keys_pool` table | All keys exhausted? Run `reset_exhausted_api_keys()` |
| Script editing locked | WorkspaceContext | `scriptConfirmed: true` blocks edits |
| Workspace not saving | `useSessionPersistence` | Check `isDirty` flag and debounce |
| Trending topics empty | `trending_topics` table | Check `expires_at` TTL, run `fetch_trending.py` |
| Wrong Indonesian pronouns | Script generation prompt | Must use gue/lo, NEVER saya/kamu |

### Multi-Layer Tracing for Sparkfluence

```
Frontend (React)
  → Supabase Client (supabase.functions.invoke)
    → Edge Function (Deno)
      → API Key Rotation (apiKeyRotation.ts)
        → External API (OpenRouter/fal.ai/Gemini)
          → Response parsing
        → Error handling (429/402/403)
      → Database operations (Supabase client)
    → Response to frontend
  → State update (WorkspaceContext)
    → UI re-render
```

At each boundary, check:
- Is the request shape correct? (log the payload)
- Is the response shape expected? (log the response)
- Are errors being caught and propagated correctly?

## Integration

- Triggered by: any error, test failure, unexpected behavior
- May lead to: gaspol-verify (verify fix after implementation)
- Pairs with: gaspol-sync-docs (if fix reveals a non-obvious pattern worth documenting)
- Does NOT replace: reading error messages carefully and thinking
