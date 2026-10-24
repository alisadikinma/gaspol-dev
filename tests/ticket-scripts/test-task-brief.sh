#!/usr/bin/env bash
# test-task-brief.sh — TDD test for skills/gaspol-parallel/scripts/task-brief
#
# task-brief extracts ONE phase's full text from a plan file into a uniquely
# named brief file, so a dispatch prompt can hand over a path instead of
# pasting the task text into the controller's context.
#
# Covers: the happy path (correct phase extracted, next phase excluded), the
# ticket-derived output path, stdout being exactly one path line, and the four
# usage errors (no args, missing plan, missing **Ticket:** header, N out of
# range). The fixture is a real temp git repo because the script resolves its
# output directory from the plan file's repository root — the same way
# review-package does.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASK_BRIEF="$REPO_ROOT/skills/gaspol-parallel/scripts/task-brief"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO="$TMP_DIR/repo"
mkdir -p "$REPO/docs/plans"
# Canonicalise: on macOS /var is a symlink to /private/var, and the script
# prints a resolved path. Compare like with like.
REPO="$(cd "$REPO" && pwd -P)"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t

PLAN="$REPO/docs/plans/2026-08-21-XYZ-9-demo-plan.md"
cat >"$PLAN" <<'EOF'
**Ticket:** XYZ-9
**Ledger:** .gaspol/progress/PROGRESS-XYZ-9.md

## Goal

Demo plan used as a test fixture.

### Phase A1: first thing

**Steps:**
1. Write failing test for the first thing. Expected error: `not defined`.
2. Implement the first thing with the magic value 4242.

**Verification:**
- [ ] first thing verified

---

### Phase A2: second thing

**Steps:**
1. Write failing test for the second thing. Expected error: `also not defined`.

**Verification:**
- [ ] second thing verified

---

### Phase A3: third thing

**Steps:**
1. Write failing test for the third thing. Expected error: `still not defined`.
EOF

fail() { echo "FAIL: $*" >&2; exit 1; }

# The mode git RECORDS, not just the mode this working tree happens to have.
# A local chmod makes every test pass while the committed file ships 100644 —
# which is exactly what happened once: the branch was green, and the script was
# non-executable for anyone who checked it out.
MODE="$(git -C "$REPO_ROOT" ls-files -s skills/gaspol-parallel/scripts/task-brief | cut -d' ' -f1)"
[ "$MODE" = "100755" ] || fail "task-brief is recorded in git as $MODE, not 100755 — it will not be executable on checkout"

# --- 1. happy path: phase 2 extracted, printed path is the only stdout line ---
echo "test-task-brief: extracting phase 2..."
OUT="$("$TASK_BRIEF" "$PLAN" 2)"

[ "$(printf '%s' "$OUT" | wc -l | tr -d ' ')" = "0" ] \
    || fail "stdout must be exactly one line (no trailing extra lines), got: $OUT"

EXPECTED_PATH="$REPO/.gaspol/tasks/XYZ-9/task-2-brief.md"
[ "$OUT" = "$EXPECTED_PATH" ] \
    || fail "expected path '$EXPECTED_PATH', got '$OUT'"
[ -s "$OUT" ] || fail "brief file is empty or missing: $OUT"

grep -q "Phase A2: second thing" "$OUT" \
    || fail "brief does not contain its own phase heading"
grep -q "also not defined" "$OUT" \
    || fail "brief does not contain the phase's steps"
grep -q "second thing verified" "$OUT" \
    || fail "brief does not contain the phase's verification block"

grep -q "Phase A3" "$OUT" \
    && fail "brief leaked the NEXT phase — extraction boundary is wrong"
grep -q "Phase A1" "$OUT" \
    && fail "brief leaked the PREVIOUS phase — extraction boundary is wrong"
grep -q "4242" "$OUT" \
    && fail "brief leaked phase A1's exact values"

# --- 2. first and last phases extract correctly (boundary cases) ---
OUT1="$("$TASK_BRIEF" "$PLAN" 1)"
grep -q "4242" "$OUT1" || fail "phase 1 brief lost its exact value"
grep -q "Phase A2" "$OUT1" && fail "phase 1 brief leaked phase 2"

OUT3="$("$TASK_BRIEF" "$PLAN" 3)"
grep -q "still not defined" "$OUT3" || fail "last phase extracted no steps"

