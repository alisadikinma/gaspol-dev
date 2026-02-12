---
name: gaspol-kickstart
description: "Use when starting any conversation. Establishes how to find and use gaspol skills. If even 1% chance a skill applies, invoke it BEFORE any response."
---

# Sparkfluence Kickstart

## The Rule

**Invoke relevant skills BEFORE any response or action.**

If there is even a 1% chance a skill applies to the user's request, invoke the Skill tool first. Do not respond, do not start working, do not "just quickly do this one thing." Invoke the skill.

---

## Flow

```
User message arrives
        |
        v
Might any skill apply? ──── No ──── Respond normally
        |
       Yes (even 1%)
        |
        v
Invoke Skill tool
        |
        v
Follow skill instructions exactly
```

---

## Skill Priority

When multiple skills might apply, use this priority:

1. **Process skills first** (brainstorm, debug, plan) -- these determine WHAT to do
2. **Implementation skills second** (tdd, execute) -- these determine HOW to do it
3. **Utility skills third** (worktree, dispatch, finish) -- these support the workflow

If a process skill and an implementation skill both apply, the process skill runs first and may invoke the implementation skill as part of its workflow.

---

## Skill Types

### Rigid Skills (follow exactly)
These skills have strict procedures that must be followed step-by-step. Do not adapt, skip, or reorder.

- `gaspol-tdd` -- RED-GREEN-REFACTOR cycle, no exceptions
- `gaspol-debug` -- Systematic debugging, no guessing
- `gaspol-verify` -- Full verification checklist
- `gaspol-finish` -- Verification chain before options

### Flexible Skills (adapt principles)
These skills provide principles and patterns. Apply them to the specific situation.

- `gaspol-brainstorm` -- Brainstorming methodology
- `gaspol-design` -- UI/UX design principles
- `gaspol-plan` -- Planning patterns
- `gaspol-review` -- Code review guidelines

---

## Red Flags: Rationalizations for NOT Invoking Skills

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple for a skill" | Simple tasks still benefit from process discipline |
| "I already know how to do this" | Skills encode lessons learned; your memory doesn't |
| "It'll be faster without the skill" | Faster now = slower later when bugs appear |
| "The user just wants a quick answer" | Quick answer + correct process > quick answer + technical debt |
| "I'll follow the skill mentally" | Mental following = skipping steps. Invoke it. |
| "This skill doesn't quite fit" | 1% chance = invoke. Let the skill decide if it applies. |
| "I'll invoke it after I start" | After = never. Invoke BEFORE any work. |
| "The user didn't ask for TDD" | Users say WHAT, not HOW. TDD is HOW. |
| "This is just a one-line fix" | One-line fixes break things too. Follow the process. |
| "I already read the skill before" | Skills are invoked, not memorized. Invoke it. |
| "This is exploratory, not implementation" | Brainstorm and debug are skills too. |
| "The skill will slow me down" | The skill will prevent you from going fast in the wrong direction. |

---

## User Instructions

When the user says "Add X" or "Fix Y" or "Build Z," they are telling you WHAT they want, not HOW to achieve it. The skills define HOW.

- "Add a button" = invoke gaspol-design + gaspol-tdd
- "Fix this bug" = invoke gaspol-debug
- "Plan this feature" = invoke gaspol-plan or gaspol-brainstorm
- "Review this code" = invoke gaspol-review
- "I'm done with this branch" = invoke gaspol-finish
- "Write a new skill" = invoke gaspol-write-skill

---

## Complete Skill List

| Skill | When to Invoke |
|-------|---------------|
| `gaspol-brainstorm` | UI/frontend ideation, design exploration |
| `gaspol-debug` | Something is broken, tests fail, unexpected behavior |
| `gaspol-design` | Building UI components, styling, layout decisions |
| `gaspol-dispatch` | 2+ independent tasks, parallel work needed |
| `gaspol-execute` | Implementation plan is ready, time to build |
| `gaspol-finish` | Work is done, need to merge/PR/cleanup |
| `gaspol-kickstart` | Starting any conversation (this skill) |
| `gaspol-parallel` | Multi-agent coordination for complex tasks |
| `gaspol-plan` | Breaking down a feature into actionable steps |
| `gaspol-receive-review` | Processing code review feedback |
| `gaspol-review` | Reviewing code for quality, correctness, patterns |
| `gaspol-sync-docs` | Updating CLAUDE.md and documentation after changes |
| `gaspol-tdd` | Any implementation or bugfix (before writing code) |
| `gaspol-verify` | Final verification before finishing |
| `gaspol-worktree` | Feature isolation, parallel branch work |
| `gaspol-write-skill` | Creating or editing skills |
