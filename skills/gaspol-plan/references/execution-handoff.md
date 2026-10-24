# Execution handoff: detail

`SKILL.md` states the post-plan offer and the non-empty skip-reason rule. This file holds the reasons, the artifact notes and the external executor.

`gaspol-auto` is offered on **every** plan. It is a documented execution mode that this skill
previously never surfaced, so the only way to reach it was to already know it existed. Its own
pre-flight gate — plan approval, clean git state, a passing baseline, the per-phase TDD check — is
unchanged and still refuses to start when any of those fail. Those are `gaspol-auto`'s refusals to
run, not reasons to hide the door.

**What the artifact contains** is the tab-count rule in
`skills/gaspol-plan/logic-design-artifact.md`: the Logic tab always, plus a Design tab holding the
mockup when the plan touches UI files. That file also carries the page skeleton to copy, the
`srcdoc` escaping rule, and the requirement that the prose is plain Indonesian.

**`ui-ux-pro-max` is invoked at most once per ticket.** Where `gaspol-brainstorm` Phase 3 already
ran, its design decisions are reused here and the skill is not called again. Where brainstorm never
ran and the plan touches UI, this is the single point it is called.

Follows "An empty reason is refused: ask again.":

A bare label with nothing after the dash documents the wish
to skip without documenting why skipping was acceptable, which is the escape hatch this repository
has already had to close once elsewhere.

Follows "Nothing was skipped, because nothing executed":

and demanding a justification for a decision the user has not yet made teaches people to type
anything to get past the prompt.

**The cost of that, stated rather than glossed:** this offer exists only here. A later session that
resumes the plan through `gaspol-execute` will not be asked again — it reads a ledger with no line,
proceeds, and records `design-artifact: none — no offer was made`. Re-entering `gaspol-plan` for
that plan is the only way to reach the offer a second time.

### Recording an approved artifact

When `[Render design artifact dulu]` is chosen and the artifact is approved, record it in **two**
places:

- `**Artifact:** <url>` in this plan file's header, beside `**Ticket:**` / `**Ledger:**`
- `design-artifact: approved — <url>` in the ledger, above `## Log`

| Ledger line | What `gaspol-execute` does |
|---|---|
| `design-artifact: approved — <url>` | proceed |
| `design-artifact: pending — <url>` | **STOP and ask** — published, never approved |
| `design-artifact: skipped — <reason>` | proceed |
| no line | proceed, recording `design-artifact: none — no offer was made` |


### `[Serahkan ke executor luar]` — shown only when an executor is configured
> "Hand off to your external executor? I'll run `<resolved command>` — it implements **blind** from this self-contained plan and its per-plan ledger, then you return here for review + commit."

This is the two-lane, token-saving path: planning + review stay in this session; the heavy codegen runs in a separate, cheaper executor process. **gaspol-dev ships no executor of its own** — this option surfaces a command *you* wired up, and never invents one.

**Resolving the executor command (in order, first hit wins):**
1. `$GASPOL_EXECUTOR` environment variable.
2. First line of a `.gaspol/executor` file in the project root (lets a repo commit its own executor).
3. **Neither set → leave this option out of the modal entirely.** The plugin works fully with the
   in-session options above; there is nothing to configure to use it.

The value is a **command template** with `{plan}` and `{ledger}` placeholders, e.g. `aider --file {plan}`, `opencode run {plan}`, `cursor-agent {plan}`. Substitute the plan path and the resolved per-plan ledger path, then present the concrete command for approval before running.

**Invariants regardless of executor:** the external tool implements + runs tests to green but **NEVER commits/pushes** — the finished diff returns to this session (or the human) for review + commit. Review is never skipped.
