#!/usr/bin/env bash
# test-skill-trim-execute.sh — gaspol-execute must stay under the compaction cut (IDS-23 Phase F).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The ceiling is 18,000 bytes, which leaves headroom. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-execute/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-execute"
LIMIT=18000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# has FILE STRING — fixed-string match, no regex surprises.
has() { grep -qF -- "$2" "$1"; }

# Format: 'gate name|fixed string'. Matched with grep -qF, at least 25 characters, one line of the
# body that states the gate's condition AND consequence, not a heading.
GATES=(
  'iron-law-1|LAW 1: NO PLACEHOLDER/MOCK/DUMMY DATA IF PLAN SPECIFIES REAL INTEGRATION'
  'iron-law-2|LAW 2: NO STEP SKIPPED WITHOUT EXPLICIT USER APPROVAL'
  'iron-law-3|LAW 3: NO COMPLETION CLAIM WITHOUT EVIDENCE'
  'iron-laws-stop|If a decision violates any law, STOP and ask the user.'
  'pre-mandatory|**MANDATORY before writing ANY code.** Do not skip any step.'
  'step0-other-ledgers|Do not proceed into Step 1 until the user has chosen.'
  'step3-one-to-one|TodoWrite maps **1:1** with the plan'"'"'s phases'
  'step3-older-flat|**Older flat** ledgers (one line per'
  'step6-blocking|### Step 6: Pre-Flight Conflict Matrix (BLOCKING — before Phase A runs)'
  'step6-two-kinds|Two kinds of row, both required:'
  'step6-not-ran|**"The scan is clean" without those rows is not a scan that ran.**'
  'step6-above-log|**above `## Log`**, never below it'
  'step6-ruling|Rule on every finding before execution begins'
  'step7-blocking|### Step 7: Verification Baseline (BLOCKING — before Phase A runs)'
  'step7-unknown-stop|tool missing) → **STOP and ask**'
  'step7-no-markers|plan-declared commands, recorded as `detect-stack: no stack markers, using plan-declared commands`.'
  'step7-red-baseline|**If the baseline is already red, STOP and ask**'
  'loop-gate|**The gate:** a phase **may not be ticked** `[x]` until its ladder ran'
  'loop-fix-loop|Full rule: **[skills/_shared/verification-loop.md](../_shared/verification-loop.md)**'
  'loop-verbatim|feed the failing command'"'"'s **actual output, verbatim** into the fix'
  'loop-skip-explicit|skipped **explicitly, with the reason**; a silent'
  'artifact-pending|| `design-artifact: pending — <url>` | **STOP and ask** — published, never approved |'
  'artifact-none|| no such line | proceed, recording `design-artifact: none — no offer was made` |'
  'artifact-empty-reason|`pending` — **STOP and ask**.'
  'artifact-never-offers|**This skill never presents the offer**'
  'completeness-heading|## Completeness Gate (before writing code for any phase, and again before calling it done)'
  'completeness-state-rungs|Before ticking the phase, state which rungs it owed and where each is covered.'
  'completeness-boundary|It never licenses a placeholder where'
  'antiph-trace|1. **TRACE the data source.**'
  'antiph-stop|4. **If about to write hardcoded data** — STOP. You are about to create a placeholder.'
  'antiph-ask|**STOP.** Use the **AskUserQuestion** tool to present the user with three options'
  'antiph-never-c|**NEVER choose option (c) silently.**'
  'checkpoint-one|1. **One phase, one checkpoint.** Never batch-complete multiple phases.'
  'checkpoint-wait|2. **Wait for approval.** Do not proceed to the next phase until the user says to continue.'
  'checkpoint-tick-gate|6. **The tick-then-append gate (BLOCKING).**'
  'checkpoint-blocking|Blocking like a test gate: no next phase until all'
  'tdd-gate|**TDD Hard Gate (BLOCKING):**'
  'tdd-stop|If phase description does NOT have this as step 1:'
  'tdd-emit|- Emit error: `"Phase [X] missing TDD gate. Plan template violation."`'
  'tdd-no-proceed|- Do NOT proceed without resolution'
  'tdd-step-one|1. Write failing test for [specific behavior]. Expected error: [error class/message].'
  'review-classifier|dispatch the `code-reviewer` agent (Sonnet per rubric) scoped to this phase'
  'step35-blocks|blocks phase approval unless the user overrides'
  'step35-script|python3 skills/gaspol-verify/scripts/design_audit.py <project-root> --json'
  'step36-triggers|new API endpoint, payment, or sensitive data**'
  'step36-blocks|unless the user explicitly accepts the risk with a reason'
  'step4-approval|Do NOT proceed until the user explicitly approves via the popup'
  'step6-completion-gate|- Report findings — do NOT claim complete if issues exist'
  'step7-handoff|Until `gaspol-finish` runs, the work is not verified.'
  'step8-offer|Finishing is an offer, not the automatic next step.'
  'step8-finish-offer-ref|[_shared/finish-offer.md](../_shared/finish-offer.md) states — options, deferral cursor,'
  'completion-blocked|Any hit and the gate is **BLOCKED**.'
  'completion-no-claim|claim completion and do NOT enter the verification chain while the gate is blocked.'
  'stop-scope-creep|(you want to add something the plan does not mention — ask first'
  'stop-architecture|an **architecture conflict**'
  'failure-completion-rerun|4. **After fixes, re-run the completion gate** — must pass clean'
)

