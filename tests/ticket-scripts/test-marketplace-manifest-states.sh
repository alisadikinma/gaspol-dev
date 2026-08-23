#!/usr/bin/env bash
# test-marketplace-manifest-states.sh -- asserts the three-state contract of
# marketplace-manifest is REACHABLE by its callers, not merely written down.
#
# The defect this was born from (IDS-14 Phase A0), verified before it was fixed:
#
#   $ bash -c 'set -euo pipefail; v="$(exit 4)"; rc=$?; echo "REACHED rc=$rc"'
#   $ echo $?
#   4                       <- "REACHED" never printed
#
# Every caller used `X="$(marketplace-manifest)"; RC=$?`. Under `set -euo
# pipefail` the assignment IS the simple command, so a non-zero substitution
# terminates the script right there and the `case "$RC"` that handles exit 3 and
# exit 4 is unreachable code. The script's own header says "Callers MUST
# distinguish 3 from 4"; not one of them could distinguish anything.
#
# It stayed invisible because on `main` the sibling checkout exists, so the
# answer was always state 1 and the two dead branches were never asked for.
# Four tests turned red the moment the suite ran from a git worktree.
#
# This test does what test-kb-state4-continues.sh does: it RUNS the control flow
# rather than reading the prose about it. A text assertion cannot catch a
# control-flow bug -- that was the whole lesson of IDS-8's round three.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MM="$SCRIPT_DIR/marketplace-manifest"
cd "$REPO_ROOT"

FAILURES=0
note() { echo "PASS: $*"; }
bad()  { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "test-marketplace-manifest-states: the script itself returns all three states..."

printf '{"plugins": [{"name": "x", "version": "9.9.9"}]}\n' > "$tmp/good.json"

rc=0; out="$(GASPOL_MARKETPLACE_MANIFEST="$tmp/good.json" "$MM")" || rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$tmp/good.json" ]; then
    note "state available -> exit 0, path on stdout"
else
    bad "state available: expected exit 0 and the path, got exit $rc / '$out'"
fi

rc=0; GASPOL_MARKETPLACE_MANIFEST="$tmp/nope.json" "$MM" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] && note "state UNKNOWN -> exit 3" \
                || bad "state UNKNOWN: expected exit 3, got $rc"

# Not-a-manifest must also be UNKNOWN, never silently "none". A readable file
# that is not a manifest is a configuration mistake, and degrading it to "none"
# reports a gate as not-configured when it is configured and broken.
printf 'hello\n' > "$tmp/junk.json"
rc=0; GASPOL_MARKETPLACE_MANIFEST="$tmp/junk.json" "$MM" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] && note "readable non-manifest -> exit 3, not 4" \
                || bad "readable non-manifest: expected exit 3, got $rc"

echo "test-marketplace-manifest-states: callers SURVIVE state 3 and state 4..."

# The regression itself. Each caller is executed with the manifest forced into a
# state it must handle, and is required to run to completion. A caller that dies
# at the assignment exits with the raw 3 or 4 and prints none of its own verdict.
CALLERS=(
    test-ids8-docs.sh
    test-naming-convention.sh
    test-prior-art-gate.sh
    test-skill-delegation.sh
)

for caller in "${CALLERS[@]}"; do
    [ -f "$SCRIPT_DIR/$caller" ] || { bad "$caller is missing -- caller list is stale"; continue; }

    # State 4: nothing configured. The caller must SKIP the cross-repo check and
    # still reach its own verdict. Exit 4 escaping to the runner turns "not
    # checked" into "failed", which is precisely the conflation the manifest
    # script's header forbids.
    rc=0
    GASPOL_MARKETPLACE_MANIFEST=none \
        bash "$SCRIPT_DIR/$caller" >"$tmp/out4" 2>&1 || rc=$?
    if [ "$rc" -eq 3 ] || [ "$rc" -eq 4 ]; then
        bad "$caller died with the manifest's raw exit $rc -- the case block is unreachable"
    else
        note "$caller survives state 4 (exit $rc)"
    fi

    # State 3: configured and unreadable. The caller must REPORT it. Whether it
    # fails or merely warns is the caller's choice; dying silently is not.
    rc=0
    GASPOL_MARKETPLACE_MANIFEST="$tmp/nope.json" \
        bash "$SCRIPT_DIR/$caller" >"$tmp/out3" 2>&1 || rc=$?
    if [ "$rc" -eq 3 ]; then
        bad "$caller died with raw exit 3 -- it never reached its UNKNOWN branch"
    elif grep -qi 'UNKNOWN' "$tmp/out3"; then
        note "$caller reaches its UNKNOWN branch and says so"
    else
        bad "$caller survived state 3 but printed no UNKNOWN verdict"
    fi
done

echo "test-marketplace-manifest-states: no caller uses the fatal assignment form..."

# Belt and braces on top of the behavioural check above: the form itself is
# banned, so a new caller cannot reintroduce it and pass merely because the
# sibling checkout happens to exist on the machine running the suite.
# Scans every caller but not this file, whose comments quote the banned form on
# purpose -- the same exemption CLAUDE.md and README.md carry in the
# completeness-ladder scan, and for the same reason: a file may EXPLAIN a
# retired form without ISSUING it.
if grep -nE '=\"?\$\([^)]*marketplace-manifest\)\"?[[:space:]]*;[[:space:]]*[A-Za-z_]+=\$\?' \
       $(ls "$SCRIPT_DIR"/*.sh | grep -v 'test-marketplace-manifest-states\.sh') 2>/dev/null; then
    bad "a caller still uses X=\"\$(marketplace-manifest)\"; RC=\$? -- use '|| RC=\$?'"
else
    note "no caller uses the fatal assignment form"
fi

echo "test-marketplace-manifest-states: resolution works from inside a git worktree..."

# Second defect from the same baseline. marketplace-manifest resolved its
# sibling relative to its OWN location, so from .claude/worktrees/<slug> it
# looked for .claude/worktrees/gaspol-one and reported "none". Every
# worktree-based ticket silently lost the cross-repo version gate -- reported
# honestly as NOT checked, but for the wrong reason and with no way to notice.
if grep -q 'git-common-dir' "$MM"; then
    note "marketplace-manifest resolves the MAIN worktree, not the linked one"
else
    bad "marketplace-manifest has no --git-common-dir resolution: it will report 'none' inside every worktree"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "test-marketplace-manifest-states: $FAILURES assertion(s) failed" >&2
    exit 1
fi
echo "PASS: test-marketplace-manifest-states -- the three states are reachable, not just documented"
