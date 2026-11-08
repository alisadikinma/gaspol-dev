#!/usr/bin/env bash
# Release metadata for v1.33.1 (ledger grouped by wave; gaspol-dbpatch from 1.33.0) agrees everywhere a reader looks,
# and the skill itself is registered, generic (public plugin) and carries its eight rules.
# Supersedes test-release-1-33-0.sh (a version pin is replaced by the next one, not stacked).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
FAILED=0
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
pass() { echo "PASS: $1"; }
V="1.33.2"
ver_of() { sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1; }

for pj in .claude-plugin/plugin.json plugin.json; do
  v="$(ver_of "$pj")"; [ "$v" = "$V" ] && pass "$pj version is $V" || fail "$pj version is $v"
done
mv="$(python3 -c 'import json;print([p["version"] for p in json.load(open("../gaspol-one/.claude-plugin/marketplace.json"))["plugins"] if p["name"]=="gaspol-dev"][0])' 2>/dev/null)"
[ "$mv" = "$V" ] && pass "marketplace entry is $V" || fail "marketplace entry is '$mv'"
grep -q "| gaspol-dev](https://github.com/alisadikinma/gaspol-dev) | $V |" ../gaspol-one/README.md 2>/dev/null \
  || grep -qE "gaspol-dev\]\(https://github.com/alisadikinma/gaspol-dev\) \| $V \|" ../gaspol-one/README.md \
  && pass "gaspol-one README table is $V" || fail "gaspol-one README table version"
top="$(grep -m1 '^## \[' CHANGELOG.md || true)"
case "$top" in *"$V"*) pass "CHANGELOG top entry is $V" ;; *) fail "CHANGELOG top is '$top'" ;; esac
body="$(awk '/^## \[1\.33\.0\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
case "$body" in *gaspol-dbpatch*) pass "CHANGELOG $V names gaspol-dbpatch" ;; *) fail "CHANGELOG $V does not name gaspol-dbpatch" ;; esac
grep -q '^## \[1\.32\.2\]' CHANGELOG.md && pass "CHANGELOG still carries 1.32.2" || fail "CHANGELOG lost 1.32.2"
grep -q "badge/version-$V" README.md && pass "README badge $V" || fail "README badge"
grep -q "| \*\*$V\*\* (current)" README.md && pass "README release row $V (current)" || fail "README release row"
[ "$(grep -c '(current)' README.md || true)" = "1" ] && pass "README has exactly one (current)" || fail "README (current) count"
[ "$(sed -n 's/^\*\*Version:\*\* //p' CLAUDE.md | head -1)" = "$V" ] && pass "CLAUDE.md footer $V" || fail "CLAUDE.md footer"

S="skills/gaspol-dbpatch/SKILL.md"
if [ ! -f "$S" ]; then
  fail "$S: No such file or directory"
else
  pass "$S exists"
  head -1 "$S" | grep -qx -- '---' && grep -q '^name: gaspol-dbpatch$' "$S" && pass "frontmatter name" || fail "frontmatter name"
  grep -m1 '^description: "Use when fixing data already stored in a database' "$S" >/dev/null && pass "description starts with trigger" || fail "description trigger"
  # shellcheck disable=SC2016
  for needle in 'read-only' 'root cause' '--apply' 'one transaction' 'idempotent' 'timeout' 'back up' 'copy of the data' 'SAME query' 'gaspol-debug' 'explicit instruction' 'undefined' 'time zone' 'cache'; do
    grep -qi -- "$needle" "$S" && pass "skill carries '$needle'" || fail "skill lacks '$needle'"
  done
  if grep -rniE "irn|indusia|alisadikin|/Users/|batam|wib|plane" skills/gaspol-dbpatch >/dev/null; then
    fail "public-plugin gate: skill names a project, path, zone or private rule"
  else pass "public-plugin gate clean"; fi
fi
for f in hooks/session-start.sh skills/using-gaspol/SKILL.md README.md CLAUDE.md; do
  grep -q 'gaspol-dbpatch' "$f" && pass "$f registers gaspol-dbpatch" || fail "$f does not register gaspol-dbpatch"
done
[ "$FAILED" -gt 0 ] && { echo "test-release-1-33-0: $FAILED failed"; exit 1; }
echo "test-release-1-33-0: ALL PASS"
