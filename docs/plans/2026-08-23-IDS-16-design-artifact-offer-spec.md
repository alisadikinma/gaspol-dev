**Ticket:** IDS-16

## Design

### Problem

`gaspol-plan`'s design-artifact gate says two different things in the same file.

- [`skills/gaspol-plan/SKILL.md:127`](../../skills/gaspol-plan/SKILL.md) — the header template's own
  comment on the `**Artifact:**` field: *"optional — present ONLY when the Execution Handoff
  artifact offer was accepted and rendered"*. An **offer**.
- [`skills/gaspol-plan/SKILL.md:315`](../../skills/gaspol-plan/SKILL.md) — *"**Step 0 — Design
  Artifact (BLOCKING)** — every plan file, no exceptions"*, and at line 343 *"There is
  deliberately no 'not applicable' state."* **Mandatory.**

Line 127 predates v1.20. IDS-10 made the gate blocking and never updated the header comment, so a
reader following the header believes the artifact is offered, and a reader following Step 0
believes it is compulsory. The reported symptom was exactly that: *"generate artifact salah step
— seharusnya setelah gaspol-plan baru sistem tanyain apakah mau lanjut render artifact atau lanjut
eksekusi?"* That reading matches line 127, which is the stale half.

Three further defects were found while reading the gate, each verified by reading the files, not
inferred:

| Defect | Evidence |
|---|---|
| `ui-ux-pro-max` can be invoked **three** times for one UI feature | `gaspol-brainstorm:692` (Phase 3), `gaspol-plan:261` (Design Deliverable column), `gaspol-plan:327` (Step 0 UI lane). Step 0 was added by IDS-10 without checking the two that already existed |
| UI work never receives the five-section logic treatment | Step 0's two-lane table routes UI work to a mockup **instead of** the Logic Design Artifact. Behaviour — error paths, edge cases, blast radius — is never written down for UI work |
| A bug that changes the UI passes no design point at all | `gaspol-debug` contains no design step. Its only occurrence of "design" is line 118, `"Design a minimal test"`, which is about test hypotheses |

### Why the gate is being relaxed, and what must not be lost

Two knowledge-store notes, both captured from IDS-14 on 2026-08-23, bear directly on this change:

- `machine-checkable-escape-hatch-closure` (proposed) — a process rule carrying an escape hatch
  degrades into a silent default when no machine reads the output the rule was supposed to produce.
- `ledger-states-require-non-empty-reasons` (proposed) — `N/A` and `not run` states count as
  satisfied only when a reason follows the dash. A bare label is `(if possible)` wearing a new name.

The user reviewed both and chose to apply them rather than override. So the gate becomes an offer,
**and** declining it writes a reason into the ledger that a test asserts is non-empty. The escape
hatch exists; it cannot be taken silently.

**What is knowingly given up.** UI work reached through `gaspol-plan` directly — without a
`gaspol-brainstorm` session — can now answer "just execute". Since IDS-10 that was impossible. This
is recorded here because it is a deliberate reduction, not an oversight.

### Resolution

#### A. The gate becomes one merged offer, only in `gaspol-plan`

After the plan file and its ledger are written, `gaspol-plan` presents exactly **one**
`AskUserQuestion`:

```text
[Render design artifact dulu]   → render it, then re-present this modal without this option
[Eksekusi di sesi ini]          → gaspol-execute (per-phase checkpoints)
[Eksekusi otomatis]             → gaspol-auto (autonomous, hard-stop guardrails) — ALWAYS offered
[Eksekusi parallel]             → gaspol-parallel (only when independent phases exist)
[Simpan buat sesi lain]         → stop
[Serahkan ke executor luar]     → only when $GASPOL_EXECUTOR or .gaspol/executor resolves
```

This replaces the current two consecutive steps (publish-and-approve, then the separate Option 1-4
modal).

**Which choices demand a reason, and which do not.** A reason is required only when execution is
about to start with no artifact — `[Eksekusi di sesi ini]`, `[Eksekusi otomatis]`,
`[Eksekusi parallel]` and `[Serahkan ke executor luar]`. Those write
`design-artifact: skipped — <reason>` to the ledger before handing off.

