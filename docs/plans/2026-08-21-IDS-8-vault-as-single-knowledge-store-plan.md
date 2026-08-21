> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-8.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. Blocking, like a test gate. Never batch at the end.
> **Self-contained:** this plan is the COMPLETE spec. Every path, contract and command it needs is written here verbatim.

**Ticket:** IDS-8
**Ledger:** .gaspol/progress/PROGRESS-IDS-8.md
**Spec:** docs/plans/2026-08-21-IDS-8-vault-as-single-knowledge-store-spec.md

## Goal

Collapse two knowledge pipelines into one. gaspol stops running its own store at
`~/.claude/gaspol-knowledge/` and instead feeds the quarantine the owner's vault extractor already
uses, in that extractor's own format, so `superbrain-promote` stays the single human gate into the
curated core. Along the way, close four defects the audit found: a relocation setting that no skill
reads, precedent lookup switched off for bounded work, a latent hazard where gaspol would commit the
owner's entire vault repository, and a code index that nothing keeps current from the chain.

## Architecture Context

Facts verified by command on 2026-08-21, not assumed:

- `~/.claude/gaspol-knowledge/` — 18 markdown entries across `architecture/` (7),
  `design-decisions/` (5), `research/` (2), `reusable-snippets/` (3), plus `INDEX.md`. 5 commits,
  no remote.
- Vault root: `/Users/alisadikin/Drive-D/Obsidian-Vault` — **is a git repository**.
- `<vault>/90-Inbox/agent-learnings/` — 62 pending notes, written by the SessionStart hook
  `~/.graphify/memory-extract.sh` since 2026-07-05. Note shape: YAML frontmatter
  (`status`/`date`/`source`), `# Title`, a `tags: [...]` line, body. `.rejected-log` records runs.
- `~/.claude/skills/superbrain-promote/SKILL.md` — the sole promoter into the vault core. Iron
  rules include *"No note in two places"* and dedup-before-append. Its routing targets include
  `30-Knowledge/coding-workflow-patterns.md`, `20-Projects/<name>/`, and the playbooks.
- Under `skills/`: `GASPOL_KB_LOCAL` 3 hits, `GASPOL_KB_REMOTE` 4 hits, **`kb_local` 0 hits**,
  **`gaspol-config` 0 files**. 16 prose sites name `~/.claude/gaspol-knowledge/` literally.
- `skills/_shared/laziness-ladder.md` is the precedent for a single shared reference file that
  several skills point at.
- `skills/gaspol-verify/scripts/extract-design-tokens` (IDS-7) is the precedent for stdout-only
  tooling whose write is offered by a skill, never taken by the script.

## Tech Stack

Markdown skill text plus stdlib-only shell/Python, matching every existing script under
`skills/*/scripts/`. **No new dependency**: frontmatter here is flat `key: value`, which the IDS-7
reader already proved needs no YAML library.

`skills/gaspol-execute/scripts/detect-stack .` prints **zero lines** for this repository — there
are no stack markers. Verification is therefore plan-declared for every phase below:

```bash
for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done
```

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---|---|---|---|---|
| KB root resolution | `$GASPOL_KB_LOCAL`, `~/.claude/gaspol-config.json` `kb_local` | new `skills/_shared/kb-path.md` | Env yes; config key read by nothing | Implement the config rung |
| Capture destination | `<vault>/90-Inbox/agent-learnings/` | resolved KB root | Yes — 62 notes live | Write into it, in its format |
| Note shape | frontmatter + `# Title` + `tags:` line | `memory-extract.sh` output | Yes | Match it exactly, unchanged |
| Promotion | `~/.claude/skills/superbrain-promote/` | user runs `/superbrain-promote` | Yes | Leave untouched |
| Design-time read | vault `INDEX.md`, `hot.md`, `30-Knowledge/`, `20-Projects/<name>/README.md` | `gaspol-brainstorm` Phase 0/0.5 | Yes | Read only, never write |
| Git ownership | `git -C <kb_root> rev-parse --show-toplevel` | sync guard | Yes (git) | Refuse commit when toplevel ≠ KB root |
| Code index | `graphify-out/` + `graphify` CLI in the target repo | `gaspol-sync-docs` | Varies per project | `graphify update .` when both present |
| Federated brain | `~/.graphify/global-graph.json` | `graphify global add` | Yes | **Offer** via AskUserQuestion, never automatic |
| Migration input | the 17 content entries + `INDEX.md` dropped + the 62 inbox notes | manual routing pass | Yes | Dedup, route, delete source |

