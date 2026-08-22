#!/usr/bin/env bash
# test-regression-gate.sh -- asserts skills/gaspol-debug/scripts/regression-gate
# answers "does this branch fix a bug, and if so did it leave a regression
# test?" deterministically, across its four exit states (IDS-14 Phase A1).
#
# Prose could not enforce prose: gaspol-debug Phase 4 step 1 said "Create a
# failing test case (if possible)" with nothing checking whether it was
# possible or whether one was written. This test exercises the machine that
# replaces the escape hatch, not the prose around it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/skills/gaspol-debug/scripts/regression-gate"

FAILURES=0
note() { echo "PASS: $*"; }
bad()  { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }

echo "test-regression-gate: the script itself passes --self-test..."
if "$GATE" --self-test; then
    note "regression-gate --self-test"
else
    bad "regression-gate --self-test exited non-zero"
fi

echo "test-regression-gate: building a fixture repo to exercise the four exit states..."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
git -C "$tmp" config user.email test@example.com
git -C "$tmp" config user.name test
echo one > "$tmp/a.txt"
git -C "$tmp" add a.txt
git -C "$tmp" commit -q -m "chore: base"
base="$(git -C "$tmp" rev-parse HEAD)"
mkdir -p "$tmp/.gaspol/progress"

# --- exit 4: no fix commits in range -----------------------------------
echo two >> "$tmp/a.txt"; git -C "$tmp" add a.txt; git -C "$tmp" commit -q -m "docs: tweak the readme"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 4 ] && note "no fix commits -> exit 4 (not applicable)" \
                || bad "no fix commits: expected exit 4, got $rc ($out)"
case "$out" in *"not applicable"*) note "exit 4 message says not applicable" ;; \
  *) bad "exit 4 message does not say not applicable: $out" ;; esac

# --- exit 3: fix commit, no ledger at all -------------------------------
echo three >> "$tmp/a.txt"; git -C "$tmp" add a.txt; git -C "$tmp" commit -q -m "fix: broken thing"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 3 ] && note "fix commit, no ledger -> exit 3 (UNKNOWN)" \
                || bad "fix commit, no ledger: expected exit 3, got $rc ($out)"

# --- exit 3: fix commit, ambiguous ledgers ------------------------------
printf '## Log\nregression-test: N/A — one\n' > "$tmp/.gaspol/progress/PROGRESS-X.md"
printf '## Log\nregression-test: N/A — two\n' > "$tmp/.gaspol/progress/PROGRESS-Y.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 3 ] && note "two ledgers, no explicit path -> exit 3 (ambiguous, UNKNOWN)" \
                || bad "ambiguous ledgers: expected exit 3, got $rc ($out)"
rm -f "$tmp/.gaspol/progress/PROGRESS-Y.md"

# --- exit 1: fix commit, ledger has no regression-test: line -----------
printf '## Log\nsome other line — NEXT: x\n' > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 1 ] && note "fix commit, no regression-test: line -> exit 1 (BLOCKING)" \
                || bad "no line: expected exit 1, got $rc ($out)"

# --- exit 0: written state ----------------------------------------------
printf '## Log\nregression-test: tests/x.sh::case1 — RED at abc123, GREEN after fix\n' \
    > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 0 ] && note "written regression-test: line -> exit 0 (satisfied)" \
                || bad "written line: expected exit 0, got $rc ($out)"

# --- exit 0: N/A with a reason -------------------------------------------
printf 'regression-test: N/A — environment-only failure, no code path to test\n' \
    > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 0 ] && note "N/A with reason -> exit 0 (satisfied)" \
                || bad "N/A with reason: expected exit 0, got $rc ($out)"

# --- exit 1: bare N/A, no reason -- a new silent default in disguise ----
printf 'regression-test: N/A\n' > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 1 ] && note "bare N/A with no reason -> exit 1 (BLOCKING, not a new (if possible))" \
                || bad "bare N/A: expected exit 1, got $rc ($out)"

# --- exit 0: not run, with a reason --------------------------------------
printf 'regression-test: not run — time pressure, tracked as follow-up IDS-99\n' \
    > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 0 ] && note "not run with reason -> exit 0 (satisfied)" \
                || bad "not run with reason: expected exit 0, got $rc ($out)"

# --- exit 1: bare "not run", no reason -----------------------------------
printf 'regression-test: not run\n' > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 1 ] && note "bare 'not run' with no reason -> exit 1 (BLOCKING)" \
                || bad "bare not run: expected exit 1, got $rc ($out)"

# --- explicit ledger-path argument overrides default resolution ---------
mkdir -p "$tmp/elsewhere"
printf 'regression-test: N/A — explicit path test\n' > "$tmp/elsewhere/ledger.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base" "elsewhere/ledger.md")" || rc=$?
[ "$rc" -eq 0 ] && note "explicit ledger-path argument is honoured" \
                || bad "explicit ledger path: expected exit 0, got $rc ($out)"

# --- keyword sweep: bug / hotfix / regression / revert all count --------
for kw in bug hotfix regression revert; do
    echo x >> "$tmp/a.txt"; git -C "$tmp" add a.txt; git -C "$tmp" commit -q -m "${kw}: something"
done
printf 'regression-test: N/A — keyword sweep\n' > "$tmp/.gaspol/progress/PROGRESS-X.md"
rc=0; out="$(cd "$tmp" && "$GATE" "$base")" || rc=$?
[ "$rc" -eq 0 ] && note "bug/hotfix/regression/revert keywords all reach the ledger check" \
                || bad "keyword sweep: expected exit 0, got $rc ($out)"

echo "test-regression-gate: usage and executability..."
rc=0; "$GATE" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && note "missing BASE arg -> exit 1 (usage error)" \
                || bad "missing arg: expected exit 1, got $rc"

if [ -x "$GATE" ]; then
    note "regression-gate is executable"
else
    bad "regression-gate is not executable (chmod +x, and git update-index --chmod=+x)"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "test-regression-gate: $FAILURES assertion(s) failed" >&2
    exit 1
fi
echo "PASS: test-regression-gate -- four exit states, all reachable and correct"
