> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-16.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat. Every file path, contract, config key, and convention it needs is written here **verbatim**, not merely referenced.

**Ticket:** IDS-16
**Ledger:** .gaspol/progress/PROGRESS-IDS-16.md
**Spec:** docs/plans/2026-08-23-IDS-16-design-artifact-offer-spec.md

## Goal

Turn `gaspol-plan`'s BLOCKING design-artifact gate into a single merged offer presented after the
plan is written, with declining recorded in the ledger as `design-artifact: skipped — <reason>`
where the reason may not be empty. Along the way, close three defects found while reading the gate:
`ui-ux-pro-max` invokable three times for one feature, UI work never receiving the five-section
logic treatment, and `gaspol-auto` being a documented execution mode that `gaspol-plan` never
offers.

**One addition beyond the spec, flagged rather than slipped in.** The spec describes the two-tab
artifact in prose. This plan puts a concrete HTML skeleton **inside** `logic-design-artifact.md`
(a fenced code block in the existing contract file — no new file is created) and proves it renders
before anything is built on it. Reason: this repository's recurring defect is a rule stated in
prose with no machine behind it — IDS-7's design gate that was never wired up, IDS-8's setting
nothing read, IDS-13's live check with no detector. "Two tabs" as prose alone is the same shape. If
you would rather keep the plan strictly to the spec, drop Phase A and Phase B's skeleton assertion;
nothing else depends on them.

## Architecture Context

Pulled from this repository's CLAUDE.md and verified by reading the files:

- **Ledger** — `.gaspol/progress/PROGRESS-<TICKET>.md`, gitignored via `.gitignore:13` (`.gaspol/`).
  Structure: header fields, then free-standing `key: value` lines, then `## Checklist`, then
  `## Log` which is ALWAYS the last block (`scan-active-ledgers` reads the last non-empty line).
- **The artifact gate today** — `skills/gaspol-plan/SKILL.md:313-349` under `## Execution Handoff`,
  headed `**Step 0 — Design Artifact (BLOCKING)**`. Its two-lane table at line 327 routes UI work
  to a mockup and everything else to `skills/gaspol-plan/logic-design-artifact.md`.
- **The stale contradiction** — `skills/gaspol-plan/SKILL.md:127`, an HTML comment on the
  `**Artifact:**` header field calling it `optional — present ONLY when the Execution Handoff
  artifact offer was accepted and rendered`. Predates v1.20.
- **The reader** — `skills/gaspol-execute/SKILL.md:203-214`, `## Design Artifact Gate (BLOCKING —
  before Phase A, before any code)`, a three-row table where a missing line means STOP.
- **Brainstorm's promise** — `skills/gaspol-brainstorm/SKILL.md:265-271`, Phase 2.5's non-UI branch,
  which states `gaspol-plan Step 0 will produce the logic design artifact`.
- **The three `ui-ux-pro-max` invocation points** — `gaspol-brainstorm/SKILL.md:692` (Phase 3),
  `gaspol-plan/SKILL.md:261` (Design Deliverable column), `gaspol-plan/SKILL.md:327` (Step 0 UI lane).
- **The test that locks the old decision** — `tests/ticket-scripts/test-logic-design-artifact.sh`.
  Of its 12 assertions, exactly ONE breaks under this change: line 53,
  `has "$PLAN" "Design Artifact (BLOCKING)"`. Verified by reading every assertion:
  `design-artifact: pending` (line 62) survives, `STOP and ask` in execute (line 77) survives, and
  the `not applicable` prohibition (line 63) is not violated because the new fourth state is named
  `none`, not `n/a`.
- **Version** — `.claude-plugin/plugin.json` is at `1.24.0`; `README.md:7` carries version, skill,
  agent and test-count badges. The marketplace manifest lives in the SIBLING repo `gaspol-one` and
  is resolved by `tests/ticket-scripts/marketplace-manifest` (exit 0 available / 3 UNKNOWN / 4 none).

## Tech Stack

Markdown skill files and bash test scripts. No application code, no package manager.

