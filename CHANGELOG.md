# Changelog

## [1.20.0] - 2026-08-22

Three complaints, one report, one ticket — which is itself the first thing this release fixes.

### Changed — the default coding stance is now COMPLETENESS, not laziness (IDS-10)

v1.9 absorbed the ponytail **Laziness Ladder** as gaspol's always-on stance. Its first rung asked
*"does this need to exist at all?"* and its rules were *"fewest files possible, shortest working
diff wins."* The fidelity boundary held — no placeholders, no skipped tests — so output stayed
REAL. Nothing kept it COMPLETE, and shallow work breaches no boundary. Every task began by looking
for a reason to do less. That is what "semakin bodoh" described.

`skills/_shared/completeness-ladder.md` replaces it, in all four live slots (the session hook,
`gaspol-plan`, `gaspol-execute`, `implementer-prompt.md`): walk DOWN and do every rung — happy path,
every error path that can actually happen, every edge case the input space allows (enumerate, don't
sample), the tests that prove them, observability, the comment explaining why. The only legitimate
stop is genuinely unrelated work, flagged as separate scope.

Kept from ponytail, demoted from a scope rule to an implementation rule: the **Reuse Rule** (stdlib
→ native feature → already-installed dependency) and the anti-abstraction rules. Deleted: rung 1's
YAGNI-skip, "shortest diff wins", and the `ponytail:` comment convention.

Grounded in `gstack/ETHOS.md` §1, which names the old ladder's own rules as anti-patterns on the
evidence that AI-assisted coding compresses test writing ~50x and feature implementation ~30x.

### Fixed — one report of N defects minted N tickets (IDS-10)

There was no batching rule anywhere (`grep "multiple bug|each bug" skills/` → 0 hits), and the only
rule on the topic pushed the other way: brainstorm's decompose gate says *"Each sub-project gets its
own spec → plan → implement cycle."* The missing question sat upstream of decompose — five bugs in
one subsystem are one piece of work.

New `skills/_shared/batch-gate.md`, read by `gaspol-brainstorm` (above the decompose gate) and
`gaspol-debug` (bug reports never reach brainstorm). Default one ticket; split only for disjoint
subsystems **and** an oversized plan, a blocking dependency, or an explicit request; **ceiling of
two**, a third needs `AskUserQuestion`. `next-ticket` runs once per batch. Each item still becomes
its own plan phase with its own regression test — batching changes the container, never the coverage.

### Fixed — logic-only work produced nothing reviewable (IDS-10)

Brainstorm Phase 2.5 offered `[No, pure backend/logic]` and that branch skipped design entirely,
while the post-plan artifact step was opt-in. For an enhancement that changes behaviour but not
pixels, the first reviewable thing was the diff.

`gaspol-plan` **Step 0** is now a BLOCKING **Design Artifact** gate — every plan produces exactly
one, approved before `gaspol-execute` starts. UI work renders a mockup; everything else produces the
**Logic Design Artifact** (`skills/gaspol-plan/logic-design-artifact.md`): before/after behaviour
with the current path quoted from real code, a mermaid flow, a data-flow table reusing the Data
Integration Map columns, an edge-case matrix (empty = failed gate), and the blast-radius statement.
Three states — approved / pending / not published. **"Not applicable" is deliberately not a state:
that state was the defect.**

### Fixed — a whole other project's identity was baked into the dispatch prompts (IDS-10)

`implementer-prompt.md` opened with *"You are an implementer subagent for the Sparkfluence
platform"* and constrained every subagent to *"emerald + charcoal, NOT purple"*; `code-reviewer.md`
said the same. Three skills carried it as their H1. Twelve files in all, roughly 25 sites, in a
plugin whose own CLAUDE.md forbids hardcoding project values. A subagent told to use another
product's design system follows the instruction — it does not notice the mismatch. All of it now
reads from the target project's CLAUDE.md and `DESIGN.md`.

### Fixed — the deterministic suite had been red since 50fbbb1 (IDS-10)

Dropping this repo's own `.claude-plugin/marketplace.json` (distribution moved to the gaspol-one
marketplace) left four tests asserting a deleted file, so the version-consistency gate reported
failure for a reason unrelated to versions and nobody could tell. `gaspol-finish` Step 0 requires
green before any agent is dispatched, so the whole chain was blocked. New
`tests/ticket-scripts/marketplace-manifest` resolves the manifest cross-repo with the house
three-state contract (0 available / 3 UNKNOWN / 4 none); **not checked is printed, never counted as
a pass.**

### Added

- `tests/ticket-scripts/test-completeness-ladder.sh`, `test-batch-gate.sh`,
  `test-logic-design-artifact.sh` — 33 deterministic tests, all green.
- The `test-execute-trim.sh` ceiling moved 25500 → 26200, and now says why: it tracks
  **obligations**, and IDS-10 added a gate. Raising it to fit wordy prose is the failure it guards.

## [1.19.0] - 2026-08-21

### Fixed — the finish chain had no bound (IDS-9)

IDS-8's `gaspol-finish` run took roughly eleven agent dispatches. The six steps were not the
problem: every one of them found a real defect, including a skill that had silently stopped
loading and a first capture that aborted on any fresh machine. The problem was that the chain
never bounded its own retries — "fix and re-run" appeared four times with no round cap, no
scoping, and no ordering rule, so five rounds went by on the **same class of finding** with
nothing saying *this is a pattern*.

Every fix already existed in the plugin. `gaspol-parallel` has a five-round loop with model
escalation, a scoped `FIX_BASE..HEAD` re-review, and a breaker that adjudicates instead of
escalating. `gaspol-finish` referenced it **zero times**.

- **`skills/_shared/fix-loop.md`** — the loop rule, stated once, read by `gaspol-parallel` (per
  task) and `gaspol-finish` (per BLOCKING gate). The cap's number is deliberately not repeated in
  either caller; a constant copied into two skills is a constant that will disagree with itself,
  which is the duplicated-pipeline defect IDS-8 removed one layer up.
- **`gaspol-finish` Step 0 — deterministic checks before any agent is dispatched.** The commands
  `detect-stack` prints, plus, where a repository keeps one, its gate-mutation harness. Three of
  IDS-8's five gate regressions would have been caught in seconds instead of by an eight-minute
  audit; an audit over a red tree costs the time and produces a verdict nobody can rely on.
- **Re-runs are scoped.** A BLOCKING gate records the SHA it audited, and the re-run reads
  `<SHA>..HEAD` — the fix diff, not the whole branch again.

**The chain was bounded, not shortened.** All six steps stay, and
`tests/ticket-scripts/test-finish-fix-loop.sh` fails if any is dropped, if the rule gets
duplicated back into a caller, if the re-run is unscoped, or if the cheap-before-expensive
ordering is removed. All six were sabotage-proved with MD5-verified mutations.

