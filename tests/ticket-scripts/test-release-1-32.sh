#!/usr/bin/env bash
# IDS-23 Phase J: release metadata for v1.32.0 agrees everywhere a reader looks.
# Supersedes test-release-1-31.sh (a version pin is replaced by the next one, not stacked).
# Values are captured into variables first (pipefail-safe), then compared.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

FAILED=0
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
pass() { echo "PASS: $1"; }

ver_of() { sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1; }

for pj in .claude-plugin/plugin.json plugin.json; do
  v="$(ver_of "$pj")"
  [ "$v" = "1.32.0" ] && pass "$pj version is 1.32.0" || fail "$pj version is $v, expected 1.32.0"
done

changelog_top="$(grep -m1 '^## \[' CHANGELOG.md || true)"
case "$changelog_top" in
  *"1.32.0"*) pass "CHANGELOG top entry is 1.32.0" ;;
  *) fail "CHANGELOG top entry is '$changelog_top', not 1.32.0" ;;
esac
changelog_body="$(awk '/^## \[1\.32\.0\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
case "$changelog_body" in *IDS-23*) pass "CHANGELOG 1.32.0 entry names IDS-23" ;; *) fail "CHANGELOG 1.32.0 entry does not name IDS-23" ;; esac
# positive control: the previous entry must still be there, below the new one
grep -q '^## \[1\.31\.0\]' CHANGELOG.md && pass "CHANGELOG still carries the 1.31.0 entry" || fail "CHANGELOG lost the 1.31.0 entry"

readme_hits="$(grep -c '1\.32\.0' README.md || true)"
[ "$readme_hits" -ge 2 ] && pass "README names 1.32.0 (badge + release table)" || fail "README names 1.32.0 only $readme_hits time(s); need badge and release-table row"
current_rows="$(grep -c '(current)' README.md || true)"
[ "$current_rows" = "1" ] && pass "README marks exactly one row (current)" || fail "README has $current_rows '(current)' rows, expected 1"

footer="$(sed -n 's/^\*\*Version:\*\* //p' CLAUDE.md | head -1)"
[ "$footer" = "1.32.0" ] && pass "CLAUDE.md footer is 1.32.0" || fail "CLAUDE.md footer is '$footer', not 1.32.0"

section="$(awk '/^### .*IDS-23/{f=1;print;next} /^### /{f=0} f' CLAUDE.md)"
[ -n "$section" ] && pass "CLAUDE.md has an IDS-23 section" || fail "CLAUDE.md has no '### ... IDS-23' section"
for phrase in "20,000" "builder check" "verification-lint" "does NOT close"; do
  case "$section" in *"$phrase"*) pass "IDS-23 section states: $phrase" ;; *) fail "IDS-23 section does not state: $phrase" ;; esac
done

for token in "skills/gaspol-plan/scripts/verification-lint" "builder-check-prompt.md" "test-skill-size.sh" "test-skill-references.sh" "test-builder-check.sh" "test-verification-lint.sh"; do
  grep -q "$token" CLAUDE.md && pass "CLAUDE.md Architecture names $token" || fail "CLAUDE.md Architecture does not name $token"
done

# live-behaviour sentences must not still describe Phase 6 as a self-review
stale="$(grep -c 'spec self-review' CLAUDE.md || true)"
[ "$stale" = "0" ] && pass "CLAUDE.md has no 'spec self-review' sentence" || fail "CLAUDE.md still has $stale 'spec self-review' mention(s)"

skill_dirs="$(find skills -maxdepth 1 -mindepth 1 -type d ! -name _shared | wc -l | tr -d ' ')"
[ "$skill_dirs" = "16" ] && pass "skills/ still holds 16 skill directories" || fail "skills/ holds $skill_dirs skill directories, expected 16"

if [ "$FAILED" -gt 0 ]; then
  echo "test-release-1-32: $FAILED assertion(s) failed"
  exit 1
fi
echo "test-release-1-32: ALL PASS"
