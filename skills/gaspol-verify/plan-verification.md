# Plan Verification Reference

Detailed reference for the Plan Fidelity Check (Layer 2) of gaspol-verify. This document covers how to read plan files, compare them against actual implementation, detect placeholders systematically, and produce structured verification reports.

---

## Reading and Parsing a Plan File

### Locating the Plan
Plans are stored in `docs/plans/` with the naming convention:
```
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md
```

If the plan was created by `gaspol-execute`, it will have a structured format with phases, files, and deliverables.

### Extracting Deliverables

Scan the plan for these sections and extract actionable items:

#### 1. Phase/Step Headings
Look for numbered phases or steps:
```markdown
## Phase 1: Component Scaffolding
## Phase 2: Hook Integration
## Step 3: Connect to API
```
Each phase is a verification checkpoint.

#### 2. File Lists
Plans often list files to create or modify:
```markdown
### Files Modified
- src/components/TopicCard.tsx (new)
- src/hooks/useTrending.ts (modified)
- src/contexts/WorkspaceContext.tsx (modified)
```
Each file is a verification target.

#### 3. Data Integration Maps
Plans may specify how data flows:
```markdown
### Data Flow
trending_topics (DB) --> useTrending hook --> TopicRecommendations --> TopicCard
```
Each arrow is a connection to verify.

#### 4. Acceptance Criteria
Plans may list explicit criteria:
```markdown
### Acceptance Criteria
- [ ] Topic cards render trending data from hook
- [ ] Loading skeleton shows during fetch
- [ ] Error state with retry button on failure
```
Each criterion is a direct verification target.

### Building the Verification Checklist

From the parsed plan, build a flat checklist:

```
PLAN: docs/plans/2026-02-10-IND-42-topic-cards-plan.md

PHASES:
  [ ] Phase 1: Component scaffolding (3 files)
  [ ] Phase 2: Hook integration (2 hooks)
  [ ] Phase 3: API connection (1 endpoint)
  [ ] Phase 4: Error/loading states (3 states)
  [ ] Phase 5: Tests (3 test files)

FILES:
  [ ] src/components/TopicCard.tsx (new)
  [ ] src/hooks/useTrending.ts (modified)
  [ ] src/contexts/WorkspaceContext.tsx (modified)

DATA FLOWS:
  [ ] DB --> useTrending --> TopicRecommendations
  [ ] useTrending --> TopicCard (props)

CRITERIA:
  [ ] Cards render trending data
  [ ] Loading skeleton present
  [ ] Error state with retry
```

---

## Comparing Plan Against Git Diff

### Step 1: Get Changed Files
```bash
git diff --name-only HEAD~N
```
Where N is the number of commits in this work session. Or compare against the branch point:
```bash
git diff --name-only main...HEAD
```

### Step 2: Cross-Reference with Plan
For each file in the plan's "Files Modified" list:
- Is it in the git diff output? If not, it was not touched.
- If it is present, was it modified in the way the plan describes?

For each file in the git diff that is NOT in the plan:
- Is it a legitimate supporting change (e.g., import updates, type definitions)?
- Or is it unplanned scope creep?

### Step 3: Check Content of Changes
For each planned modification, read the actual diff:
```bash
git diff main...HEAD -- src/components/TopicCard.tsx
```
Verify:
- The planned component/function/hook exists in the diff
- The planned behavior is implemented (not just scaffolded)
- The planned connections (imports, hook calls) are present

### Step 4: Detect Skipped Phases
A phase is skipped if:
- None of its planned files appear in the diff
- Its planned functions/components do not exist in the codebase
- Its planned behaviors are not testable

Report skipped phases explicitly -- do not silently omit them.

---

## Placeholder Detection Patterns

### Pattern 1: TODO/FIXME Comments

**Detection command:**
```bash
git diff --name-only main...HEAD | xargs grep -n -E "(//\s*(TODO|FIXME|HACK|XXX|PLACEHOLDER|TEMP|STUB))" --include="*.ts" --include="*.tsx"
```

**Examples caught:**
```typescript
// TODO: Connect to real API
// FIXME: This should use the trending hook
// PLACEHOLDER: Replace with actual data
// HACK: Temporary workaround for state issue
// STUB: Implement error handling
```

### Pattern 2: Hardcoded Data Arrays

**What to look for:**
Arrays or objects defined inline in components that contain what looks like real data (not configuration).