`test-fix-loop.sh` (IDS-6) now asserts the shared rule on the shared file and keeps only
parallel-specific claims on `gaspol-parallel/SKILL.md` — leaving them all in place would have
passed only while the rule was still duplicated. `test-ids8-docs.sh` stopped pinning the current
manifest version: a per-ticket test that asserts "the manifests read 1.18.0" goes red on every
later release, so it now asserts the historical fact instead — that the changelog carries a
1.18.0 section.

## [1.18.0] - 2026-08-21

### Fixed during the release's own review chain (IDS-8, rounds after the plan closed)

The finish chain found four defects the eight-phase implementation had not, and each one is a
different reason a green suite can still be wrong:

- **The first run on any fresh machine aborted.** All three KB skills merged `kb-root`'s exit 3
  (configured and unreadable, must stop) into exit 4 (nothing configured, must report and
  continue). Every test exercised the resolver *standalone*, so the resolver was right and its
  three callers were wrong, and nothing looked at the seam. `kb-root --init` now creates the
  default store for a write and returns 0; state 3 is untouched. A new test **executes** the bash
  extracted from each `SKILL.md` rather than reading it.
- **`gaspol-kb-audit` stopped being a valid skill.** The index caveat was inserted between the
  opening `---` and `name:` — inside the YAML frontmatter Claude Code routes on. The identical
  edit landed correctly in four other skills. `test-skill-frontmatter.sh` now checks all 20.
- **`git -C "$KB" add .` staged whole working trees.** The ownership guard asks *"is `$KB` the
  repository root?"*, which is true both for a dedicated KB repo and for a vault root a mis-set
  `kb_local` points at — structure cannot tell them apart, so the guard was never the last line of
  defence. Every write now stages one file by pathspec.
- **Resolver invocations were relative.** An agent runs a skill's bash with the *target project* as
  its working directory, so `$(skills/_shared/kb-root)` would run whatever a repo shipping that
  path happens to contain, and its stdout becomes the path gaspol commits. All ten invocations now
  go through `$CLAUDE_PLUGIN_ROOT`. Six older scripts still carry the old form and are named in
  `CLAUDE.md` as the next ticket's subject.

Five separate times on this branch, a gate's own fix tripped over prose that *described* the
hazard it polices. The answer each time was to anchor on shape — a line that runs starts the line;
prose wraps the same text in backticks mid-sentence — never to add a text exemption, because an
exemption added to keep a gate usable is how every earlier regression got in.

### Fixed — gaspol was running a second knowledge pipeline alongside one that already existed (IDS-8)

The owner keeps an Obsidian vault with a working capture pipeline: a SessionStart hook writes
session learnings to `90-Inbox/agent-learnings/`, and `superbrain-promote` is the single
human-gated promoter into the curated core. gaspol ran its own store in parallel. On 2026-08-21
**both harvested the same session**: one prior-art lesson became `search-the-market-before-building-a-capability`
in the gaspol KB and three separate notes in the vault inbox. Same day, same insight, two stores.

Four more defects, each verified by running a command:

| Defect | Evidence |
|---|---|
| `kb_local` documented as the way to relocate the KB, **read by nothing** | named in `README.md`, `CLAUDE.md`, `docs/kb-setup.md`; `grep kb_local skills/` → **0 hits**; `grep gaspol-config skills/` → **0 files** |
| Precedent lookup off for the work that repeats mistakes | `gaspol-brainstorm` Phase 0.5 was headed *"architectural path only"* — bounded fixes never queried |
| gaspol would commit a repository it does not own | synced mode runs `git commit`/`push` **inside** the KB dir; the vault is a git repo. Inert today, armed the day `kb_remote` is set |
| The code index went stale with nothing in the chain refreshing it | `grep graphify skills/gaspol-sync-docs/` → 0 hits |

The relocation defect is IDS-7's `--design-system` shape one layer up: a setting parsed into
documentation and consulted by nothing.

### Changed

- **One resolver.** `skills/_shared/kb-path.md` states the order (`$GASPOL_KB_LOCAL` → `kb_local`
  in `gaspol-config.json` → default) and the three states; `skills/_shared/kb-root` executes it,
  reporting `available` / `UNKNOWN` / `none` through exit codes 0/3/4. Sixteen prose sites across
  six skills stopped naming the default folder.
- **Capture feeds the quarantine, in the quarantine's own shape.** Flat notes with frontmatter +
  `# Title` + `tags:`, always `status: proposed`. gaspol no longer promotes its own writes;
  `superbrain-promote` stays the sole gate. The four category directories became tags.
- **Precedent query runs on bounded work too.** Spike keeps its exemption — a probe that keeps no
  code has no precedent to apply. `gaspol-brainstorm` Phase 0 reads the vault in the owner's own
  order and stops as soon as it has enough.
- **Ownership guard.** Before any write-side git operation, the KB root is compared against
  `git rev-parse --show-toplevel`; a mismatch records
  `kb-sync: skipped — KB lives inside a repo gaspol does not own` and continues. Reads stay allowed.
- **Code index lane** in `gaspol-sync-docs`: `graphify-out/` + CLI → `graphify update .`; marker
  without CLI → `graphify: UNKNOWN` and STOP; no marker → skipped, never recorded as passed. The
  federated `graphify global add` writes outside the repo, so it is offered, never taken.

### Deferred, named rather than forgotten

`gaspol-kb-audit` now overlaps `superbrain-promote` almost completely — both are
scan → cluster → per-finding human decision → apply → audit log. Not resolved here because the
two are **not like-for-like**: one is public and agnostic, the other private and hardcoded to one
vault.

### Note on the audit itself

This ticket's first duplication probe returned ten blank rows and would have "proved" zero
duplicates while being broken. Every probe afterwards carries a positive control. Four test
assertions in this release were caught passing over sabotaged code and rewritten — a guard that
can be satisfied by an unrelated line is not guarding anything.


## [1.17.0] - 2026-08-21

### Fixed — Layer 4's design gate was reporting a number, not enforcing a contract (IDS-7)

The standing complaint about this plugin was that a full app build ships colours and fonts
that drifted from the mockup. IDS-6 fixed the context half of the bug-density problem. This
release went looking for the fidelity half and found that the gate meant to catch it had
never actually been wired up. Four defects, each verified by reading the file rather than
inferred:

- **`--design-system` was parsed and never read.** Declared at `design_audit.py:170`; grep for
  `design_system` in the file returned **zero hits**. So the script could not compare a colour
  against a token list — it only ever reported "a hex literal appears here", which is a pattern
  count, not a compliance judgement.
