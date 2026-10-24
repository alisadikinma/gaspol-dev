# Progress ledger format: detail

`SKILL.md` states each ledger gate's condition and consequence. This file holds the template, the section table, the older-ledger rule and the reasons.

The ledger `gaspol-plan` creates at `.gaspol/progress/PROGRESS-<TICKET>.md` (step 7 above) MUST
use exactly this template:

```markdown
# PROGRESS — IDS-1: gaspol output naming standard

**Ticket:** IDS-1
**Plan:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-plan.md
**Spec:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-spec.md

## Pre-flight

| Gate | Result |
|---|---|
| Git clean | PASS — baseline `331fbca` |
| Baseline suite | PASS — `<command from detect-stack>`, 44 lulus / 0 gagal |
| detect-stack | `unit: npm test` (atau "no stack markers") |

## Keputusan saat jalan

(kosong sampai ada keputusan; tiap butir: apa, siapa yang memutuskan, tanggal)

## Checklist

### [x] Phase A: script detect-stack
- [x] Write failing test for detect-stack on a Node project. Expected error: `command not found`
- [x] Run test, confirm it fails for the expected reason
- [x] Implement the marker-file reader
- [x] a Node project prints one `static:` and one `unit:` line
- [x] a directory with no marker files prints nothing and exits 0

### [>] Phase B: glob ledger case-insensitive
- [ ] Write failing test for a lowercase-prefixed ledger being found. Expected error: `not found`
- [ ] ...

### [ ] Phase C: konvensi nama file spec & plan

### [~] Phase D: contoh fase dibatalkan — DIBATALKAN (YAGNI, alasan di Log)

## Phase log

| Phase | Status | Commit |
|---|---|---|
| A — script detect-stack | DONE | `4f2a1c9` |
| B — glob ledger | DOING | `<no commit>` |
| C — konvensi nama file spec & plan | TODO | `<no commit>` |
| D — contoh fase dibatalkan | DIBATALKAN | `<no commit>` |

## Utang terbuka

(kosong sampai ada yang sengaja ditinggal; tiap butir bernama)

## Log
- 2026-08-20 Phase A done — `bash tests/ticket-scripts/test-detect-stack.sh` exit 0 — NEXT: Phase B
```

**The generic commands are recorded once, in `## Pre-flight`** (the `detect-stack` row), not copied
into every phase. A phase's checklist holds that phase's own checks only; the compile and unit
commands come from the plan's `**Verification commands:**` header block.

**The Checklist body is COPIED from the plan, never summarised.** Each phase's `**Steps:**` become
checkboxes and its `**Verification:**` block is appended verbatim — it is already `- [ ]`. Nothing
is authored twice, so the ledger cannot drift from the plan it came from.

**The accepted consequence, stated rather than discovered later:** ledger quality is now bound to
plan quality. A plan whose Steps are lazy produces a lazy ledger. That coupling is the point. The
alternative — a fixed generic checkbox set — can never produce a box like *"RED seen: `'   '` plus
a signature stores `''`, expected `null`"*, because that box is specific to one phase of one
ticket, and boxes like that are the entire reason this format is worth copying.

| Section | What it holds | Why it is mandatory |
|---|---|---|
| `## Pre-flight` | git state, the baseline suite run and its counts, `detect-stack` output | a red baseline nobody recorded gets blamed on the new phase, and the fix loop burns its rounds on somebody else's failure |
| `## Keputusan saat jalan` | each mid-run choice, who decided it, the date | the only record of what is neither in the plan nor in the code |
| `## Phase log` | phase → status → **real commit SHA, always in backticks** (`<no commit>` until committed) | a SHA can be re-checked; the word "DONE" cannot |
| `## Utang terbuka` | what was deliberately left undone, each item named | what is not written down becomes a *"nanti"* that never arrives |

**Every other section is added when it has content, never as an empty heading.** IND-117's ledger
grew nine — evidence-quality notes, open items for a later phase, the plan-verifier round table,
post-run gates, deploy steps, leftovers found after close. Mandating all nine would fill most
ledgers with "N/A", and an empty label reads as *checked and clear*, which is worse than a section
that is simply absent.

**Backward compatibility — READ the old shape, WRITE the new one.** An **older flat** ledger —
one `## Checklist` line per phase, no sub-blocks, none of the four sections — is still read
exactly as it is: tick its line, append to its `## Log`, and leave its shape alone. Rewriting a
ledger mid-ticket destroys the record of what was actually observed and replaces it with what
somebody infers now, which is the opposite of what a ledger is for. Only a ledger you CREATE uses
the new shape. `scan-active-ledgers` reads both, because both end with `## Log`.

The state markers apply to a **phase heading** and to an individual **checkbox** alike: a single
step that was genuinely not done gets `[~]` with its reason on the line, rather than a tick it
did not earn or a blank that reads as forgotten.

## Why the ledger is created at plan-write time

Rationale: at plan-write time the phase names are already known,
so the executor only has to tick boxes rather than re-derive the phase list. Accepted side
effect: a plan that is written but never executed shows up as active work in
`scan-active-ledgers` — that is honest, and `gaspol-execute` Step 0 already has a 4-option
modal for it.
