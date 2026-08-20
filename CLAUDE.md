# gaspol-dev — Claude Plugin Instructions

## 🧠 Vault Context Link

Skill library — agnostic, dipakai cross-project.

Pre-read kalau perlu konteks:
- `20-Projects/claude-plugin/README.md` — skill ecosystem overview
- `30-Knowledge/Claude-Skills/` — search via `obsidian` MCP `search-vault` untuk skill pattern reference
- `10-Identity/tech-preferences.md` — stack defaults (Laravel/Vue/Python/etc)
- `10-Identity/voice-tone.md` — user-facing docs

JANGAN hardcode project-specific values. Pakai `{{placeholder}}` syntax di SKILL.md / docs.

## Plugin Overview

Claude Code plugin providing **20 development skills + 4 agents** for execution fidelity, anti-placeholder enforcement, per-phase checkpoints, plan verification, cross-project knowledge base, and compounding self-maintenance. Born from building real AI-powered SaaS platforms and evolved through v1.2 (model rubric switching, step-level closure gates, industry research grounding, KB lifecycle) and v1.3 (git-worktree isolation, the `using-gaspol` auto-trigger bootstrap, continuous parallel execution, and a `tests/` skill-triggering + pressure harness — superpowers-parity hardening), and v1.9 (the always-on **Laziness Ladder** absorbed from the ponytail plugin — a SCOPE governor that pairs with the fidelity Iron Laws so code is both real and minimal).

## Architecture

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, author) |
| `.claude-plugin/marketplace.json` | Marketplace listing |
| `hooks/hooks.json` | SessionStart hook definition |
| `hooks/session-start.sh` | Session-start bootstrap — injects the 1% rule + routing directive + always-on Laziness Ladder into every session (loads `using-gaspol`) |
| `skills/_shared/laziness-ladder.md` | **NEW (v1.9)** — the default lazy-coding stance (absorbed from the ponytail plugin): YAGNI → stdlib → native → existing dep → one line ladder, with the explicit SCOPE-vs-FIDELITY boundary. Single source referenced by plan/execute/parallel + the session-start hook |
| `tests/skill-triggering/` | Auto-trigger tests — naive intent prompts must fire the right skill (`run-all.sh`) |
| `tests/pressure/` | Pressure tests — rigid skills must resist rationalization ("skip the test", "just hardcode it"). **Stochastic** — spawns real `claude` CLI runs; treat a single run's score as a sample, not a verdict, and compare against a baseline run before calling anything a regression |
| `tests/ticket-scripts/` | Deterministic bash tests for the shell scripts (`test-next-ticket.sh`, `test-scan-active-ledgers.sh`, `test-detect-stack.sh`, `test-naming-convention.sh`, `test-skill-delegation.sh`, `test-finish-gates.sh`). Fast, no API calls — run these first |
| `docs/rubric-model-switching.md` | Auto-rubric reference (Opus/Sonnet/Haiku per task type) |
| `skills/gaspol-brainstorm/SKILL.md` | Brainstorming with CLAUDE.md-first + KB query + novelty assessment |
| `skills/gaspol-brainstorm/visual-companion.md` + `visual-companion/scripts/` | **NEW (v1.7)** — browser visual-companion loop (mockups/diagrams, just-in-time offer); zero-dep Node server vendored from superpowers (MIT), session-key auth, `.gaspol/brainstorm/` state |
| `skills/gaspol-parallel/scripts/review-package` | **NEW (v1.6)** — deterministic task-diff package for the SDD review harness (rejects `HEAD~1`) |
| `skills/gaspol-parallel/scripts/dag-lanes` | **NEW (v1.8)** — deterministic DAG scheduler (stdlib `graphlib`, zero deps): task graph → dependency waves + file-isolated lanes. Replaces binary conflict-check; has `--self-test` |
| `skills/gaspol-verify/scripts/design_audit.py` | **MOVED (v1.14)** — offline static design-compliance lint (hardcoded colours/fonts, missing breakpoints, missing states, a11y gaps). Stdlib-only. Kept when `gaspol-design` was deleted because `ui-ux-pro-max`'s audit needs Playwright + a running URL and cannot run pre-merge |
| `skills/gaspol-verify/rules/` | **MOVED (v1.14)** — anti-AI-slop tables + gaspol reasoning rules (project tokens, KB precedent). Kept for the same reason: `ui-ux-pro-max` ships no anti-slop opinion layer |
| `skills/gaspol-plan/SKILL.md` | Implementation planning with Data Integration Maps + TDD gate + ticket-prefixed `-plan.md` file |
| `skills/gaspol-execute/SKILL.md` | Plan execution with TDD hard gate + tiered auto-review + plan-verifier blocking |
| `skills/gaspol-execute/scripts/detect-stack` | **NEW (v1.13)** — reads stack marker files at a project root, prints `<level>: <command>` lines (static/lint/unit/build); prints `UNKNOWN` when a marker exists but its backing command doesn't; prints nothing when there are no markers. Feeds `gaspol-verify` Layer 1, `gaspol-parallel`'s Validation Ladder L1-L3, and `gaspol-plan`'s per-phase Verification block — no more hardcoded npm |
| `skills/gaspol-execute/anti-placeholder-rules.md` | Authoritative placeholder detection reference |
| `skills/gaspol-execute/checkpoint-template.md` | Per-phase checkpoint with Auto-Review section |
| `skills/gaspol-execute/implementer-prompt.md` | Subagent dispatch template with model rubric |
| `skills/gaspol-parallel/SKILL.md` | Multi-agent parallel with mode field (plan-phases / independent-domains) + Phase 0 worktree isolation + continuous execution + per-task **Validation Ladder** (v1.8, static→unit→build→integration→edge, fail-fast `DONE` gate) |
| `skills/gaspol-parallel/spec-reviewer-prompt.md` | Spec compliance reviewer template |
| `skills/gaspol-parallel/code-quality-reviewer-prompt.md` | Code quality reviewer template |
| `skills/gaspol-worktree/SKILL.md` | **NEW (v1.3)** — Isolated git worktree (native-tool-first, Step 0 detection, gitignore safety, clean baseline) |
| `skills/gaspol-tdd/SKILL.md` | RED-GREEN-REFACTOR cycle enforcement |
| `skills/gaspol-tdd/testing-anti-patterns.md` | Testing anti-pattern reference |
| `skills/gaspol-debug/SKILL.md` | Systematic root cause debugging — no guessing |
| `skills/gaspol-debug/root-cause-tracing.md` | Backward tracing technique reference |
| `skills/gaspol-debug/defense-in-depth.md` | 4-layer validation reference |
| `skills/gaspol-debug/condition-based-waiting.md` | Condition-based polling patterns |
| `skills/gaspol-review/SKILL.md` | Code review dispatch with code-reviewer subagent + **adversarial refutation pass (v1.8)** — one refuter per Critical/Important finding (default REFUTED) kills false positives before they cost a wrong fix; unverifiable = fail-safe CONFIRMED |
| `skills/gaspol-eval/SKILL.md` | **NEW (v1.4)** — Eval-driven dev for non-deterministic/LLM features (capability + regression evals, pass@k, 3 grader types); complements tdd (ECC port) |
| `skills/gaspol-receive-review/SKILL.md` | Receiving review feedback — verify before implementing |
| `skills/gaspol-verify/SKILL.md` | 4-layer verification (technical, plan fidelity, placeholder, integration+design compliance) |
| `skills/gaspol-verify/plan-verification.md` | Plan vs code comparison process |
| `skills/gaspol-finish/SKILL.md` | Branch completion with BLOCKING plan-verifier + merge/PR/cleanup |
| `skills/gaspol-sync-docs/SKILL.md` | CLAUDE.md sync after code changes (3 modes) |
| `skills/gaspol-write-skill/SKILL.md` | Skill creation with TDD (RED-GREEN-REFACTOR for skills) |
| `skills/using-gaspol/SKILL.md` | **NEW (v1.3)** — Bootstrap meta-skill: 1% rule, routing table, instruction priority, rationalization Red Flags (the auto-trigger backbone) |
| `skills/gaspol-research/SKILL.md` | **NEW** — Industry research with freshness-aware cache + quality gates |
| `skills/gaspol-adr/SKILL.md` | **NEW** — Auto-capture Architecture Decision Records (MADR format) |
| `skills/gaspol-learn/SKILL.md` | **NEW** — Quality-gated post-ship pattern capture to KB |
| `skills/gaspol-kb-audit/SKILL.md` | **NEW** — Periodic KB health check (stale, dup, conflict, orphan) |
| `skills/gaspol-auto/SKILL.md` | **NEW** — Autonomous execution with hard-stop guardrails |
| `agents/code-reviewer.md` | Code review between commits (model: sonnet) |
| `agents/code-simplifier.md` | Simplify and refine code for clarity (model: haiku) |
| `agents/plan-verifier.md` | Step-level evidence-based plan audit (model: opus, BLOCKING) |
| `agents/spec-reviewer.md` | Verify implementation matches specification (model: opus) |

