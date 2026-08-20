#!/usr/bin/env bash
# test-naming-convention.sh — TDD test for the date-prefixed spec/plan filename
# convention (ticket IDS-1 Phase C): docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-{spec,plan}.md
# documented consistently across skills/agents, and no stale forms left behind.
#
# Later phases (D, E, F) of this plan append more assertions here — ledger
# format, detect-stack wiring, CLAUDE.md sync — reusing the assert_grep /
# assert_not_grep helpers below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

FAILURES=0

# assert_grep <description> <pattern> <file...>
# PASS/FAIL wrapper around `grep -q`. Accumulates failures instead of exiting
# on the first one, so a single run reports every broken assertion.
assert_grep() {
  local desc="$1"; shift
  local pattern="$1"; shift
  if grep -q -- "$pattern" "$@" 2>/dev/null; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    FAILURES=$((FAILURES + 1))
  fi
}

# assert_not_grep <description> <pattern> <path...>
# Inverse of assert_grep — passes when the pattern is ABSENT. Used for
# stale-form regression checks (e.g. no leftover "no date prefix" prose).
assert_not_grep() {
  local desc="$1"; shift
  local pattern="$1"; shift
  local hits
  hits="$(grep -rni -- "$pattern" "$@" 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    printf '%s\n' "$hits" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

echo "test-naming-convention: checking dated spec/plan filename convention..."

assert_grep "brainstorm writes docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md" \
  'YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md' \
  skills/gaspol-brainstorm/SKILL.md

assert_grep "plan writes docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md" \
  'YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md' \
  skills/gaspol-plan/SKILL.md

assert_grep "plan looks up its spec by glob, not reconstructed filename" \
  'docs/plans/\*-<TICKET>-\*-spec.md' \
  skills/gaspol-plan/SKILL.md

assert_grep "plan STOPs on more than one glob match instead of picking one" \
  'STOP and ask the user which spec' \
  skills/gaspol-plan/SKILL.md

assert_grep "plan documents the 7-file pre-ticket migration note" \
  '2026-04-17-gaspol-improvements.md' \
  skills/gaspol-plan/SKILL.md

assert_grep "plan-verifier references the dated plan path" \
  'YYYY-MM-DD-<TICKET>-<topic>-plan.md' \
  agents/plan-verifier.md

assert_grep "finish references the dated plan path" \
  'YYYY-MM-DD-<TICKET>-<topic>-plan.md' \
  skills/gaspol-finish/SKILL.md

assert_grep "plan-verification.md locating-the-plan section uses the dated ticketed form" \
  'YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md' \
  skills/gaspol-verify/plan-verification.md

assert_not_grep "no leftover bare docs/plans/<TICKET>- form (missing date prefix)" \
  'docs/plans/<TICKET>-' \
  skills/ agents/

assert_not_grep "no leftover pre-ticket YYYY-MM-DD-feature-name form" \
  'YYYY-MM-DD-feature-name' \
  skills/

assert_not_grep "no leftover \"no date prefix\" claim anywhere" \
  'no date prefix' \
  skills/

echo "test-naming-convention: checking PROGRESS-<TICKET>.md ledger format (Phase D)..."

assert_grep "gaspol-plan derives the new PROGRESS-<TICKET>.md ledger path" \
  'PROGRESS-<TICKET>.md' \
  skills/gaspol-plan/SKILL.md

assert_grep "gaspol-plan documents the [>] in-progress checklist marker" \
  '\[>\]' \
  skills/gaspol-plan/SKILL.md

assert_grep "gaspol-plan documents the [~] cancelled/skipped checklist marker" \
  '\[~\]' \
  skills/gaspol-plan/SKILL.md

assert_grep "gaspol-plan states the '## Log' is always the last block rule" \
  '## Log.*is ALWAYS the last block' \
  skills/gaspol-plan/SKILL.md

assert_grep "gaspol-plan creates the ledger AT PLAN-WRITE TIME" \
  'plan-write time' \
  skills/gaspol-plan/SKILL.md

assert_grep "gaspol-execute documents backward-compat read for old ledger paths" \
  'older ledgers' \
  skills/gaspol-execute/SKILL.md

assert_grep "gaspol-execute documents the tick-then-append per-phase gate" \
  'tick.*then.*append\|tick-then-append' \
  skills/gaspol-execute/SKILL.md

assert_grep "checkpoint-template documents the tick-then-append gate" \
  'tick.*then.*append\|tick-then-append' \
  skills/gaspol-execute/checkpoint-template.md

assert_grep "gaspol-parallel documents the tick-then-append per-task gate" \
  'tick.*then.*append\|tick-then-append' \
  skills/gaspol-parallel/SKILL.md

assert_grep "gaspol-parallel references the new PROGRESS-<TICKET>.md ledger path" \
  'PROGRESS-<TICKET>.md' \
  skills/gaspol-parallel/SKILL.md

# Case-sensitive check (assert_not_grep is deliberately case-insensitive, which would
# collide with the correct new form `progress/PROGRESS-<TICKET>.md`) — the stale lowercase
# derivation `.gaspol/progress/progress-<TICKET>.md` must be gone everywhere.
echo "-- checking for leftover lowercase progress/progress- derivation --"
if grep -rn --include='*.md' 'progress/progress-' skills/ agents/ 2>/dev/null; then
  echo "FAIL: no leftover lowercase progress/progress-<TICKET> derivation anywhere"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS: no leftover lowercase progress/progress-<TICKET> derivation anywhere"
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "test-naming-convention: $FAILURES assertion(s) failed" >&2
  exit 1
fi

echo "PASS: test-naming-convention"