Every row is a real file, a real command, or a real environment variable. No placeholders.

## Laziness notes

- ~~`ponytail:` one shared reference file (`skills/_shared/kb-path.md`), not a script~~
  **DEVIATION (Phase B, 2026-08-21): a script was required after all.** The premise was that the
  KB skills are prose an agent reads. Three of them are not — they contain runnable bash that
  does `git -C "$KB" commit`. With the resolver documented only as a shell function in a
  markdown file, `KB="$(kb_root)"` is not in scope when that block runs: it resolves to the
  **empty string**, and `git -C ""` is a silent wrong answer — the exact failure class this
  ticket exists to remove. `skills/_shared/kb-root` (stdlib, ~55 lines) now reports the three
  states through exit codes 0/3/4, which cannot be conflated the way an empty stdout can. The
  doc keeps the order and the states; the script executes them. Still one source of truth, and
  the allow-list in Phase B's test is pinned to exactly those two files so the exemption cannot
  grow.
- No new skill. Every change lands in a skill that already exists.
- Soft-reference only: **no** `dependencies` key in `plugin.json`, matching the `ui-ux-pro-max`
  decision in v1.14.
- Phase F rides `gaspol-sync-docs`, which `gaspol-finish` already calls — no new gate.

---

### Phase A: KB path resolver with three honest states

**Estimated time:** 25 minutes

**Files:**
- Create: `skills/_shared/kb-path.md`
- Test: `tests/ticket-scripts/test-kb-path-resolver.sh`

**Steps:**
1. Write failing test for the documented resolution order and the three resolution states. Expected error: `FAIL: skills/_shared/kb-path.md does not exist`.
2. Run test, confirm it fails for the expected reason (missing file, not a bash syntax error).
3. Write `kb-path.md` documenting exactly one order — `$GASPOL_KB_LOCAL` > `kb_local` in `~/.claude/gaspol-config.json` > `~/.claude/gaspol-knowledge` — with the resolver snippet, plus the three states: resolved-and-readable (use it), none-configured (record `knowledge-store: none — vault not configured`, **not a failure**, name the setting), configured-but-unreadable (`knowledge-store: UNKNOWN` → **STOP and ask**).
4. Run tests, confirm all pass.
5. Commit: "feat(kb): one path resolver that actually reads the config (IDS-8 E2)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The test asserts all three state strings, and asserts the config rung sits between env and default
- [ ] A sabotage check: deleting the `UNKNOWN` state from `kb-path.md` makes the test fail
- [ ] No placeholder/TODO comments in new content

---

