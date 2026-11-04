#!/bin/zsh
# Stop hook: Claude may not claim "done" while the work is not committed or the
# gaspol ledger is older than the last commit.
#
# Why: Ali had to ask "kok gak ada commit dan update ledger?" on 2026-10-18,
# 10-21 and 10-23. A prose rule did not stop it; a Stop hook can.
#
# Blocks (exit 2, reason on stderr) only when ALL of these hold:
#   1. cwd is in a git work tree that has .gaspol/progress/PROGRESS-*.md
#   2. the last assistant message claims completion (selesai, beres, done, ...)
#   3. tracked or new files outside .gaspol/ and .claude/ are uncommitted,
#      OR the newest ledger is older than HEAD's commit time
# Asking a question mid-work, or a repo without a gaspol ledger, is never blocked.
# Blocks at most twice per session and HEAD, so a commit Ali forbade cannot loop.
# Any internal error exits 0: a broken gate must not trap the session.

INPUT="$(cat 2>/dev/null)"
eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
for k in ("cwd", "transcript_path", "session_id"):
    print("H_%s=%s" % (k.upper(), shlex.quote(str(d.get(k) or ""))))
' 2>/dev/null)" || exit 0

CWD="${H_CWD:-$PWD}"
ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LEDGERS=("$ROOT"/.gaspol/progress/PROGRESS-*.md(N.om))
[ ${#LEDGERS} -eq 0 ] && exit 0
LEDGER="${LEDGERS[1]}"

# 2. Last assistant message claims completion?
CLAIM="$(python3 - "$H_TRANSCRIPT_PATH" <<'EOF' 2>/dev/null
import json, re, sys
path = sys.argv[1]
last = ""
try:
    for line in open(path, errors="ignore"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "assistant":
            continue
        c = (d.get("message") or {}).get("content")
        if isinstance(c, list):
            t = "".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
            if t.strip():
                last = t
except OSError:
    pass
pat = (r"\b(selesai|beres|sudah (di)?kerjakan|sudah jadi|siap (di)?merge|done|completed?|finished|"
       r"all (tests )?pass(ed|ing)?|semua (tes )?lulus)\b")
print("yes" if re.search(pat, last, re.IGNORECASE) else "no")
EOF
)"
[ "$CLAIM" = "yes" ] || exit 0

# 3. What is missing?
REASONS=()
DIRTY="$(git -C "$ROOT" status --porcelain --untracked-files=normal 2>/dev/null \
  | awk '{p=substr($0,4)} p !~ /^"?\.(gaspol|claude)\//' | head -5)"
[ -n "$DIRTY" ] && REASONS+=("Ada perubahan yang belum di-commit:\n$DIRTY")

HEAD_T="$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null)"
LEDGER_T="$(stat -f %m "$LEDGER" 2>/dev/null || stat -c %Y "$LEDGER" 2>/dev/null)"
if [ -n "$HEAD_T" ] && [ -n "$LEDGER_T" ] && [ "$HEAD_T" -gt $((LEDGER_T + 60)) ]; then
  REASONS+=("Ledger ${LEDGER:t} belum diperbarui sejak commit terakhir ($(git -C "$ROOT" log -1 --format='%h %s' | cut -c1-60)).")
fi
[ ${#REASONS} -eq 0 ] && exit 0

# Loop guard: at most 2 blocks per session + HEAD.
KEY="$(printf '%s' "${H_SESSION_ID:-nosession}-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)" | tr -cd 'A-Za-z0-9-')"
CNT_FILE="${TMPDIR:-/tmp}/stop-done-gate-$KEY"
CNT=$(cat "$CNT_FILE" 2>/dev/null || echo 0)
[ "$CNT" -ge 2 ] && exit 0
echo $((CNT + 1)) > "$CNT_FILE" 2>/dev/null

{
  print "stop-done-gate: kamu menyatakan selesai, tapi:"
  for r in "${REASONS[@]}"; do print -- "- $r"; done
  print "Commit pekerjaannya dan perbarui ${LEDGER#$ROOT/} (status fase + hash commit) sebelum bilang selesai."
  print "Kalau Ali melarang commit, sebutkan itu dengan jelas di jawabanmu."
} >&2
exit 2
