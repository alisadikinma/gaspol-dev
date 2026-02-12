# Defense in Depth

## Four Layers of Validation

Bugs propagate when there is only one check. Defense in depth means validating at multiple layers so that if one layer misses a bug, the next layer catches it.

```
Layer 1: Entry Point Validation    ← Catch bad input before it enters the system
Layer 2: Business Logic Validation ← Catch invariant violations during processing
Layer 3: Environment Guards        ← Prevent dangerous operations in wrong context
Layer 4: Debug Instrumentation     ← Make bugs visible when they occur
```

## Layer 1: Entry Point Validation

Validate ALL inputs at the boundary where they enter your code. Do not trust data from external sources.

### Edge Function Entry

```typescript
// Validate request body at the top of every edge function
const body = await req.json();

// Required fields
if (!body.segments || !Array.isArray(body.segments)) {
  return new Response(
    JSON.stringify({ success: false, error: { code: 'INVALID_INPUT', message: 'segments must be an array' } }),
    { status: 400, headers: corsHeaders }
  );
}

// Type narrowing
if (body.segments.some((s: unknown) => typeof s !== 'object' || !s)) {
  return new Response(
    JSON.stringify({ success: false, error: { code: 'INVALID_INPUT', message: 'each segment must be an object' } }),
    { status: 400, headers: corsHeaders }
  );
}

// Range validation
if (body.duration && ![5, 10, 15, 30, 60, 90].includes(body.duration)) {
  return new Response(
    JSON.stringify({ success: false, error: { code: 'INVALID_INPUT', message: 'invalid duration' } }),
    { status: 400, headers: corsHeaders }
  );
}
```

### Frontend Props/State

```typescript
// Validate before using data from context or props
function ScriptStep({ segments }: { segments: Segment[] }) {
  if (!segments?.length) {
    return <EmptyState message="No segments available" />;
  }

  // Validate each segment has required fields
  const validSegments = segments.filter(s => s.type && s.narration != null);
  if (validSegments.length !== segments.length) {
    console.warn('[ScriptStep] Filtered out invalid segments:', segments.length - validSegments.length);
  }
  // ...
}
```

## Layer 2: Business Logic Validation

Check invariants (things that must ALWAYS be true) at critical points in your business logic.

### Invariant Checks

```typescript
// Before generating images: script must be confirmed
function handleGenerateImages(state: WorkspaceState) {
  // Invariant: script must be confirmed before image generation
  if (!state.scriptConfirmed) {
    throw new Error('INVARIANT VIOLATION: Cannot generate images before script is confirmed');
  }

  // Invariant: at least one segment must exist
  if (!state.scriptData?.segments?.length) {
    throw new Error('INVARIANT VIOLATION: No segments in script data');
  }

  // Invariant: all segments must have visual_direction
  const missingVisual = state.scriptData.segments.filter(s => !s.visual_direction);
  if (missingVisual.length > 0) {
    throw new Error(`INVARIANT VIOLATION: ${missingVisual.length} segments missing visual_direction`);
  }
}
```

### Domain Rules

```typescript
// Word count must respect duration limits
function validateWordCount(narration: string, durationSeconds: number): boolean {
  const wordCount = narration.trim().split(/\s+/).length;
  const maxWords = Math.floor(130 * (durationSeconds / 60) * 0.80);
  return wordCount <= maxWords;
}

// API key must be in correct format
function validateFalApiKey(key: string): boolean {
  // fal.ai keys are in key_id:key_secret format
  return /^[a-f0-9-]+:[a-f0-9]+$/.test(key);
}
```

## Layer 3: Environment Guards

Prevent dangerous operations from running in the wrong environment.

### Operation Guards

```typescript
// Prevent accidental production operations in test/dev
function guardDangerousOperation(operation: string): void {
  const env = Deno.env.get('ENVIRONMENT') || 'production';

  const dangerousOps = ['delete_all_users', 'reset_database', 'clear_storage'];
  if (dangerousOps.includes(operation) && env === 'production') {
    throw new Error(`BLOCKED: "${operation}" cannot run in production`);
  }
}

// Prevent test data from reaching production APIs
function getApiEndpoint(service: string): string {
  const isTest = Deno.env.get('ENVIRONMENT') === 'test';
  const endpoints: Record<string, { prod: string; test: string }> = {
    'fal-ai': {
      prod: 'https://fal.run',
      test: 'https://fal.run'  // same, but with test API key
    }
  };
  return isTest ? endpoints[service].test : endpoints[service].prod;
}
```

### Required Environment Variables

```typescript
// Fail fast if required env vars are missing
function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`MISSING REQUIRED ENV: ${name} is not set. Check Supabase secrets.`);
  }
  return value;
}

// Usage: fail immediately at function start, not deep in the call stack
const falApiKey = requireEnv('FAL_AI_API_KEY');
const groqApiKey = requireEnv('GROQ_API_KEY');
```

## Layer 4: Debug Instrumentation

Make bugs visible when they occur, even in production.

### Structured Logging

```typescript
// Log with context at every important decision point
function logDebug(component: string, action: string, data: Record<string, unknown>): void {
  console.log(JSON.stringify({
    component,
    action,
    timestamp: new Date().toISOString(),
    ...data
  }));
}

// Usage
logDebug('generate-images', 'model_selected', {
  segmentType: segment.type,
  model: selectedModel,
  hasReference: !!referenceImages.length
});
```

### Data Flow Snapshots

```typescript
// Snapshot the data shape at key transformation points
function snapshotData(label: string, data: unknown): void {
  const snapshot = {
    label,
    type: typeof data,
    isArray: Array.isArray(data),
    keys: typeof data === 'object' && data !== null ? Object.keys(data) : undefined,
    length: Array.isArray(data) ? data.length : undefined,
    sample: Array.isArray(data) && data.length > 0 ? typeof data[0] : undefined
  };
  console.log('[SNAPSHOT]', JSON.stringify(snapshot));
}
```

## Applying Defense in Depth

When debugging, check each layer:

1. **Is the input valid?** (Layer 1) -- add entry validation if missing
2. **Are invariants maintained?** (Layer 2) -- add invariant checks at critical points
3. **Is the environment correct?** (Layer 3) -- verify env vars, check which environment is running
4. **Can you see the bug?** (Layer 4) -- add logging if the bug is invisible

When the bug is found and fixed, leave the validation and instrumentation in place (remove verbose debug logs, keep guards and invariant checks). Each layer you add prevents future bugs from reaching the same failure mode.
