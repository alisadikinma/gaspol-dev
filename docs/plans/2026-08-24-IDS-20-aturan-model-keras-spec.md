**Ticket:** IDS-20

# IDS-20 — The model rubric becomes a rule, and the rule gets a reader

## Design

### The request

Stated by the owner, verbatim: *"perlu tambahkan rule keras bahwa model yg dipakai utk eksekusi
harus pakai sonnet 5.. klo untuk brainstorm, plan, verify, review itu pakai opus 5"*.

Two tiers, no third: **Opus for judgement, Sonnet for work.**

### Why this is a rule change and not a documentation edit

`docs/rubric-model-switching.md` opens with *"Auto-rubric untuk pilih model berdasarkan task
type"* and is referenced everywhere as advice. Nothing enforces it, nothing reads it, and it has
drifted from what the owner wants in four separate places. Verified by reading the files, not
inferred:

| Location | Today | Under the rule |
|---|---|---|
| `agents/code-reviewer.md` frontmatter | `model: sonnet` | **`opus`** |
| `agents/code-simplifier.md` frontmatter | `model: sonnet` | **`opus`** |
| `skills/gaspol-parallel/SKILL.md:318` code-quality dispatch | `model: "sonnet"` | **`"opus"`** |
| `skills/gaspol-review/SKILL.md:102` refuter | `model: Sonnet` | **Opus** |
| rubric row "Code review (code-reviewer agent)" | `sonnet` | **`opus`** |
| rubric rows for docs sync / rename / fact lookup | `haiku` | **`sonnet`** — Haiku is removed |
| `CLAUDE.md` rubric prose | "Opus **4.7**", "Sonnet **4.6**" | Opus 5, Sonnet 5 — those versions do not exist |
| `CLAUDE.md` target cost mix | "~15% Opus, ~60% Sonnet, ~25% Haiku" | two tiers, no Haiku share |

The stale version numbers matter more than they look. A rubric naming models that do not exist
reads as unmaintained, and an unmaintained rubric is one nobody consults — which is how the four
drifts above happened without anyone deciding them.

### The three decisions the owner made, and what each gives up

**1. Haiku is removed entirely. Every execution task is Sonnet.**

Two tiers are memorable and machine-checkable; three tiers with a fuzzy boundary make people
guess, and a wrong guess costs more than the price difference. What is given up, stated rather
than glossed: `gaspol-sync-docs`, rename/format, and light fact lookup become more expensive than
they strictly need to be. The alternative was a gate carrying an exception list, and an exception
is how a gate stops working — the lesson `test-gate-mutations.sh` exists to enforce.

**2. "Review" means everything that JUDGES code, five call sites.**

`code-reviewer`, `spec-reviewer`, `plan-verifier`, the refuter inside `gaspol-review`, and
`code-simplifier`. The last is the one worth defending: a refactor that must preserve behaviour
can introduce a silent regression, and the existing rubric already argued that case when it moved
`code-simplifier` off Haiku. Judging wrongly produces a wrong fix, which costs more than the
model does.

**3. Short aliases `opus` / `sonnet` in code; the full ids recorded once, in the rubric.**

The aliases already used by agent frontmatter point at the current member of each family, so
nothing needs editing when a new model ships. Full ids pinned across a dozen files would mean a
dozen edits per release, and the file somebody forgets silently keeps an old model — the
promise-with-no-implementation shape this repository has now undone seven times.

**What that gives up, and it is real:** if an alias ever resolves to a weaker model, nothing tells
you. The mitigation is not a mechanism, only a record: `docs/rubric-model-switching.md` states
which concrete ids the aliases mean **today** (`claude-opus-5`, `claude-sonnet-5`) with the date,
so a future reader can tell whether the mapping still holds. That is a note, not a guarantee, and
must not be described as one.

---

## The rule, stated once

```text
Opus  — brainstorm, plan, verify, review, and anything that JUDGES finished work.
Sonnet — execution: implement, test, refactor, sync docs, rename, capture.
```

The main orchestrator session stays Opus, unchanged: it decides which skill runs and when to stop,
which is judgement.

---

## Part A — the rubric becomes a rule

`docs/rubric-model-switching.md` is rewritten:

- The opening line stops describing an *auto-rubric to choose from* and states a **MUST**.
- The table collapses to two tiers. Every Haiku row moves to `sonnet` with its reason updated
  rather than deleted — a row that vanishes leaves the next reader wondering whether the task was
  forgotten or decided.
- A new section records the alias mapping with today's date and the reason aliases were chosen
  over pinned ids.
- The "Override Precedence" section stays, with one addition: **an override that drops a judging
  task below Opus, or raises an execution task above Sonnet, requires a written reason at the call
  site.** Silent overrides are how a rule becomes advice again.

`CLAUDE.md`'s "Model Switching Rubric" section is rewritten to match, including the cost-mix line.

## Part B — the gate

New script `skills/gaspol-verify/scripts/model-gate`, stdlib-only shell, exit contract identical
to `ledger-gate` / `spec-pointer` so callers do not have to learn a third vocabulary.

What it reads — two surfaces, because a rule enforced on one is a rule with a hole:

1. **Agent frontmatter** — every `agents/*.md` `model:` field, checked against the tier its
   filename implies. `*-reviewer`, `*-verifier`, `*-simplifier` are judging agents and MUST be
   `opus`; anything else MUST be `sonnet`.
2. **Dispatch call sites in skills** — every `model: "<value>"` and `model: <value>` inside
   `skills/**/*.md`, checked against the surrounding dispatch's `subagent_type` where one is
   present on the same or an adjacent line.