# --- 3. the brief names its plan and ticket, so it is self-identifying ---
grep -q "XYZ-9" "$OUT" || fail "brief does not name its ticket"
grep -q "$(basename "$PLAN")" "$OUT" || fail "brief does not name its plan file"

# --- 4. usage errors all exit 2 ---
expect_exit_2() {
    local label="$1"; shift
    set +e
    "$@" >/dev/null 2>&1
    local rc=$?
    set -e
    [ "$rc" = "2" ] || fail "$label: expected exit 2, got $rc"
}

expect_exit_2 "no args" "$TASK_BRIEF"
expect_exit_2 "missing N" "$TASK_BRIEF" "$PLAN"
expect_exit_2 "nonexistent plan" "$TASK_BRIEF" "$TMP_DIR/nope.md" 1
expect_exit_2 "N out of range" "$TASK_BRIEF" "$PLAN" 99
expect_exit_2 "N not a number" "$TASK_BRIEF" "$PLAN" abc

NOTICKET="$REPO/docs/plans/2026-08-21-noticket-plan.md"
printf '## Goal\n\n### Phase A1: x\n\n1. step\n' >"$NOTICKET"
expect_exit_2 "missing **Ticket:** header" "$TASK_BRIEF" "$NOTICKET" 1

# --- 5. IDS-23: the plan header's Verification commands block rides along ---
# The generic verification commands are written ONCE in the plan header. A dispatched
# implementer never sees the header (it gets the brief, not the plan), so the brief
# carries the block under a fixed heading. A plan without the block gets a brief that
# is byte-identical to what task-brief produced before IDS-23.
echo "test-task-brief: header Verification commands block..."
HPLAN="$REPO/docs/plans/2026-10-24-XYZ-10-headed-plan.md"
cat >"$HPLAN" <<'EOF'
**Ticket:** XYZ-10
**Format:** waves-v1

**Verification commands:**
- static: npx tsc --noEmit
- unit: npm test

## Goal

Plan with a header block.

### Phase A1: first thing

**Verification:**
- [ ] the first thing does its own check

---

### Phase A2: second thing

**Verification:**
- [ ] the second thing does its own check
EOF

HOUT="$("$TASK_BRIEF" "$HPLAN" 2)"
grep -qxF '## Verification commands (from the plan header)' "$HOUT" \
    || fail "brief lacks the plan-header Verification commands"
EXPECTED_TAIL="$(printf '%s\n' '## Verification commands (from the plan header)' '' \
    '**Verification commands:**' '- static: npx tsc --noEmit' '- unit: npm test')"
ACTUAL_TAIL="$(tail -n 5 "$HOUT")"
[ "$ACTUAL_TAIL" = "$EXPECTED_TAIL" ] \
    || fail "brief lacks the plan-header Verification commands verbatim at the end; got: $ACTUAL_TAIL"
grep -q "Phase A1" "$HOUT" && fail "header brief leaked another phase"

# A fenced copy of the header line (a template quoted in a phase) is not the header.
FPLAN="$REPO/docs/plans/2026-10-24-XYZ-11-fenced-plan.md"
cat >"$FPLAN" <<'EOF'
**Ticket:** XYZ-11

### Phase A1: quotes a template

```markdown
**Verification commands:**
- static: not-the-header
```
EOF
FOUT="$("$TASK_BRIEF" "$FPLAN" 1)"
grep -q "from the plan header" "$FOUT" \
    && fail "a fenced Verification commands line was taken for the plan header"

# Legacy plan: nothing appended, the file is exactly the pre-IDS-23 shape.
LOUT="$("$TASK_BRIEF" "$PLAN" 2)"
{
    echo "# Task brief — XYZ-9, phase 2"
    echo
    echo "Source plan: $(basename "$PLAN")"
    echo
    echo "These are your requirements. Use every value in them verbatim — the"
    echo "numbers, strings, signatures, and test cases here are exact, not"
    echo "illustrative. Do not go looking for the plan file this came from."
    echo
    echo "---"
    echo
    echo "### Phase A2: second thing"
    echo
    echo "**Steps:**"
    echo '1. Write failing test for the second thing. Expected error: `also not defined`.'
    echo
    echo "**Verification:**"
    echo "- [ ] second thing verified"
} > "$TMP_DIR/legacy-expected.md"
cmp -s "$LOUT" "$TMP_DIR/legacy-expected.md" \
    || fail "legacy brief changed: $(diff "$TMP_DIR/legacy-expected.md" "$LOUT" | head -5)"

echo "PASS: test-task-brief"
