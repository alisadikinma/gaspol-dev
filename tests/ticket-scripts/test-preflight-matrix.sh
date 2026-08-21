#!/usr/bin/env bash
# test-preflight-matrix.sh — asserts the pre-flight plan conflict matrix (IDS-6 A5).
#
# Cross-task conflicts are cheapest to find before task 1 and most expensive to
# find at task 12, when the contradiction has already been built on. The scan is
# a table, not a verdict: "the scan is clean" without rows is not a scan that ran.
#
# The table is written ABOVE "## Log" in the ledger — scan-active-ledgers reads the
# file's last non-empty line, so anything below "## Log" breaks active-vs-done
# detection.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARALLEL="$REPO_ROOT/skills/gaspol-parallel/SKILL.md"
EXECUTE="$REPO_ROOT/skills/gaspol-execute/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

for f in "$PARALLEL" "$EXECUTE"; do
    name="$(basename "$(dirname "$f")")"
    echo "test-preflight-matrix: checking $name..."

    has "$f" "conflict matrix" \
        "expected $name SKILL.md to require a pre-flight conflict matrix"
    has "$f" "before the first dispatch\|before task 1\|before Phase A\|before execution begins" \
        "expected $name SKILL.md to place the scan before the first task runs"

    # The two row kinds. A scan with neither is a claim, not a scan.
    has "$f" "share a file" \
        "expected $name SKILL.md to require a row per task pair sharing a file or interface"
    has "$f" "agrees with itself" \
        "expected $name SKILL.md to require a self-consistency row per task"

    has "$f" "is not a scan" \
        "expected $name SKILL.md to state that a clean claim without rows is not a scan that ran"

    has "$f" "above .## Log" \
        "expected $name SKILL.md to require the table be written above '## Log' in the ledger"

    has "$f" "ruling" \
        "expected $name SKILL.md to require each finding be ruled on and the ruling recorded"
done

echo "PASS: test-preflight-matrix"
