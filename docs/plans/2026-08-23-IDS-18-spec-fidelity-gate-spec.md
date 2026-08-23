**Ticket:** IDS-18

# Spec fidelity + blast radius — the two links the verification chain never read

## Design

### The defect

The delivery chain is `spec → plan → code`. Only the second link is guarded.

Verified by command, not inferred:

```
grep -rn -- "-spec.md" skills/ agents/
```

Five hits, all in `gaspol-plan` (a glob that *finds* a spec) and `gaspol-worktree` (a filename
mentioned in prose). **Zero** in `gaspol-execute`, `gaspol-auto`, `gaspol-verify`, or
`agents/plan-verifier.md`.

Sharper still: `gaspol-plan` **writes** the pointer `**Spec:** <path>` into every plan header
(`skills/gaspol-plan/SKILL.md:126`) and nothing reads it. This is IDS-7's `--design-system` shape
one layer up — parsed into documentation, consumed by nothing.

`agents/spec-reviewer.md` exists and its description is exactly this job. It is invoked only by
`gaspol-parallel`, and there against a task brief, never against a `-spec.md` file. On the
`gaspol-execute` and `gaspol-auto` paths it never runs at all.

The second, smaller half: the artifact `gaspol-plan` offers carries a mandatory section 5, *"What
is NOT changing (blast radius)"* (`skills/gaspol-plan/logic-design-artifact.md:64`). Nothing
compares it to the diff. `gaspol-execute` reads four `design-artifact:` ledger states
(`skills/gaspol-execute/SKILL.md:209-212`) and all four describe whether a human clicked approve —
status, never content.

This is the same defect shape this repository has now shipped five fixes for: **a rule exists in
prose, and no machine enforces it.** IDS-7 (a design gate never wired up), IDS-8 (a setting nothing
read), IDS-12 (`gaspol-execute` only read code, never ran it), IDS-13 (a Live App Check with no
detector), IDS-14 (a regression test nobody had to defend skipping).

### Batch ruling

**Two items, one ticket.** Same subsystem: both add an upstream-artifact read to the same
verification chain (`plan-verifier` plus `gaspol-verify` Layer 2). Neither split reason applies.
`next-ticket` was called once.

### Precedent applied

