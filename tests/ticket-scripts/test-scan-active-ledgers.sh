#!/usr/bin/env bash
# test-scan-active-ledgers.sh — TDD test for
# skills/gaspol-execute/scripts/scan-active-ledgers
#
# Fixture dir with two progress ledgers: one still active (last line ends
# "— NEXT: Phase 3"), one done (last line ends "— NEXT: DONE"). Asserts
# stdout is exactly the active one's basename, nothing else.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCAN_LEDGERS="$REPO_ROOT/skills/gaspol-execute/scripts/scan-active-ledgers"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LEDGER_DIR="$TMP_DIR/.gaspol/progress"
mkdir -p "$LEDGER_DIR"

cat >"$LEDGER_DIR/progress-IND-79.md" <<'EOF'
# Progress log IND-79

Phase 1 done — NEXT: Phase 2
Phase 2 done — NEXT: Phase 3
EOF

cat >"$LEDGER_DIR/progress-IND-80.md" <<'EOF'
# Progress log IND-80

Phase 1 done — NEXT: Phase 2
Phase 2 done — NEXT: DONE
EOF

echo "test-scan-active-ledgers: running scan-active-ledgers against fixture dir..."

OUTPUT="$("$SCAN_LEDGERS" "$LEDGER_DIR")"

if [[ "$OUTPUT" != "progress-IND-79.md" ]]; then
    echo "FAIL: expected stdout 'progress-IND-79.md', got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "PASS: test-scan-active-ledgers"
