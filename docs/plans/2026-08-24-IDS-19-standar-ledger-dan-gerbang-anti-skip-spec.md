**Ticket:** IDS-19

# IDS-19 — The ledger standard, and the machine that notices it is missing

## Design

### The complaint

Two items, reported together, ruled **one ticket** by the Batch Gate: same subsystem (the
progress ledger), and the combined plan does not exceed the phase threshold.

1. The ledger written during IND-117 (a consumer project) is the shape the owner wants as
   standard: a checkbox per *step*, not per *phase*, plus narrative sections recording
   baseline state, mid-run decisions, real commit SHAs, and the debt deliberately left open.
   The gaspol template produces none of that.
2. Ledger creation "sering ke-skip" — it gets skipped often.

### The evidence, measured rather than assumed

Across all 18 IDS tickets in this repository:

| Tickets | plan file | ledger file |
|---|---|---|
| IDS-3, IDS-5, IDS-9, IDS-15 | absent | **absent** |
| the other 14 | present | present |

The correlation is exact, and it names the cause: **the ledger has exactly one creator** —
`gaspol-plan` step 7 (`skills/gaspol-plan/SKILL.md:105`). Every path that reaches code without
passing through `gaspol-plan` produces no ledger at all:

- `gaspol-debug` — bug reports route straight here and never see a plan.
- `gaspol-brainstorm`'s **bounded** path — stops at in-chat approval, writes no spec and no plan
  by design.
- Direct edits with no skill invoked.

And nothing, anywhere, checks that a ledger exists. `gaspol-execute` Step 3 carries an
"Initialize only as a fallback" branch, but that branch only runs when `gaspol-execute` was
invoked from a plan — the case where a ledger already exists.

**One live bug follows directly.** `gaspol-debug` Phase 4 step 1 instructs the agent to write a
`regression-test:` line *into the ledger*, and `skills/gaspol-debug/scripts/regression-gate`
reads that line. On the debug-only path there is no ledger to write it into, so
`regression-gate` returns exit 3 (UNKNOWN — ledger unresolved) as its normal outcome on the very
path it was built for.

**This is the seventh instance of the same defect shape in this repository**: a rule stated in
prose, with nothing that reads the record the rule is supposed to produce. IDS-7 (a design gate
never wired up), IDS-8 (a setting nothing read), IDS-12 (execute only read code, never ran it),
IDS-13 (a Live App Check with no detector), IDS-14 (a regression test nobody had to defend
skipping), IDS-18 (a spec pointer with zero readers).

### Precedent applied (knowledge store, Phase 0.5)

Three notes surfaced and all three were applied rather than overridden:

- `machine-checkable-escape-hatch-closure` — a prose rule with no machine reading its output
  degrades into a silent default. The fix is a three-state contract plus a deterministic script
  that BLOCKS when no state is recorded.
- `ledger-states-require-non-empty-reasons` — `N/A` and `not run` count as satisfied only with an
  actual reason after the dash. A bare label is `(if possible)` wearing a new name.
- `worktree-ledgers-are-ephemeral` — `.gaspol/` is gitignored, so a ledger dies with its
  worktree. Copy it to the main checkout **before** `git worktree remove`, never after.

---

## Part A — the ledger template

### What changes

`## Checklist` becomes one sub-block per phase instead of one line per phase. Its content is
**copied from the plan**, not authored fresh.

This is possible with no new work because `gaspol-plan`'s per-phase template
(`skills/gaspol-plan/SKILL.md:217-238`) already produces both halves:

- a numbered `**Steps:**` block, whose step 1 is the mandatory TDD line and whose last step is
  the commit;
- a `**Verification:**` block **already written as `- [ ]` checkboxes**, with the commands filled
  in from `detect-stack` output.

So the ledger's phase block is the plan's `Steps` rendered as checkboxes, followed by the plan's
`Verification` block verbatim:

```markdown
## Checklist

### [>] Phase A: signature optional
- [x] Write failing test for e-POD with no signature. Expected error: `400 signature is required`
- [x] Run test, confirm it fails for the expected reason
- [ ] Remove the `if (!signature)` gate
- [ ] Run all tests, confirm they pass
- [ ] Commit
- [ ] `npx tsc --noEmit` passes
- [ ] `npx jest` passes
- [ ] No placeholder/TODO comments in new code

### [ ] Phase B: surat jalan PDF without the signature block
- [ ] ...
```

The four state markers move to the phase heading (`### [>] Phase A`) so phase status still reads
at a glance. The marker set is unchanged: `[ ]` todo / `[>]` doing / `[x]` done / `[~]` cancelled
with a mandatory reason.

