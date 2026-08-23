#!/usr/bin/env bash
# test-artifact-tabs.sh — the two-tab artifact skeleton is a real, checkable thing,
# not a sentence in a contract (IDS-16 Phase A).
#
# Why this test exists. This repository's recurring defect is a rule stated in prose
# with no machine behind it: IDS-7's design gate that was parsed and never read,
# IDS-8's `kb_local` setting that zero files consulted, IDS-13's live-app check that
# had no detector. "The artifact has two tabs" is that same shape. A skeleton in the
# contract, asserted here, is what turns it into something an executor can copy and a
# test can catch drifting.
#
# The CSP assertion is the load-bearing one. A published artifact blocks every request
# to an external host, so a skeleton that reaches for a CDN stylesheet or an <img src>
# on a remote host renders broken for the reader and fine for nobody. The mockup goes
# in an <iframe srcdoc>, which starts no request at all -- that is the whole reason
# srcdoc was chosen over src.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTRACT="$REPO_ROOT/skills/gaspol-plan/logic-design-artifact.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$CONTRACT" ] || fail "skills/gaspol-plan/logic-design-artifact.md is missing"

# The skeleton is a fenced ```html block inside the contract. Slice it out and assert
# against the slice only -- asserting against the whole file would let prose that
# merely MENTIONS an iframe satisfy a test about the skeleton containing one.
SKELETON="$(awk '/^```html$/{flag=1;next} /^```$/{flag=0} flag' "$CONTRACT")"

echo "test-artifact-tabs: the contract carries an <iframe srcdoc> tab skeleton..."

[ -n "$SKELETON" ] \
    || fail "logic-design-artifact.md carries no <iframe srcdoc> tab skeleton"

echo "test-artifact-tabs: exactly two tab panels, one of them the mockup frame..."

# Count OPENING TAGS, not bare occurrences of the string. The skeleton's own stylesheet
# contains the attribute selectors [role="tabpanel"] and [role="tab"], and a substring
# count reads those as elements -- which is how the first run of this test reported 3
# panels in a skeleton that has 2.
panels="$(grep -oE '<[a-z]+[^>]*role="tabpanel"' <<<"$SKELETON" | wc -l | tr -d ' ')"
[ "$panels" -eq 2 ] \
    || fail "expected exactly 2 role=\"tabpanel\" elements in the skeleton, found $panels"

tabs="$(grep -oE '<[a-z]+[^>]*role="tab"' <<<"$SKELETON" | wc -l | tr -d ' ')"
[ "$tabs" -eq 2 ] \
    || fail "expected exactly 2 role=\"tab\" controls in the skeleton, found $tabs"

grep -q '<iframe[^>]*srcdoc' <<<"$SKELETON" \
    || fail "the Design panel must mount the mockup in an <iframe srcdoc>, which isolates its CSS"

grep -q '<iframe[^>]*title=' <<<"$SKELETON" \
    || fail "the mockup iframe needs a title attribute -- an untitled frame is unreachable to a screen reader"

echo "test-artifact-tabs: the page names itself..."

grep -q '<title>' <<<"$SKELETON" \
    || fail "the skeleton has no <title> -- the artifact would be named by its filename instead"

echo "test-artifact-tabs: nothing in the skeleton reaches an external host (artifact CSP)..."

# Strip HTML comments first: a comment may legitimately cite a URL as documentation.
# What must be clean is the markup the browser actually acts on.
STRIPPED="$(perl -0777 -pe 's/<!--.*?-->//gs' <<<"$SKELETON")"
if grep -qE 'https?://' <<<"$STRIPPED"; then
    grep -nE 'https?://' <<<"$STRIPPED" >&2
    fail "the skeleton references an external host -- the artifact CSP blocks it, so this renders broken"
fi

echo "test-artifact-tabs: the one-tab case is specified, not left to the reader..."

grep -qiE 'satu tab|one tab|single tab' "$CONTRACT" \
    || fail "the contract must say what a logic-only change produces (one tab), not only the two-tab case"

echo "PASS: test-artifact-tabs — the two-tab skeleton is real, self-contained, and CSP-safe"
