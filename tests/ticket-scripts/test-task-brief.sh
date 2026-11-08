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

# task-brief and verification-lint must agree on whether a plan HAS the header. The lint
# strips trailing whitespace and CR before matching; task-brief used an exact match, so a
# plan the lint called fine produced briefs that silently lost the commands.
echo "test-task-brief: header detection agrees with verification-lint..."
LINT="$REPO_ROOT/skills/gaspol-plan/scripts/verification-lint"
make_variant() {
    # make_variant <path> <header-line-suffix> <eol>
    local path="$1" suffix="$2" eol="$3"
    {
        printf '**Ticket:** XYZ-12%s' "$eol"
        printf '\n'
        printf '**Verification commands:**%s%s\n' "$suffix" "$eol"
        printf -- '- static: npx tsc --noEmit%s\n' "$eol"
        printf -- '- unit: npm test%s\n' "$eol"
        printf '%s\n' "$eol"
        printf '### Phase A1: only phase%s\n' "$eol"
        printf '%s\n' "$eol"
        printf '**Verification:**%s\n' "$eol"
        printf -- '- [ ] the only phase does its own check%s\n' "$eol"
    } > "$path"
}
CR="$(printf '\r')"
for variant in "trailing-space| |" "trailing-tabs|$(printf '\t\t')|" "crlf||$CR"; do
    vname="${variant%%|*}"; rest="${variant#*|}"; vsuffix="${rest%%|*}"; veol="${rest#*|}"
    VPLAN="$REPO/docs/plans/2026-10-24-XYZ-12-$vname-plan.md"
    make_variant "$VPLAN" "$vsuffix" "$veol"
    set +e; "$LINT" "$VPLAN" >/dev/null 2>&1; LINT_RC=$?; set -e
    [ "$LINT_RC" = "0" ] || fail "$vname: the lint should accept this plan, got exit $LINT_RC"
    VOUT="$("$TASK_BRIEF" "$VPLAN" 1)"
    grep -qxF '## Verification commands (from the plan header)' "$VOUT" \
        || fail "$vname: the lint accepts the header but the brief lacks the plan-header Verification commands"
    grep -q "^- static: npx tsc --noEmit$" "$VOUT" \
        || fail "$vname: the brief lost or garbled the static command line"
    grep -q "^- unit: npm test$" "$VOUT" \
        || fail "$vname: the brief lost or garbled the unit command line"
    grep -q "$CR" "$VOUT" && [ "$vname" = "crlf" ] && {
        # phase text keeps its CRs (it is copied verbatim); the header block must not
        sed -n '/^## Verification commands (from the plan header)/,$p' "$VOUT" | grep -q "$CR" \
            && fail "$vname: the header block was copied with CRs still on its lines"
    }
    echo "  ok — $vname"
done

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

# --- 6. IDS-24: fences. A quoted template inside a phase is text, not structure ---
# The phase extractor used to end a brief at any `---` line and count any `### Phase`
# line, so a phase that QUOTES a plan template (a fenced block holding a rule and a
# heading) was cut short and every later phase number resolved to the wrong block. It
# now applies the same fence rule as verification-lint: an opener is three or more
# backticks or tildes after at most three spaces; the closer is the same character, a
# run at least as long, and nothing after it but blanks or CR.
echo "test-task-brief: fence-aware extraction..."

run_tb() {
    # run_tb <plan> <n> — sets TB_OUT (stdout), TB_ERR (stderr), TB_RC (exit code)
    set +e
    TB_OUT="$("$TASK_BRIEF" "$1" "$2" 2>"$TMP_DIR/stderr")"
    TB_RC=$?
    set -e
    TB_ERR="$(cat "$TMP_DIR/stderr")"
}

QPLAN="$REPO/docs/plans/2026-11-09-XYZ-20-quote-plan.md"
cat >"$QPLAN" <<'EOF'
**Ticket:** XYZ-20

### Phase A1: quotes a template

**Steps:**
1. Quote this template:

```markdown
### Phase Z: quoted
---
**Verification:**
```

2. After the fence this is still phase A1: magic 7777.

---

### Phase A2: second

1. Second text 5151.
EOF

run_tb "$QPLAN" 1
[ "$TB_RC" = "0" ] || fail "quote plan phase 1: expected exit 0, got $TB_RC ($TB_ERR)"
[ "$TB_OUT" = "$REPO/.gaspol/tasks/XYZ-20/task-1-brief.md" ] \
    || fail "quote plan phase 1: stdout must be exactly the written path, got: $TB_OUT"
