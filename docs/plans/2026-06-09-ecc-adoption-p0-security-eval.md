# ECC Adoption — P0: gaspol-security-review + gaspol-eval

> Hybrid file. This `## Design` section is from gaspol-brainstorm (2026-06-09).
> `gaspol-plan` will append `## Implementation Plan` below.

## Design

### Context & Decision

Comparison: **gaspol-dev 1.3** (opinionated workflow chain + KB, ~21 skills, lean/R1) vs
**ECC 2.0.0-rc.1** by Affaan Mustafa (64 agents, 261 skills, multi-harness library —
github.com/affaan-m/ECC, source mirror at `../ECC`).

ECC is a *horizontal library*, gaspol is a *vertical workflow*. Adopting wholesale would
violate gaspol's lean/high-signal principle (R1). Of ECC's surface, only **5** capabilities
fill a real gap; the other ~256 (stack-specific skills, multi-harness scaffolds,
deep-research/exa, knowledge-ops, bundled MCP) are skip — gaspol already equals or beats them.

**Honest recalibration after reading bodies:** `ecc-tools-cost-audit` is a *code/infra
cost-leak auditor* (retry storms, paid-model leak), NOT a prompt-budget measurer → demoted to
a "lens" inside gaspol-review (P1). `security-review` and `eval-harness` are the strongest fits.

**This file scopes P0 only** (user decision 2026-06-09):

1. `gaspol-security-review` — new skill (LOW effort)
2. `gaspol-eval` — new skill complementing gaspol-tdd (MEDIUM effort)

Deferred: PreCompact hook + cost-leak lens (P1), agent-sort (P2).

Precedent: gaspol already selectively ports from other plugins (v1.3 took worktree/bootstrap/
tests from superpowers — never wholesale). Same pattern applies.

---

### Skill 1 — `gaspol-security-review`

**Source:** ECC `.agents/skills/security-review/SKILL.md` (self-contained checklist, 10 categories).

**Adapt for Ali's stack:**
- KEEP: secrets, input-validation, SQLi, authz (JWT/httpOnly), XSS, CSRF, rate-limit,
  data-exposure, dependency security, **Supabase RLS** (Ali uses Supabase).
- STRIP: section 9 "Blockchain Security (Solana)" — not Ali's stack.
- Keep the **Pre-Deployment Security Checklist** (17 items) as the gate artifact.

**Trigger wiring (mirror how gaspol-design auto-triggers):**
- Auto-trigger from `gaspol-plan` / `gaspol-execute` when intent/keyword fires:
  auth, secret/token/credential, API endpoint, payment, file upload, user input.
- Gate in `gaspol-finish`: run Pre-Deployment Security Checklist before merge/PR option.

**Frontmatter description** must follow gaspol convention (use-when, third person), e.g.:
"Use when adding authentication, handling user input, working with secrets, creating API
endpoints, or implementing payment/sensitive features. Provides a security checklist and
patterns adapted to the project stack; gates pre-deployment in gaspol-finish."

---

### Skill 2 — `gaspol-eval`

**Source:** ECC `.agents/skills/eval-harness/SKILL.md` (eval-driven dev; capability + regression
evals; graders code/model/human; metrics pass@k / pass^k).

**Why it fits gaspol specifically:** gaspol-tdd covers *deterministic* code (RED-GREEN-REFACTOR).
But gaspol itself + Ali's content-suite (carousel/video/linkedin) are **prompt/LLM systems** —
deterministic tests miss prompt regressions. `gaspol-eval` fills the non-deterministic gap.

**Wiring into chain:**
- `gaspol-plan`: define evals BEFORE coding (capability + regression, success metrics).
- `gaspol-verify`: run evals as part of evidence (alongside existing verify commands).
- Storage: KB `evals/<feature>.md` (reuse existing gaspol-knowledge structure).
- Graders: code-based (default), model-based (LLM-judge for prompt quality), human (optional).

**Boundary:** complements, does NOT replace gaspol-tdd. TDD for logic; eval for AI/prompt behavior.

---

### Data Integration Map

| Component | Data Source | Existing? | Notes |
|-----------|-------------|-----------|-------|
| security checklist content | ECC security-review SKILL.md | Yes (`../ECC`) | strip Solana, keep Supabase RLS |
| security auto-trigger | gaspol-plan/execute trigger pattern | Yes | reuse gaspol-design trigger mechanism |
| security pre-deploy gate | gaspol-finish merge options | Yes | insert checklist before merge/PR |
| eval harness content | ECC eval-harness SKILL.md | Yes (`../ECC`) | adapt to gaspol KB paths |
| eval storage | gaspol-knowledge KB | Yes | new `evals/` category |
| eval run | gaspol-verify evidence step | Yes | add eval run to verify commands |

