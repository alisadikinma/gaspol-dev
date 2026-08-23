**Ticket:** IDS-17

# gaspol-finish: four mandatory steps, and finishing itself becomes an offer

## Problem

Two complaints, one subsystem, one ticket (Batch Gate: same subsystem, combined plan under the
phase threshold).

1. `gaspol-finish` runs a six-step chain plus a Step 0 preamble. Every step is mandatory and
   none is conditional on the diff. The owner wants four: `gaspol-verify`, `gaspol-review`,
   `/security-review`, `gaspol-sync-docs`.
2. `gaspol-finish` reads as obligatory at the end of every ticket. `gaspol-parallel` Phase 3
   says "Run `gaspol-finish` to finalize"; `gaspol-execute` lists it as downstream with no
   choice attached. The owner wants the end of a ticket to *offer* finishing, now or later.

## Design

### A. The mandatory chain drops to four steps

| # | Step | Status after this ticket |
|---|------|--------------------------|
| ~~0~~ | `detect-stack` + `regression-gate` preamble | **deleted** — an exact duplicate of `gaspol-verify` Layer 1, which is now step 1, so the cheap-checks-first ordering it existed to enforce is preserved by position rather than by repetition |
| 1 | `gaspol-verify` (4 layers) | mandatory. **The "already run this session, you may skip" permission is revoked** — with Step 0 gone this step is the only thing that runs the test suite, and an optional-and-duplicated pair collapses into nothing being run at all |
| 2 | `plan-verifier` | mandatory, BLOCKING. The existing provable-no-plan skip stays exactly as it is |
| 3 | `gaspol-review` Tier 1 | mandatory, BLOCKING on surviving Critical findings |
| 4 | `gaspol-sync-docs` | mandatory, evidence-gated (CLAUDE.md must appear in the diff on a structural change) |

Two steps leave the mandatory chain and become offers presented after step 4:

- **`/security-review`** — `[Run it]` / `[Skip]`. Declining records nothing.
- **`gaspol-learn`** — `[Capture patterns]` / `[Skip]`. Declining records nothing.

Both are offered in one `AskUserQuestion`, not two consecutive modals.

**`/security-review` is an explicit owner override of recorded precedent.** The knowledge note
`narrow-and-record-conditional-audit-gates` (2026-08-21, `proposed`) states the opposite rule and
names its reason: in a skills repository markdown *is* the executed surface, so a diff that looks
boring can still carry a hole. `tests/ticket-scripts/test-finish-gates.sh:150` was written to
block exactly this change. The precedent was surfaced at brainstorm Phase 0.5, the owner read it
and chose to override. An ADR capturing the divergence is a phase of the plan; the old note is
NOT superseded — both coexist, per the divergence rule.

**Both offers are recordless, deliberately and symmetrically.** An earlier draft gave
`gaspol-learn` a mandatory `not run — <reason>` ledger line while `/security-review` got none.
Two optional steps with two different accountability rules is a distinction nobody will remember
in a month; the owner chose one rule for both.

### B. Finishing becomes an offer

New shared file **`skills/_shared/finish-offer.md`**, holding the modal text and the three
outcomes once. Read by three call sites — `gaspol-execute` (after the final phase),
`gaspol-parallel` Phase 3, `gaspol-auto` post-run report. One source, for the reason
`fix-loop.md` was extracted: a constant copied into three skills is a constant that will
disagree with itself.

```text
[Finish sekarang]  [Nanti — branch dibiarkan]  [Cuma verify dulu]
```

| Choice | Action |
|--------|--------|
| Finish sekarang | invoke `gaspol-finish` |
| Nanti | append a ledger Log line ending `— NEXT: gaspol-finish — deferred: <reason>`; the reason may not be empty |
| Cuma verify dulu | run `gaspol-verify` only, then present the same offer again |

The deferral reuses machinery that already exists: `scan-active-ledgers` prints every ledger
whose last `NEXT:` marker is not `DONE`, so a deferred ticket resurfaces on its own next
session. Zero new code for the reminder.

The non-empty reason on `deferred:` follows `ledger-states-require-non-empty-reasons`: a bare
label is `(if possible)` wearing a new name. This applies to the deferral, which is a *state of
the work*, not to the two optional steps above, which the owner chose to leave recordless.

## What breaks and must be fixed in the same ticket

| Location | Why it breaks |
|----------|---------------|
| `tests/ticket-scripts/test-finish-gates.sh:150` | asserts no rule makes `/security-review` skippable — the assertion is deleted, and its comment replaced with the reason it was removed and who decided |
| `tests/ticket-scripts/test-finish-gates.sh:156` | loops over four "unconditional" steps including `gaspol-learn` — it leaves the loop |
| `tests/ticket-scripts/test-regression-gate.sh:167,186` | assert `gaspol-finish` Step 0 runs `regression-gate` anchored via `$CLAUDE_PLUGIN_ROOT` — Step 0 no longer exists. The `gaspol-verify` half of those assertions (lines 178, 183) stays and is now the only wiring |
| `tests/ticket-scripts/test-finish-fix-loop.sh:86` | asserts all six step names are still present — becomes four mandatory plus two offered, asserted separately so a future trim of the *mandatory* four still fails |
| `skills/gaspol-finish/SKILL.md` The Fix Loop | says "Step 0's checks run again before each fix round's dispatch" — repointed at `gaspol-verify` Layer 1 |
| `CLAUDE.md` | the gaspol-finish section and the Skill Routing table both state `/security-review` runs "ALWAYS, on every branch" from this chain |

New test **`tests/ticket-scripts/test-finish-offer.sh`**: the modal text lives in exactly one
file; all three call sites reference that file rather than restating it; the `deferred:` state
is documented as requiring a non-empty reason; the four mandatory steps are all still named in
`gaspol-finish`.

## Explicitly out of scope

`gaspol-execute` Step 3.6 also auto-runs `/security-review` on its own trigger conditions. The
request named `gaspol-finish`; that call site is untouched and keeps its current behaviour.

## Data Integration Map

| File | Change | Exists? |
|------|--------|---------|
| `skills/gaspol-finish/SKILL.md` | delete Step 0, renumber to four, two offers, fix The Fix Loop | yes |
| `skills/_shared/finish-offer.md` | new — modal text and three outcomes | **no** |
| `skills/gaspol-execute/SKILL.md` | present the offer after the final phase | yes |
| `skills/gaspol-parallel/SKILL.md` | Phase 3 step 3 becomes the offer | yes |
| `skills/gaspol-auto/SKILL.md` | post-run report uses the same modal | yes |
| `tests/ticket-scripts/test-finish-gates.sh` | two assertions changed | yes |
| `tests/ticket-scripts/test-regression-gate.sh` | two Step 0 assertions removed | yes |
| `tests/ticket-scripts/test-finish-fix-loop.sh` | step list split mandatory/offered | yes |
| `tests/ticket-scripts/test-finish-offer.sh` | new | **no** |
| ADR via `gaspol-adr` | records the `/security-review` divergence | **no** |
| `CLAUDE.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md` | v1.26.0 | yes |

No placeholders. Every change is real text in a file that is read at runtime.
