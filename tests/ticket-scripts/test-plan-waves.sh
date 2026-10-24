#!/usr/bin/env bash
# test-plan-waves.sh — Phase A of skills/gaspol-plan/scripts/plan-waves (IDS-22)
#
# plan-waves validates the `waves-v1` fields a plan carries per phase (Deps,
# Complexity) and prints the per-phase model/effort/review mapping. This file
# covers exits 0 / 1 / 3 / 4 and the parsing edge cases. Wave and lane lines
# arrive in Phase B and are tested there.
#
# Exit contract (same as ledger-gate / model-gate): one `plan-waves: <verdict>`
# line on stdout on EVERY path, detail on stderr.
#
# Every case writes its plan into a throwaway mktemp dir. Nothing here touches
# the real repository or any real plan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL="$REPO_ROOT/skills/gaspol-plan/scripts/plan-waves"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$TOOL" ] || fail "plan-waves: No such file or directory (or not executable): $TOOL"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

CASE_N=0
PLAN=""

# new_plan — start a fresh, empty plan file for the next case
new_plan() {
    CASE_N=$((CASE_N + 1))
    mkdir -p "$WORK/case-$CASE_N"
    PLAN="$WORK/case-$CASE_N/plan.md"
    : > "$PLAN"
}

# emit <text...> — append literal lines to the current plan
emit() { printf '%s\n' "$@" >> "$PLAN"; }

header() { emit '# Plan' '' '**Format:** waves-v1' ''; }

# phase <id> <deps-line-or-empty> <complexity-line-or-empty>
# An empty argument omits that line entirely.
phase() {
    emit "### Phase $1: thing $1" ''
    [ -z "$2" ] || emit "$2"
    [ -z "$3" ] || emit "$3"
    emit '**Files:**' '- Create: `src/'"$1"'.py`' '' '**Steps:**' '1. do it' ''
}

run_tool() {
    set +e
    OUT="$("$TOOL" "${1:-$PLAN}" 2>"$WORK/stderr")"
    RC=$?
    set -e
    ERR="$(cat "$WORK/stderr")"
}

# expect <want_rc> <label> [stdout-line-1-substring]
expect() {
    local want="$1" label="$2" needle="${3:-}"
    [ "$RC" = "$want" ] || fail "$label: expected exit $want, got $RC (stdout: $OUT)"
    local first
    first="$(printf '%s\n' "$OUT" | head -n 1)"
    case "$first" in
        "plan-waves: "*) : ;;
        *) fail "$label: stdout line 1 must start with 'plan-waves: ', got: $first" ;;
    esac
    if [ -n "$needle" ]; then
        case "$first" in
            *"$needle"*) : ;;
            *) fail "$label: expected line 1 to contain '$needle', got: $first" ;;
        esac
    fi
    echo "  ok — $label (exit $want)"
}

# has_line <exact line> <label> — a whole stdout line must equal the string
has_line() {
    printf '%s\n' "$OUT" | grep -qxF -- "$1" || fail "$2: missing stdout line: $1 (stdout: $OUT)"
}

# lacks <substring> <label>
lacks() {
    case "$OUT" in
        *"$1"*) fail "$2: stdout must not contain '$1' (stdout: $OUT)" ;;
    esac
}

D_NONE='**Deps:** none'
C_LIGHT='**Complexity:** light — one file, no decision'
C_MED='**Complexity:** medium — several files, known pattern'
C_CPLX='**Complexity:** complex — new logic other phases consume'

echo "test-plan-waves: Phase A cases"

# 1. valid plan: exit 0, phase lines carry the mapping
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
phase B '**Deps:** A' "$C_MED"
phase C '**Deps:** A, B' "$C_CPLX"
run_tool
expect 0 "valid plan" "OK — 3 phase(s)"
has_line "phase A complexity=light model=sonnet effort=low review=none" "valid plan"
has_line "phase B complexity=medium model=sonnet effort=medium review=none" "valid plan"
has_line "phase C complexity=complex model=sonnet effort=high review=opus" "valid plan"
[ "$(printf '%s\n' "$OUT" | grep -c '^phase ')" = 3 ] || fail "valid plan: want exactly 3 phase lines"
[ "$(printf '%s\n' "$OUT" | grep -c '^wave ')" = 0 ] || fail "valid plan: wave lines are Phase B, none expected yet"

# 2. no Format header: exit 4, never a pass
new_plan
emit '# Plan' '' '### Phase A: legacy' '' '**Files:**' '- Create: `x`'
run_tool
expect 4 "no format header" "N/A — no waves-v1 format header; treat as sequential, all medium"

# 3. header, phase without Deps
new_plan; header
phase A "" "$C_LIGHT"
run_tool
expect 1 "missing Deps" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *"phase A "*) : ;; *) fail "missing Deps: line 1 must name phase A" ;; esac

# 4. header, phase without Complexity (the RED case from the brief)
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
phase B "$D_NONE" ""
run_tool
expect 1 "missing Complexity" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *"phase B "*) : ;; *) fail "missing Complexity: line 1 must name phase B" ;; esac

# 5. bare label, dash but empty reason
new_plan; header
phase A "$D_NONE" '**Complexity:** complex —'
run_tool
expect 1 "bare label, empty reason" "BLOCKING"

# 5b. dash followed only by spaces
new_plan; header
phase A "$D_NONE" '**Complexity:** complex —    '
run_tool
expect 1 "bare label, whitespace reason" "BLOCKING"

