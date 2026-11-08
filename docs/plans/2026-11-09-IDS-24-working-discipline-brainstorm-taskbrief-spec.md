**Ticket:** IDS-24

# IDS-24: working discipline (Karpathy) and a fence-aware task-brief (superpowers 7.0.2)

Target release: **1.34.0**. One ticket by the Batch Gate: one request, all inside `skills/`, one plan under the phase threshold.

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
| 7.0.2 brainstorming: ask only when the answer changes what gets built | `CLAUDE.md` ("Interactive Confirmation Rule") and `using-gaspol` make every question go through `AskUserQuestion`. Owner decision 2026-11-09: **keep that rule unchanged**; not adopted |
| 7.0.2 `task-brief` hardening (fence-aware headings, refuse an unclosed fence, exact ID match) | gaspol's `task-brief` cuts a phase at the first `---` line even inside a fenced code block (open debt from IDS-23, found at Phase A) | **adopt (Part B)**, it closes that debt |
| 7.0.2 hook fixes for Windows and a missing bash, OpenCode V2, Devin, Hermes, Grok support | the owner runs macOS and Claude Code only | skip |

## Part A: working discipline, always on

New `skills/_shared/working-discipline.md`, written once and read from the places below. Two rules.

1. **Surgical changes.** Every changed line traces to the request. No tidying of adjacent code, comments or formatting. Match the existing style. Remove only imports, variables and functions that **your own change** left unused. Unrelated dead code is reported, never deleted.
2. **Think before coding.** State the assumptions before writing code. When a request has two readings, name both instead of picking one silently. Say so when a simpler way exists. When confused, stop and ask through `AskUserQuestion`.

**The boundary with the Completeness Ladder is written into the file.** Surgical limits code **outside** the task; the Ladder demands depth **inside** it. The two do not conflict. Simplicity First is not in the file: the rejection is recorded in this spec and in the IDS-24 `CLAUDE.md` section, so implementers do not pay bytes for it.

Wiring, kept small because of two hard budgets:

- `hooks/session-start.sh` gains 4 to 5 lines and a pointer to the file. The hook is injected in every session (4,357 bytes today), so the addition stays under about 350 bytes.
- `skills/gaspol-execute/implementer-prompt.md` points at the file. Implementers are dispatched without the session hook's context, so they need the pointer.
- **No SKILL.md body is touched for Part A.** `gaspol-execute` has 9 bytes and `gaspol-plan` 21 bytes under the 18,000 ceiling, so a pointer there would force a trim.
- A new test `tests/ticket-scripts/test-working-discipline.sh` pins: the file exists; it carries both rules and the boundary sentence; the hook names the file; `implementer-prompt.md` names it; the hook stays within its byte budget.
- `CLAUDE.md` (the "Interactive Confirmation Rule") is **not** edited. Rule 2's "stop and ask" already goes through `AskUserQuestion`.

## Part B: fence-aware `task-brief` and `verification-lint`

`skills/gaspol-parallel/scripts/task-brief` extracts one `### Phase` block. Today the block ends at the next `### ` heading or the first `---` line, and `### Phase` headings are counted wherever they appear. Both ignore fenced code, so a plan that quotes a template (as IDS-23's own Phase A does) is cut short, and a quoted `### Phase` shifts every later phase number.

**Fence rule, one definition, used by both scripts.** A fence opens on a line that starts (after up to three spaces) with a run of three or more backticks or three or more tildes. It closes on a later line that starts with the same character, a run at least as long as the opener, and nothing after the run. A shorter or different run inside the fence is plain text. This is what lets a plan quote a template that itself contains a fence. `verification-lint` and the `HEADER_BLOCK` reader in `task-brief` currently flip a boolean on any run of three characters; both move to this rule, so the two scripts still agree on which lines are fenced, and a shared fixture proves it.

Change to `task-brief`:

- A `### ` heading or `---` inside a fence does not end the block, and a `### Phase` inside a fence is not counted.
- **Refusal, exit 1.** If a fence is still open at the end of the file and it hid a `### Phase` heading, or hid the end of the captured block, `task-brief` refuses with exit 1 and a message naming the line the fence opened on. It does this whenever the hidden heading comes before the requested phase too, not only inside the captured block, because the user would otherwise get a misleading "no phase N". Exit 1 is BLOCKING on the house contract; exit 4 means "not applicable, never a pass" and is not reused. Exit 2 stays for usage errors.
- A stray fence at the end of a plan that hid no `### Phase` heading leaves the brief complete: write it and warn on stderr.
- The stdout contract (the written path, nothing else) is unchanged. The `## Verification commands (from the plan header)` section from IDS-23 is unchanged, and a legacy plan's brief stays byte-identical.
- **Callers.** The script header and `skills/gaspol-parallel/references/process-flow.md` say: any non-zero exit means stop, do not dispatch, show stderr. `gaspol-parallel/SKILL.md` is not touched (21 bytes of headroom or less), so the rule lives in the reference that the body already points at.
- Tests: `test-task-brief.sh` gains a `---` inside a fence, a `### Phase` inside a fence, a nested fence (four backticks around three), an unclosed fence that hides a later phase (exit 1, also when an earlier phase is requested), and a trailing stray fence (written, warning). `test-verification-lint.sh` gains the nested-fence fixture, and one test runs `task-brief` and the lint on the same file and asserts they agree.

## Order

Part B first (self-contained, closes known debt), then Part A, then the release phase: version 1.34.0 in `plugin.json`, the `CLAUDE.md` footer and README, a `CLAUDE.md` section for IDS-24, and the matching `gaspol-one` README row and `marketplace.json` (committed and pushed only on the owner's say-so, as in IDS-23).

## What each part gives up

- **Part A is model judgement, not a machine check.** Nothing detects a drive-by edit. It is a stated rule and a test that the text exists, not that it was obeyed. The hook grows by about 350 bytes in every session.
- **Brainstorm question-reduction (superpowers 7.0.2) is not adopted.** Agents keep asking every clarifying question; that is more questions than superpowers asks, accepted to leave the owner's mandatory rule intact.
- **Part B refuses a plan with an unclosed fence** that hides a `### Phase` heading. That is intended, and the message says how to fix the plan. It also changes `verification-lint`'s fence rule, so a plan that passed before because a stray fence flipped its state may now be judged differently.
- **Headroom stays thin.** Every trimmed skill sits within about 130 bytes of 18,000, and two sit within 21.

## Not closed

- Whether agents actually obey Part A is not measured. `tests/pressure` and `tests/skill-triggering` are stochastic; a baseline comparison against `main` is the only honest read, as in IDS-23.
- The other IDS-23 open debts (`verification-lint` Minor 3 to 6, `gaspol-plan` Phase D Minors, the REAL/PLACEHOLDER rows living only in a reference) are not part of this ticket.
- The 7.0.2 brainstorming tuning is out, by owner decision. Simplicity First stays out. If the owner wants a limited form, a new ticket decides it against the Ladder.
