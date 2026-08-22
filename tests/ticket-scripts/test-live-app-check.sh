#!/usr/bin/env bash
# test-live-app-check.sh — asserts the Live App Check has a MECHANISM, and that
# a check which could not run is never recorded as passed (IDS-13).
#
# The defect: gaspol-verify has carried a "Live App Check (mandatory for UI /
# user-visible changes)" since v1.14, and its entire content is an instruction --
# "invoke the `run` skill to actually launch the app and observe the feature
# live". Nothing detects what KIND of app it is, nothing checks whether launching
# is even possible right now, and nothing records what was observed. This is the
# shape IDS-7 and IDS-8 were both about: a rule that tells you to, with no machine
# that does.
#
# The two lanes have genuinely different preconditions, and that is the whole
# design:
#   web    -- Playwright MCP against a running URL. gaspol can start the app.
#   mobile -- a physical device over USB debugging, or a booted emulator.
#             gaspol CANNOT provide either. It can detect, offer, and ask.
#
# The rule that matters most is the last block: a check that did not run is
# reported as not run. Never as passed. Same rule /security-review already has.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT="$REPO_ROOT/skills/gaspol-execute/scripts/detect-app-target"
RULE="$REPO_ROOT/skills/_shared/live-app-check.md"
VERIFY="$REPO_ROOT/skills/gaspol-verify/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

echo "test-live-app-check: the detector exists and self-tests..."

[ -x "$DETECT" ] || fail "scripts/detect-app-target is missing or not executable"
"$DETECT" --self-test >/dev/null 2>&1 || fail "detect-app-target --self-test does not pass"

echo "test-live-app-check: the detector keeps commands literal (same invariant as detect-stack)..."

has "$DETECT" "SECURITY INVARIANT" \
    "detect-app-target has no security invariant comment — its stdout is EXECUTED by the caller, exactly like detect-stack's"
has "$DETECT" "never interpolated\|never echoed\|LITERAL" \
    "the detector must state that no value read out of a scanned project file reaches stdout"

echo "test-live-app-check: the rule file names both lanes and their preconditions..."

[ -f "$RULE" ] || fail "skills/_shared/live-app-check.md is missing — the mechanism has no single source"
has "$RULE" "playwright"   "the web lane must name Playwright MCP"
has "$RULE" "USB debug"    "the mobile lane must name USB debugging as a precondition gaspol cannot satisfy"
has "$RULE" "emulator\|simulator" "the mobile lane must name the emulator/simulator alternative"
has "$RULE" "adb devices"  "the Android readiness probe must be named literally"
has "$RULE" "simctl"       "the iOS readiness probe must be named literally"

echo "test-live-app-check: three states per lane, and the third is not a pass..."

has "$RULE" "UNKNOWN" \
    "tooling-present-but-missing must be its own state — 'adb not installed' is not 'no device'"
has "$RULE" "not run" \
    "a lane that could not run must be RECORDED as not run"
grep -qiE 'never .{0,40}(record|report).{0,40}pass|never as passed|never recorded as passed' "$RULE" \
    || fail "the rule must say outright that a check which did not run is never recorded as passed — the /security-review rule, applied here"

echo "test-live-app-check: gaspol asks rather than assuming it can fix the environment..."

has "$RULE" "AskUserQuestion" \
    "with no device connected, gaspol must ask the user — it cannot plug in a phone"
has "$RULE" "offer" \
    "booting a simulator changes the user's machine: it is OFFERED, never taken silently (the extract-design-tokens precedent)"

echo "test-live-app-check: readiness is waited for by CONDITION, never by sleep..."

has "$RULE" "condition-based\|poll" \
    "waiting for the app to come up must be condition-based; gaspol-debug already documents why a fixed sleep is a flake generator"
grep -qiE '^\s*sleep [0-9]' "$RULE" \
    && fail "the rule itself demonstrates a fixed sleep — that is the anti-pattern it must forbid"

echo "test-live-app-check: adb is resolved, not merely looked up on PATH..."

# PATH-only detection failed on the first machine this ran on: adb sat at
# ~/Library/Android/sdk/platform-tools/adb with ANDROID_HOME unset. A false
# UNKNOWN means "STOP and ask" for a tool that is right there.
has "$DETECT" "ANDROID_HOME"      "adb resolution must consult ANDROID_HOME"
has "$DETECT" "Library/Android"   "adb resolution must know the macOS default SDK location"
has "$DETECT" "quote_cmd" \
    "a resolved path containing a space must be quoted, or the caller word-splits it and reports a file-not-found that sends the reader nowhere"
has "$RULE"   "unauthorized" \
    "the rule must handle a device that IS plugged in but has not accepted the USB prompt — telling the user to plug in a phone they already plugged in is the reply that wastes their time"
has "$RULE"   "logcat -c" \
    "the log must be cleared BEFORE the run, or the dump carries unrelated history and hides the real error"
has "$RULE"   "exec-out" \
    "screenshots must use exec-out; adb shell screencap corrupts the PNG on some hosts"

echo "test-live-app-check: evidence, not adjectives..."

has "$RULE" "screenshot"      "the check must produce a screenshot"
has "$RULE" "console"         "browser/device console errors must be captured"
has "$RULE" "looks (right|good|correct)\|looks fine" \
    "the rule must name the adjective-verdict it forbids"

echo "test-live-app-check: gaspol-verify's Live App Check now points at the mechanism..."

has "$VERIFY" "Live App Check" "the Live App Check subsection was removed rather than wired up"
has "$VERIFY" "detect-app-target" \
    "gaspol-verify still tells the reader to 'launch the app' without deriving HOW"
has "$VERIFY" "_shared/live-app-check.md" \
    "gaspol-verify must defer to the shared rule instead of restating it"

echo "test-live-app-check: the N/A path survives, and stays explicit..."

has "$VERIFY" "N/A\|not applicable" \
    "a pure-backend change must still be able to record the check as N/A with a reason — removing that would make the gate unusable and get it switched off"

echo "PASS: test-live-app-check — two lanes, real preconditions, and 'did not run' never reads as passed"