echo "test-skill-trim-execute: positive control (has must reject a string the file lacks)..."
if has "$SKILL" "zzz-this-string-is-not-in-any-skill-zzz"; then
  fail "positive control: has() matched a string that cannot exist"
fi

echo "test-skill-trim-execute: size ceiling..."
[ -f "$SKILL" ] || { echo "FAIL: $SKILL_REL missing" >&2; exit 1; }
BYTES=$(wc -c < "$SKILL" | tr -d ' ')
if [ "$BYTES" -lt "$LIMIT" ]; then
  pass "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
else
  fail "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
fi

echo "test-skill-trim-execute: every gate survives in the body..."
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

echo "test-skill-trim-execute: every backticked references/ path in the body exists, and each file has a 'Read ... when' pointer..."
REFS=$(grep -oE '`references/[A-Za-z0-9_.-]+\.md`' "$SKILL" | tr -d '`' | sort -u || true)
NREFS=$(printf '%s\n' "$REFS" | grep -c . || true)
if [ "${NREFS:-0}" -lt 2 ]; then
  fail "SKILL.md names only ${NREFS:-0} references/ path(s), expected at least 2 — the scan is broken or the pointers are gone"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then pass "skills/gaspol-execute/$ref exists"; else fail "SKILL.md names skills/gaspol-execute/$ref but the file does not exist"; fi
  if grep -qF -- "Read \`$ref\` when" "$SKILL"; then pass "SKILL.md says when to read $ref"; else fail "SKILL.md has no 'Read \`$ref\` when ...' pointer"; fi
done
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || { fail "no references/*.md files exist"; break; }
  rel="references/$(basename "$f")"
  if printf '%s\n' "$REFS" | grep -qxF -- "$rel"; then :; else fail "$rel exists but SKILL.md never points at it"; fi
done

echo "test-skill-trim-execute: the moved text is really in the references..."
for pair in \
  'references/pre-execution.md|### Step 0: Check for Other Active In-Flight Ledgers' \
  'references/pre-execution.md|- **(d) Something else**' \
  'references/pre-execution.md|### Step 5: Identify Reusable Code' \
  'references/pre-execution.md|| Cross-task | every pair of tasks that **share a file** or an interface |' \
  'references/pre-execution.md|`[Proceed, treating these N failures as pre-existing]`' \
  'references/pre-execution.md|## CLAUDE.md-First Rule' \
  'references/execution-flow.md|`[Skip this phase]`, `[Stop execution]`' \
  'references/execution-flow.md|- **(a) Tick the Checklist, in place:**' \
  'references/execution-flow.md|### Session-Length Checkpoint (Context-Budget Nudge)' \
  'references/execution-flow.md|- **(c) Raise the threshold for this run**' \
  'references/execution-flow.md|### Step 5: Repeat' \
  'references/execution-flow.md|## Failure Recovery' \
  'references/execution-flow.md|2. **Categorize each issue** — placeholder, TODO, dead code, console.log, etc.'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if [ -f "$SKILL_DIR/$rf" ] && has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-execute: relative markdown links inside references/ resolve..."
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || continue
  dir="$(dirname "$f")"
  for target in $(grep -oE '\]\([^)#]+\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    if [ -f "$dir/$target" ]; then pass "$(basename "$f") link $target resolves"; else fail "$(basename "$f") links to $target which does not resolve"; fi
  done
done

echo "test-skill-trim-execute: references do not claim precedence over the body..."
if grep -qiE 'where the two disagree|SKILL\.md wins' "$SKILL_DIR"/references/*.md 2>/dev/null; then
  fail "a references/ file claims precedence over SKILL.md"
else
  pass "no references/ file claims precedence over SKILL.md"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "test-skill-trim-execute: $FAILURES failure(s)" >&2
  exit 1
fi
echo "test-skill-trim-execute: OK"
