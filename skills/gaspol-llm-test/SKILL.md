---
name: gaspol-llm-test
description: Use when implementing AI/LLM/prompt-driven features (classification, extraction, generation, agents, RAG, summarization) where behavior is non-deterministic and ordinary unit tests miss regressions. Defines capability + regression evals with pass@k metrics. Complements gaspol-tdd — it does not replace it.
---

# gaspol-llm-test

Eval-driven development (EDD) for non-deterministic features. Where `gaspol-tdd`
gives RED-GREEN-REFACTOR for deterministic code, `gaspol-llm-test` gives capability and
regression **evals** for behavior you cannot assert with a single `expect(...)`.

> Ported and adapted from the ECC `eval-harness` skill (MIT, Affaan Mustafa).
> Eval definitions live in the project (`docs/evals/`), not the cross-project KB —
> regression baselines are codebase-specific.

## Core Principle

```
DEFINE EXPECTED BEHAVIOR BEFORE IMPLEMENTATION — EVALS ARE THE UNIT TESTS OF AI WORK
```

For LLM/prompt features: define pass/fail criteria up front, run them continuously,
track regressions per change, and measure reliability with pass@k. A feature that
"looks right once" is not verified — a flaky prompt passes once and fails the next call.

## Announce at Start

> "I'm using the gaspol-llm-test skill to define and run evals for this non-deterministic feature."

## When to Activate

- LLM-driven classification, extraction, generation, summarization, or routing
- Prompt or agent changes (a prompt edit is a behavior change with no compiler to catch regressions)
- RAG pipelines, tool-use agents, LLM-as-judge flows
- Measuring agent reliability across model versions (e.g. Sonnet → Opus)

## Boundary vs gaspol-tdd (read this first)

| Situation | Skill |
|---|---|
| Deterministic logic, pure functions, API contracts, DB queries | `gaspol-tdd` (RED-GREEN-REFACTOR) |
| Non-deterministic LLM/prompt output, agent behavior, ranking quality | `gaspol-llm-test` (capability + regression evals) |
| A feature with BOTH (e.g. an endpoint that calls an LLM) | **both** — tdd for the deterministic shell, eval for the LLM behavior |

`gaspol-llm-test` does NOT replace `gaspol-tdd`. Pure-logic code still goes through TDD.

## Eval Types

### Capability evals — can it do the thing?
```markdown
[CAPABILITY EVAL: ticket-classifier]
Task: classify a support email into one of {billing, bug, feature, other} and draft a reply
Success Criteria:
  - [ ] Returns exactly one valid category
  - [ ] Category matches the labeled gold set on ≥ N fixtures
  - [ ] Draft reply addresses the ticket's actual question
Expected Output: { category, draft }
```

### Regression evals — did a change break what worked?
```markdown
[REGRESSION EVAL: ticket-classifier]
Baseline: <git SHA or checkpoint>
Tests:
  - billing-fixture-1: PASS/FAIL
  - bug-fixture-2:     PASS/FAIL
Result: X/Y passed (previously Y/Y)
```

## Grader Types

1. **Code-based grader (default, prefer this)** — deterministic checks: exact category
   match against a gold set, JSON-shape validation, `grep`/test assertions. Deterministic > probabilistic.
2. **Model-based grader (LLM-as-judge)** — for open-ended output (reply quality, tone):
   a scoring prompt (1–5 + reasoning). Use when no code grader exists. Keep the rubric explicit.
3. **Human grader** — flag HIGH-risk / ambiguous outputs for manual review. Never fully
   automate security-relevant judgments.

## Metrics

- **pass@k** — at least one success in k attempts (`pass@1` = first-try rate; `pass@3` common target > 90%).
- **pass^k** — all k trials succeed (higher bar; use for critical paths / regression = `pass^3` 100%).

Because output is non-deterministic, run each eval multiple times and report pass@k —
not a single pass/fail.

## Eval Workflow

### 1. Define (BEFORE coding) — at plan time
Write `docs/evals/<feature>.md`:
```markdown
## EVAL DEFINITION: <feature>
### Capability Evals
1. ...
### Regression Evals
1. ...
### Success Metrics
- pass@3 > 90% for capability evals
- pass^3 = 100% for regression evals
### Fixtures
- path to gold-set / fixture data (real examples, not invented)
```

### 2. Implement
Write the feature to pass the defined evals.

### 3. Evaluate — at verify time
Run each eval k times, record PASS/FAIL per attempt, compute pass@k.

### 4. Report
```markdown
EVAL REPORT: <feature>
Capability:  3/3 passed (pass@3: 100%)
Regression:  3/3 passed (pass^3: 100%)
Status: READY / NEEDS WORK
```

## Eval Storage

```
docs/evals/
  <feature>.md        # eval definition (capability + regression + fixtures)
  <feature>.log       # run history (pass@k over time)
  baseline.json       # regression baselines (per-fixture expected results)
```

Reusable eval *patterns* (e.g. "LLM-judge rubric for reply tone") can be captured to
the cross-project KB via `gaspol-learn`; project-specific definitions/baselines stay in `docs/evals/`.

## Best Practices

1. Define evals BEFORE coding — forces clear success criteria.
2. Use real fixtures (a gold set of actual examples), never invented data. Per the
   Iron Laws, an invented fixture is a placeholder — STOP and ask for real examples.
3. Prefer code graders; reserve model graders for genuinely open-ended output.
4. Keep evals fast — slow evals don't get run.
5. Run multiple trials and report pass@k — a single pass hides flakiness.
6. Version evals with the code — they are first-class artifacts.

## Integration

- **Triggered by:** intent involving LLM/prompt/agent behavior (non-deterministic features).
- **`gaspol-plan`:** for an LLM-feature phase, define evals (`docs/evals/<feature>.md`)
  as part of planning — the eval definition is the success contract.
- **`gaspol-verify`:** run the evals as an evidence step (alongside build/test/lint);
  report pass@k. A claim of "the LLM feature works" needs eval evidence, not a single demo.
- **`gaspol-tdd`:** complementary — TDD for deterministic parts, eval for the behavior.
- **`gaspol-learn`:** captures reusable eval patterns to KB post-ship.
- **Type:** flexible skill (adapt the eval design to the feature).

## Example: LLM ticket classifier

```markdown
## EVAL: ticket-classifier
### Capability
- [ ] Returns one of {billing, bug, feature, other}
- [ ] ≥ 90% category match on the 50-ticket gold set (pass@3)
- [ ] Draft reply references the ticket's actual question (LLM-judge ≥ 4/5)
### Regression
- [ ] Previously-correct fixtures still classified correctly (pass^3)
### Status after run: Capability 3/3 (pass@3 100%), Regression PASS → SHIP
```
