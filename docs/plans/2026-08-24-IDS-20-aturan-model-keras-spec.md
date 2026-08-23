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
drifted from what the owner wants in **ten** separate places. The first survey found four; a
second pass over `skills/**` found six more, and the count is recorded at its true size because an
undercounted defect is how a known hazard becomes an unknown one. Verified by reading the files,
not inferred:

| Location | Today | Under the rule |
|---|---|---|
| `agents/code-reviewer.md` frontmatter | `model: sonnet` | **`opus`** |
| `agents/code-simplifier.md` frontmatter | `model: sonnet` | **`opus`** |
| `skills/gaspol-parallel/SKILL.md:318` code-quality dispatch | `model: "sonnet"` | **`"opus"`** |
| `skills/gaspol-parallel/code-quality-reviewer-prompt.md:17` | `model: "sonnet"` | **`"opus"`** |
| `skills/gaspol-review/git-history-reviewer.md:4` | `model: sonnet` | **`opus`** |
| `skills/gaspol-review/plan-artifact-reviewer.md:4` | `model: sonnet` | **`opus`** |
| `skills/gaspol-review/pr-comments-reviewer.md:4` | `model: sonnet` | **`opus`** |
| `skills/gaspol-review/code-comment-reviewer.md:4` | `model: sonnet` | **`opus`** |
| `skills/gaspol-execute/implementer-prompt.md:10` | *"Override to `haiku` when: mechanical rename/format/docs-only changes"* | the sentence goes — `haiku` is a deleted tier, not an override |
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

**Tier is read from the FILE PATH, not from a nearby `subagent_type`.** The first design keyed
off `subagent_type` on an adjacent line; the survey killed it. Six of the ten violations sit in
frontmatter or in a prompt template where no `subagent_type` appears at all, and a rule that can
only see half its violations is not a rule. The path is the honest signal: a file named
`code-quality-reviewer-prompt.md` is a reviewer's prompt no matter how it is dispatched.

1. **Anything under `agents/` or `skills/` whose path contains `reviewer`, `verifier` or
   `simplifier`** — a JUDGING surface. Every `model:` declaration in it MUST be `opus`.
2. **Anything whose path contains `implementer`** — an EXECUTION surface. Every `model:`
   declaration MUST be `sonnet`.
3. **`model: haiku` anywhere at all**, including inside prose, is exit 1. See below.
4. **A `model:` whose value is not `opus`, `sonnet` or `haiku`** — e.g. `model: selectedModel` in
   `skills/gaspol-debug/defense-in-depth.md:178`, which is illustrative code in another language,
   not a gaspol dispatch. **Not flagged**, counted and reported. Treating it as UNKNOWN would fire
   on documentation, and a gate that fires on documentation gets switched off.
5. **A `model:` on a path matching no tier pattern** — the tier is taken from the **same line**,
   which is where a dispatch names its `subagent_type`. `skills/gaspol-parallel/SKILL.md:318`
   reads `subagent_type: "gaspol-dev:code-reviewer", model: "sonnet"` on one line, so the tier is
   knowable and the violation is catchable. Neither path nor line yields a tier → exit 3 UNKNOWN.

**Two checks, deliberately different in breadth**, because the violations are of two shapes:

| Check | Scans | Why this breadth |
|---|---|---|
| **tier** | only assignment-shaped lines, `^\s*model:\s*"?<value>` | that shape is what actually configures a dispatch. Matching mid-sentence prose would flag `skills/gaspol-auto/SKILL.md:81`'s *"(model: sonnet per rubric)"*, which is a correct sentence about the rule |
| **haiku** | the bare word, anywhere under `agents/` and `skills/`, case-insensitive | the tier is DELETED, and it survives in prose: `skills/gaspol-execute/implementer-prompt.md:10` says *"Override to `haiku` when: mechanical rename/format/docs-only changes"*. An instruction to use a deleted tier is the tier still being available. `docs/` is not scanned, so the rubric can explain the removal |

**Named limitation, not a gap that was missed:** a tier violation written as prose rather than an
assignment is invisible to the tier check. `skills/gaspol-review/SKILL.md:102` — *"dispatch a
refuter (model: Sonnet — judgment, not mechanical)"* — is exactly that, and it is fixed by hand in
this ticket while the gate cannot defend it afterwards. Widening the tier check to prose would
flag every correct sentence about the rule, and a gate that fires on its own documentation is one
somebody switches off.

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
| A `model:` value that is neither `opus`, `sonnet` nor `haiku` | **not flagged**, counted and reported. Covers both a deliberately pinned id and illustrative code such as `model: selectedModel`. Flagging documentation is how a gate gets switched off |
| `model: haiku` anywhere | exit 1 BLOCKING, never exit 3 |
| A `model:` mention inside prose or a fenced example, not a real dispatch | must NOT be flagged. The gate matches an assignment shape, the way `test-kb-no-hardcoded-path.sh` distinguishes a line that RUNS from prose in backticks |
| A dispatch whose `subagent_type` is far from its `model:` | irrelevant — tier comes from the file path, never from a nearby `subagent_type`. That first design could see only four of the ten real violations |
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
- **Tier is inferred from a file path.** A judging surface named without `reviewer`, `verifier`
  or `simplifier` reaches exit 3, which is honest but is not the same as knowing what the file
  does. Reading intent out of a description is a judgement call, and this gate makes none.
- **A `model:` value the gate does not recognise is reported, never blocked.** A pinned full id
  and a foreign-language example are indistinguishable to it.
