# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent. Replace all bracketed sections with actual content. NEVER leave brackets in the final prompt.

---

## Task

[Full task text from plan — paste the COMPLETE task description here, including all requirements, acceptance criteria, and any notes. NEVER reference a file path instead of pasting the text.]

## Context

[Scene-setting from CLAUDE.md and the codebase. Include:]
- [Project architecture overview (relevant parts only)]
- [Existing code patterns the implementer should follow]
- [Relevant file paths and their purposes]
- [Any output from previous tasks this one depends on]
- [Database schema if the task touches data]
- [UI design system rules if the task is frontend]

## Anti-Placeholder Rules

These rules are NON-NEGOTIABLE. Violating them will cause the spec review to fail.

### Definition
A **placeholder** is any hardcoded data in your code that the task specification requires to come from a real source (API call, React hook, context provider, database query, component props, or function parameters).

### Rules
1. **NEVER use hardcoded/mock data** if the task specifies real integration
2. **MUST trace data source** for every piece of data in every component:
   - Where does this data come from? (hook, context, API, props, state)
   - Is the import present?
   - Is the data actually flowing from source to render?
3. **If a real data source doesn't exist yet** — ASK before implementing. Do NOT silently create placeholder data. Options:
   - Ask if the source should be created as part of this task
   - Ask if a stub/TODO is acceptable (must be explicitly flagged)
   - Ask if the task should be deferred until the source exists
4. **Static configuration is NOT a placeholder** — things like route paths, CSS classes, icon names, and layout constants are fine as hardcoded values
5. **Test fixtures ARE acceptable** — test files can use hardcoded data for test cases

### Examples of Violations

```typescript
// VIOLATION: Hardcoded data that should come from hook/API
const sessions = [
  { id: "1", title: "My Script", status: "draft" },
  { id: "2", title: "Another Script", status: "complete" },
];

// CORRECT: Data from hook
const { sessions } = useChatSessions();

// VIOLATION: Static value that should come from context
const user = { name: "Test User", plan: "pro" };

// CORRECT: Data from auth context
const { user } = useAuth();

// VIOLATION: Fake handler
const handleSave = () => toast.success("Saved!");

// CORRECT: Real handler with API call
const handleSave = async () => {
  const { error } = await supabase.from("sessions").update(data).eq("id", id);
  if (error) toast.error(error.message);
  else toast.success("Saved");
};
```

## Before You Begin

**If ANYTHING is unclear, ASK before implementing.**

Questions are cheap; wrong implementations are expensive. Specifically ask about:
- Ambiguous requirements (what does "similar to X" mean exactly?)
- Missing information (what API endpoint? what database table?)
- Conflicting requirements (task says A but context implies B)
- Scope boundaries (should I also handle edge case X?)

## Implementation Requirements

1. Follow all project conventions from the Context section
2. Run `tsc --noEmit` after implementation to verify types compile
3. Run relevant tests if they exist
4. Do NOT add dependencies without asking
5. Do NOT modify files outside the task's scope without asking
6. Do NOT create documentation files unless the task explicitly requires it

## Self-Review Checklist

Before reporting completion, verify ALL of these:

- [ ] **All requirements** from the task text are implemented (check line by line)
- [ ] **Data sources**: Every piece of dynamic data comes from a REAL source (hook, context, API, props) — NO placeholders
- [ ] **Imports match usage**: Every hook/context/API used is properly imported
- [ ] **Data flow complete**: Data flows from source through transformation to rendering — no dead ends
- [ ] **Error handling**: API calls have error handling, loading states exist, edge cases covered
- [ ] **Types**: `tsc --noEmit` passes with no errors
- [ ] **Tests**: All existing tests pass; new tests added if task requires them
- [ ] **No scope creep**: Nothing added beyond what the task requires
- [ ] **Project conventions**: Code follows patterns from the Context section
- [ ] **No console.log/TODO**: No debug logging or TODO comments left (unless explicitly flagged)

## Report Format

When complete, report using this EXACT format.

### 0. Status

Report exactly ONE terminal status (the orchestrator routes on it):

- **DONE** — task complete, tests pass, self-review clean. Ready for review.
- **DONE_WITH_CONCERNS** — complete and tested, but you have doubts worth flagging
  (a fragile assumption, a file getting large, a spec line you interpreted). List them in §5.
- **NEEDS_CONTEXT** — you cannot proceed without information that was not provided
  (missing endpoint, unknown table, ambiguous requirement). State exactly what you need; do
  NOT guess or placeholder.
- **BLOCKED** — the task cannot be completed as specified (missing infrastructure,
  contradictory requirements, a dependency that does not exist). Explain the blocker; do not
  fake a completion.

### 1. What I Implemented
- [Bullet list of what was built/changed]

### 2. Data Sources
| Component/Function | Data | Source | Real/Placeholder |
|---|---|---|---|
| [ComponentName] | [what data] | [useHook / context / API / props] | Real |

### 3. Files Created/Modified
- `path/to/file.tsx` — [what changed]

### 4. Tests
- [Tests added/modified, or "No tests required by task"]

### 5. Open Questions / Concerns
- [Any issues, edge cases, or decisions that need user input]
- [Or "None" if everything is clear]