### Feasibility

- Both are **content/markdown skills** — no runtime backend, no placeholder risk.
- No new MCP, no new deps. Pure skill authoring + wiring edits to plan/execute/verify/finish.
- Must update gaspol README skill table + CHANGELOG (v1.4 candidate) + plugin manifest skill list.
- Use `gaspol-write-skill` (TDD-for-skills) to author both — dogfood gaspol's own process.

---

## Implementation Plan

> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan ports/adapts content from `../ECC` into real, working skills.
> NEVER ship a skill stub or a "TODO: fill checklist later". If ECC source for a
> section is missing or unclear, STOP and ask. Skills are behavior-shaping code —
> an empty checklist is a placeholder and is forbidden.

### Goal

Add two production-ready skills to the gaspol-dev plugin (v1.3.1 → **v1.4**):
`gaspol-security-review` (LOW effort, ports ECC security checklist adapted to Ali's
stack) and `gaspol-eval` (MEDIUM effort, ports ECC eval-driven harness to cover the
non-deterministic/prompt gap that `gaspol-tdd` does not). Both are wired into the
existing chain (plan → execute → verify → finish) and authored TDD-first using
`gaspol-write-skill` (pressure + triggering tests RED → SKILL.md GREEN → REFACTOR).

### Architecture Context (from gaspol-dev/CLAUDE.md)

- **Skills live in** `skills/<name>/SKILL.md`. Each is markdown with YAML frontmatter
  (`name`, `description` in "Use when…" third-person form).
- **Tests** (per CLAUDE.md → `tests/`): two suites authored by `gaspol-write-skill`:
  - `tests/skill-triggering/` — verifies the skill fires on the right intents.
  - `tests/pressure/` — verifies rigid skills hold discipline under pressure
    ("we're in a hurry, skip security"). `gaspol-security-review` is rigid → needs one.
- **TDD-for-skills mapping** (gaspol-write-skill): Test case = pressure scenario;
  RED = agent violates behavior WITHOUT the skill; GREEN = complies WITH it;
  REFACTOR = close loopholes.
- **Auto-trigger mechanism**: mirror how `gaspol-design` is auto-triggered from
  `gaspol-brainstorm` Phase 2.5/3 and how `gaspol-adr` auto-fires — keyword/intent
  match listed in the **Skill Routing** table in `CLAUDE.md`.
- **Finish gate**: `gaspol-finish` runs a verification chain before merge/PR — the
  security pre-deploy checklist inserts here.
- **KB**: cross-project knowledge base (`~/.claude/gaspol-knowledge/`, 5 categories) —
  `gaspol-eval` adds an `evals/` storage convention (reuse existing KB plumbing).
- **Registry surfaces to update**: `README.md` skill list (~L60–75), `CHANGELOG.md`
  (top), `.claude-plugin/plugin.json` (`version`, `keywords`), roadmap line (v1.4).

### Tech Stack

- Markdown skills (no compiler). "Build" = valid frontmatter + skill loads + tests pass.
- Test harness = gaspol's existing `tests/skill-triggering/` + `tests/pressure/` scenario
  format (follow the format already in those dirs — do NOT invent a new runner).
- Source material: `../ECC/.agents/skills/security-review/SKILL.md` and
  `../ECC/.agents/skills/eval-harness/SKILL.md`.

### Data Integration Map

| Feature | Data Source | Exists? | Action |
|---------|-------------|---------|--------|
| security checklist content | `../ECC/.agents/skills/security-review/SKILL.md` | Yes | Port; strip §9 Solana; keep Supabase RLS |
| security auto-trigger | gaspol-design/adr trigger pattern in CLAUDE.md Skill Routing | Yes | Add a routing row + trigger keywords |
| security pre-deploy gate | `skills/gaspol-finish/SKILL.md` verification chain | Yes | Insert checklist step before merge/PR |
| security pressure test | `tests/pressure/` format | Yes | Add new scenario file |
| eval harness content | `../ECC/.agents/skills/eval-harness/SKILL.md` | Yes | Port; adapt paths to gaspol KB |
| eval definition step | `skills/gaspol-plan/SKILL.md` | Yes | Add "define evals before coding" for LLM features |
| eval run step | `skills/gaspol-verify/SKILL.md` evidence step | Yes | Add eval-run to verify commands |
| eval storage | gaspol-knowledge KB (`evals/`) | Partial | New category dir convention |
| skill triggering tests | `tests/skill-triggering/` format | Yes | Add scenarios for both skills |

---

### Phase A: `gaspol-security-review` — RED (authoring tests)

