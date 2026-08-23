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

echo "test-regression-gate: gaspol-debug Phase 4 stops excusing itself (A2)..."

DEBUG_SKILL="$REPO_ROOT/skills/gaspol-debug/SKILL.md"

# Checks for the LIVE instruction, not prose that explains what was removed
# -- a file may EXPLAIN a retired form without ISSUING it (the same exemption
# CLAUDE.md/README carry in the completeness-ladder scan, and
# test-marketplace-manifest-states.sh carries for its own banned form).
if grep -qF 'failing test case** (if possible)' "$DEBUG_SKILL"; then
    bad "gaspol-debug still offers \"(if possible)\" as the default"
else
    note "gaspol-debug no longer offers (if possible) as a default"
fi

grep -qF 'RED at <sha>, GREEN after fix' "$DEBUG_SKILL" \
    && note "gaspol-debug documents the written regression-test: line format" \
    || bad "gaspol-debug does not document the written regression-test: line format"

grep -qF 'N/A — <reason>' "$DEBUG_SKILL" \
    && note "gaspol-debug documents the N/A — <reason> state" \
    || bad "gaspol-debug does not document the N/A — <reason> state"

grep -qF 'not run — <reason>' "$DEBUG_SKILL" \
    && note "gaspol-debug documents the not run — <reason> state" \
    || bad "gaspol-debug does not document the not run — <reason> state"

grep -qi 'RED before GREEN' "$DEBUG_SKILL" \
    && note "gaspol-debug states RED-before-GREEN is not optional" \
    || bad "gaspol-debug does not state the RED-before-GREEN requirement"

grep -qF 'regression-gate' "$DEBUG_SKILL" \
    && note "gaspol-debug names the machine that checks the ledger line" \
    || bad "gaspol-debug never names regression-gate"

echo "test-regression-gate: wiring into the two callers (A3)..."

VERIFY_SKILL="$REPO_ROOT/skills/gaspol-verify/SKILL.md"

# IDS-14 wired regression-gate into TWO callers: gaspol-verify Layer 1 and
# gaspol-finish Step 0. IDS-17 deleted Step 0 -- it ran detect-stack and
# regression-gate, which is exactly what gaspol-verify Layer 1 already runs, and
# gaspol-verify became chain step 1, so the cheap-checks-first ordering Step 0
# existed to enforce is now held by position instead of by repetition.
#
# So the two Step 0 assertions are gone and the gaspol-verify ones below are the
# ONLY wiring left. That makes them load-bearing in a way they were not before:
# if they weaken, regression-gate is wired into nothing at all.
FINISH_SKILL="$REPO_ROOT/skills/gaspol-finish/SKILL.md"
grep -q "Step 0" "$FINISH_SKILL" \
    && bad "gaspol-finish still carries a Step 0 preamble — IDS-17 deleted it; if it came back, the duplicate invocation needs its own assertion again"

# Anchored, not relative -- a relative call site executes whatever script a
# repo carrying that path happens to ship, since gaspol-verify runs with the
# TARGET PROJECT as its working directory (the same invariant IDS-8 fixed
# for kb-root). A plain substring match on the unanchored path would have
# passed on the relative form too, which is exactly how this regressed once
# already (plan-verifier audit, IDS-14 post-run) -- checking the anchored
# literal closes that hole.
grep -qF '"$CLAUDE_PLUGIN_ROOT/skills/gaspol-debug/scripts/regression-gate"' "$VERIFY_SKILL" \
    && note "gaspol-verify Layer 1 runs regression-gate, anchored via \$CLAUDE_PLUGIN_ROOT" \
    || bad "gaspol-verify Layer 1 does not run regression-gate anchored via \$CLAUDE_PLUGIN_ROOT"

grep -qF '${CLAUDE_PLUGIN_ROOT:?' "$VERIFY_SKILL" \
    && note "gaspol-verify Layer 1's regression-gate call carries the \${CLAUDE_PLUGIN_ROOT:?...} guard" \
    || bad "gaspol-verify Layer 1's regression-gate call has no \${CLAUDE_PLUGIN_ROOT:?...} guard"

grep -qF 'live-app-check' "$VERIFY_SKILL" && grep -qF 'regression-gate' "$VERIFY_SKILL" \
    && note "gaspol-verify Layer 1 still carries live-app-check alongside regression-gate" \
    || bad "gaspol-verify Layer 1 lost one of live-app-check / regression-gate"

if [ "$FAILURES" -gt 0 ]; then
    echo "test-regression-gate: $FAILURES assertion(s) failed" >&2
    exit 1
fi
echo "PASS: test-regression-gate -- four exit states, all reachable and correct"