Surfaced at Phase 0.5 from the knowledge store (133 notes, resolved into the owner's vault inbox),
all three applied by owner decision:

| Note | How it lands here |
|---|---|
| `machine-checkable-escape-hatch-closure` (IDS-14) | the three-state contract plus a deterministic script, with a mandatory non-empty reason. `spec-pointer`'s exit codes are that pattern |
| `silence-over-falsehood-in-error-states` | a broken spec pointer must NOT degrade to "no spec" — an empty spec reads as *nothing was violated* |
| `mandatory-end-of-work-chains-should-be-minimal-and` (IDS-17, yesterday) | pointed the other way — lean mandatory chains, everything else an offer. Honoured by **merging into the existing `plan-verifier` dispatch**: the chain gains zero steps and zero agent dispatches. The check itself is mandatory, not an offer |

Prior-Art Gate verdict: **NONE**. `npx skills find "specification compliance verification agent"`
returned OWASP compliance, tax compliance, a MultiversX-specific checker, and generic PR reviewers.
Nothing reads a `**Spec:**` pointer out of a gaspol plan header and verdicts against this plugin's
own FOUND/PARTIAL/MISSING vocabulary. The capability is coupled to this repository's file format,
not general.

Novelty: **PRECEDENT** — KB hit plus an in-repo pattern (`regression-gate` is structurally
identical). No research run.

Design lane: **logic**. Zero UI files touched; Phase 3 skipped. `gaspol-plan` will offer the logic
design artifact.

### The seam: what is deterministic, what is judgement

The repository already answers this consistently. `kb-root` resolves a *path* deterministically and
leaves the *content* to skill prose. `regression-gate` reads a *ledger line* deterministically and
leaves *whether the test is any good* to a human. The seam always falls in the same place.

| Concern | Nature | Form |
|---|---|---|
| Does the `**Spec:**` pointer exist / resolve / is it broken | deterministic | new script `spec-pointer` |
| Does a spec requirement appear in the code | judgement | prose in `agents/plan-verifier.md` |
| Did the plan drop a spec requirement | judgement | prose, new verdict `DROPPED` |
| Planned file list vs `git diff --name-only` | fully deterministic | new script `blast-radius-diff` |

### `spec-pointer` — three states

Exit codes follow `kb-root`'s existing contract (0 / 3 / 4), so the two cannot be read differently.

| Exit | State | Behaviour |
|---|---|---|
| 0 | pointer resolves, file readable | prints the resolved path on stdout; gate active |
| 3 | **UNKNOWN** | **STOP and ask.** Never degrade to state 4 |
| 4 | no `**Spec:**` line in the plan header | record `spec: none — standalone plan`. **Not a failure** |

Exit 3 covers four distinct conditions, each named because each has been a real defect class here:

- the header names a path and no such file exists;
- the `**Spec:**` line is present but **empty after the colon** — a bare label with nothing after
  it is `(if possible)` wearing a new name, the exact rule `regression-gate` enforces;
- the spec file is readable but **no requirement is parseable from it** — zero items must never
  read as *spec satisfied*, which is `design_audit.py`'s own defect one layer down;
- the plan file itself is unreadable — distinct from "the plan has no spec".

Path resolution is against the **repository root**, never the working directory. An agent runs a
SKILL.md bash block with the target project as its CWD; resolving a repo-relative path against CWD
is the IDS-8 hazard class.

### `blast-radius-diff` — fully deterministic

Inputs: the plan file and a BASE SHA. It extracts the literal file paths the plan's phases declare
and compares them to `git diff --name-only <BASE>..HEAD`.

| Condition | Verdict | Reason |
|---|---|---|
| file changed, never named by the plan | **WARN** | mirrors `geometry-diff`: a missing marker BLOCKS, an extra one WARNs |
| file named by the plan, deleted in the diff | counted as touched | a deletion is a change |
| plan names a glob or a directory | reported **UNKNOWN** | literal paths only; silently ignoring a glob is a silent pass |
| BASE SHA invalid or unreachable | exit 3 | never degrade to an empty diff |
| no parseable file list in the plan | exit 4, `blast-radius: none` | not a failure |

Exit codes: **0** no findings · **1** findings present, all WARN-level · **3** UNKNOWN, STOP and
ask · **4** no parseable file list, not a failure.

**Exit 1 does not block, and that is a deliberate weakening — recorded here rather than glossed.**
Every individual finding this script can produce is legitimately explainable: collateral edits
happen, and a per-file BLOCK would fire on most branches. But a report that stops nothing is a
report nobody reads. So the accountability moves rather than disappears, the same move IDS-16 made
with the design artifact: from *you may not proceed* to *the finding is on the record*.
`gaspol-verify` Layer 2 writes a `blast-radius:` line naming every unplanned file, so a reviewer
sees what the plan never mentioned. What is given up: nothing forces anyone to read that line. This
is weaker than the `DROPPED` half of the ticket and must not be described as equivalent.

**The ignore list decides whether this gate survives.** Without one, every run false-positives on
`.gaspol/`, lockfiles, `CLAUDE.md`, and `docs/plans/` — files that legitimately change on every
ticket and appear in no phase's file list. A gate that cries wolf gets switched off, and a disabled
gate is worth less than a noisy one. The defaults are built into the script.

**Source of the file list: the plan, not the artifact.** The artifact is stored as a URL; reading it
requires a network round-trip and fails outright when it belongs to another session. A gate that
needs the network to run would spend most of its life recorded as `not run`, the way the WIG lane
does. The artifact's section 5 copies its list from the plan in the first place.

The artifact is used as a **cross-check when its URL happens to be readable**. If the plan's list
and the artifact's list disagree, that is **exit 3 — UNKNOWN, STOP and ask**, never a silent win for
either side. Two sources of truth are only safe when their disagreement is loud.

### `DROPPED` — the new verdict, and it BLOCKS

A requirement present in the spec and absent from the plan is not "missing from the code" — the
planner dropped it. It gets its own label, and it is **BLOCKING, exactly like MISSING**.

The consequence is stated rather than discovered later: **a deliberate scope reduction must be
written back into the spec.** Narrowing the work in conversation, or in the plan alone, will now
BLOCK. This makes the spec a real contract instead of an opening note.

### Flow — one dispatch, more items

```
plan-verifier invoked (execute Step 7 / auto Step 111 / finish step 2)
  |
  +- Step 1a: parse the plan into granular items          [existing]
  +- Step 1b: spec-pointer <plan-file>                    [NEW, deterministic]
  |     exit 0 -> parse the spec into items, tagged `spec`
  |     exit 3 -> STOP and ask
  |     exit 4 -> record `spec: none - standalone plan`, continue
  |
  +- Step 2:  verdict every item against code, quote required   [existing, longer list]
  |     spec requirement absent from the plan -> DROPPED   [NEW]
  |
  +- Step 2b: blast-radius-diff <plan-file> <BASE>         [NEW, deterministic]
  |
  +- Verdict: BLOCKING if MISSING > 0, DROPPED > 0,
              unapproved PARTIAL > 0, or placeholders > 0
```

Zero additional agent dispatches. What grows is the item list an already-running agent reads.

### Data Integration Map

In a plugin, "data source" means the file that is read.

| Consumed | Source | Exists? | Notes |
|---|---|---|---|
| Spec path | `**Spec:**` line in the plan header | **yes** — written by `gaspol-plan` since IDS-1 | zero readers until now |
| Spec requirements | bullets + Data Integration Map in `-spec.md` | yes | written by brainstorm Phases 5-6 |
| Planned file list | per-phase file lists in `-plan.md` | yes | `gaspol-execute` Step 4 already enumerates them |
| Files actually changed | `git diff --name-only <BASE>..HEAD` | yes | plain git |
| Artifact URL | `design-artifact:` in the ledger | yes | cross-check only, when readable |

**Zero new integrations. Zero placeholder risk** — every source is already written today; none has
to be invented.

### Files touched

| File | Action |
|---|---|
| `skills/gaspol-verify/scripts/spec-pointer` | new |
| `skills/gaspol-verify/scripts/blast-radius-diff` | new |
| `agents/plan-verifier.md` | Step 1b, the `DROPPED` verdict, the BLOCKING rule |
| `skills/gaspol-verify/SKILL.md` Layer 2 | `spec-fidelity:` and `blast-radius:` lines |
| `tests/ticket-scripts/` | new tests plus attack rows in `test-gate-mutations.sh` |
| `CLAUDE.md` | Architecture table and verification section |
| `.claude-plugin/plugin.json` | version bump |

**Both scripts are invoked as `"$CLAUDE_PLUGIN_ROOT/skills/..."`, never by a relative path.**
`spec-pointer`'s stdout becomes a path the agent then reads; a relative invocation executes whatever
the target repository happens to ship at that path. That is precisely the surface `/security-review`
found in IDS-8. Adding two new relative call sites now would add debt whose shape this repository
already knows. The anchored-invocation gate currently matches only `kb-root` and must be widened to
cover both new scripts.

### Tests

Adding an exemption means adding its attack row first — the rule `test-gate-mutations.sh` exists to
enforce.

- `test-spec-pointer.sh` — all four states, including empty-after-the-colon, a zero-requirement spec
  file, and repo-root-relative path resolution
- `test-blast-radius-diff.sh` — the ignore list, a deleted file, an extra file WARNing, an invalid
  BASE exiting 3, a glob reported UNKNOWN
- `test-plan-verifier-spec.sh` — text assertions that the agent carries `DROPPED`, all three pointer
  states, and the anchored invocation
- new attack rows in `test-gate-mutations.sh`
- the anchored-invocation gate widened from `kb-root` alone to both new scripts

### What this does NOT close

Written here so the deferral cannot later be mistaken for completion.

- **The artifact's other four sections stay unverified** — before/after behaviour, the mermaid flow,
  the data-flow table, and the edge-case matrix are never compared to code. Only blast radius is.
- **Recall is model-bounded, not deterministic.** A requirement the agent does not recognise as a
  requirement will never be reported `DROPPED`. A spec is prose, and prose is not machine-parseable.
  This is a judgement gate; calling it a guarantee would overclaim.
- **Spec quality is not graded.** The question answered is "was it dropped", never "was the
  requirement correct". The spec self-review in `gaspol-brainstorm` Phase 6 still grades itself.
- **A bug fix that changes behaviour still passes no spec point at all** — bug reports route to
  `gaspol-debug`, which produces no spec. Unchanged by this ticket, and deliberately not ticketed:
  a number pointing at no spec is the promise-with-no-implementation shape this repository keeps
  having to undo.
