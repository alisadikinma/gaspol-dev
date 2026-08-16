#!/usr/bin/env bash
# test-next-ticket.sh — TDD test for skills/gaspol-execute/scripts/next-ticket
#
# Fixture: a CLAUDE.md-style file with a "## gaspol Ticket Counter" section.
# Asserts: running next-ticket on it prints exactly the next ticket id to
# stdout AND rewrites the fixture's "Last ticket:" line in place.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NEXT_TICKET="$REPO_ROOT/skills/gaspol-execute/scripts/next-ticket"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE="$TMP_DIR/CLAUDE.md"
cat >"$FIXTURE" <<'EOF'
## gaspol Ticket Counter

Prefix: IND
Last ticket: IND-80
EOF

echo "test-next-ticket: running next-ticket against fixture..."

OUTPUT="$("$NEXT_TICKET" "$FIXTURE")"

if [[ "$OUTPUT" != "IND-81" ]]; then
    echo "FAIL: expected stdout 'IND-81', got '$OUTPUT'" >&2
    exit 1
fi

if ! grep -qx "Last ticket: IND-81" "$FIXTURE"; then
    echo "FAIL: fixture 'Last ticket:' line was not rewritten to 'Last ticket: IND-81'" >&2
    echo "--- fixture contents ---" >&2
    cat "$FIXTURE" >&2
    exit 1
fi

echo "PASS: test-next-ticket"
