> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-21.md` (created by `gaspol-plan` at plan-write time). After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate. **Never batch all updates at the end.** Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec for an executor with **no other context**. Every path, string and convention it needs is written here verbatim.

**Ticket:** IDS-21
**Ledger:** .gaspol/progress/PROGRESS-IDS-21.md
**Spec:** docs/plans/2026-10-24-IDS-21-single-owner-gates-spec.md

## Goal

Cut the token cost of a gaspol ticket without removing a guarantee: (A) every end-of-ticket gate
(`gaspol-verify` full, `plan-verifier`, Tier 1 review, `gaspol-sync-docs`) has exactly ONE owner,
`gaspol-finish`, instead of running in `gaspol-execute` Step 7 / `gaspol-auto` post-run and again in
finish; (B) delete the `gaspol-learn` skill and every live reference to it; (C) make `gaspol-research`
gather with Firecrawl and synthesize with the `notebooklm` CLI, stopping (not falling back) when either
is unavailable. Released as v1.30.0.

## Architecture Context

Read from `CLAUDE.md` (this repo is a Claude Code plugin; the executed surface is markdown + bash):

- Skills: `skills/<name>/SKILL.md`; shared rules `skills/_shared/*.md`; agents `agents/*.md`; session hook `hooks/session-start.sh`.
- Tests: bash, `tests/ticket-scripts/*.sh`, run with `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. They read skill TEXT (e.g. `test-finish-gates.sh`, `test-finish-fix-loop.sh`, `test-execute-trim.sh`, `test-plan-verifier-spec.sh`) — changing prose can break them; each broken assertion is updated deliberately, with the reason in a comment, never deleted silently.
- Ledger convention (v1.29.2, commit `3dc18e6`): commit SHAs in the ledger are always in backticks. `skills/gaspol-verify/scripts/ledger-gate` reads the ledger; any new ledger line this plan introduces must not break it (Phase B verifies with a fixture).
- Fix-loop bound lives only in `skills/_shared/fix-loop.md`; do not restate its round cap.
- Finish offer text lives only in `skills/_shared/finish-offer.md`; do not restate it.
- Model rule (`docs/rubric-model-switching.md`, enforced by `skills/gaspol-verify/scripts/model-gate`): Opus judges, Sonnet works; no third tier; a file the gate cannot classify declares `model-tier:`. `skills/gaspol-research/SKILL.md` line 6 already carries `<!-- model-tier: exec ... -->`.
- Working-tree state at plan time: `skills/gaspol-finish/SKILL.md` and `skills/gaspol-auto/SKILL.md` hold uncommitted edits from `docs/proposals/2026-10-24-reuse-verification-at-same-head.md`; `docs/proposals/` and `CLAUDE.md` (ticket counter → IDS-21) are also uncommitted. Phase B supersedes the `gaspol-auto` edit (revert it) and rewrites the `gaspol-finish` edit.

## Tech Stack

Markdown skills, bash tests, `git`. External tools used by Phase C: `notebooklm` CLI (`~/.local/bin/notebooklm`, already logged in) and the Firecrawl MCP (`firecrawl_search`, `firecrawl_scrape`). No new dependency. `detect-stack .` prints **no lines** for this repo.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
| Reuse of finish verdicts | ledger `## Log` lines `verified: PASS @ <sha>`, `plan-verifier: CLEAN @ <sha>` | `git rev-parse HEAD`, `git status --porcelain` | Yes (ledger + git) | New line formats only, written/read by `gaspol-finish` |
| Ledger shape safety | `skills/gaspol-verify/scripts/ledger-gate` | exit 0/1/3/4 contract | Yes | Run against a fixture carrying the new lines; do not modify the script |
| gaspol-learn removal proof | repo files | `grep` | Yes | New test `test-learn-removed.sh` |
| Research source collection | Firecrawl MCP | `firecrawl_search`, `firecrawl_scrape` (`maxAge: 0`) | Yes (MCP connected) | Replace `WebFetch`/`WebSearch` instructions in skill text |
| Research synthesis | `notebooklm` CLI | `create`, `source add`, `source wait`, `ask`, `list`, `status`, `doctor` | Yes (installed, logged in) | Replace Sonnet gather subagents in skill text |
| Skill-text assertions | `skills/**/SKILL.md` | bash `grep` | Yes | New tests `test-single-owner-gates.sh`, `test-research-tools.sh` |

Nothing here is a placeholder: every row is an existing tool or file.

## Decisions recorded for the ledger (`## Keputusan saat jalan`)

