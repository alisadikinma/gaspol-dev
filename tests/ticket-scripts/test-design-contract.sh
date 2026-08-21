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
    && fail "with no DESIGN.md, findings gained a severity field — the no-contract path must stay byte-identical to pre-IDS-7 output"

# --- Phase C: the --design-system flag is read, or gone. Never both. --------

echo "test-design-contract: no parsed-but-unread flag..."
if grep -q '"--design-system"' "$AUDIT_DIR/design_audit.py"; then
    grep -q 'args\.design_system\|design_system' "$AUDIT_DIR/design_audit.py" \
        || fail "--design-system is still declared and never read — that unread flag is the defect this phase exists to kill"
fi

echo "PASS: test-design-contract"