`[Simpan buat sesi lain]` writes **no** `design-artifact:` line at all. Nothing was skipped,
because nothing executed. Demanding a reason there would be asking someone to justify a decision
they have not made yet, which is how a gate teaches people to type anything to get past it.

**What that costs, stated plainly rather than glossed.** Because the offer lives only in
`gaspol-plan`, a later session that resumes the plan through `gaspol-execute` will not see it
again: it reads a ledger with no line, proceeds, and records
`design-artifact: none — no offer was made`. The only way to reach the offer again is to re-enter
`gaspol-plan` for that plan. This follows directly from the one-place rule in this section and is
not a separate decision; it is written down here so the gap is visible instead of being discovered
later.

**`gaspol-auto` is added to the offer and is unconditional.** It is a documented execution mode in
CLAUDE.md's routing table — *"Execute plan with full autonomy + hard-stop guardrails"* — and
`gaspol-plan` has never offered it, so the only way to reach it was to know it existed and ask by
name. It is offered on every plan, alongside `gaspol-execute`. Its own pre-flight gate is
unchanged and still applies once chosen: plan approval, clean git state, a passing baseline, and
the per-phase TDD check. Those are `gaspol-auto`'s own refusals to run, not reasons to hide the
option; a mode whose entry point is undiscoverable is the same defect class as a gate nothing
reads.

**The offer exists in exactly one place.** `gaspol-execute` never presents it. This is a direct
user instruction — *"tawaran render artifact hanya muncul setelah gaspol-plan, gak ada lagi tempat
lain"* — and it decides the missing-line behaviour in section B: `gaspol-execute` cannot stop and
send the user back for an offer that does not exist there.

#### B. Four ledger states, and `gaspol-execute` only reads them

The ledger is `.gaspol/progress/PROGRESS-<TICKET>.md`; the line sits above `## Log`.

| Ledger line | `gaspol-execute` |
|---|---|
| `design-artifact: approved — <url>` | proceed |
| `design-artifact: pending — <url>` | **STOP and ask** — published, never approved |
| `design-artifact: skipped — <reason>` | proceed |
| no such line | proceed, and record `design-artifact: none — no offer was made` |

`skipped` with an empty reason is rejected — the `ledger-states-require-non-empty-reasons` rule.
The `pending` state keeps its STOP: something was published and left un-adjudicated, which is a
genuine ambiguity rather than a decision.

#### C. One artifact, tab count varies — the two-lane split is deleted

The current Step 0 table routes to a mockup **or** a Logic Design Artifact. That branch is why UI
work never gets the five sections. Replaced by:

| Change touches UI? | Artifact contains |
|---|---|
| yes | **two tabs** — *Design* (the rendered mockup) and *Logic* (the five sections) |
| no | **one tab** — *Logic* |

The Logic tab is always present, for every kind of work. UI detection reuses the existing signal
rather than inventing a second one: the file extensions already listed in `gaspol-plan`'s Design
Deliverable column — `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css` and the other style
extensions it names.

**Tab isolation is unproven and is the first implementation step.** A mockup carries its own CSS,
which can collide with the artifact page's. The intended mechanism is `<iframe srcdoc="…">`: it
starts no request to an external host, so it should satisfy the artifact CSP. "Should" is not
evidence. The first phase proves it renders isolated inside a published artifact before anything
else is built on it; if it does not, the fallback is scoped CSS with a generated prefix, decided
against a real published page rather than by reading.

#### D. The mockup is rendered exactly once, after `gaspol-plan`

Per direct user instruction — *"mockup dihasilkan setelah gaspol-plan saja"*.

| Stage | What it produces |
|---|---|
| `gaspol-brainstorm` Phase 3 | design **decisions as text** — palette, font pairing, layout blueprint, motion, accessibility. No mockup file |
| `gaspol-plan` Design Deliverable column | **cites** those decisions; it does not invoke `ui-ux-pro-max` again |
| the offer in section A, Design tab | the **only** point a mockup is rendered, using the Phase 3 decisions; where brainstorm never ran, `ui-ux-pro-max` is invoked here, once |

`ui-ux-pro-max` is therefore invoked at most once per ticket, down from a possible three times.

`skills/gaspol-brainstorm/visual-companion.md` is unchanged and keeps its current role: an
interactive just-in-time tool for questions that are clearer shown than told during a brainstorm.
It is not the deliverable, and this ticket does not route the deliverable through it.

