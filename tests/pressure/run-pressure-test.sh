#!/usr/bin/env bash
# Pressure-test a RIGID gaspol skill: the user actively pressures the agent
# to skip the discipline ("just hardcode it", "skip the test, we're in a hurry").
# A skill passes only if it BOTH (a) still triggers AND (b) the agent does not
# emit a forbidden capitulation pattern.
#
# Usage: ./run-pressure-test.sh <skill-name> <prompt-file> <forbidden-regex> [max-turns]
# Example:
#   ./run-pressure-test.sh gaspol-tdd ./prompts/tdd-skip.txt 'skip the test|without a test'
#   ./run-pressure-test.sh gaspol-execute ./prompts/placeholder.txt 'const data = \[|mock(Data|Users)'

set -e

SKILL_NAME="$1"
PROMPT_FILE="$2"
FORBIDDEN="$3"
MAX_TURNS="${4:-3}"

if [ -z "$SKILL_NAME" ] || [ -z "$PROMPT_FILE" ] || [ -z "$FORBIDDEN" ]; then
    echo "Usage: $0 <skill-name> <prompt-file> <forbidden-regex> [max-turns]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/gaspol-tests/${TIMESTAMP}/pressure/${SKILL_NAME}"
mkdir -p "$OUTPUT_DIR"

PROMPT=$(cat "$PROMPT_FILE")
LOG_FILE="$OUTPUT_DIR/claude-output.json"

echo "=== gaspol Pressure Test ==="
echo "Skill:     $SKILL_NAME"
echo "Forbidden: $FORBIDDEN"
echo ""

cd "$OUTPUT_DIR"
timeout 300 claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    > "$LOG_FILE" 2>&1 || true

SKILL_PATTERN='"skill":"([^"]*:)?'"${SKILL_NAME}"'"'
TRIGGERED=false
grep -qE "$SKILL_PATTERN" "$LOG_FILE" && TRIGGERED=true

CAPITULATED=false
# Extract assistant text and scan for the forbidden capitulation pattern.
if grep -ioE "$FORBIDDEN" "$LOG_FILE" >/dev/null 2>&1; then
    CAPITULATED=true
fi

echo "=== Results ==="
echo "Skill triggered:  $TRIGGERED"
echo "Capitulated:      $CAPITULATED"
echo ""

if [ "$TRIGGERED" = "true" ] && [ "$CAPITULATED" = "false" ]; then
    echo "✅ PASS: skill held under pressure"
    echo "Full log: $LOG_FILE"
    exit 0
else
    echo "❌ FAIL: $([ "$TRIGGERED" = false ] && echo 'skill did not trigger; ')$([ "$CAPITULATED" = true ] && echo 'agent emitted a forbidden pattern')"
    echo "Review the log manually — capitulation detection is heuristic: $LOG_FILE"
    exit 1
fi
