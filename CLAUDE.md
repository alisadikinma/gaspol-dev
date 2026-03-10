# gaspol-dev — Claude Plugin Instructions

## Plugin Overview

Claude Code plugin providing 16 development skills + 4 agents for execution fidelity, anti-placeholder enforcement, per-phase checkpoints, plan verification, and design intelligence. Born from building a real AI-powered SaaS platform.

## Architecture

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, author) |
| `.claude-plugin/marketplace.json` | Marketplace listing |
| `hooks/hooks.json` | SessionStart hook definition |
| `hooks/session-start.sh` | Session start script — announces available skills |
| `skills/gaspol-brainstorm/SKILL.md` | Collaborative brainstorming with CLAUDE.md-first approach |
| `skills/gaspol-design/SKILL.md` | Frontend design intelligence — anti-AI-slop aesthetics |
| `skills/gaspol-plan/SKILL.md` | Implementation planning with Data Integration Maps |
| `skills/gaspol-execute/SKILL.md` | Plan execution with anti-placeholder enforcement + checkpoints |
| `skills/gaspol-execute/anti-placeholder-rules.md` | Authoritative placeholder detection reference |
| `skills/gaspol-execute/checkpoint-template.md` | Per-phase checkpoint report template |
| `skills/gaspol-execute/implementer-prompt.md` | Subagent dispatch template |
| `skills/gaspol-parallel/SKILL.md` | Multi-agent parallel execution with two-stage review |
| `skills/gaspol-parallel/spec-reviewer-prompt.md` | Spec compliance reviewer template |
| `skills/gaspol-parallel/code-quality-reviewer-prompt.md` | Code quality reviewer template |
| `skills/gaspol-dispatch/SKILL.md` | Parallel agent dispatch for independent problem domains |
| `skills/gaspol-tdd/SKILL.md` | RED-GREEN-REFACTOR cycle enforcement |
| `skills/gaspol-tdd/testing-anti-patterns.md` | Testing anti-pattern reference |
| `skills/gaspol-debug/SKILL.md` | Systematic root cause debugging — no guessing |
| `skills/gaspol-debug/root-cause-tracing.md` | Backward tracing technique reference |
| `skills/gaspol-debug/defense-in-depth.md` | 4-layer validation reference |
| `skills/gaspol-debug/condition-based-waiting.md` | Condition-based polling patterns |
| `skills/gaspol-review/SKILL.md` | Code review dispatch with code-reviewer subagent |
| `skills/gaspol-receive-review/SKILL.md` | Receiving review feedback — verify before implementing |
| `skills/gaspol-verify/SKILL.md` | 4-layer verification (technical, plan fidelity, placeholder scan, integration) |
| `skills/gaspol-verify/plan-verification.md` | Plan vs code comparison process |
| `skills/gaspol-finish/SKILL.md` | Branch completion with verification chain + merge/PR/cleanup |
| `skills/gaspol-sync-docs/SKILL.md` | CLAUDE.md sync after code changes (3 modes) |
| `skills/gaspol-worktree/SKILL.md` | Git worktree management with safety verification |
| `skills/gaspol-kickstart/SKILL.md` | Session startup skill routing |
| `skills/gaspol-write-skill/SKILL.md` | Skill creation with TDD (RED-GREEN-REFACTOR for skills) |
| `agents/code-reviewer.md` | Code review between commits |
| `agents/code-simplifier.md` | Simplify and refine code for clarity |
| `agents/plan-verifier.md` | Compare plan vs actual code changes |
| `agents/spec-reviewer.md` | Verify implementation matches specification |

## Interactive Confirmation Rule (MANDATORY)

**ALL clarifying questions, confirmations, and option selections MUST use the `AskUserQuestion` tool.**

This shows an interactive popup modal with selectable options — NOT plain text questions buried in chat output. The user expects to see a modal they can click on, not a wall of text.

When to use AskUserQuestion:

- Brainstorming clarifying questions (Phase 1 questions, design approval)
- Checkpoint approvals after each phase ("Proceed to next phase?")
- Decision gates (placeholder vs real integration, merge vs PR vs keep vs discard)
- Design confirmations ("Does this look right?")
- Any yes/no or multiple-choice question during skill execution

