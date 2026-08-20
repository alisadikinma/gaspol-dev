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


# --- 4. gaspol-sync-docs must prove it ran ---------------------------------
# Step 5 was a self-reported checkbox: "[x] Step 5 gaspol-sync-docs: COMPLETED".
# Nothing checked that CLAUDE.md actually changed. A claim with no evidence is
# exactly what Iron Law 3 forbids, and sync-docs is the one chain step with no
# trigger test, no pressure test, and no verification of any kind.
has "finish Step 5 demands evidence that CLAUDE.md changed" \
    "CLAUDE.md must appear in the branch diff"
# Specific phrase, not "skills/" -- that substring already appears elsewhere in
# the file, so asserting it would have passed vacuously and proved nothing.
has "finish Step 5 names the structural change that triggers the requirement" \
    "structural change"

# --- 5. gaspol-eval renamed to say what it tests ----------------------------
# NOTICE.md is excluded for the same reason as CHANGELOG.md: it is an
# attribution record, so naming the skill's former identity is its JOB, not
# stale drift. The first version of this helper excluded CHANGELOG but not
# NOTICE, then the rename immediately wrote history into NOTICE -- the test was
# inconsistent with its own stated principle, and caught it.
lacks_repo() {
  local desc="$1" pattern="$2" hits
  hits="$(git ls-files -- '*.md' '*.sh' '*.json' \
          | grep -v -e '^docs/plans/' -e '^CHANGELOG\.md$' -e '^NOTICE\.md$' -e 'test-finish-gates\.sh$' \
          | tr '\n' '\0' | xargs -0 grep -n -- "$pattern" /dev/null 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then pass "$desc"; else fail "$desc" "$hits"; fi
}
if [[ -f skills/gaspol-llm-test/SKILL.md ]]; then
  pass "skill renamed to gaspol-llm-test"
else
  fail "skill renamed to gaspol-llm-test"
fi
if [[ ! -e skills/gaspol-eval ]]; then
  pass "old gaspol-eval directory is gone"
else
  fail "old gaspol-eval directory is gone"
fi
lacks_repo "no live reference to the old gaspol-eval name" "gaspol-eval"

# --- 6. gaspol-receive-review compliance is measurable ---------------------
# It produces no artifact, so 7 commits touching it prove it was maintained,
# not that it was obeyed. A pressure case makes obedience observable: feed it
# review feedback that is technically WRONG and see whether it caves.
if [[ -f tests/pressure/prompts/receive-review-wrong-feedback.txt ]]; then
  pass "receive-review pressure prompt exists"
else
  fail "receive-review pressure prompt exists"
fi
if grep -q 'receive-review-wrong-feedback.txt' tests/pressure/run-all.sh 2>/dev/null; then
  pass "receive-review pressure case registered in run-all.sh"
else
  fail "receive-review pressure case registered in run-all.sh"
fi

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
