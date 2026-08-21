#!/usr/bin/env bash
# test-design-contract.sh — DESIGN.md token contract (IDS-7 Phase A, C, D)
#
# Layer 4's design sub-check could not judge compliance because it never loaded
# a token list: design_audit.py accepted --design-system and grep for
# `design_system` in the file returned zero hits. This asserts the contract is
# really parsed, that the three states stay distinct, and that the gate blocks
# by CSS role rather than blocking on every colour it sees.
#
# The three states matter more than the happy path. KB precedent
# `marker-file-is-not-proof-tool-installed`: a present file proves intent, never
# that it parses. A broken contract must raise, never return an empty dict — an
# empty dict reads as "nothing violated" and ships a silent pass.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/skills/gaspol-verify/scripts"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Run a python snippet with design_audit importable. Prints the snippet's stdout.
py() { PYTHONPATH="$AUDIT_DIR" python3 -c "$1"; }

# --- fixtures ---------------------------------------------------------------

GOOD="$TMP_DIR/good"
mkdir -p "$GOOD"
cat >"$GOOD/DESIGN.md" <<'EOF'
---
colors:
  primary: "#2563EB"
  text:    "#1F2937"
  border:  "#E5E7EB"
  surface: "#FFF"
fonts:
  heading: "Poppins"
  body:    "Inter"
---

# Design

Prose below the frontmatter is ignored.
EOF

MISSING="$TMP_DIR/missing"
mkdir -p "$MISSING"

BROKEN="$TMP_DIR/broken"
mkdir -p "$BROKEN"
printf '# Design\n\nNo frontmatter here at all.\n' >"$BROKEN/DESIGN.md"

NOCOLORS="$TMP_DIR/nocolors"
mkdir -p "$NOCOLORS"
printf -- '---\nfonts:\n  body: "Inter"\n---\n' >"$NOCOLORS/DESIGN.md"

# --- Phase A: state 1 — no DESIGN.md returns None, does NOT raise ------------

echo "test-design-contract: state 1 (absent)..."
OUT="$(py "
import design_audit as d
print(repr(d.load_design_contract('$MISSING')))
")" || fail "load_design_contract raised on an absent DESIGN.md — absent must be a supported state, not an error"
[ "$OUT" = "None" ] || fail "absent DESIGN.md must return None, got: $OUT"

# --- Phase A: state 2 — present and parses ----------------------------------

echo "test-design-contract: state 2 (loaded)..."
OUT="$(py "
import design_audit as d
c = d.load_design_contract('$GOOD')
print(sorted(c['colors'].values()))
print(sorted(c['fonts'].values()))
")"
echo "$OUT" | grep -q '#2563eb' \
    || fail "hex must be normalised to lowercase; contract values were: $OUT"
echo "$OUT" | grep -q '#ffffff' \
    || fail "3-digit hex #FFF must expand to #ffffff, else the same colour reads as two tokens"
echo "$OUT" | grep -q 'Poppins' || fail "fonts were not parsed from the contract"

# --- Phase A: state 3 — present but unparseable RAISES ----------------------

echo "test-design-contract: state 3 (UNKNOWN)..."
for bad in "$BROKEN" "$NOCOLORS"; do
    set +e
    py "
import design_audit as d
d.load_design_contract('$bad')
" >/dev/null 2>&1
    rc=$?
    set -e
    [ "$rc" != "0" ] \
        || fail "$(basename "$bad"): a present-but-unparseable DESIGN.md must raise DesignContractError, not return quietly — a silent empty contract reads as 'nothing violated'"
done

# The raised type is named, so callers can distinguish it from an IO error.
py "
import design_audit as d
assert issubclass(d.DesignContractError, Exception)
" || fail "DesignContractError is not defined as an exception class"

# --- No new dependency ------------------------------------------------------

if grep -qE '^\s*(import|from)\s+(yaml|ruamel|toml|pydantic)' "$AUDIT_DIR/design_audit.py"; then
    fail "design_audit.py grew a third-party parser dependency — the frontmatter shape is flat, stdlib covers it"
fi

# --- Phase C: the gate blocks by CSS ROLE, not on every colour it sees ------
#
# An off-contract colour is not uniformly a defect. A one-off rgba(0,0,0,0.05)
# shadow is ordinary craft, not drift. Blocking on it produces false alarms,
# false alarms get the gate switched off, and a disabled gate is worth less than
# a noisy one. The split is decided by CSS property name so it needs no
# judgement and cannot drift between runs.