- **WCAG AA contrast was claimed in two places and computed in zero.** The module docstring and
  `gaspol-verify/SKILL.md` both promised it; grep for `contrast` returned one hit, the docstring
  line itself. Same defect class as the `gaspol-finish` Step 5 checkbox IDS-6 fixed: a step
  recorded as passed that never ran.
- **It scanned the whole project, never the diff.** `scan_project(root)` walked the tree and
  there was no `git` anywhere in the file. On any repository with existing code the layer
  collected hundreds of pre-existing findings, and since it FAILS below score 60, **the gate
  failed permanently** — which is indistinguishable from having no gate.
- **CSS was never scanned at all.** `is_ui_file()` tested `UI_EXTENSIONS` only.
  `STYLE_EXTENSIONS` was defined and never consulted, so `.css`/`.scss` went unaudited while
  the docs said otherwise. Found while implementing the first phase, not during planning.

### Added — DESIGN.md as a machine-readable token contract (IDS-7)

- **`DESIGN.md` at the project root** — YAML frontmatter with a `colors:` map and optional
  `fonts:` map. Format from Google Stitch; 73 worked examples at
  [voltagent/awesome-design-md](https://github.com/voltagent/awesome-design-md), **referenced,
  never vendored**. Parsed with a stdlib reader (~54 lines) — no YAML dependency for a flat
  `key: value` shape.
- **Three states, kept strictly distinct** (KB precedent `marker-file-is-not-proof-tool-installed`):
  absent → `design-contract: none`, gate not run, **not a failure**; parses → gate active;
  present but unparseable → `design-contract: UNKNOWN` and **STOP**. A broken contract must
  never degrade to an empty one, because an empty contract reads as "nothing violated".
- **Severity by CSS role, not judgement.** Structural colours (`color`, `background`,
  `border-color`, `fill`, `stroke`, Tailwind `bg-[…]`/`text-[…]`/`border-[…]`) BLOCK;
  decorative ones (`box-shadow`, `outline-color`, anything with alpha) WARN. A one-off
  `rgba(0,0,0,0.05)` shadow is craft, not drift — blocking on it produces false alarms, false
  alarms get the gate switched off, and a disabled gate is worth less than a noisy one.
  A colour that IS in the contract produces no finding: compliant means silent. Matching covers
  hex, Tailwind `…-[#hex]`, and numeric `rgb()`/`rgba()`. A named colour or `hsl()` is **not
  detected at all** — a coverage gap, not a lenient verdict.
- **Fonts have three states, and the third one is the point.** Declared and used → silent;
  declared and violated → BLOCKS; **no `fonts:` map** → reported but *unjudged*, with
  `font_gate: not run` recorded. `extract-design-tokens` emits colours only, so the documented
  onboarding path produces exactly that contract — and collapsing the third state into
  "compliant" turned `Hardcoded fonts: 2` into `Hardcoded fonts: 0`. Contrast carries the same
  `contrast_gate` key for the same reason. Both are emitted in JSON and text from one value, so
  the two output modes cannot drift apart.
- **`skills/gaspol-verify/scripts/extract-design-tokens`** — reads tailwind theme colours,
  `--color-*`/`--brand-*` custom properties, or a `theme.json` colours map, so existing
  repositories get the gate without hand-writing anything. Extraction is **literal**: an
  unrecognised config emits nothing and exits 1 saying why, never a plausible invented token.
  **stdout only** — the write is offered by `gaspol-verify` via `AskUserQuestion`, because
  writing a contract into someone's repo unasked is the same overreach as installing a
  marketplace skill without asking.
- **`gaspol-brainstorm` Phase 3** offers to freeze an approved palette into `DESIGN.md` — the
  moment the design is agreed and no code exists yet is the cheapest possible time to fix it.

### Added — Web Interface Guidelines lane, fetched not forked (IDS-7)

`design_audit.py` knows about a dozen patterns; Vercel maintains about 100 across 17 sections covering accessibility,
focus states, forms, animation, performance and mobile. Layer 4 now fetches
`vercel-labs/web-interface-guidelines/main/command.md` at review time and applies it to the same
changed-file list — its `file:line` output needs no adaptor. **Fetch, do not fork**: the 1.4MB
`gaspol-design` fork drifted and was deleted in v1.14, and a static copy of these rules would go
the same way.

Three security rails, because this pulls markdown off the public internet and feeds it to a
review model — the fetched text is untrusted input:

1. The URL is **pinned literally**, never taken from a file, argument, or another document.
2. The fetched text is **data, not instructions**. Any directive inside it — run a command, read
   a secret, write a file, fetch another URL, change the verdict — is ignored and reported,
   never followed.
3. A failed or unrecognised fetch records `wig-lane: not run (fetch failed or unrecognised
   content)` and falls back to the local script. **Never recorded as passed when it did not
   run**, the same rule `gaspol-finish` applies to an unavailable `/security-review`.

### Rejected during prior-art search (IDS-7)

`Abhinav1004/Image2Code` was evaluated and turned down: academic pix2code (TensorFlow/Keras +
Streamlit), 77% accuracy on a synthetic DSL over toy datasets. Not tooling, and outperformed by
any current VLM reading a screenshot. `leonxlnx/taste-skill` was already installed in full and
overlaps `ui-ux-pro-max`; absorbing it would repeat the v1.14 fork mistake, so nothing was taken.

### Scope boundary — deliberately not overclaimed

`DESIGN.md` pins **tokens**, not **layout geometry**. This release closes the wrong-colours and
wrong-fonts half of the mockup-mismatch complaint. The wrong-layout half remains open and is
still the subject of IDS-6's deferred Part B (canvas.html as a single visual source, `data-vv`
DOM markers, geometry diffing).

## [1.16.0] - 2026-08-21

### Changed — the dispatch is a path, not a paste (IDS-6 Part A)

Bug density used to rise with task index: tasks 1-3 landed clean, tasks 8-15 leaked defects.
The cause was never task difficulty — it was controller context. Every dispatch pasted the
full task text and every subagent printed its full report back, and both stayed resident,
re-read on every later turn.

- **`skills/gaspol-parallel/scripts/task-brief <PLAN_FILE> <N>`** extracts one phase to
  `.gaspol/tasks/<TICKET>/task-<N>-brief.md` and prints the path. On this repo's own IDS-6
  plan, a phase brief is 33 lines against a ~340-line plan.
- A dispatch now carries five things: one line of project context, the brief path, interfaces
  from earlier tasks, the controller's resolution of any ambiguity, and the report-file path.
  Exact values live only in the brief.
- The blanket rule `NEVER reference a file` is **narrowed, not reversed** — never reference the
  *plan* (a subagent handed 2000 lines reads the wrong task); always reference the task-scoped
  *brief*. The failure the old rule prevented is still prevented.
