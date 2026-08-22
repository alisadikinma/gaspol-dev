---
name: using-gaspol
description: "Use at the start of any conversation or task in a project where gaspol-dev is installed. Establishes how to find and invoke gaspol skills, requiring a Skill-tool check BEFORE any response — including clarifying questions, codebase exploration, or 'just one quick thing'."
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific, already-scoped task, skip this skill — your controller already selected the workflow.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If there is even a 1% chance a gaspol skill applies to what you are about to do, you MUST invoke that skill via the Skill tool first.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of it. Invoking a skill that turns out not to fit costs seconds; skipping one that did fit costs a broken feature, a placeholder shipped to production, or a debugging session you could have avoided.
</EXTREMELY-IMPORTANT>

# Using gaspol

This is the bootstrap. Its single job: make the right gaspol skill fire at the right moment, automatically, without the user having to type a slash command.

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means you invoke it to check. The skill check comes BEFORE clarifying questions, BEFORE reading files, BEFORE "let me just quickly look."

```
User message received
   │
   ▼
About to write code / create / fix / plan / review / finish something?
   │ yes (even 1%)
   ▼
Invoke the matching gaspol skill (Skill tool)  ──►  Announce: "Using <skill> to <purpose>"
   │                                                        │
   │ has a checklist? ──► create a TodoWrite item per step  │
   ▼                                                        ▼
Follow the skill exactly  ◄─────────────────────────────────┘
   │
   ▼ definitely no skill applies
Respond directly (including clarifications)
```

## Instruction Priority

gaspol skills override default model behavior, but **the user's instructions always win**:

1. **User's explicit instructions** (the project's CLAUDE.md, direct requests) — highest priority
2. **gaspol skills** — override default behavior where they conflict
3. **Default behavior** — lowest priority

If the project's CLAUDE.md says "skip TDD here" and `gaspol-tdd` says "always TDD," follow the user. The user is in control. (Note: gaspol's own anti-placeholder Iron Laws are a safety floor — if you are about to ship fake data, surface it via AskUserQuestion rather than silently complying.)

## How to Access Skills

Use the **Skill** tool. When you invoke a skill, its full content is loaded — follow it directly. **Never use the Read tool on a SKILL.md file** to "peek" at it; that loads stale content and skips the harness's skill machinery.

## Skill Routing (match intent → invoke BEFORE responding)

| User intent | Invoke |
|-------------|--------|
| Create a feature, add a component, build something new | `gaspol-brainstorm` |
| Design UI, colors, layout, styling | `ui-ux-pro-max` (third-party plugin; if absent, tell the user to run `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill` and continue without it — gaspol declares no hard dependency on it) — also auto-triggered by brainstorm |
| Plan an implementation, break down a task | `gaspol-plan` |
| Execute a plan (per-phase checkpoints) | `gaspol-execute` |
| Execute a plan fully autonomously | `gaspol-auto` |
| Execute with parallel/independent work | `gaspol-parallel` (→ `gaspol-worktree` first) |
| Need an isolated workspace / protect current branch | `gaspol-worktree` |
| Implement or fix anything (before writing code) | `gaspol-tdd` |
| A bug, error, test failure, unexpected behavior | `gaspol-debug` |
| Review code quality | `gaspol-review` |
| Auth, secrets, user input, API endpoint, payment, sensitive data | built-in `/security-review` (also auto-run by execute Step 3.6 + finish gate) |
| Received review feedback | `gaspol-receive-review` |
| Claim work is done / ready to commit | `gaspol-verify` |
| Done with a branch — merge/PR/cleanup | `gaspol-finish` |
| Update CLAUDE.md after changes | `gaspol-sync-docs` |
| Research a library/API/pattern | `gaspol-research` |
| An architectural decision at a fork | `gaspol-adr` |
| Capture patterns after shipping | `gaspol-learn` |

## Skill Priority (when several could apply)

1. **Process skills first** (brainstorm, debug, plan) — determine WHAT to do.
2. **Implementation skills second** (tdd, execute, auto, parallel, design) — determine HOW.
3. **Verification skills third** (verify, review, finish, plan-verifier).
4. **Learning skills fourth** (learn, adr, kb-audit).

"Let's build X" → brainstorm first. "Fix this bug" → debug first.

## Red Flags — these thoughts mean STOP, you're rationalizing

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for a skill. |
| "I need more context first" | The skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore (CLAUDE.md-first). Check first. |
| "I'll just do this one quick thing" | Check BEFORE doing anything. |
| "I remember this skill" | Skills evolve. Invoke the current version, don't recall it. |
| "This doesn't need a formal skill" | If a skill exists, use it. 1% = invoke. |
| "The user didn't ask for TDD/brainstorm" | Users say WHAT, skills say HOW. WHAT ≠ skip the process. |
| "It'll be faster without the skill" | Faster now = slower later when the bug appears. |

## Skill Types

- **Rigid** (`gaspol-tdd`, `gaspol-debug`, `gaspol-verify`, `gaspol-finish`, `gaspol-auto`, `gaspol-worktree`): follow exactly, do not adapt away the discipline.
- **Flexible** (`gaspol-brainstorm`, `gaspol-plan`, `gaspol-review`, `gaspol-research`): adapt the principles to the situation.
- **Meta** (`gaspol-sync-docs`, `using-gaspol`): apply to the plugin/process itself.

The skill states which type it is.

## Interactive Confirmation

All clarifying questions, confirmations, and option selections use the **AskUserQuestion** tool (interactive modal), never a wall of text. See the project CLAUDE.md "Interactive Confirmation Rule."
