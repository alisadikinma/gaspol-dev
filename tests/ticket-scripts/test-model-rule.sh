#!/usr/bin/env bash
# test-model-rule.sh — the rubric is a RULE, not advice (IDS-20)
#
# docs/rubric-model-switching.md opened with "Auto-rubric untuk pilih model
# berdasarkan task type" and was referenced everywhere as something to choose
# from. Nothing enforced it, and it drifted from the owner's intent in ten
# places. Its prose still named Opus 4.7 and Sonnet 4.6, versions that do not
# exist — and a rubric naming models that do not exist reads as unmaintained,
# which is how ten drifts happened without anyone deciding them.
#
# These are text assertions over documentation. They cannot catch a wrong
# declaration in a skill file — that is what model-gate and test-model-gate.sh
# are for. What they catch is the RULE quietly softening back into advice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUBRIC="$REPO_ROOT/docs/rubric-model-switching.md"
CM="$REPO_ROOT/CLAUDE.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
note() { echo "  ok — $*"; }

# near <file> <anchor regex> <partner regex> [window]
#
# Two assertions in this file need "these two ideas appear close together", and
# BOTH first failed against correct prose for the same reason: `grep -E` matches
# one LINE at a time, and a wrapped sentence puts the two halves on different
# lines. An earlier attempt also used [^.]{0,N}, which excludes the period and so
# rejected "…ran on `haiku`. That tier is deleted." — the exact phrasing it was
# written to accept. Proximity is a whole-file question; grep is the wrong tool
# for it.
near() {
    python3 - "$1" "$2" "$3" "${4:-200}" <<'PYNEAR'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read().lower()
anchor, partner, win = sys.argv[2].lower(), sys.argv[3].lower(), int(sys.argv[4])
ok = any(re.search(partner, text[max(0, m.start() - win):m.end() + win])
         for m in re.finditer(anchor, text))
sys.exit(0 if ok else 1)
PYNEAR
}

[ -f "$RUBRIC" ] || fail "docs/rubric-model-switching.md is missing"

echo "test-model-rule: the rubric states a rule, not a preference..."
grep -qE '\bMUST\b|\bWAJIB\b' "$RUBRIC" \
    || fail "the rubric still reads as advice, not a rule — no MUST anywhere"
note "the rubric states a MUST"

echo "test-model-rule: no third tier survives..."
if grep -qiF 'haiku' "$RUBRIC"; then
    # The rubric is the ONE place allowed to name the deleted tier, and only to
    # record that it was deleted. Naming it as a choice is the tier coming back.
    near "$RUBRIC" "haiku" "(removed|deleted|dihapus|no longer|gone|blocking)" \
        || fail "the rubric names haiku without saying it was removed nearby — a deleted tier presented as a choice is the tier still being available"
    note "haiku appears only as a recorded removal"
else
    note "the rubric does not name haiku at all"
fi
# CLAUDE.md gets the same allowance as the rubric, and for the same reason: to
# record that a tier was removed you must name it. The test that forbade the
# word outright failed against the paragraph documenting the removal — a checker
# cannot forbid the vocabulary its subject needs to explain itself.
if grep -qiF 'haiku' "$CM"; then
    near "$CM" "haiku" "(removed|deleted|dihapus|no longer|blocking|until ids-20)" \
        || fail "CLAUDE.md names haiku without saying it was removed nearby — a deleted tier presented as a choice is the tier still being available"
    note "CLAUDE.md names haiku only as a recorded removal"
else
    note "CLAUDE.md names no haiku tier"
fi

echo "test-model-rule: the stale version numbers are gone..."
# A stale version may be QUOTED as evidence that it was stale — the record of
# the fix has to name what was fixed. What is forbidden is presenting one as
# current. Same allowance as the deleted tier above, and for the same reason:
# forbidding the vocabulary the subject needs to explain itself makes the
# checker fail against correct documentation, which happened FIVE times in this
# ticket before the pattern was named.
for stale in "Opus 4.7" "Sonnet 4.6" "Haiku 4.5"; do
    for doc in "$RUBRIC" "$CM"; do
        if grep -qF "$stale" "$doc"; then
            near "$doc" "$(printf '%s' "$stale" | tr 'A-Z' 'a-z')" \
                 "(do(es)? not exist|no longer|stale|until ids-20|was |were )" \
                || fail "$(basename "$doc") names $stale as if it were current — that version does not exist"
        fi
    done
done
note "no stale version number is presented as current"

echo "test-model-rule: both tiers are named, and only two..."
grep -qiE '\bopus\b' "$RUBRIC" || fail "the rubric never names opus"
grep -qiE '\bsonnet\b' "$RUBRIC" || fail "the rubric never names sonnet"
note "opus and sonnet are both named"

echo "test-model-rule: the alias mapping is recorded WITH a date..."
# The aliases are a choice with a cost: if `opus` ever resolves to a weaker
# model, nothing detects it. The dated record is what a human checks. An undated
# one cannot be judged stale, which makes it worse than none.
grep -qF 'claude-opus-5' "$RUBRIC" \
    || fail "the rubric does not record which concrete id 'opus' means today"
grep -qF 'claude-sonnet-5' "$RUBRIC" \
    || fail "the rubric does not record which concrete id 'sonnet' means today"
grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|[0-9]{1,2} (January|February|March|April|May|June|July|August|September|October|November|December) 20[0-9]{2}' "$RUBRIC" \
    || fail "the alias mapping carries no date — an undated mapping cannot be judged stale, which is worse than none"
note "the alias mapping is recorded with a date"

echo "test-model-rule: the alias choice states what it gives up..."
grep -qiE 'weaker|nothing (tells|detects)|not a (guarantee|mechanism)' "$RUBRIC" \
    || fail "the rubric presents the alias choice without naming its cost — a trade-off stated only on the winning side is not a trade-off"
note "the cost of the alias choice is stated"

echo "test-model-rule: overrides require a written reason..."
near "$RUBRIC" "override" "written reason" \
    || fail "the rubric allows overrides without demanding a written reason — a silent override is how a rule becomes advice again"
note "an override must carry a written reason"

echo "test-model-rule: the rule points at the machine that reads it..."
grep -qF 'model-gate' "$RUBRIC" \
    || fail "the rubric never names model-gate — a rule with no named enforcer is the shape this repo keeps having to undo"
note "the rubric names model-gate"

echo "test-model-rule: the proximity helper's own positive control..."
near "$RUBRIC" "haiku" "definitely-not-in-this-file-xyzzy" \
    && fail "the proximity helper matched a string that is not in the file — every assertion using it is vacuous"
echo "  ok — near() can fail"

echo "test-model-rule: PASS"
