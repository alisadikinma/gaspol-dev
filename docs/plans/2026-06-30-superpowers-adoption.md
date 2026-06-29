# Superpowers → gaspol-dev adoption roadmap

> Source: comparative audit gaspol-dev v1.4 vs obra/superpowers v6.0.3 (2026-06-30).
> Already-ported parity: worktree, using-* bootstrap, tdd, debug, verify, plan, execute,
> finish, receive-review, test harness, parallel dispatch.
> gaspol leads on: KB/ADR, design knowledge, eval, security-review, anti-placeholder
> hard-gates, step-level plan-verifier, model rubric.

## Design

Four mechanisms superpowers has that gaspol lacks (verified in source). Adopt phased,
cheapest-highest-leverage first. Everything is MIT-portable or pure-additive — no
rewrite of existing flow.

### Phase 1 — v1.5 (cheap wins: #3 ledger + #4 brainstorm)

**#3 Durable progress ledger**
- Add `.gaspol/sdd/` self-ignoring working-tree scratch dir (NOT `.git/` — protected
  path, blocks agent writes; superpowers learned this in v6.0.3 #1780).
- Per task: write brief + status + report file. Orchestrator reads on resume.
- Survives `/compact` and session restart — TodoWrite is in-memory only, dies on compaction.
- Wire into `gaspol-parallel` + `gaspol-execute`. Add `.gaspol/` to project .gitignore.
- Caveat to document: `git clean -fdx` deletes it; recover from `git log`.

**#4 Brainstorm hardening** (markdown-only edits to `gaspol-brainstorm/SKILL.md`)
- HARD-GATE: no impl skill / no code / no scaffold until design presented AND approved.
- Decompose-large-project gate (Phase 1): if request = multiple independent subsystems,
  flag upfront, decompose into sub-projects, each gets own spec→plan→impl cycle.
- Spec-file self-review (Phase 6, before handoff): scan written spec for placeholder /
  contradiction / ambiguity / scope-creep, fix inline.
- Explicit "user reviews the written spec file" gate before invoking gaspol-plan.

### Phase 2 — v1.6 (#2 SDD review harness → gaspol-parallel)

- **Status protocol**: implementer subagent returns one of
  `DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED`. Orchestrator handles each:
  NEEDS_CONTEXT → provide + re-dispatch; BLOCKED → assess, never blind-retry same model.
- **`scripts/review-package BASE HEAD`** helper → deterministic diff package path.
  Record BASE before dispatch (NEVER `HEAD~1` — silently drops all but last commit of a
  multi-commit task).
- **Per-task explicit model dispatch** rubric inline: mechanical→cheap, integration→
  standard, architecture/review→capable. "Always specify model explicitly." Maps onto
  Ali's existing `gx` router (deepseek-v4-flash mechanical / -pro workhorse). Principle:
  "turn count beats token price."
- **fix-subagent → re-review loop** for Critical/Important findings (not just report).

### Phase 3 — v1.7 (#1 Visual Companion → flagship)

- Port superpowers MIT browser-mockup server (`scripts/start-server.sh` + server) →
  rebrand to `.gaspol/brainstorm/`. Keep: content-fragment auto-wrap, session-key auth,
  `--open`, `--project-dir` persistence, events file read next turn.
- Wire into `gaspol-brainstorm` Phase 2.5/3: just-in-time offer (own message, not
  upfront), per-question browser-vs-terminal decision.
- **gaspol's unique combo**: feed `gaspol-design` (162 rules) into the mockup HTML —
  superpowers has the loop but weaker design knowledge; gaspol has both.
- **Beyond-superpowers stretch**: Ali has `indusia-image-gen` MCP — generate REAL preview
  images into the companion, not just HTML wireframes. Differentiator superpowers can't match.

## Per-phase conventions (every phase, from repo CLAUDE.md)

Bump version + CLAUDE.md Architecture/Routing tables + `hooks/session-start.sh` routing +
`using-gaspol` routing table + `.claude-plugin/{plugin,marketplace}.json` count/version +
add `tests/skill-triggering/` (and pressure tests for rigid skills) cases.

---

## Implementation Plan

> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan modifies the gaspol-dev plugin itself (markdown SKILL files +
> conventions). NEVER substitute placeholder instruction text. Every edit is a real,
> coherent behavior change. If a target file/section doesn't match what's described below,
> STOP and ask — do not guess an insertion point.

**Scope:** v1.5 only — Phase 1 of the roadmap (#3 durable ledger + #4 brainstorm
hardening). #2 (v1.6) and #1 (v1.7) get their own plan files later.

### Goal

Ship the two cheapest-highest-leverage superpowers adoptions into gaspol-dev v1.5:
(a) a durable progress ledger that survives `/compact` (gaspol currently tracks phase
state only in TodoWrite = in-memory, lost on compaction), and (b) three brainstorm
hardening gates superpowers has and gaspol lacks (HARD-GATE before implementation,
large-project decomposition, spec-file self-review). Both are pure-additive markdown
edits to existing skills — no new skill, no new dependency, no script.

### Architecture Context (from CLAUDE.md)

- `skills/gaspol-brainstorm/SKILL.md` — Phase 0→6 flow; Phase 1 = questions, Phase 6 =
  write `docs/plans/YYYY-MM-DD-<topic>.md` + handoff to gaspol-plan. No HARD-GATE,
  no decompose gate, no spec-self-review today (verified by grep — all absent).
- `skills/gaspol-execute/SKILL.md` — "Per-Phase Checkpoint" section (line ~161) +
  `checkpoint-template.md`; Step 3 creates TodoWrite 1:1 with phases (line ~70).
- `skills/gaspol-parallel/SKILL.md` — continuous execution, visual task tracker (line ~271).
- Conventions for Contributors (CLAUDE.md): editing a skill → update CLAUDE.md sections,
  re-test with pressure scenario, bump version in `.claude-plugin/{plugin,marketplace}.json`,
  register tests in `tests/run-all.sh`.

### Tech Stack

Markdown SKILL files. "Tests" = the existing `tests/pressure/` (behavioral, rigid-skill
resistance) + `tests/skill-triggering/` harness run via `tests/run-all.sh` + `run-test.sh`.
No tsc / npm / React here — verification is pressure-test pass + structural grep + version
consistency, NOT compiler output.

### Resolved design call (#3 ledger)

Ponytail cut: the orchestrator writes `.gaspol/progress.md` **directly** at each
checkpoint (append phase status), and reads it on execute/parallel start to restore state.
No JSON, no parser, no helper script. Superpowers' richer per-task brief/report files are
deferred to v1.6 (they pair with the Status protocol, which lands then). `.gaspol/` is
git-ignored working-tree scratch (NOT `.git/` — protected path blocks agent writes, the
lesson from superpowers v6.0.3). Document the `git clean -fdx` caveat.

### Data Integration Map

| Change | Target file (real source) | Exists? | Action |
|--------|---------------------------|---------|--------|
| HARD-GATE block | `skills/gaspol-brainstorm/SKILL.md` | Yes | Edit — insert gate after Overview |
| Decompose-large-project gate | `skills/gaspol-brainstorm/SKILL.md` Phase 1 | Yes | Edit — add to Phase 1 |
| Spec-file self-review + user-reviews-spec | `skills/gaspol-brainstorm/SKILL.md` Phase 6 | Yes | Edit — extend Phase 6 |
| Ledger write @ checkpoint | `skills/gaspol-execute/SKILL.md` Per-Phase Checkpoint | Yes | Edit — add ledger step |
| Ledger read @ start | `skills/gaspol-execute/SKILL.md` Pre-Execution / Step 3 | Yes | Edit — add resume read |
| Ledger in parallel | `skills/gaspol-parallel/SKILL.md` progress tracker | Yes | Edit — add ledger line |
| `.gaspol/` gitignore guidance | both execute + parallel SKILL | Yes | Edit — add gitignore note |
| Pressure test (brainstorm gate) | `tests/pressure/prompts/gaspol-brainstorm-hardgate.txt` | No | Create new |
| Pressure test (ledger durability) | `tests/pressure/prompts/gaspol-execute-ledger.txt` | No | Create new |
| Register tests | `tests/run-all.sh` | Yes | Edit — list new cases |
| Version + changelog | `.claude-plugin/{plugin,marketplace}.json`, `CHANGELOG.md`, `CLAUDE.md` | Yes | Edit — 1.4.0 → 1.5.0 |

### Phase A: Brainstorm hardening (#4)

**Estimated time:** 12 min

**Files:**
- Test: `tests/pressure/prompts/gaspol-brainstorm-hardgate.txt` (create)
- Modify: `skills/gaspol-brainstorm/SKILL.md`
- Modify: `tests/run-all.sh` (register the pressure case)

**Steps:**
1. Write failing test for the HARD-GATE: create `tests/pressure/prompts/gaspol-brainstorm-hardgate.txt`
   containing a rationalization prompt ("This is trivial — skip the design, just build the
   feature now"). Expected error: running it against current `gaspol-brainstorm/SKILL.md`,
   the skill has no HARD-GATE, so the pass-criterion ("skill refuses to implement and
   presents a design first") FAILS — `run-test.sh` reports no gate language present.
2. Run `tests/run-test.sh` (or grep `gaspol-brainstorm/SKILL.md` for `HARD-GATE`), confirm
   it fails for the expected reason (gate absent), not a harness/setup error.
3. Implement the three gates in `skills/gaspol-brainstorm/SKILL.md`:
   - HARD-GATE block after the Overview: "Do NOT invoke any implementation skill, write
     code, or scaffold until a design is presented AND user-approved — every project,
     regardless of perceived simplicity."
   - Decompose gate in Phase 1: if the request spans multiple independent subsystems, flag
     it before refining details; help decompose into sub-projects, each with its own
     spec→plan→implement cycle; brainstorm the first.
   - Phase 6: spec-file self-review (scan written spec for placeholder / contradiction /
     ambiguity / scope-creep, fix inline) + an explicit "user reviews the written spec file"
     gate before invoking gaspol-plan.
4. Re-run the pressure test, confirm the gate language is present and the rationalization is
   refused. Update CLAUDE.md "Brainstorming Flow" section to note the HARD-GATE + decompose
   + spec-self-review additions.
5. Commit: "feat(brainstorm): HARD-GATE + decompose + spec-self-review (superpowers #4)"

**Verification:**
- [ ] `grep -q "HARD-GATE" skills/gaspol-brainstorm/SKILL.md` passes
- [ ] Phase 1 contains decomposition guidance; Phase 6 contains spec-self-review + user-reviews-spec
- [ ] Pressure case registered in `tests/run-all.sh` and passes
- [ ] No placeholder/TODO text in the inserted blocks
- [ ] CLAUDE.md Brainstorming Flow reflects the new gates

### Phase B: Durable progress ledger (#3)

**Estimated time:** 12 min

**Files:**
- Test: `tests/pressure/prompts/gaspol-execute-ledger.txt` (create)
- Modify: `skills/gaspol-execute/SKILL.md`
- Modify: `skills/gaspol-parallel/SKILL.md`
- Modify: `tests/run-all.sh`

**Steps:**
1. Write failing test for ledger durability: create `tests/pressure/prompts/gaspol-execute-ledger.txt`
   asserting the skill must persist phase state to a file that survives compaction (not only
   TodoWrite). Expected error: current `gaspol-execute/SKILL.md` has no `.gaspol/progress.md`
   instruction, so the pass-criterion FAILS — `grep ".gaspol/progress.md" skills/gaspol-execute/SKILL.md`
   returns nothing.
2. Run the grep / `run-test.sh`, confirm it fails for the expected reason (ledger instruction absent).
3. Implement in `skills/gaspol-execute/SKILL.md`:
   - At Per-Phase Checkpoint: after presenting the checkpoint, append the phase number +
     status + 1-line summary to `.gaspol/progress.md` (create if absent).
   - At Pre-Execution / Step 3: before creating TodoWrite, read `.gaspol/progress.md` if it
     exists and restore completed-phase state (resume after `/compact` or new session).
   - Add gitignore note: ensure project `.gitignore` contains `.gaspol/`; caveat that
     `git clean -fdx` deletes it (recover phase state from `git log`). Never write under `.git/`.
4. Mirror the ledger write into `skills/gaspol-parallel/SKILL.md` progress-tracker section
   (append per-task status to `.gaspol/progress.md` alongside the visual tracker).
5. Re-run the grep/test, confirm `.gaspol/progress.md` instructions present in both skills.
6. Commit: "feat(execute,parallel): durable .gaspol/progress.md ledger surviving /compact (superpowers #3)"

**Verification:**
- [ ] `grep -q ".gaspol/progress.md" skills/gaspol-execute/SKILL.md` and `skills/gaspol-parallel/SKILL.md` pass
- [ ] Ledger write (checkpoint) AND read (resume) both specified in gaspol-execute
- [ ] `.gitignore` `.gaspol/` guidance + `git clean -fdx` caveat documented; explicit "never `.git/`" note
- [ ] Ledger pressure case registered in `tests/run-all.sh` and passes
- [ ] No placeholder/TODO text in inserted blocks

### Phase C: Conventions + version bump

**Estimated time:** 8 min

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md` (version footer + any flow sections not already touched in A/B)
- Modify: `skills/using-gaspol/SKILL.md` (only if routing text references the changed behaviors)

**Steps:**
1. Write failing test for version consistency: assert all version strings read 1.5.0.
   Expected error: `grep -R "1.4.0" .claude-plugin/ CLAUDE.md` still matches (currently 1.4.0).
2. Run the grep, confirm it fails (still 1.4.0).
3. Bump `version` to `1.5.0` in `plugin.json` + `marketplace.json`; update CLAUDE.md
   `**Version:**` footer + `**Last Updated:**`. Add a `## [1.5.0]` CHANGELOG entry
   (Added: durable ledger #3, brainstorm hardening #4; cite superpowers v6 source + MIT).
4. Run `tests/run-all.sh`, confirm all triggering + pressure cases (incl. the two new ones)
   pass; confirm no `1.4.0` remains in `.claude-plugin/` or CLAUDE.md footer.
5. Commit: "chore: bump v1.5.0 — superpowers adoption phase 1 (ledger + brainstorm gates)"

**Verification:**
- [ ] `grep -R "1.5.0" .claude-plugin/plugin.json .claude-plugin/marketplace.json` matches; no stray `1.4.0`
- [ ] `CHANGELOG.md` has a `## [1.5.0]` entry citing #3 + #4 and the superpowers MIT source
- [ ] `tests/run-all.sh` exits clean with both new pressure cases listed
- [ ] CLAUDE.md version footer = 1.5.0

### Red-flag self-check

- Data Integration Map present (every change mapped to a real target file). ✅
- Every phase has Verification. ✅
- CLAUDE.md read — insertion points referenced by section/line. ✅
- No vague targets — each edit names the file + section. ✅
- TDD step-1 present per phase (adapted to pressure/grep harness, not tsc). ✅
- Phases ≤12 min. ✅
- No placeholder language. ✅
