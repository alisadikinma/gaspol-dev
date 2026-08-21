#!/usr/bin/env bash
# test-fix-loop.sh — asserts the five-round fix loop with model escalation (IDS-6 A3)
# and the scoped re-review against FIX_BASE (IDS-6 A4).
#
# A loop that survives three resumes usually means the implementer cannot see its
# own problem. The answer is fresh eyes plus a capability bump — not a human
# interrupt, which costs a turn and a re-explanation of context the loop already has.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/gaspol-parallel/SKILL.md"
REREVIEW="$REPO_ROOT/skills/gaspol-parallel/re-review-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }
lacks(){ grep -qi -- "$2" "$1" && fail "$3"; return 0; }

echo "test-fix-loop: checking the round structure..."

has "$SKILL" "five rounds" \
    "expected SKILL.md to define five fix rounds"
has "$SKILL" "rounds 1-3" \
    "expected SKILL.md to describe rounds 1-3"
has "$SKILL" "resume the .*implementer" \
    "expected SKILL.md to resume the original implementer for rounds 1-3"
has "$SKILL" "rounds 4-5" \
    "expected SKILL.md to describe rounds 4-5 escalation"
has "$SKILL" "one model tier above" \
    "expected SKILL.md to escalate the model tier at round 4"
has "$SKILL" "fresh implementer" \
    "expected SKILL.md to dispatch a fresh implementer at rounds 4-5"

echo "test-fix-loop: checking the round-5 breaker..."

has "$SKILL" "adjudicate" \
    "expected SKILL.md to adjudicate open findings when the breaker trips, rather than looping forever"

echo "test-fix-loop: checking the old three-attempt rule is gone..."

lacks "$SKILL" "After 3 attempts, stop and escalate" \
    "SKILL.md still carries the old 'after 3 attempts escalate to user' rule"
lacks "$SKILL" "After 3 loops still failing" \
    "SKILL.md still carries the old 'after 3 loops escalate' rule"
lacks "$SKILL" "fails after 3 fix attempts" \
    "SKILL.md's stop-conditions list still names the 3-attempt rule"

echo "test-fix-loop: checking the fix-report evidence gate..."

has "$SKILL" "covering test" \
    "expected SKILL.md to require the fix report name the covering tests"
has "$SKILL" "the command run" \
    "expected SKILL.md to require the fix report include the command run"

echo "test-fix-loop: checking the scoped re-review..."

has "$SKILL" "FIX_BASE" \
    "expected SKILL.md to define FIX_BASE for the scoped re-review"
has "$SKILL" "review-package <FIX_BASE> HEAD" \
    "expected SKILL.md to name the exact re-review command"
has "$SKILL" "the head the previous review saw" \
    "expected SKILL.md to define FIX_BASE as the head the previous review saw"
has "$SKILL" "HEAD~1" \
    "expected SKILL.md to keep the HEAD~1 prohibition visible alongside FIX_BASE"

echo "test-fix-loop: checking the re-review prompt..."

[ -s "$REREVIEW" ] || fail "expected skills/gaspol-parallel/re-review-prompt.md to exist and be non-empty"

for input in "findings" "brief" "report file" "diff"; do
    has "$REREVIEW" "$input" \
        "expected re-review-prompt.md to name its '$input' input"
done

has "$REREVIEW" "do not" \
    "expected re-review-prompt.md to bound the re-reviewer's scope (no new broad review ground)"

echo "PASS: test-fix-loop"
