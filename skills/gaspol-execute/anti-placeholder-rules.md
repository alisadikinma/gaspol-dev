# Anti-Placeholder Rules Reference

This document is the authoritative reference for placeholder detection and prevention during plan execution. It is read by the main executor and by implementer subagents dispatched via `gaspol-parallel`.

---

## The 3 Iron Laws

```
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

These laws are absolute. No context, deadline, or rationalization overrides them.

---

## Data Source Tracing Checklist

Before implementing ANY component that displays, processes, or transforms data, answer these questions IN ORDER:

### 1. What data does this component need?

List every piece of state the component renders or uses in logic. Be specific — not "segment data" but "segment.text, segment.type, segment.wordCount, segment.visualDirection."

### 2. Where does the plan say this data comes from?

Check the plan's Data Integration Map, architecture diagram, or phase description. Common real sources:

- **React Context** — `WorkspaceContext`, `AuthContext`, etc.
- **Custom Hook** — `useChatSessions()`, `useSessionPersistence()`, etc.
- **Supabase Client** — `supabase.from('table').select(...)` via a hook
- **Edge Function** — `supabase.functions.invoke('function-name', ...)`
- **Props** — passed from a parent that has a real source
- **Computed** — derived from other real data via `.map()`, `.filter()`, `.reduce()`
- **URL Params** — `useParams()`, `useSearchParams()`
- **Local State** — `useState()` for UI-only state (toggles, form inputs)

### 3. Does this data source already exist in the codebase?

Check CLAUDE.md for existing hooks, contexts, and utilities. Check `src/hooks/`, `src/contexts/`, `src/lib/` for implementations. If the source exists, USE IT. Do not create a duplicate.

### 4. If the source does NOT exist, can you create it?

If the plan specifies a hook or context that doesn't exist yet, CREATE IT as part of the current phase. The hook creation IS part of the implementation — it is not a separate task to defer.

### 5. Are you about to write hardcoded data?

If the answer to any of these is YES, you are creating a placeholder:

- `const data = [{ ... }]` with literal values
- `const items = []` with a comment about "connecting later"
- `return 'Sample Text'` for content that should be dynamic
- `const count = 42` for a value that should come from state
- `// TODO: replace with real data`

**STOP.** You are violating Law 1.

---

## Real vs. Placeholder Code Patterns

### REAL Integration Patterns

```tsx
// Real: Data from context
const { segments, scriptData } = useWorkspace();

// Real: Data from custom hook
const { sessions, loading, error } = useChatSessions();

// Real: Data from Supabase query (inside a hook)
const { data, error } = await supabase
  .from('trending_topics')
  .select('*')
  .eq('country', country)
  .order('volume_score', { ascending: false });

// Real: Data from Edge Function
const { data, error } = await supabase.functions.invoke('generate-script', {
  body: { topic, settings, language }
});

// Real: Data from props (parent has real source)
interface SegmentCardProps {
  segment: Segment;
  onEdit: (id: string, text: string) => void;
}
function SegmentCard({ segment, onEdit }: SegmentCardProps) {
  return <div>{segment.text}</div>;
}

// Real: Computed from real data
const totalWords = segments.reduce((sum, seg) => sum + seg.wordCount, 0);
const hookSegment = segments.find(s => s.type === 'HOOK');

// Real: Local UI state (toggles, inputs — not content data)
const [isExpanded, setIsExpanded] = useState(false);
const [searchQuery, setSearchQuery] = useState('');
```

### PLACEHOLDER Patterns (VIOLATIONS)

```tsx
// PLACEHOLDER: Hardcoded array
const segments = [
  { id: '1', type: 'HOOK', text: 'Sample hook text', wordCount: 8 },
  { id: '2', type: 'BODY', text: 'Sample body content', wordCount: 15 },
];

// PLACEHOLDER: Empty array with deferred intent
const segments: Segment[] = []; // Will connect to API later

// PLACEHOLDER: Hardcoded strings for dynamic content
const title = "My Awesome Video";
const score = 85;
const status = "completed";

// PLACEHOLDER: Mock function
const fetchSegments = () => {
  return Promise.resolve([
    { id: '1', text: 'Mock segment' }
  ]);
};

// PLACEHOLDER: Commented-out real code replaced with hardcoded
// const { segments } = useWorkspace();
const segments = mockSegments;

// PLACEHOLDER: Default fallback hiding missing integration
const data = props.data || defaultMockData;

// PLACEHOLDER: Inline mock in JSX
<SegmentCard segment={{ id: '1', text: 'Preview', type: 'HOOK' }} />
```

---

## Self-Review Checklist for Placeholder Detection

Run this checklist on EVERY file you create or modify before marking a phase complete.

### Component Files (.tsx)

