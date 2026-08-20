> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-2.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor (`— NEXT: <next phase, or DONE>`, or the WIP form `— WIP — <done so far> — BLOCKER: <what's stuck> — NEXT: <exact resume action>`). This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md`.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat.

**Ticket:** IDS-2
**Ledger:** .gaspol/progress/PROGRESS-IDS-2.md

## Goal

gaspol-dev carries two skills that duplicate tooling the user already has installed, and one
skill that is quietly better than the official equivalent but is missing two of its mechanics.
This plan sheds the duplication and absorbs the missing mechanics: delete `skills/gaspol-design`
(1.7MB of forked design data superseded by the `ui-ux-pro-max` plugin, already installed at
2.13.0), delete `skills/gaspol-security-review` (12KB checklist superseded by `/security-review`,
which is compiled into the Claude Code CLI binary itself), and sharpen `gaspol-review`'s
adversarial refutation with the confidence-scoring rubric and false-positive catalogue taken from
Anthropic's official `code-review` plugin. Net effect: the plugin drops ~1.7MB and two skills
while every gate it enforces today keeps working.

## Architecture Context

Pulled from this repo's `CLAUDE.md` — the executor does not need to re-read it for these facts:

- gaspol-dev is a **markdown-and-bash plugin**. No `package.json`, no TypeScript, no build step,
  no test runner. "Tests" are standalone bash scripts under `tests/`.
- `tests/ticket-scripts/` holds **deterministic** bash tests (fast, no API calls). This is where
  this plan's tests go. `tests/pressure/` and `tests/skill-triggering/` spawn real `claude` CLI
  runs and are **stochastic** — a single run's score is a sample, not a verdict.
- Skill files live at `skills/<skill-name>/SKILL.md`. Reference files sit beside them.
- `hooks/session-start.sh` injects the routing table into every session. `skills/using-gaspol/SKILL.md`
  carries the same routing table. Both must be edited whenever a skill is added or removed.
- The 3 Iron Laws (no placeholder where a real integration is specified; no step skipped without
  approval; no completion claim without evidence) and the Laziness Ladder
  (`skills/_shared/laziness-ladder.md`) both apply to every phase here.

### Established facts this plan depends on (verified 2026-08-21, do not re-litigate)

1. **`/security-review` is a CLI built-in.** Verified by string-searching the installed binary
   `~/.local/share/claude/versions/2.1.206`: it registers
   `{name:"security-review", description:"Complete a security review of the pending changes on the
   current branch"}` with a built-in prompt body. It needs no plugin install and no marketplace.
2. **`/code-review` is an installed Anthropic plugin, `code-review@claude-plugins-official`, and
   it is PR-only.** Its command file's `allowed-tools` are all `gh pr …` / `gh issue …`; it fetches
   a pull request, reviews it, and posts a comment back to GitHub. It **cannot** review a local
   working diff, so it cannot replace `gaspol-review`'s pre-merge gate in `gaspol-finish`.
3. **`gaspol-review` already has all five of that plugin's review lanes** —
   `code-reviewer.md`, `plan-artifact-reviewer.md`, `git-history-reviewer.md`,
   `code-comment-reviewer.md`, `pr-comments-reviewer.md` — plus tiering and an adversarial
   refutation pass the official plugin lacks. It is a superset, not a subset. The two things it
   lacks are the numeric confidence rubric and the explicit false-positive catalogue. **Those two
   things, and only those two, are what Phase C adds.**
4. **`ui-ux-pro-max` has no offline equivalent of `design_audit.py`.** Its audit is
   `stack/scripts/design-audit.mjs`, which drives Chromium via Playwright against a **running
   URL**, and it lives inside a `stack/` scaffold template rather than being exposed as a plugin
   command. `gaspol-verify` Layer 4 runs **offline, pre-merge, with no dev server**, so the
   browser audit cannot substitute for it. This is why Phase A relocates the script instead of
   deleting it.
5. **`design_audit.py` is self-contained.** 205 lines; imports only `argparse`, `json`, `re`,
   `sys`, `pathlib`. It never reads the 1.4MB `data/` directory. It can be moved as a single file
   with no other changes.
6. **No hard `dependencies` field.** The user explicitly rejected declaring `ui-ux-pro-max-skill`
   in `plugin.json` `dependencies`, because that field is all-or-nothing: if the third-party
   marketplace entry is renamed, yanked, or broken, **all of gaspol-dev** disables with
   `dependency-unsatisfied` — including the 20 skills that have nothing to do with design. The
   reference is **soft**: prose points at the skill and tells the user how to install it if missing.
7. **The anti-AI-slop rules are not lost.** `skills/gaspol-design/rules/anti-ai-slop.md` is being
   deleted, but its content is already duplicated verbatim in this repo's `CLAUDE.md` under
   "Anti-AI-slop enforcement rules" (never Inter/Roboto/Arial as primary, no purple gradients on
   white, no predictable symmetric layouts, no cookie-cutter card grids, no emojis as icons).
   Phase A must **verify that duplication still exists** before deleting the file.

## Tech Stack

Bash (`/bin/bash`, macOS system bash 3.2 compatible — no `${var,,}`, no associative arrays),
Python 3 stdlib only (for the relocated `design_audit.py`), Markdown. No new dependency is
introduced by this plan, and none may be.

## Data Integration Map

| Feature | Data Source | Hook/API | Exists? | Action |
|---------|-------------|----------|---------|--------|
| Design intelligence (aesthetics, palettes, typography, UX rules) | `ui-ux-pro-max` plugin skill, installed at 2.13.0 from marketplace `ui-ux-pro-max-skill` | Skill tool: `ui-ux-pro-max` | Yes | Reference softly in prose. NO `dependencies` field. |
| Offline design-compliance lint (execute Step 3.5, verify Layer 4) | `design_audit.py`, 205 lines, stdlib-only | `python3 skills/gaspol-verify/scripts/design_audit.py <root> --json` | Yes — being relocated from `skills/gaspol-design/scripts/` | Move with `git mv`, rewire both call sites |
| Pre-deployment security checklist (finish Step 4, execute Step 3.6) | Claude Code CLI built-in, compiled into 2.1.206 | Slash command `/security-review` | Yes | Invoke the built-in; delete the local skill |
| Deep multi-agent code review (escalation only) | Claude Code built-in cloud review | `/code-review ultra` | Yes | Document as a **user-triggered** escalation. It is billed and **Claude cannot launch it** — the skill must say so, never attempt it. |
| Local pre-merge code review (finish Step 3, BLOCKING) | `gaspol-review` Tier 0/1/2 lanes, already in-repo | Skill tool: `gaspol-review` | Yes | Keep. Enhance Step 2.5 only. |
| Confidence rubric + false-positive catalogue | `code-review@claude-plugins-official` command file, read at `~/.claude/plugins/cache/claude-plugins-official/code-review/unknown/commands/code-review.md` | n/a — prose absorbed into `gaspol-review/SKILL.md` | Yes | Absorb the rubric text; do not add a runtime dependency on that plugin |

**Nothing in this plan is a placeholder.** Every row above resolves to something that exists on
disk today. If any call site cannot be rewired to a real target, STOP and ask the user — do not
leave a dangling path.

## Prerequisite (already done — do not repeat)

The 22 symlinks at `~/.claude/skills/gaspol-*` that pinned the plugin to version 1.12.0 have been
removed, the 14 unpushed IDS-1 commits have been pushed, and the plugin cache has been updated to
1.13.0. Skills now resolve through the plugin itself (namespaced `gaspol-dev:<skill>`) and follow
version updates automatically. Without that fix, none of this plan's edits would ever take effect.
A backup of the removed symlinks is at `~/.claude/maintenance/gaspol-symlinks-backup-2026-08-21.txt`.

## Laziness notes (deliberate simplifications — keep them)

- **One test file, not three.** All three phases' assertions live in
  `tests/ticket-scripts/test-skill-delegation.sh`, each phase appending its own function. Three
  separate scripts would triple the boilerplate for no added signal.
- **`git mv`, not copy-then-delete,** for `design_audit.py` — preserves history in one operation.
- **No shim, no wrapper, no compatibility alias** for the deleted skills. A skill that no longer
  exists should fail loudly at its call site, and there are exactly two call sites, both edited in
  this plan. `ponytail:` a compatibility shim would be the upgrade path if external repos turn out
  to reference `skills/gaspol-design/` — none do today.
- **Historical plan documents are not edited.** `docs/plans/*.md` files dated before this ticket
  are a record of what was true then. Rewriting them would be falsifying history. Only these files
  get swept: `CLAUDE.md`, `README.md`, `NOTICE.md`, `hooks/session-start.sh`, `tests/README.md`,
  and the `SKILL.md` files named per phase.

---

### Phase A: Dissolve gaspol-design, keep its one working part

**Estimated time:** 12 minutes

**Files:**
- Create: `tests/ticket-scripts/test-skill-delegation.sh`
- Move: `skills/gaspol-design/scripts/design_audit.py` → `skills/gaspol-verify/scripts/design_audit.py`
- Delete: `skills/gaspol-design/` (entire directory, after the move)
- Modify: `skills/gaspol-execute/SKILL.md` (line ~371), `skills/gaspol-verify/SKILL.md` (line ~297),
  `skills/gaspol-brainstorm/SKILL.md`, `skills/gaspol-plan/SKILL.md`, `skills/gaspol-adr/SKILL.md`,
  `skills/gaspol-write-skill/SKILL.md`, `skills/using-gaspol/SKILL.md`,
  `skills/gaspol-brainstorm/visual-companion.md`, `hooks/session-start.sh`,
  `tests/skill-triggering/run-all.sh`

**Steps:**

1. Write failing test for design-skill delegation. Expected error: `test-skill-delegation.sh: no such file or directory`.

   Create `tests/ticket-scripts/test-skill-delegation.sh`, executable (`chmod +x`), containing a
   `test_design_delegation` function asserting all four of:
   - `skills/gaspol-design/` does **not** exist
   - `skills/gaspol-verify/scripts/design_audit.py` exists **and** `python3 <path> --help` exits 0
   - `grep -rn 'skills/gaspol-design' --include='*.md' --include='*.sh' .` returns **zero** hits
     outside `docs/plans/` and `CHANGELOG.md`
   - `grep -rln 'ui-ux-pro-max' skills/ hooks/` returns at least `hooks/session-start.sh` and
     `skills/using-gaspol/SKILL.md`

   Follow the existing style in `tests/ticket-scripts/test-detect-stack.sh`: plain bash, a
   `fail()` helper that prints to stderr and returns 1, a pass/fail counter, exit non-zero on any
   failure. Use `/bin/bash` explicitly in the shebang.

2. Run `bash tests/ticket-scripts/test-skill-delegation.sh`, confirm it fails on the first
   assertion (`skills/gaspol-design/` still exists) — not on a syntax error.

3. Verify the anti-AI-slop rules are already duplicated in `CLAUDE.md` before destroying the
   source: `grep -c 'Anti-AI-slop' CLAUDE.md` must be ≥1 and the "NEVER use" / "ALWAYS choose"
   lists must be present. **If they are not, STOP and ask the user** — do not delete the file.

4. `git mv skills/gaspol-design/scripts/design_audit.py skills/gaspol-verify/scripts/design_audit.py`
   (create `skills/gaspol-verify/scripts/` first if absent). Confirm the file is executable-readable
   and that `python3 skills/gaspol-verify/scripts/design_audit.py --help` exits 0.

5. `git rm -r skills/gaspol-design`. Also delete any `__pycache__` left behind and confirm
   `skills/gaspol-design` is gone from the working tree.

6. Rewire the two functional call sites — **exact string replacement**, both currently reading
   `python3 skills/gaspol-design/scripts/design_audit.py <project-root> --json`:
   - `skills/gaspol-execute/SKILL.md` (Step 3.5, ~line 371)
   - `skills/gaspol-verify/SKILL.md` (Design Compliance Sub-Check, ~line 297)

   Both become `python3 skills/gaspol-verify/scripts/design_audit.py <project-root> --json`.
   Leave every surrounding threshold rule untouched — in particular `gaspol-verify`'s
   "🔴 NON-COMPLIANT (score <60) → Layer 4 FAILS" must survive verbatim. The gate does not weaken.

7. Rewire the design-intelligence prose. Everywhere a skill file currently routes UI/design work to
   `gaspol-design`, route it to the `ui-ux-pro-max` skill instead, with a **soft** fallback
   sentence in each of the two routing tables (`hooks/session-start.sh` and
   `skills/using-gaspol/SKILL.md`):

   > Design UI / colors / layout → invoke the `ui-ux-pro-max` skill (third-party plugin). If it is
   > not installed, tell the user to run
   > `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill` and continue without it — gaspol
   > declares no hard dependency on it, so its absence never disables any other skill.

   Apply the same substitution in `gaspol-brainstorm/SKILL.md` (Phase 2.5 gate and Phase 3),
   `gaspol-plan/SKILL.md` (Design Deliverable column), `gaspol-adr/SKILL.md`,
   `gaspol-write-skill/SKILL.md`, and `gaspol-brainstorm/visual-companion.md`. Remove
   `gaspol-design`'s line from `tests/skill-triggering/run-all.sh`'s comment block.

8. Run `bash tests/ticket-scripts/test-skill-delegation.sh`, confirm `test_design_delegation`
   passes.

9. Run the pre-existing deterministic suite to prove nothing regressed:
   `for t in tests/ticket-scripts/test-*.sh; do bash "$t" || echo "FAILED: $t"; done`

10. Commit: `refactor(design): delegate design intelligence to ui-ux-pro-max, keep the offline audit`

**Verification:**
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` exits 0
- [ ] All other `tests/ticket-scripts/test-*.sh` still exit 0
- [ ] `skills/gaspol-design/` does not exist; `git status` shows the deletion staged
- [ ] `python3 skills/gaspol-verify/scripts/design_audit.py --help` exits 0
- [ ] `grep -rn 'skills/gaspol-design' --include='*.md' --include='*.sh' .` returns hits **only**
      under `docs/plans/` and `CHANGELOG.md`
- [ ] `gaspol-verify`'s "score <60 → Layer 4 FAILS" rule is byte-identical to before
- [ ] `plugin.json` contains **no** `dependencies` key
- [ ] No placeholder/TODO comments introduced
- [ ] Ledger: Phase A ticked in `## Checklist` **and** a `## Log` line appended ending `— NEXT: Phase B`

---

### Phase B: Dissolve gaspol-security-review, call the CLI built-in

**Estimated time:** 10 minutes

**Files:**
- Modify: `tests/ticket-scripts/test-skill-delegation.sh` (add `test_security_delegation`)
- Delete: `skills/gaspol-security-review/`
- Modify: `skills/gaspol-finish/SKILL.md` (Step 4, ~line 96 and the Integration table ~line 282,
  and the chain-status block ~line 135), `skills/gaspol-execute/SKILL.md` (Step 3.6, ~line 397),
  `skills/gaspol-plan/SKILL.md` (Security-Sensitive Phases note), `skills/using-gaspol/SKILL.md`,
  `hooks/session-start.sh`, `tests/skill-triggering/run-all.sh`, `tests/pressure/run-all.sh`,
  `tests/README.md`

**Steps:**

1. Write failing test for security-review delegation. Expected error: `test_security_delegation: command not found`.

   Add a `test_security_delegation` function to `tests/ticket-scripts/test-skill-delegation.sh`
   asserting:
   - `skills/gaspol-security-review/` does **not** exist
   - `skills/gaspol-finish/SKILL.md` contains the literal `/security-review`
   - `skills/gaspol-execute/SKILL.md` contains the literal `/security-review`
   - `grep -rn 'gaspol-security-review' --include='*.md' --include='*.sh' .` returns **zero** hits
     outside `docs/plans/` and `CHANGELOG.md`
   - `tests/pressure/run-all.sh` no longer contains a `gaspol-security-review` case

   Wire the new function into the script's runner list.

2. Run `bash tests/ticket-scripts/test-skill-delegation.sh`, confirm the new function fails on
   `skills/gaspol-security-review/ still exists` while `test_design_delegation` still passes.

3. `git rm -r skills/gaspol-security-review`.

4. Rewrite `gaspol-finish` Step 4. It currently reads
   "### Step 4: Run gaspol-security-review -- ALWAYS runs from this chain" and delegates to that
   skill's checklist. Replace the mechanism, **preserving every gate property**:
   - It still **ALWAYS** runs from this chain, on every branch, regardless of whether the diff
     looks security-sensitive. This is not conditional here.
   - It now invokes the **built-in `/security-review`** slash command, which reviews the pending
     changes on the current branch.
   - A reported vulnerability is still treated as BLOCKING: STOP and use AskUserQuestion with
     `[Fix now]` / `[Accept risk with documented reason]`. Never present merge options with an
     unresolved security finding.
   - A clean result is still reported explicitly, e.g. "Security review: PASSED (`/security-review`,
     no findings)."
   - Update the chain-status checklist line (~135) to
     `[x] Step 4 Security review (/security-review built-in): PASSED`.
   - Update the Integration table row (~282) to name the built-in instead of the deleted skill.

