#!/usr/bin/env bash
# test-ids8-docs.sh — documentation matches what shipped (IDS-8 Phase H)
#
# This ticket exists because documentation promised a setting no code read.
# Leaving the same documents describing the OLD arrangement would reproduce the
# defect while claiming to have fixed it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CM="$REPO_ROOT/CLAUDE.md"; CH="$REPO_ROOT/CHANGELOG.md"
KS="$REPO_ROOT/docs/kb-setup.md"; RM="$REPO_ROOT/README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-ids8-docs: the 1.18.0 release is recorded, and the manifests agree..."
# HISTORICAL fact, not the current version. This assertion used to pin the
# manifests to "1.18.0" and therefore went red on the very next release (it did,
# on IDS-9). A per-ticket test owns what its ticket shipped; the CURRENT version
# is a cross-cutting property, and test-naming-convention.sh already asserts the
# two manifests and CLAUDE.md's footer agree with each other.
grep -qF "## [1.18.0]" "$CH" \
    || fail "CHANGELOG.md has no 1.18.0 section — this ticket's release is not recorded"
PV=$(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/.claude-plugin/plugin.json" | head -1)
[ -n "$PV" ] || fail "plugin.json carries no parsable version — the scan is broken, so agreement below would prove nothing"
# The marketplace manifest moved out of this repo in 50fbbb1; resolve it, and
# report the three states apart. Exit 4 is "not checked", never "agrees".
MM_RC=0
MM="$("$REPO_ROOT/tests/ticket-scripts/marketplace-manifest")" || MM_RC=$?
case "$MM_RC" in
    0)  MV=$(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "$MM" | head -1)
        [ "$PV" = "$MV" ] || fail "manifests disagree: plugin.json=$PV marketplace=$MV ($MM)" ;;
    3)  fail "marketplace-manifest: UNKNOWN — configured and unreadable" ;;
    4)  echo "  marketplace-manifest: none — cross-manifest version agreement NOT checked" ;;
esac

echo "test-ids8-docs: kb-setup no longer promises a setting nothing reads..."
grep -qF 'kb-path.md' "$KS" \
    || fail "docs/kb-setup.md still presents kb_local as working without naming the resolver that implements it — kb_local had ZERO readers under skills/, which is the defect this ticket opened with"
grep -qF 'kb-root' "$KS" \
    || fail "docs/kb-setup.md does not name the executable resolver, so a reader cannot check the claim"

echo "test-ids8-docs: CLAUDE.md documents what actually shipped..."
for token in 'kb-path.md' 'kb-root' '90-Inbox' 'superbrain-promote' 'show-toplevel' 'graphify: UNKNOWN' 'status: proposed'; do
    grep -qF "$token" "$CM" || fail "CLAUDE.md does not mention '$token' — the architecture table is what the next session reads instead of the diff"
done

echo "test-ids8-docs: the kb-audit overlap is recorded as RESOLVED, with its reason..."
# IDS-8 deferred this overlap and the test asserted the deferral was written down.
# IDS-11 resolved it by deleting gaspol-kb-audit, so the assertion changes what it
# asserts rather than disappearing: a resolution nobody wrote down is a resolution
# the next reader undoes by rebuilding the skill.
grep -qiE 'kb-audit.{0,200}(deleted|removed)' "$CM" \
    || fail "CLAUDE.md does not record that gaspol-kb-audit was REMOVED in favour of the store's own promoter — an unrecorded deletion is how a deleted skill gets rebuilt"
grep -qiE 'superbrain-promote' "$CM" \
    || fail "the promoter that took over is not named; 'removed' with no successor reads as a capability simply lost"

echo "test-ids8-docs: the changelog leads with the defect, not the feature..."
sec=$(awk '/^## \[1.18.0\]/{f=1;next} /^## \[/{f=0} f' "$CH")
[ -n "$sec" ] || fail "CHANGELOG.md has no [1.18.0] section"
# Structural, not vocabulary. An earlier version grepped for literal phrases
# ("two pipelines", "zero hits") and failed a changelog that DID lead with the
# defect, in different words. What matters is the ORDER of the subsections.
FIRST_SUB=$(printf '%s\n' "$sec" | grep -m1 '^### ')
printf '%s\n' "$FIRST_SUB" | grep -qiE '^### (fixed|removed)' \
    || fail "the 1.18.0 changelog opens with '$FIRST_SUB' — it must lead with what was broken, not what was added; a release note advertising only additions hides why it was needed"