- The implementer writes its full report to `task-<N>-report.md` and returns four fields:
  status, commits, a one-line test summary, concerns. It also carries a no-subagents contract —
  every reviewer a worker spawned in a real session duplicated the review the orchestrator
  dispatched anyway.

### Changed — five-round fix loop with model escalation (IDS-6)

Replaces "3 attempts, then escalate to the user", in all three places it appeared.

- Rounds 1-3 resume the same implementer with the findings verbatim; its context is intact.
- Rounds 4-5 dispatch a **fresh** implementer **one model tier above** the stuck one. A loop
  that survives three resumes usually means the implementer cannot see its own problem.
- Every round the fix report must carry the covering tests, the command run, and its output
  before the re-review is dispatched.
- Round 5 is a breaker, not a wall: adjudicate each open finding with the spec as binding
  authority, record the ruling, continue. Ask the user only when every path forward is a guess.
- New `skills/gaspol-parallel/re-review-prompt.md` — scoped re-review against
  `review-package <FIX_BASE> HEAD`, where `FIX_BASE` is the head the previous review saw. The
  `review-package` script itself is unchanged; `FIX_BASE` is just a different `BASE`.

### Added — pre-flight conflict matrix, BLOCKING (IDS-6)

Before the first dispatch, in both `gaspol-parallel` and `gaspol-execute`: one table row per
pair of tasks sharing a file or interface, one row per task for self-consistency. "The scan is
clean" without those rows is not a scan that ran. Written to the ledger **above `## Log`**, so
`scan-active-ledgers` still reads the last non-empty line. Every finding is ruled on before
execution begins.

### Changed — measured trims (IDS-6 Part C)

A token audit was run because the plugin *felt* heavy. It measured otherwise: the fixed
per-session tax is **~1.9k tokens**, one full skill cycle is ~26k, and there are **zero**
duplicated prose blocks across all twenty skills. The plugin's own text was never the bloat.
Three findings still changed code:

- `gaspol-execute/SKILL.md` 32.7KB → 25.1KB (**-23%**), words cut and obligations kept —
  `tests/ticket-scripts/test-execute-trim.sh` asserts every gate name, all three Iron Laws, and
  the exact TDD step-1 phrasing survive. The consulted Red Flags / Rationalizations table moved
  into `anti-placeholder-rules.md` rather than being deleted, and a project-specific leak
  ("Sparkfluence", named hooks) left an agnostic plugin.
- `gaspol-write-skill`'s three heavy references (~11.9k tokens) were **orphans** — SKILL.md
  never referenced them, they only referenced each other. The audit's premise was wrong; they
  now have a pointer table naming the question each answers, read only when it is live.
- `gaspol-finish` gained exactly **one** conditional gate: `plan-verifier` is skipped when the
  branch provably references no plan, and the skip is recorded in the ledger with its reason.
  `/security-review` stays unconditional on every branch, guarded by a new assertion — security
  defects hide in boring diffs, and in a skills repository markdown *is* the executed surface.

### Deferred

The visual contract (`canvas.html`, the visual lock, `gaspol-visual-verify`) is designed in
`docs/plans/2026-08-21-IDS-6-execution-hygiene-and-visual-contract-spec.md` and carried to a
later ticket. Part A lowers the cost of building it.

## [1.15.0] - 2026-08-21

### Added — a prior-art gate, so nothing gets rebuilt that already exists (IDS-4)

v1.14 deleted two skills that should never have been written: `gaspol-design` (a 1.4MB fork
of data `ui-ux-pro-max` already publishes) and `gaspol-security-review` (a checklist for a
`/security-review` command compiled into the CLI binary). Two builds, two deletions, zero
prior-art searches. This release adds the search.

