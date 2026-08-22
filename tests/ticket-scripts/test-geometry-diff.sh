#!/usr/bin/env bash
# test-geometry-diff.sh -- asserts skills/gaspol-verify/scripts/geometry-diff
# diffs two DOM geometry snapshots per data-vv marker (IDS-14 Phase B1-B4):
# colour normalisation, structural-vs-decorative severity split, missing/extra
# marker asymmetry, ratio-vs-pixel tolerance on fluid layouts, and the three
# states (parses / UNKNOWN / no canvas contract).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIFF="$REPO_ROOT/skills/gaspol-verify/scripts/geometry-diff"

FAILURES=0
note() { echo "PASS: $*"; }
bad()  { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }

echo "test-geometry-diff: the script itself passes --self-test..."
if python3 "$DIFF" --self-test; then
    note "geometry-diff --self-test"
else
    bad "geometry-diff --self-test exited non-zero"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

CANVAS_OK='{"source": "canvas", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 160, "h": 44},
                            "style": {"font-size": "16px", "color": "#3B82F6"}}}}'
APP_OK='{"source": "app", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 160, "h": 44},
                            "style": {"font-size": "16px", "color": "rgb(59, 130, 246)"}}}}'

printf '%s' "$CANVAS_OK" > "$tmp/canvas_ok.json"
printf '%s' "$APP_OK" > "$tmp/app_ok.json"

echo "test-geometry-diff: identical geometry, colour spelled two ways -> exit 0..."
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_ok.json" "$tmp/app_ok.json")" || rc=$?
[ "$rc" -eq 0 ] && note "matching snapshot (hex vs rgb() colour) -> exit 0" \
                || bad "matching snapshot: expected exit 0, got $rc ($out)"

echo "test-geometry-diff: structural colour differs -> BLOCKS, exit 1..."
APP_BAD_COLOR='{"source": "app", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 160, "h": 44},
                            "style": {"font-size": "16px", "color": "rgb(220, 38, 38)"}}}}'
printf '%s' "$APP_BAD_COLOR" > "$tmp/app_bad_color.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_ok.json" "$tmp/app_bad_color.json")" || rc=$?
[ "$rc" -eq 1 ] && note "structural colour drift -> exit 1 (BLOCKING)" \
                || bad "colour drift: expected exit 1, got $rc ($out)"
case "$out" in *BLOCKING*color*|*BLOCKING*Color*) note "finding names the colour property" ;; \
  *) bad "finding does not name the colour property: $out" ;; esac

echo "test-geometry-diff: missing marker (in canvas, absent in app) BLOCKS..."
APP_NO_MARKER='{"source": "app", "viewport": {"w": 1440, "h": 900}, "elements": {}}'
printf '%s' "$APP_NO_MARKER" > "$tmp/app_no_marker.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_ok.json" "$tmp/app_no_marker.json")" || rc=$?
[ "$rc" -eq 1 ] && note "marker present in canvas, absent in app -> exit 1 (BLOCKING)" \
                || bad "missing marker: expected exit 1, got $rc ($out)"

echo "test-geometry-diff: extra marker (in app, absent in canvas) WARNS, exit 0..."
CANVAS_NO_MARKER='{"source": "canvas", "viewport": {"w": 1440, "h": 900}, "elements": {}}'
printf '%s' "$CANVAS_NO_MARKER" > "$tmp/canvas_no_marker.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_no_marker.json" "$tmp/app_ok.json")" || rc=$?
[ "$rc" -eq 0 ] && note "marker present in app, absent in canvas -> exit 0 (WARN only)" \
                || bad "extra marker: expected exit 0, got $rc ($out)"
case "$out" in *WARN*) note "extra marker produces a WARN finding" ;; \
  *) bad "extra marker produced no WARN finding: $out" ;; esac

echo "test-geometry-diff: fluid width passes on ratio despite failing on pixels..."
CANVAS_FLUID='{"source": "canvas", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 640, "h": 44}, "style": {}}}}'
APP_FLUID='{"source": "app", "viewport": {"w": 1366, "h": 850},
 "elements": {"hero.cta": {"box": {"x": 100, "y": 200, "w": 610, "h": 44}, "style": {}}}}'
printf '%s' "$CANVAS_FLUID" > "$tmp/canvas_fluid.json"
printf '%s' "$APP_FLUID" > "$tmp/app_fluid.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_fluid.json" "$tmp/app_fluid.json")" || rc=$?
[ "$rc" -eq 0 ] && note "640/1440 vs 610/1366 (both ~44%) passes on ratio despite 30px pixel diff" \
                || bad "fluid width: expected exit 0, got $rc ($out)"

