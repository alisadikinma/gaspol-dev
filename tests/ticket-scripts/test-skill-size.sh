#!/usr/bin/env bash
# test-skill-size.sh — no SKILL.md may reach 20,000 bytes (IDS-23).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so anything
# past the cut vanishes. Bytes (wc -c) are stricter than characters, so a pass here is a pass
# there. The ceiling applies to every skill with no exception: the only parameter of check_dir
# is the directory, and the controls use it to point at a fixture tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIMIT=20000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# check_dir DIR — prints one FAIL line per DIR/*/SKILL.md of LIMIT bytes or more; returns 1 if any.
check_dir() {
  local dir="$1" f bytes bad=0
  for f in "$dir"/*/SKILL.md; do
    [ -f "$f" ] || continue
    bytes="$(wc -c < "$f" | tr -d ' ')"
    if [ "$bytes" -ge "$LIMIT" ]; then
      echo "FAIL: ${f#"$dir"/} is $bytes bytes, ceiling is under $LIMIT" >&2
      bad=1
    fi
  done
  return "$bad"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_skill() { # make_skill TREE NAME BYTES
  mkdir -p "$1/$2"
  head -c "$3" /dev/zero | tr '\0' 'a' > "$1/$2/SKILL.md"
}

# Positive controls: the checker must see the boundary, or a green run proves nothing.
make_skill "$TMP/c20001" gaspol-x 20001
make_skill "$TMP/c20000" gaspol-x 20000
make_skill "$TMP/c19999" gaspol-x 19999

if check_dir "$TMP/c20001" 2>/dev/null; then
  fail "control: 20,001-byte SKILL.md was accepted"
else
  pass "control: 20,001-byte SKILL.md fails"
fi
if check_dir "$TMP/c20000" 2>/dev/null; then
  fail "control: 20,000-byte SKILL.md was accepted"
else
  pass "control: 20,000-byte SKILL.md fails"
fi
if check_dir "$TMP/c19999" 2>/dev/null; then
  pass "control: 19,999-byte SKILL.md passes"
else
  fail "control: 19,999-byte SKILL.md was rejected"
fi

# The real check.
if check_dir "$REPO_ROOT/skills"; then
  pass "every skills/*/SKILL.md is under $LIMIT bytes"
else
  FAILURES=$((FAILURES + 1))
fi

# Headroom, for a human reading the log.
echo "Five largest SKILL.md files (bytes):"
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  echo "$(wc -c < "$f" | tr -d ' ') ${f#"$REPO_ROOT"/}"
done | sort -rn | head -5

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s)" >&2
  exit 1
fi
echo "ALL PASS"