5. Rewrite `gaspol-execute` Step 3.6 the same way: same trigger conditions (auth/authorization,
   secrets, user input or file uploads, new API endpoint, payment, sensitive data), same
   checkpoint section, same 🔴 FAIL blocking rule — but invoke `/security-review` instead of the
   deleted skill. Keep "Skip Step 3.6 entirely for non-security phases" verbatim.

6. Sweep the remaining prose: `skills/gaspol-plan/SKILL.md`, `skills/using-gaspol/SKILL.md`,
   `hooks/session-start.sh` routing line, `tests/README.md`. Remove the
   `gaspol-security-review` case line from `tests/pressure/run-all.sh` and its mention in
   `tests/skill-triggering/run-all.sh`'s comment block.

7. Run `bash tests/ticket-scripts/test-skill-delegation.sh`, confirm both functions pass.

8. Run every other `tests/ticket-scripts/test-*.sh`; all must exit 0.

9. Commit: `refactor(security): call the built-in /security-review, drop the forked checklist`

**Verification:**
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` exits 0 with both functions passing
- [ ] All other `tests/ticket-scripts/test-*.sh` still exit 0
- [ ] `skills/gaspol-security-review/` does not exist
- [ ] `gaspol-finish` Step 4 still says the security review **ALWAYS** runs from the chain
- [ ] `gaspol-finish` Step 4 still BLOCKS on a finding and still uses AskUserQuestion to resolve it
- [ ] `gaspol-execute` Step 3.6 trigger list is unchanged (auth, secrets, input/uploads, endpoint,
      payment, sensitive data)
- [ ] `grep -rn 'gaspol-security-review'` returns hits only under `docs/plans/` and `CHANGELOG.md`
- [ ] Security: this phase changes **who runs** the security check, never **whether** it runs.
      Inputs still validated, queries still parameterized, authz still server-side, no secrets in
      source — the gate that enforces those moved, it did not weaken.
- [ ] Ledger: Phase B ticked **and** a `## Log` line appended ending `— NEXT: Phase C`