Format: Always provide 3-5 selectable options. Include "Something else" or a custom-input option as the last choice.

## The Rule

**Invoke relevant skills BEFORE any response or action.**

If there is even a 1% chance a skill applies to the user's request, invoke the Skill tool first. Do not respond, do not start working, do not "just quickly do this one thing." Invoke the skill.

## Skill Routing

When a user message arrives, match it against this table and invoke the skill BEFORE responding:

| User Intent | Skill to Invoke |
|-------------|-----------------|
| Create feature, add component, build something new | `gaspol-brainstorm` |
| Design UI, pick colors, layout, styling | `gaspol-design` |
| Plan implementation, break down a task | `gaspol-plan` |
| Execute an existing plan from `docs/plans/` | `gaspol-execute` |
| Execute plan with independent parallel tasks | `gaspol-parallel` |
| 2+ independent tasks, parallel work needed | `gaspol-dispatch` |
| Implement or fix anything (before writing code) | `gaspol-tdd` |
| Bug, error, test failure, unexpected behavior | `gaspol-debug` |
| Review code quality after completing work | `gaspol-review` |
| Received code review feedback from others | `gaspol-receive-review` |
| Claim work is done, ready to commit/merge | `gaspol-verify` |
| Done with feature branch, merge/PR/cleanup | `gaspol-finish` |
| Update CLAUDE.md after code changes | `gaspol-sync-docs` |
| Need feature isolation, git worktree | `gaspol-worktree` |
| Create or edit a skill | `gaspol-write-skill` |

### Implicit Routing (Users say WHAT, skills say HOW)

| User Says | Actually Means |
|-----------|---------------|
| "Add a button" | invoke `gaspol-brainstorm` + `gaspol-design` + `gaspol-tdd` |
| "Fix this bug" | invoke `gaspol-debug` |
| "Plan this feature" | invoke `gaspol-brainstorm` or `gaspol-plan` |
| "Review this code" | invoke `gaspol-review` |
| "I'm done with this branch" | invoke `gaspol-finish` |
| "Write a new skill" | invoke `gaspol-write-skill` |

### Priority Order

When multiple skills apply:

1. **Process skills first** (brainstorm, debug, plan) — determine WHAT to do
2. **Implementation skills second** (tdd, execute) — determine HOW to do it
3. **Utility skills third** (worktree, dispatch, finish) — support the workflow

### Skill Types

**Rigid skills** — follow exactly, step-by-step, no adaptation:
`gaspol-tdd`, `gaspol-debug`, `gaspol-verify`, `gaspol-finish`

**Flexible skills** — apply principles to the specific situation:
`gaspol-brainstorm`, `gaspol-design`, `gaspol-plan`, `gaspol-review`

## Key Concepts

### Workflow Chains (skills chain automatically)

```text
brainstorm -> plan -> execute -> verify -> sync-docs -> review -> finish
```

- `gaspol-brainstorm` auto-triggers `gaspol-design` for UI work (Phase 3 detection: new pages, components, visual redesigns, layouts, dashboards, animations, themes)
- `gaspol-brainstorm` leads to `gaspol-plan` after design approval (saves spec to `docs/plans/YYYY-MM-DD-<topic>-design.md`)
- `gaspol-plan` produces implementation plan with mandatory Data Integration Map
- `gaspol-execute` runs per-phase checkpoints, then auto-invokes: verify -> sync-docs -> review
- `gaspol-finish` runs verification chain: verify -> plan-verifier -> sync-docs -> then presents 4 options (merge, PR, keep, discard)

### CLAUDE.md-First Approach

Before exploring ANY codebase in a target project, ALWAYS read that project's CLAUDE.md first. Extract:

- Existing routes/components (avoid duplication)
- Data sources (hooks, APIs, edge functions)
- Design system tokens (colors, patterns, component styles)
- Known gotchas (debugging checklist)
- Database tables and schemas
- Conventions (naming, file organization, patterns)

This saves 10-50k tokens per brainstorm session by avoiding redundant codebase exploration.

### Anti-Placeholder Enforcement

The 3 Iron Laws (non-negotiable):