- **`gaspol-write-skill` Step 0: Prior-Art Search — BLOCKING.** Three lookups before any
  SKILL.md is written, because each is blind where the others see: (1) already installed,
  (2) a built-in harness `/command` — these appear in no skill listing, (3) the marketplace
  via `npx skills find` (vercel-labs `skills` CLI, https://skills.sh). Verdict recorded in
  the RED notes as `NONE` / `EXISTS` / `DELTA`; `DELTA` requires naming the delta, which is
  what `anti-ai-slop.md` did to survive the IDS-2 deletion.
- **Install is never automatic.** A skill is a prompt that runs inside the agent. No
  `npx skills add ... -y` (upstream `find-skills` documents that exact flag pair — it is not
  followed), candidate presented via `AskUserQuestion`, candidate's SKILL.md read before it is
  recommended, and the standing context cost of every installed skill weighed against use.
- **`gaspol-brainstorm` Phase 1.5, `NEW` branch only.** No KB hit and no project pattern is
  precisely when someone else's packaged skill beats an invented design — a ~30s probe runs
  before the ~20min deep research. Deliberately NOT Phase 0.5, which is product precedent.
- **`gaspol-research` gather lane 6.** "Already packaged as an agent skill" is a research
  finding like any other, and the cheapest recommendation available. Reported, never installed.
- **Soft reference throughout**, on the same reasoning that kept `ui-ux-pro-max` out of
  `plugin.json`'s `dependencies`: a missing CLI degrades the search and blocks nothing, and an
  unrun lookup is reported as unrun rather than recorded as empty.
- **`tests/ticket-scripts/test-prior-art-gate.sh`** — deterministic, no API calls, with a
  self-check that fails loudly rather than passing vacuously if the grep helper stops matching.

## [1.14.0] - 2026-08-21

### Changed — two skills deleted in favour of tooling every user already has (IDS-2)

gaspol carried a 1.7MB fork of the ui-ux-pro-max design database and a 12KB security checklist.
Both duplicated something already installed: the ui-ux-pro-max plugin itself, and
`/security-review`, which is compiled into the Claude Code CLI binary. Forks drift; the
originals do not. Both were deleted, and the parts with no equivalent upstream were kept.

- **`gaspol-design` deleted.** Design intelligence now comes from the `ui-ux-pro-max` plugin,
  referenced **softly** — there is deliberately no `dependencies` key in `plugin.json`, because
  that field is all-or-nothing and a yanked third-party marketplace entry would disable every
  remaining gaspol skill. If the plugin is missing, say so, point at
  `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`, and carry on.
- **Three parts survived the deletion**, each because ui-ux-pro-max has no equivalent:
  `design_audit.py` (a stdlib-only STATIC source lint; the upstream audit needs Playwright and a
  running URL, so it cannot serve `gaspol-verify` Layer 4, which runs offline and pre-merge),
  `anti-ai-slop.md`, and `reasoning-gaspol.md`. All three now live under `skills/gaspol-verify/`.
  The plan had claimed CLAUDE.md already duplicated the anti-slop rules; it holds a two-line
  summary against 119 lines of source, so execution paused and the premise was corrected rather
  than followed.
- **`gaspol-security-review` deleted.** `gaspol-finish` Step 4 and `gaspol-execute` Step 3.6 now
  run the built-in `/security-review`. The gate is unchanged: Step 4 still ALWAYS runs on every
  branch and still blocks merge options on any finding, and Step 3.6 keeps its full trigger list.
  New clause: if `/security-review` is unavailable, walk the same ground by hand and never record
  the step as passed when it did not run.
- **The security pressure test was kept, not deleted.** It tests whether the agent refuses to
  bless string-concatenated SQL and a JWT in `localStorage` under time pressure — discipline that
  did not move to the built-in, which only fires when explicitly invoked. Retargeted at
  `gaspol-execute`; fixture renamed `security-ship-pressure.txt`.

### Added — gaspol-review absorbs the two mechanics it was missing

`gaspol-review` was measured against Anthropic's official `code-review` plugin and **kept**. That
plugin is PR-only (all its tools are `gh pr ...`, it posts to a GitHub comment) so it cannot gate
a local branch before merge, and gaspol-review already runs all five of its review lanes plus
tiering and an adversarial refutation pass it lacks. Two things it did better are now absorbed:

- **Confidence rubric.** Each refuter returns `CONFIDENCE: 0-100` against a written five-point
  scale; below 80 a finding is recorded as noise rather than fixed.
- **False-positive catalogue.** Seven score-0 categories, including anything a linter or
  typechecker catches — with an explicit instruction not to run builds during review.
- **The verdict outranks the score.** REFUTED drops a finding at any score; an UNVERIFIABLE
  Critical still blocks regardless of score. The threshold can only demote a CONFIRMED finding to
  noise, never promote a REFUTED one or rescue a blocked one. Two Red Flags rows guard each
  direction.
- `/code-review ultra` documented as the deeper pass — user-triggered and billed, with an
  explicit "Claude cannot launch it".

### Changed — gaspol-finish gains three gates, gaspol-eval renamed (IDS-3)

Shipped in the same unreleased version as IDS-2.

- **`gaspol-eval` renamed to `gaspol-llm-test`.** "eval" reads as a shell builtin or a generic
  word outside ML; the skill tests LLM, prompt, and agent features whose output varies run to
  run. Ten files updated. Nothing downstream breaks — the old name survives only in historical
  plan documents. Deletion was proposed and withdrawn on evidence: it looked unused because
  usage was measured in THIS repo, which has no LLM feature; three other projects carry 1,080
  lines of real eval specs under `docs/evals/`.
- **The ledger lifecycle now ends.** `gaspol-plan` created `PROGRESS-<TICKET>.md` and
  `gaspol-execute` ticked it, but `gaspol-finish` mentioned it zero times against 23 mentions in
  execute. Being gitignored, a finished ticket's ledger never showed up in `git status` and just
  accumulated with a cursor still claiming work in flight. Finish now writes the closing
  `— NEXT: DONE` line, refuses to silently tick a `[ ]`/`[>]` entry, and runs
  `scan-active-ledgers` to surface any other open ledger.
- **`npm test` no longer hardcoded in finish.** IDS-1 added `detect-stack` to stop assuming npm;
  verify, parallel, plan, and execute all used it and finish was the last holdout, printing a
  command a Laravel or Go project cannot run.
- **Merging is not publishing.** "Merge locally" ended at `git branch -d`. Finish now requires
  `git push`, and for a plugin repo `claude plugin marketplace update` +
  `claude plugin update <plugin>@<marketplace>` (the full id — the bare name fails with
  `Plugin "<name>" not found`) plus a restart. This is how v1.13.0 sat inert on one machine
  while the repo claimed it had shipped.
- **Step 5 is evidence-gated.** `[x] Step 5 gaspol-sync-docs: COMPLETED` was self-reported and
  unverified. CLAUDE.md must now appear in the branch diff whenever the branch changed anything
  structural; a branch with no structural change must say so rather than record a bare COMPLETED.
- **`gaspol-receive-review` compliance is now observable.** It produces no artifact, so commits
  touching it proved maintenance, not obedience — the only skill whose compliance could not be
  measured. A pressure case feeds it review feedback that is wrong in three ways, wrapped in
  seniority and deadline pressure; it passes only if the agent refutes rather than complies.

### Fixed

- CLAUDE.md documented the finish chain as five steps; it has been six since v1.8. `gaspol-review`
  (Step 3) and the security review (Step 4) were missing from the documented chain entirely.
- Skill count corrected to 20 across CLAUDE.md, README.md, and marketplace.json, and the new
  `test-skill-delegation.sh` derives it from `ls` so it cannot silently drift again.

## [1.13.0] - 2026-08-20

### Added — output naming standard: dated spec/plan files, PROGRESS-<TICKET>.md ledger, detect-stack (IDS-1)

Field report: plan/spec filenames collided across tickets sharing a topic slug, the ledger's
`.gaspol/progress/<slug>.md` path gave no per-phase checklist a human could scan at a glance, and
Layer 1 / Validation Ladder verification hardcoded `npm run build` / `npx tsc --noEmit` even on
non-Node projects. Seven phases close all three gaps (A-F as planned, plus G adding the same conventions to
`gaspol-worktree`).

**Suite status, measured not assumed:** ticket-scripts 4/4, skill-triggering 6/6,
pressure 3/9 (exit 1). The pressure suite spawns real `claude` CLI runs and is stochastic —
two measurements on this branch both scored 3/9 but with different failure composition, one
with zero capitulations and one with two. Its redness predates this release: `tests/pressure/`
is untouched here, no skill `description:` frontmatter changed (frontmatter drives triggering),
and a baseline measurement at cd8bd1a scored 1/9. Repairing that suite is its own ticket.

- **Dated spec/plan filenames.** `gaspol-brainstorm` and `gaspol-plan` now write
  `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-{spec,plan}.md`. `gaspol-plan` locates its spec by
  glob (`docs/plans/*-<TICKET>-*-spec.md`) instead of reconstructing the filename, and STOPs to
  ask the user if more than one file matches. Seven pre-ticket files in `docs/plans/` predate the
  convention and are deliberately not renamed.
- **Case-insensitive ledger scan.** `scan-active-ledgers` now globs `PROGRESS-*.md` as well as
  lowercase `progress-*.md`.
- **`PROGRESS-<TICKET>.md` ledger with a per-phase checklist.** `gaspol-plan` creates
  `.gaspol/progress/PROGRESS-<TICKET>.md` at plan-write time: a `## Checklist` block (`[ ]` todo /
  `[>]` doing / `[x]` done / `[~]` cancelled-with-mandatory-reason) above a `## Log` block that is
  ALWAYS last. `gaspol-execute` and `gaspol-parallel` gain a BLOCKING per-phase gate — tick the
  checklist AND append the Log line with its `— NEXT:` cursor before the next phase starts. Older
  ledger paths are still read for backward compatibility.
- **`detect-stack`** (`skills/gaspol-execute/scripts/detect-stack`) — reads stack marker files at
  a project root and prints `<level>: <command>` lines (static/lint/unit/build); prints `UNKNOWN`
  when a marker exists but its backing command doesn't (`command -v` checks for
  python/go/rust/flutter too); prints nothing when there are no markers.
