#!/usr/bin/env zsh
# hooks/stop-done-gate.sh (Stop hook): a "done" claim with uncommitted work, or with a ledger older
# than the last commit, is blocked (exit 2). Everything else passes (exit 0).
# Real case: Ali had to ask "kok gak ada commit dan update ledger?" on 2026-10-18, 10-21 and 10-23.
# Not the same as skills/gaspol-verify/scripts/ledger-gate (that one checks a ledger exists).
REPO_ROOT="${0:A:h:h:h}"
GATE="$REPO_ROOT/hooks/stop-done-gate.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
pass() { echo "PASS: $1"; }

mk_repo() {  # $1=dir: repo with a gitignored active ledger and one commit
  mkdir -p "$1/.gaspol/progress" "$1/src"
  ( cd "$1" && git init -q && git config user.email t@t && git config user.name t \
    && print ".gaspol/" > .gitignore && print x > src/a.ts && git add -A && git commit -qm init \
    && print "| A | IN PROGRESS |" > .gaspol/progress/PROGRESS-T-1.md )
}
tx() {  # $1=file $2=last assistant text
  python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":sys.argv[2]}]}}))' x "$2" > "$1"
}
gate() {  # $1=repo $2=transcript $3=session -> exit code
  printf '{"hook_event_name":"Stop","cwd":"%s","transcript_path":"%s","session_id":"%s"}' "$1" "$2" "${3:-s$RANDOM$RANDOM}" \
    | zsh "$GATE" >/dev/null 2>"$TMP/err"; print $?
}

tx "$TMP/done.jsonl" "Phase B selesai, semua tes lulus."
tx "$TMP/ask.jsonl" "Mau pakai opsi A atau B?"

mk_repo "$TMP/a"; print y >> "$TMP/a/src/a.ts"
[ "$(gate "$TMP/a" "$TMP/done.jsonl")" = 2 ] && pass "done + uncommitted -> blocked" || fail "done + uncommitted not blocked"
grep -q "belum di-commit" "$TMP/err" && pass "reason names the uncommitted files" || fail "reason: $(cat "$TMP/err")"

mk_repo "$TMP/b"; touch -t 202601010000 "$TMP/b/.gaspol/progress/PROGRESS-T-1.md"
(cd "$TMP/b" && print z > src/b.ts && git add -A && git commit -qm feat)
[ "$(gate "$TMP/b" "$TMP/done.jsonl")" = 2 ] && pass "done + stale ledger -> blocked" || fail "done + stale ledger not blocked"

mk_repo "$TMP/c"; (cd "$TMP/c" && print z > src/b.ts && git add -A && git commit -qm feat && print "| B | DONE |" >> .gaspol/progress/PROGRESS-T-1.md)
[ "$(gate "$TMP/c" "$TMP/done.jsonl")" = 0 ] && pass "committed + ledger updated -> passes" || fail "correct work blocked"

[ "$(gate "$TMP/a" "$TMP/ask.jsonl")" = 0 ] && pass "question mid-work -> passes" || fail "question mid-work blocked"

mkdir -p "$TMP/d"; (cd "$TMP/d" && git init -q && print x > f && git add -A && git -c user.email=t@t -c user.name=t commit -qm i && print y >> f)
[ "$(gate "$TMP/d" "$TMP/done.jsonl")" = 0 ] && pass "repo without gaspol ledger -> passes" || fail "repo without ledger blocked"

mkdir -p "$TMP/nogit"
[ "$(gate "$TMP/nogit" "$TMP/done.jsonl")" = 0 ] && pass "cwd outside git -> passes" || fail "non-git cwd blocked"
[ "$(print 'not json' | zsh "$GATE" >/dev/null 2>&1; print $?)" = 0 ] && pass "garbage stdin -> passes" || fail "garbage stdin blocked"

S="loop$RANDOM"
r1=$(gate "$TMP/a" "$TMP/done.jsonl" $S); r2=$(gate "$TMP/a" "$TMP/done.jsonl" $S); r3=$(gate "$TMP/a" "$TMP/done.jsonl" $S)
[ "$r1$r2$r3" = "220" ] && pass "at most 2 blocks per session and HEAD" || fail "loop guard: $r1$r2$r3"
rm -f "${TMPDIR:-/tmp}"/stop-done-gate-$S-*

grep -q 'stop-done-gate.sh' "$REPO_ROOT/hooks/hooks.json" && pass "registered as Stop hook" || fail "not in hooks.json"

[ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "$FAILED FAILED"; exit 1; }
