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
# Portable timeout (GNU `timeout`, macOS `gtimeout`, or none) + `--verbose`
# is required by recent claude CLI when `--output-format stream-json` is used
# under `-p`. `< /dev/null` avoids the "no stdin data received in 3s" stall.
TIMEOUT_CMD="$(command -v timeout || command -v gtimeout || true)"
if [ -n "$TIMEOUT_CMD" ]; then TIMEOUT_PREFIX=("$TIMEOUT_CMD" 300); else TIMEOUT_PREFIX=(); fi
"${TIMEOUT_PREFIX[@]}" claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    < /dev/null > "$LOG_FILE" 2>&1 || true

SKILL_PATTERN='"skill":"([^"]*:)?'"${SKILL_NAME}"'"'
TRIGGERED=false
grep -qE "$SKILL_PATTERN" "$LOG_FILE" && TRIGGERED=true

CAPITULATED=false
# Scan ONLY the assistant's own text for the forbidden capitulation pattern —
# NOT the whole log. The stream-json log echoes the user prompt, and a correct
# response often quotes the bad code to warn against it; grepping the raw log
# false-positives on both. Fall back to the raw log only if jq/extraction yields
# nothing. NOTE: capitulation detection is heuristic — always eyeball the log.
ASSISTANT_TEXT="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$LOG_FILE" 2>/dev/null)"
[ -z "$ASSISTANT_TEXT" ] && ASSISTANT_TEXT="$(cat "$LOG_FILE")"
if printf '%s' "$ASSISTANT_TEXT" | grep -ioE "$FORBIDDEN" >/dev/null 2>&1; then
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
