#!/usr/bin/env bash
# test-blast-radius-diff.sh — the plan's file list vs the real diff (IDS-18 Phase B)
#
# The artifact carries a mandatory section 5 "What is NOT changing (blast
# radius)" (skills/gaspol-plan/logic-design-artifact.md:64) and nothing ever
# compared it to anything. The list is read from the PLAN rather than the
# artifact on purpose: the artifact is stored as a URL, and a gate that needs the
# network to run spends most of its life recorded as "not run".
#
# The ignore list is the case that decides whether this gate survives contact
# with a real branch. Without it every run false-positives on .gaspol/, on
# docs/plans/, and on CLAUDE.md — files that legitimately change on every ticket
# and appear in no phase's file list. A gate that cries wolf gets switched off.
#
# Every case builds a REAL git repository with REAL commits. A mocked diff cannot
# exercise renames or deletions, which are two of the four interesting rows.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRD="$REPO_ROOT/skills/gaspol-verify/scripts/blast-radius-diff"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# Builds a repo with one baseline commit; echoes "<canonical-root> <base-sha>".
# $1 = the `**Files:**` block body written into the plan (may be empty).
make_repo() {
    local files_block="$1"
    local d; d="$(mktemp -d "$TMPROOT/repo.XXXXXX")"
    git -C "$d" init -q
    git -C "$d" config user.email t@t; git -C "$d" config user.name t
    d="$(git -C "$d" rev-parse --show-toplevel)"
    mkdir -p "$d/docs/plans" "$d/src"
    {
        echo "**Ticket:** T-1"
        echo ""
        echo "### Phase A: something"
        echo ""
        echo "**Files:**"
        [ -n "$files_block" ] && printf '%s\n' "$files_block"
        echo ""
        echo "**Steps:**"
    } > "$d/docs/plans/p-plan.md"
    echo "baseline" > "$d/src/existing.txt"
    git -C "$d" add -A >/dev/null
    git -C "$d" commit -qm "baseline"
    echo "$d $(git -C "$d" rev-parse HEAD)"
}

commit_all() { git -C "$1" add -A >/dev/null; git -C "$1" commit -qm "${2:-change}"; }

run_brd() {
    OUT=""; RC=0
    OUT="$( "$BRD" "$1/docs/plans/p-plan.md" "$2" 2>&1 )" || RC=$?
    return 0
}

echo "test-blast-radius-diff: the script exists and self-tests..."
[ -x "$BRD" ] || fail "blast-radius-diff is not present or not executable at $BRD"
bash "$BRD" --self-test >/dev/null 2>&1 || fail "blast-radius-diff --self-test did not exit 0"

echo "test-blast-radius-diff: case 1 — every changed file is planned -> exit 0..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case1 expected exit 0, got $RC ($OUT)"

echo "test-blast-radius-diff: case 2 — an unplanned changed file -> exit 1, WARN..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
echo changed > "$d/src/existing.txt"; echo new > "$d/src/surprise.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 1 ] || fail "case2 expected exit 1, got $RC ($OUT)"
case "$OUT" in *surprise.txt*) ;; *) fail "case2 must NAME the unplanned file, not just count it: $OUT" ;; esac

echo "test-blast-radius-diff: case 3 — exit 1 is WARN, never BLOCK..."
case "$OUT" in
    *WARN*) ;;
    *) fail "case3 exit 1 must be labelled WARN — collateral edits are legitimate and a per-file BLOCK would fire on most branches: $OUT" ;;
esac

echo "test-blast-radius-diff: case 4 — ignored paths never produce a finding..."
# Without this the gate false-positives on every single ticket.
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
echo changed > "$d/src/existing.txt"
mkdir -p "$d/.gaspol/progress"
echo x > "$d/.gaspol/progress/PROGRESS-T-1.md"
echo x > "$d/CLAUDE.md"
echo x > "$d/docs/plans/2026-01-01-T-1-x-spec.md"
echo x > "$d/package-lock.json"
commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case4 expected exit 0 — .gaspol/, CLAUDE.md, docs/plans/ and lockfiles must be ignored, got $RC ($OUT)"

echo "test-blast-radius-diff: case 5 — a planned file that was DELETED counts as touched..."
read -r d base <<<"$(make_repo '- Delete: `src/existing.txt`')"
rm "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case5 expected exit 0 — a deletion is a change, got $RC ($OUT)"

echo "test-blast-radius-diff: case 6 — a rename reports BOTH paths..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
git -C "$d" mv src/existing.txt src/renamed.txt; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 1 ] || fail "case6 expected exit 1 — the new path was never planned, got $RC ($OUT)"
case "$OUT" in *renamed.txt*) ;; *) fail "case6 must name the new path: $OUT" ;; esac

echo "test-blast-radius-diff: case 7 — a planned file never touched produces NO finding here..."
# That fact is plan-verifier's MISSING. Reporting it twice gives two findings for
# one defect, and the second one is the noisy kind that gets a gate disabled.
read -r d base <<<"$(make_repo '- Create: `src/never-written.txt`
- Modify: `src/existing.txt`')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case7 expected exit 0 — planned-but-untouched belongs to plan-verifier, got $RC ($OUT)"
case "$OUT" in *never-written*) fail "case7 must NOT report a planned-but-untouched file: $OUT" ;; esac

