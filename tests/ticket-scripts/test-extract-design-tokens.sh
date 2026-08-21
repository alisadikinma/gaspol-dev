#!/usr/bin/env bash
# test-extract-design-tokens.sh — token extractor (IDS-7 Phase E)
#
# Existing projects already declare their colours somewhere. Extracting them
# means the gate works on a repository that never went through a gaspol
# brainstorm, instead of waiting for someone to hand-write a contract that
# nobody will hand-write.
#
# Two rules carry the weight:
#   1. Extraction is LITERAL. A colour must appear as a value in the source. An
#      unrecognised config shape emits NOTHING and says so — never a plausible
#      guess, which looks like it worked (KB: marker-file-is-not-proof).
#   2. The script never writes a file. Writing a contract into someone's repo
#      unasked is the same overreach as auto-installing a marketplace skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXTRACT="$REPO_ROOT/skills/gaspol-verify/scripts/extract-design-tokens"
AUDIT_DIR="$REPO_ROOT/skills/gaspol-verify/scripts"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- the mode git RECORDS, not the mode this working tree happens to have ----
# IDS-6's exact failure: task-brief was committed 100644 while the local tree
# had the executable bit, so every test passed on the branch and the script was
# non-executable for anyone who checked it out.
MODE="$(git -C "$REPO_ROOT" ls-files -s skills/gaspol-verify/scripts/extract-design-tokens | cut -d' ' -f1)"
[ "$MODE" = "100755" ] \
    || fail "extract-design-tokens is recorded in git as '${MODE:-<untracked>}', not 100755 — it will not be executable on checkout"

# --- source 1: tailwind.config.js -------------------------------------------

TW="$TMP_DIR/tw"
mkdir -p "$TW"
cat >"$TW/tailwind.config.js" <<'EOF'
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#2563EB',
        ink: "#1F2937",
      },
    },
  },
};
EOF

echo "test-extract-design-tokens: tailwind..."
OUT="$("$EXTRACT" "$TW")" || fail "extractor failed on a tailwind.config.js fixture"
echo "$OUT" | grep -q 'primary: "#2563eb"' \
    || fail "tailwind colour not extracted or not normalised — got: $OUT"
echo "$OUT" | grep -q 'ink: "#1f2937"' || fail "second tailwind colour missing — got: $OUT"

# --- the output must be valid input to Phase A's parser ---------------------
# The pair most likely to drift silently: two halves that each look right and
# do not actually connect. Assert the round trip, do not assume it.
echo "test-extract-design-tokens: round trip into load_design_contract..."
RT="$TMP_DIR/roundtrip"
mkdir -p "$RT"
"$EXTRACT" "$TW" >"$RT/DESIGN.md"
PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('$RT')
assert c is not None, 'extractor output did not parse as a contract at all'
assert c['colors'].get('primary') == '#2563eb', f\"round trip lost the token: {c['colors']}\"
" || fail "extractor output does not parse under load_design_contract — the two halves do not connect"

# --- source 2: CSS custom properties ----------------------------------------

CSS="$TMP_DIR/css"
mkdir -p "$CSS/src"
cat >"$CSS/src/theme.css" <<'EOF'
:root {
  --color-primary: #2563EB;
  --brand-accent: #F59E0B;
  --spacing-sm: 4px;
}
EOF

echo "test-extract-design-tokens: css custom properties..."
OUT="$("$EXTRACT" "$CSS")" || fail "extractor failed on a CSS custom-properties fixture"
echo "$OUT" | grep -q '#2563eb' || fail "CSS custom property colour not extracted — got: $OUT"
echo "$OUT" | grep -q '4px' \
    && fail "a non-colour custom property (--spacing-sm: 4px) leaked into the colors map — got: $OUT"

# --- source 3: theme.json ----------------------------------------------------

TJ="$TMP_DIR/tj"
mkdir -p "$TJ"
printf '{"colors": {"primary": "#2563EB", "surface": "#FFFFFF"}}\n' >"$TJ/theme.json"

echo "test-extract-design-tokens: theme.json..."
OUT="$("$EXTRACT" "$TJ")" || fail "extractor failed on a theme.json fixture"
echo "$OUT" | grep -q '#2563eb' || fail "theme.json colour not extracted — got: $OUT"

# --- unrecognised shape: emit nothing, and SAY so ---------------------------

EMPTY="$TMP_DIR/empty"
mkdir -p "$EMPTY"
printf 'export default { plugins: [] }\n' >"$EMPTY/tailwind.config.js"

echo "test-extract-design-tokens: unrecognised shape..."
set +e
OUT="$("$EXTRACT" "$EMPTY" 2>&1)"
rc=$?
set -e
[ "$rc" != "0" ] \
    || fail "an unrecognised config exited 0 — no tokens found must be a distinct, non-silent outcome"
echo "$OUT" | grep -qi 'no colour\|no color\|not recognis\|not recogniz\|found no' \
    || fail "the empty case does not say why nothing was extracted: $OUT"
echo "$OUT" | grep -qE '#[0-9a-fA-F]{3,8}' \
    && fail "the extractor invented a colour for an unrecognised config — extraction must be literal"

# --- the script never writes anything ---------------------------------------

echo "test-extract-design-tokens: writes nothing..."
BEFORE="$(find "$TW" -type f | sort)"
"$EXTRACT" "$TW" >/dev/null
AFTER="$(find "$TW" -type f | sort)"
[ "$BEFORE" = "$AFTER" ] \
    || fail "the extractor created or removed a file — it must be stdout-only; the write is offered by gaspol-verify, never taken"

echo "PASS: test-extract-design-tokens"