`skills/gaspol-execute/scripts/detect-stack .` prints **zero lines** — this repository has no stack
marker files (no `package.json`, `composer.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`,
`pubspec.yaml`). Per `gaspol-plan`'s rule for that case, every phase's Verification block therefore
declares its own commands and records:

```text
detect-stack: no stack markers for this project — verification is plan-declared only
```

**The plan-declared verification command, used verbatim in every phase below:**

```bash
for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done
```

Run it from the repository root. It must exit 0 with no `FAIL:` line on stderr.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-------------|----------|---------|--------|
| Artifact tab skeleton | authored HTML, inline in the contract file | `skills/gaspol-plan/logic-design-artifact.md` | No | Create as a fenced block in the existing file |
| Mockup content for the Design tab | `ui-ux-pro-max` skill output | Skill tool | Yes | Invoke once, at the offer point only |
| Five-section contract | `skills/gaspol-plan/logic-design-artifact.md` | file read | Yes | Extend, do not rewrite |
| Offer modal | `AskUserQuestion` tool | harness built-in | Yes | Use directly |
| Artifact publish + URL | `Artifact` tool | harness built-in | Yes | Use directly |
| Ledger line | `.gaspol/progress/PROGRESS-IDS-16.md` | file write | Yes (created by this plan) | Append above `## Log` |
| UI detection signal | file extensions `.tsx .jsx .vue .svelte .astro .css .scss .sass` | `skills/gaspol-plan/SKILL.md:252` | Yes | Reuse — do NOT author a second detector |
| Execution modes offered | `gaspol-execute`, `gaspol-auto`, `gaspol-parallel` | Skill tool | Yes | All three offered; `gaspol-auto` unconditionally |
| External executor command | `$GASPOL_EXECUTOR`, then `.gaspol/executor` first line | env / file read | Conditional | Offer the option ONLY when one resolves |
| Version consistency check | `tests/ticket-scripts/marketplace-manifest` | script, exit 0/3/4 | Yes | Use its three states; never conflate 3 with 4 |

## Completeness Gate — what each phase owes

Walked per phase before writing it, per `skills/_shared/completeness-ladder.md`:

- **Error paths that can actually happen here:** the user declines the artifact and gives an empty
  reason; `ui-ux-pro-max` is not installed; the mockup HTML contains characters that break an
  `srcdoc` attribute; `marketplace-manifest` returns 3 (UNKNOWN) rather than 0 or 4. Each is a step
  below, not a footnote.
- **Edge cases enumerated, not sampled:** zero phases in a plan; a plan with UI phases only; a plan
  with no UI phases; an artifact declined then later rendered; a ledger that already carries a
  `design-artifact:` line from a previous run.
- **Observability:** every gate decision writes one machine-greppable ledger line. That is what a
  later reader has; nothing else records it.
- **Not applicable, with reason:** no runtime logging, metrics or tracing — this ticket ships no
  executable code beyond bash test assertions, so there is no process to observe at runtime.

---

### Phase A: Prove the two-tab artifact renders isolated

**Estimated time:** 12 minutes

**Files:**
- Modify: `skills/gaspol-plan/logic-design-artifact.md` (add one fenced `html` block — the skeleton)
- Create: `tests/ticket-scripts/test-artifact-tabs.sh`

**Why first:** the whole two-tab design rests on an unverified assumption — that `<iframe srcdoc>`
renders inside a published Artifact and isolates the mockup's CSS from the page's. If it does not,
the contract written in Phase B would be wrong, so this is proved against a real published page
before anything depends on it.

