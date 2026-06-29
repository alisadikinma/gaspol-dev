#!/usr/bin/env bash
# Smoke test for the gaspol visual companion server.
# Proves the curl-verifiable contract: server BOOTS, serves the keyed bootstrap (HTTP 200),
# REJECTS requests without the session key (HTTP 403 — the auth gate), and STOPS clean.
# Screen content itself is pushed over WebSocket to the browser (helper.js) — that render
# path needs a real browser and is validated live when the companion is used, not here.
# Usage: ./smoke-test.sh
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SESSION=""
fail() { echo "FAIL: $*"; [ -n "$SESSION" ] && "$DIR/stop-server.sh" "$SESSION" >/dev/null 2>&1; exit 1; }

INFO="$("$DIR/start-server.sh" --project-dir "$TMP" 2>&1)"
printf '%s' "$INFO" | grep -q server-started || fail "server did not start: $INFO"

URL="$(printf '%s' "$INFO" | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).url')"
SCREEN="$(printf '%s' "$INFO" | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).screen_dir')"
SESSION="$(dirname "$SCREEN")"
[ -d "$SCREEN" ] || fail "screen_dir missing: $SCREEN"
case "$SCREEN" in *".gaspol/brainstorm/"*) : ;; *) fail "session not under .gaspol/brainstorm: $SCREEN";; esac

BASE="${URL%%\?*}"
# 1) WITH key -> 200 (bootstrap shell served)
KCODE="$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
[ "$KCODE" = "200" ] || fail "keyed request not 200 (got $KCODE)"
# 2) WITHOUT key -> 403 (auth gate)
UCODE="$(curl -s -o /dev/null -w '%{http_code}' "$BASE")"
[ "$UCODE" = "403" ] || fail "unkeyed request not rejected (got $UCODE)"

"$DIR/stop-server.sh" "$SESSION" >/dev/null 2>&1
sleep 0.3
pgrep -f "visual-companion/scripts/server.cjs" >/dev/null 2>&1 && fail "server process still running after stop"
echo "PASS: boot ok, keyed=200, unkeyed=403 (auth gate), stopped clean"
