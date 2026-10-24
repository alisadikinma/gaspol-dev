#!/usr/bin/env bash
# test-builder-check.sh — asserts brainstorm Phase 6 uses a fresh-eyes builder check
# (IDS-23 Phase A) instead of the author grading its own spec.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT="$REPO_ROOT/skills/gaspol-brainstorm/references/builder-check-prompt.md"
BRAIN="$REPO_ROOT/skills/gaspol-brainstorm/SKILL.md"
GATE="$REPO_ROOT/skills/gaspol-verify/scripts/model-gate"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qF -- "$2" "$1" || fail "$3"; }

echo "test-builder-check: positive control (helper must fail on a file lacking the string)..."
CTRL="$(mktemp)"; trap 'rm -f "$CTRL"' EXIT
echo "unrelated content" > "$CTRL"
if ( has "$CTRL" "model-tier: judge" "control" ) 2>/dev/null; then
  fail "positive control: assertion helper passed on a file lacking the string"
fi

echo "test-builder-check: prompt file..."
[ -f "$PROMPT" ] || fail "skills/gaspol-brainstorm/references/builder-check-prompt.md missing"
has "$PROMPT" "model-tier: judge" "prompt lacks 'model-tier: judge'"
has "$PROMPT" "nothing important left" "prompt lacks 'nothing important left'"
has "$PROMPT" "looks unnecessary" "prompt lacks 'looks unnecessary'"

echo "test-builder-check: SKILL.md Phase 6..."
for s in 'builder-check-prompt.md' 'model: "opus"' 'model-tier: judge' 'nothing important left' 'one round'; do
  has "$BRAIN" "$s" "SKILL.md Phase 6 lacks '$s'"
done
if grep -qF -- "Spec self-review" "$BRAIN"; then
  fail "SKILL.md still contains 'Spec self-review'"
fi

echo "test-builder-check: model-gate clean on this repo..."
"$GATE" >/dev/null || fail "model-gate did not exit 0 (exit $?)"

echo "test-builder-check: OK"