---

### Phase C: Sharpen gaspol-review Step 2.5

**Estimated time:** 10 minutes

**Files:**
- Modify: `tests/ticket-scripts/test-skill-delegation.sh` (add `test_review_confidence`)
- Modify: `skills/gaspol-review/SKILL.md` (Step 2.5, its Red Flags table, and Quick Reference)

**Steps:**

1. Write failing test for the confidence rubric. Expected error: assertion failure `expected 'CONFIDENCE:' in gaspol-review/SKILL.md, found none`.

   Add `test_review_confidence` to `tests/ticket-scripts/test-skill-delegation.sh` asserting
   `skills/gaspol-review/SKILL.md` contains all of:
   - the literal `CONFIDENCE:`
   - the literal `80` on a line also containing `threshold` (case-insensitive)
   - the literal `pre-existing` (the false-positive catalogue)
   - the literal `/code-review ultra`
   - the still-present literal `VERDICT: CONFIRMED | REFUTED | UNVERIFIABLE` — the existing
     adversarial pass must survive, this phase **adds to** it and does not replace it

2. Run the test, confirm `test_review_confidence` fails while A's and B's functions pass.

3. Extend the Step 2.5 refuter prompt in `skills/gaspol-review/SKILL.md` to return a numeric
   score alongside its verdict, appending to the existing return block:

   ```
   VERDICT: CONFIRMED | REFUTED | UNVERIFIABLE
   CONFIDENCE: <0-100>
   EVIDENCE: <code quote + 1-2 line reason>
   ```

   Add the rubric verbatim, so the refuter is scored against a written scale rather than a vibe:

   - **0** — Not confident at all. A false positive that does not survive light scrutiny, or a
     pre-existing issue not introduced by this change.
   - **25** — Somewhat confident. Might be real, might be a false positive; could not be verified.
     If stylistic, it is not something CLAUDE.md explicitly calls out.
   - **50** — Moderately confident. Verified real, but possibly a nitpick or rare in practice.
     Relative to the rest of the change, not important.
   - **75** — Highly confident. Double-checked and very likely to be hit in practice. The current
     approach is insufficient, or CLAUDE.md names this issue directly.
   - **100** — Certain. Double-checked and confirmed; will happen frequently. Evidence directly
     confirms it.

