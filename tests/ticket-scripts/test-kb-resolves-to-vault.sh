#!/usr/bin/env bash
# test-kb-resolves-to-vault.sh — the relocation survives a clean environment (IDS-8 Phase G)
#
# The whole ticket turns on this: with GASPOL_KB_LOCAL unset, resolution must
# land on the configured store, not the default. If it falls through, local-only
# mode auto-creates ~/.claude/gaspol-knowledge and the duplication grows back —
# a migration that undoes itself the first time a process does not inherit the
# right shell.
#
# This test is machine-shaped on purpose: it asserts the CONTRACT (a configured
# kb_local wins over the default, with the environment variable removed), not
# any particular person's vault path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KBROOT="$REPO_ROOT/skills/_shared/kb-root"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-resolves-to-vault: a configured kb_local beats the default with a clean env..."
H="$(mktemp -d)"; mkdir -p "$H/.claude" "$H/elsewhere/store" "$H/.claude/gaspol-knowledge"
printf '{"kb_local": "%s/elsewhere/store"}\n' "$H" > "$H/.claude/gaspol-config.json"
GOT="$(env -u GASPOL_KB_LOCAL HOME="$H" "$KBROOT")" \
    || fail "resolver exited non-zero with a valid config"
[ "$GOT" = "$H/elsewhere/store" ] \
    || fail "with GASPOL_KB_LOCAL unset the KB resolved to '$GOT', not the configured path — the default would win and the old store grows back"

echo "test-kb-resolves-to-vault: the default is NOT chosen even though it exists..."
case "$GOT" in *gaspol-knowledge) fail "resolution fell through to the default directory despite a valid kb_local" ;; esac
rm -rf "$H"

echo "test-kb-resolves-to-vault: this machine's own config points somewhere that exists..."
# Informational on a fresh clone (no config = the default, which is correct);
# a HARD assertion once a config exists, because a config naming a missing
# directory is the UNKNOWN state and must never be left sitting.
if [ -f "$HOME/.claude/gaspol-config.json" ]; then
    if ! OUT="$("$KBROOT" 2>&1)"; then
        fail "this machine has a gaspol-config.json and the resolver reports: $OUT"
    fi
    echo "  resolved: $OUT"
else
    echo "  no gaspol-config.json on this machine — default applies (not a failure)"
fi

echo "PASS: test-kb-resolves-to-vault"