ADDED_AT=$(printf '%s\n' "$sec" | grep -n '^### \(Added\|Changed\)' | head -1 | cut -d: -f1)
FIXED_AT=$(printf '%s\n' "$sec" | grep -n '^### Fixed' | head -1 | cut -d: -f1)
if [ -n "$ADDED_AT" ] && [ -n "$FIXED_AT" ] && [ "$ADDED_AT" -lt "$FIXED_AT" ]; then
    fail "an Added/Changed subsection precedes Fixed in the 1.18.0 notes — the defect has to come first"
fi
printf '%s\n' "$sec" | grep -qiE 'evidence|verified by running|grep .{0,20}(→|->) ' \
    || fail "the 1.18.0 notes assert defects without showing how they were verified — this repo's changelogs quote the command, not the conclusion"

echo "test-ids8-docs: no doc still tells a user to relocate via a key nothing reads..."
# Paragraph-scoped. A line-scoped check flagged a wrapped explanatory sentence
# whose pointer sat on the NEXT line — the same false-positive shape that bit
# the git-init and negation assertions earlier in this ticket.
for d in "$RM" "$CM" "$KS"; do
    python3 - "$d" <<'PYEOF' || fail "$(basename "$d") names kb_local in a block that never points at the resolver reading it — that is the promise-with-no-implementation this ticket exists to end"
import re, sys
blocks = re.split(r"\n\s*\n", open(sys.argv[1], encoding="utf-8").read())
bad = [b for b in blocks if "kb_local" in b
       and not re.search(r"kb-path|kb-root|resolver|resolution order", b)]
if bad:
    print("  offending block: " + " ".join(bad[0].split())[:160], file=sys.stderr)
    sys.exit(1)
PYEOF
done

echo "test-ids8-docs: CLAUDE.md documents the ledger gate (IDS-19)..."
grep -qiE 'ledger-gate' "$CM" \
    || fail "CLAUDE.md: expected a ledger-gate section, found none"

# The three new files must each earn a row in the Architecture table, or the
# table stops being the map it claims to be.
for f in "skills/gaspol-verify/scripts/ledger-gate" \
         "tests/ticket-scripts/test-ledger-gate.sh" \
         "tests/ticket-scripts/test-ledger-template.sh"; do
    grep -qF "$f" "$CM" || fail "CLAUDE.md has no Architecture row for $f"
    [ -s "$REPO_ROOT/$f" ] || fail "$f is documented but missing or empty"
done

# The boundary must be stated, not implied. A gate described without its limit
# gets read as a completeness guarantee by the next person, which is how a
# partial gate becomes a false one.
python3 - "$CM" <<'PYEOF2' || fail "CLAUDE.md describes the ledger gate without saying what it does NOT close — a gate stated without its limit reads as a guarantee"
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
sec = re.search(r"\n### [^\n]*Ledger[^\n]*\n(.*?)(?=\n### |\n## )", text, re.S)
if not sec:
    print("  no '### ... Ledger ...' section found", file=sys.stderr)
    sys.exit(1)
body = sec.group(1)
if not re.search(r"does NOT close|never checks whether|not honesty|honest", body):
    print("  the section never states the boundary", file=sys.stderr)
    sys.exit(1)
PYEOF2

echo "test-ids8-docs: plugin version and CLAUDE.md footer agree..."
PJ="$REPO_ROOT/.claude-plugin/plugin.json"
PJ_VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$PJ")"
grep -qF "**Version:** $PJ_VER" "$CM" \
    || fail "plugin.json says $PJ_VER but CLAUDE.md's footer does not — the two must agree or nobody knows what shipped"

echo "PASS: test-ids8-docs"
