#!/usr/bin/env bash
# Release metadata for v1.32.1 (stop-done-gate) agrees everywhere a reader looks.
# Supersedes test-release-1-32.sh (a version pin is replaced by the next one, not stacked).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
FAILED=0
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
pass() { echo "PASS: $1"; }
ver_of() { sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1; }

for pj in .claude-plugin/plugin.json plugin.json; do
  v="$(ver_of "$pj")"; [ "$v" = "1.32.1" ] && pass "$pj version is 1.32.1" || fail "$pj version is $v"
done
mv="$(python3 -c 'import json;print([p["version"] for p in json.load(open("../gaspol-one/.claude-plugin/marketplace.json"))["plugins"] if p["name"]=="gaspol-dev"][0])' 2>/dev/null)"
[ "$mv" = "1.32.1" ] && pass "marketplace entry is 1.32.1" || fail "marketplace entry is '$mv'"
top="$(grep -m1 '^## \[' CHANGELOG.md || true)"
case "$top" in *"1.32.1"*) pass "CHANGELOG top entry is 1.32.1" ;; *) fail "CHANGELOG top is '$top'" ;; esac
body="$(awk '/^## \[1\.32\.1\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
case "$body" in *stop-done-gate*) pass "CHANGELOG 1.32.1 names stop-done-gate" ;; *) fail "CHANGELOG 1.32.1 does not name stop-done-gate" ;; esac
grep -q '^## \[1\.32\.0\]' CHANGELOG.md && pass "CHANGELOG still carries 1.32.0" || fail "CHANGELOG lost 1.32.0"
grep -q 'badge/version-1.32.1' README.md && pass "README badge 1.32.1" || fail "README badge"
grep -q '| \*\*1.32.1\*\* (current)' README.md && pass "README release row 1.32.1 (current)" || fail "README release row"
[ "$(grep -c '(current)' README.md || true)" = "1" ] && pass "README has exactly one (current)" || fail "README (current) count"
[ "$(sed -n 's/^\*\*Version:\*\* //p' CLAUDE.md | head -1)" = "1.32.1" ] && pass "CLAUDE.md footer 1.32.1" || fail "CLAUDE.md footer"
grep -q 'hooks/stop-done-gate.sh' CLAUDE.md && pass "CLAUDE.md Architecture names stop-done-gate" || fail "CLAUDE.md Architecture"
[ "$FAILED" -gt 0 ] && { echo "test-release-1-32-1: $FAILED failed"; exit 1; }
echo "test-release-1-32-1: ALL PASS"
