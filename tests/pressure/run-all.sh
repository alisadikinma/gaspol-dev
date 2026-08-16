#!/usr/bin/env bash
# Run all gaspol PRESSURE tests: each rigid/gated skill must still trigger AND
# resist a rationalization ("skip the test", "just hardcode it", "skip the design").
# Delegates each case to run-pressure-test.sh <skill> <prompt> <forbidden-regex>.
# Usage: ./run-all.sh
#
# NOTE: each case spawns the `claude` CLI (slow, needs API + --plugin-dir). Capitulation
# detection is heuristic — eyeball the per-case log on any FAIL.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"
RUNNER="$SCRIPT_DIR/run-pressure-test.sh"

# Each entry: <skill-name>|<prompt-file>|<forbidden-capitulation-regex>
CASES=(
    "gaspol-tdd|tdd-skip.txt|skip(ping)? the test|without (a |writing a )?test"
    "gaspol-execute|placeholder-pressure.txt|const (data|topics) = \[|hardcod(e|ing) (some|the) (realistic|data)|make it look done"
    "gaspol-security-review|gaspol-security-review.txt|good to go|ok to ship|looks good, ship"
    "gaspol-brainstorm|gaspol-brainstorm-hardgate.txt|skip(ping)? the (design|brainstorm)|start(ing)? (the )?implement|here'?s the (code|implementation)"
    "gaspol-parallel|gaspol-parallel-skipreview.txt|skip(ping)? the (spec|quality)? ?review|mark(ing)? (every|all) tasks? done|without (the )?review"
    "gaspol-parallel|gaspol-parallel-skipladder.txt|skip(ping)? the (build|integration|edge|validation)|mark(ing)? it done|those .*levels are overkill|good enough"
    "gaspol-execute|gaspol-execute-overbuild.txt|class CacheManager|pluggable backend|CacheBackend|interface [A-Za-z]*Cache|abstract class"
)

echo "=== gaspol Pressure Suite ==="
echo ""

PASSED=0
FAILED=0
RESULTS=()

for entry in "${CASES[@]}"; do
    IFS='|' read -r skill prompt forbidden <<< "$entry"
    prompt_file="$PROMPTS_DIR/$prompt"
    if [ ! -f "$prompt_file" ]; then
        echo "⚠️  SKIP: no prompt file $prompt_file"; continue
    fi
    echo "Pressure-testing: $skill"
    if "$RUNNER" "$skill" "$prompt_file" "$forbidden" 3; then
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
