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
  local desc="$1" pattern="$2" files hits
  files="$(git ls-files -- '*.md' '*.sh' '*.json' \
           | grep -v -e '^docs/plans/' -e '^CHANGELOG\.md$' -e '^NOTICE\.md$' -e 'test-finish-gates\.sh$' || true)"
  # An empty file list would make the grep below return nothing, and "nothing"
  # is indistinguishable from "no stale references" -- the assertion would pass
  # while checking zero files. That vacuous pass is the exact defect class this
  # ticket exists to remove, so treat an empty list as a failure, not a clean bill.
  if [[ -z "$files" ]]; then
    fail "$desc" "file list came back empty -- this assertion checked nothing"
    return
  fi
  hits="$(printf '%s\n' "$files" | tr '\n' '\0' \
          | xargs -0 grep -n -- "$pattern" /dev/null 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then pass "$desc"; else fail "$desc" "$hits"; fi
}
# IDS-11 deleted gaspol-llm-test (8KB, two live referrers). The RULE it carried
# survives inline: a non-deterministic feature needs evals because unit tests miss
# its regressions. Assert the rule, not the skill -- otherwise the deletion also
# deletes the reason the skill existed.
if grep -q 'docs/evals/' skills/gaspol-plan/SKILL.md && grep -q 'docs/evals/' skills/gaspol-verify/SKILL.md; then
  pass "the eval rule survives in gaspol-plan and gaspol-verify"
else
  fail "the eval rule survives in gaspol-plan and gaspol-verify" \
    "gaspol-llm-test was deleted and its rule went with it"
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

# IDS-6 C3: the ONE conditional gate — plan-verifier is skipped only when the
# branch provably references no plan. Everything else stays unconditional.
if grep -qi 'no plan referenced by this branch' skills/gaspol-finish/SKILL.md; then
  pass "finish defines the no-plan skip for plan-verifier"
else
  fail "finish defines the no-plan skip for plan-verifier"
fi
if grep -qi 'record\|ledger' skills/gaspol-finish/SKILL.md && \
   grep -qi 'plan-verifier: skipped' skills/gaspol-finish/SKILL.md; then
  pass "the skip is recorded with its reason, never silent"
else
  fail "the skip is recorded with its reason, never silent"
fi

# The trim must NOT weaken /security-review. Security defects hide in boring
# diffs, and in a skills repository markdown IS the executed surface — "docs
# only" does not mean "cannot introduce a vulnerability".
# REMOVED in IDS-17 alongside its twin below. This one asserted /security-review
# was unconditional, and by the end of IDS-17 it passed for the worst possible
# reason: its unanchored substring 'every branch' matched the sentence in
# gaspol-finish/SKILL.md that explains why the review is NO LONGER unconditional
# ("running it on every branch spends time on branches where there is nothing to
# find"). A green assertion whose claim the file actively contradicts is the
# unanchored-substring failure test-gate-mutations.sh exists to catch. Its attack
# row lives there now.
# REMOVED in IDS-17: the assertion that no rule makes /security-review skippable.
#
# It was added in IDS-3 and reinforced by the knowledge note
# `narrow-and-record-conditional-audit-gates`, whose reason was sound on its own
# terms: in a skills repository markdown IS the executed surface, so a
# boring-looking diff can still carry a hole.
#
# The owner overrode it deliberately: not every ticket changes anything related
# to security, so running the review unconditionally on every branch spends time
# on branches where there is nothing to find. /security-review is now OFFERED
# from gaspol-finish -- still present, still blocking when it IS run and reports
# a finding. gaspol-execute Step 3.6 still runs it unconditionally on its own
# security-sensitive triggers, so the auth/secrets/endpoint/payment path is
# untouched.
#
# This comment is the record. Deleting an assertion with no explanation is how
# the next person restores it by accident, believing it was lost rather than
# retired. test-finish-fix-loop.sh asserts /security-review is still NAMED in
# gaspol-finish -- an offer nobody is shown would be a deletion wearing a
# different word.
if grep -qi 'security-review' skills/gaspol-finish/SKILL.md; then
  pass "/security-review is still named in gaspol-finish (offered, not deleted)"
else
  fail "/security-review is still named in gaspol-finish (offered, not deleted)"
fi

# The four MANDATORY chain steps stay unconditional. gaspol-learn left this list
# in IDS-17 -- it is offered now, and an offer is by definition conditional.
for step in gaspol-verify gaspol-review gaspol-sync-docs; do
  if grep -q "$step" skills/gaspol-finish/SKILL.md; then
    pass "chain step $step still present"
  else
    fail "chain step $step still present"
  fi
done

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