```text
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

**Before implementing ANY component that displays data:**

1. TRACE the data source — where does this data come from?
2. CHECK the plan — does the plan specify a real integration?
3. If YES — implement the real integration. Period.
4. If about to write `const data = [...]` — STOP. Present user 3 options: (a) implement real integration, (b) skip entirely, (c) placeholder with explicit TODO. NEVER choose (c) silently.

**Data Source Classification:**

| Source Type | Status | Example |
|-------------|--------|---------|
| Hook/Context state | REAL | `const { data } = useSegments()` |
| Edge function response | REAL | `await supabase.functions.invoke(...)` |
| Props from parent (real source) | REAL | `function Card({ segment }: Props)` |
| Computed from real data | REAL | `segments.reduce(...)` |
| Local UI state (toggles, inputs) | REAL | `useState(false)` |
| Hardcoded array in component | PLACEHOLDER | `const data = [{id:1}]` |
| Empty array awaiting API | PLACEHOLDER | `const data: T[] = []` |
| String literals for dynamic content | PLACEHOLDER | `const title = "Sample"` |
| Mock function returning static data | PLACEHOLDER | `() => mockData` |
| Commented-out API call | PLACEHOLDER | `// TODO: fetch` |

### Per-Phase Checkpoints

After completing EACH phase (never batched), present structured checkpoint report:

```text
## Phase [X] Complete: [Phase Name]

### Implemented:
- [feature] with [real data source]

### Data Sources:
| Component | Data Source | Type |
|-----------|-----------|------|
| [name] | [source] | Real / Placeholder |

### Files Modified:
- [file path] (created/modified)

### Deviations from Plan:
- None / [description + justification]

### Next Phase: [X+1] — [description]
-> Waiting for approval before proceeding.
```

Rules: One phase one checkpoint. Wait for user approval before next phase. Report all deviations. Classify all data sources as Real or Placeholder.

### Brainstorming Flow (gaspol-brainstorm)

When user wants to create, add, or modify anything:

1. **Phase 0**: Read project's CLAUDE.md first (MANDATORY before any codebase exploration)
2. **Phase 1**: Ask clarifying questions ONE at a time (multiple choice, max 4 options). Only one question per message. Understand the problem before proposing solutions
3. **Phase 2**: Propose 2-3 approaches with trade-offs. Lead with recommendation. YAGNI ruthlessly
4. **Phase 3**: Design Intelligence (AUTO-TRIGGERED for UI work) — run design search, apply bold aesthetic choices (NOT generic AI output), constrain with project design system
5. **Phase 4**: Implementation feasibility check — can this be built with REAL data from existing backend?
6. **Phase 5**: Present design in 200-300 word sections, ask "Does this look right?" after each. Include Data Integration Map
7. **Phase 6**: Write spec to `docs/plans/`, offer to proceed to `gaspol-plan`

### TDD Enforcement (gaspol-tdd)

Iron Law: `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`

RED-GREEN-REFACTOR cycle:

1. **RED**: Write ONE minimal failing test. State WHY it will fail and WHAT error to expect BEFORE writing it
2. **Verify RED**: Run test, confirm it fails for the expected reason (not setup error)
3. **GREEN**: Write SIMPLEST code to pass. No extra features. No refactoring
4. **Verify GREEN**: Run ALL tests. Zero failures, zero errors, zero warnings
5. **REFACTOR**: Improve code quality. No new behavior. Run ALL tests after every change
6. Repeat

If code was written before test: DELETE IT. Start over. No exceptions.

### Systematic Debugging (gaspol-debug)

Iron Law: `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST`

4 Phases:

1. **Root Cause Investigation**: Read FULL error message + stack trace. Reproduce consistently. Check recent changes (`git log --oneline -20`). Isolate the layer. Trace data flow. Use backward tracing (symptom -> immediate cause -> upstream -> root cause)
2. **Pattern Analysis**: Find working examples FIRST. Read working version COMPLETELY. Compare systematically. Check dependencies and docs
3. **Hypothesis and Testing**: One hypothesis, one change, one test. If 3 attempts fail -> STOP, question the architecture
4. **Implementation**: Create failing regression test. Implement single fix. Verify fix. Check for regressions

### 4-Layer Verification (gaspol-verify)

Iron Law: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

**The Gate Function** (5 steps, no shortcuts):