- Owner approved in brainstorm (2026-10-24): scope "one gate, one place"; owner of full verify + `plan-verifier` is `gaspol-finish`; Tier 1 review skipped when `plan-verifier` CLEAN at HEAD (mandatory with no plan); per-phase auto-review only on big triggers; delete `gaspol-learn`; research STOPs and asks when `notebooklm`/Firecrawl is unavailable.
- Planner extension (needs no new approval, flagged for the owner): `gaspol-execute` Step 7 also ran `gaspol-verify`, `gaspol-sync-docs` and `gaspol-review`, all of which `gaspol-finish` owns too. "One owner" means all four leave Step 7, not only `plan-verifier`.

## Out of scope

Shrinking large skill texts; the gaspol-one marketplace entry and its README version table (separate repo, updated after release); measuring token savings automatically (no such harness exists).

---

### Phase A: Delete gaspol-learn and every live reference

**Estimated time:** 15 minutes

**Files:**
- Delete: `skills/gaspol-learn/` (whole directory)
- Modify: `skills/gaspol-finish/SKILL.md` (lines naming `gaspol-learn`: ~36, ~169, ~197-, ~253, ~451)
- Modify: `skills/gaspol-debug/SKILL.md` (~309), `skills/gaspol-adr/SKILL.md` (~240), `skills/gaspol-research/SKILL.md` (~229), `skills/gaspol-brainstorm/SKILL.md` (~473), `skills/using-gaspol/SKILL.md` (~78), `skills/_shared/kb-path.md` (~4), `skills/gaspol-verify/rules/reasoning-gaspol.md` (~82)
- Modify: `agents/plan-verifier.md` (~376), `hooks/session-start.sh` (~34), `rules/AGENTS.md` (~28)
- Modify: `README.md` (~90, ~281, ~327-328, ~479), `docs/kb-setup.md` (~14), `docs/rubric-model-switching.md` (~41, ~116)
- Modify: `tests/ticket-scripts/test-finish-fix-loop.sh` (~102-106), `test-kb-git-guard.sh` (~34, ~62), `test-kb-write-format.sh` (~27, ~43, ~84), `test-kb-state4-continues.sh` (~12, ~35, ~41), `test-kb-no-hardcoded-path.sh` (~150), `test-finish-gates.sh` (~181 comment), `test-model-gate.sh` (~183 comment), `tests/README.md` (~26), `tests/skill-triggering/run-all.sh` (~19)
- Modify: `CLAUDE.md` (Architecture row ~88, routing row ~146, ~83, ~208, ~259, ~280, ~543, ~1062, ~1256, ~1463, ~1589)
- Test: `tests/ticket-scripts/test-learn-removed.sh` (create)

