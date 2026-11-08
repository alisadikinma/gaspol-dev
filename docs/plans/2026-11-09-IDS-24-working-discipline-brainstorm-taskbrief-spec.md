**Ticket:** IDS-24

# IDS-24: working discipline (Karpathy), brainstorm questions and a fence-aware task-brief (superpowers 7.0.2)

Target release: **1.34.0**. One ticket by the Batch Gate: one request, three items, all inside `skills/`, one plan under the phase threshold.

## Sources, read on 2026-11-09

- `multica-ai/andrej-karpathy-skills` (MIT): one `CLAUDE.md` with four principles: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.
- `/Users/alisadikin/Drive-D/claude-plugin/superpowers` v7.0.2, the only release since the v7.0.1 review: brainstorming tuning, harness bootstrap fixes (Windows, no-bash), SDD helper fixes.

## Prior-art verdict (`skills/_shared/prior-art-gate.md`): DELTA

| Principle / change | Already in gaspol-dev? | Verdict |
|---|---|---|
| Goal-Driven Execution | yes: TDD step 1, plan Verification blocks, `gaspol-verify` | skip |
| Simplicity First | contradicts the Completeness Ladder, which replaced the Laziness Ladder in IDS-10 for making scope-cutting the default | **not adopted**, on purpose |
| Surgical Changes | no. `grep -rniE "surgical\|adjacent code\|drive-by\|unrelated dead code" skills/ hooks/ agents/` returned nothing. The only nearby text tells the executor to scan for orphaned imports, with no ownership rule | **adopt (Part A)** |
| Think Before Coding | only inside `gaspol-brainstorm`; no always-on rule, so a direct edit or a bug fix state no assumptions | **adopt (Part A)** |
| 7.0.2 brainstorming: ask only when the answer changes what gets built; process steps are the agent's calls; do recon instead of offering it | no. `gaspol-brainstorm` says every clarifying question uses `AskUserQuestion`, one at a time, and nothing says which questions may be skipped | **adopt (Part C)** |
| 7.0.2 `task-brief` hardening (fence-aware headings, refuse an unclosed fence, exact ID match) | gaspol's `task-brief` cuts a phase at the first `---` line even inside a fenced code block (open debt from IDS-23, found at Phase A) | **adopt (Part B)**, it closes that debt |
| 7.0.2 hook fixes for Windows and a missing bash, OpenCode V2, Devin, Hermes, Grok support | the owner runs macOS and Claude Code only | skip |

## Part A: working discipline, always on

New `skills/_shared/working-discipline.md`, written once and read from the places below. Two rules.

1. **Surgical changes.** Every changed line traces to the request. No tidying of adjacent code, comments or formatting. Match the existing style. Remove only imports, variables and functions that **your own change** left unused. Unrelated dead code is reported, never deleted.
2. **Think before coding.** State the assumptions before writing code. When a request has two readings, name both instead of picking one silently. Say so when a simpler way exists. When confused, stop and ask through `AskUserQuestion`.

**The boundary with the Completeness Ladder is written into the file.** Surgical limits code **outside** the task; the Ladder demands depth **inside** it. The two do not conflict. The new file says Simplicity First was read and not adopted, and why, so the next reader does not re-propose it.

Wiring, kept small because of two hard budgets:

- `hooks/session-start.sh` gains 4 to 5 lines and a pointer to the file. The hook is injected in every session (4,357 bytes today), so the addition stays under about 350 bytes.
- `skills/gaspol-execute/implementer-prompt.md` points at the file. Implementers are dispatched without the session hook's context, so they need the pointer.
- `skills/_shared/completeness-ladder.md` gets one sentence pointing at the file, next to its existing BOUNDARY line.
- **No SKILL.md body is touched for Part A.** `gaspol-execute` has 9 bytes and `gaspol-plan` 21 bytes under the 18,000 ceiling, so a pointer there would force a trim.
- A new test `tests/ticket-scripts/test-working-discipline.sh` pins: the file exists; it carries both rules and the boundary sentence; the hook names the file; `implementer-prompt.md` names it; the hook stays within its byte budget.