- **Verification commands are derived, not hardcoded.** `gaspol-verify` Layer 1 and
  `gaspol-parallel`'s Validation Ladder L1–L3 now run `detect-stack` instead of assuming npm;
  `gaspol-plan` copies its output verbatim into each phase's Verification block, and
  `implementer-prompt.md` carries it verbatim to dispatched subagents. Three documented result
  cases: a command line → run it; `UNKNOWN` → STOP and ask the user; zero lines → fall back to the
  plan-declared commands, recorded explicitly rather than silently skipped.

## [1.10.1] - 2026-07-11

### Changed — ledger update is now a hard per-phase gate

Field report: an external executor filled the per-plan ledger only once at the end of the run
(or not visibly during it), so mid-run it still read all-`todo` and a crash would have recorded
zero progress. The contract wording was too soft ("update after each phase"). Strengthened the
plan header (`gaspol-plan`) to state the ledger write is **blocking, like a test gate**: after
each phase and BEFORE the next, append the line (`doing` on start → `done` + command/result on
green); never batch at the end. No API change — wording/enforcement only.

## [1.10.0] - 2026-07-11

### Added — two-lane execution (plan-once, run-anywhere)

The plan artifact is now identical whether executed **in-session** or handed to a **separate
executor process** — the lane is chosen by one optional config, not by two plan formats. Planning
and review stay in the (expensive) main session; heavy codegen can run in a cheaper executor,
saving tokens. Works fully with zero config (pure in-session).

- **`gaspol-plan` — self-contained plan header.** Every plan now declares a `Progress ledger:`
  path and a `Self-contained:` contract: the plan must be executable by an agent with no other
  context (a fresh post-`/compact` session, or an external executor that can't see the chat or a
  linked PDF) — every path, contract, config key, and convention written verbatim, not linked.
- **`gaspol-plan` — Execution Handoff Option 4: External executor.** Surfaces **only if**
  `$GASPOL_EXECUTOR` or a `.gaspol/executor` file is set (a command template with `{plan}`/`{ledger}`
  placeholders, e.g. `aider --file {plan}`). Unset → hidden → Options 1–3 work exactly as before.
  gaspol-dev ships **no executor of its own** and never invents one; the external tool implements +
  tests to green but **never commits** — the diff returns for review + commit.
- **Per-plan progress ledger.** `gaspol-execute`/`gaspol-parallel` now read/write the plan's declared
  `.gaspol/progress/<slug>.md`, so concurrent plans no longer overwrite each other's ledger. Falls
  back to the shared `.gaspol/progress.md` when a plan names none (backward-compatible).
- **New Red Flags:** plan that only makes sense with chat context; missing `Progress ledger:` header.

## [1.8.0] - 2026-06-30

### Added — ECC-adoption (3 selective ports from a local kitchen-sink toolkit; rest rejected as bloat)

- **DAG lane scheduling** (`skills/gaspol-parallel/scripts/dag-lanes`) — a deterministic Python3
  stdlib-only (`graphlib`) scheduler that turns `gaspol-parallel` mode `independent-domains`'
  binary conflict-check ("can all run parallel? y/n") into dependency **waves** (topological
  layers) + file-isolated **lanes** (within a wave, tasks sharing any file → one sequential lane
  via union-find; no overlap → concurrent). A single dependency no longer forces the whole batch
  sequential. Prints a LANE VERIFICATION MATRIX proving no two concurrently-dispatched tasks
  touch the same file. Rejects cycles / unknown deps / duplicate + missing ids with clean errors
  (no traceback); has `--self-test` (7 cases). Zero new dependencies.
- **Adversarial refutation** (`gaspol-review` Step 2.5) — before any Critical/Important finding
  is acted on, one refuter subagent per finding (default REFUTED, verdict
  `CONFIRMED | REFUTED | UNVERIFIABLE`) tries to disprove it. Kills hallucinated findings before
  a wrong "fix" breaks working code; `UNVERIFIABLE` (runtime-only) fails safe → CONFIRMED. Only
  confirmed/unverifiable Critical findings block. Wired into `gaspol-parallel` Step 6.
- **Per-task Validation Ladder** (`gaspol-parallel` Step 4 + `implementer-prompt.md`) — an
  implementer may not report `DONE` until an ordered fail-fast ladder passes: L1 Static (tsc +
  lint) → L2 Unit → L3 Build → L4 Integration → L5 Edge (non-happy paths actually run). Cheap
  levels gate expensive ones; fail → fix → restart from L1; an N/A level is skipped *explicitly*
  (silent skip = placeholder-grade lie). Does NOT replace the independent spec + quality reviews
  (Steps 5–6) — self-validation and independent review are different guarantees.
- **Pressure test** (`tests/pressure/prompts/gaspol-parallel-skipladder.txt`) — verifies an
  implementer resists "skip the build/integration/edge levels, mark it DONE."

### Why

- Compared `gaspol-parallel`/`gaspol-execute` against a local 200-skill / 70-agent toolkit
  ("ECC"). Verdict: not strictly better, different axes — ECC had 3 real ideas worth porting
  (parallel throughput, review trust, verification depth); the rest (200+ skills, multi-IDE,
  external-model subagent zoo, per-language reviewers) is surface area, not value, and was
  deliberately NOT adopted (ponytail: focus + Iron Laws beat breadth). Self-reviewed via
  `gaspol-review`; the review's own Critical was refuted (Step 2.5 dogfood), 2 Important +
  minors fixed.

## [1.7.0] - 2026-06-30

### Added — superpowers-adoption Phase 3 (#1 visual brainstorm companion, flagship; from superpowers MIT)

- **Visual companion** (`skills/gaspol-brainstorm/visual-companion/`) — a browser-based loop
  for showing mockups, diagrams, and side-by-side options during brainstorming/design. A local
  Node server (zero npm deps) watches a screen dir, serves the newest HTML to the user's
  browser (auto-wrapping content fragments in a frame), and records click/selection events to a
  state dir the orchestrator reads next turn. Offered **just-in-time** (never upfront) and wired
  into `gaspol-brainstorm` Phase 3; `visual-companion.md` is the operator guide.