**Consequence, stated rather than discovered later:** ledger quality is now bound to plan
quality. A plan whose Steps are lazy produces a lazy ledger. That is the intended coupling — the
alternative (a fixed generic checkbox set) can never produce a box like *"RED seen: `'   '` plus
a signature stores `''`, expected `null`"*, because that box is specific to one phase of one
ticket.

### The four mandatory sections

Added **above `## Log`**, never below it.

| Section | Content | Why mandatory |
|---|---|---|
| `## Pre-flight` | a table of gates checked before Phase A: git clean, baseline test run green or red, infra up | a red baseline nobody recorded gets blamed on the new phase, and the fix loop burns its rounds on somebody else's failure |
| `## Decisions taken during the run` | each mid-run choice, who decided it, and the date | the only record of what is neither in the plan nor in the code |
| `## Phase log` | a table of phase → status → real commit SHA | a SHA can be re-checked; the word "DONE" cannot |
| `## Utang terbuka` (open debt) | what was deliberately left undone, each item named | what is not written down becomes a "nanti" that never arrives |

Everything else IND-117's ledger grew — evidence-quality notes, open items for a later phase, the
plan-verifier round table, post-run gates, deploy steps, leftovers found after close — is
**added when it has content**, never as an empty heading. Nine mandatory sections would be filled
with "N/A", and per `ledger-states-require-non-empty-reasons` an empty label is worse than no
section: it reads as *checked and clear*.

### The structural rule that does not change

`## Log` stays the last block in the file. `scan-active-ledgers` reads the file's last non-empty
line to decide active-vs-done; anything appended below `## Log` breaks that detection. The new
`###` sub-headings sit **inside** `## Checklist`, above `## Log`, so the existing behaviour is
untouched.

---

## Part B — the machine that notices a missing ledger

Two halves, because neither works alone: a script cannot create a ledger, and a second creator
cannot see the paths it does not own.

### B1 — the second creator

`gaspol-debug` creates the ledger at Phase 1 when none exists, in the Part A format. This also
closes the live `regression-gate` exit-3 bug described above: the file its Phase 4 line is
written into now exists on the debug path.

The ticket for a debug-path ledger is minted the same way `gaspol-brainstorm` Phase 6 mints one —
`skills/gaspol-execute/scripts/next-ticket` against the target project's CLAUDE.md — and the
Batch Gate that `gaspol-debug` already reads decides how many tickets that batch of reported
defects is worth. No second counter, no second batching rule.

### B2 — the gate

New script `skills/gaspol-verify/scripts/ledger-gate`, stdlib-only shell, with the exit contract
`spec-pointer` and `kb-root` already use.

Ticket resolution, in order — deterministic, never inferred by a model:

1. a `**Ticket:**` line in a plan file present in the branch diff;
2. failing that, a `[A-Z]+-[0-9]+` pattern in the current branch name;
3. failing that, no ticket.

| Exit | State | Treatment |
|---|---|---|
| 0 | ledger found at `.gaspol/progress/PROGRESS-<TICKET>.md`, structurally valid | pass |
| 1 | ticket resolved, ledger **absent**, and the branch carries code commits | **BLOCKING** |
| 3 | ledger present but malformed — no `## Checklist`, or a block below `## Log` | **UNKNOWN — STOP and ask** |
| 4 | no ticket resolved anywhere, **or** the branch carries no code commits | **not a failure** — caller records `ledger: N/A — <reason>` |

Exit 4 covers two distinct situations on purpose, and the reason line is what tells them apart:
unticketed work (`N/A — no ticket on this branch`) and ticketed work that changed no code
(`N/A — docs-only branch, no code commits`). They are not merged because they read differently to
whoever audits the line later, and splitting them into separate exit codes would buy a distinction
no caller acts on differently.

**"No code commits" needs a definition, or it becomes the loophole this ticket exists to close.**
A commit counts as a code commit unless every path it touches is in the ignore list, which is
exactly the list `blast-radius-diff` already carries and is reused rather than re-invented:
`.gaspol/`, `docs/plans/`, `CLAUDE.md`, and lockfiles.

Markdown is **not** on that list, and that is deliberate rather than an oversight. In a skills
repository a `skills/*.md` file IS the executed surface — the same reasoning CLAUDE.md records for
why `/security-review` was worth running on markdown diffs. A rule that let markdown count as
"docs" would hand this repository a permanent exemption from its own gate.

**Exit 4 is what keeps this gate alive.** Without it, every typo fix on an unticketed branch gets
blocked, the gate cries wolf, and somebody switches it off — the exact reasoning that made
`blast-radius-diff` a WARN rather than a BLOCK. The reason after the dash is mandatory, per
`ledger-states-require-non-empty-reasons`.

