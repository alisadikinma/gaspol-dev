#!/usr/bin/env bash
# test-kb-write-format.sh — capture into the quarantine, in its own shape (IDS-8 Phase C)
#
# The owner already runs a capture pipeline: memory-extract.sh writes session
# learnings to 90-Inbox/agent-learnings/, and superbrain-promote is the single
# human gate that moves them into the curated core. gaspol was running a second,
# parallel store — on 2026-08-21 both harvested the same lesson, four files, one
# insight.
#
# So gaspol stops owning a store and starts feeding that quarantine. Two things
# this test refuses to let slip:
#
#   1. superbrain-promote's scan reads frontmatter + H1. If gaspol's notes are a
#      different shape, the promoter silently skips them and the capture is worse
#      than useless — it looks captured and is unreachable.
#   2. status must be `proposed`, never `accepted`. gaspol no longer promotes its
#      own writes; only the human gate does. An agent that grades its own work as
#      accepted has removed the gate it was told to feed.
#
# And the ≥200-word quality gate must SURVIVE the restructure. It is the only
# thing gaspol contributes that the vault extractor does not already do. Losing
# it while deleting directories would be a silent downgrade dressed as cleanup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEARN="$REPO_ROOT/skills/gaspol-learn/SKILL.md"
ADR="$REPO_ROOT/skills/gaspol-adr/SKILL.md"
RESEARCH="$REPO_ROOT/skills/gaspol-research/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-write-format: no skill writes into a category DIRECTORY..."
# The four category dirs are what made gaspol a separate store. Routing to a
# final home is superbrain-promote's job and it already has the table for it.
for f in "$LEARN" "$ADR" "$RESEARCH"; do
    if grep -nE '<KB_ROOT>/(architecture|design-decisions|research|reusable-snippets|ui-patterns)/' "$f" >/dev/null; then
        grep -nE '<KB_ROOT>/(architecture|design-decisions|research|reusable-snippets|ui-patterns)/' "$f" | sed 's/^/    /' >&2
        fail "$(basename "$(dirname "$f")") still writes into a category directory — that shape is a second store, and superbrain-promote's scan will not see it"
    fi
done
grep -qE '<KB_ROOT>/<category>/' "$LEARN" \
    && fail "gaspol-learn still writes <KB_ROOT>/<category>/<slug>.md instead of a flat quarantine note"

echo "test-kb-write-format: the flat quarantine filename is specified..."
for f in "$LEARN" "$ADR" "$RESEARCH"; do
    grep -qE '<KB_ROOT>/(YYYY-MM-DD|\$\(date)' "$f" \
        || fail "$(basename "$(dirname "$f")") does not specify the flat dated filename <KB_ROOT>/YYYY-MM-DD-<slug>.md"
done

echo "test-kb-write-format: the note shape matches what the promoter scans..."
for f in "$LEARN" "$ADR" "$RESEARCH"; do
    n=$(basename "$(dirname "$f")")
    grep -qF 'status: proposed' "$f" \
        || fail "$n does not mandate 'status: proposed' — the promoter's scan keys on frontmatter"
    grep -qE '^\s*#\s|# <Title>|# <title>' "$f" \
        || fail "$n does not show the '# Title' H1 the scan reads"
    grep -qE 'tags:\s*\[' "$f" \
        || fail "$n does not show the tags: [...] line"
done

echo "test-kb-write-format: gaspol never grades its own capture as accepted..."
for f in "$LEARN" "$ADR" "$RESEARCH"; do
    n=$(basename "$(dirname "$f")")
    grep -qiE 'never .{0,40}accepted|not .{0,20}accepted|proposed.{0,60}never accepted' "$f" \
        || fail "$n does not state that gaspol writes are never 'accepted' — promotion belongs to superbrain-promote, and a skill that promotes itself has removed the gate"
done

# --- the gate that must survive the restructure -----------------------------
echo "test-kb-write-format: the quality gate survived..."
# BOTH halves, separately. A single "does 200 appear anywhere" check passed a
# sabotage that halved the threshold, because the OTHER gate line still carried
# the digits. Weakening either half must fail.
grep -qE '(≥|>=) ?200 ?word' "$LEARN" \
    || fail "the ACCEPT threshold (body ≥200 words) is gone or weakened — it is the ONLY thing gaspol adds that memory-extract.sh does not, so losing it turns this merge into a pure downgrade"
grep -qiE '< ?200 ?word.*reject|reject.*< ?200 ?word' "$LEARN" \
    || fail "the REJECT rule for a body under 200 words is gone — a threshold with no rejection is a suggestion, not a gate"
grep -c '200' "$LEARN" | grep -qE '^[2-9]|^[0-9]{2,}' \
    || fail "fewer than two 200-word gate references remain — the accept threshold and the reject rule are separate lines and both must survive"

# --- sole-promoter rule stated where a reader will meet it ------------------
echo "test-kb-write-format: the sole-promoter rule is written down..."
grep -qi 'superbrain-promote\|sole promoter\|single .{0,20}gate' "$LEARN" \
    || fail "gaspol-learn does not name the promoter it feeds — without that, the next editor will 'helpfully' write straight into the curated core"

# --- coherence: nobody reads an index nobody writes -------------------------
# Removing the INDEX.md write while leaving thirteen readers in place would be
# the exact "documented but does not work" pattern this ticket opened with.
echo "test-kb-write-format: no skill instructs writing or grepping an index gaspol never writes..."
# The vault's own INDEX.md is a DIFFERENT artifact: the owner writes and
# maintains it as the vault master map, and reading it is correct. Only an index
# GASPOL would have to write is forbidden. The exemption is named rather than
# broad, so it cannot quietly cover a gaspol-written index later.
STALE=$(grep -rn "INDEX.md" "$REPO_ROOT/skills" 2>/dev/null \
        | grep -viE "no index|index caveat|maintains one|removed .{0,10}no index|there is no index|master map" || true)
if [ -n "$STALE" ]; then
    printf '%s\n' "$STALE" | sed 's/^/    /' >&2
    fail "skill text still points at INDEX.md — gaspol writes no index, so every one of these reads finds nothing and reports 'no precedent', which is when a known mistake gets repeated"
fi

echo "PASS: test-kb-write-format"
