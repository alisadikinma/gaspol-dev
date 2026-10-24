# Model Rule — two tiers, and a machine that reads them

**This is a rule, not a preference.** It was an "auto-rubric to choose from" until IDS-20, and in
that form it drifted from what it was supposed to say in **ten** places — including four reviewer
prompt files and a sentence instructing an override to a tier nobody had used deliberately in
months. A rubric you choose from is a rubric that drifts.

```text
Opus   MUST be used for brainstorm, plan, verify, review, and anything that
       JUDGES finished work.
Sonnet MUST be used for execution: implement, test, refactor, sync docs,
       rename, capture, gather.
```

**Two tiers. There is no third.** The main orchestrator session stays on Opus, unchanged: it
decides which skill runs and when to stop, which is judgement.

Enforced by `skills/gaspol-verify/scripts/model-gate`, invoked from `gaspol-verify` Layer 1.

## The Rule Table

| Task Kind | Model | Why this tier |
|-----------|-------|---------------|
| Main orchestrator (current session) | `opus` | decides what runs and when to stop — judgement |
| Architecture planning | `opus` | trade-off evaluation with no single right answer |
| Brainstorming (`gaspol-brainstorm`) | `opus` | design choices, and the questions worth asking |
| Implementation planning (`gaspol-plan`) | `opus` | decides coverage; what the plan omits, nothing downstream recovers |
| Verification (`gaspol-verify`) | `opus` | reads evidence and rules on whether it proves the claim |
| Spec review (`spec-reviewer`) | `opus` | architectural judgement |
| Plan fidelity audit (`plan-verifier`) | `opus` | evidence-based, step-level, and BLOCKING |
| Code review (`code-reviewer`) | `opus` | **changed in IDS-20.** Was `sonnet`, justified as "pattern matching / style check". A review that judges wrongly produces a wrong fix, which costs more than the model does |
| Refutation pass (`gaspol-review`) | `opus` | argues against a finding — judgement by another name |
| Refactor for clarity (`code-simplifier`) | `opus` | **changed in IDS-20.** A refactor that must preserve behaviour can introduce a silent regression |
| Complex debugging (systematic root-cause) | `opus` | hypothesis branching, non-linear |
| Research synthesis | `opus` | cross-source consolidation and reasoning |
| Autonomous orchestration (`gaspol-auto`) | `opus` | hard-stop decisions |
| Feature implementation | `sonnet` | execute a well-defined task |
| Test writing | `sonnet` | mechanical but precise |
| Research gathering (per-source) | `sonnet` | fetch and summarise one source |
| ADR capture (`gaspol-adr`) | `sonnet` | structured template filling |
| Design system reasoning | `sonnet` | apply rules, match templates |
| Documentation sync (`gaspol-sync-docs`) | `sonnet` | **was `haiku` until IDS-20** — see below |
| Simple refactor / rename / format | `sonnet` | **was `haiku` until IDS-20** — see below |
| Simple fact lookup | `sonnet` | **was `haiku` until IDS-20** — see below |

## The third tier was removed, not forgotten

The last three rows above ran on `haiku`. That tier is **deleted**, and the three rows are kept
rather than dropped so the next reader can tell a decision from an oversight.

**What that costs, said plainly:** documentation sync, renames and light lookups are now more
expensive than they strictly need to be. **What it buys:** a boundary nobody has to guess at. A
three-tier rubric with a fuzzy middle makes people guess, and a wrong guess costs more than the
price difference. The alternative was a gate carrying an exception list, and an exception is how a
gate stops working — the reason `tests/ticket-scripts/test-gate-mutations.sh` exists.

`model-gate` treats `haiku` as **exit 1 BLOCKING**, never "unknown". It is not an unrecognised
tier; it is a deleted one, and reporting it as unknown invites a case-by-case exemption. This file
is the one place allowed to name it, and only to record that it is gone.

## Which concrete models the aliases mean

Skills and agent frontmatter use the **short aliases** `opus` and `sonnet`, which point at the
current member of each family.

As of **2026-08-24**:

| Alias | Concrete model |
|---|---|
| `opus` | `claude-opus-5` |
| `sonnet` | `claude-sonnet-5` |

**Why aliases rather than pinned ids.** Pinning `claude-opus-5` across a dozen files means a dozen
edits every time a model ships, and the file somebody forgets silently keeps the old model — the
promise-with-no-implementation shape this repository has now undone seven times.

**What that gives up, and it is real:** if `opus` ever resolves to a *weaker* model, **nothing
tells you.** The table above is a dated record a human can check, not a mechanism. It is not a
guarantee and must not be described as one. If the mapping ever stops holding, this table is what
should be corrected first.

## How to Apply

### In skill dispatch

```
Agent({
  description: "Code review task",
  prompt: "...",
  subagent_type: "code-reviewer",
  model: "opus"   // judging surface — the rule, not a preference
})
```

### In agent frontmatter

```yaml
---
name: code-reviewer
description: ...
model: opus
---
```

### When the tier is not obvious from the name

`model-gate` reads the tier from the file path (`reviewer`, `verifier`, `simplifier`, `refuter` →
judging; `implementer` → execution), falling back to the same line. A file it cannot classify
declares its own tier:

```markdown
<!-- model-tier: exec — gathering is execution: each subagent fetches and summarises one source -->
```

Use it rather than renaming a file to satisfy a pattern. `skills/gaspol-research/SKILL.md` carries one.

### Override precedence

1. Explicit `model` param in the Agent tool call (highest)
2. The agent's frontmatter `model` field
3. Inherited from the parent session (fallback)

**An override that drops a judging task below Opus, or raises an execution task above Sonnet,
MUST carry a written reason at the call site.** Not a ticket number, not a shrug — a sentence
saying why this case is different. A silent override is how a rule becomes advice again, which is
exactly the state this file was in before IDS-20.

## What this rule does NOT do

- **It governs declarations, never what actually ran.** `model-gate` reads what the files say. If
  the harness ignores the field, every check here still passes. This closes the drift hole, not
  the execution hole.
- **It cannot see the main session's own model.** gaspol has no way to read or change it. The rule
  states the expectation and stops there.
- **A tier violation written as prose is invisible to the gate.** The tier check only matches
  `model:` followed by a model name; widening it to every sentence would flag correct writing
  *about* the rule, and a gate that fires on its own documentation is one somebody switches off.