1. IDENTIFY — what command proves this claim?
2. RUN — execute the FULL command, fresh, not from cache
3. READ — complete output, check exit code, count failures
4. VERIFY — does output actually confirm the specific claim?
5. ONLY THEN — make the claim, quote the evidence

**Layer 1: Technical** — `npm run build` (exit 0), `npx tsc --noEmit` (exit 0), `npm test` (0 failures), `npm run lint`

**Layer 2: Plan Fidelity** — compare implementation to plan phase by phase (DONE/PARTIAL/SKIPPED/DIVERGED)

**Layer 3: Placeholder Scan** — search changed files for TODO/FIXME/HACK/placeholder/mock/dummy patterns, check for hardcoded data, missing imports, dead code, console.log

**Layer 4: Integration** — verify data flows from source through hook/context to rendered output, check error/loading/empty states

### Design Intelligence (gaspol-design)

Anti-AI-Slop Rules:

**NEVER use**: Inter/Roboto/Arial as primary, purple gradients on white, predictable symmetric layouts, cookie-cutter card grids, emojis as icons

**ALWAYS choose**: Distinctive display fonts, sharp accent contrast, asymmetric/grid-breaking layouts, intentional motion, layered backgrounds

Output format: Aesthetic Direction -> Color Palette (hex codes) -> Typography (font pairings) -> Component Examples (code) -> Layout Blueprint (ASCII) -> Motion Plan (timing table)

### Plan Structure (gaspol-plan)

Every plan MUST include:

- **Data Integration Map** (contract between planner and executor):

```text
| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
```

- **Per-phase verification criteria** (no phase ships without checks)
- **TDD-first steps** (write test, see fail, implement, see pass, commit)
- Bite-sized tasks (2-5 minutes each, one action per step)
- Plan header with gaspol-execute instruction

Plans saved to: `docs/plans/YYYY-MM-DD-<feature-name>.md`

### Parallel Execution (gaspol-parallel)

Fresh subagent per task + two-stage review:

1. **Implementer** dispatched with full task text (NEVER reference a file), anti-placeholder rules, self-review checklist
2. **Spec Review** — reads ACTUAL CODE (not implementer's report), compares to requirements line by line
3. **Code Quality Review** — uses code-reviewer template, reviews commits between base SHA and HEAD
4. If spec fails after 3 attempts -> stop and escalate to user

### Agent Dispatch (gaspol-dispatch)

One agent per independent problem domain. Use when:

- 3+ failures with different root causes
- Multiple independent subsystems need changes
- No shared state between tasks
- Embarrassingly parallel work

Do NOT use when: related failures (fixing one fixes others), shared state, sequential dependencies, single root cause.

Conflict check before dispatching: Do they modify the same files? Same database tables? Does one produce output the other needs? If yes to any -> do NOT parallelize.

### Receiving Review Feedback (gaspol-receive-review)

Response pattern: READ -> UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND -> IMPLEMENT

**Forbidden responses**: "You're absolutely right!", "Great point!", "Great catch!", "Thanks for pointing that out!" — these are performative agreement, not technical assessment

**Instead**: "Fixed. [description]." / "Good catch. [root cause]. Fixed in [location]." / "I checked this — the current code is correct because [reason]."

When feedback is unclear: STOP. Do not guess. Ask for clarification with specific interpretation options.

### Finishing Work (gaspol-finish)

Pre-finish verification chain (MANDATORY):

1. Run `gaspol-verify` (all 4 layers)
2. Run plan verifier (compare plan vs actual)
3. Run `gaspol-sync-docs` (update CLAUDE.md)

Then present exactly 4 options:

- **Merge locally** — `git merge --no-ff`, verify tests, delete branch
- **Push and create PR** — `git push -u`, `gh pr create`
- **Keep as-is** — leave branch, report status
- **Discard** — requires typed "discard" confirmation

### Sync Docs (gaspol-sync-docs)

3 modes:

- **Mode 1: Post-Implementation Sync** — scan git diff, map changes to CLAUDE.md sections, apply updates
- **Mode 2: Quality Audit** — score CLAUDE.md against 6 criteria (100 points), grade A-F
- **Mode 3: Session Learning Capture** — reflect on missing context, propose one-liner additions

### Git Worktree (gaspol-worktree)

Safety verification before creating any worktree:

1. Directory is gitignored (`git check-ignore -q .worktrees`)
2. Branch does not already exist
3. No existing worktree at target path
4. Clean working directory (warn if dirty)

### Writing Skills (gaspol-write-skill)

TDD applied to process documentation:

- **RED**: Run agent WITHOUT skill, document failures
- **GREEN**: Write minimal SKILL.md addressing each failure
- **REFACTOR**: Re-test WITH skill, close loopholes

SKILL.md frontmatter `description` must start with "Use when..." — triggering conditions ONLY, NEVER summarize the workflow (Claude follows summary instead of reading full skill).

## Red Flags: Rationalizations for NOT Invoking Skills

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple for a skill" | Simple tasks still benefit from process discipline |
| "I already know how to do this" | Skills encode lessons learned; your memory doesn't |
| "It'll be faster without the skill" | Faster now = slower later when bugs appear |
| "The user just wants a quick answer" | Quick answer + correct process > quick answer + debt |
| "I'll follow the skill mentally" | Mental following = skipping steps. Invoke it. |
| "This skill doesn't quite fit" | 1% chance = invoke. Let the skill decide. |
| "The user didn't ask for TDD" | Users say WHAT, not HOW. TDD is HOW. |
| "I'll invoke it after I start" | After = never. Invoke BEFORE any work. |
| "This is just a one-line fix" | One-line fixes break things too. Follow the process. |
| "I already read the skill before" | Skills are invoked, not memorized. Invoke it. |
| "The skill will slow me down" | The skill prevents going fast in the wrong direction. |

## Debugging (Plugin Development)

| Issue | Check |
|-------|-------|
| Skill not loading | Verify `SKILL.md` exists in `skills/<name>/` with correct YAML frontmatter |
| Skill not triggering | Check `description` field in frontmatter — must contain triggering conditions |
| Agent says "looks fine" without running commands | `gaspol-verify` not invoked — Iron Law: no claims without fresh evidence |
| Placeholders slipping through | `gaspol-execute` anti-placeholder rules not enforced — check Data Source Classification |
| Agent jumps to code without asking questions | `gaspol-brainstorm` not invoked — Phase 1 requires questions ONE at a time |
| Agent writes code before tests | `gaspol-tdd` not invoked — Iron Law: no production code without failing test first |
| Agent guesses at bug fixes | `gaspol-debug` not invoked — Iron Law: no fixes without root cause investigation |
| Agent claims "done" without evidence | `gaspol-verify` not invoked — 4-layer verification required |
| Agent batch-completes phases | Checkpoint rules violated — one phase, one checkpoint, one approval |
| Agent uses performative agreement | `gaspol-receive-review` not invoked — forbidden responses list |
| Agent creates duplicate hooks/contexts | CLAUDE.md-first rule not followed — check existing architecture before creating new |
| Session-start hook not firing | Check `hooks/hooks.json` matcher pattern and `session-start.sh` permissions |
| Skills not listed in session | Check that `CLAUDE.md` exists and is loaded by Claude Code |

## Conventions for Contributors

### Adding a New Skill

1. Create `skills/gaspol-<name>/SKILL.md` with YAML frontmatter
2. Follow RED-GREEN-REFACTOR process from `gaspol-write-skill`
3. Update this CLAUDE.md with skill entry in Architecture and Skill Routing tables
4. Update `hooks/session-start.sh` to announce the new skill
5. Add supporting reference files in the skill directory if needed

### Editing a Skill

1. Read the existing SKILL.md completely
2. Make changes, preserving the skill structure (Iron Law, Core Principle, Process, Red Flags, Rationalization Table, Integration)
3. Re-test with a pressure scenario to verify changes work
4. Update this CLAUDE.md if skill description or routing changed

### File Naming

- Skill directories: `gaspol-<kebab-case-name>/`
- Main skill file: always `SKILL.md`
- Reference files: lowercase, kebab-case (e.g., `anti-placeholder-rules.md`)
- Agent files: `<kebab-case-name>.md` in `agents/`

---

**Version:** 1.1.0
**Last Updated:** March 2026
