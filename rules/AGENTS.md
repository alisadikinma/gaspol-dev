# gaspol-dev — Process Discipline Rules

═══════════════════════════════════════════════════════════════
gaspol-dev active — Process discipline for real code, not placeholders.
═══════════════════════════════════════════════════════════════

## The 1% Rule (Auto-Trigger Directive)
**Non-negotiable**: If there is even a 1% chance a gaspol skill applies to what you are about to do, activate and read its `SKILL.md` BEFORE taking action — before writing code, before making assumptions, before "just one quick thing." For bootstrap guidance, refer to `using-gaspol`.

### Routing Table — Match Intent Before Acting:
| Intent | Skill to Activate |
| :--- | :--- |
| **build / add feature / new component** | `gaspol-brainstorm` |
| **plan / break down a task** | `gaspol-plan` |
| **execute a plan (with checkpoints)** | `gaspol-execute` |
| **execute fully autonomously** | `gaspol-auto` |
| **parallel / independent work** | `gaspol-worktree` → `gaspol-parallel` |
| **isolate workspace / protect branch** | `gaspol-worktree` |
| **implement or fix (before code)** | `gaspol-tdd` |
| **bug / error / test failure** | `gaspol-debug` |
| **review code** | `gaspol-review` |
| **received review feedback** | `gaspol-receive-review` |
| **claim done / ready to commit** | `gaspol-verify` |
| **merge / PR / cleanup a branch** | `gaspol-finish` |
| **sync project docs / guidelines** | `gaspol-sync-docs` |
| **research a lib / API / pattern** | `gaspol-research` |
| **architectural decision** | `gaspol-adr` |

---

## The 3 Iron Laws
These are non-negotiable. No rationalization overrides them:
1. **LAW 1**: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION.
2. **LAW 2**: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL.
3. **LAW 3**: NO COMPLETION CLAIM WITHOUT EVIDENCE.

---

## Completeness Ladder (Always-On Coverage Governor)
Do the complete thing — completeness is cheap now, the shortcut is not.
Walk **DOWN** and do every rung:
1. **Happy path, real integration**.
2. **Every error path** that can actually happen.
3. **Every edge case** the input space allows — enumerate, don't sample.
4. **The tests** that prove 1–3, written first.
5. **The observability** a 3am debugger needs (logs, errors, state).
6. **The one comment** that explains WHY.

* **Reuse**: Prefer stdlib → native feature → already-installed dependency over authoring new code.
* **Boundary**: Completeness is depth on the REQUESTED work, never new features, and never an excuse for a placeholder or a skipped Iron Law.

---

## Interactive Confirmation Rule
Whenever clarifying questions, confirmations, or option selections are required, use the interactive `ask_question` tool to present structured choices to the user.

---

## Slash Command Invocations
If the user's message begins with or contains a slash command for any skill (e.g., `/gaspol-brainstorm`, `/gaspol-plan`, `/gaspol-execute`, `/gaspol-tdd`, `/gaspol-verify`, `/gaspol-debug`, `/gaspol-review`, `/gaspol-finish`, `/using-gaspol`, etc.):
1. Treat it as an explicit, high-priority command to execute that specific skill.
2. Immediately activate and read the corresponding `SKILL.md` before taking any other action.
3. Announce the skill activation and execute its protocol faithfully following the 3 Iron Laws.