## Interactive Confirmation Rule (MANDATORY)

**ALL clarifying questions, confirmations, and option selections MUST use the `AskUserQuestion` tool.**

This shows an interactive popup modal with selectable options — NOT plain text questions buried in chat output. The user expects to see a modal they can click on, not a wall of text.

When to use AskUserQuestion:

- Brainstorming clarifying questions (Phase 1 questions, design approval)
- Phase 0.5 KB precedent surfacing ([Apply] / [Override with reason] / [Skip])
- Phase 1.5 novelty assessment (when research depth needs user decision)
- Checkpoint approvals after each phase ("Proceed to next phase?")
- Decision gates (placeholder vs real integration, merge vs PR vs keep vs discard)
- Design confirmations ("Does this look right?")
- Plan-verifier BLOCKING resolution (per-finding options)
- KB audit per-finding resolution
- Any yes/no or multiple-choice question during skill execution

Format: Always provide 3-5 selectable options. Include "Something else" or a custom-input option as the last choice.

## The Rule

**Invoke relevant skills BEFORE any response or action.**

If there is even a 1% chance a skill applies to the user's request, invoke the Skill tool first. Do not respond, do not start working, do not "just quickly do this one thing." Invoke the skill.

## Skill Routing

When a user message arrives, match it against this table and invoke the skill BEFORE responding:

| User Intent | Skill to Invoke |
|-------------|-----------------|
| Create feature, add component, build something new | `gaspol-brainstorm` |
| Design UI, pick colors, layout, styling | `ui-ux-pro-max` plugin skill (also auto-triggered by brainstorm Phase 2.5/3) |
| Plan implementation, break down a task | `gaspol-plan` |
| Execute an existing plan from `docs/plans/` | `gaspol-execute` (per-phase checkpoints) |
| Execute plan with full autonomy + hard-stop guardrails | `gaspol-auto` |
| Execute plan with parallel phases (in-session) | `gaspol-parallel` (mode: plan-phases) |
| 2+ independent problem domains (ad-hoc) | `gaspol-parallel` (mode: independent-domains) |
| Need isolated workspace / protect current branch | `gaspol-worktree` (auto-invoked by parallel Phase 0) |
| Session start / "which skill applies?" / enforce auto-trigger | `using-gaspol` (loaded by session-start bootstrap) |
| Implement or fix anything (before writing code) | `gaspol-tdd` |
| Implement an LLM/prompt/agent (non-deterministic) feature | `gaspol-eval` (define + run evals; complements `gaspol-tdd`) |
| Bug, error, test failure, unexpected behavior | `gaspol-debug` |
| Review code quality after completing work | `gaspol-review` |
| Auth, secrets, user input, API endpoint, payment, sensitive data | built-in `/security-review` (also auto-run by execute Step 3.6 + finish gate) |
| Received code review feedback from others | `gaspol-receive-review` |
| Claim work is done, ready to commit/merge | `gaspol-verify` |
| Done with feature branch, merge/PR/cleanup | `gaspol-finish` |
| Update CLAUDE.md after code changes | `gaspol-sync-docs` |
| Create or edit a skill | `gaspol-write-skill` |
| Research external library/API/pattern | `gaspol-research` |
| Architectural decision at fork point | `gaspol-adr` (usually auto-triggered) |
| Capture patterns after shipping | `gaspol-learn` (auto-triggered by finish) |
| Audit KB health (stale, duplicates, conflicts) | `gaspol-kb-audit` (quarterly) |