grep -q "7777" "$TB_OUT" || fail "brief stops at a --- inside a fence"
grep -q "^### Phase Z: quoted$" "$TB_OUT" || fail "the quoted heading inside the fence was dropped from the brief"
grep -q "Phase A2" "$TB_OUT" && fail "phase 1 brief leaked phase 2"
[ -z "$TB_ERR" ] || fail "a well-formed fenced plan must not write to stderr, got: $TB_ERR"

run_tb "$QPLAN" 2
[ "$TB_RC" = "0" ] || fail "quote plan phase 2: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "5151" "$TB_OUT" || fail "phase 2 resolved to the wrong block: the quoted ### Phase Z was counted"
grep -q "Phase Z" "$TB_OUT" && fail "phase 2 brief contains the quoted block"

run_tb "$QPLAN" 3
[ "$TB_RC" = "2" ] || fail "quote plan phase 3: a quoted heading must not count as a phase, expected exit 2, got $TB_RC"
[ -z "$TB_OUT" ] || fail "quote plan phase 3: stdout must be empty on exit 2, got: $TB_OUT"

# (a) nested fence: three backticks inside four are text; a tilde fence holds backticks
NPLAN="$REPO/docs/plans/2026-11-09-XYZ-21-nested-plan.md"
cat >"$NPLAN" <<'EOF'
**Ticket:** XYZ-21

### Phase A1: nested quotes

````markdown
```
---
### Phase Q: not a phase
```
---
````

~~~
```
---
~~~

tail text 8888.

---

### Phase A2: second

1. Second text 6262.
EOF

run_tb "$NPLAN" 1
[ "$TB_RC" = "0" ] || fail "nested plan phase 1: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "8888" "$TB_OUT" || fail "brief stops inside a nested fence (--- or ### seen as structure)"
grep -q "Phase A2" "$TB_OUT" && fail "nested plan phase 1 leaked phase 2"
run_tb "$NPLAN" 2
grep -q "6262" "$TB_OUT" || fail "nested plan phase 2 resolved to the wrong block"

# A closer followed by a run of CRs still closes the fence, as in verification-lint (which
# strips every trailing CR). Review finding: awk stripped only one CR, so the fence stayed
# open, the quoted `### Phase Q` was not counted by the lint but WAS skipped here, and
# `task-brief 2` wrote the quoted heading as the brief without a warning.
CPLAN="$REPO/docs/plans/2026-11-09-XYZ-38-crrun-plan.md"
printf '**Ticket:** XYZ-38\n\n### Phase A1: first\n```\nx\n```\r\r\n### Phase A2: real 4141\n```\n### Phase Q: quoted\n```\n### Phase A3: third\n```\n```\n' >"$CPLAN"
run_tb "$CPLAN" 2
[ "$TB_RC" = "0" ] || fail "CR-run closer: phase 2 expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "4141" "$TB_OUT" || fail "CR-run closer: phase 2 resolved to the wrong block"
run_tb "$CPLAN" 3
grep -q "Phase A3" "$TB_OUT" || fail "CR-run closer: phase 3 is not the third real phase"
run_tb "$CPLAN" 4
[ "$TB_RC" = "2" ] || fail "CR-run closer: a fourth phase must not exist, expected exit 2, got $TB_RC"

# A fence indented four spaces is not a fence: the --- after it still ends the block.
IPLAN="$REPO/docs/plans/2026-11-09-XYZ-27-indented-plan.md"
cat >"$IPLAN" <<'EOF'
**Ticket:** XYZ-27

### Phase A1: indented backticks

    ```
body 3131

---

### Phase A2: second

1. Second text 3232.
EOF
run_tb "$IPLAN" 1
[ "$TB_RC" = "0" ] || fail "indented plan phase 1: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "3131" "$TB_OUT" || fail "indented plan phase 1 lost its body"
grep -q "Phase A2" "$TB_OUT" && fail "four-space-indented backticks were taken for a fence; the --- did not end the block"
run_tb "$IPLAN" 2
grep -q "3232" "$TB_OUT" || fail "indented plan phase 2 resolved to the wrong block"

# (b) an unclosed fence opening INSIDE the requested phase hides a later phase heading
UPLAN="$REPO/docs/plans/2026-11-09-XYZ-22-unclosed-plan.md"
cat >"$UPLAN" <<'EOF'
**Ticket:** XYZ-22

### Phase A1: opens a fence it never closes

```markdown
sample text