echo "test-geometry-diff: same ratio math, but the absolute gap is real drift -> BLOCKS..."
CANVAS_DRIFT='{"source": "canvas", "viewport": {"w": 1000, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 0, "y": 0, "w": 440, "h": 44}, "style": {}}}}'
APP_DRIFT='{"source": "app", "viewport": {"w": 1000, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 0, "y": 0, "w": 610, "h": 44}, "style": {}}}}'
printf '%s' "$CANVAS_DRIFT" > "$tmp/canvas_drift.json"
printf '%s' "$APP_DRIFT" > "$tmp/app_drift.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_drift.json" "$tmp/app_drift.json")" || rc=$?
[ "$rc" -eq 1 ] && note "44% vs 61% at the same viewport fails on both pixel and ratio -> exit 1" \
                || bad "real width drift: expected exit 1, got $rc ($out)"

echo "test-geometry-diff: decorative property differs -> WARN only, exit 0..."
CANVAS_SHADOW='{"source": "canvas", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 0, "y": 0, "w": 100, "h": 40},
                            "style": {"box-shadow": "0 1px 2px rgba(0,0,0,0.1)"}}}}'
APP_SHADOW='{"source": "app", "viewport": {"w": 1440, "h": 900},
 "elements": {"hero.cta": {"box": {"x": 0, "y": 0, "w": 100, "h": 40},
                            "style": {"box-shadow": "0 2px 4px rgba(0,0,0,0.2)"}}}}'
printf '%s' "$CANVAS_SHADOW" > "$tmp/canvas_shadow.json"
printf '%s' "$APP_SHADOW" > "$tmp/app_shadow.json"
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_shadow.json" "$tmp/app_shadow.json")" || rc=$?
[ "$rc" -eq 0 ] && note "box-shadow differs -> exit 0 (WARN only, decorative)" \
                || bad "decorative drift: expected exit 0, got $rc ($out)"
case "$out" in *WARN*shadow*|*WARN*box-shadow*) note "box-shadow finding is WARN, named" ;; \
  *) bad "box-shadow finding missing or wrong severity: $out" ;; esac

echo "test-geometry-diff: exit 4 on a missing canvas file (no canvas contract)..."
rc=0; out="$(python3 "$DIFF" "$tmp/does-not-exist.json" "$tmp/app_ok.json")" || rc=$?
[ "$rc" -eq 4 ] && note "missing canvas file -> exit 4 (none)" \
                || bad "missing canvas: expected exit 4, got $rc ($out)"
case "$out" in *"no canvas contract"*) note "exit 4 message says no canvas contract" ;; \
  *) bad "exit 4 message does not say no canvas contract: $out" ;; esac

echo "test-geometry-diff: exit 3 on malformed JSON..."
printf 'not json at all {' > "$tmp/malformed.json"
rc=0; out="$(python3 "$DIFF" "$tmp/malformed.json" "$tmp/app_ok.json")" || rc=$?
[ "$rc" -eq 3 ] && note "malformed canvas JSON -> exit 3 (UNKNOWN)" \
                || bad "malformed JSON: expected exit 3, got $rc ($out)"
case "$out" in *UNKNOWN*) note "exit 3 message says UNKNOWN" ;; \
  *) bad "exit 3 message does not say UNKNOWN: $out" ;; esac

echo "test-geometry-diff: exit 3 when 'elements' key is missing (not a geometry snapshot)..."
printf '{"source": "canvas", "viewport": {"w": 1440, "h": 900}}' > "$tmp/no_elements.json"
rc=0; out="$(python3 "$DIFF" "$tmp/no_elements.json" "$tmp/app_ok.json")" || rc=$?
[ "$rc" -eq 3 ] && note "missing 'elements' key -> exit 3 (UNKNOWN)" \
                || bad "missing elements key: expected exit 3, got $rc ($out)"

echo "test-geometry-diff: malformed APP snapshot is also exit 3, not silently ignored..."
rc=0; out="$(python3 "$DIFF" "$tmp/canvas_ok.json" "$tmp/malformed.json")" || rc=$?
[ "$rc" -eq 3 ] && note "malformed app snapshot -> exit 3 (UNKNOWN)" \
                || bad "malformed app snapshot: expected exit 3, got $rc ($out)"

echo "test-geometry-diff: --emit-extractor (B2)..."

rc=0; out1="$(python3 "$DIFF" --emit-extractor)" || rc=$?
[ "$rc" -eq 0 ] && [ -n "$out1" ] && note "--emit-extractor printed a non-empty extractor" \
                || bad "--emit-extractor printed nothing"

case "$out1" in *"data-vv"*) note "extractor targets the data-vv marker attribute" ;; \
  *) bad "extractor does not mention data-vv: $out1" ;; esac