echo "test-blast-radius-diff: case 8 — no changes at all -> exit 0..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case8 (empty diff) expected exit 0, got $RC ($OUT)"

echo "test-blast-radius-diff: case 9 — a glob in the plan -> exit 3 UNKNOWN..."
read -r d base <<<"$(make_repo '- Modify: `src/*.txt`')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 3 ] || fail "case9 expected exit 3 — silently ignoring a glob is a silent pass, got $RC ($OUT)"

echo "test-blast-radius-diff: case 10 — a directory in the plan -> exit 3 UNKNOWN..."
read -r d base <<<"$(make_repo '- Modify: `src/`')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 3 ] || fail "case10 expected exit 3, got $RC ($OUT)"

echo "test-blast-radius-diff: case 11 — no **Files:** entries at all -> exit 4, not a failure..."
read -r d base <<<"$(make_repo '')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 4 ] || fail "case11 expected exit 4, got $RC ($OUT)"

echo "test-blast-radius-diff: case 12 — an invalid BASE -> exit 3, never an empty diff..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
[ "$RC" = 3 ] || fail "case12 expected exit 3 — an unreachable BASE must not degrade to 'nothing changed', got $RC ($OUT)"

echo "test-blast-radius-diff: case 13 — an unreadable plan -> exit 3..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
RC=0; "$BRD" "$d/docs/plans/absent-plan.md" "$base" >/dev/null 2>&1 || RC=$?
[ "$RC" = 3 ] || fail "case13 expected exit 3, got $RC"

echo "test-blast-radius-diff: case 14 — a planned path containing spaces..."
read -r d base <<<"$(make_repo '- Modify: `src/my file.txt`')"
echo changed > "$d/src/my file.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case14 expected exit 0, got $RC ($OUT)"

echo "test-blast-radius-diff: case 15 — a verb bullet OUTSIDE any **Files:** block is not parsed..."
# Found by plan-verifier on this ticket's own branch. The parser was unscoped, so
# a `- Create: ...` bullet written anywhere in the plan's prose was read as a
# declared file — and a plan with NO **Files:** block returned findings instead of
# the exit 4 the contract defines for exactly that case.
read -r d base <<<"$(make_repo '')"
python3 - "$d/docs/plans/p-plan.md" <<'PYEOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
# No **Files:** heading anywhere — only a verb bullet loose in prose.
p.write_text("**Ticket:** T-1\n\n### Phase A\n\nThe fix will `- Create: `src/loose.txt`` eventually.\n\n- Create: `src/loose.txt`\n", encoding="utf-8")
PYEOF
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 4 ] || fail "case15 expected exit 4 — a verb bullet outside a **Files:** block is prose, not a declaration; got $RC ($OUT)"

echo "test-blast-radius-diff: case 16 — the **Files:** block still parses when it IS present..."
read -r d base <<<"$(make_repo '- Modify: `src/existing.txt`')"
printf '\n**Steps:**\n\n1. Later we will `- Create: `src/never.txt`` maybe.\n- Create: `src/never.txt`\n' >> "$d/docs/plans/p-plan.md"
echo changed > "$d/src/existing.txt"; commit_all "$d"
run_brd "$d" "$base"
[ "$RC" = 0 ] || fail "case16 expected exit 0 — the real block parses and the bullet under **Steps:** does not; got $RC ($OUT)"

echo "test-blast-radius-diff: a report line is written on EVERY exit path..."
for spec in "0:- Modify: \`src/existing.txt\`" "4:" "3:- Modify: \`src/*.txt\`"; do
    want="${spec%%:*}"; block="${spec#*:}"
    read -r d base <<<"$(make_repo "$block")"
    echo changed > "$d/src/existing.txt"; commit_all "$d"
    run_brd "$d" "$base"
    case "$OUT" in
        *"blast-radius:"*) ;;
        *) fail "no 'blast-radius:' report line on the exit-$want path: $OUT" ;;
    esac
done

echo "test-blast-radius-diff: git output is captured before grep ever sees it..."
# regression-gate's own header documents this: under `set -o pipefail`, a
# `grep -q` that exits on first match can SIGPIPE the git process, and pipefail
# then reports git's SIGPIPE status as the pipeline's. That raced one run in six
# there. Positive control first, so a clean result cannot be vacuous.
CONTROL=$(grep -c 'git' "$BRD" || true)
[ "${CONTROL:-0}" -ge 3 ] \
    || fail "positive control matched only ${CONTROL:-0} git line(s) — the search is broken, so the check below would be vacuous"
PIPED="$(grep -nE 'git (diff|log)[^|]*\|[[:space:]]*grep -[a-zA-Z]*q' "$BRD" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
[ -z "$PIPED" ] \
    || { echo "$PIPED" >&2; fail "git output is piped straight into grep -q — capture it into a variable first (see regression-gate's SIGPIPE/pipefail race)"; }

echo "PASS: test-blast-radius-diff"
