#!/usr/bin/env bash
# IDS-22 Phase F: release metadata for v1.31.0 agrees everywhere a reader looks.
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
  [ "$v" = "1.31.0" ] && pass "$pj version is 1.31.0" || fail "$pj version is '$v', not 1.31.0"
done

changelog_top="$(grep -m1 '^## \[' CHANGELOG.md || true)"
case "$changelog_top" in
  *"1.31.0"*) pass "CHANGELOG top entry is 1.31.0" ;;
  *) fail "CHANGELOG top entry is '$changelog_top', not 1.31.0" ;;
esac
changelog_body="$(awk '/^## \[1\.31\.0\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
case "$changelog_body" in *IDS-22*) pass "CHANGELOG 1.31.0 entry names IDS-22" ;; *) fail "CHANGELOG 1.31.0 entry does not name IDS-22" ;; esac
# positive control: the previous entry must still be there, below the new one
grep -q '^## \[1\.30\.0\]' CHANGELOG.md && pass "CHANGELOG still carries the 1.30.0 entry" || fail "CHANGELOG lost the 1.30.0 entry"

readme_hits="$(grep -c '1\.31\.0' README.md || true)"
[ "$readme_hits" -ge 2 ] && pass "README names 1.31.0 (badge + release table)" || fail "README names 1.31.0 only $readme_hits time(s); need badge and release-table row"

footer="$(sed -n 's/^\*\*Version:\*\* //p' CLAUDE.md | head -1)"
[ "$footer" = "1.31.0" ] && pass "CLAUDE.md footer is 1.31.0" || fail "CLAUDE.md footer is '$footer', not 1.31.0"

section="$(awk '/^### .*IDS-22/{f=1;print;next} /^### /{f=0} f' CLAUDE.md)"
[ -n "$section" ] && pass "CLAUDE.md has an IDS-22 section" || fail "CLAUDE.md has no '### ... IDS-22' section"
for phrase in "plan-waves" "Opus review" "does NOT close"; do
  case "$section" in *"$phrase"*) pass "IDS-22 section states: $phrase" ;; *) fail "IDS-22 section does not state: $phrase" ;; esac
done

arch_row="$(grep -m1 'skills/gaspol-plan/scripts/plan-waves' CLAUDE.md || true)"
[ -n "$arch_row" ] && pass "CLAUDE.md Architecture table names plan-waves" || fail "CLAUDE.md Architecture table has no plan-waves row"

skill_dirs="$(find skills -maxdepth 1 -mindepth 1 -type d ! -name _shared | wc -l | tr -d ' ')"
[ "$skill_dirs" = "16" ] && pass "skills/ still holds 16 skill directories" || fail "skills/ holds $skill_dirs skill directories, expected 16"

if [ "$FAILED" -gt 0 ]; then
  echo "test-release-1-31: $FAILED assertion(s) failed"
  exit 1
fi
echo "test-release-1-31: ALL PASS"