#### E. Artifact prose is written in plain Indonesian

Added to `logic-design-artifact.md` as a contract requirement, not left as a habit: the artifact's
sentences are plain Indonesian, short, one idea per sentence. It is written into the contract file
because the contract is what a fresh executor reads; a habit that lives only in conversation does
not survive `/compact` or an external executor.

**What stays English, stated as a rule rather than a list of examples.** Any technical term whose
English form is the one the reader actually recognises stays verbatim. Two classes, and the second
is the one an over-eager translator gets wrong:

1. **Literals** — file names, tool names, CLI commands, skill names, error strings, variable names,
   config keys. These are strings that must match something real; translating one makes it wrong,
   not merely awkward.
2. **Ordinary technical vocabulary** — *framework*, *hardisk*, *cache*, *deploy*, *commit*,
   *branch*, *endpoint*, *query*, *build*. These have dictionary-Indonesian equivalents, and using
   them (*kerangka kerja*, *cakram keras*, *singgahan*) is **worse**: the reader has to translate
   back to know what is meant. The English word is the plainer word here, so it wins.

The test for a borderline term is not "does an Indonesian word exist" but **"which form does the
reader recognise faster"**. Where the Indonesian word is the everyday one, use it. Where the
English word is what the reader would say out loud, keep the English word.

**What must be simple is the surrounding sentence**, not the vocabulary: short sentences, one idea
each, no process jargon that carries no meaning for the reader.

This does not change the language of `docs/plans/*.md`, which stay English for contributors. The
artifact is read directly by the plugin's owner; the spec is read by whoever maintains the code.

#### F. The `gaspol-debug` gap is recorded, not closed

A bug fix that changes the UI passes no design point in any path today. This is written into
CLAUDE.md as a known-open gap. **No ticket number is minted** — this repo's convention refuses a
ticket id that points at no spec, and the number gets minted when the spec is written.

### Files touched

| File | Change |
|---|---|
| `skills/gaspol-plan/SKILL.md` | Step 0 (315-349) rewritten as the merged offer; two-lane table deleted; header comment (127) made consistent; Design Deliverable column (252-261) cites instead of invoking |
| `skills/gaspol-plan/logic-design-artifact.md` | tab contract, the tab-count rule, and the plain-Indonesian requirement |
| `skills/gaspol-execute/SKILL.md` | gate (203-214) becomes a four-state reader; the missing-line STOP is removed |
| `skills/gaspol-brainstorm/SKILL.md` | Phase 2.5 (265-271) "will produce" → "will offer"; Phase 3 states that it produces decisions, not a mockup file |
| `tests/ticket-scripts/test-logic-design-artifact.sh` | inverted: asserts the offer, the non-empty skip reason, the four ledger states, the tab-count rule, and the single `ui-ux-pro-max` invocation point |
| `CLAUDE.md` | "Design Artifact Gate (NEW in v1.20)" section rewritten; the `gaspol-debug` gap recorded |
| `README.md` | two BLOCKING claims (48, 129) corrected; badges |
| `.claude-plugin/plugin.json` | 1.24.0 → 1.25.0, and the matching entry in the sibling gaspol-one marketplace |

### Out of scope

- Adding a design gate to `gaspol-debug` — the gap is recorded in section F, not closed.
- Any change to `skills/gaspol-brainstorm/visual-companion.md` or its vendored server.
- Publishing the mockup as a second, separate artifact — rejected in favour of the two-tab layout.
- `DesignSync` (the harness tool for `claude.ai/design`) — it manages a persistent design-system
  component library across tickets, which is a different problem from one ticket's mockup.

### Blast radius

Four skills' text, one contract file, one test, two narrative documents, one version bump. No
script is added or changed. No control flow outside the artifact gate moves: `gaspol-parallel`,
`gaspol-verify` and `gaspol-finish` never read the `design-artifact:` line and are untouched.

The one behaviour that genuinely changes for existing work: plans whose ledger has no
`design-artifact:` line currently cannot be executed at all, and after this they execute with the
state recorded. Every ledger in `.gaspol/progress/` today predates the line or carries `approved`,
so nothing in flight is blocked by the change.