**Suspicious pattern:**
```typescript
// BAD: Hardcoded data that should come from a hook or API
const topics = [
  { id: 1, title: "AI Trends", source: "google" },
  { id: 2, title: "Cooking Tips", source: "tiktok" },
  { id: 3, title: "Fitness Goals", source: "youtube" },
];

return topics.map(t => <TopicCard key={t.id} topic={t} />);
```

**Correct pattern:**
```typescript
// GOOD: Data from hook
const { topics, isLoading, error } = useTrending();

if (isLoading) return <Skeleton />;
if (error) return <ErrorBanner error={error} onRetry={refetch} />;

return topics.map(t => <TopicCard key={t.id} topic={t} />);
```

**Detection heuristic:**
- Array/object with 3+ items defined inside a component function body
- Items have properties like `id`, `title`, `name`, `description`, `url`
- No corresponding hook import or API call in the same component
- Data looks like it represents real entities (not UI config like breakpoints or colors)

### Pattern 3: Missing Hook/Context Imports

**What to look for:**
Components that the plan says should connect to a hook or context, but do not import it.

**Detection:**
```bash
# Check if TopicCard imports useTrending (as plan requires)
grep -n "useTrending\|useWorkspace\|useChatSessions" src/components/TopicCard.tsx
```

If the grep returns nothing but the plan says the component should use that hook, it is a gap.

### Pattern 4: Empty or Stub Functions

**Suspicious pattern:**
```typescript
// BAD: Function exists but does nothing
const handleRetry = () => {
  // Will implement later
};

// BAD: Function returns static value
const getScore = (segment: Segment): number => {
  return 75; // TODO: Calculate real score
};

// BAD: Async function that does not actually call API
const fetchTopics = async () => {
  return []; // Stub
};
```

**Detection heuristic:**
- Function body is empty or contains only a comment
- Function returns a hardcoded value with a TODO comment
- Async function that does not contain `await`, `fetch`, or `supabase`

### Pattern 5: Commented-Out Code

**Suspicious pattern:**
```typescript
// const realData = await fetchFromAPI();
// setTopics(realData);
const fakeData = getMockData();
setTopics(fakeData);
```

**Detection:**
```bash
git diff --name-only main...HEAD | xargs grep -n -E "^(\s*//\s*(const|let|var|await|return|if|for|while))" --include="*.ts" --include="*.tsx"
```

### Pattern 6: Console Debug Statements

**Detection:**
```bash
git diff --name-only main...HEAD | xargs grep -n -E "(console\.(log|warn|error|debug|info|trace))" --include="*.ts" --include="*.tsx"
```

Exclude intentional error logging (e.g., in catch blocks with proper error handling) from the report, but flag everything else.

### Pattern 7: Type Suppression

**Suspicious pattern:**
```typescript
// BAD: Suppressing type errors instead of fixing them
const data = response as any;
// @ts-ignore
const value = obj.unknownProp;
// @ts-expect-error
const result = fn(wrongArgs);
// eslint-disable-next-line
const unused = computeValue();
```

**Detection:**
```bash
git diff --name-only main...HEAD | xargs grep -n -E "( as any|@ts-ignore|@ts-expect-error|eslint-disable)" --include="*.ts" --include="*.tsx"
```

---

## Verification Report Template

### Full Report Format