| Exit | State | Treatment |
|---|---|---|
| 0 | every model reference matches its tier | pass |
| 1 | **BLOCKING** — a reference names the wrong tier, or names `haiku` at all | fix it |
| 3 | UNKNOWN — a `model:` reference whose tier cannot be determined (no resolvable `subagent_type`, unparseable frontmatter) | **STOP and ask.** Never guess a tier: guessing is exactly what the rule exists to stop |
| 4 | not applicable — no `model:` reference found anywhere | not a failure, not a pass; record the reason |

**Why `haiku` is exit 1 rather than exit 3.** It is not an unknown tier; it is a tier the rule
deleted. Reporting it as unknown would invite a case-by-case exemption, which is how the deleted
tier comes back one row at a time.

Wired into `gaspol-verify` Layer 1 beside `ledger-gate`, invoked through `$CLAUDE_PLUGIN_ROOT`,
and added to `test-kb-no-hardcoded-path.sh`'s anchored-script list — which IDS-19 widened to four
and this widens to five.

---

## File Integration Map

| Change | File | Exists? | Action |
|---|---|---|---|
| The rule, canonical | `docs/rubric-model-switching.md` | yes | rewrite: MUST, two tiers, alias record, override rule |
| The rule, summary | `CLAUDE.md` "Model Switching Rubric" | yes | rewrite to match; fix "Opus 4.7"/"Sonnet 4.6"; drop the Haiku cost share |
| Judging agent | `agents/code-reviewer.md` | yes | `sonnet` → `opus` |
| Judging agent | `agents/code-simplifier.md` | yes | `sonnet` → `opus` |
| Judging agent | `agents/plan-verifier.md` | yes | already `opus` — assert, do not edit |
| Judging agent | `agents/spec-reviewer.md` | yes | already `opus` — assert, do not edit |
| Dispatch | `skills/gaspol-parallel/SKILL.md:318` | yes | `"sonnet"` → `"opus"` |
| Dispatch | `skills/gaspol-review/SKILL.md:102` | yes | Sonnet → Opus, with the reason updated |
| Dispatch | `skills/gaspol-execute/implementer-prompt.md:18` | yes | stays `"sonnet"` — implementation is execution. Assert it |
| Dispatch | `skills/gaspol-auto/SKILL.md:81` | yes | stays `sonnet`; the prose "per rubric" now points at a rule |
| Docs sync tier | `skills/gaspol-sync-docs/SKILL.md` | yes | any `haiku` reference → `sonnet` |
| The gate | `skills/gaspol-verify/scripts/model-gate` | **no** | build it, with `--self-test` |
| Gate wiring | `skills/gaspol-verify/SKILL.md` Layer 1 | yes | anchored invocation + a recorded `model-tier:` line |
| Anchored-path gate | `tests/ticket-scripts/test-kb-no-hardcoded-path.sh` | yes | widen from four scripts to five |
| Gate tests | `tests/ticket-scripts/test-model-gate.sh` | **no** | build it: all four exits, both surfaces |
| Rule tests | `tests/ticket-scripts/test-model-rule.sh` | **no** | build it: the rubric states MUST, names no Haiku, records the aliases |
| Release | `CHANGELOG.md`, `.claude-plugin/plugin.json`, the `gaspol-one` manifest | yes | 1.29.0 |

No placeholder is needed anywhere: every file above exists today.

## Edge cases enumerated

| Case | Behaviour |
|---|---|
| An `agents/*.md` with no `model:` field | exit 3 UNKNOWN — the tier is undeclared, and inheriting from the parent silently is what the rule forbids |
| A `model:` value that is neither `opus`, `sonnet` nor `haiku` (a pinned full id) | exit 3 UNKNOWN, with the value quoted — a pinned id may be deliberate, and the gate must not guess its tier |
| `model: haiku` anywhere | exit 1 BLOCKING, never exit 3 |
| A `model:` mention inside prose or a fenced example, not a real dispatch | must NOT be flagged. The gate matches an assignment shape, the way `test-kb-no-hardcoded-path.sh` distinguishes a line that RUNS from prose in backticks |
| A dispatch whose `subagent_type` is on a line far from its `model:` | exit 3 UNKNOWN rather than a guessed pairing |
| A new agent file added later whose name matches no tier pattern | exit 3 UNKNOWN — the naming convention is the tier signal, and an unrecognised name is a decision nobody made |
| No `model:` reference anywhere (a stripped-down checkout) | exit 4, reason recorded |
| Case: `Model:`, `MODEL:` | matched case-insensitively for the key; the VALUE is compared lowercased |

## What this does NOT close — named so the deferral cannot be mistaken for completion

- **The gate reads declarations, never what actually ran.** Nothing here observes the model a
  dispatched subagent was really served. If the harness ignores the field, the gate still passes.
  This closes the drift hole, not the execution hole.
- **The alias mapping is a note, not a mechanism.** If `opus` ever resolves to a weaker model,
  nothing detects it. The dated record in the rubric is what a human checks; it is not a check.
- **The main session's own model is not enforced.** A user can run the orchestrator on any model,
  and gaspol has no way to read or change that. The rule states the expectation and stops there.
- **Tier is inferred from a filename pattern.** A judging agent named without `-reviewer`,
  `-verifier` or `-simplifier` reaches exit 3, which is honest but is not the same as knowing what
  the agent does. Reading intent out of a description is a judgement call, and this gate makes
  none.
