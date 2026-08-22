# Root Cause Tracing

## Backward Tracing Technique

The most reliable debugging technique: start at the symptom and trace backwards through the system until you find the original trigger.

### The 5-Step Process

```
Step 1: Observe the symptom (what is wrong?)
Step 2: Find the immediate cause (what directly produced this symptom?)
Step 3: Ask "What called this?" (trace one level up the call stack)
Step 4: Keep tracing (repeat Step 3 until you reach the original trigger)
Step 5: Find the original trigger (the first incorrect action in the chain)
```

### Example: Full Backward Trace

```
SYMPTOM: User sees "Failed to generate images" error toast

Trace backward:
1. Toast shown by: catch block in ImageStep.handleGenerate()
2. Error thrown by: supabase.functions.invoke('generate-images') returned { error }
3. Edge function returned 500 because: fal.ai call threw "Invalid API key"
4. API key was: read from Deno.env.get('FAL_AI_API_KEY')
5. Key value was: "fal-xxx" (missing the key_id:key_secret format)
6. ROOT CAUSE: Secret was set with wrong format

Fix: Update the secret with correct key_id:key_secret format
```

### Key Principle: The Symptom Is Almost Never the Bug

```
Symptom location:    Frontend UI (error toast)
Actual bug location: Supabase secret configuration (4 layers deep)

If you "fixed" the frontend by adding better error handling,
you would HIDE the bug, not FIX it.
```

## Stack Trace Instrumentation

When the built-in stack trace is not enough, add temporary instrumentation.

### Logging at Component Boundaries

Add logs at each boundary to narrow down where data goes wrong:

```typescript
// Frontend: before the call
console.log('[ImageStep] Sending to generate-images:', {
  segmentCount: segments.length,
  hasReferenceImages: !!referenceImages.length,
  model: selectedModel
});

// Edge Function: on entry
console.log('[generate-images] Received:', {
  bodyKeys: Object.keys(body),
  segmentTypes: body.segments?.map(s => s.type),
  hasApiKey: !!Deno.env.get('FAL_AI_API_KEY')
});

// Edge Function: before external call
console.log('[generate-images] Calling fal.ai:', {
  endpoint: modelEndpoint,
  inputKeys: Object.keys(input),
  promptLength: input.prompt?.length
});

// Edge Function: after external call
console.log('[generate-images] fal.ai response:', {
  status: result.status,
  hasImages: !!result.data?.images?.length,
  errorMessage: result.error?.message
});
```

### Data Shape Logging

When you suspect the data shape is wrong, log the full shape at each step:

```typescript
// Log shape without logging sensitive values
function logShape(label: string, obj: unknown): void {
  if (obj === null || obj === undefined) {
    console.log(`[SHAPE] ${label}: ${obj}`);
    return;
  }
  if (Array.isArray(obj)) {
    console.log(`[SHAPE] ${label}: Array[${obj.length}]`, obj.length > 0 ? logShape('item[0]', obj[0]) : 'empty');
    return;
  }
  if (typeof obj === 'object') {
    const shape: Record<string, string> = {};
    for (const [key, value] of Object.entries(obj)) {
      shape[key] = Array.isArray(value) ? `Array[${value.length}]` : typeof value;
    }
    console.log(`[SHAPE] ${label}:`, shape);
    return;
  }
  console.log(`[SHAPE] ${label}: ${typeof obj}`);
}
```

## Finding the Polluter (Test Pollution)

When tests pass individually but fail when run together, one test is "polluting" the shared state for another.

### Bisection Approach

```
Given: Tests A, B, C, D, E run together. Test E fails.
       Test E passes when run alone.

Step 1: Run A, B, E → passes? Polluter is C or D
Step 2: Run A, B, C, E → passes? Polluter is D
Step 3: Run A, B, D, E → fails? Confirmed: D is the polluter
Step 4: Examine D for shared state mutations
```

### Common Pollution Sources

| Source | Example | Fix |
|---|---|---|
| Global state mutation | Modifying a shared config object | Deep clone before mutating |
| Uncleared mocks | `jest.spyOn` without `mockRestore` | Use `afterEach(() => jest.restoreAllMocks())` |
| Database state | Test inserts data, doesn't clean up | Use transactions with rollback |
| Environment variables | `process.env.X = 'test'` without reset | Save and restore in beforeEach/afterEach |
| Timers | Fake timers not restored | `jest.useRealTimers()` in afterEach |
| Module-level side effects | Import triggers initialization | Lazy-initialize, reset between tests |

### Project-Specific Pollution (build this table from the project's CLAUDE.md)

Every codebase has its own leak sources. Read the target project's CLAUDE.md and list them before
you blame the test; these are the shapes to look for:

| Shape | Where it hides | Fix |
|---|---|---|
| Shared reducer / store state | a context or global store the tests share | reset the state in test setup |
| Browser storage cache | a versioned `localStorage` key | clear it in `beforeEach` |
| Client singletons | one DB/HTTP client for the whole suite | mock per test, not globally |
| In-memory rotation/pool state | key pools, connection pools, round-robin counters | reset the pool between tests |

## When Backward Tracing Gets Stuck

If you trace backwards and hit a dead end:

1. **Add more logging** -- you probably skipped a boundary
2. **Check async boundaries** -- the bug might cross a Promise/await gap
3. **Check event listeners** -- the trigger might be an event, not a direct call
4. **Check timers/intervals** -- the trigger might be delayed
5. **Check external state** -- database, localStorage, environment variables
6. **Binary search the timeline** -- use `git bisect` to find the commit that introduced the bug:

```bash
git bisect start
git bisect bad          # current commit is broken
git bisect good abc123  # this old commit was working
# Git checks out a middle commit -- test it
git bisect good         # or git bisect bad
# Repeat until git identifies the exact commit
git bisect reset        # clean up when done
```