**Steps:**
1. Write failing test for the tab skeleton's presence in the contract. Expected error: `FAIL: logic-design-artifact.md carries no <iframe srcdoc> tab skeleton`.
2. Run `bash tests/ticket-scripts/test-artifact-tabs.sh`, confirm it fails for that reason and not a syntax error.
3. Write the skeleton into `logic-design-artifact.md` as a fenced ```html block: a `<title>`, two `<button role="tab">` controls, two `<div role="tabpanel">` panels, the Design panel containing `<iframe srcdoc="…" title="Mockup">`, plain-CSS/JS tab switching with **no external URL of any kind** (the artifact CSP blocks external hosts).
4. Add the remaining assertions to the test: exactly two `role="tabpanel"` occurrences, an `iframe` with `srcdoc`, a `<title>` element, and **zero** occurrences of `http://` or `https://` outside a code comment.
5. Run the test, confirm it passes.
6. **Prove it live, not by reading:** publish a throwaway page built from the skeleton with the `Artifact` tool, containing a mockup fragment whose CSS deliberately collides (`body { background: red }`, `.tab { display: none }`). Open the published URL and confirm the artifact chrome is unaffected and both tabs switch.
7. Record the outcome in the ledger as `tab-isolation: proven — <url>` or, if it failed, `tab-isolation: FAILED — <what happened>` and **STOP and ask** before continuing; the fallback is scoped CSS with a generated prefix, which changes Phase B's contract.
8. Run the full suite.
9. Commit: `feat: two-tab artifact skeleton, proven against a published page (IDS-16 Phase A)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `bash tests/ticket-scripts/test-artifact-tabs.sh` passes
- [ ] A real published artifact URL is recorded in the ledger, and the colliding-CSS mockup did NOT alter the page chrome
- [ ] The skeleton contains no `http://` or `https://` reference
- [ ] No placeholder/TODO comments in the new test or the skeleton

---

### Phase B: The contract gains tabs, the tab-count rule, and the language rule

**Estimated time:** 12 minutes

**Files:**
- Modify: `skills/gaspol-plan/logic-design-artifact.md`
- Modify: `tests/ticket-scripts/test-logic-design-artifact.sh`

**Steps:**
1. Write failing test for the tab-count rule in the contract. Expected error: `FAIL: the contract does not state that a UI-touching change gets two tabs and a logic-only change gets one`.
2. Run the suite, confirm ONLY that new assertion fails.
3. Write into `logic-design-artifact.md`: the tab-count rule (UI-touching → Design + Logic tabs; otherwise → Logic tab alone; the Logic tab is ALWAYS present); the UI signal is the extension list already in `skills/gaspol-plan/SKILL.md:252` — `.tsx .jsx .vue .svelte .astro .css .scss .sass` — quoted verbatim and explicitly NOT a second detector.
4. Write the language rule: artifact prose is plain Indonesian, short sentences, one idea each. Technical terms stay English in two classes — (a) literals: file names, tool names, CLI commands, skill names, error strings, variable names, config keys; (b) ordinary technical vocabulary such as `framework`, `hardisk`, `cache`, `deploy`, `commit`, `branch`, `endpoint`, `query`, `build`, whose Indonesian dictionary equivalents make the sentence slower to read, not easier. State the test for borderline terms: not "does an Indonesian word exist" but "which form does the reader recognise faster".
5. Write the `srcdoc` escaping rule: the mockup HTML is embedded in an attribute, so `"` and `&` must be escaped; a mockup that cannot be escaped safely is embedded as an inline `<style>`-scoped block instead, and that decision is recorded.
6. Add assertions for the tab-count rule, the language rule (both classes), and the escaping rule.
7. Run the suite, confirm green.
8. Commit: `feat: artifact contract gains tab count, language, and srcdoc escaping rules (IDS-16 Phase B)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The contract names both technical-term classes, with at least `framework` and `hardisk` as worked examples
- [ ] The contract quotes the extension list rather than defining a new one
- [ ] The five existing mandatory sections are still asserted and still present
- [ ] No placeholder/TODO comments in new content

---

### Phase C: `gaspol-plan` — one merged offer, two-lane table deleted

**Estimated time:** 15 minutes

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md`
- Modify: `tests/ticket-scripts/test-logic-design-artifact.sh`

