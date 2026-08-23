#!/usr/bin/env bash
# test-finish-offer.sh — finishing is an OFFER, and its text lives in one file (IDS-17)
#
# Two defects this pins, both the shape this repository keeps re-fixing:
#
#   1. Ending a ticket read as an obligation. gaspol-parallel Phase 3 said "Run
#      gaspol-finish to finalize" and gaspol-execute listed it as downstream with
#      no choice attached -- an instruction with no door out of it.
#   2. The obvious fix -- write the modal into all three callers -- is how a
#      constant ends up disagreeing with itself. fix-loop.md was extracted for
#      exactly this reason, so the offer text gets the same treatment: one file,
#      three references, zero restatements.
#
# The deferral is the part with teeth. "Nanti" has to leave a cursor a machine
# already reads (scan-active-ledgers), or a finished branch quietly never merges
# and nothing anywhere notices.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OFFER="$REPO_ROOT/skills/_shared/finish-offer.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Whitespace-normalised, for the reason test-finish-fix-loop.sh states: markdown
# prose reflows, so a line-scoped grep on a phrase longer than a few words is a
# test that passes or fails on where the editor happened to wrap.
claim() {   # claim <file> <label> <phrase>
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

echo "test-finish-offer: the offer text lives in ONE file..."
[ -f "$OFFER" ] || fail "skills/_shared/finish-offer.md does not exist — the offer would have to be restated in each of the three callers, which is how a constant ends up disagreeing with itself"

echo "test-finish-offer: all three options are named..."
claim "$OFFER" "finish-offer" "Finish sekarang" || exit 1
claim "$OFFER" "finish-offer" "Nanti" || exit 1
claim "$OFFER" "finish-offer" "Cuma verify dulu" || exit 1

echo "test-finish-offer: the deferral leaves a cursor scan-active-ledgers already reads..."
# The literal cursor, not a paraphrase. scan-active-ledgers matches on the
# NEXT: marker in the last non-empty line; a cursor spelled any other way is a
# deferral nothing surfaces.
claim "$OFFER" "finish-offer" "— NEXT: gaspol-finish — deferred:" || exit 1
claim "$OFFER" "finish-offer" "scan-active-ledgers" || exit 1

echo "test-finish-offer: an empty deferral reason is refused..."
# ledger-states-require-non-empty-reasons: a bare label documents the wish to
# skip without documenting why skipping was acceptable.
claim "$OFFER" "finish-offer" "may not be empty" || exit 1
claim "$OFFER" "finish-offer" "ask again" || exit 1

echo "test-finish-offer: the two error paths that actually happen are covered..."
# A branch with no plan has no ledger. Inventing one to hold a deferral line
# would put a progress file where no progress was ever tracked.
claim "$OFFER" "finish-offer" "no ledger" || exit 1
# And a failed verify must not loop back into the offer: work that does not pass
# its own suite is not work you get asked how to finish.
claim "$OFFER" "finish-offer" "do NOT re-present the offer" || exit 1

echo "test-finish-offer: callers reference the file, none restates the modal..."
for f in gaspol-execute gaspol-parallel gaspol-auto; do
    grep -qF "_shared/finish-offer.md" "$REPO_ROOT/skills/$f/SKILL.md" \
        || fail "skills/$f/SKILL.md does not reference _shared/finish-offer.md — an unreferenced shared file is the kb_local defect again: documented in one place, read by nothing"
done
COPIES=$(grep -rl "Cuma verify dulu" "$REPO_ROOT/skills" 2>/dev/null | wc -l | tr -d ' ')
[ "$COPIES" = "1" ] \
    || fail "'Cuma verify dulu' appears in $COPIES files under skills/ — it must appear in exactly one (skills/_shared/finish-offer.md)"

echo "test-finish-offer: gaspol-auto's offer is post-run, not a mid-run checkpoint..."
claim "$REPO_ROOT/skills/gaspol-auto/SKILL.md" "gaspol-auto" "not a mid-run checkpoint" || exit 1

# Positive control: the claim() helper must be able to FAIL, or every check above
# is theatre.
if claim "$OFFER" "control" "a phrase that is certainly not in this file zzqq" 2>/dev/null; then
    fail "the claim helper passed a phrase that cannot be present — it never fails, so every assertion above proved nothing"
fi

echo "PASS: test-finish-offer (one source, three callers, deferral leaves a readable cursor)"
