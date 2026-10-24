#!/usr/bin/env bash
# test-auto-waves.sh — gaspol-auto runs plan waves (IDS-22 Phase D)
#
# gaspol-auto used to walk the plan one phase at a time. Phase B gave the plugin
# `plan-waves`, which turns a waves-v1 plan into dependency waves, file-isolated
# lanes and a per-phase `complexity=... model=... effort=... review=...` line.
# These are text assertions over the skill: they prove the obligations are stated,
# not that an agent obeys them (that is what the pressure harness is for).
#
# Sections are EXTRACTED from the skill and captured into variables first
# (pipefail-safe), never copied into this file: a copy would keep passing after
# the skill drifted. The mapping complexity -> model/effort/review lives only in
# plan-waves; this test also asserts the skill does not restate it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTO="$REPO_ROOT/skills/gaspol-auto/SKILL.md"

fails=0
fail() { echo "FAIL: $1"; fails=$((fails+1)); }
has()  { printf '%s' "$2" | grep -qF -- "$1"; }

[ -f "$AUTO" ] || { echo "FAIL: skills/gaspol-auto/SKILL.md not found"; exit 1; }
skill=$(cat "$AUTO")

preflight=$(awk '/^### Pre-Flight Gate/{f=1;next} /^### Execution Loop/{f=0} f' "$AUTO")
loop=$(awk '/^### Execution Loop/{f=1;next} /^### Hard Stop Conditions/{f=0} f' "$AUTO")
hard=$(awk '/^### Hard Stop Conditions/{f=1;next} /^### Post-Run Consolidated Report/{f=0} f' "$AUTO")

# Positive control: the extractors read real skill text, not empty strings.
[ -n "$preflight" ] || fail "extractor read an empty Pre-Flight Gate section"
[ -n "$loop" ]      || fail "extractor read an empty Execution Loop section"
[ -n "$hard" ]      || fail "extractor read an empty Hard Stop Conditions section"
has 'Iron Law' "$skill" || fail "positive control: skill text lacks its own 'Iron Law' heading"
has 'Test baseline' "$preflight" || fail "positive control: Pre-Flight section lacks the 'Test baseline' check"
has 'Ambiguity in plan' "$hard" || fail "positive control: hard-stop table lacks the 'Ambiguity in plan' row"

# 1 — anchored plan-waves invocation (exact form gated by test-kb-no-hardcoded-path.sh)
anchored='"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves"'
has 'plan-waves' "$skill" || fail "skills/gaspol-auto/SKILL.md does not invoke plan-waves"
has "$anchored" "$preflight" || fail "plan-waves is not invoked through the anchored CLAUDE_PLUGIN_ROOT path in Pre-Flight"

# 2 — pre-flight is five checks, every count agrees
has 'Only after all 5 pre-flight checks pass' "$preflight" || fail "pre-flight does not say 'all 5 pre-flight checks'"
has 'all 5 checks' "$skill" || fail "Red Flags row does not say 'all 5 checks'"
stale=$(printf '%s\n' "$skill" | grep -nE 'all 4 (pre-flight )?checks|4 pre-flight' || true)
[ -z "$stale" ] || fail "stale four-check wording remains: $stale"
five=$(printf '%s\n' "$preflight" | grep -E '^5\. ' || true)
[ -n "$five" ] || fail "Pre-Flight has no numbered check 5"

# 3 — all four exit states handled by name
for code in 0 1 3 4; do
  printf '%s\n' "$preflight" | grep -qE "exit $code\b|Exit $code\b" || fail "Pre-Flight check 5 does not handle plan-waves exit $code"
done
has 'waves: none — legacy plan' "$preflight" || fail "legacy fallback line 'waves: none — legacy plan' missing"
has 'every phase' "$preflight" || fail "legacy fallback does not say every phase is treated as medium"
has 'STOP and ask' "$preflight" || fail "exit 3 does not say STOP and ask"
has 'refuse to start' "$preflight" || fail "exit 1 does not say refuse to start"

