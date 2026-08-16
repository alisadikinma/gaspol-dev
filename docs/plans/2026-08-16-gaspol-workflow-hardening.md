# gaspol-dev Workflow Hardening: Review/Ledger/Ceremony Fixes

## Design

### Context

This design comes from two internal sources — not from any external plugin's design:

1. **Operational audit of gaspol-dev's own conventions.** `gaspol-write-skill/SKILL.md`
   (lines 73-87) already states a rule — skill descriptions must be trigger-conditions-only,
   never a workflow summary, because the description is loaded every session and Claude
   follows it as a shortcut instead of reading the full skill body. Several live skill
   descriptions violate gaspol-dev's own stated rule (confirmed by grep — see Item 1).
   Ceremony scaling (Item 2), skill-authoring craft (Items 4/5), and review-lane
   decomposition (Item 7) are general operational practices, independently validated below
   against current industry sources rather than copied from any single external project.

2. **Vault review of past execute-vs-design incidents** (Obsidian vault,
   `30-Knowledge/coding-workflow-patterns.md`, `20-Projects/IRN-Logistik/README.md`,
   `40-Daily/2026-08-08.md`, `30-Knowledge/deck-b2b-standard.md`). Recurring pattern: **a
   passing per-phase/text-level gate is not a quality claim.** Concrete precedent:
   - *"Per-phase TDD gates are not a quality claim. Four defects passed unit-green and
     per-feature e2e, surfacing only in cross-file integration and real browser use."*
   - IRN QA batch-2: *"Doc yang berjanji ≠ kode yang menjalankan"* — spec said X, code did
     Y, the test locked the bug in; caught in a QA/code-review pass after prod, not before.
   - Deck Ekaputra Dinata Utama §0d: *"Review render = fase tersendiri — PASS di teks,
     BLOCKING di render, hari yang sama."*
   - IRN's own established practice: `🚦 GATE WAJIB: Design-first — prototype Figma →
     approval Ali → BARU development.`

   Items 6, 6b, 7 below close this gap inside gaspol-dev's own workflow.

3. A third, independent request: ledger filenames collide when two plans are in flight
   (Item 8).

4. A fourth, independent observation: gaspol's context-survival mechanism (the durable
   ledger) is currently **reactive only** — it survives `/compact` and session restart, but
   nothing proactively suggests a fresh session before a long execution run degrades. Claude
   Code itself auto-compacts transparently as context approaches its limit; gaspol's own gap
   is that nothing on gaspol's side offers a clean breakpoint before that happens (Item 9).

All items are markdown/skill-file edits inside the `gaspol-dev` plugin source repo itself
(no external project touched). No UI — Phase 3 design intelligence not invoked.

---

### Token-Efficiency Validation (required before finalizing scope)

Before locking this design, ran a live web-research pass (2026-08-16) to confirm none of the
additions burn context/token budget beyond what the fix is worth. Findings:

- **Multi-agent fan-out is expensive and often not worth it.** Anthropic reports
  multi-agent systems run **~15× the tokens of a chat interaction**; naive multi-agent setups
  add **3-10× cost** with communication-instability risk
  ([EITT, "AI Agents 2026"](https://eitt.academy/knowledge-base/ai-agents-2026-guide-from-llm-to-multi-agent-systems/)).
  For code review specifically, **"multi-agent methods are generally the most costly"** and a
  single agent already handles tasks of 5-10 steps in one competency domain — which covers
  most code-review scenarios
  ([Medium, "Multi-Agent in Production in 2026: What Actually Survived"](https://medium.com/@Micheal-Lanham/multi-agent-in-production-in-2026-what-actually-survived-f86de8bb1cd1)).
  The pattern fails specifically when **coordination overhead exceeds the cost of doing the
  work manually**; teams that reach for multi-agent because "it sounds sophisticated" end up
  debugging overhead a single well-structured agent would have avoided
  ([Augment Code, "Multi-Agent Orchestration: A Practical Architecture"](https://www.augmentcode.com/guides/multi-agent-orchestration-architecture-guide)).
  → **Item 7 (review lanes) is redesigned below as tiered, not a flat 5-way fan-out.**
- **Skill descriptions are a genuine always-on cost.** They load into every session's system
  prompt regardless of whether the skill is used that session; the combined
  description+when-to-use text is truncated around 1,536 characters, the budget scales with
  the model's context window, and least-used skills' descriptions get dropped first when the
  budget overflows
  ([Claude Code docs, "Explore the context window"](https://code.claude.com/docs/en/context-window);
  [Quinton Wall, "Best practices to make Claude Code skills token-efficient"](https://www.quintonwall.com/writing/best-practices-to-make-claude-code-skills-token-efficient)).
  → **Item 1 (trim descriptions to trigger-only) is confirmed as a real efficiency fix, not
  cosmetic.**
- **Ceremony should scale with task size and risk, not run flat.** Process preparation
  before execution is the rate-limiting factor for output quality; single-agent, low-ceremony
  workflows handle contained tasks well, and teams add explicit orchestration only as tasks
  grow larger or more critical
  ([Anthropic, "How to scale agentic coding across your engineering organization"](https://claude.com/blog/scaling-agentic-coding)).
  → **Item 2 (three-path ceremony router) is validated as-is** — it already gates heavy
  machinery (KB query, novelty check, spec file) to the architectural path only.
- **Items 4, 5, 6, 8 carry no incremental agent-fan-out cost** — they are authoring-guidance
  additions (4, 5), a single opt-in artifact render gated to architectural-path plans only
  (6), and local shell scripting with no LLM calls (8). No change needed on efficiency
  grounds.

This section is the standing citation trail for every "why does this cost what it costs"
question the plan below answers per item — see each item's own note on tiering/gating.

---

### Item 1 — Description compliance audit

Confirmed violations of gaspol-dev's own rule (mechanism prose inside the trigger-only
`description` field, grepped from the live skill files):

- `gaspol-parallel`: "...Dispatches fresh subagent per task with anti-placeholder
  enforcement, DAG lane scheduling (dependency waves + file-isolated lanes for max safe
  parallelism), and two-stage review (spec compliance then code quality)."
- `gaspol-review`: "...Dispatches code-reviewer subagent with enhanced placeholder
  detection, then an adversarial refutation pass..."
- `gaspol-finish`: "...Guides completion with mandatory verification chain: plan-verifier,
  sync-docs, then presents structured merge/PR/cleanup options."
- `gaspol-learn`: "...Distills reusable patterns from completed work, captures them to
  cross-project knowledge base with user confirmation and quality gate validation..."
- `gaspol-sync-docs`, `gaspol-adr`: same pattern.

**Scope:** audit all 22 `skills/*/SKILL.md` frontmatter `description` fields against the
existing rule in `gaspol-write-skill`. For each violation: trim to "Use when [triggering
conditions]" only; move the mechanism/workflow detail (already present) down into the body
if not already there. Do not shorten any description that is already trigger-only. Update
`CLAUDE.md`'s Skill Routing table only if a routing-table row quotes the old
mechanism-heavy description verbatim. Bump `CLAUDE.md` version line (currently stale at
1.9.1; git is at 1.10.1) to the version this batch ships as.

---

### Item 2 — Three-path brainstorm router (spike / bounded / architectural)

`gaspol-brainstorm/SKILL.md` currently runs the same Phase 0→6 pipeline (KB query, novelty
classification, design gate, spec file, self-review, user-reviews-spec) regardless of task
size. Validated by the efficiency research above: contained tasks should stay low-ceremony;
heavier orchestration should only kick in as task size/risk grows. Classify the request
first and scale ceremony:

- **Spike** — feasibility question, no spec file, 2-3 sentence probe + nod, report a
  recommendation.
- **Bounded** — well-scoped change to existing code (a flag, a small endpoint, a one-file
  fix). Clarifying questions + a short **in-chat** design (no spec file, no Phase 0.5/1.5/2.5
  ceremony). Approval gate is as hard as architectural — just lighter artifact.
- **Architectural** — new subsystems, interface changes others depend on. Full existing
  gaspol-brainstorm pipeline, unchanged.

**One-way ratchet:** hidden complexity discovered mid-task upgrades the path (spike→bounded,
bounded→architectural); nothing downgrades mid-task. Add a Red-Flags table for the
classification-dodge rationalizations ("it's bounded, I'll skip the spec", "I understand this
kind of app so it's bounded" — bounded measures the repo, not familiarity).

**Scope:** add a classification step at the top of `gaspol-brainstorm/SKILL.md` Phase 1,
before the decompose gate. Gaspol's KB (Phase 0.5), novelty assessment (Phase 1.5), and
design-gate (Phase 2.5/3) machinery are **architectural-path only** after this change —
they do not run for spike/bounded. HARD-GATE (no implementation before approval) applies
to all three paths unchanged.

---

### Item 4 — Match-the-Form-to-Failure framework

`gaspol-write-skill/SKILL.md` has rationalization tables but no meta-framework for choosing
*which* guidance form to write for a given failure mode:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips/violates a rule under pressure | Prohibition + rationalization table + red flags | Soft guidance ("prefer...") |
| Complies, but output has the wrong shape | Positive recipe/contract: state what the output IS | Prohibition list ("don't restate") |
| Omits a required element | Structural: REQUIRED field/slot in the template | Prose reminders near the template |
| Behavior should depend on a condition | Conditional keyed to an observable predicate | Unconditional rule + exemptions |

Plus two wording rules: no nuance clauses ("don't X unless it matters" reopens negotiation),
and exemption clauses don't scope (restructure so the excluded part can't reach the rule).

**Scope:** add this as a new section in `gaspol-write-skill/SKILL.md`, between "Bulletproofing"
and "Skill Creation Checklist". Add a checklist item: classify the baseline failure type
before choosing rationalization-table vs recipe vs structural-field vs conditional.

---

### Item 5 — Micro-test wording pass

`gaspol-write-skill/SKILL.md`'s "Testing Skills After Creation" section has Manual /
Automated / Meta testing but no cheap pre-pass before a full pressure-scenario run: one
fresh-context sample per wording variant, always with a no-guidance control (if the control
doesn't fail, there's nothing to fix — stop), 5+ reps, every flagged match read manually (not
just counted), variance-as-metric (five different interpretations across five reps = the
wording isn't binding, tighten before adding words).

**Scope:** add a "Micro-Test Wording Before Full Pressure Scenarios" subsection under
RED-GREEN-REFACTOR in `gaspol-write-skill/SKILL.md`, positioned as a cheap gate before the
existing (more expensive) subagent pressure-scenario testing — it does not replace it.

---

### Item 6 — Post-plan design-artifact gate

`gaspol-plan/SKILL.md` currently ends with "Ready to set up for implementation?" straight
to `gaspol-execute`. Nothing renders the planned flow for a human look before code starts.
Precedent this closes: IRN-Logistik's own established gate (Figma prototype → approval →
development), and the "don't trust a layout you haven't seen rendered" lesson (two bugs in
`coding-workflow-patterns.md` were invisible to code review, only visible in a rendered
preview).

**Scope:** add a step at the end of `gaspol-plan/SKILL.md`, after the plan file is written
and before the execute handoff question — **gated to architectural-path plans only** (Item
2's classification; bounded/spike plans skip silently, keeping the cost proportional to
task size per the efficiency findings above). `AskUserQuestion`: offer to render a design
artifact of the plan's flow before execute starts. Options: **(a)** yes, render it — use the
`Artifact` tool: an HTML mockup (reusing the `gaspol-design`/visual-companion pattern) if the
plan is UI-flow-heavy, or an embedded mermaid diagram (sequence/flow/state) if the plan is
backend/data-flow-heavy; **(b)** skip. Default-recommended, not upfront-forced. The rendered
artifact URL/path, once approved, gets recorded in the plan file header alongside the
existing ledger-path field (see item 8) so later review stages (item 6b) can find it.

---

### Item 6b — Artifact becomes a cross-check input

Once item 6 exists, the artifact it produces is not decorative — later checks read it:

- The Plan+Artifact-compliance lane in `gaspol-review` (item 7, Tier 1) compares the shipped
  behavior against the approved artifact, not only against the text plan.
- `gaspol-verify` Layer 4 (currently "Integration + Design Compliance" — design-token/a11y
  checks via `scripts/design_audit.py`) gains an artifact-comparison check when a plan header
  names an artifact path: does the implemented flow match what was approved, not just does it
  use the right design tokens.

**Scope:** `gaspol-review/SKILL.md` (Tier 1 lane, see item 7) + `gaspol-verify/SKILL.md`
Layer 4 section — both read the plan header's artifact-path field (added by item 6) when
present; no-op when absent (older plans, or plans that skipped the item-6 offer).

---

### Item 7 — Tiered gaspol-review lanes + mandatory finish gate

Compared against a general-purpose 5-lane PR reviewer pattern (CLAUDE.md compliance / bug
scan / git-history context / previous-PR-comments / code-comment compliance, then
confidence-scoring), `gaspol-review` currently dispatches **one** reviewer agent
(`agents/code-reviewer.md`, a single six-category checklist: quality, architecture, testing,
requirements, production-readiness, data-integrity), then adversarial refutation on
Critical/Important findings.

gaspol's refutation step (an independent agent trying to *disprove* each high-severity
finding, default-REFUTED, fail-safe CONFIRMED on unverifiable) is more rigorous than a
self-reported confidence score and **is kept as-is, unchanged**. The real gap is a dedicated
**plan/artifact-compliance pass** — the single agent's "Requirements" checklist bullet is one
line inside six categories, and it has no knowledge of the design artifact (item 6 didn't
exist before this batch). That gap is exactly what the vault incidents in the Context section
describe: a per-phase or text-level pass gives false confidence when the actual divergence is
in cross-file integration or rendered output.

**Given the token-efficiency findings above (flat multi-agent fan-out is the most costly
review pattern and often not worth it), this is deliberately tiered, not a flat 5-way split:**

- **Tier 0 (default — every review):** unchanged single core lane (`agents/code-reviewer.md`,
  minus its "Requirements" bullet, now owned by Tier 1) + existing adversarial refutation.
  Same cost as today.
- **Tier 1 (triggered by: `gaspol-finish`'s BLOCKING gate, OR the plan is architectural-path
  per item 2/6):** add exactly **one** more lane — `plan-artifact-reviewer.md` — reads the
  plan file and, if present, the item-6 artifact; reports FOUND/PARTIAL/MISSING/DIVERGED per
  plan item using `plan-verifier`'s existing vocabulary. Two agents total, not five.
- **Tier 2 (opt-in only — Tier 1 surfaces a contested/ambiguous finding, or the user
  explicitly asks for a deeper pass):** add `git-history-reviewer.md` (git log/blame on
  changed files, flags reintroduced-bug patterns) and `code-comment-reviewer.md` (does the
  diff follow existing in-file guidance it touches).
- **PR-comments lane:** a plain `gh pr view` existence check (bash, not an agent call) gates
  whether `pr-comments-reviewer.md` is dispatched at all — no PR, no agent call, not a
  dispatch-then-report-N/A.

All lanes active in a given tier run concurrently (single message, multiple Agent calls).
Findings merge; Step 2.5 adversarial refutation runs on the merged Critical/Important set
exactly as today.

**`gaspol-finish/SKILL.md`'s pre-finish chain** — currently `gaspol-verify` (4 layers) →
`plan-verifier` BLOCKING → `gaspol-sync-docs` → `gaspol-learn`, with `gaspol-review` and
`gaspol-security-review` only reachable via loose description/diagram language, not the
chain itself — becomes:

```
1. gaspol-verify (4 layers; UI/behavior-visible changes must include running the `run`
   skill to observe the feature live, not only npm test/tsc/lint — green tests alone are
   not a quality claim)
2. plan-verifier — BLOCKING
3. gaspol-review at Tier 1 — BLOCKING on any surviving (post-refutation) Critical
4. gaspol-security-review — always runs (not conditional-trigger-only), checklist result
   attached to the finish report
5. gaspol-sync-docs
6. gaspol-learn
```

---

### Item 8 — Ticket-numbered ledger + in-flight collision guard

**Problem:** ledger filenames are currently `.gaspol/progress/<slug>.md` (slug from plan
filename) — two differently-named plans never collide, but there's no cheap, memorable,
collision-proof identifier, and nothing stops two `gaspol-execute` runs from touching the
same working tree at once.

**Ticket format:** `<PREFIX>-<N>`, e.g. `IND-80`. Ledger file becomes
`.gaspol/progress/progress-<PREFIX>-<N>.md`.

**Counter storage — in the project's `CLAUDE.md`:** a new section,

```markdown
## gaspol Ticket Counter

Prefix: IND
Last ticket: IND-80
```

Read and incremented by whichever skill assigns the next ticket (see below), written back
using the same CLAUDE.md-touching mechanism `gaspol-sync-docs` already has. First time a
project needs a ticket and this section doesn't exist yet: `AskUserQuestion` for a prefix
(no default guess — the user picks), create the section starting at `<PREFIX>-1`.

**Assignment point (primary):** `gaspol-plan/SKILL.md` — when the plan file is finalized and
its header is written (existing v1.10 behavior already has the header name a ledger path;
this extends that same step to mint the ticket number first, then derive the ledger path
from it).

**Assignment point (fallback):** `gaspol-execute/SKILL.md` Step 0 — if the plan header has no
ticket (older plan, predates this feature) or execution is ad-hoc (`gaspol-parallel`
independent-domains mode with no formal plan file), mint one here before proceeding.

**In-flight collision guard (`gaspol-execute/SKILL.md` new Step 0, before ticket
resolution):** scan `.gaspol/progress/progress-*.md` in the current working tree. For each,
read the last line's handoff cursor (existing v1.9.1 convention: `— NEXT: <phase, or DONE>`
/ `— WIP — ... — BLOCKER: ... — NEXT: ...`). Any file whose last cursor is not `NEXT: DONE`,
and that does not belong to the plan about to execute, is an **active** ledger.
If one or more active ledgers are found: `AskUserQuestion` — **(a)** create a new worktree
for this task via `gaspol-worktree` (recommended, isolates file edits), **(b)** resume the
in-flight ticket instead, **(c)** proceed here anyway (accepts file-conflict risk),
**(d)** something else. No active ledgers found → proceed straight to ticket
resolution/assignment.

---

### Item 9 — Proactive context-budget checkpoint

**Problem:** the ledger (v1.9.1 handoff cursor, v1.10 per-plan path) already makes `/compact`
and session restart *safe* — it survives them and lets a resumed session pick up exactly
where it left off. But nothing on gaspol's side is *proactive*: there's no point where the
skill checks "has this session been running a while?" and offers a clean breakpoint before
things degrade. Claude Code's own auto-compaction is transparent and out of gaspol's control;
this item is about gaspol offering a deliberate stop, not about compaction itself.

**Observable proxy (no special tooling required):** count phases/tasks completed *in this
execute run* — this is a number gaspol-execute and gaspol-parallel already know, since each
completed phase writes a ledger line. No token-counting API is needed.

**Scope:** `gaspol-execute/SKILL.md` and `gaspol-parallel/SKILL.md` — after the checkpoint
report for the 3rd (and every 3rd subsequent) phase/wave completed in the current run,
`AskUserQuestion`: "N phases done this session. Continue here, or pick up fresh next
session? The ledger (`.gaspol/progress/progress-<TICKET>.md`) has the exact resume point
either way." Options: continue as normal / stop here and report the resume point clearly /
raise the threshold for this run (don't ask again for N more phases). Default threshold: 3,
not configurable via a flag in this batch — a fixed, simple default is enough to close the
gap; making it tunable is a YAGNI cut unless it proves too chatty in practice.

---

## Data Integration Map (files touched)

| Item | Files |
|---|---|
| 1 | All `skills/gaspol-*/SKILL.md` (audit pass), `CLAUDE.md` (version bump, routing-table text if quoted) |
| 2 | `skills/gaspol-brainstorm/SKILL.md` |
| 4, 5 | `skills/gaspol-write-skill/SKILL.md` |
| 6 | `skills/gaspol-plan/SKILL.md` |
| 6b | `skills/gaspol-review/SKILL.md`, `skills/gaspol-verify/SKILL.md` |
| 7 | `skills/gaspol-review/SKILL.md`, `agents/code-reviewer.md` (trim "Requirements" bullet), new Tier-1/Tier-2 lane prompt templates, `skills/gaspol-finish/SKILL.md`, `skills/gaspol-verify/SKILL.md` (Layer 1 run-the-app note) |
| 8 | `skills/gaspol-plan/SKILL.md`, `skills/gaspol-execute/SKILL.md`, `CLAUDE.md` (per-project, template section) |
| 9 | `skills/gaspol-execute/SKILL.md`, `skills/gaspol-parallel/SKILL.md` |

All edits are markdown/skill-file changes to the gaspol-dev plugin source itself (plus two
small, dependency-free shell scripts for item 8). No new runtime dependency, no placeholder
risk (nothing here displays data — it's process documentation), and per the token-efficiency
research above, no unbounded agent-fan-out cost — item 7's default (Tier 0) cost is unchanged
from today, Tier 1 adds exactly one agent, Tier 2 is opt-in.

## Sources / Precedent

- Obsidian vault: `30-Knowledge/coding-workflow-patterns.md`, `20-Projects/IRN-Logistik/README.md`, `40-Daily/2026-08-08.md`, `30-Knowledge/deck-b2b-standard.md` §0d
- Token-efficiency research (2026-08-16 web search, full citations in that section above): Claude Code context-window docs, Anthropic's agentic-coding scaling guide, and current multi-agent-orchestration cost analyses
- Memory: [[gaspol-dev-source-and-reinstall]]

## Spec Self-Review

- Placeholder scan: none — every item names concrete files and a concrete change.
- Internal consistency: item 6b and 7 both depend on item 6's artifact-path field existing
  in the plan header; item 8's ticket number and item 6's artifact path are two separate
  optional fields on the same plan header — no conflict, both additive. Item 7's tiering
  is consistent with item 2's path classification (both gate heavier machinery to
  architectural-path/finish-time only).
- Scope check: nine items, all confined to the gaspol-dev plugin source repo. Items 4/5
  and 1 are independent and can run in any order; 6→6b→7 are dependency-ordered; 8 and 9
  are independent of everything else; 2 is independent but item 6 depends on its
  classification existing.
- Ambiguity check: "trivial plan" (item 6's skip condition) is defined by reference to item
  2's bounded/architectural classification, not left to separate judgment. Item 7's tier
  boundaries are defined by concrete trigger conditions (finish-time, architectural-path,
  contested finding, explicit user request), not vague "when appropriate" language.
