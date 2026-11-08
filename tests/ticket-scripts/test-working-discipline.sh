#!/usr/bin/env bash
# test-working-discipline.sh — asserts the working-discipline rule file exists,
# carries both rules and the boundary with the Completeness Ladder, and is wired
# into the session hook and the implementer prompt (IDS-24 Phase C).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RULE="$REPO_ROOT/skills/_shared/working-discipline.md"
HOOK="$REPO_ROOT/hooks/session-start.sh"
IMPL="$REPO_ROOT/skills/gaspol-execute/implementer-prompt.md"
LADDER="$REPO_ROOT/skills/_shared/completeness-ladder.md"

# hooks/session-start.sh was 4,357 bytes before IDS-24; the block may add 450.
HOOK_MAX=$((4357 + 450))

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
has()  { grep -qiF -- "$2" "$1" || fail "$3"; }
lacks(){ if grep -qF -- "$2" "$1"; then fail "$3"; fi; return 0; }

[ -f "$RULE" ] || fail "skills/_shared/working-discipline.md missing"
pass "rule file exists"

has "$RULE" "Surgical changes" "heading 'Surgical changes' missing"
has "$RULE" "Think before coding" "heading 'Think before coding' missing"
has "$RULE" "imports, variables and functions that YOUR change" "own-orphan removal rule missing"
has "$RULE" "unrelated dead code is reported" "report-not-delete sentence missing"
has "$RULE" "AskUserQuestion" "stop-and-ask via AskUserQuestion missing"
has "$RULE" "skills/_shared/completeness-ladder.md" "boundary does not name the Completeness Ladder file"
has "$RULE" "limits code OUTSIDE the task" "boundary: Surgical limits code OUTSIDE the task missing"
has "$RULE" "INSIDE it" "boundary: Ladder demands depth INSIDE it missing"
lacks "$RULE" "Simplicity First" "rule file must not contain 'Simplicity First'"
pass "rule file content"

has "$HOOK" "skills/_shared/working-discipline.md" "session-start.sh does not point at the rule file"
has "$IMPL" "skills/_shared/working-discipline.md" "implementer-prompt.md does not point at the rule file"
pass "wiring"

size=$(wc -c < "$HOOK" | tr -d ' ')
[ "$size" -le "$HOOK_MAX" ] || fail "session-start.sh is $size bytes, ceiling $HOOK_MAX"
pass "hook size $size <= $HOOK_MAX"

git -C "$REPO_ROOT" show HEAD:skills/_shared/completeness-ladder.md | cmp -s - "$LADDER" \
    || fail "completeness-ladder.md differs from HEAD"
pass "completeness-ladder.md untouched"

# Positive control: the helper must fail on a file lacking the string.
tmp="$(mktemp)"; echo "nothing relevant" > "$tmp"
if ( has "$tmp" "Surgical changes" "control" ) 2>/dev/null; then
    rm -f "$tmp"; fail "positive control: helper passed on a file lacking the string"
fi
rm -f "$tmp"
pass "positive control"

bash -n "$HOOK" || fail "bash -n hooks/session-start.sh failed"
count=$(bash "$HOOK" | grep -c "WORKING DISCIPLINE (always-on):")
[ "$count" -eq 1 ] || fail "hook prints the WORKING DISCIPLINE block $count times, expected 1"
pass "hook syntax and single block"

echo "test-working-discipline: all passed"
