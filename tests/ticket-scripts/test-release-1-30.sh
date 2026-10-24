#!/usr/bin/env bash
# IDS-21 Phase D: release metadata for v1.30.0 agrees everywhere a reader looks.
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
  [ "$v" = "1.30.0" ] && pass "$pj version is 1.30.0" || fail "$pj version is '$v', not 1.30.0"
done

changelog_top="$(grep -m1 '^## \[' CHANGELOG.md || true)"
case "$changelog_top" in
  *"1.30.0"*) pass "CHANGELOG top entry is 1.30.0" ;;
  *) fail "CHANGELOG top entry is '$changelog_top', not 1.30.0" ;;
esac
changelog_body="$(awk '/^## \[1\.30\.0\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
case "$changelog_body" in *IDS-21*) pass "CHANGELOG 1.30.0 entry names IDS-21" ;; *) fail "CHANGELOG 1.30.0 entry does not name IDS-21" ;; esac
# positive control: the previous entry must still be there, below the new one
grep -q '^## \[1\.29\.2\]' CHANGELOG.md && pass "CHANGELOG still carries the 1.29.2 entry" || fail "CHANGELOG lost the 1.29.2 entry"

readme_hits="$(grep -c '1\.30\.0' README.md || true)"
[ "$readme_hits" -ge 2 ] && pass "README names 1.30.0 (badge + release table)" || fail "README names 1.30.0 only $readme_hits time(s); need badge and release-table row"

footer="$(sed -n 's/^\*\*Version:\*\* //p' CLAUDE.md | head -1)"
[ "$footer" = "1.30.0" ] && pass "CLAUDE.md footer is 1.30.0" || fail "CLAUDE.md footer is '$footer', not 1.30.0"

section="$(awk '/^### .*IDS-21/{f=1;print;next} /^### /{f=0} f' CLAUDE.md)"
[ -n "$section" ] && pass "CLAUDE.md has an IDS-21 section" || fail "CLAUDE.md has no '### ... IDS-21' section"
for phrase in "second reader" "Nanti" "not measured"; do
  case "$section" in *"$phrase"*) pass "IDS-21 section states give-up: $phrase" ;; *) fail "IDS-21 section does not state give-up: $phrase" ;; esac
done

count_line="$(grep -m1 'skills + 4 agents' CLAUDE.md || true)"
case "$count_line" in
  *"16 development skills"*) pass "CLAUDE.md says 16 skills" ;;
  *) fail "CLAUDE.md skill-count line is: $count_line" ;;
esac
skill_dirs="$(find skills -maxdepth 1 -mindepth 1 -type d ! -name _shared | wc -l | tr -d ' ')"
[ "$skill_dirs" = "16" ] && pass "skills/ holds 16 skill directories" || fail "skills/ holds $skill_dirs skill directories, expected 16"

if [ "$FAILED" -gt 0 ]; then
  echo "test-release-1-30: $FAILED assertion(s) failed"
  exit 1
fi
echo "test-release-1-30: ALL PASS"