**Steps:**
1. Write failing test for the removal of gaspol-learn in `tests/ticket-scripts/test-learn-removed.sh`. Expected error: `FAIL: skills/gaspol-learn still exists`.
   The test asserts (each with its own `fail "<message>"`): (a) `skills/gaspol-learn` does not exist; (b) no file under `skills/`, `agents/`, `hooks/`, `rules/`, `tests/` (excluding this test file itself), plus `README.md` and `docs/*.md` (NOT `docs/plans/`, `docs/proposals/`) contains the string `gaspol-learn`; (c) `CLAUDE.md` has no table row starting `` | `skills/gaspol-learn `` and no row starting `| Capture patterns after shipping |`; (d) `hooks/session-start.sh` and `skills/using-gaspol/SKILL.md` list no "capture patterns after shipping" route; (e) positive control: `gaspol-adr` and `gaspol-research` still exist and still mention writing to the KB, so the test cannot pass on an empty repo. Use `set -u`, no `set -e` around `grep` pipelines (a no-match `grep` returning 1 aborts silently under `pipefail` — capture into a variable first, per the repo's recorded incidents).
2. Run the new test, confirm it fails for the expected reason (`bash tests/ticket-scripts/test-learn-removed.sh`).
3. `git rm -r skills/gaspol-learn`. Then edit each live reference listed under **Files**:
   - `gaspol-finish`: the post-chain modal keeps ONE offer, `/security-review`, as `AskUserQuestion` options `[Jalankan /security-review]` / `[Lewati]`; delete the `### gaspol-learn` subsection, the `gaspol-learn : [Jalankan] [Lewati]` line, the report line `[x] gaspol-learn: ...`, and the integration-table row. Reword the "Two further checks ... offered" sentence to one check. Keep the "declining records nothing" statement for `/security-review`.
   - `gaspol-debug` ~309: delete the sentence telling the reader to capture via `gaspol-learn` (a one-line pattern worth keeping goes to `gaspol-adr` only if it is a decision; otherwise drop).
   - Table rows in `gaspol-adr`, `gaspol-research`, `plan-verifier`, `using-gaspol`, `AGENTS.md`, hook text: delete the row/line.
   - `kb-path.md`, `kb-setup.md`, `brainstorm` ~473, `reasoning-gaspol.md`: remove the name from the writer lists (writers are now `gaspol-adr` and `gaspol-research`).
   - `docs/rubric-model-switching.md`: delete the "Learn capture" row (~41) and the `gaspol-learn` mention in the model-tier-declaration paragraph (~116), leaving `gaspol-research` as the example.
   - `README.md`: skill count and list, finish description (~90), examples (~327-328), KB sentence (~479).
   - `CLAUDE.md`: delete the Architecture row and routing row; fix every remaining sentence that states `gaspol-learn` exists or is offered (lines ~83, ~208, ~259, ~280, ~1062, ~1256, ~1463, ~1589); "17 development skills" → "16"; leave historical narrative only where it is plainly past tense, and add one short note: `gaspol-learn` was deleted in v1.30.0 (IDS-21) — owner judged it had no function; KB writes remain via `gaspol-adr` and `gaspol-research`.
4. Update the tests that named it, each with a comment citing IDS-21: `test-finish-fix-loop.sh` loop becomes `for offered in "/security-review"`; the `kb-*` tests drop `gaspol-learn` from their skill lists (`SKILLS=(gaspol-adr gaspol-research)`, `must_create` keeps `gaspol-adr`), and `test-kb-write-format.sh` drops the `LEARN` assertions; comments in `test-finish-gates.sh`, `test-model-gate.sh`, `tests/README.md`, `run-all.sh` are reworded. Do NOT weaken any assertion that still applies to `gaspol-adr`/`gaspol-research`.
5. Run `bash tests/ticket-scripts/test-learn-removed.sh`, then each edited test individually: `test-finish-fix-loop.sh`, `test-finish-gates.sh`, `test-kb-git-guard.sh`, `test-kb-write-format.sh`, `test-kb-state4-continues.sh`, `test-kb-no-hardcoded-path.sh`, `test-model-gate.sh`, `test-skill-frontmatter.sh`, `test-ids8-docs.sh`. All must exit 0. A failure caused by prose now removed on purpose is fixed in the test with a reason; a failure caused by an accidental deletion is fixed in the skill.
6. Error path: a deleted skill still routable. Run `grep -rn "gaspol-learn" skills agents hooks rules README.md docs/*.md tests CLAUDE.md` and paste the remaining hits into the checkpoint report; every hit must be the sanctioned `CLAUDE.md` removal/past-tense note or this test file's own string.
7. Observability / why-comment: the removal note in `CLAUDE.md` is the one comment explaining WHY; the test file's header comment states that a deleted skill leaving a routing row is the failure it guards.
8. Commit: `feat(gaspol-dev): delete gaspol-learn (IDS-21)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-learn-removed.sh` exits 0
- [ ] `bash tests/ticket-scripts/test-finish-fix-loop.sh`, `test-finish-gates.sh`, `test-kb-git-guard.sh`, `test-kb-write-format.sh`, `test-kb-state4-continues.sh`, `test-kb-no-hardcoded-path.sh`, `test-model-gate.sh`, `test-skill-frontmatter.sh` each exit 0
- [ ] `grep -rn "gaspol-learn" skills agents hooks rules` returns nothing
- [ ] No weakened assertion: `git diff tests/` shows only `gaspol-learn` removals and IDS-21 comments
- [ ] No placeholder/TODO comments in new code