4. Add the threshold rule and reconcile it with the existing fail-safe, which must **not** be
   weakened:

   > **Threshold 80.** A finding scoring below 80 is review noise: record it, do not fix it.
   > **Interaction with the existing verdict (this rule wins on conflict):** a
   > `REFUTED` verdict drops the finding regardless of score, and an `UNVERIFIABLE` verdict on a
   > Critical finding is still treated as CONFIRMED and still blocks **regardless of score** — the
   > numeric rubric sharpens ranking among surviving findings, it never converts a fail-safe into
   > a fail-open.

5. Add the false-positive catalogue as an explicit list the refuter is told to check against —
   these are score-0 by definition:
   - Pre-existing issues not introduced by this change
   - Something that looks like a bug but is not
   - Pedantic nitpicks a senior engineer would not raise
   - Anything a linter, typechecker, or compiler catches (missing imports, type errors, formatting)
     — assume CI runs these separately; do not run builds during review
   - General quality complaints (test coverage, documentation) unless CLAUDE.md requires them
   - Issues explicitly silenced in code (lint-ignore comment)
   - Real issues on lines this change did not modify

6. Add the escalation route, worded so no agent ever attempts to launch it:

   > **Escalation — `/code-review ultra`.** For the deepest available review, the user can run
   > `/code-review ultra` (no argument reviews the current local branch; `/code-review ultra <PR#>`
   > reviews a GitHub PR). It is a multi-agent cloud review, it is **billed**, and it is
   > **user-triggered only — Claude cannot launch it**. Offer it; never attempt it. Note also that
   > the separate `/code-review` plugin command is **PR-only** and cannot review a local working
   > diff, which is why it does not replace this skill's pre-merge gate.