### Implicit Routing (Users say WHAT, skills say HOW)

| User Says | Actually Means |
|-----------|---------------|
| "Add a button" | invoke `gaspol-brainstorm` → (Phase 2.5 UI gate) → `ui-ux-pro-max` → `gaspol-plan` → `gaspol-tdd` |
| "Fix this bug" | invoke `gaspol-debug` |
| "Plan this feature" | invoke `gaspol-brainstorm` or `gaspol-plan` |
| "Review this code" | invoke `gaspol-review` |
| "I'm done with this branch" | invoke `gaspol-finish` (which triggers plan-verifier + sync-docs + learn) |
| "Write a new skill" | invoke `gaspol-write-skill` |
| "Research X vs Y" | invoke `gaspol-research` (cache-aware) |
| "Audit the knowledge base" | invoke `gaspol-kb-audit` |

### Priority Order

When multiple skills apply:

1. **Process skills first** (brainstorm, debug, plan) — determine WHAT to do
2. **Implementation skills second** (tdd, execute, auto) — determine HOW to do it
3. **Verification skills third** (verify, review, plan-verifier agent) — confirm correctness
4. **Learning skills fourth** (learn, adr, kb-audit) — capture and maintain KB

### Skill Types

**Rigid skills** — follow exactly, step-by-step, no adaptation:
`gaspol-tdd`, `gaspol-debug`, `gaspol-verify`, `gaspol-finish`, `gaspol-auto` (hard-stop conditions), `gaspol-worktree` (Step 0 detection + gitignore safety)

**Flexible skills** — apply principles to the specific situation:
`gaspol-brainstorm`, `gaspol-plan`, `gaspol-review`, `gaspol-research`

**Meta-skills** — apply to plugin ecosystem:
`gaspol-write-skill`, `gaspol-sync-docs`, `gaspol-kb-audit`, `using-gaspol` (auto-trigger bootstrap)

## Key Concepts

### Workflow Chains (skills chain automatically)

```text
brainstorm (Phase 0.5 KB + 1.5 novelty + 2.5 design gate + 3 design)
    ↓
plan (ticket-prefixed `-plan.md` file, TDD step 1 mandatory, design deliverable column)
    ↓
execute (TDD hard gate + tiered auto-review + plan-verifier BLOCKING)
    OR
auto (autonomous with hard-stop guardrails)
    ↓
verify (4 layers incl. Layer 4 design compliance)
    ↓
sync-docs (CLAUDE.md update)
    ↓
review (code quality)
    ↓
finish (plan-verifier BLOCKING + merge/PR/cleanup)
    ↓
learn (quality-gated pattern capture → KB)
```

Parallel branches:
- `gaspol-worktree` — Phase 0 isolation invoked BEFORE concurrent dispatch (required for independent-domains, recommended for overlapping plan-phases); teardown owned by `gaspol-finish`
- `gaspol-parallel mode:plan-phases` — replaces execute for independent-phase plans (continuous execution once isolated)
- `gaspol-parallel mode:independent-domains` — for unrelated multi-domain problems
- `gaspol-research` — invoked from brainstorm Phase 1.5 (NEW novelty) or standalone
- `gaspol-adr` — invoked from brainstorm Phase 2 (approach picked) or plan fork point
- `gaspol-kb-audit` — periodic (quarterly) or size-triggered, independent

### CLAUDE.md-First Approach

Before exploring ANY codebase in a target project, ALWAYS read that project's CLAUDE.md first. Extract:

- Existing routes/components (avoid duplication)
- Data sources (hooks, APIs, edge functions)
- Design system tokens (colors, patterns, component styles)
- Known gotchas (debugging checklist)
- Database tables and schemas
- Conventions (naming, file organization, patterns)

This saves 10-50k tokens per brainstorm session by avoiding redundant codebase exploration.

### Cross-Project Knowledge Base (NEW in v1.2)

Persistent cross-project memory at `~/.claude/gaspol-knowledge/`. **Works out of the box (local-only) since v1.3.1 — no GitHub required.** GitHub sync (cross-machine) is an optional upgrade. Three modes resolved by every KB skill (canonical: [docs/kb-setup.md](docs/kb-setup.md)):

- **local-only** (DEFAULT — no config, or config without `kb_remote`): auto-init the local KB on first use, read/write local files, no pull/push, never fail on a missing remote. Cross-project learning works on this machine.
- **synced** (`kb_remote` in config or `$GASPOL_KB_REMOTE` set): `git pull` before reads, `git commit && git push` after writes (per-user **private** repo — never shared).
- **off** (`"kb_mode": "off"` in config): KB disabled, skills skip silently.

**Per-user requirement:** This plugin is public. The KB is **PRIVATE PER USER** — never share a KB repo across users. Each gaspol-dev user:
1. Creates their own private repo (e.g., `<your-username>/gaspol-knowledge`)
2. Clones locally to `~/.claude/gaspol-knowledge/` (standard path, same for all users)
3. Writes `~/.claude/gaspol-config.json` with their personal remote URL

Config file schema:
```json
{
  "kb_remote": "git@github.com:<your-github-username>/gaspol-knowledge.git",
  "kb_local": "~/.claude/gaspol-knowledge",
  "kb_owner": "<your-github-username>"
}
```

Env var override (for CI or power users): `GASPOL_KB_REMOTE=git@github.com:...`

Skills that touch KB (`gaspol-research`, `gaspol-adr`, `gaspol-learn`, `gaspol-kb-audit`, `gaspol-brainstorm` Phase 0.5) resolve mode per [docs/kb-setup.md](docs/kb-setup.md): default to **local-only** (auto-init `~/.claude/gaspol-knowledge/`, write locally, no remote needed); upgrade to **synced** when `kb_remote` is configured; only disable on explicit `"kb_mode": "off"`. Remote URL is read from config — never hardcoded. The KB is no longer a prerequisite — it just works.

