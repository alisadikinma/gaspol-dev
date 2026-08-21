#!/usr/bin/env bash
# test-finish-fix-loop.sh — gaspol-finish's chain is bounded (IDS-9)
#
# IDS-8's finish chain ran ~11 agent dispatches. The six steps were not the
# problem -- every one of them found a real defect, including a skill that had
# stopped loading. The problem was that the chain had no BOUND:
#
#   * "fix and re-run" appeared four times with no round cap, so five rounds of
#     the SAME finding class went by with nothing saying "this is a pattern".
#   * every re-run audited the WHOLE branch, because nothing told it to scope to
#     the fix diff.
#   * an 8-minute Opus audit could be dispatched over a tree whose 2-second
#     deterministic suite was already red.
#
# All three had a fix already sitting in the plugin -- gaspol-parallel's Fix Loop
# and its scoped re-review-prompt -- which gaspol-finish referenced ZERO times.
# So this test pins the reuse, not a new mechanism.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIN="$REPO_ROOT/skills/gaspol-finish/SKILL.md"
PAR="$REPO_ROOT/skills/gaspol-parallel/SKILL.md"
LOOP="$REPO_ROOT/skills/_shared/fix-loop.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Whitespace-normalised claims. Three line-scoped assertions in IDS-8 lost to a
# sentence WRAPPING across two source lines; markdown prose is reflowed, so any
# check on a phrase longer than a few words has to read the file as one string.
claim() {   # claim <file> <label> <phrase>
    # `return 1`, NOT `exit 1`: an `exit` inside a function kills the whole script,
    # so the positive control below could never observe a failure and every check
    # above it would be theatre. Same defect class a reviewer found in IDS-8's RAW
    # control, which died at exit 2 with no FAIL line ever printed.
    python3 - "$1" "$2" "$3" <<'PYEOF' || return 1
import sys
path, label, phrase = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    text = " ".join(open(path, encoding="utf-8").read().split())
except OSError as exc:
    print(f"FAIL: {label} — cannot read {path}: {exc}", file=sys.stderr); sys.exit(1)
if phrase not in text:
    print(f"FAIL: {label} — missing claim: {phrase!r}", file=sys.stderr); sys.exit(1)
PYEOF
}

echo "test-finish-fix-loop: the loop lives in ONE file..."
[ -f "$LOOP" ] || fail "skills/_shared/fix-loop.md does not exist — the five-round loop still lives inside gaspol-parallel, where gaspol-finish cannot reach it without loading 30KB of unrelated skill"
claim "$LOOP" "fix-loop" "Five rounds maximum" || exit 1
claim "$LOOP" "fix-loop" "FIX_BASE" || exit 1
claim "$LOOP" "fix-loop" "the head the previous review saw" || exit 1
claim "$LOOP" "fix-loop" "Round 5 is the breaker, not a wall" || exit 1
claim "$LOOP" "fix-loop" "every path forward is a guess" || exit 1

echo "test-finish-fix-loop: both callers reference it, neither re-states it..."
for f in "$FIN" "$PAR"; do
    grep -qF "_shared/fix-loop.md" "$f" \
        || fail "$(basename "$(dirname "$f")") does not reference skills/_shared/fix-loop.md — an unreferenced shared file is the kb_local defect again: documented in one place, read by nothing"
done
# A second copy of the cap is how the two drift apart. One source, or it is not shared.
COPIES=$(grep -rl "Five rounds maximum" "$REPO_ROOT/skills" 2>/dev/null | wc -l | tr -d ' ')
[ "$COPIES" = "1" ] \
    || fail "'Five rounds maximum' appears in $COPIES files under skills/ — it must appear in exactly one (skills/_shared/fix-loop.md); a duplicated rule is a rule that will disagree with itself"

echo "test-finish-fix-loop: cheap gates run before expensive ones..."
claim "$FIN" "finish" "before dispatching any agent" || exit 1
claim "$FIN" "finish" "test-gate-mutations.sh" || exit 1

echo "test-finish-fix-loop: Step 0 anchors its script and names its checks..."
# /security-review, IDS-9. Step 0 was the one place this diff introduced a new
# script invocation, and it introduced it twice over: a relative path, plus an
# instruction to DISCOVER a harness in the working repo and run it. Step 0 runs
# before /security-review by design, so nothing would have inspected either first.
claim "$FIN" "finish" '`"$CLAUDE_PLUGIN_ROOT/skills/gaspol-execute/scripts/detect-stack"' || exit 1
claim "$FIN" "finish" "never go looking for a checker to run" || exit 1

echo "test-finish-fix-loop: re-runs are scoped, not whole-branch..."
claim "$FIN" "finish" "record the SHA that verdict saw" || exit 1
claim "$FIN" "finish" "re-runs a gate scopes to that SHA" || exit 1

echo "test-finish-fix-loop: the six steps are still all there..."
# The chain is bounded, not shortened. Each of these found a real defect in
# IDS-8; deleting a gate because the chain felt slow would throw away exactly the
# thing that caught a skill which had stopped loading.
for step in "gaspol-verify" "plan-verifier" "gaspol-review" "/security-review" "gaspol-sync-docs" "gaspol-learn"; do
    grep -qF "$step" "$FIN" \
        || fail "gaspol-finish no longer names '$step' — the chain was bounded, not shortened"
done

# Positive control: the claim() helper must be able to FAIL, or every check above
# is theatre. A helper that always exits 0 is this repo's own
# vacuous-assertion-proves-nothing.
if claim "$FIN" "control" "a phrase that is certainly not in this file zzqq" 2>/dev/null; then
    fail "the claim helper passed a phrase that cannot be present — it never fails, so every assertion above proved nothing"
fi

echo "PASS: test-finish-fix-loop (loop shared, gates ordered cheap-first, re-runs scoped, six steps intact)"