### Phase A2: hidden by the fence

1. never visible
EOF
run_tb "$UPLAN" 1
[ "$TB_RC" = "1" ] || fail "unclosed fence in the requested phase: expected exit 1, got $TB_RC"
[ -z "$TB_OUT" ] || fail "refusal must print nothing on stdout, got: $TB_OUT"
case "$TB_ERR" in
    *"the code fence opened at line 5 of 2026-11-09-XYZ-22-unclosed-plan.md never closes"*) ;;
    *) fail "stderr must name the fence's opening line and the plan basename, got: $TB_ERR" ;;
esac
[ ! -e "$REPO/.gaspol/tasks/XYZ-22" ] || fail "refusal wrote into .gaspol/tasks/XYZ-22"
case "$TB_ERR" in *"$REPO"*) fail "stderr leaked the plan's directory: $TB_ERR" ;; esac

# (c) the same refusal when a LATER phase is requested and the fence opened in an earlier one
EPLAN="$REPO/docs/plans/2026-11-09-XYZ-23-earlier-plan.md"
cat >"$EPLAN" <<'EOF'
**Ticket:** XYZ-23

### Phase A1: first

```
unclosed sample

### Phase A2: hidden second
EOF
run_tb "$EPLAN" 2
[ "$TB_RC" = "1" ] || fail "fence opened in an earlier phase: expected exit 1 (not the misleading exit 2), got $TB_RC"
[ -z "$TB_OUT" ] || fail "refusal must print nothing on stdout, got: $TB_OUT"
case "$TB_ERR" in
    *"opened at line 5 of 2026-11-09-XYZ-23-earlier-plan.md never closes"*) ;;
    *) fail "stderr must name line 5, got: $TB_ERR" ;;
esac
[ ! -e "$REPO/.gaspol/tasks/XYZ-23" ] || fail "refusal wrote into .gaspol/tasks/XYZ-23"

# (d) a stray unclosed fence at the very end that hides no phase heading: warn, write, exit 0
SPLAN="$REPO/docs/plans/2026-11-09-XYZ-24-stray-plan.md"
cat >"$SPLAN" <<'EOF'
**Ticket:** XYZ-24

### Phase A1: first

1. First text 1111.

---

### Phase A2: last

1. Last text 2222.

```
stray tail line
EOF
run_tb "$SPLAN" 2
[ "$TB_RC" = "0" ] || fail "stray fence: expected exit 0, got $TB_RC ($TB_ERR)"
[ "$TB_OUT" = "$REPO/.gaspol/tasks/XYZ-24/task-2-brief.md" ] || fail "stray fence: stdout must be the written path, got: $TB_OUT"
grep -q "2222" "$TB_OUT" || fail "stray fence: brief lost its phase text"
case "$TB_ERR" in
    "task-brief: warning: the code fence opened at line 13 never closes; it hides no phase heading, so this brief is complete") ;;
    *) fail "stray fence: expected the one-line warning naming line 13, got: $TB_ERR" ;;
esac
run_tb "$SPLAN" 1
[ "$TB_RC" = "0" ] || fail "stray fence, earlier phase: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "1111" "$TB_OUT" || fail "stray fence, earlier phase: brief lost its phase text"
case "$TB_ERR" in "task-brief: warning:"*) ;; *) fail "stray fence, earlier phase: expected a warning, got: $TB_ERR" ;; esac

# (d2) an unclosed fence that hides a plain ### heading (not a phase) still refuses:
# it hid the end of the captured block, so the brief would run on into the fence.
HPLAN2="$REPO/docs/plans/2026-11-09-XYZ-28-hidesend-plan.md"
cat >"$HPLAN2" <<'EOF'
**Ticket:** XYZ-28

### Phase A1: first