**Estimated time:** ~12 min

**Files:**
- Create: `tests/skill-triggering/gaspol-security-review.md`
- Create: `tests/pressure/gaspol-security-review.md`

**Steps:**
1. Write failing test for security-review triggering. Expected error: without the skill,
   agent writes an auth/secrets/API-endpoint change and ships it WITHOUT running any
   security checklist (the RED behavioral gap).
2. Run the scenario mentally/with the existing harness, confirm RED (agent skips security).
3. Write pressure scenario: user says "we're shipping now, skip the security check" —
   expected RED behavior (without skill): agent complies and skips.
4. Confirm both scenarios document the desired GREEN behavior they will later assert.
5. Commit: "test: RED scenarios for gaspol-security-review (triggering + pressure)".

**Verification:**
- [ ] Both test files follow the existing `tests/` scenario format (compared against a sibling file)
- [ ] Each defines RED (no skill) and GREEN (with skill) expected behavior explicitly
- [ ] No skill authored yet — tests describe behavior, not implementation

### Phase B: `gaspol-security-review` — GREEN (author SKILL.md)

**Estimated time:** ~15 min

**Files:**
- Create: `skills/gaspol-security-review/SKILL.md`

**Steps:**
1. Write failing test confirmation: load skill, confirm it makes the Phase A scenarios pass.
   Expected error (before authoring): skill file does not exist → triggering test cannot pass.
2. Author frontmatter: `name: gaspol-security-review`, description in "Use when adding
   authentication, handling user input, secrets, API endpoints, payment/sensitive features…".
3. Port the 10-category checklist from ECC source; **strip §9 Blockchain/Solana**; **keep**
   Supabase RLS and the 17-item Pre-Deployment Security Checklist (the gate artifact).
4. Add an "Announce at Start" line and a "Integration" section (triggered-by / gates-finish),
   matching the structure of existing gaspol skills.
5. Re-run Phase A scenarios, confirm GREEN (agent now runs checklist + holds under pressure).
6. Commit: "feat: add gaspol-security-review skill (ECC port, stack-adapted)".

**Verification:**
- [ ] Frontmatter valid; skill loads in skill list
- [ ] Phase A triggering + pressure scenarios now pass (GREEN)
- [ ] §9 Solana removed; Supabase RLS + 17-item pre-deploy checklist present
- [ ] No placeholder/TODO/empty-section in the skill body

### Phase C: `gaspol-security-review` — wire into chain

**Estimated time:** ~10 min

**Files:**
- Modify: `CLAUDE.md` (Skill Routing table)
- Modify: `skills/gaspol-plan/SKILL.md` + `skills/gaspol-execute/SKILL.md` (auto-trigger note)
- Modify: `skills/gaspol-finish/SKILL.md` (pre-deploy gate)

**Steps:**
1. Write failing test for finish-gate wiring. Expected error: a security-relevant change
   reaches `gaspol-finish` and no pre-deploy security checklist runs (gate absent).
2. Add a Skill Routing row in `CLAUDE.md`: "Auth/secrets/API/payment/upload change → `gaspol-security-review`".
3. Add auto-trigger note in `gaspol-plan`/`gaspol-execute` (same pattern as gaspol-design trigger keywords).
4. Insert the Pre-Deployment Security Checklist as a step in `gaspol-finish` verification chain.
5. Re-run, confirm the gate fires on a security-relevant change.
6. Commit: "feat: wire gaspol-security-review into plan/execute/finish".

**Verification:**
- [ ] Routing row present; trigger keywords listed
- [ ] `gaspol-finish` runs the checklist before presenting merge/PR options
- [ ] Wiring test passes (gate fires; non-security changes unaffected)

### Phase D: `gaspol-security-review` — register

**Estimated time:** ~6 min

**Files:**
- Modify: `README.md` (skill list), `CHANGELOG.md`, `.claude-plugin/plugin.json`

**Steps:**
1. Add a `- **gaspol-security-review** — …` bullet to the README skill list.
2. Add CHANGELOG entry under a new **v1.4** heading.
3. Bump `plugin.json` `version` to `1.4.0`; add `"security"` to keywords if absent.
4. Commit: "docs: register gaspol-security-review (v1.4)".

**Verification:**
- [ ] README lists the skill; CHANGELOG v1.4 entry present
- [ ] `plugin.json` version = 1.4.0
- [ ] No broken markdown in README/CHANGELOG

---

### Phase E: `gaspol-eval` — RED (authoring tests)

**Estimated time:** ~12 min

**Files:**
- Create: `tests/skill-triggering/gaspol-eval.md`