**Exit 3 is deliberately not merged into exit 1.** A malformed ledger must never degrade to
"missing", and must never degrade to "fine": a ledger with a block below `## Log` still exists,
so `scan-active-ledgers` will read the wrong line and report the ticket's state incorrectly —
worse than an absent file, which at least reports nothing.

### Where it is wired

`gaspol-verify` Layer 1, beside the existing `detect-stack` and `regression-gate` calls, invoked
as `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/ledger-gate"` — the anchored form, never a
relative path. `tests/ticket-scripts/test-kb-no-hardcoded-path.sh` is widened to cover it, the
same way IDS-18 widened it from `kb-root` alone to three scripts.

Deliberately **not** also wired into `gaspol-execute` Step 0. `gaspol-verify` runs before every
merge on the `gaspol-finish` path, so nothing reaches main unchecked, and adding a gate to the
most frequently invoked skill in the plugin is the opposite direction from this ticket.

---

## File Integration Map

| Change | File | Exists? | Action |
|---|---|---|---|
| Ledger template (Part A) | `skills/gaspol-plan/SKILL.md` "Progress Ledger Format" | yes | rewrite the template block; add the four mandatory sections |
| Ledger creation at plan-write | `skills/gaspol-plan/SKILL.md` step 7 | yes | copy Steps + Verification per phase instead of one line per phase |
| Fallback initializer | `skills/gaspol-execute/SKILL.md` Step 3 | yes | point at the new format (it already defers to gaspol-plan's section) |
| Second creator (Part B1) | `skills/gaspol-debug/SKILL.md` Phase 1 | yes | new step: create the ledger if absent |
| The gate (Part B2) | `skills/gaspol-verify/scripts/ledger-gate` | **no** | new script, stdlib shell, with `--self-test` |
| Gate wiring | `skills/gaspol-verify/SKILL.md` Layer 1 | yes | add the anchored invocation and the recorded `ledger:` line |
| Anchored-path gate | `tests/ticket-scripts/test-kb-no-hardcoded-path.sh` | yes | widen to include `ledger-gate` |
| Gate tests | `tests/ticket-scripts/test-ledger-gate.sh` | **no** | new: all four exit states, plus the malformed cases |
| Template tests | `tests/ticket-scripts/test-ledger-template.sh` | **no** | new: assert the four mandatory section names and the `## Log`-is-last rule survive |
| Docs | `CLAUDE.md` | yes | new section; Architecture table rows; version bump |

No placeholder is required anywhere: every consumer named above exists in the repository today.

## Edge cases enumerated

| Case | Behaviour |
|---|---|
| Branch name has no ticket pattern and no plan in the diff | exit 4, caller records `ledger: N/A — <reason>` |
| Branch name carries a ticket but the work is docs-only | exit 4 with `N/A — docs-only branch, no code commits`. Exit 1 fires only when code commits exist |
| Two plans in the diff naming different tickets | STOP and ask which — never pick the first silently |
| Ledger exists at the legacy path (`.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md`) | resolved and accepted; backward compatibility is unchanged |
| `.gaspol/progress/` does not exist at all | same as ledger absent — exit 1 or 4 by the ticket rule, never a crash |
| Ledger exists but is empty (0 bytes) | exit 3 malformed, not exit 0 |
| Phase cancelled `[~]` with no reason on the line | the template test catches it; this is the existing rule, restated not invented |
| Worktree removed before the ledger is copied back | out of scope for the gate (the file is simply gone); the `worktree-ledgers-are-ephemeral` precedent is written into `gaspol-worktree`'s teardown prose as a reminder |

## What this does NOT close — named so the deferral cannot be mistaken for completion

- **The gate checks existence and shape, never honesty.** A checklist ticked without the work
  being done passes exit 0. This closes the silent-skip hole, not the recorded-but-false hole —
  the same boundary `machine-checkable-escape-hatch-closure` states explicitly.
- **The bounded brainstorm path still creates no ledger.** It creates no ticket either, so it
  lands on exit 4 and is recorded as `N/A` rather than blocked. Making bounded work mint a ticket
  is a different, unrequested change to the path's whole purpose.
- **`.gaspol/` stays gitignored.** The ledger remains invisible to `git status` and still dies
  with a worktree. Tracking it in git is a separate decision with its own merge-conflict cost,
  and is not taken here.
- **No back-fill.** IDS-3, IDS-5, IDS-9 and IDS-15 stay ledger-less. A ledger written months
  after the fact is fiction, and fiction in the record is worse than an admitted gap.