```
sample

### Notes

more
EOF
run_tb "$HPLAN2" 1
[ "$TB_RC" = "1" ] || fail "fence hiding the end of the block: expected exit 1, got $TB_RC ($TB_ERR)"
[ ! -e "$REPO/.gaspol/tasks/XYZ-28" ] || fail "refusal wrote into .gaspol/tasks/XYZ-28"

# (e) a plan with no fences: the brief is byte-identical to what the pre-change script
# wrote. The expected bytes are fixed here (generated with the pre-change script), so
# the test keeps meaning something after the script changes. CRLF phase text, a
# whitespace-only line and blank lines before the rule are all copied verbatim.
BPLAN="$REPO/docs/plans/2026-11-09-XYZ-25-bytes-plan.md"
printf '%s\r\n' '**Ticket:** XYZ-25' '**Format:** waves-v1' '' '**Verification commands:**' '- unit: npm test' '' \
    '### Phase A1: first' '' '1. First 1.' '' '---' '' \
    '### Phase A2: second' '' '1. Second line.' '   ' '2. Next line, then blanks.' '' '' '---' '' \
    '### Phase A3: third' '1. Third.' >"$BPLAN"
run_tb "$BPLAN" 2
[ "$TB_RC" = "0" ] || fail "byte plan: expected exit 0, got $TB_RC ($TB_ERR)"
[ -z "$TB_ERR" ] || fail "byte plan: stderr must be empty, got: $TB_ERR"
{
    echo "# Task brief — XYZ-25, phase 2"
    echo
    echo "Source plan: 2026-11-09-XYZ-25-bytes-plan.md"
    echo
    echo "These are your requirements. Use every value in them verbatim — the"
    echo "numbers, strings, signatures, and test cases here are exact, not"
    echo "illustrative. Do not go looking for the plan file this came from."
    echo
    echo "---"
    echo
    printf '%s\r\n' '### Phase A2: second' '' '1. Second line.' '   ' '2. Next line, then blanks.' '' ''
    echo
    echo "## Verification commands (from the plan header)"
    echo
    echo "**Verification commands:**"
    echo "- unit: npm test"
} > "$TMP_DIR/bytes-expected.md"
# Command substitution strips only trailing LFs, so the block keeps its final CRs (the two
# blank CR lines) and `echo` then supplies the blank line before the header section.
cmp -s "$TB_OUT" "$TMP_DIR/bytes-expected.md" \
    || fail "no-fence brief is not byte-identical to the pre-change output: $(diff "$TMP_DIR/bytes-expected.md" "$TB_OUT" | head -8 | cat -A)"

# (f) usage errors still exit 2
expect_exit_2 "N is zero" "$TASK_BRIEF" "$PLAN" 0
expect_exit_2 "N is negative" "$TASK_BRIEF" "$PLAN" -1
expect_exit_2 "empty N" "$TASK_BRIEF" "$PLAN" ""
expect_exit_2 "fenced plan, nonexistent phase" "$TASK_BRIEF" "$QPLAN" 99

# --- 7. IDS-24: task-brief and verification-lint agree on which lines are fenced ---
# Same fixture through both scripts: the lint reports N phases and task-brief resolves
# exactly N phase numbers. If the two fence rules drifted apart, one would count the
# quoted heading and the other would not.
echo "test-task-brief: agrees with verification-lint on fenced lines..."
APLAN="$REPO/docs/plans/2026-11-09-XYZ-26-agree-plan.md"
cat >"$APLAN" <<'EOF'
**Ticket:** XYZ-26

**Verification commands:**
- unit: npm test

### Phase A1: quotes a template

**Verification:**
- [ ] the quoted template survives intact

````markdown
### Phase Z: quoted
---
```
**Verification:**
- [ ] a quoted item
```
---
````

---

### Phase A2: second

**Verification:**
- [ ] the second phase does its own check
EOF
LINT_OUT="$("$LINT" "$APLAN")" || fail "the lint rejected the agreement fixture: $LINT_OUT"
case "$LINT_OUT" in
    "verification-lint: OK — 2 phase(s)") ;;
    *) fail "the lint should report 2 phases, got: $LINT_OUT" ;;
esac
run_tb "$APLAN" 1
[ "$TB_RC" = "0" ] || fail "agreement fixture phase 1: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "a quoted item" "$TB_OUT" || fail "agreement fixture phase 1: the quoted block was cut short"
run_tb "$APLAN" 2
[ "$TB_RC" = "0" ] || fail "agreement fixture phase 2: expected exit 0, got $TB_RC ($TB_ERR)"
grep -q "the second phase does its own check" "$TB_OUT" || fail "agreement fixture phase 2 resolved to the wrong block"
run_tb "$APLAN" 3
[ "$TB_RC" = "2" ] || fail "the lint saw 2 phases but task-brief resolved a third: expected exit 2, got $TB_RC"

echo "PASS: test-task-brief"
