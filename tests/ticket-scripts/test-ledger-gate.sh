#!/usr/bin/env bash
# test-ledger-gate.sh — the four exit states of skills/gaspol-verify/scripts/ledger-gate
#                       (IDS-19 Phase A)
#
# The gate exists because the progress ledger had exactly one creator
# (gaspol-plan step 7) and no reader that checked it existed. Measured across all
# 18 IDS tickets in this repository, the ledger was present if and only if a plan
# file was: IDS-3, IDS-5, IDS-9 and IDS-15 had neither.
#
# Every case below builds a throwaway git repository under mktemp -d and removes
# it. Nothing here touches the real repository, and no case depends on the
# working directory the suite happens to be run from — the gate resolves paths
# against `git rev-parse --show-toplevel`, and case 19 proves it by invoking the
# gate from a foreign directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/skills/gaspol-verify/scripts/ledger-gate"

fail() { echo "FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

CASE_N=0
REPO=""
BASE=""

# new_repo — a fresh git repo with one seed commit; sets $REPO and $BASE.
new_repo() {
    CASE_N=$((CASE_N + 1))
    REPO="$WORK/case-$CASE_N"
    mkdir -p "$REPO/docs/plans" "$REPO/skills/foo"
    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.email "t@example.invalid"
    git -C "$REPO" config user.name "t"
    echo seed > "$REPO/seed.txt"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "base"
    BASE="$(git -C "$REPO" rev-parse HEAD)"
}

commit_all() { git -C "$REPO" add -A && git -C "$REPO" commit -q -m "${1:-work}"; }

# write_plan <file> <ticket>
write_plan() {
    printf '**Ticket:** %s\n**Ledger:** .gaspol/progress/PROGRESS-%s.md\n\n## Goal\n\nx\n' \
        "$2" "$2" > "$REPO/$1"
}

# write_ledger <path> <ticket> — a structurally VALID ledger in the IDS-19 shape.
write_ledger() {
    mkdir -p "$(dirname "$REPO/$1")"
    cat > "$REPO/$1" <<LEDGER
# PROGRESS — $2: contoh

**Ticket:** $2

## Pre-flight

| Gate | Result |
|---|---|
| Git clean | PASS |

## Keputusan saat jalan

(kosong)

## Checklist

### [ ] Phase A: contoh
- [ ] satu langkah

## Phase log

| Phase | Status | Commit |
|---|---|---|

## Utang terbuka

(kosong)

## Log
- 2026-08-24 plan ditulis — NEXT: Phase A
LEDGER
}

# run_gate [args...] — runs the gate from inside $REPO; sets $RC and $OUT.
run_gate() {
    set +e
    OUT="$(cd "$REPO" && "$GATE" "$@" 2>/dev/null)"
    RC=$?
    set -e
}

# expect <want_rc> <label> [substring]
expect() {
    local want="$1" label="$2" needle="${3:-}"
    [ "$RC" = "$want" ] || fail "$label: expected exit $want, got $RC (stdout: $OUT)"
    case "$OUT" in
        "ledger-gate: "*) : ;;
        *) fail "$label: stdout must be one 'ledger-gate: ' line, got: $OUT" ;;
    esac
    [ "$(printf '%s' "$OUT" | wc -l | tr -d ' ')" = "0" ] \
        || fail "$label: stdout must be exactly ONE line, got: $OUT"
    if [ -n "$needle" ]; then
        case "$OUT" in
            *"$needle"*) : ;;
            *) fail "$label: expected stdout to contain '$needle', got: $OUT" ;;
        esac
    fi
    echo "  ok — $label (exit $want)"
}

echo "test-ledger-gate: 19 cases"

# 1 — ticket from a plan header, ledger present and valid.
new_repo
write_plan "docs/plans/2026-08-24-IDS-99-x-plan.md" "IDS-99"
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
run_gate "$BASE"
expect 0 "case 1: plan header + valid ledger"