case "$out1" in *getBoundingClientRect*) note "extractor reads real DOM geometry" ;; \
  *) bad "extractor does not call getBoundingClientRect: $out1" ;; esac

echo "test-geometry-diff: --emit-extractor is a LITERAL — a hostile --tolerance changes nothing..."
rc=0; out2="$(python3 "$DIFF" --emit-extractor --tolerance '$(echo PWNED)')" || rc=$?
[ "$rc" -eq 0 ] && note "--emit-extractor with --tolerance still exits 0" \
                || bad "--emit-extractor with --tolerance exited $rc"
if [ "$out1" = "$out2" ]; then
    note "extractor output is byte-identical regardless of --tolerance — no interpolation"
else
    bad "extractor output CHANGED when --tolerance was passed — an argument reached stdout"
fi
case "$out2" in *PWNED*) bad "hostile --tolerance value leaked into the extractor output" ;; \
  *) note "hostile --tolerance value did not leak into the extractor output" ;; esac

echo "test-geometry-diff: script exists and self-tests via python3..."
[ -f "$DIFF" ] && note "geometry-diff exists" || bad "geometry-diff does not exist"

echo "test-geometry-diff: visual-contract.md carries all five required statements (B3)..."

CONTRACT="$REPO_ROOT/skills/_shared/visual-contract.md"
if [ ! -f "$CONTRACT" ]; then
    bad "visual-contract.md is missing"
else
    note "visual-contract.md exists"

    grep -qF 'data-vv="<screen>.<element>"' "$CONTRACT" \
        && note "states the data-vv naming format" \
        || bad "visual-contract.md does not state the data-vv naming format"

    grep -qiE 'target stack|copies rather than translates|the project.s (own )?stack' "$CONTRACT" \
        && note "states markup must be in the target stack, not translated" \
        || bad "visual-contract.md does not require markup in the target stack"

    grep -qiE 'worst.case content|realistic worst' "$CONTRACT" \
        && note "states content must be realistic worst-case" \
        || bad "visual-contract.md does not require realistic worst-case content"

    grep -qF 'docs/plans/YYYY-MM-DD-<TICKET>-<topic>-canvas.html' "$CONTRACT" \
        && note "states the canvas file path convention" \
        || bad "visual-contract.md does not state the canvas file path"

    grep -qF 'gaspol-visual-verify' "$CONTRACT" \
        && note "names gaspol-visual-verify as deferred (not built here)" \
        || bad "visual-contract.md does not name gaspol-visual-verify as deferred"

    grep -qiE 'pixel.diff' "$CONTRACT" \
        && note "names the pixel-diff trigger as deferred" \
        || bad "visual-contract.md does not name the pixel-diff trigger as deferred"

    grep -qF 'IDS-6' "$CONTRACT" \
        && note "cites IDS-6 Part B as its origin" \
        || bad "visual-contract.md does not cite IDS-6 as its origin"
fi

echo "test-geometry-diff: wiring into live-app-check web lane (B4)..."

LIVE_APP_CHECK="$REPO_ROOT/skills/_shared/live-app-check.md"
VERIFY_SKILL="$REPO_ROOT/skills/gaspol-verify/SKILL.md"

grep -qF 'geometry-diff' "$LIVE_APP_CHECK" \
    && note "live-app-check.md references geometry-diff" \
    || bad "live-app-check.md web lane does not run geometry-diff"

# The mobile lane must be excluded AND the reason must be there -- a silent
# absence reads as an oversight, not a scoping decision.
grep -qiE 'no DOM behind it|this machine does not apply' "$LIVE_APP_CHECK" \
    && note "live-app-check.md states WHY the mobile lane is excluded from the visual diff" \
    || bad "live-app-check.md does not explain why the mobile lane is excluded"

for outcome in 'visual-diff: [0-9]+ blocking' 'visual-diff: none' 'visual-diff: UNKNOWN'; do
    grep -qE "$outcome" "$LIVE_APP_CHECK" \
        && note "live-app-check.md lists the '$outcome' outcome" \
        || bad "live-app-check.md is missing the '$outcome' outcome line"
done

grep -qF 'visual-diff:' "$VERIFY_SKILL" \
    && note "gaspol-verify Layer 4 carries a visual-diff: line" \
    || bad "gaspol-verify Layer 4 does not carry a visual-diff: line"

if [ "$FAILURES" -gt 0 ]; then
    echo "test-geometry-diff: $FAILURES assertion(s) failed" >&2
    exit 1
fi
echo "PASS: test-geometry-diff -- colour normalisation, severity split, marker asymmetry, ratio tolerance, three states"