Structure (same on every user's machine):

```
~/.claude/gaspol-knowledge/
├── INDEX.md                  ← tagged index (grepped by brainstorm Phase 0.5)
├── ui-patterns/              ← populated by gaspol-learn (component patterns)
├── architecture/             ← populated by gaspol-learn (system-level patterns)
├── design-decisions/         ← populated by gaspol-adr (ADRs, MADR format)
├── research/                 ← populated by gaspol-research (with TTL + freshness)
└── reusable-snippets/        ← populated by gaspol-learn (hooks, helpers)
```

Entry status lifecycle: `proposed` → `accepted` → `superseded` OR `deprecated`.

Default query filter: `status=accepted`. Freshness tiers for research: 🟢 FRESH <90d / 🟡 AMBER 90-180d / 🟠 STALE 180-365d / 🔴 EXPIRED >365d.

Compounding effect: every shipped feature → `gaspol-learn` captures patterns → next project with same domain surfaces precedent in brainstorm Phase 0.5 → skip re-exploration → faster, more consistent outputs.

### Anti-Placeholder Enforcement

The 3 Iron Laws (non-negotiable):

```text
LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION
LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL
LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE
```

**Before implementing ANY component that displays data:**

1. TRACE the data source — where does this data come from?
2. CHECK the plan — does the plan specify a real integration?
3. If YES — implement the real integration. Period.
4. If about to write `const data = [...]` — STOP. Present user 3 options: (a) implement real integration, (b) skip entirely, (c) placeholder with explicit TODO. NEVER choose (c) silently.

**Data Source Classification:**

| Source Type | Status | Example |
|-------------|--------|---------|
| Hook/Context state | REAL | `const { data } = useSegments()` |
| Edge function response | REAL | `await supabase.functions.invoke(...)` |
| Props from parent (real source) | REAL | `function Card({ segment }: Props)` |
| Computed from real data | REAL | `segments.reduce(...)` |
| Local UI state (toggles, inputs) | REAL | `useState(false)` |
| Hardcoded array in component | PLACEHOLDER | `const data = [{id:1}]` |
| Empty array awaiting API | PLACEHOLDER | `const data: T[] = []` |
| String literals for dynamic content | PLACEHOLDER | `const title = "Sample"` |
| Mock function returning static data | PLACEHOLDER | `() => mockData` |
| Commented-out API call | PLACEHOLDER | `// TODO: fetch` |

### Laziness Ladder (NEW in v1.9) — absorbed from ponytail

Default coding stance, always-on. Canonical source: `skills/_shared/laziness-ladder.md`. Injected ambiently by `hooks/session-start.sh` and enforced as an explicit gate in `gaspol-plan` (scope), `gaspol-execute`, and the `implementer-prompt.md` template (`gaspol-parallel`).

Write the laziest code that actually works. Before any code, stop at the first rung that holds: (1) does it need to exist? YAGNI → skip. (2) stdlib → (3) native platform feature → (4) already-installed dep → (5) one line → (6) only then minimum code. Fewest files, shortest diff, no unrequested abstractions. Mark deliberate cuts with a `ponytail:` comment.

**Orthogonal, not conflicting — the two governors:**

| Governor | Rule | Cuts |
|----------|------|------|
| 3 Iron Laws (fidelity) | build what the plan says, real data, evidence | correctness |
| Laziness Ladder (scope) | build the minimum that satisfies it | bloat |

**The boundary (must not be misread):** the ladder cuts SCOPE, never FIDELITY. It NEVER excuses a placeholder when a real integration is specified (`const data = []` awaiting an API is a Law-1 PLACEHOLDER, not a lazy one-liner), nor skipping validation/security/tests. A "lazy" move that crosses into fake data or a skipped safety check is negligent, not lazy. Structured reports (checkpoints, data-source tables, plan-verifier evidence) stay — their CONTENT is safety — but write them terse (hemat token = ringkas laporan, not less fidelity).

**Relationship to peer plugins:** ponytail (global) governs code minimalism and is **absorbed here** so gaspol is self-contained on the coding path; caveman (global) governs prose voice — a different axis, deliberately NOT absorbed; RTK / context-mode compress tool OUTPUT at runtime — a different layer, help gaspol automatically, nothing to absorb.

### Model Switching Rubric (NEW in v1.2)

Orchestrator (main session) always Opus 4.7. Subagent dispatch chooses model by task type — see [docs/rubric-model-switching.md](docs/rubric-model-switching.md).

Quick reference:
- **Opus 4.7**: architecture planning, spec review, complex debug, research synthesis, autonomous orchestration
- **Sonnet 4.6**: feature implementation, code review, test writing, research gathering, ADR capture, learn capture, design reasoning
- **Haiku 4.5**: docs sync, simple refactor, rename/format, simple fact lookup

Applied via:
- Agent frontmatter `model:` field (4 agents: code-reviewer=sonnet, code-simplifier=haiku, plan-verifier=opus, spec-reviewer=opus)
- Agent tool dispatch with `model` param per call

Target cost mix: ~15% Opus, ~60% Sonnet, ~25% Haiku.

### Per-Phase Checkpoints (Tiered Auto-Review in v1.2)

**Durable ledger + handoff cursor (v1.5, cursor v1.9.1, per-plan v1.10, PROGRESS-<TICKET>.md v1.13):**
`gaspol-plan` creates the ledger at plan-write time as `.gaspol/progress/PROGRESS-<TICKET>.md`, containing a
`## Checklist` block (`[ ]` todo / `[>]` doing / `[x]` done / `[~]` cancelled-with-mandatory-reason) above a
`## Log` block that is ALWAYS last. After each checkpoint, `gaspol-execute`/`gaspol-parallel` tick the checklist
AND append the phase/task status to the Log — a BLOCKING gate before the next phase starts — falling back to
the shared `.gaspol/progress.md` when the plan names none (gitignored working-tree scratch, never `.git/`).
Older ledgers (`.gaspol/progress/<slug>.md`, or the lowercase-prefixed per-ticket form) are still read for
backward compatibility.
Each Log line carries a trailing **handoff cursor** — `— NEXT: <next phase, or DONE>` on a COMPLETE line, or
`— WIP — <done so far> — BLOCKER: <what's stuck> — NEXT: <exact resume action>` when a phase is left unfinished
(blocker/`/compact`/pause). It survives `/compact`; `gaspol-execute` Step 3 reads the LAST line's cursor on start
to resume from the exact `NEXT:` action and surface any open `BLOCKER:`, instead of merely inferring the first
unfinished phase. Older suffix-less lines still parse (backward-compatible). TodoWrite alone is in-memory and lost on compaction.

After completing EACH phase (never batched), present structured checkpoint report with Auto-Review section:

```text
## Phase [X] Complete: [Phase Name]

### Implemented:
- [feature] with [real data source]

### Data Sources:
| Component | Data Source | Type |
|-----------|-----------|------|
| [name] | [source] | Real / Placeholder |

### Files Modified:
- [file path] (created/modified)

### Deviations from Plan:
- None / [description + justification]

### Auto-Review (Tiered):
Classifier result: REVIEW / SKIP
Triggered because: [files>3 OR LoC>100 OR new-feature]
Or skipped because: [docs-only, config-only, rename-only]
Findings: [if REVIEW — bullets]

### Next Phase: [X+1] — [description]
-> Waiting for approval before proceeding.
```

Rules: One phase one checkpoint. Wait for user approval before next phase. Report all deviations. Classify all data sources as Real or Placeholder. Auto-review fires tiered by complexity classifier.

### Research Grounding (NEW in v1.2)

`gaspol-brainstorm` Phase 1.5 classifies task novelty:

- **PRECEDENT** — KB hit + project pattern → use precedent, skip research
- **SEMI-NEW** — KB hit OR project pattern (not both) → light 2-3 WebSearch queries inline
- **NEW** — no KB no project → invoke `gaspol-research` (deep, cached with TTL)

Research quality gates mandatory:
- ≥4 sources per topic
- Recency <18 months preferred
- Signal filter (stars, downloads, activity)
- Anti-pattern check ("X vs Y", "problems with X")
- Constraint fit (project-specific, not generic)
- Citation mandatory per claim

Anti-hallucination: WebFetch actual pages, orchestrator spot-check cache for quote accuracy.

### Step-Level Closure Gate (NEW in v1.2)

`plan-verifier` agent upgraded to step-level evidence-based audit (`agents/plan-verifier.md`):

- Parses plan into granular items (every bullet, not phase header)
- Verdict per item: FOUND (with code quote) / PARTIAL / MISSING / DIVERGED
- BLOCKING verdict if MISSING > 0 OR unapproved PARTIAL > 0 OR placeholders > 0
- Anti-hallucination spot-check: orchestrator samples 3 random FOUND items, verifies quotes

Invoked BLOCKING from:
- `gaspol-execute` Step 7 (after completion gate) — cannot claim done until CLEAN
- `gaspol-finish` Step 2 (pre-chain) — cannot present merge/PR options until CLEAN

### Design Intelligence — Delegated (CHANGED in v1.14, was a forked power peer)

`gaspol-design` is **gone**. Design intelligence now comes from the **`ui-ux-pro-max` plugin**
(84 styles, 192 palettes, 74 font pairings, 98 UX guidelines, 25 chart types, 22 stacks), invoked
as a skill from brainstorm Phase 3 and from `gaspol-plan`'s per-UI-phase Design Deliverable column.
gaspol carried a 1.4MB fork of that data; the fork drifted, the upstream did not, so the fork went.

**The reference is SOFT — there is deliberately no `dependencies` key in `plugin.json`.** That
field is all-or-nothing: if `ui-ux-pro-max-skill` were renamed, yanked, or broken, the whole of
gaspol-dev would disable with `dependency-unsatisfied`, taking down the twenty skills that have
nothing to do with design. If the plugin is missing, say so, point at
`claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`, and continue — design quality degrades,
nothing breaks.

**Three parts did NOT delegate**, because `ui-ux-pro-max` has no equivalent for any of them:

| Kept | Where | Why it could not be delegated |
|------|-------|-------------------------------|
| Offline compliance lint | `skills/gaspol-verify/scripts/design_audit.py` | 205 lines, stdlib-only, scans **source**. The upstream audit drives Chromium via Playwright against a **running URL** and lives in a scaffold template — it cannot run in `gaspol-verify` Layer 4, which is offline and pre-merge |
| Anti-AI-slop tables | `skills/gaspol-verify/rules/anti-ai-slop.md` | `ui-ux-pro-max` ships **no** anti-slop opinion layer — zero "never use" lists. Deleting this would have been a net loss |
| gaspol reasoning rules | `skills/gaspol-verify/rules/reasoning-gaspol.md` | Project-CLAUDE.md-token respect and KB precedent lookup; the file's own header calls these "not present in the base library" |

Integration points that survive unchanged: planning (Design Deliverable column), execute Step 3.5
fidelity check, verify Layer 4 compliance (still FAILS below score 60), and learn capture of UI
patterns to the KB.

Anti-AI-slop enforcement rules:

**NEVER use**: Inter/Roboto/Arial as primary, purple gradients on white, predictable symmetric layouts, cookie-cutter card grids, emojis as icons

**ALWAYS choose**: Distinctive display fonts, sharp accent contrast, asymmetric/grid-breaking layouts, intentional motion (150-300ms), layered backgrounds

Output format: Aesthetic Direction → Color Palette (hex codes) → Typography (font pairings) → Component Examples (code in detected stack) → Layout Blueprint (ASCII) → Component States → Motion Plan → Accessibility → Anti-AI-Slop Self-Check

### KB Self-Maintenance (NEW in v1.2)

`gaspol-kb-audit` skill keeps KB from becoming sampah:

6 check types:
1. Stale (status=accepted, last_validated >180d)
2. Duplicates (title >80% overlap + tag overlap ≥80%)
3. Conflicts (same tag+domain, different verdicts)
4. Orphans (source_project no longer exists locally)
5. Broken refs (supersedes/superseded_by pointing to nonexistent)
6. Unpromoted proposed (>90d without validation)

Per-finding resolution via AskUserQuestion: `[Promote]` / `[Supersede]` / `[Archive]` / `[Merge]` / `[Keep — bump last_validated]`

Health thresholds: 🟢 Green <10% stale | 🟡 Yellow 10-25% stale → audit recommended | 🔴 Red >25% stale → mandatory audit blocks new captures

### Brainstorming Flow (gaspol-brainstorm) — UPDATED in v1.2, hardened in v1.5

When user wants to create, add, or modify anything:

0. **HARD-GATE (v1.5)**: no implementation skill / code / scaffold until a design is
   presented AND user-approved — every project, regardless of perceived simplicity.
1. **Phase 0**: Read project's CLAUDE.md (MANDATORY before any codebase exploration)
2. **Phase 0.5**: KB cross-project query (MANDATORY — git pull, grep INDEX.md, surface precedent)
3. **Phase 1**: Ask clarifying questions ONE at a time via AskUserQuestion (**decompose gate
   (v1.5)**: flag multi-subsystem requests first, split into sub-projects, each its own cycle)
4. **Phase 1.5**: Novelty assessment (PRECEDENT / SEMI-NEW / NEW → decide research depth)
5. **Phase 2**: Propose 2-3 approaches with trade-offs + MANDATORY source citations (from research cache or live research)
6. **Phase 2.5**: Design gate (explicit AskUserQuestion if UI detection ambiguous)
7. **Phase 3**: Design Intelligence (AUTO-TRIGGERED for UI work) — invokes the `ui-ux-pro-max` plugin skill
8. **Phase 4**: Implementation feasibility check (REAL data paths, existing backend)
9. **Phase 5**: Present design in 200-300 word sections, AskUserQuestion confirm per section, include Data Integration Map
10. **Phase 6**: Mint ticket, write to `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md`;
    **spec self-review (v1.5)** (scan for placeholder/contradiction/ambiguity/scope) + **user
    reviews the written spec** before offering to proceed to `gaspol-plan`, which writes a
    separate dated `-plan.md` file (same ticket, reused — not re-minted)

### TDD Enforcement (gaspol-tdd) — Hard-Gated by execute in v1.2

Iron Law: `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`

RED-GREEN-REFACTOR cycle:

1. **RED**: Write ONE minimal failing test. State WHY it will fail and WHAT error to expect BEFORE writing it
2. **Verify RED**: Run test, confirm it fails for the expected reason (not setup error)
3. **GREEN**: Write SIMPLEST code to pass. No extra features. No refactoring
4. **Verify GREEN**: Run ALL tests. Zero failures, zero errors, zero warnings
5. **REFACTOR**: Improve code quality. No new behavior. Run ALL tests after every change
6. Repeat

**Hard gate in `gaspol-execute` Step 2**: phase description MUST contain step 1 format `"Write failing test for [behavior]. Expected error: [error]."` — execute refuses to run phase without it.

If code was written before test: DELETE IT. Start over. No exceptions.

### Systematic Debugging (gaspol-debug)

Iron Law: `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST`

4 Phases:

1. **Root Cause Investigation**: Read FULL error + stack trace. Reproduce consistently. `git log --oneline -20`. Isolate layer. Backward tracing (symptom → immediate → upstream → root)
2. **Pattern Analysis**: Find working examples FIRST. Read working version COMPLETELY. Compare systematically
3. **Hypothesis and Testing**: One hypothesis, one change, one test. 3 attempts fail → STOP, question architecture
4. **Implementation**: Create failing regression test. Implement single fix. Verify. Check regressions

### 4-Layer Verification (gaspol-verify) — Layer 4 Extended in v1.2

Iron Law: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

**The Gate Function** (5 steps, no shortcuts):

1. IDENTIFY — what command proves this claim?
2. RUN — execute the FULL command, fresh, not from cache
3. READ — complete output, check exit code, count failures
4. VERIFY — does output actually confirm the specific claim?
5. ONLY THEN — make the claim, quote the evidence

**Layer 1: Technical** — commands are derived, never hardcoded: run `skills/gaspol-execute/scripts/detect-stack <project-root>`, which prints `<level>: <command>` lines (e.g. `unit: npm test`, `static: npx tsc --noEmit`). Three cases: a `<level>: <command>` line → run it, must exit 0 / 0 failures; `<level>: UNKNOWN` (marker present, no backing command) → STOP and ask the user; zero lines (no stack markers) → fall back to the plan-declared commands, recorded explicitly as `detect-stack: no stack markers, using plan-declared commands` rather than silently skipped

**Layer 2: Plan Fidelity** — use upgraded `plan-verifier` agent (step-level, evidence-based, BLOCKING if MISSING>0)

**Layer 3: Placeholder Scan** — search changed files for TODO/FIXME/HACK/placeholder/mock/dummy patterns, check for hardcoded data, missing imports, dead code, console.log

**Layer 4: Integration + Design Compliance** — verify data flows end-to-end; design system compliance (tokens used, responsive breakpoints, semantic HTML, ARIA labels, contrast ratios) via `scripts/design_audit.py`

### Plan Structure (gaspol-plan) — UPDATED in v1.2

Every plan MUST include:

- **Data Integration Map** (contract between planner and executor):

```text
| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-----------|----------|---------|--------|
```

- **Per-phase verification criteria** (no phase ships without checks)
- **TDD-first step 1** (MANDATORY): `"Write failing test for [behavior]. Expected error: [error]."`
- **Design Deliverable column** (for UI phases): tokens, layout, states, motion, a11y
- Bite-sized tasks (2-5 minutes each, one action per step)
- Plan header with gaspol-execute instruction

Plans saved to: `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md` — ticket reused from the preceding `gaspol-brainstorm` spec file (found by glob `docs/plans/*-<TICKET>-*-spec.md`; STOP and ask the user which spec if more than one matches) if one exists, else minted fresh. Spec and plan are always separate files; the suffix (`-spec.md` vs `-plan.md`) says which stage produced it. Seven pre-ticket files in `docs/plans/` predate this convention and are deliberately not renamed.

### Parallel Execution (gaspol-parallel) — Mode Field in v1.2, Worktree + Continuous in v1.3, SDD harness in v1.6

**SDD review harness (v1.6, superpowers #2):** the implementer reports an explicit terminal
**Status** — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` — and the orchestrator
routes on it (`NEEDS_CONTEXT` → provide + re-dispatch; `BLOCKED` → assess, never blind-retry).
Record the base SHA before dispatch and build a deterministic review artifact with
`skills/gaspol-parallel/scripts/review-package <BASE> HEAD` (writes `.gaspol/review/*.diff`;
rejects `HEAD~1` as BASE). Dispatch each task with an **explicit model** scaled by class
(`docs/rubric-model-switching.md`; "turn count beats token price"). Critical/Important review
findings trigger a **fix → re-review loop** until clean.

**Validation Ladder (v1.8) — `DONE` gate:** before an implementer may report `DONE`, it runs an
ordered fail-fast ladder, stopping at the first failure: **L1 Static** (tsc + lint) → **L2 Unit**
→ **L3 Build** → **L4 Integration** → **L5 Edge** (non-happy paths actually run). Cheap checks
gate expensive ones; fail at level N → fix → restart from N; an N/A level is skipped *explicitly*
(silent skip = placeholder-grade lie). This is per-task self-verification depth — it does NOT
replace the independent spec + quality reviews (different subagent, different guarantee).

**Phase 0 (v1.3):** invoke `gaspol-worktree` BEFORE concurrent dispatch — required for `independent-domains`, recommended for overlapping `plan-phases`. Parallel agents in a shared working directory race on files.

**Continuous execution (v1.3):** once the task list is confirmed and the workspace is isolated, execute all tasks without pausing to check in between them. The only always-pause conditions: review fails after 3 attempts, genuine ambiguity, Iron Law violation / destructive op, or all tasks complete. Update the visual task tracker instead of narrating each task.

Fresh subagent per task + two-stage review:

**Mode `plan-phases`:** execute independent phases from plan
1. Implementer dispatched with full task text (NEVER reference a file), anti-placeholder rules, self-review
2. Spec Review — reads ACTUAL CODE, compares to requirements line by line
3. Code Quality Review — uses code-reviewer template, reviews commits between base SHA and HEAD
4. If spec fails after 3 attempts → stop and escalate

**Mode `independent-domains`:** solve 2+ unrelated problems concurrently
- **DAG lane scheduling (v1.8) BLOCKING** — declare each task's `deps` + `files` (DB table = synthetic `db:<name>` token), run `scripts/dag-lanes` → dependency **waves** + file-isolated **lanes**. Replaces the old all-or-nothing conflict check: one dependency no longer serializes the whole batch; independent tasks still parallelize, dependents wait for their wave. Matrix is the proof no two concurrent tasks touch the same file.
- Wave-by-wave dispatch (one batch of concurrent Agent calls per wave, one per lane; multi-task lanes run sequentially); start wave N+1 only after wave N returns
- Integration phase: read summaries, test together, resolve conflicts

Final review: plan-verifier (mode:plan-phases) or full verify (mode:independent-domains).

### Receiving Review Feedback (gaspol-receive-review)

Response pattern: READ → UNDERSTAND → VERIFY → EVALUATE → RESPOND → IMPLEMENT

**Forbidden responses**: "You're absolutely right!", "Great point!", "Great catch!", "Thanks for pointing that out!" — performative agreement, not technical assessment

**Instead**: "Fixed. [description]." / "Good catch. [root cause]. Fixed in [location]." / "I checked this — the current code is correct because [reason]."

When feedback is unclear: STOP. Do not guess. Ask for clarification with specific interpretation options.

### Finishing Work (gaspol-finish) — six-step chain, three of them BLOCKING

Pre-finish verification chain (MANDATORY — all six, in order, none conditional on the diff):

1. Run `gaspol-verify` (all 4 layers)
2. Run `plan-verifier` agent **BLOCKING** (step-level, evidence-based, spot-check 3 random FOUND items).
   If BLOCKING → return to execute, fix, re-run. Do not waste a review pass on code about to change.
3. Run `gaspol-review` at **Tier 1** — **BLOCKING** on any Critical finding that survives the
   Step 2.5 refutation pass. Fix and re-run before proceeding.
4. Run the built-in **`/security-review`** — **ALWAYS**, on every branch, regardless of whether
   the diff looks security-sensitive. A finding BLOCKS: resolve via AskUserQuestion
   (`[Fix now]` / `[Accept risk with documented reason]`) before any merge option is offered.
   If the command is unavailable, say so and walk the same ground by hand — never record it as
   passed when it did not run.
5. Run `gaspol-sync-docs` (update CLAUDE.md)
6. Trigger `gaspol-learn` for pattern capture (quality-gated, user confirms)

**After the chosen option executes (IDS-3):** close the ledger. Append a final `## Log` line
to `.gaspol/progress/PROGRESS-<TICKET>.md` ending `— NEXT: DONE`, confirm no `[ ]`/`[>]` is left
in the Checklist, and run `skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress` to
surface any other ticket still in flight. The ledger is gitignored, so a stale one is invisible to
`git status` — nothing else closes it.

**Merging is not publishing (IDS-3).** A local merge leaves the work on one machine. Push, and for
a plugin repo also run `claude plugin marketplace update <marketplace>` +
`claude plugin update <plugin>@<marketplace>` (the full id — the bare name fails with
`Plugin "<name>" not found`), then restart Claude Code. The post-merge test command is derived from
`skills/gaspol-execute/scripts/detect-stack`, never hardcoded to npm.

Then present exactly 4 options via AskUserQuestion:

- **Merge locally** — `git merge --no-ff`, verify tests, delete branch
- **Push and create PR** — `git push -u`, `gh pr create`
- **Keep as-is** — leave branch, report status
- **Discard** — requires typed "discard" confirmation

### Sync Docs (gaspol-sync-docs)

3 modes:

- **Mode 1: Post-Implementation Sync** — scan git diff, map changes to CLAUDE.md sections, apply updates
- **Mode 2: Quality Audit** — score CLAUDE.md against 6 criteria (100 points), grade A-F
- **Mode 3: Session Learning Capture** — reflect on missing context, propose one-liner additions

### Autonomous Mode (gaspol-auto) — NEW in v1.2

For familiar codebase + verified plan. Pre-flight gate, hard-stop guardrails, consolidated post-run report.

Pre-flight checks:
1. Plan review + user approval (AskUserQuestion)
2. Clean git state
3. Baseline tests pass
4. Plan TDD gate (every phase has step 1 TDD)

Execution: phase-by-phase without per-phase checkpoint. Hard-stop conditions:
- Test failure
- Placeholder trigger
- Destructive operation
- Ambiguity in plan
- Iron Law violation
- 3+ consecutive errors

NEVER autonomous: merge-to-main, force-push, PR creation, external messaging, plan modifications.

Post-run: auto-invoke verify chain + plan-verifier BLOCKING + consolidated report.

### Writing Skills (gaspol-write-skill)

TDD applied to process documentation:

- **RED**: Run agent WITHOUT skill, document failures
- **GREEN**: Write minimal SKILL.md addressing each failure
- **REFACTOR**: Re-test WITH skill, close loopholes

SKILL.md frontmatter `description` must start with "Use when..." — triggering conditions ONLY, NEVER summarize the workflow (Claude follows summary instead of reading full skill).

## Red Flags: Rationalizations for NOT Invoking Skills

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "This is too simple for a skill" | Simple tasks still benefit from process discipline |
| "I already know how to do this" | Skills encode lessons learned; your memory doesn't |
| "It'll be faster without the skill" | Faster now = slower later when bugs appear |
| "The user just wants a quick answer" | Quick answer + correct process > quick answer + debt |
| "I'll follow the skill mentally" | Mental following = skipping steps. Invoke it. |
| "This skill doesn't quite fit" | 1% chance = invoke. Let the skill decide. |
| "The user didn't ask for TDD" | Users say WHAT, not HOW. TDD is HOW. |
| "I'll invoke it after I start" | After = never. Invoke BEFORE any work. |
| "This is just a one-line fix" | One-line fixes break things too. Follow the process. |
| "I already read the skill before" | Skills are invoked, not memorized. Invoke it. |
| "The skill will slow me down" | The skill prevents going fast in the wrong direction. |
| "No need to query KB — I know this" | KB has project patterns you forgot. Query it. |
| "Training data is fresh enough" | Cutoff Jan 2026. Industry moves fast. Use gaspol-research. |
| "Plan-verifier is optional" | BLOCKING in v1.2. Cannot claim done without CLEAN verdict. |

## Debugging (Plugin Development)

| Issue | Check |
|-------|-------|
| Skill not loading | Verify `SKILL.md` exists in `skills/<name>/` with correct YAML frontmatter |
| Skill not triggering | Check `description` field in frontmatter — must contain triggering conditions |
| Agent says "looks fine" without running commands | `gaspol-verify` not invoked — Iron Law: no claims without fresh evidence |
| Placeholders slipping through | `gaspol-execute` anti-placeholder rules not enforced — check Data Source Classification |
| Agent jumps to code without asking questions | `gaspol-brainstorm` not invoked — Phase 1 requires questions ONE at a time |
| Agent writes code before tests | `gaspol-tdd` not invoked OR execute hard gate bypassed — check phase step 1 format |
| Agent guesses at bug fixes | `gaspol-debug` not invoked — Iron Law: no fixes without root cause investigation |
| Agent claims "done" without evidence | `gaspol-verify` not invoked OR plan-verifier not BLOCKING — 4-layer verification required |
| Agent batch-completes phases | Checkpoint rules violated — one phase, one checkpoint, one approval |
| Agent uses performative agreement | `gaspol-receive-review` not invoked — forbidden responses list |
| Agent creates duplicate hooks/contexts | CLAUDE.md-first rule not followed — check existing architecture before creating new |
| Session-start hook not firing | Check `hooks/hooks.json` matcher pattern and `session-start.sh` permissions |
| Skills not listed in session | Check that `CLAUDE.md` exists and is loaded by Claude Code |
| KB not surfacing precedent | Phase 0.5 skipped, OR KB still empty (nothing captured yet via adr/learn). Local-only auto-inits `~/.claude/gaspol-knowledge/` — check `"kb_mode":"off"` isn't set; see [docs/kb-setup.md](docs/kb-setup.md) |
| Research claims without citations | `gaspol-research` quality gates not enforced — every claim needs URL |
| Cache stale but used as-is | Freshness tier not checked — research entries need age filter |
| Generic "Inter font" recommendation | anti-AI-slop rules bypassed — check `skills/gaspol-verify/rules/anti-ai-slop.md` |
| Design not integrated in plan | Phase 2.5 gate skipped — UI detection may need explicit AskUserQuestion |
| KB growing with junk | `gaspol-learn` quality gate not enforced — require min 200 words, tags, no duplicates |
| Old ADRs surfacing as precedent | `gaspol-kb-audit` overdue — run quarterly |

## Conventions for Contributors

### Adding a New Skill

1. Create `skills/gaspol-<name>/SKILL.md` with YAML frontmatter including `description` starting "Use when..."
2. Follow RED-GREEN-REFACTOR process from `gaspol-write-skill`
3. Update this CLAUDE.md with skill entry in Architecture and Skill Routing tables
4. Update `hooks/session-start.sh` routing block AND `skills/using-gaspol/SKILL.md` routing table to include the new skill
5. Update `.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json` skill count / version if listed
6. Add supporting reference files in the skill directory if needed
7. Add a trigger test: `tests/skill-triggering/prompts/<skill>.txt` (naive intent prompt) + list it in `run-all.sh`. For rigid skills, add a `tests/pressure/` case. Run before bumping the version.

### Editing a Skill

1. Read the existing SKILL.md completely
2. Make changes, preserving the skill structure (Iron Law, Core Principle, Process, Red Flags, Rationalization Table, Integration)
3. Re-test with a pressure scenario to verify changes work
4. Update this CLAUDE.md if skill description or routing changed

### File Naming

- Skill directories: `gaspol-<kebab-case-name>/`
- Main skill file: always `SKILL.md`
- Reference files: lowercase, kebab-case (e.g., `anti-placeholder-rules.md`)
- Agent files: `<kebab-case-name>.md` in `agents/`

## gaspol Ticket Counter

Prefix: IDS
Last ticket: IDS-3

---

**Version:** 1.14.0
**Last Updated:** August 2026
