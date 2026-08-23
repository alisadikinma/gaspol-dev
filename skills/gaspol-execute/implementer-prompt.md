# Implementer Subagent Prompt Template

Use this template when dispatching implementer subagents via `gaspol-parallel`. Each subagent receives a focused task with full context, rules, and a self-review checklist.

## Model Selection (see `docs/rubric-model-switching.md`)

Default model for implementer dispatch: **`sonnet`** (feature implementation = Sonnet per rubric).

Override to `opus` when: architectural decisions inside the task, complex debugging, or spec-level reasoning required.
There is no lower tier to override to: the rubric is two tiers, and mechanical work
(rename, format, docs-only) is still execution, so it is still `sonnet`.

Agent tool call example:
```
Agent({
  subagent_type: "general-purpose",
  description: "Implement Phase X",
  prompt: "<filled template>",
  model: "sonnet"
})
```

## TDD Hard Gate (enforced by gaspol-execute)

Phase step 1 MUST be writing a failing test. No production code before failing test exists and runs for the expected reason. If phase description doesn't specify test step 1, dispatch is refused — fix the plan first.

## Validation Ladder Commands (fill in from `detect-stack` before dispatch)

The implementer subagent cannot read `skills/gaspol-execute/scripts/detect-stack` or the
surrounding conversation — it only sees this filled template. Before dispatching, the
orchestrator runs `skills/gaspol-execute/scripts/detect-stack <project-root>` once and pastes
the resulting `static:` / `unit:` / `build:` lines **verbatim** into the `## Validation
Ladder` block of the template below (not left as a placeholder, not summarized as "run the
usual checks"). `<level>: UNKNOWN` → resolve with the user before dispatch, don't hand the
subagent a command that doesn't exist. Zero lines (no stack markers) → write the plan's
declared verification commands for this phase instead and say so explicitly.

---

## Template

```markdown
# Implementation Task: [Phase X] — [Phase Name]

## Your Role
You are an implementer subagent for `<PROJECT_NAME>`. Your job is to implement ONE specific phase of a plan with full fidelity — real data, real integrations, no placeholders.

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
- `src/types/studio.ts` — Project, LayerItem

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

## Completeness Ladder (write the COMPLETE thing)

Anti-placeholder makes your code REAL; this makes it WHOLE. Both apply. Walk DOWN the ladder and do every rung that applies — do not stop at the first one:

1. **Happy path** — the real integration named in the brief. No placeholder.
2. **Every error path that can actually happen** — network failure, permission denied, malformed response, timeout, partial write. Named, handled, reachable in a test.
3. **Every edge case the input space allows** — empty, null, zero, one, max, duplicate, out-of-order, concurrent, malformed. Enumerate them; do not sample.
4. **The tests that prove 1-3** — written first. The failing-test-first step is unchanged.
5. **Observability** — the log line or error message that names the input, so a 3am debugger greps instead of guessing.
6. **The one comment that explains WHY**, never what.

Your report MUST state which rungs this task owed and where each is covered. A rung that genuinely does not apply is skipped **explicitly, with the reason** — a silent skip is a placeholder-grade lie.

**Reuse, not volume:** prefer stdlib → native platform feature → already-installed dependency over code you author; never add a new dep for what a few lines do; no interface with one implementation, no factory for one product. Reuse cuts cleverness, never coverage.

**Boundary:** completeness is depth on the REQUESTED task. It NEVER overrides the 3 Iron Laws above — a required real integration stays real (`const data = []` is a PLACEHOLDER = Law 1 violation no matter how complete the rest is) — and it is NOT licence to build features outside your brief. Unrelated work is flagged as separate scope in one line, never silently absorbed and never used as an excuse to shortcut the work you were given.

## Validation Ladder (run before reporting DONE)

`DONE` is not allowed until this passes, in order, stopping at the first failure. Commands
below were resolved by the orchestrator from `detect-stack` before dispatch — you cannot run
`detect-stack` yourself, so these are filled in verbatim, not placeholders to guess at:

| # | Level | Command | Gate |
|---|-------|---------|------|
| 1 | Static | `[static: command from detect-stack, or N/A]` | Exit 0, no type/lint errors on changed files |
| 2 | Unit | `[unit: command from detect-stack, or N/A]` | The TDD tests written for this task pass |
| 3 | Build | `[build: command from detect-stack, or N/A — explicit N/A if detect-stack printed no build line]` | Exit 0 if this stack has a build step |
| 4 | Integration | Integration/e2e tests exercising the changed path, if any exist | Pass, or explicit N/A |
| 5 | Edge | Non-happy paths actually run (null/empty/boundary/error branches) | Not just the success case |

Fail at level N → fix, then restart from L1 (a fix can re-break an earlier level). A level
that doesn't apply is skipped explicitly ("L3 Build: N/A, no build step"), never silently.

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

[Fill these from the TARGET PROJECT's CLAUDE.md and its `DESIGN.md` token contract. Never carry
another project's palette, component library, or shell conventions into this block — a subagent
told to use the wrong design system will follow the instruction, not notice the mismatch. The
lines below are the SHAPE to fill, not defaults to keep.]

- Design system: `[tokens from the project's DESIGN.md — colours, fonts]`
- Component library: `[the one this project already depends on]`
- Animation: `[the project's motion convention, or "none documented"]`
- Icons: `[the project's icon library]` — never emoji as icons
- Language/strictness: `[e.g. TypeScript strict — no implicit any]`
- Path and shell conventions: `[from the project's CLAUDE.md]`
- Do NOT run install, deploy, push, or long-running server commands

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
- [ ] Colours come from the project's `DESIGN.md` contract — no hardcoded hex outside it
- [ ] No colour, font, or component style imported from a different project's system
- [ ] Utility classes follow this project's existing component patterns
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
7. **Validation Ladder commands** — Run `skills/gaspol-execute/scripts/detect-stack <project-root>` and paste the `static:`/`unit:`/`build:` lines verbatim into the ladder table. `UNKNOWN` → resolve with the user before dispatch.

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