# 2 — same, ledger absent, a code file changed.
new_repo
write_plan "docs/plans/2026-08-24-IDS-99-x-plan.md" "IDS-99"
echo change > "$REPO/skills/foo/a.sh"
commit_all
run_gate "$BASE"
expect 1 "case 2: ticket resolved, ledger missing, code changed"

# 3 — ticket from the branch name, no plan in the diff.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
run_gate "$BASE"
expect 0 "case 3: ticket from branch name + valid ledger"

# 4 — no ticket anywhere.
new_repo
git -C "$REPO" checkout -q -b feature/cleanup
echo change > "$REPO/skills/foo/a.sh"
commit_all
run_gate "$BASE"
expect 4 "case 4: no ticket on this branch" "no ticket on this branch"

# 5 — ticket resolves, but only ignored paths changed.
new_repo
write_plan "docs/plans/2026-08-24-IDS-99-x-plan.md" "IDS-99"
echo "# doc" > "$REPO/CLAUDE.md"
commit_all
run_gate "$BASE"
expect 4 "case 5: docs-only branch" "docs-only branch"

# 6 — markdown under skills/ IS code in a skills repository.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo "# skill" > "$REPO/skills/foo/SKILL.md"
commit_all
run_gate "$BASE"
expect 1 "case 6: skills/*.md counts as code"

# 7 — ledger exists but is empty.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
mkdir -p "$REPO/.gaspol/progress"
: > "$REPO/.gaspol/progress/PROGRESS-IDS-99.md"
run_gate "$BASE"
expect 3 "case 7: empty ledger is UNKNOWN, not missing"

# 8 — ledger exists but has no ## Checklist.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
mkdir -p "$REPO/.gaspol/progress"
printf '# PROGRESS — IDS-99\n\n## Log\n- x — NEXT: DONE\n' \
    > "$REPO/.gaspol/progress/PROGRESS-IDS-99.md"
run_gate "$BASE"
expect 3 "case 8: no ## Checklist is UNKNOWN"

# 9 — a ## heading after ## Log breaks scan-active-ledgers.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
printf '\n## Utang terbuka\n\n- sesuatu\n' >> "$REPO/.gaspol/progress/PROGRESS-IDS-99.md"
run_gate "$BASE"
expect 3 "case 9: a block below ## Log is UNKNOWN"

# 10 — two plans naming DIFFERENT tickets.
new_repo
write_plan "docs/plans/2026-08-24-IDS-98-a-plan.md" "IDS-98"
write_plan "docs/plans/2026-08-24-IDS-99-b-plan.md" "IDS-99"
echo change > "$REPO/skills/foo/a.sh"
commit_all
run_gate "$BASE"
expect 3 "case 10: two plans, two tickets — never pick one silently"

# 11 — two plans naming the SAME ticket is fine.
new_repo
write_plan "docs/plans/2026-08-24-IDS-99-a-plan.md" "IDS-99"
write_plan "docs/plans/2026-08-24-IDS-99-b-plan.md" "IDS-99"
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
run_gate "$BASE"
expect 0 "case 11: two plans, one ticket"

# 12 — .gaspol/progress/ does not exist at all: BLOCKING, never a crash.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
[ -d "$REPO/.gaspol" ] && fail "case 12 setup: .gaspol should not exist"
run_gate "$BASE"
expect 1 "case 12: no .gaspol directory at all"

# 13 — legacy per-slug ledger, identified by its body.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/some-old-slug.md" "IDS-99"
run_gate "$BASE"
expect 0 "case 13: legacy .gaspol/progress/<slug>.md"

# 14 — legacy shared ledger.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress.md" "IDS-99"
run_gate "$BASE"
expect 0 "case 14: legacy shared .gaspol/progress.md"

# 15 — BASE is not a valid ref.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
run_gate "nonexistent-ref"
expect 3 "case 15: invalid BASE"

# 16 — no argument at all.
new_repo
run_gate
expect 3 "case 16: no BASE argument"