**Steps:**
1. Write failing test for the merged offer replacing the BLOCKING gate. Expected error: `FAIL: gaspol-plan still presents Step 0 as a BLOCKING gate instead of an offer`.
2. Invert line 53's assertion: `has "$PLAN" "Design Artifact (BLOCKING)"` becomes a prohibition, plus a new positive assertion that the offer lists all of `gaspol-execute`, `gaspol-auto`, `gaspol-parallel`.
3. Run the suite, confirm ONLY the new assertions fail.
4. Rewrite `skills/gaspol-plan/SKILL.md:313-349`: one `AskUserQuestion` after the plan file AND ledger are written, offering — `[Render design artifact dulu]`, `[Eksekusi di sesi ini]` (gaspol-execute), `[Eksekusi otomatis]` (gaspol-auto, offered on EVERY plan), `[Eksekusi parallel]` (only when independent phases exist), `[Simpan buat sesi lain]`, `[Serahkan ke executor luar]` (only when `$GASPOL_EXECUTOR` or the first line of `.gaspol/executor` resolves).
5. Write the reason rule verbatim: the four options that START EXECUTION write `design-artifact: skipped — <reason>` with a non-empty reason; `[Simpan buat sesi lain]` writes NO line because nothing executed. State the cost plainly: a later session resuming through `gaspol-execute` will not see the offer again — only re-entering `gaspol-plan` presents it.
6. Delete the two-lane table at line 327 and replace it with a pointer to the contract's tab-count rule.
7. Fix the stale header comment at line 127 so it no longer contradicts the body.
8. Change the Design Deliverable column (lines 252-261) from `produced by invoking the ui-ux-pro-max skill during plan creation` to citing the decisions `gaspol-brainstorm` Phase 3 already produced; state that `ui-ux-pro-max` is invoked at most ONCE per ticket, at the offer point, and only when brainstorm never ran.
9. Add assertions: the reason rule, the save-for-later exemption, the single-invocation rule, and that `design-artifact: pending` still exists.
10. Run the suite, confirm green.
11. Commit: `feat: gaspol-plan's artifact gate becomes one merged offer including gaspol-auto (IDS-16 Phase C)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `grep -c "Design Artifact (BLOCKING)" skills/gaspol-plan/SKILL.md` returns 0
- [ ] The offer names `gaspol-auto` and states it is offered on every plan
- [ ] The two-lane UI-vs-logic table is gone
- [ ] Line 127's comment and the body agree
- [ ] No placeholder/TODO comments in new content

---

### Phase D: `gaspol-execute` reads four states and never offers

**Estimated time:** 10 minutes

**Files:**
- Modify: `skills/gaspol-execute/SKILL.md`
- Modify: `tests/ticket-scripts/test-logic-design-artifact.sh`

**Steps:**
1. Write failing test for the fourth ledger state. Expected error: `FAIL: gaspol-execute does not define the 'skipped' artifact state`.
2. Run the suite, confirm ONLY that assertion fails.
3. Rewrite `skills/gaspol-execute/SKILL.md:203-214` as a four-row table: `approved — <url>` → proceed; `pending — <url>` → STOP and ask; `skipped — <reason>` → proceed; no line → proceed and record `design-artifact: none — no offer was made`.
4. State explicitly that `gaspol-execute` NEVER presents the offer, and why the missing-line row proceeds rather than stopping: the offer exists only in `gaspol-plan`, so stopping here would send the user to a question that is not asked there.
5. State that a `skipped` line whose reason is empty is treated as `pending` — STOP and ask. An empty reason is not a decision.
6. Add assertions for all four rows, for the never-offers rule, and for the empty-reason rule. Keep the existing `STOP and ask` assertion satisfied by the `pending` row.
7. Run the suite, confirm green.
8. Commit: `feat: gaspol-execute reads four artifact states and never offers (IDS-16 Phase D)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] All four states appear in `skills/gaspol-execute/SKILL.md`
- [ ] The `pending` row still STOPs, so the pre-existing assertion at line 77 still passes
- [ ] An empty `skipped` reason is documented as STOP, not as proceed
- [ ] No placeholder/TODO comments in new content

---

### Phase E: `gaspol-brainstorm` stops promising what it no longer guarantees