7. Update the Step 2.5 Red Flags table with one new row:
   `| Treating a sub-80 finding as blocking | Wastes a fix cycle on noise — below threshold means record, not fix |`
   and one guarding the fail-safe:
   `| Using a low score to drop an UNVERIFIABLE Critical finding | Fail-open on a real risk — the verdict outranks the score |`

8. Update the Quick Reference block's line 2.5 to mention the score and threshold.

9. Run `bash tests/ticket-scripts/test-skill-delegation.sh`, confirm all three functions pass.

10. Commit: `feat(review): confidence rubric, false-positive catalogue, ultra escalation`

**Verification:**
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` exits 0, all three functions passing
- [ ] `VERDICT: CONFIRMED | REFUTED | UNVERIFIABLE` still present — the adversarial pass survives
- [ ] The UNVERIFIABLE-Critical fail-safe still blocks, and the SKILL.md says the verdict outranks
      the score
- [ ] `/code-review ultra` is documented as user-triggered and billed, with an explicit
      "Claude cannot launch it"
- [ ] The five Tier 0/1/2 lanes and the tier cost table are unchanged
- [ ] No placeholder/TODO comments introduced
- [ ] Ledger: Phase C ticked **and** a `## Log` line appended ending `— NEXT: Phase D`

---

### Phase D: Final gate — docs, counts, version

