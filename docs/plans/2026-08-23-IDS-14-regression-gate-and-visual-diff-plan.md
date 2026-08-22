# IDS-14 — Implementation Plan

**Ticket:** IDS-14
**Spec:** docs/plans/2026-08-23-IDS-14-regression-gate-and-visual-diff-spec.md
**Branch:** IDS-14-regression-gate-visual-diff
**Ledger:** .gaspol/progress/PROGRESS-IDS-14.md
**Artifact:** <pending — Design Artifact gate, BLOCKING>
**Execute with:** `gaspol-execute` (continuous; workspace is an isolated worktree)

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---|---|---|---|---|
| fix-commit detection | `git log --format=%s <BASE>..HEAD` | git | yes | read; keyword set reused from `gaspol-review/git-history-reviewer.md` |
| regression-test verdict | `.gaspol/progress/PROGRESS-<TICKET>.md` | file read | yes | new `regression-test:` line, written by `gaspol-debug` |
| ledger path resolution | `PROGRESS-<TICKET>.md` then `.gaspol/progress.md` | file read | yes | same fallback order `gaspol-execute` already uses |
| canvas contract | `docs/plans/*-<TICKET>-*-canvas.html` | glob | **no** | new format, defined in `visual-contract.md` |
| canvas geometry | Playwright MCP `browser_evaluate` on the canvas file | MCP | yes | extractor emitted by `geometry-diff --emit-extractor` |
| app geometry | Playwright MCP `browser_evaluate` on the running app | MCP | yes | same extractor, second run |
| geometry snapshots | `.gaspol/design/<TICKET>/{canvas,app}.json` | file write | **no** | gitignored (`.gaspol/` already ignored) |
| severity split by CSS role | `design_audit.py`'s existing structural/decorative table | constant | yes | reuse the same role names so the two scripts cannot disagree |

No placeholder path: every row is produced by a real script or a real MCP call, and the one gate
that can fail to run (`visual-diff`) reports itself as NOT RUN rather than as passed.

## Completeness Gate (coverage decided here, per `_shared/completeness-ladder.md`)

| Rung | Covered by |
|---|---|
| happy path | A1, B1 |
| every error path | unreadable ledger (exit 3), missing snapshot file, malformed JSON, missing `elements` key, zero-width viewport |
| every edge case | no commits in range; fix commit but ledger absent; `N/A` line; `not run` line; marker sets disjoint; identical snapshots; differing viewports; colour spelled three ways; a fluid element passing on ratio while failing on pixels |
| the tests that prove them | `test-regression-gate.sh`, `test-geometry-diff.sh`, plus `--self-test` inside each script |
| observability | every verdict names the file and the value on both sides — `hero.cta w 640 vs 610 (44.4% vs 44.7%) — within tolerance` |
| the WHY comment | each script header states its security invariant and the defect it was built for |

## Phases

### Phase A0 — repair the baseline before blaming a phase for it (added during execution)

The Verification Loop's baseline came back **RED, 31/35**, and the four reds were one defect
belonging to IDS-13, not pre-existing unrelated breakage:

1. Every caller of `marketplace-manifest` used `X="$(cmd)"; RC=$?`. Under `set -euo pipefail` the
   assignment *is* the simple command, so any non-zero exit terminates the caller there and the
   `case "$RC"` handling exit 3 and exit 4 is unreachable — while the script's own header requires
   callers to distinguish them. Green on `main` only because the sibling checkout is present there,
   so the answer was always state 1 and the two dead branches were never asked for.
2. `marketplace-manifest` resolved the sibling relative to its own location, so from
   `.claude/worktrees/<slug>` it looked for `.claude/worktrees/gaspol-one`. Every worktree-based
   ticket loses the cross-repo version gate.

Fixed together with a test that **runs** the callers under each forced state instead of reading
their prose — the `test-kb-state4-continues.sh` precedent, because a text assertion cannot catch a
control-flow bug.

**Verification:** `bash tests/ticket-scripts/test-marketplace-manifest-states.sh` exit 0; suite
36/36.

### Phase A1 — `regression-gate` script (TDD)

1. Write failing test for the regression gate's four exit states. Expected error:
   `bash: tests/ticket-scripts/test-regression-gate.sh: No such file or directory`, then once the
   test exists, `regression-gate: No such file or directory`.
2. Write `skills/gaspol-debug/scripts/regression-gate` — args `<BASE>` `[ledger-path]`, exits
   0/1/3/4, `--self-test`.
3. `chmod +x` **and** `git update-index --chmod=+x` — `core.fileMode=false` on this machine means
   the mode change never reaches the index otherwise. IDS-13 shipped two scripts as `100644` for
   exactly this reason and they failed only after a clean checkout.