### Phase B: the 16 prose sites stop naming the old folder

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-learn/SKILL.md`, `skills/gaspol-adr/SKILL.md`, `skills/gaspol-research/SKILL.md`, `skills/gaspol-kb-audit/SKILL.md`, `skills/gaspol-brainstorm/SKILL.md`, `skills/gaspol-verify/rules/reasoning-gaspol.md`
- Test: `tests/ticket-scripts/test-kb-no-hardcoded-path.sh`

**Steps:**
1. Write failing test for the absence of an unqualified literal KB path in skill prose. Expected error: `FAIL: 16 site(s) still name ~/.claude/gaspol-knowledge without referencing the resolver`.
2. Run test, confirm it fails and reports a count greater than zero (a test that passes here proves nothing — the sites demonstrably exist).
3. Rewrite each site to reference the resolved KB root and `skills/_shared/kb-path.md`. The literal default may appear **only** inside `kb-path.md` itself, as the last rung.
4. Run tests, confirm all pass.
5. Commit: "fix(kb): skill prose reads the resolved root, not a hardcoded folder (IDS-8 E2)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The test's allow-list contains exactly five files — `skills/_shared/kb-path.md`,
      `skills/_shared/kb-root`, `docs/kb-setup.md`, `CLAUDE.md`, `README.md`. **AMENDED
      2026-08-21 (gaspol-review Tier 1):** this line said *one* and the Laziness DEVIATION note
      said *two*, while the test asserts *five* and its echo still claimed *two*. The two
      resolver files spell the path because that is their job; the three docs explain it, and a
      separate check forbids them carrying runnable bash that uses it — so the widening is not a
      hole. Three different numbers across plan, deviation note and test message is how an
      exemption grows unnoticed, which is this ticket's recurring failure. The echo is corrected
      and the number is pinned here
- [ ] Positive control: the test finds the sites before the fix and zero after
- [ ] No placeholder/TODO comments in new content

---

### Phase C: write quarantine notes in the extractor's own format

**Estimated time:** 30 minutes

**Files:**
- Modify: `skills/gaspol-learn/SKILL.md`, `skills/gaspol-adr/SKILL.md`, `skills/gaspol-research/SKILL.md`
- Test: `tests/ticket-scripts/test-kb-write-format.sh`

**Steps:**
1. Write failing test for the quarantine note contract. Expected error: `FAIL: gaspol-learn still writes <category>/<slug>.md instead of a flat quarantine note`.
2. Run test, confirm it fails for the expected reason.
3. Rewrite the write instructions: flat file at `<kb_root>/YYYY-MM-DD-<slug>.md`, frontmatter `status: proposed` / `date:` / `source: gaspol-learn (<project> <TICKET>)`, then `# Title`, then a `tags: [...]` line, then the body. Category becomes a tag, not a directory. State explicitly that `status` is **never** `accepted` — gaspol does not promote its own captures; `superbrain-promote` does.
4. Run tests, confirm all pass.
5. Commit: "feat(kb): capture into the quarantine superbrain-promote already reads (IDS-8)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The test asserts `status: proposed` is mandated AND that `status: accepted` is prohibited for gaspol writes
- [ ] The test asserts the ≥200-word quality gate survived the rewrite — the gate is gaspol's whole contribution and must not be lost with the directories
- [ ] No placeholder/TODO comments in new content

---

### Phase D: gaspol never commits a repository it does not own

**Estimated time:** 20 minutes

**Files:**
- Modify: `skills/_shared/kb-path.md`, `skills/gaspol-learn/SKILL.md`, `skills/gaspol-adr/SKILL.md`, `skills/gaspol-research/SKILL.md`
- Test: `tests/ticket-scripts/test-kb-git-guard.sh`

**Steps:**
1. Write failing test for the git ownership guard. Expected error: `FAIL: no skill checks git rev-parse --show-toplevel before committing the KB`.
2. Run test, confirm it fails for the expected reason.
3. Document the guard in `kb-path.md` and reference it from each syncing skill: before any `git commit`/`git push`, compare `git -C <kb_root> rev-parse --show-toplevel` against the KB root. Not equal → refuse the write operations, record `kb-sync: skipped — KB lives inside a repo gaspol does not own (<toplevel>)`, continue. Reads stay allowed.
4. Run tests, confirm all pass.
5. Commit: "fix(kb): refuse to commit a repo gaspol does not own (IDS-8 E4)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] A live check proves the guard's premise: `git -C <vault>/90-Inbox/agent-learnings rev-parse --show-toplevel` returns the **vault root**, not the KB root — quote the output
- [ ] The test asserts the skipped state is *recorded*, never silent
- [ ] No placeholder/TODO comments in new content

---

### Phase E: brainstorm reads the second brain, on bounded work too