- **gaspol-design fusion** — the companion renders `gaspol-design` output (palette, layout
  blueprint, 162+ rules) into the mockups: gaspol now has both the design *knowledge* and the
  interactive *loop* (superpowers had the loop, gaspol adds the knowledge).
- **Vendored + rebranded from obra/superpowers (MIT)** — see `NOTICE.md`. Privacy/brand strip:
  removed the remote brand-image fetch to primeradiant.com and the telemetry plumbing (**the
  server now makes zero outbound requests**); session files moved to `.gaspol/brainstorm/`;
  brand is local text-only; version reads the gaspol manifest.
- **Security-reviewed (🟢 PASS)** — session-key auth is constant-time on HTTP (403 unkeyed) and
  on the WebSocket upgrade (key + origin allow-list); `/files/` serving has a `realpath`
  containment guard against path traversal; binds loopback by default; `X-Frame-Options: DENY`
  + `CSP frame-ancestors 'none'`; session key + server-info are owner-only (umask 077 / 0o600).
- **`smoke-test.sh`** — proves the server boots, serves the keyed bootstrap (200), rejects
  unkeyed requests (403), and stops clean (screen render itself is WebSocket+browser, validated
  live).

### Why

- Phase 3 (flagship) of `docs/plans/2026-06-30-superpowers-adoption.md` — the last and heaviest
  of the four adopted mechanisms. Completes the roadmap (v1.5 #3+#4, v1.6 #2, v1.7 #1). The
  `indusia-image-gen` fusion (real preview images vs HTML wireframes) is noted as a future v1.8
  stretch, not built here.

## [1.6.0] - 2026-06-30

### Added — superpowers-adoption Phase 2 (#2 SDD per-task review harness, from superpowers v6 MIT)

- **Status protocol** (`gaspol-parallel`) — the implementer subagent now reports one explicit
  terminal status: `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
  (`implementer-prompt.md` §0). The orchestrator routes on it — `NEEDS_CONTEXT` → provide
  context + re-dispatch; `BLOCKED` → assess, **never** blind-retry the same model — instead of
  treating every return as "done".
- **`review-package` script** (`skills/gaspol-parallel/scripts/review-package`) — deterministic
  task-diff artifact: `review-package <BASE> HEAD` writes commits + stat + patch to
  `.gaspol/review/<base>-<head>.diff` and prints the path, so the spec/quality reviewers audit
  one stable artifact. Records the superpowers gotcha as a hard guard: **rejects `HEAD~1` as
  BASE** (it silently drops all but the last commit of a multi-commit task). Ships a
  `--self-test`.
- **Per-task model dispatch** (`gaspol-parallel`) — "always specify the model explicitly,"
  scaled by task class (mechanical→cheap, integration→standard, architecture/review→capable,
  per `docs/rubric-model-switching.md`). Principle: **turn count beats token price**.
- **Fix → re-review loop** — Critical/Important review findings now dispatch a fix then
  **re-run the review** until clean, rather than "fix and move on."
- Pressure test `tests/pressure/prompts/gaspol-parallel-skipreview.txt` (resists "skip the
  review, just mark all tasks done"), registered in the pressure aggregator.

### Why

- Phase 2 of `docs/plans/2026-06-30-superpowers-adoption.md`. gaspol-parallel already had
  fresh-subagent-per-task + two-stage review; this closes the gaps vs superpowers v6's
  `subagent-driven-development` rewrite (explicit status, deterministic review package,
  per-task model choice, enforced re-review). #1 (visual brainstorm companion) remains for v1.7.

## [1.5.0] - 2026-06-30

### Added — selective adoption from superpowers v6 (MIT)

- **Brainstorm hardening** (`gaspol-brainstorm`) — three gates ported from superpowers'
  `brainstorming` skill: a **HARD-GATE** (no implementation skill / code / scaffold until a
  design is presented AND user-approved, every project regardless of perceived simplicity);
  a **decompose gate** in Phase 1 (flag multi-subsystem requests, split into sub-projects,
  each with its own spec→plan→implement cycle); and **spec self-review + user-reviews-spec**
  in Phase 6 (scan the written design for placeholder/contradiction/ambiguity/scope, then
  the user approves the written spec before planning). Also fixed a pre-existing duplicate
  `## Phase 1` header. Pressure test added (`tests/pressure/prompts/gaspol-brainstorm-hardgate.txt`).
- **Durable progress ledger** (`gaspol-execute`, `gaspol-parallel`) — phase/task state is now
  appended to a `.gaspol/progress.md` working-tree file that **survives `/compact` and session
  restart** (TodoWrite is in-memory and lost on compaction). `gaspol-execute` Step 3 reads the
  ledger on start to resume from the first unfinished phase. Written under `.gaspol/` (gitignored
  scratch), **never** under `.git/` — Claude Code treats `.git/` as a protected path and blocks
  agent writes there (lesson from superpowers v6.0.3). Caveat documented: `git clean -fdx`
  deletes it, recover from `git log`.
- **`tests/pressure/run-all.sh`** — new aggregator that runs every pressure case
  (tdd-skip, placeholder, security-review, brainstorm-hardgate) with its forbidden-capitulation
  regex; previously pressure cases could only be run one at a time.

### Why

- This is **Phase 1 of the superpowers-adoption roadmap** (see
  `docs/plans/2026-06-30-superpowers-adoption.md`): the two cheapest-highest-leverage gaps —
  pure-additive, no new skill, no dependency. #2 (SDD per-task review harness) is queued for
  v1.6; #1 (visual brainstorm companion) for v1.7.

## [1.4.0] - 2026-06-09

### Added — selective adoption from ECC (Everything Claude Code)
- **`gaspol-security-review`** — new rigid skill. Security checklist across 9 categories
  (secrets, input validation, SQL injection, auth/authz, XSS, CSRF, rate limiting,
  sensitive-data exposure, dependency security) plus a Supabase Row-Level-Security
  section and a 16-item Pre-Deployment Security Checklist. Ported and adapted from the
  ECC `security-review` skill (MIT); the blockchain/Solana section was dropped as
  out-of-stack. Auto-triggered by `gaspol-execute` (Step 3.6) on security-sensitive
  phases and gated by `gaspol-finish` before merge/PR. Pressure test added (it is a
  second-order skill — auto-triggered downstream, so it is not cold-prompt
  triggering-tested, like `gaspol-design`/`adr`/`learn`).
- **`gaspol-eval`** — new flexible skill. Eval-driven development for non-deterministic /
  LLM features (classification, extraction, generation, RAG, agents): capability +
  regression evals, three grader types (code / model-as-judge / human), and pass@k /
  pass^k metrics. Ported from the ECC `eval-harness` skill (MIT); eval definitions live
  in `docs/evals/` (project-local — regression baselines are codebase-specific) rather
  than the cross-project KB. Defined at plan time, run by `gaspol-verify`. Complements
  `gaspol-tdd` (TDD for deterministic code, eval for non-deterministic behavior); does
  not replace it. Second-order skill (auto-triggered via plan/verify wiring), so not
  cold-prompt triggering-tested.

### Why

- **security-review:** gaspol-review covers general quality but had no security-specific
  lens (secrets, SQLi, authz, RLS). Closes a real gap with a stack-fit checklist rather
  than adopting ECC's broad library wholesale.
- **eval:** gaspol-tdd asserts deterministic code, but a prompt edit is a behavior change
  with no compiler and no single `expect()` to catch regressions. Most of gaspol's own
  surface and Ali's content suite are LLM/prompt systems — this closes the
  non-deterministic verification gap.

## [1.3.1] - 2026-06-03

### Changed — KB works out of the box (local-only default)
- The cross-project Knowledge Base no longer requires a GitHub repo or `gaspol-config.json`. On first use the local KB auto-inits at `~/.claude/gaspol-knowledge/` and `gaspol-adr` / `gaspol-learn` start capturing immediately. GitHub sync is now an **optional upgrade**.
- New canonical doc **[docs/kb-setup.md](docs/kb-setup.md)** — 3-mode resolution: `local-only` (default), `synced` (remote configured), `off` (explicit `"kb_mode":"off"`).
- Reworked KB mechanics in `gaspol-brainstorm` (Phase 0.5), `gaspol-adr`, `gaspol-learn`, `gaspol-research`, `gaspol-kb-audit`: pull/push are now **conditional on synced mode**; commits always happen locally; missing remote is no longer a fail-loud condition. The old "no config → skip" behavior is replaced by "no config → local-only".
- `session-start.sh` now prints the active KB mode (local-only / synced / off) so the user can see the flywheel is live.

### Why
adr & learn were effectively dormant for any user who never did the manual GitHub setup (silent-skip). This makes the KB flywheel — the headline "compounding knowledge" differentiator vs superpowers — active by default, with zero onboarding friction.

## [1.3.0] - 2026-06-03

### Added (superpowers-parity hardening)
- **`gaspol-worktree`** — isolated git worktree skill: Step 0 existing-isolation detection (with submodule guard), native-tool-first (`EnterWorktree`) then safe `git worktree` fallback, mandatory gitignore safety verification, clean-baseline gate. Adapted from superpowers `using-git-worktrees` (MIT).
- **`using-gaspol`** — bootstrap meta-skill: the 1% rule, full routing table, instruction-priority hierarchy, and rationalization Red Flags. The auto-trigger backbone. Adapted from superpowers `using-superpowers` (MIT).
- **`tests/skill-triggering/`** — auto-trigger test harness (`run-test.sh`, `run-all.sh`, naive intent prompts): skills must fire from intent alone, not from a slash command.
- **`tests/pressure/`** — pressure tests: rigid skills (`gaspol-tdd`, anti-placeholder) must hold under "skip the test" / "just hardcode it" pressure.

### Changed
- **`hooks/session-start.sh`** — upgraded from a passive echo into a forceful bootstrap directive (1% rule + compact routing table + Iron Law reminders) injected into every session, so skills auto-trigger reliably in any project.
- **`gaspol-parallel`** — added Phase 0 worktree isolation (required before concurrent dispatch) and a continuous-execution discipline (no per-task check-ins; bounded always-pause conditions).
- **`gaspol-finish`** — documents worktree teardown ownership (`git worktree remove` after the merge/PR decision, never before).
- **README comparison table** — corrected the outdated "superpowers design intelligence ✗" claim (superpowers shipped a visual brainstorm loop); added worktree / bootstrap / test-harness parity rows.

## [1.2.0] - 2026-04

### Added
- Cross-project knowledge base (GitHub-synced, per-user private, freshness-aware)
- Power-peer design intelligence (`gaspol-design`: 85+ styles, 162+ reasoning rules, multi-framework)
- Auto-rubric model switching (Opus / Sonnet / Haiku per task type)
- Step-level evidence-based plan-verifier (BLOCKING)
- Industry research grounding with TTL cache (`gaspol-research`)
- 5 new skills: `gaspol-research`, `gaspol-adr`, `gaspol-learn`, `gaspol-kb-audit`, `gaspol-auto`
- Tiered auto-review per phase + KB lifecycle management

## [1.0.0] - 2026-02-11

### Added
- **18 skills** for execution fidelity, anti-placeholder enforcement, and design intelligence
- **4 agents** (plan-verifier, code-reviewer, spec-reviewer, code-simplifier)
- **Anti-Placeholder Iron Law** — enforced throughout execution chain
- **Per-Phase Checkpoints** — structured reports with user approval gates
- **Plan Verification Agent** — compares plan vs git diff post-implementation
- **CLAUDE.md-First Rule** — read project docs before exploring codebase
- **gaspol-sync-docs** — 3-mode CLAUDE.md maintenance (sync, audit, session learning)
- **gaspol-design** — frontend design intelligence with anti-AI-slop rules
- **Design Search Engine** — BM25 search across 8 design domains
- **Data Integration Maps** — mandatory in every plan, contract between planner and executor

### Skills
- `gaspol-brainstorm` — CLAUDE.md-first ideation with design intelligence auto-trigger
- `gaspol-design` — data-driven frontend design with bold aesthetics
- `gaspol-plan` — implementation plans with Data Integration Maps
- `gaspol-execute` — anti-placeholder execution with per-phase checkpoints
- `gaspol-parallel` — subagent-driven development with placeholder detection
- `gaspol-verify` — 4-layer verification (technical, plan fidelity, placeholder, integration)
- `gaspol-sync-docs` — CLAUDE.md maintenance and quality audit
- `gaspol-review` — enhanced code review with data integrity checks
- `gaspol-receive-review` — technical rigor over performative agreement
- `gaspol-dispatch` — parallel agent dispatch for independent problems
- `gaspol-tdd` — RED-GREEN-REFACTOR with rationalization prevention
- `gaspol-debug` — systematic 4-phase root cause investigation
- `gaspol-worktree` — git worktree management with safety checks
- `gaspol-finish` — branch completion with mandatory verification chain
- `gaspol-kickstart` — session startup and skill discovery
- `gaspol-write-skill` — TDD applied to skill creation

### Absorbed
- `claude-md-management` functionality (now in gaspol-sync-docs)
- `code-simplifier` functionality (now in code-simplifier agent)
