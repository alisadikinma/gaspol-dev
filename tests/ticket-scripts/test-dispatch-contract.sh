#!/usr/bin/env bash
# test-dispatch-contract.sh — asserts the file-based dispatch handoff (IDS-6 A2).
#
# The controller hands a dispatched implementer a PATH to a task-scoped brief and
# a path to write its report to. It does not paste the task text, and it does not
# read back a full report. Both of those stay resident in the controller's context
# for the rest of the session and are re-read on every later turn.
#
# The old blanket rule "NEVER reference a file" is narrowed, not reversed: never
# reference the PLAN (a subagent handed a 2000-line plan picks the wrong task),
# always reference the task-scoped BRIEF.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/gaspol-parallel/SKILL.md"
PROMPT="$REPO_ROOT/skills/gaspol-parallel/implementer-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }
lacks(){ grep -qi -- "$2" "$1" && fail "$3"; return 0; }

echo "test-dispatch-contract: checking gaspol-parallel SKILL.md..."

has "$SKILL" "scripts/task-brief" \
    "expected SKILL.md to reference scripts/task-brief"
has "$SKILL" "task-scoped brief" \
    "expected SKILL.md to name the task-scoped brief as what a dispatch references"
has "$SKILL" "never reference the plan" \
    "expected SKILL.md to state the narrowed rule: never reference the plan"

lacks "$SKILL" "NEVER reference a file" \
    "SKILL.md still carries the old blanket rule 'NEVER reference a file' — it must be narrowed to the plan, not files in general"
lacks "$SKILL" "Paste the full task text" \
    "SKILL.md still instructs pasting the full task text into the dispatch prompt"

# The five things a dispatch prompt carries.
has "$SKILL" "report-file path" \
    "expected SKILL.md to require the report-file path in the dispatch"
has "$SKILL" "verbatim" \
    "expected SKILL.md to introduce the brief as requirements to use verbatim"
has "$SKILL" "exact values" \
    "expected SKILL.md to state that exact values live only in the brief"

echo "test-dispatch-contract: checking implementer-prompt.md..."

has "$PROMPT" ".gaspol/tasks/" \
    "expected implementer-prompt.md to name the report file location"
has "$PROMPT" "task-.*-report.md" \
    "expected implementer-prompt.md to name the report file"
has "$PROMPT" "never dispatch" \
    "expected implementer-prompt.md to carry the no-subagents contract"

# The short return contract: four fields, not a full report pasted back.
for field in "status" "commit" "test summary" "concerns"; do
    has "$PROMPT" "$field" \
        "expected implementer-prompt.md to name '$field' in the short return contract"
done

echo "test-dispatch-contract: checking CLAUDE.md doc sync (IDS-6 D1)..."

CLAUDEMD="$REPO_ROOT/CLAUDE.md"

has "$CLAUDEMD" "task-brief" \
    "expected CLAUDE.md to document scripts/task-brief"
has "$CLAUDEMD" "re-review-prompt.md" \
    "expected CLAUDE.md to document re-review-prompt.md"
has "$CLAUDEMD" "five-round\|5-round\|five rounds" \
    "expected CLAUDE.md to describe the five-round fix loop"
has "$CLAUDEMD" "conflict matrix" \
    "expected CLAUDE.md to describe the pre-flight conflict matrix"

# The three Part C trims, with the audit figures that motivated them.
has "$CLAUDEMD" "1.9k\|~1,900\|1900" \
    "expected CLAUDE.md to record the measured per-session token tax"
has "$CLAUDEMD" "orphan" \
    "expected CLAUDE.md to record that the write-skill references were orphans"
has "$CLAUDEMD" "no plan referenced" \
    "expected CLAUDE.md to record the finish plan-verifier skip condition"

echo "PASS: test-dispatch-contract"