---

### Phase B: One owner per gate (gaspol-finish), drop duplicates in execute and auto

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-finish/SKILL.md` (Steps 1-3, fix-loop note, ledger lines)
- Modify: `skills/gaspol-execute/SKILL.md` (Step 7 "Auto-Invoke Verification Chain", plus any later mention that Step 7 runs `plan-verifier`; Step 8 stays)
- Modify: `skills/gaspol-auto/SKILL.md` (post-run section ~lines 110-150, the comparison table ~193, hard-stop table ~209, integration table ~219-222, checklist ~242-246) — start from `git checkout -- skills/gaspol-auto/SKILL.md` to drop the uncommitted proposal edit
- Modify: `skills/_shared/finish-offer.md` only if it names the removed chain (read first; edit only a stale sentence)
- Modify: `docs/proposals/2026-10-24-reuse-verification-at-same-head.md` (header `Status:` line only)
- Test: `tests/ticket-scripts/test-single-owner-gates.sh` (create)

**Steps:**
1. Write failing test for the single-owner gate wording in `tests/ticket-scripts/test-single-owner-gates.sh`. Expected error: `FAIL: gaspol-execute Step 7 still dispatches plan-verifier`.
   Assertions, each reading the real files (extract sections with `awk` between headings, then `grep` the captured variable): (a) the text of `gaspol-execute` between `### Step 7` and `### Step 8` contains none of `plan-verifier`, `gaspol-verify`, `gaspol-review`, `gaspol-sync-docs` as a thing to run, and DOES name `gaspol-finish` as the owner; (b) the `gaspol-auto` post-run section contains no dispatch of `plan-verifier` or `gaspol-verify` and still ends in the finish offer (`_shared/finish-offer.md`); (c) `gaspol-finish` contains the literals `verified: PASS @`, `plan-verifier: CLEAN @`, `git rev-parse HEAD`, a clean-tree condition (`git status --porcelain`), `never` + `memory` (read from ledger, not memory), `<SHA>..HEAD` inside the `plan-verifier` re-run sentence, `gaspol-review: skipped — plan-verifier CLEAN @`, and a sentence making the review mandatory when there is no plan; (d) positive control: the four mandatory step names (`gaspol-verify`, `plan-verifier`, `gaspol-review`, `gaspol-sync-docs`) still appear in finish's mandatory chain; (e) no assertion that restates the fix-loop round cap number (that lives in `fix-loop.md`).
