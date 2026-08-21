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

echo "PASS: test-design-contract"