# 17 — a lowercase branch name must NOT resolve a ticket.
new_repo
git -C "$REPO" checkout -q -b ids-99-lowercase
echo change > "$REPO/skills/foo/a.sh"
commit_all
run_gate "$BASE"
expect 4 "case 17: lowercase branch resolves no ticket" "no ticket on this branch"

# 18 — the ledger is unreadable.
new_repo
git -C "$REPO" checkout -q -b IDS-99-foo
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
chmod 000 "$REPO/.gaspol/progress/PROGRESS-IDS-99.md"
run_gate "$BASE"
chmod 644 "$REPO/.gaspol/progress/PROGRESS-IDS-99.md"
if [ "$(id -u)" = "0" ]; then
    echo "  skip — case 18: running as root, chmod 000 is not enforced"
else
    expect 3 "case 18: unreadable ledger is UNKNOWN"
fi

# 19 — invoked from a FOREIGN directory: paths resolve against the repo root,
#      never $PWD. This is the IDS-8 hazard class, and the reason spec-pointer
#      resolves through `git rev-parse --show-toplevel`.
new_repo
FOREIGN="$WORK/foreign"
mkdir -p "$FOREIGN"
git -C "$REPO" checkout -q -b IDS-99-foo
mkdir -p "$REPO/sub/dir"
echo change > "$REPO/skills/foo/a.sh"
commit_all
write_ledger ".gaspol/progress/PROGRESS-IDS-99.md" "IDS-99"
set +e
OUT="$(cd "$REPO/sub/dir" && "$GATE" "$BASE" 2>/dev/null)"
RC=$?
set -e
expect 0 "case 19: run from a subdirectory, resolves against the repo root"

echo "test-ledger-gate: running the script's own --self-test..."
"$GATE" --self-test >/dev/null || fail "ledger-gate --self-test failed"
echo "  ok — --self-test"

# The BSD portability guard lives HERE, not in the script's --self-test, and the
# reason is worth keeping: a guard that searches its own source for a pattern
# must quote that pattern, so it always finds one. Two attempts inside the
# script both failed against themselves — first scanning the whole file, then
# scanning only lines containing "sed", where the narrowed guard's own comment
# reintroduced the word. A checker cannot be its own subject. This file reads
# the script without being it.
#
# The hazard is specific: BSD sed rejects \| alternation in a BASIC regex, and
# IDS-18's blast-radius-diff parser silently found ZERO paths because of it —
# reporting "the plan declares no files" on a plan full of them. grep -E and
# grep -F handle those characters fine, so only sed invocations are in scope.
# COMMENT LINES ARE EXCLUDED, and that is the check being correct rather than
# being weakened. The comment in ledger-gate that WARNS about this very hazard
# necessarily quotes the pattern; flagging it would make the guard fire on its
# own documentation and teach the next person to delete the warning. What must
# not contain the pattern is an executable sed invocation.
echo "test-ledger-gate: BSD sed portability..."
SED_LINES="$(grep -n 'sed ' "$GATE" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
if printf '%s\n' "$SED_LINES" | grep -qF '\|'; then
    fail "ledger-gate has a sed invocation using BSD-hostile \\| alternation:
$(printf '%s\n' "$SED_LINES" | grep -F '\|')"
fi
echo "  ok — no executable sed invocation uses \\| alternation"

# Positive control: the check above must be able to FAIL. Without this, a
# pattern that silently matches nothing reports "clean" forever — which is
# precisely the IDS-18 defect it was written to prevent.
echo "test-ledger-gate: portability check's own positive control..."
PLANT="$WORK/planted-sed.sh"
printf '#!/usr/bin/env bash\n# a comment mentioning sed and \\| must NOT trip this\necho x | sed -e "s/a\\\\|b/c/"\n' > "$PLANT"
PLANTED="$(grep -n 'sed ' "$PLANT" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
printf '%s\n' "$PLANTED" | grep -qF '\|' \
    || fail "positive control: the portability check did not catch a planted BSD-hostile sed"
echo "  ok — the portability check catches a planted violation"

echo "test-ledger-gate: PASS (19 cases)"
