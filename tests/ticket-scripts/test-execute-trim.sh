#!/usr/bin/env bash
# test-execute-trim.sh — asserts the gaspol-execute trim (IDS-6 C1).
#
# gaspol-execute is the largest skill in the plugin and fires on nearly every job,
# so it is the one file where trimming prose pays off across every run. The trim
# cuts WORDS, never OBLIGATIONS: every gate this skill owns must still be named
# here, and the detail that moved must have moved into a reference file that
# actually exists — not been deleted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/gaspol-execute/SKILL.md"
DIR="$REPO_ROOT/skills/gaspol-execute"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

# 18000 since IDS-23: Claude Code keeps only the first 20,000 characters of a SKILL.md after
# /compact, so a gate past that cut vanishes. The ceiling leaves headroom under the cut, and
# the detail that moved lives in skills/gaspol-execute/references/. The gate sentences stay in
# the body; test-skill-trim-execute.sh pins them one by one.
LIMIT=18000
# The ceiling tracks OBLIGATIONS, not a fixed byte budget: it was 25500 after
# IDS-6's word-trim, IDS-10 raised it by 700 for the Design Artifact Gate, and
# IDS-17 raised it by 400 for Step 8, the finish offer -- a new decision point
# this skill owns and must present. Each is a new obligation, not new prose.
# Raise it only when one is ADDED, and say which one here. Raising it to make a
# wordy edit fit is the failure this guards.
SIZE="$(wc -c < "$SKILL" | tr -d ' ')"
echo "test-execute-trim: SKILL.md is $SIZE bytes (limit $LIMIT)"
[ "$SIZE" -le "$LIMIT" ] || fail "expected SKILL.md under $LIMIT bytes, got $SIZE"

# Every gate the skill owns still has to be named in it.
for gate in "TDD" "anti-placeholder" "plan-verifier" "security-review" "ledger" "checkpoint" \
            "conflict matrix" "Completeness Gate" "Completion Gate" "Iron Law" \
            "Verification Loop" "detect-stack"; do
    has "$SKILL" "$gate" "trim removed the '$gate' gate — the trim cuts words, not obligations"
done

# The three Iron Laws survive by content, not just by the heading.
has "$SKILL" "NO PLACEHOLDER" "Iron Law 1 (no placeholder data) is missing"
has "$SKILL" "NO STEP SKIPPED"  "Iron Law 2 (no step skipped without approval) is missing"
has "$SKILL" "NO COMPLETION CLAIM" "Iron Law 3 (no completion claim without evidence) is missing"

# The TDD step-1 hard gate keeps its exact required wording.
has "$SKILL" "Write failing test for" \
    "the TDD step-1 hard gate lost its exact required phrasing"

# Detail that moved must point at a file that exists in this skill's directory.
for ref in "anti-placeholder-rules.md" "checkpoint-template.md"; do
    has "$SKILL" "$ref" "expected SKILL.md to point at $ref for the detail it no longer inlines"
    [ -s "$DIR/$ref" ] || fail "$ref is referenced but missing or empty — detail was deleted, not moved"
done

# The per-phase ledger gate is blocking; the trim must not soften it.
has "$SKILL" "BLOCKING\|blocking" "the ledger/verification gate lost its BLOCKING status"

# IDS-19: the ledger's SHAPE changed (a sub-block per phase, copied from the
# plan's Steps and Verification blocks). Ledgers written before that are still
# READ unchanged -- only new ones use the new shape. If Step 3's fallback stops
# saying so, an executor meeting an older flat ledger has no instruction and will
# either rewrite it or stall.
has "$SKILL" "older flat" \
    "gaspol-execute: expected the old flat ledger form to be named as still-readable, found no mention"
has "$SKILL" "Steps" \
    "gaspol-execute Step 3 no longer names the plan's Steps block as the ledger checklist's source"

echo "PASS: test-execute-trim"
