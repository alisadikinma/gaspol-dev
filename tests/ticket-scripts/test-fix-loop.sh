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
# IDS-9 moved the RULE to a shared file so gaspol-finish could apply the same bound
# without loading 30KB of parallel. The assertions follow it: what is shared is
# asserted on the shared file, what is specific to this skill stays on SKILL.md.
# Leaving them all on SKILL.md would have passed only while the rule was duplicated.
LOOP="$REPO_ROOT/skills/_shared/fix-loop.md"
REREVIEW="$REPO_ROOT/skills/gaspol-parallel/re-review-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }
lacks(){ grep -qi -- "$2" "$1" && fail "$3"; return 0; }

echo "test-fix-loop: checking the round structure..."

has "$LOOP" "five rounds" \
    "expected the fix-loop rule to define five fix rounds"
has "$LOOP" "rounds 1-3" \
    "expected the fix-loop rule to describe rounds 1-3"
has "$LOOP" "resume the .*fixer" \
    "expected the fix-loop rule to resume the original implementer for rounds 1-3"
has "$LOOP" "rounds 4-5" \
    "expected the fix-loop rule to describe rounds 4-5 escalation"
has "$LOOP" "one model tier above" \
    "expected the fix-loop rule to escalate the model tier at round 4"
has "$LOOP" "fresh fixer" \
    "expected the fix-loop rule to dispatch a fresh implementer at rounds 4-5"

echo "test-fix-loop: checking the round-5 breaker..."

has "$LOOP" "adjudicate" \
    "expected the fix-loop rule to adjudicate open findings when the breaker trips, rather than looping forever"

echo "test-fix-loop: checking the old three-attempt rule is gone..."

lacks "$SKILL" "After 3 attempts, stop and escalate" \
    "SKILL.md still carries the old 'after 3 attempts escalate to user' rule"
lacks "$SKILL" "After 3 loops still failing" \
    "SKILL.md still carries the old 'after 3 loops escalate' rule"
lacks "$SKILL" "fails after 3 fix attempts" \
    "SKILL.md's stop-conditions list still names the 3-attempt rule"
for old in "After 3 attempts, stop and escalate" "After 3 loops still failing" "fails after 3 fix attempts"; do
    lacks "$LOOP" "$old" "the shared fix-loop rule carries the old 3-attempt rule: $old"
done

# The shared file is only shared if BOTH skills read it. An unreferenced shared
# file is IDS-8's kb_local defect again -- documented in one place, read by none.
for caller in "$SKILL" "$REPO_ROOT/skills/gaspol-finish/SKILL.md"; do
    grep -qF "_shared/fix-loop.md" "$caller" \
        || fail "$(basename "$(dirname "$caller")") does not reference the shared fix-loop rule"
done

echo "test-fix-loop: checking the fix-report evidence gate..."

has "$LOOP" "covering test" \
    "expected the fix-loop rule to require the fix report name the covering tests"
has "$LOOP" "the command run" \
    "expected the fix-loop rule to require the fix report include the command run"

echo "test-fix-loop: checking the scoped re-review..."

has "$LOOP" "FIX_BASE" \
    "expected the fix-loop rule to define FIX_BASE for the scoped re-review"
has "$SKILL" "review-package <FIX_BASE> HEAD" \
    "expected gaspol-parallel/SKILL.md to name the exact re-review command"
has "$SKILL" "the head the previous review saw" \
    "expected the fix-loop rule to define FIX_BASE as the head the previous review saw"
has "$SKILL" "HEAD~1" \
    "expected the fix-loop rule to keep the HEAD~1 prohibition visible alongside FIX_BASE"

echo "test-fix-loop: checking the re-review prompt..."

[ -s "$REREVIEW" ] || fail "expected skills/gaspol-parallel/re-review-prompt.md to exist and be non-empty"

for input in "findings" "brief" "report file" "diff"; do
    has "$REREVIEW" "$input" \
        "expected re-review-prompt.md to name its '$input' input"
done

has "$REREVIEW" "do not" \
    "expected re-review-prompt.md to bound the re-reviewer's scope (no new broad review ground)"

echo "PASS: test-fix-loop"
