#!/usr/bin/env bash
# test-skill-delegation.sh — TDD test for ticket IDS-2: gaspol-dev sheds the two
# skills that duplicate tooling the user already has, and absorbs the two review
# mechanics it was missing.
#
# One file, four functions, one per plan phase. A separate script per phase would
# triple the boilerplate for no added signal, so each phase appends its function
# here and registers it in the runner at the bottom.
#
#   test_design_delegation    (Phase A) — gaspol-design gone, design_audit.py relocated
#   test_security_delegation  (Phase B) — gaspol-security-review gone, /security-review wired
#   test_review_confidence    (Phase C) — gaspol-review Step 2.5 scores findings 0-100
#   test_docs_consistent      (Phase D) — counts, versions, and tables agree with reality
#
# Deliberately excludes docs/plans/ and CHANGELOG.md from every "no stale
# reference" sweep: those files are a record of what was true when written.
# Rewriting them to hide a deleted skill would be falsifying history, not
# cleaning up after it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

FAILURES=0

# pass <description>
pass() { echo "PASS: $1"; }

# fail <description> [detail...]
# Accumulates instead of exiting, so one run reports every broken assertion
# rather than only the first.
fail() {
  echo "FAIL: $1"
  shift
  [[ $# -gt 0 ]] && printf '%s\n' "$@" >&2
  FAILURES=$((FAILURES + 1))
}

# assert_grep <description> <pattern> <file...>
assert_grep() {
  local desc="$1"; shift
  local pattern="$1"; shift
  if grep -q -- "$pattern" "$@" 2>/dev/null; then pass "$desc"; else fail "$desc"; fi
}

# assert_absent_path <description> <path>
assert_absent_path() {
  local desc="$1" path="$2"
  if [[ -e "$path" ]]; then fail "$desc" "still present: $path"; else pass "$desc"; fi
}

# assert_present_path <description> <path>
assert_present_path() {
  local desc="$1" path="$2"
  if [[ -e "$path" ]]; then pass "$desc"; else fail "$desc" "missing: $path"; fi
}

# sweep_live <pattern>
# Prints every hit for <pattern> among TRACKED .md/.sh/.json files, minus three
# things that are allowed to mention a deleted skill:
#   docs/plans/  — the historical record; rewriting it would falsify history
#   CHANGELOG.md — same, it records what each release actually did
#   this file    — it necessarily contains the very strings it forbids
#
# Why `git ls-files` and not `grep -r`: BSD grep 2.6.0 (the macOS system grep)
# stops honouring --include once --exclude-dir is also passed. With both flags
# set it happily returned .diff files and 600KB of graphify-out/*.json AST
# cache. Feeding it an explicit tracked-file list sidesteps the bug entirely
# and gets the right semantics for free — graphify-out/ and .gaspol/ are
# gitignored, so they can never enter the list.
sweep_live() {
  local pattern="$1" files
  files="$(git ls-files -- '*.md' '*.sh' '*.json' \
           | grep -v -e '^docs/plans/' \
                     -e '^CHANGELOG\.md$' \
                     -e 'test-skill-delegation\.sh$' || true)"
  [[ -z "$files" ]] && return 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -n -- "$pattern" /dev/null 2>/dev/null || true
}

# assert_no_live_reference <description> <pattern>
assert_no_live_reference() {
  local desc="$1" pattern="$2" hits
  hits="$(sweep_live "$2")"
  if [[ -z "$hits" ]]; then pass "$desc"; else fail "$desc" "$hits"; fi
}

# self_check_sweep
# Guards sweep_live against silently matching nothing. If the file list or the
# grep breaks, every "no stale reference" assertion would pass VACUOUSLY — the
# exact failure mode this ticket exists to stamp out. Proves the sweep still
# sees a pattern that is definitely present in a non-excluded tracked file.
self_check_sweep() {
  if [[ -n "$(sweep_live 'gaspol-verify')" ]]; then
    pass "sweep machinery still sees live references (not vacuously empty)"
  else
    fail "sweep machinery still sees live references (not vacuously empty)" \
      "sweep_live returned nothing for a pattern known to be present — every 'no stale reference' PASS is meaningless"
  fi
}

# ---------------------------------------------------------------------------
# Phase A — design intelligence delegated to the ui-ux-pro-max plugin
# ---------------------------------------------------------------------------
# The skill directory goes; its one working part does not. design_audit.py is a
# 205-line stdlib-only STATIC source lint. ui-ux-pro-max's nearest equivalent
# (stack/scripts/design-audit.mjs) drives Chromium via Playwright against a
# RUNNING URL and lives inside a scaffold template, so it cannot stand in for a
# check that gaspol-verify Layer 4 runs offline, pre-merge, with no dev server.
# That asymmetry is why this test asserts the script MOVED rather than vanished.
test_design_delegation() {
  assert_absent_path "gaspol-design skill directory is gone" \
    "skills/gaspol-design"

  assert_present_path "design_audit.py relocated under gaspol-verify" \
    "skills/gaspol-verify/scripts/design_audit.py"

  if python3 skills/gaspol-verify/scripts/design_audit.py --help >/dev/null 2>&1; then
    pass "relocated design_audit.py still runs (--help exits 0)"
  else
    fail "relocated design_audit.py still runs (--help exits 0)"
  fi

  assert_no_live_reference "no live reference to skills/gaspol-design" \
    "skills/gaspol-design"

  # Kept by an explicit mid-execution decision: ui-ux-pro-max 2.13.0 ships NO
  # anti-slop opinion layer (zero "never use" lists) and no project-token /
  # KB-precedent reasoning rules. The plan originally claimed CLAUDE.md already
  # duplicated these -- it holds a two-line summary against 119 + 167 lines of
  # source. Deleting them would have been a silent net loss.
  assert_present_path "anti-ai-slop rules survived the deletion" \
    "skills/gaspol-verify/rules/anti-ai-slop.md"

  assert_present_path "gaspol reasoning rules survived the deletion" \
    "skills/gaspol-verify/rules/reasoning-gaspol.md"

  assert_grep "brainstorm Phase 3 still points at the surviving taste layer" \
    "anti-ai-slop.md" skills/gaspol-brainstorm/SKILL.md

  # The replacement must be reachable from BOTH routing tables, or the skill is
  # simply missing rather than delegated.
  assert_grep "session-start hook routes design work to ui-ux-pro-max" \
    "ui-ux-pro-max" hooks/session-start.sh

  assert_grep "using-gaspol routes design work to ui-ux-pro-max" \
    "ui-ux-pro-max" skills/using-gaspol/SKILL.md

  # Soft reference, not a hard dependency. plugin.json's `dependencies` field is
  # all-or-nothing: a yanked third-party marketplace entry would disable every
  # remaining gaspol skill, including tdd, debug, verify, and finish. Rejected
  # by the user on exactly those grounds.
  if grep -q '"dependencies"' .claude-plugin/plugin.json 2>/dev/null; then
    fail "plugin.json declares no hard dependency on ui-ux-pro-max" \
      "plugin.json gained a dependencies key — all-or-nothing failure mode"
  else
    pass "plugin.json declares no hard dependency on ui-ux-pro-max"
  fi

  # The gate must not weaken as a side effect of moving the script.
  assert_grep "gaspol-verify Layer 4 still fails below score 60" \
    "score <60" skills/gaspol-verify/SKILL.md
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
self_check_sweep
test_design_delegation

if [[ "$FAILURES" -gt 0 ]]; then
  echo "test-skill-delegation: $FAILURES assertion(s) failed" >&2
  exit 1
fi

echo "PASS: test-skill-delegation"