**Steps:**
1. Write failing test for eval triggering. Expected error: without the skill, agent builds
   an LLM/prompt feature and verifies it with deterministic tests only, missing prompt-regression
   coverage (the RED gap).
2. Confirm scenario documents GREEN: agent defines capability + regression evals with pass@k.
3. Add a boundary scenario: pure-logic feature → `gaspol-eval` should NOT fire (gaspol-tdd does).
4. Commit: "test: RED scenarios for gaspol-eval (triggering + boundary)".

**Verification:**
- [ ] Triggering + boundary scenarios follow existing test format
- [ ] Boundary case asserts eval does NOT replace gaspol-tdd for deterministic code

### Phase F: `gaspol-eval` — GREEN (author SKILL.md)

**Estimated time:** ~15 min

**Files:**
- Create: `skills/gaspol-eval/SKILL.md`

**Steps:**
1. Write failing confirmation: skill absent → triggering test cannot pass.
2. Author frontmatter: `name: gaspol-eval`, description "Use when implementing AI/LLM/prompt-driven
   features where deterministic tests miss behavior regressions; complements gaspol-tdd…".
3. Port eval-driven content from ECC source: capability vs regression evals, graders
   (code / model-based LLM-judge / human), metrics `pass@k` / `pass^k`, define-before-code workflow.
4. Adapt storage paths to gaspol KB `evals/<feature>.md`. Add explicit boundary vs gaspol-tdd.
5. Re-run Phase E, confirm GREEN; confirm boundary scenario still excludes pure-logic features.
6. Commit: "feat: add gaspol-eval skill (ECC eval-harness port, KB-integrated)".

**Verification:**
- [ ] Frontmatter valid; skill loads
- [ ] Phase E triggering passes; boundary case excludes deterministic-only features
- [ ] Capability/regression/graders/pass@k all present; KB `evals/` path documented
- [ ] No placeholder/empty section

### Phase G: `gaspol-eval` — wire into chain

**Estimated time:** ~8 min

**Files:**
- Modify: `CLAUDE.md` (Skill Routing), `skills/gaspol-plan/SKILL.md`, `skills/gaspol-verify/SKILL.md`

**Steps:**
1. Write failing test: LLM feature plan has no eval-definition step. Expected error: plan
   ships without evals defined before coding.
2. Add Skill Routing row: "AI/LLM/prompt feature → `gaspol-eval`".
3. Add "define evals before coding" note in `gaspol-plan` for LLM-feature phases.
4. Add eval-run as an evidence step in `gaspol-verify`.
5. Re-run, confirm evals are defined at plan-time and run at verify-time for LLM features.
6. Commit: "feat: wire gaspol-eval into plan/verify".

**Verification:**
- [ ] Routing row present
- [ ] `gaspol-plan` prompts eval definition for LLM features; `gaspol-verify` runs them
- [ ] Wiring test passes

### Phase H: `gaspol-eval` — register

**Estimated time:** ~6 min

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`

**Steps:**
1. Add README skill bullet for `gaspol-eval`.
2. Append to the v1.4 CHANGELOG entry (eval-driven dev for LLM features).
3. Add `"eval-driven"` to plugin.json keywords if absent.
4. Commit: "docs: register gaspol-eval (v1.4)".

**Verification:**
- [ ] README + CHANGELOG updated under v1.4
- [ ] plugin.json keywords include eval-driven
- [ ] Markdown valid

---

### Final Verification (whole plan)

- [ ] Both skills appear in the skill list and fire on correct intents (triggering tests pass)
- [ ] `gaspol-security-review` holds under pressure (pressure test passes) and gates `gaspol-finish`
- [ ] `gaspol-eval` complements (does not replace) `gaspol-tdd` (boundary test passes)
- [ ] README, CHANGELOG (v1.4), plugin.json (v1.4.0) all updated and consistent
- [ ] No placeholder/empty sections in either SKILL.md
- [ ] `gaspol-sync-docs` run so CLAUDE.md reflects the two new skills + routing rows

### Notes / deferred (out of scope for this plan)

- `gaspol-geo` (net-new GEO capability — gap in BOTH gaspol and ECC) → separate brainstorm.
- `seo` skill seed, `security-scan`/`security-bounty-hunter` → P1 backlog.
- 20 ECC language-reviewer agents → **skip** (gaspol-review + /code-review already cover it).

### Execution Handoff

- **Option 1 (in-session):** Start Phase A with `gaspol-execute` (per-phase checkpoints).
- **Option 2 (parallel):** Phases A–D (security) and E–H (eval) are independent →
  `gaspol-parallel` (mode: plan-phases) can run the two skill tracks concurrently.
- **Option 3 (later):** Plan file is self-contained for a fresh session.
