#!/usr/bin/env bash
# test-finish-gates.sh — TDD test for ticket IDS-3: three gaps in gaspol-finish.
#
#   1. The ledger has a birth (gaspol-plan) and a middle (gaspol-execute) but no
#      death. gaspol-finish mentioned it ZERO times, so PROGRESS-<TICKET>.md
#      files -- gitignored, therefore invisible to git status -- accumulate
#      forever with a stale cursor.
#   2. gaspol-finish still hardcoded `npm test` for the post-merge run. IDS-1
#      added detect-stack specifically to kill hardcoded npm; verify, parallel,
#      plan, and execute all use it. finish was the last holdout, and on a
#      Laravel or Go repo it printed the wrong command.
#   3. "Merge locally" ended at `git branch -d`. Nothing pushed, so nothing
#      published. That is exactly how v1.13.0 sat inert on one machine for a
#      day while the repo claimed it had shipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

F="skills/gaspol-finish/SKILL.md"
FAILURES=0

pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  shift
  [[ $# -gt 0 ]] && printf '%s\n' "$@" >&2
  FAILURES=$((FAILURES + 1))
}

has() {
  local desc="$1" pattern="$2"
  if grep -q -- "$pattern" "$F" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi
}

lacks() {
  local desc="$1" pattern="$2" hits
  hits="$(grep -n -- "$pattern" "$F" 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then pass "$desc"; else fail "$desc" "$hits"; fi
}

# --- 1. ledger lifecycle ends here -----------------------------------------
has "finish names the per-ticket ledger" "PROGRESS-<TICKET>.md"
has "finish writes a closing Log line"   "NEXT: DONE"
has "finish surfaces other open ledgers via scan-active-ledgers" \
    "scripts/scan-active-ledgers"

# --- 2. post-merge test command is derived, not assumed ---------------------
has "finish derives the post-merge test command from detect-stack" \
    "scripts/detect-stack"
lacks "finish no longer hardcodes npm test" "^npm test"

# --- 3. merging is not publishing ------------------------------------------
has "finish reminds to push after a local merge" "git push origin"
has "finish covers republishing a plugin repo" "claude plugin update"
has "finish states a restart is required for a plugin update" "Restart"

# The referenced scripts must actually exist, or the instruction is a lie that
# only fails at the moment someone follows it.
for s in scan-active-ledgers detect-stack; do
  if [[ -x "skills/gaspol-execute/scripts/$s" ]]; then
    pass "referenced script $s exists and is executable"
  else
    fail "referenced script $s exists and is executable"
  fi
done

if [[ "$FAILURES" -gt 0 ]]; then
  echo "test-finish-gates: $FAILURES assertion(s) failed" >&2
  exit 1
fi

echo "PASS: test-finish-gates"
