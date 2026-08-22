#!/usr/bin/env bash
# test-batch-gate.sh — asserts one report of N defects mints ONE ticket (IDS-10 Phase C).
#
# The complaint: "misal ada 5 bug yg dilaporin dia akan create 5 ticket.. itu salah
# total." Verified cause — there was no batching rule anywhere:
#
#   grep -rn "multiple bug|several bug|each bug" skills/   ->  0 hits
#
# and the opposite rule did exist, in gaspol-brainstorm's decompose gate:
# "Each sub-project gets its own spec -> plan -> implement cycle." The gate that
# was missing sits UPSTREAM of decompose: decompose asks "one project or
# several?", and nothing first asked "one piece of WORK or several?". Five bugs
# in one subsystem are one piece of work.
#
# The rule must live in BOTH skills. A batch rule that exists only in brainstorm
# would not fire for the exact complaint that produced this ticket: bug reports
# route to gaspol-debug and never reach brainstorm.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRAIN="$REPO_ROOT/skills/gaspol-brainstorm/SKILL.md"
DEBUG="$REPO_ROOT/skills/gaspol-debug/SKILL.md"
GATE="$REPO_ROOT/skills/_shared/batch-gate.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

echo "test-batch-gate: the rule has ONE source, referenced by both callers..."

[ -f "$GATE" ] || fail "skills/_shared/batch-gate.md is missing — the threshold has no single source"
for f in "$BRAIN" "$DEBUG"; do
    n="$(basename "$(dirname "$f")")"
    has "$f" "Batch Gate"        "$n has no Batch Gate — N reports still become N tickets"
    has "$f" "_shared/batch-gate.md" "$n does not reference the shared rule — a copied threshold drifts"
    has "$f" "ONE ticket\|one ticket" "$n does not state the default of one ticket at the gate"
done
# The threshold numbers must live in the shared file and NOWHERE else, for the
# reason fix-loop.md was extracted: a constant in two files disagrees with itself.
for f in "$BRAIN" "$DEBUG"; do
    grep -qiE "8 phases|eight phases" "$f" \
        && fail "$(basename "$(dirname "$f")") repeats the phase threshold — it belongs only in _shared/batch-gate.md"
done

echo "test-batch-gate: the gate runs BEFORE the decompose gate in brainstorm..."

batch_line="$(grep -n "Batch Gate" "$BRAIN" | head -1 | cut -d: -f1)"
decomp_line="$(grep -n "Decompose gate" "$BRAIN" | head -1 | cut -d: -f1)"
[ -n "$batch_line" ] && [ -n "$decomp_line" ] \
    || fail "could not locate both gates in gaspol-brainstorm"
[ "$batch_line" -lt "$decomp_line" ] \
    || fail "the Batch Gate must precede the Decompose gate (batch=$batch_line decompose=$decomp_line) — decompose splits, so anything it sees first is already split"

echo "test-batch-gate: the split reasons are a closed list of exactly three..."

has "$GATE" "disjoint subsystem"   "split reason 1 (disjoint subsystems) missing"
has "$GATE" "8 phases\|eight phases" "split reason 1 must carry the >8-phase half of the AND"
has "$GATE" "Both halves"          "split reason 1 must require BOTH halves, not either"
has "$GATE" "blocks"               "split reason 2 (one item blocks another) missing"
has "$GATE" "user explicitly"      "split reason 3 (the user asked) missing"

echo "test-batch-gate: the never-split list names the tempting non-reasons..."

has "$GATE" "different bugs"  "'they are different bugs' must be listed as NOT a split reason"
has "$GATE" "different files" "'they are in different files' must be listed as NOT a split reason"
has "$GATE" "would be big\|getting big" "'the ticket would be big' must be listed as NOT a split reason"

echo "test-batch-gate: the ceiling is two, and exceeding it needs the user..."

has "$GATE" "Never more than two" "the hard ceiling of two tickets is not stated"
has "$GATE" "AskUserQuestion"     "exceeding the ceiling must go through AskUserQuestion"

echo "test-batch-gate: batching changes the container, never the coverage..."

has "$GATE" "own regression test" \
    "each batched item must still get its own regression test — batching must not become dropping"
has "$GATE" "own phase"  "each batched item must become its own plan phase"
has "$GATE" "severity"   "batched items must be ordered by severity"
has "$GATE" "Law 2"      "dropping a batched item must be named as an Iron Law 2 violation"

echo "test-batch-gate: one next-ticket call per batch, not per item..."

has "$GATE"  "once per batch"     "the shared rule must state one next-ticket call per batch"
has "$BRAIN" "once per batch\|one per batch" \
    "gaspol-brainstorm Phase 6 must mint exactly one ticket id per batch"

echo "test-batch-gate: the rationalizations are Red Flags..."

has "$GATE" "tidier" "Red Flag missing — 'one ticket per bug is tidier'"

echo "test-batch-gate: gaspol-debug carries no project-specific section (IDS-10 Phase E)..."

leak="$(cd "$REPO_ROOT" && grep -rilE 'sparkfluence' skills/ agents/ hooks/ 2>/dev/null || true)"
[ -z "$leak" ] || fail "a project name is hardcoded in an agnostic plugin: $leak"
has "$DEBUG" "target project's CLAUDE.md\|project's CLAUDE.md" \
    "gaspol-debug must read the target project's CLAUDE.md instead of naming one project"

echo "PASS: test-batch-gate — one report, one ticket; split is the exception, capped at two"
