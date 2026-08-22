**Ticket:** IDS-10

# Completeness stance, report batching, and a design artifact for logic-only work

## Why this ticket exists

Three complaints, one report, one ticket — which is itself the first thing this ticket fixes.

1. **"5 bug dilaporkan → 5 tiket dibuat. Itu salah total."**
2. **"Kalau project-nya cuma enhancement logic tanpa perubahan design, tetap perlu 1 artifact design supaya bisa direview setelah plan selesai."**
3. **"Versi baru ini malah semakin bodoh."**

Reference for what good looks like: `/Users/alisadikin/Drive-D/Projects/claude-plugin/gstack`
(Garry Tan's builder stack), specifically its `ETHOS.md`.

---

## Defect 1 — one report becomes N tickets

**Verified cause.** There is no batching rule anywhere in the plugin:

```
grep -rn "multiple bug|several bug|each bug|N bugs" skills/   →  0 hits
```

The opposite rule *does* exist. `gaspol-brainstorm` Phase 1 **Decompose gate**:

> "Help the user split it into sub-projects... Then brainstorm the FIRST sub-project through
> the normal flow. **Each sub-project gets its own spec → plan → implement cycle.**"

And `skills/gaspol-execute/scripts/next-ticket` mints exactly one id per invocation, with no
notion of a batch. So five reported defects walk five times through brainstorm Phase 6 and mint
five ticket ids. This is the designed behaviour, not a bug in the implementation of it.

**The gate that is missing** is upstream of decompose: decompose asks *"is this one project or
several?"*, and nothing first asks *"is this one **piece of work** or several?"*. Five bugs in one
subsystem are one piece of work.

**Resolution — the Batch Gate.** Runs BEFORE the decompose gate, on every request carrying more
than one item, in `gaspol-brainstorm` and in `gaspol-debug` alike (bug reports usually land on
debug, never reaching brainstorm — a rule that lives only in brainstorm would not fire for the
exact complaint that produced this ticket).

Default: **one ticket.** Split is the exception and needs a stated reason, from a closed list:

| May split into 2 when | Never split for |
|---|---|
| items touch **disjoint subsystems** AND the combined plan needs **>8 phases** | "they are different bugs" |
| one item **blocks** another (must ship in separate releases) | "they are in different files" |
| user explicitly asks for separate tickets | "the ticket would be big" |

**Ceiling: 2.** More than two tickets from one report requires the user to ask, via
`AskUserQuestion`. Never automatic.

Items inside the batched ticket become **phases** of the one plan, ordered by severity, each with
its own regression test. Nothing is dropped — batching changes the container, never the coverage.

---

## Defect 2 — logic-only work produces nothing reviewable

**Verified cause.** `gaspol-brainstorm` Phase 2.5 offers `[No, pure backend/logic]`, and that branch
skips Phase 3 entirely. `gaspol-plan` then emits a markdown plan. For an enhancement that changes
behaviour but not pixels, there is no artifact a human can look at and say "yes, that is the flow I
wanted" — the first reviewable thing is the diff, which is too late.

**Resolution — the Logic Design Artifact, BLOCKING, after the plan is written.**

Every ticket gets exactly one design artifact before `gaspol-execute` runs. Which kind depends on
the work, and the *no design at all* branch is deleted:

| Work | Artifact |
|---|---|
| UI work | `ui-ux-pro-max` output as today (unchanged) |
| logic-only | **Logic Design Artifact** — new |

Contents, all five sections mandatory:

1. **Before → After behaviour** — the current path and the new path, side by side, per changed
   behaviour. Current path must be quoted from real code, not described from memory.
2. **Flow diagram** — mermaid `flowchart` or `sequenceDiagram` of the changed path.
3. **Data flow / contract table** — every input, its source, every output, its consumer. Reuses the
   plan's Data Integration Map columns so the two cannot drift.
4. **Edge-case matrix** — one row per non-happy path: input, expected behaviour, which phase covers
   it, which test proves it. An empty matrix is a failed gate, never a pass.
5. **What is NOT changing** — the blast-radius statement: touched files' behaviour that stays.

Published as an **HTML Artifact** (the `Artifact` tool), so the review happens on a page rather than
in scrollback. It is BLOCKING: `gaspol-execute` refuses to start a plan whose ticket has no approved
design artifact, exactly as it already refuses a phase with no TDD step 1.

**Three states, never blurred** (the house rule this repo already applies to `DESIGN.md` and to the
KB root): `approved` → execute; `pending` → STOP and ask; `not applicable` is **not a state** — it
was the bug.

---

## Defect 3 — the plugin got dumber (the Laziness Ladder)

**Verified cause.** v1.9 absorbed the ponytail plugin's **Laziness Ladder**
(`skills/_shared/laziness-ladder.md`) as gaspol's always-on default coding stance. It is injected by
`hooks/session-start.sh` into every session, and enforced as an explicit gate in three places
(`gaspol-plan` "Laziness Gate", `gaspol-execute` "Laziness Gate", `implementer-prompt.md`). Its
first rung is:

> "**Does this need to exist at all?** Speculative need → skip it."

and its rules are "Fewest files possible. Shortest working diff wins. Deletion over addition."

The stated boundary (never a placeholder, never a skipped test) keeps the output *real*. It does
nothing to keep it *complete* — and shallow work violates no boundary. Every task begins with a
prompt to look for a reason not to do the work. That is what "semakin bodoh" describes: not a
weaker model, a stance that instructs the model to do as little as possible.

**gstack takes the opposite position, and it is the reference the user named.** From
`gstack/ETHOS.md`, §1 "Boil the Ocean":

> "AI-assisted coding makes the marginal cost of completeness near-zero, so the old caution has
> quietly turned into an excuse. When the complete implementation costs minutes more than the
> shortcut — do the complete thing. Every time."

> "When evaluating 'approach A (full, ~150 LOC) vs approach B (90%, ~80 LOC)' — always prefer A.
> The 70-line delta costs seconds with AI coding."

Its named anti-patterns are, verbatim, what the Laziness Ladder instructs:

- *"Choose B — it covers 90% with less code."*
- *"Let's defer tests to a follow-up PR."*

The two cannot both run. One says the shortest diff wins; the other says take the longer one.

**Resolution — the Completeness Ladder replaces the Laziness Ladder.** Same slot (always-on,
`skills/_shared/`, injected by the session hook, gated in plan/execute/parallel), inverted content.

```
Before writing code, walk DOWN and do every rung that applies:

1. The happy path — the real integration, no placeholder.
2. Every error path that can actually happen — named, handled, tested.
3. Every edge case the input space allows — empty, null, zero, max, concurrent, malformed.
4. The tests that prove 1-3 — written first (TDD step 1 is unchanged and still hard-gated).
5. The observability someone debugging this at 3am needs.
6. The docs/comment that stops the next reader from re-deriving it.

Stop only at genuinely unrelated work — a rewrite, a multi-quarter migration. Flag that as
separate scope. Never as a reason to ship the shortcut.
```

**What survives from ponytail, and why.** The ladder's rungs 2-4 (stdlib → native platform feature
→ already-installed dependency) were never scope rules; they are *implementation* rules, and they
agree with gstack's own §2 "Search Before Building". They are kept, demoted to a **Reuse Rule**
inside the Completeness Ladder: prefer what already exists over what you write. The anti-abstraction
rules (no interface with one implementation, no factory for one product) are kept for the same
reason — they cut *cleverness*, not *coverage*.