- [ ] Every `const data = [...]` with literal objects — is this real or placeholder?
- [ ] Every `const value = 'string'` for content — is this hardcoded or from state?
- [ ] Every `const count = number` — is this computed from real data?
- [ ] Does this component import at least one hook or context for its data needs?
- [ ] If the component receives props — does the PARENT have real data sources?
- [ ] Are there any `// TODO` or `// FIXME` comments about data connections?
- [ ] Are there any empty event handlers — `onClick={() => {}}`?
- [ ] Are there any `console.log` statements not guarded by dev checks?

### Hook Files (.ts)

- [ ] Does this hook return real data from Supabase, context, or computation?
- [ ] Are there any hardcoded fallback values that mask missing integrations?
- [ ] Is the hook's return type fully implemented (no `as any` casts)?
- [ ] Does the hook handle loading, error, and empty states?

### Context Files (.tsx)

- [ ] Does the context provider get its initial state from a real source?
- [ ] Are all reducer actions implemented with real logic (not `return state`)?
- [ ] Is the context used by at least one component (not orphaned)?

### Type Files (.ts)

- [ ] Do interfaces match the database schema in CLAUDE.md?
- [ ] Are there any `any` types that should be specific?
- [ ] Do optional fields (`?`) match what's actually nullable in the DB?

---

## Decision Tree

When you encounter a data need during implementation:

```
Does the plan specify where this data comes from?
├── YES → Does the data source already exist?
│   ├── YES → Use it. Import and connect.
│   └── NO → Create it (hook/context/query). Then use it.
└── NO → Is this UI-only state (toggle, input, selection)?
    ├── YES → Use useState. This is fine.
    └── NO → STOP. The plan has a gap.
        Ask user: "The plan doesn't specify where [X] data comes from.
        Should I: (a) integrate with [suggested source], (b) skip, (c) placeholder with TODO?"
```

---

## Common Traps

### The "Render First, Connect Later" Trap

You build a beautiful component with hardcoded data to "see how it looks." Then you move to the next component. Then the next. By the end, you have 12 components with hardcoded data and zero integrations. Connecting them all is now a massive task that nobody wants to do.

**Prevention:** Connect as you build. The component is not done until its data is real.

### The "It's Just the Skeleton" Trap

You build the file structure, the JSX layout, the CSS — but no data connections. You call this "the skeleton" and plan to "add the muscles later." The muscles never come.

**Prevention:** A skeleton with no data flow is not a phase deliverable. The plan phase includes integration.

### The "Works In Storybook" Trap

The component works perfectly in isolation with props. But nothing in the app actually passes those props with real data. The component is an island.

**Prevention:** Trace the prop chain to its source. If the source is a hardcoded parent, you have a placeholder.

### The "Default Props" Trap

You add `defaultProps` or default parameter values that provide "reasonable" data. The component never gets real data because the defaults are "good enough."

**Prevention:** Default values for UI state (isOpen = false) are fine. Default values for content data (title = 'Sample') are placeholders.

---

# Red Flags and Rationalizations (moved from SKILL.md, IDS-6 C1)


Observing any of these means STOP and reassess. The left column is what you will actually
catch yourself thinking; none of it is valid.

| Signal / excuse | What it really is | Correct action |
|---|---|---|
| About to write `const data = [...]` | Placeholder | Trace the source, implement the real integration |
| "I'll connect this to the API later" / "temporary" | Later never comes; placeholders become permanent | Connect now, or get an explicit user deferral |
| "The plan didn't specify the implementation" | The Data Integration Map IS the specification | Trace the data flow and implement it |
| "The hook doesn't exist yet" | That is the work, not a blocker | Create it, or report a real blocker |
| "It works the same with mock data" | Working is not complete | Plan says real integration; do real integration |
| "Just this one component" / "it's only the UI layer" | One placeholder becomes many; UI with fake data is a fake UI | Same standard everywhere |
| "The API isn't ready" | A genuine blocker — but not a licence to mock | Report the blocker and wait for guidance |
| Skipping a plan phase without asking | Law 2 violation | Ask before skipping any phase |
| Batch-completing 3+ phases | Checkpoint-rule violation | One phase, one checkpoint, one approval |
| "Close enough" / "minor deviation" | Plan drift; you do not decide what is minor | Compare explicitly, report it, let the user judge |
| "This is basically done" / "I'm confident" | Law 3 violation; confidence is not evidence | Run the completion gate scan |
| Creating a hook CLAUDE.md already lists | CLAUDE.md was not read | Use the existing one |
| Component imports no hook or context | Probably hardcoded data | Verify the source against the plan |
| 3+ TODOs in a file, or "I'll clean up TODOs at the end" | Incomplete implementation; TODOs get forgotten | Resolve each as you go, or flag it |
| Test file with no assertions | Phantom coverage | Write real assertions or mark it incomplete |