**Estimated time:** 30 minutes

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md`
- Test: `tests/ticket-scripts/test-vault-read.sh`

**Steps:**
1. Write failing test for the vault read order and the removal of the bounded-path exemption. Expected error: `FAIL: Phase 0.5 is still headed "architectural path only"`.
2. Run test, confirm it fails for the expected reason.
3. Add the vault read to Phase 0 in the owner's own order (`INDEX.md` → `hot.md` → `10-Identity/` for identity work → `20-Projects/<name>/README.md` → `30-Knowledge/`), stopping as soon as there is enough. Remove `architectural path only` from Phase 0.5 and state that **bounded** now runs the precedent query while **spike** keeps its exemption, with the reason written down. Add the missing-vault soft-reference: say what is missing, name the setting, continue — never hard-fail.
4. Run tests, confirm all pass.
5. Commit: "feat(brainstorm): query precedent on bounded work, read the vault at Phase 0 (IDS-8 E3)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The test asserts spike is still exempt — widening the gate to *everything* would be a different, unrequested change
- [ ] The test asserts no absolute vault path appears in the skill (the plugin is public and agnostic)
- [ ] No placeholder/TODO comments in new content

---

### Phase F: graphify update runs from the slot that already exists

**Estimated time:** 25 minutes

**Files:**
- Modify: `skills/gaspol-sync-docs/SKILL.md`
- Test: `tests/ticket-scripts/test-graphify-lane.sh`

**Steps:**
1. Write failing test for the graphify lane's three states. Expected error: `FAIL: gaspol-sync-docs never mentions graphify`.
2. Run test, confirm it fails for the expected reason.
3. Add the lane: `graphify-out/` present **and** CLI on PATH → run `graphify update .`, record `graphify: updated`; `graphify-out/` present, CLI missing → `graphify: UNKNOWN — index present, CLI missing` → STOP and ask; no `graphify-out/` → skip silently, **never recorded as passed**. Add the federated refresh (`graphify global add … --as <tag>`) as an `AskUserQuestion` offer, because it writes outside the repository.
4. Run tests, confirm all pass.
5. Commit: "feat(sync-docs): keep the code index current, three states, no new gate (IDS-8)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] The test asserts the global refresh is **offered**, and fails if it is described as automatic
- [ ] A genuinely negative assertion: any unnegated sentence recording the lane as passed when it did not run fails the test (the IDS-7 `wig-lane` pattern)
- [ ] No placeholder/TODO comments in new content

---

### Phase G: migrate the entries, then retire the old store

> **AMENDED 2026-08-21 (execution):** this phase said **18 entries** throughout. The store held 18
> *files*, of which **17 are content**; the 18th is `INDEX.md`, the index Phase C stopped writing.
> It was deliberately **not** migrated and is a recorded loss, not an oversight. Read "18" below as
> **17 content entries + INDEX.md dropped**. Amended in place for the same reason the Laziness note
> above was: a plan that still asserts a number the implementation contradicts is a plan nobody can
> audit against.
>
> **AMENDED AGAIN 2026-08-21 (gaspol-review Tier 1):** step 3 below routes 10 entries into
> `30-Knowledge/coding-workflow-patterns.md` and 5 into `20-Projects/<name>/`. **That is not what
> was done, and the plan was wrong.** All 17 landed in `90-Inbox/agent-learnings/`. Writing into
> the curated core **is promotion**, and this ticket's own iron rule reserves promotion for
> `superbrain-promote` and the human gate — a skill that promotes its own capture has removed the
> gate it was told to feed. The commit subject was quietly changed from *"into the vault"* to
> *"into the vault quarantine"* and nothing else recorded the divergence; an auditor re-reading
> step 3 would look in `30-Knowledge/` and find nothing. **Read step 3's routing targets as
> superseded: every entry goes to quarantine, and `superbrain-promote` routes from there.** The
> smaller count discrepancy got an in-place amendment while the larger routing change got none;
> that asymmetry is the defect being corrected here.
>
> **Also recorded (Phase A string):** the plan mandates `knowledge-store: none — vault not
> configured`; the ship prints `knowledge-store: none — not configured`. "vault" was dropped
> deliberately — a public, agnostic plugin cannot name one user's vault in its own diagnostic —
> but the plan text was never amended, so it is amended here.

**Estimated time:** 45 minutes

**Files:**
- Write: `~/.claude/gaspol-config.json` (`kb_local` → `<vault>/90-Inbox/agent-learnings`)
- Move/merge: the 18 entries in `~/.claude/gaspol-knowledge/` into vault targets
- Remove: `~/.claude/gaspol-knowledge/` once routing is complete

**Steps:**
1. Write failing test for a clean-environment resolution to the vault. Expected error: `FAIL: with GASPOL_KB_LOCAL unset the KB resolves to ~/.claude/gaspol-knowledge, not the configured vault path`.
2. Run test with `env -u GASPOL_KB_LOCAL`, confirm it fails for the expected reason.
3. Write `~/.claude/gaspol-config.json` with `kb_local`. Then route each of the 18 entries using `superbrain-promote`'s own targets — 7 `architecture/` + 3 `reusable-snippets/` → `30-Knowledge/coding-workflow-patterns.md`; 5 `design-decisions/` → `20-Projects/<name>/`; 2 `research/` → quarantine for the human gate. **Dedup first** against the 62 pending inbox notes; where a duplicate is confirmed, keep one and delete the other — `superbrain-promote`'s iron rule is *no note in two places*. Delete each source only after its target is written. Then remove `~/.claude/gaspol-knowledge/`.
4. Run tests, confirm all pass.
5. Commit: "chore(kb): route the 18 entries into the vault and retire the old store (IDS-8)"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] With a clean environment (`env -u GASPOL_KB_LOCAL`), resolution lands on the vault path — quote the resolved path
- [ ] All 18 entries accounted for: each is either merged into a named target or deleted as a confirmed duplicate. **A count, per entry, quoted** — "migrated" without a per-entry disposition is a completion claim without evidence
- [ ] `~/.claude/gaspol-knowledge/` no longer exists, and a subsequent KB write lands under the vault — verified by running one, not assumed
- [ ] The vault's own git status is inspected and reported; nothing was committed there by gaspol

---

### Phase H: documentation and version

**Estimated time:** 25 minutes

**Files:**
- Modify: `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `docs/kb-setup.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Steps:**
1. Write failing test for documentation fidelity. Expected error: `FAIL: docs/kb-setup.md still presents kb_local as working without naming the resolver`.
2. Run test, confirm it fails for the expected reason.
3. Update the four documents: the resolution order, the quarantine format, the sole-promoter rule, the git guard, the graphify lane, and the deferred `gaspol-kb-audit` overlap recorded as an open question. Bump to **1.18.0** in both plugin manifests. The CHANGELOG leads with the duplication and the unread setting, not with the feature.
4. Run tests, confirm all pass.
5. Commit: "docs: CLAUDE.md and CHANGELOG document IDS-8, bump to 1.18.0"

**Verification:**
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] `for f in tests/ticket-scripts/*.sh; do bash "$f" || exit 1; done` exits 0
- [ ] Both manifests read `1.18.0`
- [ ] `docs/kb-setup.md` no longer promises a setting that nothing reads
- [ ] The `gaspol-kb-audit` overlap is written down as deferred, with the reason it is not like-for-like
- [ ] No placeholder/TODO comments in new content

---

## Pre-flight conflict matrix (BLOCKING — ruled on before Phase A starts)

| Pair / self | Shared surface | Ruling |
|---|---|---|
| A ↔ B | `skills/_shared/kb-path.md` — A creates it, B's allow-list names it | A must land first; B's test would otherwise allow-list a nonexistent file |
| A ↔ D | Both write to `kb-path.md` | Sequential; D appends the guard section, never rewrites A's order |
| B ↔ C | Both edit learn/adr/research SKILL.md | Sequential; B fixes the *path*, C fixes the *note shape* — disjoint text, same files |
| C ↔ G | C defines the format, G writes real notes in it | G must follow C; a migration in the old shape would need redoing |
| D ↔ G | D's guard fires on G's first vault write | G verifies the guard live, quoting the vault toplevel |
| E ↔ B | Both edit `gaspol-brainstorm/SKILL.md` | Sequential; B touches Phase 0.5's path text, E touches its heading and Phase 0 |
| F ↔ H | F adds the lane, H documents it | H last |
| G ↔ (all) | G is the only phase that touches files **outside this repository** | Runs after every in-repo phase is green; nothing in the vault is touched before then |
| A self | resolver text vs its own test | The test must fail with the file absent — assert the failure first |
| B self | allow-list vs the count assertion | Positive control required: non-zero before, zero after |
| C self | new format vs the surviving quality gate | Both asserted in the same test; the gate is what gaspol contributes |
| D self | guard prose vs live git behaviour | Both: the text and a quoted `rev-parse` result |
| E self | widened gate vs spike exemption | Assert spike is still exempt — the change is bounded, not universal |
| F self | three states vs the negative assertion | The unnegated-pass check must not flag the prohibition itself (IDS-7 lesson) |
| G self | 17 content sources vs their dispositions (the store held 18 files; the 18th was `INDEX.md`, dropped — see the Phase G amendment) | Per-entry accounting, not a summary count |
| H self | docs vs code | Each documented claim points at something that exists in the diff |

## Execution Handoff

Execute with `gaspol-execute` (per-phase checkpoints) or `gaspol-auto` (autonomous, hard-stop
guardrails). **Phase G is the one phase that writes outside this repository** — it modifies the
owner's vault and deletes the old KB. Under `gaspol-auto` it must be treated as a hard-stop
"destructive operation" pause, not run unattended.
