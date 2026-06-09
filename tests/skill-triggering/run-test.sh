#!/usr/bin/env bash
# Test whether a gaspol skill auto-triggers from a naive prompt
# (one that never names the skill). This is the gaspol analogue of
# superpowers' acceptance test: skills must fire on intent, not on
# the user typing a slash command.
#
# Usage: ./run-test.sh <skill-name> <prompt-file> [max-turns]
# Example: ./run-test.sh gaspol-debug ./prompts/gaspol-debug.txt

set -e

SKILL_NAME="$1"
PROMPT_FILE="$2"
MAX_TURNS="${3:-3}"

if [ -z "$SKILL_NAME" ] || [ -z "$PROMPT_FILE" ]; then
    echo "Usage: $0 <skill-name> <prompt-file> [max-turns]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# plugin root = two levels up from tests/skill-triggering
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/gaspol-tests/${TIMESTAMP}/skill-triggering/${SKILL_NAME}"
mkdir -p "$OUTPUT_DIR"

PROMPT=$(cat "$PROMPT_FILE")
cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

echo "=== gaspol Skill-Triggering Test ==="
echo "Skill:    $SKILL_NAME"
echo "Prompt:   $PROMPT_FILE"
echo "Plugin:   $PLUGIN_DIR"
echo "Output:   $OUTPUT_DIR"
echo ""

LOG_FILE="$OUTPUT_DIR/claude-output.json"
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

echo "=== Results ==="
# Match "skill":"gaspol-debug" or "skill":"gaspol-dev:gaspol-debug"
SKILL_PATTERN='"skill":"([^"]*:)?'"${SKILL_NAME}"'"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
    echo "✅ PASS: '$SKILL_NAME' was triggered"
    TRIGGERED=true
else
    echo "❌ FAIL: '$SKILL_NAME' was NOT triggered"
    TRIGGERED=false
fi

echo ""
echo "Skills triggered in this run:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"
echo ""
echo "Full log: $LOG_FILE"

[ "$TRIGGERED" = "true" ] && exit 0 || exit 1
