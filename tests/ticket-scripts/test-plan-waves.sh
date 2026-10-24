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

echo "test-plan-waves: Phase A cases (parse and validate)"

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
has_line "wave 1 lane 1: A" "valid plan"
has_line "wave 2 lane 1: B" "valid plan"
has_line "wave 3 lane 1: C" "valid plan"

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


echo "test-plan-waves: Phase B cases (wave scheduling via dag-lanes)"

# phasef <id> <deps-line> <complexity-line> <file...> — like phase(), with chosen Files bullets
phasef() {
    local id="$1" deps="$2" cplx="$3"
    shift 3
    emit "### Phase $id: thing $id" '' "$deps" "$cplx" '**Files:**'
    local f
    for f in "$@"; do emit '- Modify: `'"$f"'`'; done
    emit '' '**Steps:**' '1. do it' ''
}

# B1. the RED case: B depends on A, C independent
new_plan; header
phasef A "$D_NONE" "$C_LIGHT" src/a.py
phasef B '**Deps:** A' "$C_LIGHT" src/b.py
phasef C "$D_NONE" "$C_LIGHT" src/c.py
run_tool
expect 0 "A->B plus independent C" "OK — 3 phase(s), 2 wave(s)"
has_line "wave 1 lane 1: A" "A->B plus C"
has_line "wave 1 lane 2: C" "A->B plus C"
has_line "wave 2 lane 1: B" "A->B plus C"

# B2. line order: wave lines first, then phase lines, in plan order
first_wave="$(printf '%s\n' "$OUT" | grep -n '^wave ' | head -n 1 | cut -d: -f1)"
first_phase="$(printf '%s\n' "$OUT" | grep -n '^phase ' | head -n 1 | cut -d: -f1)"
[ "$first_wave" -lt "$first_phase" ] || fail "line order: wave lines must precede phase lines"
[ "$(printf '%s\n' "$OUT" | grep '^phase ' | cut -d' ' -f2 | tr -d '\n')" = "ABC" ] \
    || fail "line order: phase lines must follow plan order"

# B3. dependency chain: three waves
new_plan; header
phasef A "$D_NONE" "$C_LIGHT" src/a.py
phasef B '**Deps:** A' "$C_LIGHT" src/b.py
phasef C '**Deps:** B' "$C_LIGHT" src/c.py
run_tool
expect 0 "dependency chain" "OK — 3 phase(s), 3 wave(s)"
has_line "wave 3 lane 1: C" "dependency chain"

# B4. two phases sharing a file in the same wave: one lane, in plan order
new_plan; header
phasef A "$D_NONE" "$C_LIGHT" src/shared.py
phasef B "$D_NONE" "$C_LIGHT" src/other.py src/shared.py
phasef C "$D_NONE" "$C_LIGHT" src/c.py
run_tool
expect 0 "shared file, one lane" "OK — 3 phase(s), 1 wave(s)"
has_line "wave 1 lane 1: A B" "shared file, one lane"
has_line "wave 1 lane 2: C" "shared file, one lane"

# B5. cycle A <-> B
new_plan; header
phasef A '**Deps:** B' "$C_LIGHT" src/a.py
phasef B '**Deps:** A' "$C_LIGHT" src/b.py
run_tool
expect 1 "cycle" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *cycle*) : ;; *) fail "cycle: line 1 must say cycle" ;; esac

# B6. unknown dep names the phase and the missing id
new_plan; header
phasef A '**Deps:** Q' "$C_LIGHT" src/a.py
run_tool
expect 1 "unknown dep" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *"phase A "*Q*) : ;; *) fail "unknown dep: line 1 must name phase A and Q" ;; esac

# B7. self-dep
new_plan; header
phasef A '**Deps:** A' "$C_LIGHT" src/a.py
run_tool
expect 1 "self-dep" "BLOCKING"
case "$(printf '%s\n' "$OUT" | head -n 1)" in *"phase A "*) : ;; *) fail "self-dep: line 1 must name phase A" ;; esac

# B8. dag-lanes unreachable: a copy of plan-waves in a tree with no sibling dag-lanes
ORPHAN="$WORK/orphan/skills/gaspol-plan/scripts"
mkdir -p "$ORPHAN"
cp "$TOOL" "$ORPHAN/plan-waves"
new_plan; header
phasef A "$D_NONE" "$C_LIGHT" src/a.py
set +e
OUT="$("$ORPHAN/plan-waves" "$PLAN" 2>"$WORK/stderr")"; RC=$?
set -e
ERR="$(cat "$WORK/stderr")"
expect 3 "dag-lanes missing" "UNKNOWN"