2. Run the new test, confirm it fails for the expected reason.
3. `git checkout -- skills/gaspol-auto/SKILL.md`, then edit `gaspol-auto`: post-run keeps "compile report" and "present the finish offer"; the verify chain and `plan-verifier` dispatch are removed; the report states in plain words that the gates run in `gaspol-finish` and nothing is yet verified beyond per-phase ladders; update every table/checklist row that listed `plan-verifier`/`gaspol-verify` as a post-run step so none claims it runs there. `gaspol-auto`'s hard-stop list and pre-flight gate are untouched.
4. Edit `gaspol-execute` Step 7: retitle to "Hand Off to gaspol-finish"; list that `gaspol-verify` (full), `plan-verifier`, `gaspol-review` and `gaspol-sync-docs` are owned and run once by `gaspol-finish`; keep the Completion Gate and the per-phase ladder; Step 8 (finish offer) unchanged. Search the rest of the file and `skills/_shared/*.md` for sentences that still say Step 7 runs `plan-verifier` and fix them.
5. Edit `gaspol-finish`: replace the working-tree proposal wording with this contract. Step 1 and Step 2 run `gaspol-verify` and `plan-verifier`; after a pass each appends its line to `## Log` (`verified: PASS @ <sha>`, `plan-verifier: CLEAN @ <sha>`; follow the backtick convention of commit `3dc18e6` for the SHA). On a later entry (e.g. after `[Nanti]`) a line is reused ONLY when its sha equals `git rev-parse HEAD` AND `git status --porcelain` is empty; read it from the ledger, never from memory; a missing/unreadable ledger or any other case runs the check again. `plan-verifier` re-run after a fix reads `<SHA>..HEAD` only, as `skills/_shared/fix-loop.md` states. Step 3: skip with the logged line `gaspol-review: skipped — plan-verifier CLEAN @ <sha>` when Step 2 is CLEAN at HEAD and the user did not ask for a review; mandatory when Step 2 was skipped (no plan) or the user asks. Keep the 3-item spot check when a `plan-verifier` verdict is reused. State what is given up: a deferred (`[Nanti]`) ticket has no `plan-verifier` pass until finish runs.
6. Error path — ledger shape: build a fixture ledger (in a temp dir under the scratchpad, not the repo) carrying the new lines above `## Log`/inside `## Log` and run `skills/gaspol-verify/scripts/ledger-gate` against it; it must still exit 0. If it exits 1 or 3, change the line format to one the gate accepts and update Step 5 and the test.
7. Edge cases, each a named assertion or an explicit not-applicable with reason: same SHA + clean tree → reuse; same SHA + dirty tree → rerun; different SHA → rerun; no plan → `plan-verifier` skipped as before and review mandatory; line present but SHA unbackticked/garbled → treated as missing. Observability: every skip writes a ledger line with its reason; nothing is skipped silently.
8. Edit the `Status:` line of `docs/proposals/2026-10-24-reuse-verification-at-same-head.md` to `superseded by IDS-21 (docs/plans/2026-10-24-IDS-21-single-owner-gates-spec.md)`.
9. Run `bash tests/ticket-scripts/test-single-owner-gates.sh`, then `test-finish-gates.sh`, `test-finish-fix-loop.sh`, `test-finish-offer.sh`, `test-fix-loop.sh`, `test-execute-trim.sh`, `test-plan-verifier-spec.sh`, `test-verification-loop.sh`, `test-dispatch-contract.sh`, `test-ledger-gate.sh`, `test-skill-frontmatter.sh`. All exit 0. Where an existing assertion encodes the OLD chain (e.g. execute Step 7 naming `plan-verifier`, or "every gate name" lists in `test-execute-trim.sh`), update it with a comment `IDS-21: owned by gaspol-finish` and add the positive check that the name still exists in finish. Never delete a gate-name assertion without moving it to the new owner.
10. Commit: `feat(gaspol-dev): one owner per end-of-ticket gate, scoped re-run (IDS-21)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-single-owner-gates.sh` exits 0
- [ ] The ten tests named in step 9 each exit 0
- [ ] `ledger-gate` exits 0 on a fixture ledger containing the new lines
- [ ] `grep -n "plan-verifier" skills/gaspol-auto/SKILL.md skills/gaspol-execute/SKILL.md` shows no sentence saying either skill runs it
- [ ] `git diff skills/gaspol-auto/SKILL.md` contains no `verified: PASS @` line (proposal edit dropped)
- [ ] No placeholder/TODO comments in new code

---

