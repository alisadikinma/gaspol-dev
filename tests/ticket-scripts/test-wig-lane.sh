#!/usr/bin/env bash
# test-wig-lane.sh — Layer 4 rewrite + Web Interface Guidelines lane (IDS-7 Phase F)
#
# The lane fetches markdown from a public URL and hands it to a review model as
# rules. Fetched content is UNTRUSTED INPUT, not instructions. Three rails, all
# asserted here because prose rails rot silently:
#   1. the URL is pinned literally, never taken from a file or an argument
#   2. the fetched text produces findings and nothing else — any directive
#      inside it is ignored and reported, never followed
#   3. a failed or unrecognised fetch is recorded as NOT RUN, never as passed
#
# Plus the fetch-don't-fork guard: gaspol's static forks drift, which is why the
# 1.4MB gaspol-design fork was deleted in v1.14. If the WIG rules ever appear
# copied into this repo, this test fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY="$REPO_ROOT/skills/gaspol-verify/SKILL.md"
BRAINSTORM="$REPO_ROOT/skills/gaspol-brainstorm/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

WIG_URL="https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md"

echo "test-wig-lane: pinned URL..."
grep -qF "$WIG_URL" "$VERIFY" \
    || fail "expected gaspol-verify/SKILL.md to name the pinned Web Interface Guidelines URL literally"
has "$VERIFY" "pinned" \
    "expected the URL to be described as pinned — a URL read from a file or an argument is an injection vector"

echo "test-wig-lane: fetched content is data, not instructions..."
has "$VERIFY" "not instructions\|never instructions\|as data" \
    "expected gaspol-verify/SKILL.md to state that fetched guidelines are data, never instructions"
has "$VERIFY" "ignored and reported\|ignore.*never follow\|never followed" \
    "expected an explicit rule that a directive inside the fetched text is ignored and reported, not followed"

echo "test-wig-lane: honest failure record..."
grep -qF "wig-lane: not run" "$VERIFY" \
    || fail "expected the exact 'wig-lane: not run' record string for a failed fetch"
has "$VERIFY" "never.*passed\|not.*as passed" \
    "expected an explicit prohibition on recording the lane as passed when it did not run"

# The presence check above proves a prohibition EXISTS. It cannot fail if text
# CONTRADICTING it is added later, which is the failure mode that actually
# matters. This is the genuinely negative half.
# Find any sentence that records the lane as passed, EXCLUDING the negated ones
# — "Never record the lane as passed" is the prohibition itself, and a pattern
# that cannot tell it from an endorsement flags the correct file.
if grep -iE 'record[a-z]* .{0,40}as passed|wig-lane: passed' "$VERIFY" \
     | grep -qivE 'never|not |must not|prohibit'; then
    fail "gaspol-verify/SKILL.md contains an UNNEGATED instruction recording the WIG lane as passed — a lane that did not run must never be recorded as passing"
fi

echo "test-wig-lane: fetch-don't-fork..."
if grep -rqi "prefers-reduced-motion" "$REPO_ROOT/skills/gaspol-verify/rules/" 2>/dev/null; then
    fail "the Web Interface Guidelines look vendored into skills/gaspol-verify/rules/ — the whole point is fetch-don't-fork; the 1.4MB gaspol-design fork drifted and was deleted in v1.14"
fi

echo "test-wig-lane: Layer 4 reads the contract..."
grep -qF -- "--changed-files" "$VERIFY" \
    || fail "Layer 4 still invokes the whole-project scan — it must pass --changed-files BASE"
grep -qF "design-contract: none" "$VERIFY" \
    || fail "expected Layer 4 to record the no-contract state explicitly rather than skipping silently"
grep -qF "design-contract: UNKNOWN" "$VERIFY" \
    || fail "expected Layer 4 to record the broken-contract state as UNKNOWN and STOP"
has "$VERIFY" "extract-design-tokens" \
    "expected Layer 4 to name the extractor it offers when no contract exists"
has "$VERIFY" "AskUserQuestion" \
    "expected the DESIGN.md write to be OFFERED, never taken silently"

echo "test-wig-lane: the stale contrast claim is gone..."
grep -qi "WCAG AA contrast ratios" "$VERIFY" \
    && fail "gaspol-verify/SKILL.md still claims 'WCAG AA contrast ratios' in the old blanket form — that phrasing described code that did not exist; state what Phase D actually computes"

echo "test-wig-lane: brainstorm authoring path..."
has "$BRAINSTORM" "DESIGN.md" \
    "expected gaspol-brainstorm Phase 3 to offer freezing the approved palette into DESIGN.md"
has "$REPO_ROOT/skills/gaspol-brainstorm/references/phase-3-design.md" "awesome-design-md" \
    "expected the DESIGN.md format origin to be referenced"

echo "PASS: test-wig-lane"