# B9. dag-lanes present but not executable, crashing, or printing garbage
FAKE="$WORK/fake/skills/gaspol-parallel/scripts"
mkdir -p "$FAKE" "$WORK/fake/skills/gaspol-plan/scripts"
cp "$TOOL" "$WORK/fake/skills/gaspol-plan/scripts/plan-waves"
run_fake() {
    set +e
    OUT="$("$WORK/fake/skills/gaspol-plan/scripts/plan-waves" "$PLAN" 2>"$WORK/stderr")"; RC=$?
    set -e
    ERR="$(cat "$WORK/stderr")"
}
printf '#!/bin/sh\necho hello\n' > "$FAKE/dag-lanes"; chmod 644 "$FAKE/dag-lanes"
run_fake
expect 3 "dag-lanes not executable" "UNKNOWN"
printf '#!/bin/sh\necho "boom" >&2\nexit 2\n' > "$FAKE/dag-lanes"; chmod 755 "$FAKE/dag-lanes"
run_fake
expect 3 "dag-lanes crashed" "UNKNOWN"
printf '#!/bin/sh\necho "no json here"\nexit 0\n' > "$FAKE/dag-lanes"
run_fake
expect 3 "dag-lanes printed no JSON" "UNKNOWN"
printf '#!/bin/sh\necho JSON\necho "{not json"\nexit 0\n' > "$FAKE/dag-lanes"
run_fake
expect 3 "dag-lanes printed malformed JSON" "UNKNOWN"
printf '#!/bin/sh\necho JSON\necho "{\\"waves\\": 7}"\nexit 0\n' > "$FAKE/dag-lanes"
run_fake
expect 3 "dag-lanes printed wrong JSON shape" "UNKNOWN"

# B10. empty Files is allowed
new_plan; header
emit '### Phase A: no files' '' "$D_NONE" "$C_LIGHT" '**Files:**' '' '**Steps:**' '1. x' ''
phasef B "$D_NONE" "$C_LIGHT" src/b.py
run_tool
expect 0 "empty Files allowed" "OK — 2 phase(s), 1 wave(s)"

# B11. a phase with no Files line at all is also allowed
new_plan; header
emit '### Phase A: no files line' '' "$D_NONE" "$C_LIGHT" '' '**Steps:**' '1. x' ''
run_tool
expect 0 "no Files line allowed" "OK — 1 phase(s), 1 wave(s)"

# B12. twelve phases schedule without error: a chain of four with eight leaves
new_plan; header
phasef A "$D_NONE" "$C_LIGHT" src/a.py
phasef B '**Deps:** A' "$C_LIGHT" src/b.py
phasef C '**Deps:** B' "$C_LIGHT" src/c.py
phasef D '**Deps:** C' "$C_LIGHT" src/d.py
for id in E F G H I J K L; do phasef "$id" '**Deps:** D' "$C_LIGHT" "src/$id.py"; done
run_tool
expect 0 "twelve phases" "OK — 12 phase(s), 5 wave(s)"
[ "$(printf '%s\n' "$OUT" | grep -c '^phase ')" = 12 ] || fail "twelve phases: want 12 phase lines"
has_line "wave 5 lane 8: L" "twelve phases"

# B13. live fixture: this ticket's own plan. A fixture green only on synthetic plans
#      proves nothing about the plan it ships with.
LIVE="$REPO_ROOT/docs/plans/2026-10-24-IDS-22-parallel-waves-and-complexity-plan.md"
run_tool "$LIVE"
expect 0 "live fixture: IDS-22 plan" "OK — 6 phase(s), 4 wave(s)"
[ "$(printf '%s\n' "$OUT" | grep -c '^phase ')" = 6 ] || fail "live fixture: want 6 phase lines"
has_line "wave 1 lane 1: A" "live fixture"
has_line "wave 2 lane 1: B" "live fixture"
has_line "wave 3 lane 1: C" "live fixture"
has_line "wave 3 lane 2: D" "live fixture"
has_line "wave 3 lane 3: E" "live fixture"
has_line "wave 4 lane 1: F" "live fixture"
has_line "phase D complexity=complex model=sonnet effort=high review=opus" "live fixture"
has_line "phase F complexity=light model=sonnet effort=low review=none" "live fixture"

echo "test-plan-waves: all Phase A and Phase B cases passed"