### Phase C: gaspol-research gathers with Firecrawl, synthesizes with notebooklm

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-research/SKILL.md` (header comment line 6, line ~36 "use WebSearch directly", Phase 3, Phase 4, freshness lines ~190-191, ~199, red-flag rows ~215-216)
- Modify: `skills/gaspol-brainstorm/SKILL.md` (Phase 1.5 SEMI-NEW bullet "2-3 WebSearch queries")
- Modify: `skills/using-gaspol/SKILL.md` and `hooks/session-start.sh` only if they name `WebSearch` for research (check with grep; edit only if so)
- Test: `tests/ticket-scripts/test-research-tools.sh` (create)

**Steps:**
1. Write failing test for the research tool contract in `tests/ticket-scripts/test-research-tools.sh`. Expected error: `FAIL: gaspol-research does not call notebooklm`.
   Assertions against `skills/gaspol-research/SKILL.md`: contains `notebooklm create`, `notebooklm source add`, `notebooklm source wait`, `notebooklm ask`, `notebooklm list` (reuse an existing notebook before creating one), `firecrawl_search`, `firecrawl_scrape`, `maxAge: 0`; contains a STOP-and-ask rule naming `notebooklm login` and the Firecrawl MCP, and states there is no fallback to `WebSearch`; contains NEITHER `WebFetch` NOR `WebSearch` as an instruction (the only allowed occurrence is inside the sentence forbidding fallback — make the test match the instruction forms `use WebSearch`/`WebFetch actual pages`, not the bare word, and add a positive control proving the matcher catches an old-style line); does NOT contain `Dispatch 3-5 parallel subagents`; contains a rule that only PUBLIC URLs are added as sources (never project files, secrets, or private repo contents — NotebookLM is an external service); still contains the quality gates (`≥4 sources` or the existing wording, found by reading the file first) and `model-tier:`. Against `skills/gaspol-brainstorm/SKILL.md`: Phase 1.5 SEMI-NEW names `firecrawl_search` and no `WebSearch` queries.
2. Run the new test, confirm it fails for the expected reason.
3. Read `notebooklm --help`, `notebooklm source --help`, `notebooklm ask --help` and `notebooklm doctor` once (read-only) and write the skill's commands exactly as the CLI spells them; if a command named in this plan differs, the CLI wins and the test strings are adjusted to match.
4. Rewrite `gaspol-research` Phase 3 as: (1) tool check — `notebooklm doctor` (or `status`) and the Firecrawl tools present; either missing/unauthenticated → state UNKNOWN, STOP and ask, name the fix (`notebooklm login`, enable the Firecrawl MCP), never degrade; (2) `notebooklm list`, reuse a notebook for the topic if one exists, else `notebooklm create "gaspol-research: <topic>"`; (3) collect candidate URLs with `firecrawl_search` (official docs, repo, comparisons, anti-pattern queries "problems with X"/"X deprecated", case studies) and read freshness-critical pages with `firecrawl_scrape` + `maxAge: 0`; (4) `notebooklm source add <public url>` per source, then `notebooklm source wait`; (5) `notebooklm ask` with a prompt demanding a cited comparison. Only the `ask` answer and a one-line status per source enter the conversation. Keep lane 6 (`npx skills find`) as is. Remove the subagent dispatch; Phase 4 now validates and records the `ask` answer instead of consolidating subagent reports.
5. Error paths written as steps in the skill, not footnotes: `source add` fails for a URL (paywall/blocked) → record that source as `not added — <reason>`, continue; if fewer than the quality-gate minimum sources remain, report the gap and STOP rather than proceed; `ask` returns claims without citations → reject that answer under the existing citation gate and re-ask once, then report; Firecrawl credits exhausted → STOP and relay Firecrawl's own message; `notebooklm source wait` times out → report the sources still processing, do not synthesize from a partial set silently.
6. Replace the freshness-check lines (~190-191, ~199) and red-flag rows (~215-216) so they name `firecrawl_search`/`firecrawl_scrape` instead of `WebSearch`/`WebFetch`; replace the "use WebSearch directly" line (~36) with `firecrawl_search`. Update the line-6 header comment so it no longer says "each subagent" but keeps `model-tier: exec` (the gate must still classify the file). Edit `gaspol-brainstorm` Phase 1.5 SEMI-NEW to "2-3 `firecrawl_search` queries".
7. Run `bash tests/ticket-scripts/test-research-tools.sh`, then `test-model-gate.sh`, `skills/gaspol-verify/scripts/model-gate` directly against the repo (must exit 0, never 3 for `gaspol-research`), `test-skill-frontmatter.sh`, `test-prior-art-gate.sh`, `test-kb-no-hardcoded-path.sh`, `test-kb-state4-continues.sh`, `test-skill-delegation.sh`. All exit 0.
8. Live check, recorded as evidence and not part of the suite: run `notebooklm doctor` and one `firecrawl_search` of a trivial query now, and paste both outputs' first lines into the checkpoint report. If either fails, report `live research check: not run — <reason>`, never `PASS`.
9. Commit: `feat(gaspol-dev): research via Firecrawl + notebooklm, no fallback (IDS-21)`.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-research-tools.sh` exits 0
- [ ] `skills/gaspol-verify/scripts/model-gate` exits 0 on this repo
- [ ] `grep -nE "WebFetch|WebSearch" skills/gaspol-research/SKILL.md` shows only the no-fallback sentence
- [ ] The commands in the skill match `notebooklm --help` spellings exactly
- [ ] Live check line is recorded as PASS with output, or as `not run — <reason>`
- [ ] No placeholder/TODO comments in new code

