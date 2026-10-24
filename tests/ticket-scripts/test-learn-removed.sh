#!/usr/bin/env bash
# IDS-21: gaspol-learn was deleted. The failure this guards is a deleted skill that
# still has a routing row, a hook line or a test list naming it: the router would
# send work to a skill that no longer exists.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
SELF="tests/ticket-scripts/test-learn-removed.sh"
FAILS=0
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS + 1)); }

# (a) the directory is gone
[ -e skills/gaspol-learn ] && fail "skills/gaspol-learn still exists"

# (b) no live file names it
hits="$(grep -rln "gaspol-learn" skills agents hooks rules tests README.md docs/*.md 2>/dev/null | grep -v -x "$SELF")"
if [ -n "$hits" ]; then
  while IFS= read -r f; do fail "$f still mentions gaspol-learn"; done <<< "$hits"
fi

# (c) CLAUDE.md has no table row for it
row="$(grep -nE '^\| `skills/gaspol-learn |^\| Capture patterns after shipping \|' CLAUDE.md)"
[ -n "$row" ] && fail "CLAUDE.md still has a gaspol-learn table row: $row"

# (d) no capture route in the router surfaces
for f in hooks/session-start.sh skills/using-gaspol/SKILL.md; do
  r="$(grep -niE 'capture patterns after shipping' "$f")"
  [ -n "$r" ] && fail "$f still lists a capture-patterns-after-shipping route"
done

# (e) positive control: the remaining KB writers exist and still write to the KB
for s in gaspol-adr gaspol-research; do
  if [ ! -f "skills/$s/SKILL.md" ]; then
    fail "skills/$s/SKILL.md missing, test would pass on an empty repo"
  else
    w="$(grep -ciE 'KB_ROOT|knowledge' "skills/$s/SKILL.md")"
    [ "${w:-0}" -gt 0 ] || fail "skills/$s no longer mentions writing to the KB"
  fi
done

if [ "$FAILS" -gt 0 ]; then echo "test-learn-removed: $FAILS failure(s)" >&2; exit 1; fi
echo "test-learn-removed: PASS"
