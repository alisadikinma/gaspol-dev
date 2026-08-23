#!/usr/bin/env bash
# test-scripts-executable.sh — every script gaspol invokes DIRECTLY must be
# committed with its executable bit set (IDS-13, review round).
#
# This repo has `core.fileMode = false`, so git ignores mode changes in the
# working tree entirely. `chmod +x` after creating a file therefore never reaches
# the index: the file runs fine for whoever created it and is committed 100644.
# Nobody notices until the branch is merged and git rewrites the file, or until
# somebody clones -- at which point the script fails with "Permission denied",
# which reads like a system problem rather than a packaging one.
#
# Caught exactly that way: detect-app-target and marketplace-manifest were both
# committed 100644 and only failed after `git checkout main && git merge`.
#
# Scope: scripts INVOKED DIRECTLY. design_audit.py is deliberately excluded --
# every caller runs it as `python3 <path>`, where the bit is irrelevant.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

DIRECT=(
    skills/_shared/kb-root
    skills/gaspol-execute/scripts/detect-stack
    skills/gaspol-execute/scripts/detect-app-target
    skills/gaspol-debug/scripts/regression-gate
    skills/gaspol-execute/scripts/next-ticket
    skills/gaspol-execute/scripts/scan-active-ledgers
    skills/gaspol-parallel/scripts/dag-lanes
    skills/gaspol-parallel/scripts/review-package
    skills/gaspol-parallel/scripts/task-brief
    skills/gaspol-verify/scripts/extract-design-tokens
    skills/gaspol-verify/scripts/spec-pointer
    skills/gaspol-verify/scripts/blast-radius-diff
    skills/gaspol-verify/scripts/ledger-gate
    skills/gaspol-verify/scripts/model-gate
    skills/gaspol-brainstorm/visual-companion/scripts/start-server.sh
    skills/gaspol-brainstorm/visual-companion/scripts/stop-server.sh
    skills/gaspol-brainstorm/visual-companion/scripts/smoke-test.sh
    tests/ticket-scripts/marketplace-manifest
)

# Data, not programs. These are served or `require`d, never executed, so their
# mode is irrelevant and forcing 755 on them would be cargo cult.
ASSETS_RE='\.(py|md|html|js|cjs|json|css)$'

# Python scripts invoked via `python3 <path>`, not run directly -- their
# mode bit is irrelevant the same way design_audit.py's is (ASSETS_RE
# exempts THAT one because it carries a .py extension). geometry-diff
# carries no extension, matching the naming convention of the bash scripts
# in DIRECT above, so ASSETS_RE cannot catch it by suffix -- named here
# explicitly instead (IDS-14 Phase B1).
INTERPRETER_INVOKED=(
    skills/gaspol-verify/scripts/geometry-diff
)

echo "test-scripts-executable: every directly-invoked script is committed 100755..."

for s in "${DIRECT[@]}"; do
    [ -f "$s" ] || fail "$s is listed here but does not exist — update the list or restore the file"
    mode="$(git ls-files -s -- "$s" | awk '{print $1}')"
    [ -n "$mode" ] || fail "$s is not tracked by git, so its mode cannot be committed at all"
    [ "$mode" = "100755" ] \
        || fail "$s is committed $mode — it will arrive non-executable for anyone who clones or after any merge that rewrites it. Fix with: git update-index --chmod=+x $s"
    echo "  ok $s"
done

echo "test-scripts-executable: the list has not drifted from the filesystem..."

# A new script under scripts/ that nobody added here is a script whose mode
# nothing guards -- which is precisely how the two above slipped through.
while IFS= read -r found; do
    case " ${DIRECT[*]} ${INTERPRETER_INVOKED[*]} " in
        *" $found "*) : ;;
        *) fail "$found exists but is not in this test's list. Add it (or document why it is never invoked directly, as design_audit.py is)." ;;
    esac
done < <(git ls-files 'skills/*/scripts/*' 'skills/_shared/kb-root' \
         | grep -vE "$ASSETS_RE" || true)

echo "PASS: test-scripts-executable"