```
============================================================
VERIFICATION REPORT
Plan: docs/plans/2026-02-10-IND-42-feature-name-plan.md
Date: 2026-02-10
Branch: feat/feature-name
============================================================

--- LAYER 1: TECHNICAL VERIFICATION ---

  Build (npm run build):
    Status:   PASS
    Exit:     0
    Errors:   0
    Warnings: 3 (non-blocking)

  TypeCheck (tsc --noEmit):
    Status:   PASS
    Exit:     0
    Errors:   0

  Tests (npm test):
    Status:   PASS
    Suites:   14 passed, 0 failed
    Tests:    47 passed, 0 failed, 2 skipped
    Coverage: 72%

  Lint (npm run lint):
    Status:   PASS
    Errors:   0
    Warnings: 1

  Layer 1 Result: PASS

--- LAYER 2: PLAN FIDELITY CHECK ---

  Phase 1: Component scaffolding
    Status: DONE
    Files:  TopicCard.tsx (created), TopicList.tsx (created), TopicBadge.tsx (created)
    Notes:  All 3 planned components exist with correct props

  Phase 2: Hook integration
    Status: DONE
    Files:  useTrending.ts (modified), useTopicSearch.ts (created)
    Notes:  Both hooks implemented with planned signatures

  Phase 3: API connection
    Status: PARTIAL
    Files:  useTrending.ts (modified)
    Notes:  Fetch connected but error retry logic missing (planned but not implemented)
    Gap:    handleRetry function is a stub (line 45)

  Phase 4: Polish & animations
    Status: DONE
    Files:  TopicCard.tsx, TopicList.tsx
    Notes:  Framer Motion transitions added as planned

  Phase 5: Tests
    Status: SKIPPED
    Files:  None of the 3 planned test files exist
    Gap:    TopicCard.test.tsx, useTrending.test.ts, TopicList.test.tsx not created

  Plan Summary: 3/5 DONE, 1 PARTIAL, 1 SKIPPED
  Layer 2 Result: FAIL (2 gaps found)

--- LAYER 3: PLACEHOLDER SCAN ---

  Pattern Matches:
    0 TODO
    0 FIXME
    1 STUB: useTrending.ts:45 "// stub: implement retry"

  Structural Issues:
    0 hardcoded arrays

  Import Gaps:
    0 missing hook imports

  Dead Code:
    1 unused: utils/topicHelpers.ts:88 formatLegacyTopic() -- defined, never imported

  Debug Artifacts:
    2 console.log: TopicCard.tsx:23, TopicList.tsx:67

  Layer 3 Result: FAIL (4 issues found)

--- LAYER 4: INTEGRATION VERIFICATION ---

  TopicCard:
    Hook:     useTrending() via parent props -- CONNECTED
    Data:     topic object from props -- FLOWING
    Loading:  N/A (parent handles) -- N/A
    Error:    N/A (parent handles) -- N/A
    Empty:    N/A (parent handles) -- N/A

  TopicList:
    Hook:     useTrending() -- CONNECTED
    Data:     topics array from hook -- FLOWING
    Loading:  Skeleton component -- PRESENT
    Error:    Error banner -- PRESENT (but retry is stub)
    Empty:    "No topics found" message -- PRESENT

  Layer 4 Result: PARTIAL (retry stub noted)

============================================================
OVERALL RESULT: FAIL

Issues to resolve before completion:
  1. useTrending.ts:45 -- implement retry logic (plan Phase 3)
  2. Create 3 test files (plan Phase 5)
  3. Remove console.log from TopicCard.tsx:23 and TopicList.tsx:67
  4. Remove or use formatLegacyTopic() in utils/topicHelpers.ts:88

After fixing: re-run FULL verification (all 4 layers)
============================================================
```

### Status Icons Reference

| Icon | Meaning | Action |
|------|---------|--------|
| PASS | Verification passed, no issues | Proceed |
| DONE | Plan item fully implemented | None |
| PARTIAL | Plan item partially implemented | Fix gaps, then re-verify |
| FAIL | Verification failed, issues found | Fix issues, then re-verify ALL layers |
| SKIPPED | Plan item not implemented at all | Implement or explicitly defer with user approval |
| N/A | Not applicable to this component | None |

### Compact Report Format

For quick status checks or progress updates, use the compact format:

```
VERIFY: feature-name
  L1 Technical:   PASS (build ok, types ok, 47 tests pass)
  L2 Plan:        3/5 phases done, 1 partial, 1 skipped
  L3 Placeholders: 4 issues (1 stub, 1 dead fn, 2 console.log)
  L4 Integration:  PARTIAL (retry stub)
  RESULT: FAIL -- 6 issues to resolve
```

---

## Common Pitfalls

### Pitfall 1: Verifying Only Changed Files
The placeholder scan must cover ALL files in the diff, not just the ones you remember changing. Automated refactors and IDE actions can introduce issues in files you did not intentionally modify.

### Pitfall 2: Accepting "Mostly Done"
A plan with 7/8 phases complete is NOT complete. Report the 1 missing phase explicitly. Let the user decide whether to defer it, not you.

### Pitfall 3: Ignoring Test Phase
Test phases are the most commonly skipped. If the plan includes tests, their absence is a verification failure, not an oversight.

### Pitfall 4: Counting Stubs as Implemented
A function that exists but returns a hardcoded value or has an empty body is NOT implemented. It is a placeholder. Report it as PARTIAL or STUB, never as DONE.

### Pitfall 5: Trusting Import Presence
A component that imports a hook but never calls it is not connected. Check that the hook is actually invoked and its return values are used.
