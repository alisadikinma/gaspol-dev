#!/usr/bin/env bash
# Every hook script referenced by hooks/hooks.json is stored EXECUTABLE in git (mode 100755).
# Regression for 1.32.1: stop-done-gate.sh shipped as 100644, so Claude Code ran
# "${CLAUDE_PLUGIN_ROOT}/hooks/stop-done-gate.sh" and got "Permission denied" on every
# machine — the Stop hook never ran once, and nothing went red.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
FAILED=0
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
pass() { echo "PASS: $1"; }

scripts="$(sed -n 's/.*"command":[[:space:]]*"\${CLAUDE_PLUGIN_ROOT}\/\([^" ]*\)".*/\1/p' hooks/hooks.json)"
[ -n "$scripts" ] || fail "no hook command found in hooks/hooks.json"
for s in $scripts; do
  mode="$(git ls-files -s -- "$s" | awk '{print $1}')"
  if [ -z "$mode" ]; then fail "$s is referenced by hooks.json but not tracked"
  elif [ "$mode" = "100755" ]; then pass "$s is 100755"
  else fail "$s is $mode in git (must be 100755)"; fi
done
[ "$FAILED" -gt 0 ] && { echo "test-hooks-executable: $FAILED failed"; exit 1; }
echo "test-hooks-executable: ALL PASS"
