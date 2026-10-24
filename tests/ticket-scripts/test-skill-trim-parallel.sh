#!/usr/bin/env bash
# test-skill-trim-parallel.sh — gaspol-parallel must stay under the compaction cut (IDS-23 Phase E).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The ceiling is 18,000 bytes, which leaves headroom. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-parallel/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-parallel"
LIMIT=18000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# has FILE STRING — fixed-string match, no regex surprises.
has() { grep -qF -- "$2" "$1"; }

# Format: 'gate name|fixed string'. Matched with grep -qF, at least 25 characters, one line of the
# body that states the gate's condition AND consequence, not a heading.
GATES=(
  'mode-independent-wave|A new wave starts only after the previous wave'"'"'s tasks all return.'
  'phase0-isolate|Before dispatching ANY concurrent implementer subagents, ensure an isolated workspace exists'
  'phase0-required|isolation is **required**. Parallel agents editing the same working directory race on files.'
  'continuous-execute|**execute all tasks continuously — do not pause to check in between tasks.**'
  'pause-fix-loop|The fix loop trips its round-5 breaker AND adjudicating the open findings still leaves every path forward a guess'
  'pause-ambiguity|A genuine ambiguity in a task blocks progress (ask via AskUserQuestion).'
  'pause-iron-law|An Iron Law violation or destructive operation is required (always pause).'
  'pause-checkpoint|The session-length checkpoint fires'
  'preflight-blocking|## Pre-Flight Conflict Matrix (BLOCKING — before the first dispatch)'
  'preflight-two-rows|Two kinds of row, both required:'
  'preflight-cross-task|every pair of tasks that **share a file** or an interface'
  'preflight-self-consistency|whether its own text **agrees with itself**'
  'preflight-not-ran|**"The scan is clean" without those rows is not a scan that ran.**'
  'preflight-above-log|**above `## Log`**, never below it'
  'preflight-ruling|Rule on every finding before execution begins'
  'dag-blocking|**Run the scheduler** (BLOCKING — do not hand-schedule'
  'dag-never-start|Never start wave N+1 until wave N fully completes.'
  'dag-rejects|The scheduler rejects dependency cycles and unknown deps'
  'dag-under-declared|you under-declared `files`'
  'plan-waves-source|take deps, files, model and effort from the'
  'base-sha-never-head1|NEVER use `HEAD~1` as the base'
  'task-brief-run|`skills/gaspol-parallel/scripts/task-brief <PLAN_FILE> <N>`'
  'brief-single-source|the single source of the implementer'"'"'s requirements.'
  'never-reference-plan|**Never reference the plan.**'
  'exact-values-brief|**Exact values** — numbers, magic strings, signatures, test cases — live only in the brief.'
  'model-explicit|**Always specify the model explicitly.**'
  'model-turn-count|**Turn count beats token price**'
  'ladder-done|`DONE` is not allowed until it passes'
  'ladder-fail-restart|**Fail at level N → fix, then restart the ladder from L1**'
  'ladder-skip-explicit|**A level that genuinely doesn'"'"'t apply is skipped explicitly, not silently**'
  'ladder-unknown-stop|`<level>: UNKNOWN` → STOP and ask'
  'ladder-orchestrator-resolves|the orchestrator resolves the L1–L3'
  'status-route|Route on the reported status — do NOT treat every return as "done":'
  'status-done|**DONE** — generate the review package and proceed to Step 5.'
  'status-concerns|**DONE_WITH_CONCERNS** — read the concerns FIRST.'
  'status-needs-context|**NEEDS_CONTEXT** — provide the missing information and **re-dispatch** the same task.'
  'status-blocked|**BLOCKED** — assess the blocker.'
  'status-never-blind-retry|**Never** ignore the escalation or blind-retry the same'
  'review-base-never-head1|**BASE is the Step-2 SHA, never `HEAD~1`**'
  'spec-reviewer-model|subagent_type: "gaspol-dev:spec-reviewer"`, `model: "opus"`'
  'spec-before-quality|Do NOT proceed to quality review until spec passes.'
  'quality-reviewer-model|subagent_type: "gaspol-dev:code-reviewer"`, `model: "opus"`'
  'refuter-default-refuted|dispatch one refuter subagent per finding (default REFUTED)'
  'minor-never-loop|never enter the loop. Do not mark the task complete with unresolved Critical/Important'
  'fix-loop-canonical|**Canonical rule: [skills/_shared/fix-loop.md](../_shared/fix-loop.md)**'
  'fix-loop-fix-base|never `HEAD~1`, which silently drops all but the last commit of a multi-commit fix.'
  'phase3-plan-verifier|Run `plan-verifier` agent (BLOCKING — step-level evidence-based)'
  'phase3-finish-offer|Present the finish offer per [_shared/finish-offer.md](../_shared/finish-offer.md)'
  'domains-verify|Run `gaspol-verify` (all 4 layers including plan-verifier if applicable)'
  'anti-placeholder-must|These rules MUST be included in every implementer dispatch.'
  'anti-placeholder-ask|the implementer MUST ask — not silently placeholder'
  'anti-placeholder-trace|**Trace every data source**'
  'red-flags-table|| Proceeding with unfixed Critical/Important issues |'
  'red-flag-worktree|Dispatching parallel implementation subagents WITHOUT worktree isolation'
  'red-flag-skip-spec|| Skipping spec review | "It looks done"'
  'ledger-tick-gate|tick-then-append gate, BLOCKING'
  'ledger-no-next-task|no next task until both steps are written, never batched at the end'
  'checkpoint-ask|use the **AskUserQuestion** tool:'
  'failures-spec-adjudicate|Adjudicate each open finding and record the ruling.'
  'failures-fix-loop|Run The Fix Loop: rounds 1-3 resume the implementer'
  'failures-escalate|Escalate to the user only when adjudication leaves every path forward a guess.'
  'failures-tests|Implementer must fix before reporting completion'
)