GATE="$TMP_DIR/gate"
mkdir -p "$GATE/src"
cp "$GOOD/DESIGN.md" "$GATE/DESIGN.md"
cat >"$GATE/src/App.tsx" <<'EOF'
export const App = () => (
  <div className="bg-[#2563eb] text-[#1F2937]">
    <span className="bg-[#123456]">off contract, structural</span>
  </div>
);
EOF
# Decorative cases must use declarations the scanner actually matches. The
# existing HARDCODED_COLOR_PATTERNS key off a `color|background|bg|border|
# fill|stroke` prefix, so `shadow-[...]` is invisible to them — asserting on it
# would test the fixture, not the gate.
cat >"$GATE/src/card.css" <<'EOF'
.btn { background: #123456; }
.card { border-color: rgba(0, 0, 0, 0.05); }
.ring { outline-color: #123456; }
.ok { color: #2563EB; }
EOF

echo "test-design-contract: role split..."
OUT="$(cd "$GATE" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import json, design_audit as d
c = d.load_design_contract('.')
f = d.scan_files(['src/App.tsx', 'src/card.css'], contract=c)
for finding in f:
    for item in finding['hardcoded_colors']:
        print(item['severity'], item['match'])
")" || fail "scan_files does not accept a contract yet, or findings carry no severity"

echo "$OUT" | grep -q 'BLOCKING.*123456' \
    || fail "an off-contract structural colour must be BLOCKING — got: $OUT"
echo "$OUT" | grep -qi 'WARN.*rgba' \
    || fail "an off-contract translucent rgba() must be WARN, not BLOCKING — got: $OUT"
# The property-name half of the rule, separate from the alpha half: an OPAQUE
# off-contract hex on a decorative property is still only a WARN. Assert the
# exact count -- `grep -c WARN | grep -v '^1$'` would also pass on ZERO warnings,
# which proves nothing (KB: vacuous-assertion-proves-nothing).
WARN_COUNT="$(echo "$OUT" | grep -c 'WARN' | tr -d ' ')"
[ "$WARN_COUNT" = "2" ] \
    || fail "expected exactly 2 WARN findings (translucent rgba + opaque outline-color), got $WARN_COUNT — if 1, the property-name rule never fires and only the alpha rule does. Output: $OUT"

# A colour that IS in the contract produces NO finding at all. Not a
# low-severity one -- compliant means silent, or the report is unreadable.
if echo "$OUT" | grep -qi '2563eb'; then
    fail "a colour present in the contract was still reported — compliant must mean silent, got: $OUT"
fi
# Case-insensitive: the contract holds #1f2937, the source writes #1F2937.
if echo "$OUT" | grep -qi '1f2937'; then
    fail "matching is case-sensitive — #1F2937 in source did not match #1f2937 in the contract"
fi

# --- Phase C: a decorative token on the SAME LINE must not downgrade a
#     structural violation. Classifying on the whole line turned every minified
#     stylesheet and every Tailwind className string into a free pass:
#     `.a { background: #ff0000; box-shadow: 0 1px 2px #000 }` reported WARN.
#     Scope is the DECLARATION, not the line and not the bare match.

echo "test-design-contract: declaration scoping..."
MIX="$TMP_DIR/mixed"
mkdir -p "$MIX/src"
cp "$GOOD/DESIGN.md" "$MIX/DESIGN.md"
cat >"$MIX/src/min.css" <<'EOF'
.a { background: #ff0000; box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
EOF
cat >"$MIX/src/Tw.tsx" <<'EOF'
export const T = () => <div className="shadow-[#654321] bg-[#999999]">x</div>;
EOF
OUT="$(cd "$MIX" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('.')
for f in d.scan_files(['src/min.css', 'src/Tw.tsx'], contract=c):
    for i in f['hardcoded_colors']:
        print(i['severity'], i['match'])
")"
echo "$OUT" | grep -q 'BLOCKING.*#ff0000' \
    || fail "background: #ff0000 downgraded to WARN because a box-shadow shared its line — one minified CSS line then defeats the whole gate. Got: $OUT"
echo "$OUT" | grep -q 'BLOCKING.*bg-\[#999999\]' \
    || fail "bg-[#999999] downgraded because shadow-[…] sat in the same className string. Got: $OUT"
# And the decorative ones on those very same lines stay WARN, so the fix
# narrowed the scope rather than deleting the WARN branch.
echo "$OUT" | grep -qi 'WARN.*rgba' \
    || fail "the box-shadow rgba() on the same line should still be WARN — the fix removed the WARN branch instead of scoping it. Got: $OUT"
echo "$OUT" | grep -q 'WARN.*shadow-\[#654321\]' \
    || fail "shadow-[#654321] is not detected at all — the docs promise it WARNs, so either detect it or stop promising it. Got: $OUT"

# --- Phase C: FONTS are enforced too, not just parsed -----------------------
#     The contract has a `fonts:` map and the docs claim fonts are checked.
#     Parsing it and never reading it is defect D1's exact shape, rebuilt
#     inside the fix for D1.

echo "test-design-contract: fonts are enforced..."
FNT="$TMP_DIR/fonts"
mkdir -p "$FNT/src"
cp "$GOOD/DESIGN.md" "$FNT/DESIGN.md"   # fonts: heading Poppins, body Inter
cat >"$FNT/src/type.css" <<'EOF'
.h { font-family: Poppins, sans-serif; }
.x { font-family: "Comic Sans MS", cursive; }
EOF
OUT="$(cd "$FNT" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('.')
for f in d.scan_files(['src/type.css'], contract=c):
    for i in f['hardcoded_fonts']:
        print(i.get('severity', 'NO-SEVERITY'), i['match'])
")"
echo "$OUT" | grep -q 'NO-SEVERITY' \
    && fail "font findings carry no severity — the contract's fonts: map is parsed and never read, which is exactly the --design-system defect this ticket exists to kill. Got: $OUT"
echo "$OUT" | grep -qi 'BLOCKING' \
    || fail "an off-contract font (Comic Sans MS) was not BLOCKED. Got: $OUT"
if echo "$OUT" | grep -qi 'poppins'; then
    fail "Poppins IS in the contract and must produce no finding — compliant means silent. Got: $OUT"
fi

# --- A colors-only contract must not SILENCE font findings ------------------
#     extract-design-tokens emits colours only, so this is the documented
#     onboarding path. Before this guard, adopting a contract turned
#     "Hardcoded fonts: 2" into "Hardcoded fonts: 0" — which reads as
#     checked-and-clean when nothing was checked. Three states, like colours:
#     declared+used -> silent, declared+violated -> BLOCKING, no fonts map ->
#     reported unjudged AND recorded as a gate that did not run.

echo "test-design-contract: colors-only contract does not silence fonts..."
CONLY="$TMP_DIR/colorsonly"
mkdir -p "$CONLY/src"
printf -- '---\ncolors:\n  primary: "#2563eb"\n---\n' >"$CONLY/DESIGN.md"
printf '.h { font-family: Poppins; }\n.x { font-family: Comic Sans; }\n' >"$CONLY/src/t.css"

NO_CONTRACT_FONTS="$(cd "$CONLY" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
print(sum(len(f['hardcoded_fonts']) for f in d.scan_files(['src/t.css'])))
")"
WITH_CONTRACT_FONTS="$(cd "$CONLY" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('.')
print(sum(len(f['hardcoded_fonts']) for f in d.scan_files(['src/t.css'], contract=c)))
")"
[ "$WITH_CONTRACT_FONTS" = "$NO_CONTRACT_FONTS" ] \
    || fail "adopting a colors-only DESIGN.md changed font findings from $NO_CONTRACT_FONTS to $WITH_CONTRACT_FONTS — a contract with no fonts: map must leave font reporting exactly as it was, not silence it"

# ...and the report must SAY the font gate did not run, rather than printing
# "Hardcoded fonts: N" as though it had been judged.
OUT="$(cd "$CONLY" && python3 "$AUDIT_DIR/design_audit.py" . 2>&1 || true)"
echo "$OUT" | grep -qi 'font-gate: not run' \
    || fail "a contract with no fonts: map must record 'font-gate: not run' — otherwise the font count reads as judged. Got: $OUT"

# --- Phase C: no DESIGN.md must behave exactly as before --------------------

echo "test-design-contract: no-contract regression..."
NOC="$TMP_DIR/nocontract"
mkdir -p "$NOC/src"
cp "$GATE/src/App.tsx" "$NOC/src/App.tsx"
BEFORE="$(cd "$NOC" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import json, design_audit as d
print(json.dumps(d.scan_files(['src/App.tsx']), sort_keys=True))
")"
echo "$BEFORE" | grep -q 'severity' \
    && fail "with no DESIGN.md, findings gained a severity field — the no-contract path must stay unchanged from pre-IDS-7 output"

# The checkbox excludes style files because D4 makes them scanned for the first
# time. That exclusion has to be a TESTED claim, not a loophole: prove a .css
# file really is scanned now, so "style files may differ" means D4 works rather
# than that nobody looked.
printf '.q { background: #abcdef; }\n' >"$NOC/src/s.css"
STYLE_SCANNED="$(cd "$NOC" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
print(len(d.scan_files(['src/s.css'])))
")"
[ "$STYLE_SCANNED" = "1" ] \
    || fail "a .css file is still not scanned — the plan checkbox excludes style files on the grounds that D4 changed them, so if D4 does not work the exclusion is a loophole"

# --- Phase C: the --design-system flag is read, or gone. Never both. --------

echo "test-design-contract: no parsed-but-unread flag..."
if grep -q '"--design-system"' "$AUDIT_DIR/design_audit.py"; then
    grep -q 'args\.design_system\|design_system' "$AUDIT_DIR/design_audit.py" \
        || fail "--design-system is still declared and never read — that unread flag is the defect this phase exists to kill"
fi

# --- Phase D: WCAG AA contrast is COMPUTED, not merely claimed --------------
#
# The docstring listed "contrast issues" and gaspol-verify/SKILL.md claimed
# "WCAG AA contrast ratios". grep for `contrast` in the script returned one hit:
# that docstring line. Zero computation. Same defect class as the gaspol-finish
# Step 5 checkbox IDS-6 fixed — a step recorded as passed that never ran.

echo "test-design-contract: contrast ratio..."
py "
import design_audit as d
r = d.contrast_ratio('#ffffff', '#000000')
assert abs(r - 21.0) < 0.01, f'white on black must be 21.0, got {r}'
assert abs(d.contrast_ratio('#000000', '#ffffff') - 21.0) < 0.01, 'ratio must be order-independent'
assert abs(d.contrast_ratio('#ffffff', '#ffffff') - 1.0) < 0.01, 'identical colours must be 1.0'
" || fail "contrast_ratio is missing or wrong"

# The AA boundary is tested, not only the trivial extremes. #767676 on white is
# the canonical just-passing pair (~4.54); #777777 just fails (~4.48). A test
# that only checks black-on-white passes against almost any broken formula.
py "
import design_audit as d
ok  = d.contrast_ratio('#767676', '#ffffff')
bad = d.contrast_ratio('#777777', '#ffffff')
assert ok >= 4.5,  f'#767676 on white must meet AA 4.5:1, got {ok:.2f}'
assert bad < 4.5,  f'#777777 on white must fail AA 4.5:1, got {bad:.2f}'
" || fail "the AA 4.5:1 boundary is wrong — the formula passes the easy case but not the real threshold"

# A contract whose text/surface pair fails AA is reported, naming both tokens.
LOWC="$TMP_DIR/lowcontrast"
mkdir -p "$LOWC"
printf -- '---\ncolors:\n  text: "#777777"\n  surface: "#ffffff"\n---\n' >"$LOWC/DESIGN.md"
OUT="$(py "
import design_audit as d
for f in d.check_contract_contrast(d.load_design_contract('$LOWC')):
    print(f['severity'], f['message'])
")" || fail "check_contract_contrast is missing"
echo "$OUT" | grep -qi 'text' || fail "the low-contrast finding does not name the text token: $OUT"
echo "$OUT" | grep -qi 'surface' || fail "the low-contrast finding does not name the surface token: $OUT"
# Assert the MEASURED ratio, not the AA constant. `grep '4\.5'` passed
# unconditionally because "below WCAG AA 4.5:1" contains it whatever the
# computation did — a vacuous assertion (KB: vacuous-assertion-proves-nothing).
# #777777 on #ffffff measures 4.48, a number that appears only if it was computed.
echo "$OUT" | grep -q '4\.48:1' \
    || fail "the finding does not quote the MEASURED ratio (expected 4.48:1 for #777777 on white): $OUT"

# No determinable pairing -> say so. Never invent a pairing and grade it.
NOPAIR="$TMP_DIR/nopair"
mkdir -p "$NOPAIR"
printf -- '---\ncolors:\n  brand: "#2563EB"\n  accent: "#F59E0B"\n---\n' >"$NOPAIR/DESIGN.md"
OUT="$(py "
import design_audit as d
for f in d.check_contract_contrast(d.load_design_contract('$NOPAIR')):
    print(f['severity'], f['message'])
")"
echo "$OUT" | grep -qi 'no declared' \
    || fail "with no foreground/background pairing the check must say so, not grade an assumed pair: $OUT"

echo "PASS: test-design-contract"