# 4 — the loop iterates waves, and names the parser lines it reads
has 'each wave' "$loop" || fail "Execution Loop does not iterate waves"
has 'wave <N> lane <M>' "$loop" || fail "Execution Loop does not name the 'wave <N> lane <M>' lines"
has 'phase <id>' "$loop" || fail "Execution Loop does not name the 'phase <id>' lines"
has 'model' "$loop" && has 'effort' "$loop" || fail "Execution Loop does not pass model and effort from the phase line"
has 'complexity=complex' "$loop" || fail "Execution Loop does not name complexity=complex"
has 'never done in-session' "$loop" || fail "a complex phase is not forbidden from running in-session"

# 5 — multi-lane waves: worktree, concurrency, lane order
has 'gaspol-worktree' "$loop" || fail "multi-lane wave does not invoke gaspol-worktree"
has 'single message' "$loop" || fail "lanes are not dispatched concurrently in a single message"
has 'one after another' "$loop" || fail "phases inside one lane are not run one after another"

# 6 — commit ownership
has 'do not commit' "$loop" || fail "multi-lane sub-agents are not told 'do not commit'"
has 'orchestrator commits' "$loop" || fail "'orchestrator commits' missing for multi-lane waves"
has 'git status --porcelain' "$loop" || fail "post-commit 'git status --porcelain' rule missing"
has 'empty' "$loop" || fail "porcelain output is not required to be empty"
has 'Ambiguity in plan' "$loop" || fail "leftover files do not route to the 'Ambiguity in plan' hard-stop"
has 'skills/_shared/verification-loop.md' "$loop" || fail "wave ladder does not reference skills/_shared/verification-loop.md"
has 'detect-stack' "$loop" || fail "wave ladder does not derive commands via detect-stack"

# 7 — complex-phase review
has 'gaspol-dev:code-reviewer' "$loop" || fail "complex review does not dispatch gaspol-dev:code-reviewer"
has 'model: "opus"' "$loop" || fail "complex review does not pin model: \"opus\""
has 'review-package' "$loop" || fail "complex review is not scoped by review-package"
has 'skills/_shared/fix-loop.md' "$loop" || fail "fix loop is not delegated to skills/_shared/fix-loop.md"

# 8 — no cap number, no mapping table restated
cap=$(printf '%s\n' "$loop" | grep -iE '(five|three|four|two|[0-9]+)[ -]rounds?|rounds? (cap|limit|max)|max(imum)? [0-9]+ rounds' || true)
[ -z "$cap" ] || fail "Execution Loop restates a fix-loop round cap: $cap"
mapping=$(printf '%s\n' "$skill" | grep -E '^\| *(light|medium|complex) *\|' || true)
[ -z "$mapping" ] || fail "skill restates the complexity -> model/effort/review table: $mapping"

# 9 — lane failure: results kept, wave stops, next wave not started, ledger in plan order
has 'completed, failed or not started' "$loop$hard" || fail "pause message does not list lanes as completed, failed or not started"
has 'uncommitted' "$loop$hard" || fail "in-flight lane results are not kept uncommitted"
has 'plan order' "$loop" || fail "ledger rows after a wave do not follow plan order"
has 'NEXT:' "$loop" || fail "per-phase Log line does not carry its NEXT: cursor"

# 10 — obligations the rewrite must keep
for lit in 'Clean git state' 'Plan TDD gate' 'Ledger tick (BLOCKING)' 'Rollback on Abort' 'What Autonomous DOES NOT Do' \
           'Post-Run Consolidated Report' '_shared/finish-offer.md'; do
  has "$lit" "$skill" || fail "gaspol-auto lost: $lit"
done
for row in 'Test failure' 'Placeholder detected' 'Destructive operation' 'Ambiguity in plan' 'Iron Law violation' \
           '3+ consecutive errors' 'External API failure' 'Git conflict'; do
  has "| $row |" "$hard" || fail "hard-stop table lost the row: $row"
done

if [ "$fails" -ne 0 ]; then
  echo "test-auto-waves: $fails failure(s)"
  exit 1
fi
echo "test-auto-waves: all assertions passed"
