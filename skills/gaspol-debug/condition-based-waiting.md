# Condition-Based Waiting

## The Problem with Arbitrary Timeouts

```typescript
// BAD: Arbitrary timeout -- too short = flaky, too long = slow
await new Promise(resolve => setTimeout(resolve, 2000));
expect(element).toBeVisible();

// BAD: Magic numbers that "usually work"
await sleep(3000); // "3 seconds should be enough"
```

Arbitrary timeouts are the #1 source of flaky tests and unreliable async code. They either:
- **Too short:** fail intermittently under load
- **Too long:** waste time on every run
- **Both:** fail under load AND waste time when fast

## The Solution: Poll for Conditions

Replace `sleep(n)` with `waitFor(() => condition)`.

### Generic Polling Function

```typescript
interface WaitForOptions {
  timeout?: number;    // Max time to wait (ms). Default: 5000
  interval?: number;   // Poll frequency (ms). Default: 100
  message?: string;    // Error message if timeout. Default: 'Condition not met'
}

async function waitFor(
  condition: () => boolean | Promise<boolean>,
  options: WaitForOptions = {}
): Promise<void> {
  const { timeout = 5000, interval = 100, message = 'Condition not met within timeout' } = options;
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    try {
      const result = await condition();
      if (result) return;
    } catch {
      // Condition threw -- treat as not yet met
    }
    await new Promise(resolve => setTimeout(resolve, interval));
  }

  throw new Error(`${message} (waited ${timeout}ms)`);
}
```

### Quick Patterns

| Scenario | Pattern |
|---|---|
| Wait for element | `await waitFor(() => document.querySelector('.result') !== null)` |
| Wait for state | `await waitFor(() => store.getState().isLoaded === true)` |
| Wait for API | `await waitFor(() => fetch('/health').then(r => r.ok).catch(() => false))` |
| Wait for file | `await waitFor(() => fs.existsSync(outputPath))` |
| Wait for DB row | `await waitFor(() => supabase.from('jobs').select().eq('id', jobId).single().then(r => r.data?.status === 'completed'))` |
| Wait for queue | `await waitFor(() => queue.length === 0, { timeout: 30000 })` |

### fal.ai Polling (Sparkfluence-Specific)

fal.ai's `fal.subscribe()` already implements condition-based waiting internally. Use it instead of manual polling:

```typescript
// GOOD: fal.subscribe handles polling automatically
const result = await fal.subscribe(endpoint, {
  input: { prompt, image_url },
  logs: true,
  onQueueUpdate: (update) => {
    if (update.status === 'IN_PROGRESS') {
      console.log('Progress:', update.logs);
    }
  }
});

// BAD: Manual polling of fal.ai queue
while (true) {
  const status = await fal.queue.status(requestId);
  if (status.status === 'COMPLETED') break;
  await sleep(1000); // Don't do this
}
```

## Common Mistakes

| Mistake | Why It's Bad | Fix |
|---|---|---|
| Polling too fast (1ms interval) | Hammers CPU/API, may cause rate limits | Use 100ms+ intervals |
| No timeout | Waits forever if condition never met | Always set a timeout |
| Stale closure data | Condition captures old state | Re-read state inside condition function |
| Swallowing errors silently | Hides real failures as timeouts | Log errors inside condition, only catch expected ones |
| Nested timeouts | `setTimeout` inside `setTimeout` = unmaintainable | Use single `waitFor` with clear condition |
| Polling after unmount | React component unmounted but polling continues | Use AbortController or cleanup in useEffect |

### React Cleanup Example

```typescript
useEffect(() => {
  let cancelled = false;

  async function pollForResult() {
    try {
      await waitFor(
        () => {
          if (cancelled) throw new Error('Cancelled');
          return checkCondition();
        },
        { timeout: 30000, interval: 1000 }
      );
      if (!cancelled) {
        setResult(await fetchResult());
      }
    } catch (err) {
      if (!cancelled) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      }
    }
  }

  pollForResult();
  return () => { cancelled = true; };
}, [dependency]);
```

## When NOT to Use Polling

| Scenario | Better Alternative |
|---|---|
| WebSocket events | Listen for the event directly |
| Database changes | Use Supabase realtime subscriptions |
| React state updates | Use useEffect with the state as dependency |
| Promise resolution | Just await the promise |
| DOM mutations | Use MutationObserver |

The rule: if the system can NOTIFY you, listen. If it cannot, poll.