echo "test-skill-trim-parallel: positive control (has must reject a string the file lacks)..."
if has "$SKILL" "zzz-this-string-is-not-in-any-skill-zzz"; then
  fail "positive control: has() matched a string that cannot exist"
fi

echo "test-skill-trim-parallel: size ceiling..."
[ -f "$SKILL" ] || { echo "FAIL: $SKILL_REL missing" >&2; exit 1; }
BYTES=$(wc -c < "$SKILL" | tr -d ' ')
if [ "$BYTES" -lt "$LIMIT" ]; then
  pass "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
else
  fail "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
fi

echo "test-skill-trim-parallel: every gate survives in the body..."
for entry in "${GATES[@]}"; do
  name="${entry%%|*}"
  needle="${entry#*|}"
  if [ "${#needle}" -lt 25 ]; then
    fail "gate '$name': fixed string is under 25 characters (${#needle}) — too weak to prove the gate"
  elif has "$SKILL" "$needle"; then
    pass "gate '$name' present in SKILL.md body"
  else
    fail "gate '$name' missing from SKILL.md body: $needle"
  fi
done

echo "test-skill-trim-parallel: the dag-lanes and plan-waves scripts are named in the body, with the anchored plan-waves call..."
for needle in 'skills/gaspol-parallel/scripts/dag-lanes' 'skills/gaspol-parallel/scripts/review-package <BASE> HEAD' '"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan>'; do
  if has "$SKILL" "$needle"; then pass "body names: $needle"; else fail "body lost: $needle"; fi
done

echo "test-skill-trim-parallel: every backticked references/ path in the body exists, and each file has a 'Read ... when' pointer..."
REFS=$(grep -oE '`references/[A-Za-z0-9_.-]+\.md`' "$SKILL" | tr -d '`' | sort -u || true)
NREFS=$(printf '%s\n' "$REFS" | grep -c . || true)
if [ "${NREFS:-0}" -lt 4 ]; then
  fail "SKILL.md names only ${NREFS:-0} references/ path(s), expected at least 4 — the scan is broken or the pointers are gone"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then pass "skills/gaspol-parallel/$ref exists"; else fail "SKILL.md names skills/gaspol-parallel/$ref but the file does not exist"; fi
  if grep -qF -- "Read \`$ref\` when" "$SKILL"; then pass "SKILL.md says when to read $ref"; else fail "SKILL.md has no 'Read \`$ref\` when ...' pointer"; fi
done
for f in "$SKILL_DIR"/references/*.md; do
  rel="references/$(basename "$f")"
  if printf '%s\n' "$REFS" | grep -qxF -- "$rel"; then :; else fail "$rel exists but SKILL.md never points at it"; fi
done

echo "test-skill-trim-parallel: the moved text is really in the references..."
for pair in \
  'references/process-flow.md|### Mode `plan-phases` — Phase 1: Plan Intake' \
  'references/process-flow.md|| # | Level | Gate (what must pass) |' \
  'references/process-flow.md|"auth-fix","files":["src/auth.ts"]' \
  'references/process-flow.md|Agent 1: Authentication Middleware Fix' \
  'references/process-flow.md|##### Generate the review package' \
  'references/task-tracking.md|- **(a) Tick the Checklist:**' \
  'references/task-tracking.md|- **(c) Raise the threshold for this run**' \
  'references/task-tracking.md|Task 2/5: Add session persistence hook' \
  'references/modes.md|- 3+ failures with different root causes' \
  'references/modes.md|### Do NOT Use This Skill When' \
  'references/modes.md|## Integration' \
  'references/anti-placeholder-examples.md|const userName = "John Doe";'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if [ -f "$SKILL_DIR/$rf" ] && has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-parallel: relative markdown links inside references/ resolve..."
for f in "$SKILL_DIR"/references/*.md; do
  dir="$(dirname "$f")"
  for target in $(grep -oE '\]\([^)#]+\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    if [ -f "$dir/$target" ]; then pass "$(basename "$f") link $target resolves"; else fail "$(basename "$f") links to $target which does not resolve"; fi
  done
done

echo "test-skill-trim-parallel: the body does not restate the fix loop's round count..."
if grep -qiE 'five rounds|rounds 4-5 dispatch' "$SKILL"; then
  fail "SKILL.md restates the fix-loop round count, which belongs to skills/_shared/fix-loop.md"
else
  pass "SKILL.md points at skills/_shared/fix-loop.md without restating its round count"
fi

echo "test-skill-trim-parallel: references do not claim precedence over the body..."
if grep -qiE 'where the two disagree|SKILL\.md wins' "$SKILL_DIR"/references/*.md 2>/dev/null; then
  fail "a references/ file claims precedence over SKILL.md"
else
  pass "no references/ file claims precedence over SKILL.md"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "test-skill-trim-parallel: $FAILURES failure(s)" >&2
  exit 1
fi
echo "test-skill-trim-parallel: OK"
