#!/usr/bin/env bash
# test-logic-design-artifact.sh — asserts every ticket produces one reviewable
# design artifact before code starts, including logic-only work (IDS-10 Phase D).
#
# The complaint: "jika project nya hanya enhancement logic tidak ada perubahan
# design, maka perlu buatkan 1 artifact design supaya bisa di review dulu setelah
# plan selesai."
#
# Verified cause, two layers deep:
#   1. gaspol-brainstorm Phase 2.5 offered "[No, pure backend/logic]", and that
#      branch skipped Phase 3 entirely — no design, by design.
#   2. gaspol-plan's post-plan artifact step existed but was OPT-IN ("Skip" was
#      one of two answers), so the default outcome for logic work was nothing to
#      look at. The first reviewable thing became the diff, which is too late.
#
# The gate below is BLOCKING and has no "not applicable" state. "Not applicable"
# was the bug.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAN="$REPO_ROOT/skills/gaspol-plan/SKILL.md"
BRAIN="$REPO_ROOT/skills/gaspol-brainstorm/SKILL.md"
EXEC="$REPO_ROOT/skills/gaspol-execute/SKILL.md"
CONTRACT="$REPO_ROOT/skills/gaspol-plan/logic-design-artifact.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

echo "test-logic-design-artifact: the contract file exists..."

[ -f "$CONTRACT" ] || fail "skills/gaspol-plan/logic-design-artifact.md is missing"

echo "test-logic-design-artifact: all five mandatory sections are specified..."

has "$CONTRACT" "Before .*After"      "section 1 (before/after behaviour) missing"
has "$CONTRACT" "quoted from real code\|quote.*real code" \
    "section 1 must require the CURRENT path be quoted from real code, not described from memory"
has "$CONTRACT" "mermaid"             "section 2 (flow/sequence diagram) must specify mermaid"
has "$CONTRACT" "Data Integration Map" \
    "section 3 must reuse the plan's Data Integration Map columns so the two cannot drift"
has "$CONTRACT" "edge-case matrix\|edge case matrix" "section 4 (edge-case matrix) missing"
has "$CONTRACT" "empty matrix"        "an empty edge-case matrix must be a failed gate, never a pass"
has "$CONTRACT" "NOT changing\|not changing" "section 5 (blast radius — what is NOT changing) missing"

echo "test-logic-design-artifact: it is published as an artifact and approved explicitly..."

has "$CONTRACT" "Artifact"        "the contract must publish via the Artifact tool"
has "$CONTRACT" "AskUserQuestion" "approval must go through AskUserQuestion"

echo "test-logic-design-artifact: the tab-count rule is stated, both cases..."

has "$CONTRACT" "Logic tab is always present\|Logic tab is ALWAYS present" \
    "the contract must state that the Logic tab is present for every kind of work"
has "$CONTRACT" "satu tab\|one tab\|single tab" \
    "the contract must say what a logic-only change produces, not only the two-tab case"

echo "test-logic-design-artifact: the srcdoc escaping rule is stated, not left to be discovered..."

has "$CONTRACT" "&amp;quot;" \
    "the escaping rule must show the actual entity a double quote becomes inside srcdoc"
has "$CONTRACT" "Escape .* first\|escape .* first" \
    "the escaping rule must state the ampersand is escaped FIRST, or the others get double-escaped"
has "$CONTRACT" "record which of the two\|record which mechanism" \
    "a fallback away from srcdoc must be recorded, not switched to silently"

echo "test-logic-design-artifact: the artifact is written in plain Indonesian, with technical terms kept..."

has "$CONTRACT" "plain Indonesian" \
    "the contract must state the artifact prose is plain Indonesian"
has "$CONTRACT" "framework" \
    "the language rule must name ordinary technical vocabulary that stays English -- 'framework' is the worked example"
has "$CONTRACT" "hardisk" \
    "the language rule must carry the second worked example the owner gave -- 'hardisk'"
has "$CONTRACT" "recognise faster\|recognises faster\|recognize faster" \
    "the borderline test must be which form the READER recognises faster, not whether an Indonesian word exists"
grep -qi 'docs/plans' "$CONTRACT" \
    || fail "the contract must say the Indonesian rule does NOT extend to docs/plans/*.md"

echo "test-logic-design-artifact: gaspol-plan gates on it, and the gate is BLOCKING..."

has "$PLAN" "Design Artifact (BLOCKING)" \
    "gaspol-plan's post-plan step is not a BLOCKING Design Artifact gate"
has "$PLAN" "logic-design-artifact.md" \
    "gaspol-plan must reference the contract file"
has "$PLAN" "design-artifact: approved" \
    "gaspol-plan must record the verdict in the ledger as a machine-checkable line"

echo "test-logic-design-artifact: three states, and 'not applicable' is not one of them..."

has "$PLAN" "design-artifact: pending" "the pending state must be defined"
grep -qiE 'design-artifact: (n/?a|not applicable)' "$PLAN" \
    && fail "'not applicable' reintroduced as an artifact state — that state WAS the bug"

echo "test-logic-design-artifact: brainstorm no longer offers 'no design at all'..."

grep -qiE '\[No, pure backend/logic\]' "$BRAIN" \
    && fail "brainstorm Phase 2.5 still offers a branch that skips design entirely"
has "$BRAIN" "logic design artifact" \
    "brainstorm Phase 2.5's non-UI branch must route to the logic design artifact, not to nothing"

echo "test-logic-design-artifact: gaspol-execute refuses a plan without an approved artifact..."

has "$EXEC" "design-artifact" \
    "gaspol-execute has no pre-execution check for the design artifact"
has "$EXEC" "STOP and ask" \
    "gaspol-execute must STOP and ask on a pending artifact rather than proceeding"

echo "PASS: test-logic-design-artifact — every ticket owes one reviewable artifact before code"
