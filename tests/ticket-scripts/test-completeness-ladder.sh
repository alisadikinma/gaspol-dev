#!/usr/bin/env bash
# test-completeness-ladder.sh — asserts the Completeness Ladder replaced the
# Laziness Ladder everywhere it was live (IDS-10 Phase B).
#
# v1.9 made the ponytail Laziness Ladder gaspol's always-on default coding
# stance: rung 1 was "does this need to exist at all -> skip", and the rules were
# "fewest files possible, shortest working diff wins". Its fidelity boundary kept
# the output REAL; nothing kept it COMPLETE, and shallow work breaches no
# boundary. The reference stack the user named (gstack/ETHOS.md) takes the
# opposite position and names the ladder's own rules as anti-patterns:
# "Choose B -- it covers 90% with less code" and "let's defer tests to a
# follow-up PR". Both stances cannot be the default. This asserts which one is.
#
# The regression that actually matters is the LAST block: a stance that is
# rewritten in the shared file but left standing in the session hook or in one
# of the three gates is a stance the agent still reads every session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LADDER="$REPO_ROOT/skills/_shared/completeness-ladder.md"
HOOK="$REPO_ROOT/hooks/session-start.sh"
PLAN="$REPO_ROOT/skills/gaspol-plan/SKILL.md"
EXEC="$REPO_ROOT/skills/gaspol-execute/SKILL.md"
IMPL="$REPO_ROOT/skills/gaspol-execute/implementer-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }
lacks(){ grep -qi -- "$2" "$1" && fail "$3"; return 0; }

echo "test-completeness-ladder: the shared stance file exists and is the only source..."

[ -f "$LADDER" ] || fail "skills/_shared/completeness-ladder.md is missing — the stance has no single source"
[ -f "$REPO_ROOT/skills/_shared/laziness-ladder.md" ] \
    && fail "skills/_shared/laziness-ladder.md still exists — two default stances is no default at all"

echo "test-completeness-ladder: all six rungs are present..."

has "$LADDER" "happy path"        "rung 1 (the happy path, real integration) missing"
has "$LADDER" "error path"        "rung 2 (every error path that can actually happen) missing"
has "$LADDER" "edge case"         "rung 3 (edge cases the input space allows) missing"
has "$LADDER" "test"              "rung 4 (the tests that prove the rungs above) missing"
has "$LADDER" "observability"     "rung 5 (observability for the 3am debugger) missing"
has "$LADDER" "walk down"         "the ladder must be walked DOWN doing every rung, not stopped at the first that holds"

echo "test-completeness-ladder: the ladder is walked, never short-circuited..."

# The retired rules may still be NAMED — as the quoted history of why the stance
# changed, and as Red Flag rows. What must not survive is any line that still
# ISSUES them. A blunt `lacks` cannot tell those apart and would force the file
# to stop explaining itself, so the assertion is: every occurrence sits inside a
# quotation ("), a table row (|), or a line marking it deleted/retired.
quoted_only() {
    local file="$1" pattern="$2" msg="$3" line
    while IFS= read -r line; do
        case "$line" in
            *'"'*|*'|'*|*Deleted*|*deleted*|*retired*|*"was the old one"*) continue ;;
            *) fail "$msg — issued as a live instruction: $line" ;;
        esac
    done < <(grep -iE -- "$pattern" "$file" || true)
}

quoted_only "$LADDER" "stop at the first rung" \
    "'stop at the first rung that holds' is the laziness ladder's control flow — completeness does every rung"
quoted_only "$LADDER" "shortest .*diff wins" \
    "'shortest diff wins' is a retired rule"
quoted_only "$LADDER" "fewest files possible" \
    "'fewest files possible' is a retired rule"

echo "test-completeness-ladder: the one legitimate stop is genuinely unrelated work..."

has "$LADDER" "unrelated work" \
    "the ladder must name its only stopping condition: genuinely unrelated work"
has "$LADDER" "separate scope" \
    "unrelated work must be flagged as separate scope, not used as a reason to ship a shortcut"

echo "test-completeness-ladder: the Reuse Rule survived from ponytail rungs 2-4..."

has "$LADDER" "reuse rule"  "the Reuse Rule (stdlib > native > installed dep) must survive — it is an implementation rule, not a scope cut"
has "$LADDER" "stdlib"      "Reuse Rule must name stdlib"
has "$LADDER" "already-installed" "Reuse Rule must name an already-installed dependency"
has "$LADDER" "one implementation" \
    "the anti-abstraction rule (no interface with one implementation) must survive — it cuts cleverness, not coverage"

echo "test-completeness-ladder: the scope-cut rationalizations are Red Flags..."

has "$LADDER" "90%"                 "Red Flag missing: '90% coverage with less code is the better trade'"
has "$LADDER" "follow-up"           "Red Flag missing: 'tests in a follow-up PR'"
has "$LADDER" "YAGNI"               "Red Flag missing: YAGNI applies to unrequested features, never to a requested one's completeness"
has "$LADDER" "didn't ask\|did not ask" \
    "Red Flag missing: 'the user didn't ask for the error path'"

echo "test-completeness-ladder: fidelity is unchanged — completeness never excuses a shortcut either..."

has "$LADDER" "Iron Law"       "the ladder must still defer to the 3 Iron Laws"
has "$LADDER" "placeholder"    "the ladder must still forbid placeholder data"

echo "test-completeness-ladder: every live enforcement point carries the new stance..."

has "$HOOK" "COMPLETENESS LADDER" "the session-start hook still injects the old stance"
has "$HOOK" "completeness-ladder.md" "the hook must point at the shared file by name"
has "$PLAN" "Completeness Gate"   "gaspol-plan still gates on the laziness ladder"
has "$EXEC" "Completeness Gate"   "gaspol-execute still gates on the laziness ladder"
has "$IMPL" "Completeness"        "implementer-prompt.md still dispatches subagents with the laziness ladder"

echo "test-completeness-ladder: no live file references the retired stance..."

# docs/plans/, CHANGELOG.md, the stance file, and this test are the historical
# record of WHY the stance changed, and are exempt: rewriting what a past release
# said is how a project loses the ability to explain its own course corrections.
# CLAUDE.md is exempt at file level for the same reason and checked line-by-line
# below instead -- it must EXPLAIN the retired stance without ISSUING it.
leak="$(cd "$REPO_ROOT" && grep -rilE 'laziness|ponytail' \
          hooks/ skills/ agents/ tests/ticket-scripts/ README.md 2>/dev/null \
          | grep -vE 'tests/ticket-scripts/test-completeness-ladder\.sh|skills/_shared/completeness-ladder\.md' || true)"
[ -z "$leak" ] || fail "the retired stance is still live in: $leak"

CMD="$REPO_ROOT/CLAUDE.md"
has  "$CMD" "Completeness Ladder" "CLAUDE.md does not document the current stance"
grep -q "Laziness Gate" "$CMD" \
    && fail "CLAUDE.md still documents a 'Laziness Gate' — that gate no longer exists in any skill"
grep -qE '^Default coding stance.*laziness|stop at the first rung' "$CMD" \
    && fail "CLAUDE.md still ISSUES the retired stance rather than recording that it was replaced"

echo "PASS: test-completeness-ladder — the default stance is completeness, in all four live slots"
