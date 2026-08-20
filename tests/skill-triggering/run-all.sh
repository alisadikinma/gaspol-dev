#!/usr/bin/env bash
# Run all gaspol skill-triggering tests.
# Each entry: <skill-name> must auto-trigger from prompts/<skill-name>.txt
# Usage: ./run-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

SKILLS=(
    "gaspol-brainstorm"
    "gaspol-tdd"
    "gaspol-debug"
    "gaspol-plan"
    "gaspol-review"
    "gaspol-worktree"
)
# NOTE: gaspol-eval, gaspol-adr, and gaspol-learn are SECOND-ORDER skills
# (auto-triggered downstream by execute/finish/plan/verify). A cold naive
# build-prompt correctly routes to gaspol-brainstorm first, so they are
# intentionally NOT cold-prompt triggering-tested.
# Security discipline is validated via tests/pressure/ instead -- the checklist
# skill was deleted in v1.14.0 in favour of the CLI built-in /security-review,
# but the pressure case survives, retargeted at gaspol-execute Step 3.6.

echo "=== gaspol Skill-Triggering Suite ==="
echo ""

PASSED=0
FAILED=0
RESULTS=()

for skill in "${SKILLS[@]}"; do
    prompt_file="$PROMPTS_DIR/${skill}.txt"
    if [ ! -f "$prompt_file" ]; then
        echo "⚠️  SKIP: no prompt file for $skill"
        continue
    fi
    echo "Testing: $skill"
    if "$SCRIPT_DIR/run-test.sh" "$skill" "$prompt_file" 3; then
        PASSED=$((PASSED + 1)); RESULTS+=("✅ $skill")
    else
        FAILED=$((FAILED + 1)); RESULTS+=("❌ $skill")
    fi
    echo ""; echo "---"; echo ""
done

echo "=== Summary ==="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo ""
echo "Passed: $PASSED   Failed: $FAILED"
[ $FAILED -gt 0 ] && exit 1 || exit 0
