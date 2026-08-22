**Ticket:** IDS-11

# Drop gaspol-write-skill, gaspol-kb-audit and gaspol-llm-test, rescue their rules

## Why

The plugin is being narrowed to the coding path. Three of the twenty skills earn their removal on
their own evidence, not on a general wish for fewer files. (`gaspol-llm-test` was added to the
scope mid-ticket, on the Batch Gate's own reasoning: same job, same subsystem, one ticket.)

**`gaspol-kb-audit`** — CLAUDE.md already records, from IDS-8, that this skill *"now overlaps
`superbrain-promote` almost completely — both are scan → cluster → per-finding human decision →
apply → audit log."* It was kept then for one reason only: *"they are not like-for-like: one is
public and agnostic, the other private and hardcoded to one vault."* That reason was about keeping
gaspol usable by strangers. For an owner narrowing gaspol to their own coding loop, it no longer
holds. 12K, invoked quarterly at most.

**`gaspol-write-skill`** — 80K across 4 files, the largest skill in the repo, and it fires only when
authoring a skill. Removing it is straightforward **except for one thing that must not go with it.**

## The one thing that must be rescued

`gaspol-write-skill` **Step 0: Prior-Art Search (BLOCKING)** is not a skill-authoring rule that
happens to live there — it is the plugin's only "look before you build" gate, and two other live
skills reference it by name:

| Referrer | Line | What it defers |
|---|---|---|
| `gaspol-brainstorm` Phase 1.5 (`NEW` branch) | 210 | *"the install rules live in gaspol-write-skill Step 0 and apply here unchanged"* |
| `gaspol-research` gather lane 6 | 103 | the same install rules |

Deleting the file leaves two live references pointing at nothing. Worse, the block carries the
plugin's **only** supply-chain rules for installing third-party skills: never `npx skills add -y`,
read the candidate's SKILL.md first, install count is popularity not an audit, every installed skill
is a permanent per-session context tax. A skill is a prompt that runs inside your agent; those rules
are the only thing standing between a curious search and an unread prompt with tool access.

**Resolution:** extract Step 0 to `skills/_shared/prior-art-gate.md` before the deletion, and
generalise its framing. Bound to skill-authoring it dies with its host; stated as *"nothing gets
built in-house before somebody looks whether it already exists"* it applies to every build decision
— which is also `gstack/ETHOS.md` §2, "Search Before Building". Roughly 3K of the 80K survives.

## What else must be repointed, not dropped

**Promotion of KB entries.** `gaspol-learn` states *"user promotes to `accepted` via gaspol-kb-audit
after validation"*, and `gaspol-adr` / `gaspol-research` name it as the thing that flags stale
entries. gaspol only ever writes `status: proposed`; promotion is the human gate. With the audit
skill gone the gate must be named as what it actually is — `superbrain-promote` in the owner's
vault — and where no vault is configured, the skills must say promotion is manual and leave the
entry `proposed`. A promotion path that silently points at a deleted skill is worse than none: it
reads as "handled".

**The health thresholds.** CLAUDE.md documents *"🔴 Red >25% stale → mandatory audit blocks new
captures"*. Nothing will implement that after the deletion. It goes, rather than standing as a rule
with no enforcer — the promise-with-no-implementation shape IDS-8 and IDS-7 were both about.

## `gaspol-llm-test` — added mid-ticket

8K, and only two of its thirteen references actually do anything: `gaspol-plan:272` tells the
planner to write `docs/evals/<feature>.md` for non-deterministic work, and `gaspol-verify:120` runs
those evals as evidence. Both are conditional on the feature being non-deterministic.

The skill goes; **the rule stays inline in both places.** Unit tests miss LLM regressions — that
fact is not a function of whether a skill file exists. `test-finish-gates.sh` had an assertion that
the skill's file was present (left over from a v1.14 rename); it now asserts the RULE survives in
both referrers instead. Asserting a file exists tests the filesystem; asserting the rule survives
tests the thing that mattered.

## Explicitly NOT in scope

`gaspol-research`, `gaspol-adr`, `gaspol-learn`, `using-gaspol`, `gaspol-receive-review` stay. The knowledge base keeps its
writers, so `gaspol-brainstorm` Phase 0.5 keeps reading a store that still fills. `using-gaspol`
especially stays: it is the auto-trigger backbone the session hook loads, and removing it would make
the coding skills fire *less* often, which is the opposite of narrowing to coding.

## Definition of done

- No live file references either deleted skill.
- The Prior-Art Gate survives at `skills/_shared/prior-art-gate.md`, with both referrers repointed,
  and its install rules intact word for word.
- KB promotion names a gate that exists, and says so honestly when none is configured.
- Skill count is 17 everywhere it is asserted.
- Deterministic suite green.
