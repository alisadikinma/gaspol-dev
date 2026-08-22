#!/usr/bin/env bash
# test-verification-loop.sh — asserts gaspol-execute RUNS things per phase
# instead of reading them (IDS-12).
#
# The defect, verified by grep on 1.21.0:
#
#   grep -n "detect-stack|npm test|Validation Ladder" skills/gaspol-execute/SKILL.md
#   -> 0 hits
#
# The Validation Ladder existed since v1.8 but only in implementer-prompt.md (for
# dispatched subagents) and gaspol-parallel. The in-session path -- the one that
# runs on almost every job -- had no automatic execution at all. Its per-phase
# "Auto-Review" dispatches a model to READ the code; nothing RAN it. Everything
# executable was deferred to gaspol-verify at the very end, which is the slowest
# and most expensive place to discover a type error.
#
# A gate that reads is an opinion. A gate that runs is evidence. This asserts the
# second kind exists on the hot path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXEC="$REPO_ROOT/skills/gaspol-execute/SKILL.md"
CKPT="$REPO_ROOT/skills/gaspol-execute/checkpoint-template.md"
STACK="$REPO_ROOT/skills/gaspol-execute/scripts/detect-stack"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

echo "test-verification-loop: the loop exists at all..."

has "$EXEC" "Verification Loop" \
    "gaspol-execute has no Verification Loop section — the in-session path still only reads code"
has "$EXEC" "detect-stack" \
    "gaspol-execute never invokes detect-stack, so its commands are guessed or hardcoded"
[ -x "$STACK" ] || fail "detect-stack is not executable — the loop's command source cannot run"

echo "test-verification-loop: the baseline is captured BEFORE phase 1..."

# Without a baseline, a suite that was already red gets blamed on the first phase,
# and the fix loop spins on somebody else's failure. gaspol-finish learned this in
# IDS-9; the same reasoning applies one layer earlier.
has "$EXEC" "baseline" \
    "no baseline run — a pre-existing failure will be blamed on the first phase"
has "$EXEC" "already red\|red at baseline\|red before" \
    "the skill does not say what happens when the baseline is ALREADY failing"

echo "test-verification-loop: the ladder runs fail-fast, cheapest first..."

has "$EXEC" "L1" "ladder level L1 (static) not named"
has "$EXEC" "L2" "ladder level L2 (unit) not named"
has "$EXEC" "L3" "ladder level L3 (build) not named"
has "$EXEC" "fail-fast\|stop at the first failure" \
    "the ladder must stop at the first failing level — running an expensive level after a cheap one failed wastes the run"
has "$EXEC" "restart from\|re-run from" \
    "after a fix the ladder must restart from the failed level, not from the top or from the next one"

echo "test-verification-loop: proportionality — not every level on every phase..."

# The Completeness Ladder (IDS-10) removed the scope governor. Running a full
# build after a one-line docs phase is exactly the over-application that leaves.
has "$EXEC" "docs-only\|config-only" \
    "no proportionality rule — a docs-only phase must not pay for a build"
has "$EXEC" "explicitly\|explicit" \
    "a level that does not apply must be skipped EXPLICITLY; a silent skip is a placeholder-grade lie"

echo "test-verification-loop: the failure feeds back as the REAL error text..."

has "$EXEC" "verbatim\|actual error\|full output" \
    "the failing command's real output must reach the fix, not a summary of it — a paraphrased error is a guess about a fact you already have"

echo "test-verification-loop: the fix loop is bounded, and borrows the bound..."

has "$EXEC" "_shared/fix-loop.md" \
    "the per-phase fix loop must defer to the shared bound instead of inventing its own"
grep -qE 'five rounds|5 rounds|three attempts|3 attempts' "$EXEC" \
    && fail "gaspol-execute repeats the round cap — a constant copied into two files disagrees with itself (the reason fix-loop.md exists)"

echo "test-verification-loop: three states for detect-stack, never blurred..."

has "$EXEC" "UNKNOWN" \
    "the marker-present-but-command-missing state must STOP and ask, not silently skip"
has "$EXEC" "no stack markers\|zero lines" \
    "a repo with no stack markers must fall back to the plan-declared commands, recorded as such"

echo "test-verification-loop: the checkpoint reports evidence, not a claim..."

has "$CKPT" "Verification" \
    "the checkpoint template has no Verification block — the phase can still claim done with no run"
has "$CKPT" "exit code\|exit 0" \
    "the checkpoint must record the exit code, not the word 'passed'"
has "$CKPT" "command" \
    "the checkpoint must name the command that was run, so the claim is reproducible"

echo "test-verification-loop: the completion gate cannot be reached without it..."

# The whole point: a phase that never ran its ladder must not be tickable.
has "$EXEC" "may not be ticked\|cannot be ticked\|do not tick" \
    "nothing stops a phase being ticked complete without its ladder having run"

echo "PASS: test-verification-loop — the hot path runs code, it does not only read it"
