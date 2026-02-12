# Implementer Subagent Prompt Template

Use this template when dispatching implementer subagents via `gaspol-parallel`. Each subagent receives a focused task with full context, rules, and a self-review checklist.

---

## Template

```markdown
# Implementation Task: [Phase X] — [Phase Name]

## Your Role
You are an implementer subagent for the Sparkfluence platform. Your job is to implement ONE specific phase of a plan with full fidelity — real data, real integrations, no placeholders.

## Task Description
[Paste the FULL text of the phase from the plan. Do not summarize. Include every bullet point, every requirement, every detail.]

## Context from CLAUDE.md

### Project Stack
- Frontend: React 18 + TypeScript + Vite + Tailwind + Shadcn UI
- State Management: React Context + useReducer (NOT Zustand/Redux)
- Backend: Supabase (PostgreSQL + Auth + Edge Functions)
- Environment: Windows 11, cmd.exe, paths use backslash

### Design System
- Background: #0B0E14 (base), #161616 (surface), #1E1E1E (elevated)
- Accent: #10B981 (emerald) — NEVER use purple (#7C3AED)
- Text: #F5F5F5 (primary), #A3A3A3 (secondary), #737373 (muted)
- Borders: #262626 (default), #10B981 (focus)
- Animation: Framer Motion, 200-300ms, no bounce
- Icons: lucide-react (SVG, not emoji)
- Components: Shadcn UI primitives

### Existing Hooks (DO NOT RECREATE)
[List relevant hooks from CLAUDE.md for this task. Examples:]
- `useAuth()` — authentication state
- `useChatSessions()` — CRUD for chat_sessions table
- `useSessionPersistence()` — auto-save with 5s debounce
- `useWorkspace()` — WorkspaceContext access (segments, scriptData, etc.)

### Existing Contexts (DO NOT RECREATE)
[List relevant contexts. Examples:]
- `WorkspaceContext` — session state with 25+ reducer actions
- `AuthContext` — user auth state
- `OnboardingContext` — onboarding flow state

### Existing Types (USE THESE)
[List relevant type files. Examples:]
- `src/types/topic.ts` — TrendingSource, Topic, SOURCE_BADGE_CONFIG
- `src/types/studio.ts` — SparkfluenceProject, LayerItem

### Database Tables (MATCH THESE SCHEMAS)
[List relevant tables with key columns. Examples:]
- `chat_sessions` — order_id, session_type, status, script_data (JSONB), etc.
- `trending_topics` — source, keyword, country, volume_score, expires_at

### File Organization
- Components: `src/components/` (ui/, layout/, features/, workspace/)
- Screens: `src/screens/`
- Hooks: `src/hooks/`
- Contexts: `src/contexts/`
- Types: `src/types/`
- Utilities: `src/lib/`
- Edge Functions: `supabase/functions/`

## Anti-Placeholder Rules

### The 3 Iron Laws
1. NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
2. NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
3. NO COMPLETION CLAIM WITHOUT EVIDENCE

### Before Writing ANY Component That Displays Data:
1. TRACE the data source — where does this data come from?
2. CHECK the plan — does it specify a real integration?
3. If YES — implement the real integration
4. If about to write `const data = [...]` with literal objects — STOP

### Data Source Classification
| Source | Status |
|--------|--------|
| Context/hook state | REAL |
| Supabase query result | REAL |
| Edge function response | REAL |
| Props from parent with real source | REAL |
| Computed from real data | REAL |
| Hardcoded array/object | PLACEHOLDER |
| Empty array with TODO comment | PLACEHOLDER |
| String literals for dynamic content | PLACEHOLDER |
| Mock function returning static data | PLACEHOLDER |

### If You Encounter a Situation Where Real Integration Is Not Possible:
Do NOT silently substitute with a placeholder. Instead, flag the issue in your output:
```
BLOCKER: [component] needs data from [source] but [reason it's not available].
Options: (a) implement [alternative], (b) skip, (c) placeholder with TODO.
Awaiting user decision.
```

## Files You May Create or Modify
[List the specific files this subagent is authorized to work on. Be explicit.]

- CREATE: `[absolute path]` — [purpose]
- MODIFY: `[absolute path]` — [what to change]

Do NOT modify files outside this list without flagging it.

## Dependencies
[List any other phases or files this phase depends on.]

- Depends on Phase [X-1] completing: [what it provides]
- Requires existing file: `[path]` — [what it contains]
- Requires existing hook: `[hook name]` — [what it returns]

## Constraints
- Follow Sparkfluence design system (emerald + charcoal, NOT purple)
- Use existing Shadcn UI components for Dialog, Popover, Select, Tooltip, Tabs
- Use Framer Motion for animations (200-300ms, no bounce/spring)
- Use lucide-react for icons (NOT emoji)
- TypeScript strict mode — no `any` types unless absolutely necessary
- All file paths must be absolute (Windows backslash format)
- Do NOT run npm install, deploy, push, or server commands

## Self-Review Checklist

Before submitting your implementation, verify ALL of the following:

### Completeness
- [ ] Every requirement in the task description is implemented
- [ ] No TODO/FIXME/placeholder/mock/dummy comments in the code
- [ ] All event handlers have real logic (no empty `() => {}`)
- [ ] All components import the hooks/contexts they need for data

### Quality
- [ ] TypeScript types are correct — no `any` casts
- [ ] Component props have proper interfaces defined
- [ ] Error states are handled (loading, error, empty)
- [ ] Follows CLAUDE.md naming conventions (snake_case tables, camelCase components)

### Data Sources
- [ ] Every data-displaying component uses a REAL data source
- [ ] No hardcoded arrays/objects for content that should be dynamic
- [ ] Data flow is traceable from source to render
- [ ] Existing hooks/contexts are reused (not duplicated)

### Design System
- [ ] Colors match the palette (#0B0E14, #161616, #10B981, etc.)
- [ ] No purple (#7C3AED) used anywhere
- [ ] Tailwind classes follow Sparkfluence component patterns
- [ ] Glassmorphism only on sticky headers/overlays/modals
- [ ] Retention borders follow type-to-color mapping

### Testing
- [ ] Component renders without errors
- [ ] No `console.log` in production code
- [ ] No unused imports or variables
- [ ] No functions defined but never called

## Output Format

Submit your implementation in this format:

### Files Created
```
[absolute path]
---
[full file content]
```

### Files Modified
```
[absolute path]
---
BEFORE (lines X-Y):
[original code]

AFTER:
[modified code]
```

### Data Source Report
| Component | Data Source | Type |
|-----------|-----------|------|
| [name] | [source] | REAL / PLACEHOLDER |

### Blockers (if any)
- [description of blocker and proposed resolution]

### Deviations from Plan (if any)
- [what changed and why]
```

---

## Customization Notes

When using this template, the executor must fill in:

1. **Task Description** — Copy the FULL phase text from the plan. Do not summarize.
2. **Context from CLAUDE.md** — Extract only the sections relevant to this specific phase. Do not paste the entire CLAUDE.md.
3. **Existing Hooks/Contexts** — List only those the subagent will actually need.
4. **Database Tables** — List only those the subagent will query or write to.
5. **Files You May Create or Modify** — Be specific. Restrict the blast radius.
6. **Dependencies** — List what must exist before this phase can execute.

### Over-Context vs. Under-Context

- **Over-context** — Giving the subagent the entire CLAUDE.md. Too much noise, subagent may miss relevant details.
- **Under-context** — Giving the subagent only the task description. Missing hooks, wrong patterns, placeholder risk.
- **Right-context** — Task description + relevant CLAUDE.md sections + anti-placeholder rules + self-review checklist.

Aim for right-context. The subagent should have everything it needs to implement correctly, and nothing that distracts from the task.

---

## Parallel Dispatch Rules

When dispatching multiple subagents for parallel execution:

1. **No overlapping file modifications.** Two subagents must never modify the same file.
2. **Dependency ordering.** If Phase B depends on Phase A's output, they cannot run in parallel.
3. **Shared types first.** If both phases need a new type, create the type file BEFORE dispatching.
4. **Integration after merge.** After parallel subagents complete, run an integration pass to connect their outputs.
5. **Checkpoint per subagent.** Each subagent's output gets its own data source report and deviation report.