## Part B: fence-aware `task-brief`

`skills/gaspol-parallel/scripts/task-brief` extracts one `### Phase` block. Today the block ends at the next `### ` heading or the first `---` line, and `### Phase` headings are counted wherever they appear. Both ignore fenced code, so a plan that quotes a template (as IDS-23's own Phase A does) is cut short, and a quoted `### Phase` shifts every later phase number.

Change:

- Track ``` and ~~~ fences. A `### ` heading or `---` inside a fence does not end the block, and a `### Phase` inside a fence is not counted.
- A fence that is still open while the block is being captured, with a later heading hidden by it, makes `task-brief` refuse with exit 4 and a message naming the line the fence opened on. Handing an implementer several phases as its requirements is worse than refusing.
- A stray fence at the end of a plan that hides no heading leaves the brief complete: write it and warn on stderr.
- The stdout contract (the written path, nothing else) and exit 2 for usage errors are unchanged. The `## Verification commands (from the plan header)` section from IDS-23 is unchanged, and a legacy plan's brief stays byte-identical.
- `test-task-brief.sh` gains cases: a `---` inside a fence, a `### Phase` inside a fence, an unclosed fence (exit 4), a trailing stray fence (written, warning). `verification-lint` already ignores fenced code, and a test asserts the lint and `task-brief` agree on the same fixture.

## Part C: brainstorm asks only when the answer changes the result

Edit `skills/gaspol-brainstorm/SKILL.md` Phase 1 and the Phase 5 wording, and move the long detail to `references/phase-detail.md`.

- A clarifying question is asked only when its answer would change what gets built **and** neither the request, the project's `CLAUDE.md` nor the knowledge store answers it. Otherwise state the choice and the reason as a proposal the owner can correct, and move on.
- Process steps are never questions: where files go, whether to look further, how to present something. Do them and say so.
- "Offer recon" becomes "do recon": look, then say what was looked for and found.
- **What does not change.** Every question that IS asked still uses `AskUserQuestion` with selectable options, one at a time. The HARD-GATE, the Batch Gate, the three paths, the design approval before any code, and the builder check are untouched. This reduces which questions are asked, never whether approval is needed.
- The body must end at or under its current size: `gaspol-brainstorm/SKILL.md` has 360 bytes of headroom, so any added sentence is paid for by moving detail into `references/`. `test-skill-trim-brainstorm.sh` keeps pinning the gates, and a new pin covers the rule's condition and its consequence.

## Order

Part B first (smallest, self-contained, closes known debt), then Part A, then Part C (it touches the tightest file), then the release phase: version 1.34.0 in `plugin.json`, the `CLAUDE.md` footer and README, a `CLAUDE.md` section for IDS-24, and the matching `gaspol-one` README row and `marketplace.json` (committed and pushed only on the owner's say-so, as in IDS-23).

## What each part gives up

- **Part A is model judgement, not a machine check.** Nothing detects a drive-by edit. It is a stated rule and a test that the text exists, not that it was obeyed. The hook grows by about 350 bytes in every session.
- **Part C can under-ask.** An agent that wrongly decides a question "does not change the result" builds on a guess. The cost is stated here; the mitigation is that a guess is written down as a proposal the owner can correct, and the design approval gate remains.
- **Part B refuses a plan with an unclosed fence** that hides a heading. That is intended, and the message says how to fix the plan.
- **Headroom stays thin.** Every trimmed skill sits within about 130 bytes of 18,000, and two sit within 21.

## Not closed

- Whether agents actually obey Part A or Part C is not measured. `tests/pressure` and `tests/skill-triggering` are stochastic; a baseline comparison against `main` is the only honest read, as in IDS-23.
- The other IDS-23 open debts (`verification-lint` Minor 3 to 6, `gaspol-plan` Phase D Minors, the REAL/PLACEHOLDER rows living only in a reference) are not part of this ticket.
- Simplicity First stays out. If the owner wants a limited form, a new ticket decides it against the Ladder.