# 6. bare label, no dash at all
new_plan; header
phase A "$D_NONE" '**Complexity:** complex'
run_tool
expect 1 "bare label, no dash" "BLOCKING"

# 7. unknown label value
new_plan; header
phase A "$D_NONE" '**Complexity:** hard — it is hard'
run_tool
expect 1 "value hard" "BLOCKING"

# 8. duplicate phase id
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
phase A "$D_NONE" "$C_LIGHT"
run_tool
expect 1 "duplicate phase id" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *"phase A "*) : ;; *) fail "duplicate id: line 1 must name phase A" ;; esac

# 9. a phase heading only inside a fenced block is not a phase
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
emit '```text' '### Phase Z: shown as an example' '```' ''
run_tool
expect 0 "fenced heading ignored" "OK — 1 phase(s)"
lacks "phase Z" "fenced heading ignored"

# 9b. a Format header inside a fence is not a header
new_plan
emit '# Plan' '```text' '**Format:** waves-v1' '```' '' '### Phase A: x' ''
run_tool
expect 4 "fenced format header ignored" "N/A"

# 10. header present, zero phases: UNKNOWN
new_plan; header
emit '## Overview' 'no phases here'
run_tool
expect 3 "zero phases" "UNKNOWN"

# 11. nonexistent path
run_tool "$WORK/does-not-exist.md"
expect 3 "nonexistent path" "UNKNOWN"
[ -n "$ERR" ] || fail "nonexistent path: stderr must carry the reason"

# 11b. empty file
new_plan
run_tool
expect 3 "empty file" "UNKNOWN"

# 11c. non-UTF-8 bytes
new_plan; header
printf '### Phase A: caf\xe9\n**Deps:** none\n' >> "$PLAN"
run_tool
expect 3 "non-UTF-8 bytes" "UNKNOWN"

# 11d. unreadable file (skipped when running as root, where chmod 000 is no barrier)
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
chmod 000 "$PLAN"
if [ -r "$PLAN" ]; then
    echo "  skip — unreadable file (running with read access despite chmod 000)"
else
    run_tool
    expect 3 "unreadable file" "UNKNOWN"
fi
chmod 644 "$PLAN"

# 11e. a directory is not a plan
run_tool "$WORK"
expect 3 "directory as path" "UNKNOWN"

# 12. Deps forms: none, single, list; wave count follows from them
new_plan; header
phase A '**Deps:** none' "$C_LIGHT"
phase B '**Deps:** A' "$C_LIGHT"
phase C '**Deps:** A,B' "$C_LIGHT"
run_tool
expect 0 "deps list forms" "OK — 3 phase(s), 3 wave(s)"

new_plan; header
phase A "$D_NONE" "$C_LIGHT"
phase B "$D_NONE" "$C_LIGHT"
run_tool
expect 0 "two independent phases" "OK — 2 phase(s), 1 wave(s)"

# 12b. Deps value with an illegal id token
new_plan; header
phase A '**Deps:** none, B' "$C_LIGHT"
run_tool
expect 1 "none mixed with ids" "BLOCKING"

new_plan; header
phase A '**Deps:** ' "$C_LIGHT"
run_tool
expect 1 "empty Deps value" "BLOCKING"

# 13. spaced hyphen separator accepted
new_plan; header
phase A "$D_NONE" '**Complexity:** medium - several files, known pattern'
run_tool
expect 0 "spaced hyphen separator" "OK — 1 phase(s)"
has_line "phase A complexity=medium model=sonnet effort=medium review=none" "spaced hyphen"

# 13b. an unspaced hyphen is not a separator
new_plan; header
phase A "$D_NONE" '**Complexity:** medium-several files'
run_tool
expect 1 "unspaced hyphen" "BLOCKING"

# 14. Format header and fields read from the argument, not $PWD
new_plan; header
phase A "$D_NONE" "$C_LIGHT"
mkdir -p "$WORK/elsewhere/deep"
set +e
OUT="$(cd "$WORK/elsewhere/deep" && "$TOOL" "$PLAN" 2>/dev/null)"
RC=$?
set -e
expect 0 "run from a subdirectory" "OK — 1 phase(s)"

# 15. plan text is data: shell metacharacters in values never execute or reach output unparsed
new_plan; header
MARK="$WORK/pwned"
emit '### Phase A: $(touch '"$MARK"') `touch '"$MARK"'`' ''
emit '**Deps:** none' '**Complexity:** light — $(touch '"$MARK"')' ''
run_tool
expect 0 "metacharacters stay inert" "OK — 1 phase(s)"
[ ! -e "$MARK" ] || fail "metacharacters: plan text was executed"

# 16. a missing argument is UNKNOWN, still one verdict line
set +e
OUT="$("$TOOL" 2>"$WORK/stderr")"
RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
expect 3 "no argument" "UNKNOWN"

# 17. Format header tolerated with trailing spaces; other format values are not waves-v1
new_plan
emit '# Plan' '**Format:** waves-v1   ' ''
phase A "$D_NONE" "$C_LIGHT"
run_tool
expect 0 "trailing spaces on header" "OK — 1 phase(s)"

new_plan
emit '# Plan' '**Format:** waves-v2' ''
phase A "$D_NONE" "$C_LIGHT"
run_tool
expect 4 "other format value" "N/A"

echo "test-plan-waves: all Phase A cases passed"
