#!/usr/bin/env bash
# test-skill-references.sh — reference files and the pointers to them must match (IDS-23).
#
# A trimmed skill moves detail into skills/<name>/references/. Two things can then rot silently:
# a SKILL.md pointing at a reference file that does not exist (the detail is lost), and a
# reference file no SKILL.md names (nobody will ever read it). Both fail here, for every skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# check_refs DIR — checks every DIR/*/ skill; prints one FAIL line per problem; returns 1 if any.
check_refs() {
  local dir="$1" skill_dir name md refs_dir ptrs p f rel bad=0
  for skill_dir in "$dir"/*/; do
    skill_dir="${skill_dir%/}"
    name="$(basename "$skill_dir")"
    md="$skill_dir/SKILL.md"
    [ -f "$md" ] || continue
    refs_dir="$skill_dir/references"

    # (a) every pointer resolves. grep exits 1 on no match, so capture first and tolerate it.
    ptrs="$(grep -oE 'references/[A-Za-z0-9._/-]+\.md' "$md" || true)"
    if [ -n "$ptrs" ]; then
      while IFS= read -r p; do
        if [ ! -f "$skill_dir/$p" ]; then
          echo "FAIL: skills/$name names $p, which does not exist" >&2
          bad=1
        fi
      done <<EOF
$(printf '%s\n' "$ptrs" | sort -u)
EOF
    fi

    # (b) every reference file is named by SKILL.md.
    if [ -d "$refs_dir" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        rel="references/${f#"$refs_dir"/}"
        if ! grep -qF -- "$rel" "$md"; then
          echo "FAIL: skills/$name/$rel is an orphan: SKILL.md never names it" >&2
          bad=1
        fi
      done <<EOF
$(find "$refs_dir" -type f | sort)
EOF
    fi
  done
  return "$bad"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixtures.
mkdir -p "$TMP/dangling/gaspol-a"
printf 'Detail lives in `references/missing.md`.\n' > "$TMP/dangling/gaspol-a/SKILL.md"

mkdir -p "$TMP/orphan/gaspol-a/references"
printf 'No pointers here.\n' > "$TMP/orphan/gaspol-a/SKILL.md"
printf 'x\n' > "$TMP/orphan/gaspol-a/references/orphan.md"

mkdir -p "$TMP/clean/gaspol-a/references"
printf 'Read references/detail.md when needed.\n' > "$TMP/clean/gaspol-a/SKILL.md"
printf 'x\n' > "$TMP/clean/gaspol-a/references/detail.md"

mkdir -p "$TMP/bare/gaspol-a"
printf 'No references at all.\n' > "$TMP/bare/gaspol-a/SKILL.md"

if check_refs "$TMP/dangling" 2>/dev/null; then
  fail "control: dangling pointer was accepted"
else
  pass "control: dangling pointer fails"
fi
if check_refs "$TMP/orphan" 2>/dev/null; then
  fail "control: orphan reference file was accepted"
else
  pass "control: orphan reference file fails"
fi
if check_refs "$TMP/clean" 2>/dev/null; then
  pass "control: clean skill passes"
else
  fail "control: clean skill was rejected"
fi
if check_refs "$TMP/bare" 2>/dev/null; then
  pass "control: skill with no references/ and no pointers passes"
else
  fail "control: skill with no references/ was rejected"
fi

# Vacuity guard: the real scan must have something to scan.
REAL_COUNT="$(find "$REPO_ROOT"/skills/*/references -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$REAL_COUNT" -ge 15 ]; then
  pass "real tree has $REAL_COUNT reference files (>= 15)"
else
  fail "real tree has only $REAL_COUNT reference files, expected at least 15"
fi

# The real check.
if check_refs "$REPO_ROOT/skills"; then
  pass "every reference pointer resolves and every reference file is named"
else
  FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s)" >&2
  exit 1
fi
echo "ALL PASS"