**What is deleted outright:**

- rung 1, "does this need to exist at all → skip"
- "Fewest files possible. Shortest working diff wins."
- the `ponytail:` comment convention for marking deliberate cuts, which exists only to record a
  shortcut being taken

**Scope-cut anti-patterns become Red Flags,** mirroring the rationalization tables the plugin
already uses everywhere else:

| Rationalization | Why it is wrong |
|---|---|
| "90% coverage with less code is the better trade" | The delta costs seconds. Take the full one. |
| "Tests in a follow-up PR" | Tests are the cheapest rung on the ladder. |
| "The user didn't ask for the error path" | Users state WHAT. Error paths are HOW. |
| "YAGNI" | YAGNI applies to unrequested *features*, never to the completeness of a requested one. |
| "Shortest diff wins" | Deleted rule. The correct diff wins. |

---

## Defect 4 (found while verifying, in scope)

- `skills/gaspol-debug/SKILL.md` still carries a `## Sparkfluence-Specific Debugging` section —
  a project-specific leak in a plugin whose CLAUDE.md forbids hardcoding project values. The same
  class of leak was removed from `gaspol-execute` in v1.16 and missed here.
- **The test suite is red at baseline: 4 of 30 fail**, all on the same cause —
  `.claude-plugin/marketplace.json` was deleted in commit `50fbbb1` ("distribute via gaspol-one")
  and four tests still assert against it. The version-consistency gate has therefore been dead
  since that commit. `gaspol-finish` Step 0 requires the deterministic suite to be green before any
  agent is dispatched, so this blocks the whole chain and is repaired first.

---

## Out of scope

- The eight scripts still invoked by a relative path (`detect-stack` et al) — the deferred item
  recorded in CLAUDE.md's IDS-8 section. Untouched here.
- `gaspol-kb-audit` / `superbrain-promote` overlap — still deferred.
- Layout-geometry verification (IDS-6 Part B) — still deferred.

## Definition of done

- One report of N defects mints exactly one ticket; a split needs a listed reason and never exceeds
  two without the user asking.
- A logic-only ticket cannot reach `gaspol-execute` without an approved design artifact.
- No live file references the Laziness Ladder; the Completeness Ladder occupies its slot in the
  hook, in `gaspol-plan`, in `gaspol-execute`, and in `implementer-prompt.md`.
- `gaspol-debug` contains no project-specific section.
- All deterministic tests green, including new tests for each rule above and for the batch/split
  threshold specifically.