**Estimated time:** 10 minutes

**Files:**
- Modify: `tests/ticket-scripts/test-skill-delegation.sh` (add `test_docs_consistent`)
- Modify: `CLAUDE.md`, `README.md`, `NOTICE.md`, `CHANGELOG.md`,
  `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Steps:**

1. Write failing test for documentation consistency. Expected error: assertion failure `expected skill count 20 in CLAUDE.md, found 22`.

   Add `test_docs_consistent` asserting:
   - the number of directories under `skills/` excluding `_shared` equals the skill count written
     in `CLAUDE.md`'s Plugin Overview line and in `README.md`
   - `CLAUDE.md` has no `| skills/gaspol-design/... |` or `| skills/gaspol-security-review/... |`
     rows in its Architecture table
   - `plugin.json` and `marketplace.json` carry the **same** version string
   - `plugin.json` still has no `dependencies` key

2. Run the test, confirm it fails on the count mismatch.

3. Count the real skills: `ls skills | grep -v '^_shared$' | wc -l`. Expect **20** after A and B.
   Update the count everywhere it is written — `CLAUDE.md` Plugin Overview ("22 development
   skills + 4 agents"), `README.md`, and `marketplace.json`'s description if it names a count.

4. Update `CLAUDE.md`:
   - Remove the `skills/gaspol-design/*` and `skills/gaspol-security-review/` rows from the
     Architecture table; add a row for `skills/gaspol-verify/scripts/design_audit.py`.
   - Rewrite the "Design Intelligence Power Peer" section into a short section explaining that
     design intelligence is delegated to `ui-ux-pro-max`, that the reference is soft with no
     `dependencies` declaration and why (all-or-nothing failure mode), and that the offline
     compliance lint stayed. **Keep the anti-AI-slop rules block** — it is now the only copy.
   - Update both routing tables (main and Implicit Routing) for design and security.
   - Update the Workflow Chains block and the `gaspol-finish` description for the new Step 4.
   - Update the Debugging table rows that name the two deleted skills.

5. Update `README.md` and `NOTICE.md` — `NOTICE.md` credits the ui-ux-pro-max fork, which no
   longer exists in-tree; rewrite that attribution to say the forked data was removed in this
   version and the upstream plugin is used directly. Do not delete the attribution outright; a
   removed fork still had a history.

6. Add a `CHANGELOG.md` entry for **1.14.0** listing exactly the three changes and the
   symlink-shadowing fix. Write the honest framing: `gaspol-review` was **not** replaced because
   it is a superset of the official plugin, and the official plugin is PR-only.
   **CRLF warning:** `CHANGELOG.md` uses CRLF line endings in this repo (no `.gitattributes`; 33
   tracked `.md` files are CRLF). Edit it in a way that preserves them, and verify with
   `git diff --numstat CHANGELOG.md` — a small edit reporting hundreds of changed lines means the
   endings were converted. Restore them if so.

7. Bump `version` to `1.14.0` in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json`, and in `CLAUDE.md`'s footer.

8. Run the full deterministic suite: every `tests/ticket-scripts/test-*.sh` must exit 0.

9. Run `bash tests/skill-triggering/run-all.sh` and `bash tests/pressure/run-all.sh` **only if the
   user asks** — both are stochastic and spawn real `claude` CLI runs. If run, compare against a
   baseline run on the pre-change commit before calling any delta a regression. Report the numbers
   as samples, never as verdicts.

10. Verify no dangling references remain anywhere outside the historical record:
    `grep -rn 'gaspol-design\|gaspol-security-review' --include='*.md' --include='*.sh' --include='*.json' . | grep -v '^./docs/plans/' | grep -v '^./CHANGELOG.md' | grep -v '^./.gaspol/'`
    must return nothing.

11. Commit: `chore: sync docs, skill count, and version to 1.14.0 for IDS-2`

**Verification:**
- [ ] `bash tests/ticket-scripts/test-skill-delegation.sh` exits 0, all four functions passing
- [ ] Every other `tests/ticket-scripts/test-*.sh` exits 0
- [ ] The grep in step 10 returns **zero** lines
- [ ] Skill count in `CLAUDE.md` and `README.md` equals `ls skills | grep -v '^_shared$' | wc -l`
- [ ] `plugin.json` and `marketplace.json` both read `1.14.0`; `plugin.json` has no `dependencies`
- [ ] `git diff --numstat CHANGELOG.md` shows a line count proportional to the actual edit
- [ ] Anti-AI-slop rules still present in `CLAUDE.md`
- [ ] Ledger: Phase D ticked **and** a `## Log` line appended ending `— NEXT: DONE`

---

## What this plan deliberately does NOT do

- **No `dependencies` field in `plugin.json`.** Rejected by the user; the failure mode is
  all-or-nothing and would take 20 unrelated skills down with a third-party marketplace entry.
- **No replacement of `gaspol-review` with `/code-review`.** The official plugin is PR-only and
  cannot gate a local pre-merge branch, and `gaspol-review` already has all five of its lanes.
- **No editing of historical `docs/plans/*.md`.** Those record what was true when written.
- **No renaming of the seven pre-ticket files in `docs/plans/`.** Out of scope since IDS-1.
- **No fix for the `caveman` and `ponytail` symlinks**, which have the same version-pinning defect
  found in the prerequisite (`ponytail` pinned at 4.7.0 while 4.9.0 is installed; `caveman` pinned
  to a bare SHA). Flagged to the user; their call, their machine, separate ticket.
- **No update to `docs/rubric-model-switching.md`,** which still names stale model versions
  (opus 4.7 / sonnet 4.6) and has no rows for `gaspol-brainstorm` or `gaspol-plan`. Carried over
  from IDS-1's open questions as its own ticket.

## Open questions for the user

1. ~~Does anything render from `skills/gaspol-design/templates/`?~~ **Answered 2026-08-21: no.**
   `grep -rn 'templates/' skills/ hooks/ tests/` returns zero hits outside `skills/gaspol-design/`
   itself — the 108KB of multi-framework component templates are referenced by nothing. Safe for
   Phase A to delete; `ui-ux-pro-max` covers 22 stacks and supersedes them.
2. After 1.14.0 ships, it must be **pushed and the plugin updated** for any of it to take effect —
   the same trap that made IDS-1 inert for a day. `gaspol-finish` should end with
   `git push` + `claude plugin update gaspol-dev@gaspol-dev` + a restart reminder.