---

### Phase D: Release v1.30.0 — docs, version, full suite

**Estimated time:** 20 minutes

**Files:**
- Modify: `.claude-plugin/plugin.json` (`version` → `1.30.0`)
- Modify: `CHANGELOG.md` (new top entry), `README.md` (version row + changelog line, skill count, finish and research descriptions), `CLAUDE.md` (new section, Architecture rows for changed skills, `**Version:**` and `**Last Updated:**`, skill count text)
- Modify: `docs/kb-setup.md` only if a sentence still describes research via web tools
- Test: `tests/ticket-scripts/test-release-1-30.sh` (create)

**Steps:**
1. Write failing test for the v1.30.0 release metadata in `tests/ticket-scripts/test-release-1-30.sh`. Expected error: `FAIL: plugin.json version is not 1.30.0`.
   Assertions: `plugin.json` version equals `1.30.0` (parse with `grep`/`sed`, BSD-safe: no `\|` in basic regex); `CHANGELOG.md` top entry heading mentions `1.30.0` and `IDS-21`; `README.md` contains `1.30.0`; `CLAUDE.md` `**Version:**` line equals `1.30.0` and it contains a section whose heading includes `IDS-21` and the three give-up statements (`second reader`, `Nanti`, `not measured`); `CLAUDE.md` says 16 skills and not 17; positive control that `CHANGELOG.md` still contains the `1.29.2` entry below the new one.
2. Run the new test, confirm it fails for the expected reason.
3. Edit the files above. `CHANGELOG.md` and the `CLAUDE.md` section state, in plain terms: what changed (A, B, C), what each gives up (a second reader of the diff; deferred tickets have no `plan-verifier` pass until finish; savings are an estimate, not measured), and the extension that moved `gaspol-sync-docs`/`gaspol-review`/`gaspol-verify` out of execute Step 7. `CLAUDE.md` sections older than this ticket are corrected only where they now state something false (e.g. "execute Step 7 runs plan-verifier"); do not rewrite history paragraphs. Do NOT edit the gaspol-one marketplace repo or its README table here; list both as "follow-up, separate repo" in the checkpoint report.
4. Leak check: `git diff main... -- . ':!docs/plans' ':!.gaspol'` piped through `grep -nE "/Users/alisadikin|ali\.sadikincom85|sk-[A-Za-z0-9]{20,}"` — captured into a variable first; any hit outside the sanctioned examples is removed.
5. Refresh the code index per `CLAUDE.md`: `graphify update .` (AST-only, no API cost). If the CLI is missing, record `graphify: UNKNOWN — CLI missing` in the checkpoint report; do not claim it ran.
6. Full suite — the final gate, run once here and nowhere earlier: `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done`. Also run `skills/gaspol-verify/scripts/model-gate` and `skills/gaspol-verify/scripts/ledger-gate` against this repo/ledger. Read the whole output; the claim "all pass" quotes the exit code and the count of files run.
7. Error path: any failure → read the failing command's output verbatim, fix at the cause (skill text or test, per Phase A step 5's rule), re-run only the failing test, then re-run the full suite once. The round cap is `skills/_shared/fix-loop.md`'s.
8. Commit: `chore(gaspol-dev): release 1.30.0 — single-owner gates, no gaspol-learn, research via notebooklm + Firecrawl (IDS-21)`. Do not push; push, `claude plugin marketplace update gaspol-one` and `claude plugin update gaspol-dev@gaspol-one` are offered by `gaspol-finish`, not run here.

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `bash tests/ticket-scripts/test-release-1-30.sh` exits 0
- [ ] Full suite `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0 (quote the file count)
- [ ] `model-gate` and `ledger-gate` exit 0
- [ ] Leak check returned no hit outside sanctioned examples
- [ ] `graphify update .` ran, or `graphify: UNKNOWN — CLI missing` is recorded
- [ ] No placeholder/TODO comments in new code
