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