**Estimated time:** 8 minutes

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md`
- Modify: `tests/ticket-scripts/test-logic-design-artifact.sh`

**Steps:**
1. Write failing test for the corrected promise. Expected error: `FAIL: brainstorm Phase 2.5 still promises gaspol-plan Step 0 WILL produce the artifact`.
2. Run the suite, confirm ONLY that assertion fails.
3. Change Phase 2.5 (lines 265-271): `gaspol-plan Step 0 will produce the logic design artifact` becomes `gaspol-plan will OFFER the logic design artifact once the plan is written`. Keep the literal phrase `logic design artifact` — the pre-existing assertion at line 70 greps for it.
4. Change Phase 3 (around line 692) to state that it produces design DECISIONS as text — palette, font pairing, layout blueprint, motion, accessibility — and that the mockup file itself is rendered later, once, at `gaspol-plan`'s offer. Keep the `ui-ux-pro-max` invocation itself unchanged.
5. Add assertions: the word `offer` in the Phase 2.5 branch, and that Phase 3 does not claim to render a mockup file.
6. Confirm `[No, pure backend/logic]` is still absent so line 68's prohibition still holds.
7. Run the suite, confirm green.
8. Commit: `fix: brainstorm offers rather than promises the logic design artifact (IDS-16 Phase E)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The literal phrase `logic design artifact` still appears in `skills/gaspol-brainstorm/SKILL.md`
- [ ] `grep -c '\[No, pure backend/logic\]' skills/gaspol-brainstorm/SKILL.md` returns 0
- [ ] No placeholder/TODO comments in new content

---

### Phase F: Documentation, the recorded gap, and 1.25.0

**Estimated time:** 15 minutes

**Files:**
- Modify: `CLAUDE.md`, `README.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`
- Modify: the sibling `gaspol-one` marketplace manifest, resolved via `tests/ticket-scripts/marketplace-manifest`

**Steps:**
1. Write failing test for the version bump. Expected error: `FAIL: plugin.json is 1.24.0, expected 1.25.0`. (Use the existing version-consistency assertions in `tests/ticket-scripts/test-naming-convention.sh` rather than authoring a parallel check.)
2. Run the suite, confirm ONLY that assertion fails.
3. Rewrite CLAUDE.md's `### Design Artifact Gate (NEW in v1.20)` section: it is now an offer, the four states, the tab-count rule, the single `ui-ux-pro-max` invocation point, and the plain-Indonesian requirement. State plainly what was given up — UI work reaching `gaspol-plan` without a brainstorm can now decline design entirely, which was impossible from IDS-10 to IDS-15.
4. Record the `gaspol-debug` gap in CLAUDE.md: a bug fix that changes the UI passes no design point in any path. **Mint no ticket number** — this repository's convention refuses an id that points at no spec.
5. Correct `README.md:48` and `README.md:129`, which both claim the gate is BLOCKING. Update the badges: version to 1.25.0 and the deterministic-test count to its real value after this ticket (count the files, do not guess).
6. Add the `[1.25.0]` CHANGELOG entry.
7. Set `.claude-plugin/plugin.json` to `1.25.0`, and update the matching entry in the sibling marketplace. Resolve it with `rc=0; path="$(tests/ticket-scripts/marketplace-manifest)" || rc=$?` — never `path=...; rc=$?`, which terminates under `set -e`. Honour all three exit codes: 0 update it, **3 STOP and ask** (configured but unreadable), 4 record `marketplace: none — not configured` and continue.
8. Run the suite, confirm green.
9. Commit: `docs: release 1.25.0 — artifact gate becomes an offer (IDS-16 Phase F)`

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] `.claude-plugin/plugin.json`, CLAUDE.md's version line and the README badge all read 1.25.0
- [ ] The README test-count badge equals `ls tests/ticket-scripts/*.sh | wc -l`
- [ ] Neither README.md:48 nor README.md:129 still calls the gate BLOCKING
- [ ] The `gaspol-debug` gap is recorded with NO ticket id attached
- [ ] `marketplace-manifest`'s exit code was handled by its own value, and the outcome is written in the ledger
- [ ] No placeholder/TODO comments in new content

---

## Out of scope

- Adding a design gate to `gaspol-debug` — recorded in Phase F, deliberately not closed.
- Any change to `skills/gaspol-brainstorm/visual-companion.md` or its vendored server.
- Publishing the mockup as a second, separate artifact — the two-tab layout replaces it.
- The eight scripts still invoked by relative path (`detect-stack`, `task-brief`, `dag-lanes`,
  `review-package`, `next-ticket`, `scan-active-ledgers`, `design_audit.py`,
  `extract-design-tokens`) — a known open hazard from IDS-8, untouched here.