**Verification:** `bash tests/ticket-scripts/test-regression-gate.sh` exit 0;
`skills/gaspol-debug/scripts/regression-gate --self-test` exit 0; full suite green.

### Phase A2 — `gaspol-debug` Phase 4 stops excusing itself

1. Write failing test for the absence of `(if possible)` and the presence of the three ledger
   states. Expected error: `FAIL: gaspol-debug still offers "(if possible)" as the default`.
2. Delete `(if possible)`; add the three-state table and the RED-before-GREEN requirement.

**Verification:** `bash tests/ticket-scripts/test-regression-gate.sh` exit 0.

### Phase A3 — wire the gate into its two callers

1. Write failing test asserting `gaspol-verify` Layer 1 and `gaspol-finish` Step 0 both invoke
   `regression-gate` through `$CLAUDE_PLUGIN_ROOT`. Expected error:
   `FAIL: gaspol-finish Step 0 does not run regression-gate`.
2. Add both invocations, anchored — `"$CLAUDE_PLUGIN_ROOT/skills/gaspol-debug/scripts/regression-gate"`
   with `${CLAUDE_PLUGIN_ROOT:?…}`, the form IDS-8 established. A new relative call site would add
   to the ~33 already deferred.

**Verification:** suite green; `test-kb-no-hardcoded-path.sh` still passes.

### Phase B1 — `geometry-diff` core (TDD)

1. Write failing test for: colour normalisation across three spellings; structural vs decorative
   severity; missing marker BLOCKS; extra marker WARNs; ratio-vs-pixel tolerance where the smaller
   deviation wins; exit 3 on malformed JSON; exit 4 on a missing canvas. Expected error:
   `python3: can't open file 'geometry-diff'`.
2. Write `skills/gaspol-verify/scripts/geometry-diff` — stdlib only.

**Verification:** `bash tests/ticket-scripts/test-geometry-diff.sh` exit 0;
`python3 skills/gaspol-verify/scripts/geometry-diff --self-test` exit 0.

### Phase B2 — `--emit-extractor`

1. Write failing test asserting the emitted JavaScript is a **literal** — no interpolation of any
   argument, and running the script with a hostile `--tolerance` value does not change a byte of
   the extractor. Expected error: `FAIL: --emit-extractor printed nothing`.
2. Emit the extractor; assert the round trip in `--self-test` by feeding its documented output
   shape straight back into the diff.

**Verification:** as above; the literalness assertion is the security-relevant one.

### Phase B3 — `skills/_shared/visual-contract.md`

1. Write failing test for the five required statements: `data-vv` naming, markup in the target
   stack, worst-case content, the canvas file path, and the explicit list of IDS-6 Part B items
   **not** built here. Expected error: `FAIL: visual-contract.md is missing`.
2. Write the file.

**Verification:** `bash tests/ticket-scripts/test-geometry-diff.sh` exit 0.

### Phase B4 — wire into the web lane only

1. Write failing test asserting `live-app-check.md` runs the diff on the web lane, states the
   mobile lane is excluded **and why**, and lists the three `visual-diff:` outcome lines. Expected
   error: `FAIL: live-app-check.md web lane does not run geometry-diff`.
2. Add the web-lane step, the mobile-lane exclusion with its reason, and the outcome vocabulary.
   Add the `visual-diff:` line to `gaspol-verify` Layer 4 beside `design-contract:`.

**Verification:** `test-live-app-check.sh` and `test-geometry-diff.sh` both exit 0.

### Phase C1 — docs sync + release

1. Write failing test for version agreement at 1.24.0 across `plugin.json`, `CLAUDE.md`, and the
   gaspol-one manifest. Expected error: `FAIL: version string mismatch`.
2. CLAUDE.md: Architecture rows for the two scripts and `visual-contract.md`; a section for each
   part naming what is **not** closed; ticket counter to IDS-14. README release row. Version
   1.24.0 in `plugin.json` and in gaspol-one's `marketplace.json`.
3. Raise `test-execute-trim.sh`'s ceiling only if a gate was added to `gaspol-execute` — it was
   not, so it must stay unchanged. Note it in the ledger either way.

**Verification:** full `tests/ticket-scripts/` suite green; `test-naming-convention.sh` version
block passes against the sibling manifest.

## Verification Loop (per `_shared/verification-loop.md`)

`detect-stack` prints nothing here — a skills repository has no stack markers — so the
plan-declared command stands in, recorded explicitly rather than skipped:

```bash
for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done
```

Baseline captured before Phase A1. A red baseline STOPs and asks rather than being absorbed into
the first phase.
