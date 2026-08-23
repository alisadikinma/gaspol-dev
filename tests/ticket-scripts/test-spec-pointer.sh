#!/usr/bin/env bash
# test-spec-pointer.sh — the plan header's spec pointer resolves in three states (IDS-18 Phase A)
#
# gaspol-plan has written `**Spec:** <path>` into every plan header since IDS-1
# and nothing ever read it — `grep -rn -- "-spec.md" skills/ agents/` found five
# hits, all of them either a glob that FINDS a spec or a filename mentioned in
# prose. This asserts the resolver that finally reads it.
#
# The load-bearing case is exit 3, not exit 0. A broken pointer that degrades to
# "no spec" is silently indistinguishable from a standalone plan, and an empty
# spec reads as "nothing was violated" — which is design_audit.py's own defect
# one layer down (KB: silence-over-falsehood-in-error-states).
#
# Every case builds a REAL git repository in a temp dir. Path resolution is the
# thing most likely to be wrong (an agent runs a SKILL.md bash block with the
# TARGET PROJECT as its CWD), and a mocked repo cannot exercise it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POINTER="$REPO_ROOT/skills/gaspol-verify/scripts/spec-pointer"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# Builds a throwaway git repo; echoes its path.
#   $1 = the literal **Spec:** line to write into the plan header, or the empty
#        string for a plan carrying no such line at all.
#   $2 = the spec file's body. Empty string writes no spec file.
#   $3 = optional spec filename, default docs/plans/x-spec.md
make_repo() {
    local spec_line="$1" spec_body="$2" spec_name="${3:-docs/plans/x-spec.md}"
    local d; d="$(mktemp -d "$TMPROOT/repo.XXXXXX")"
    git -C "$d" init -q
    # The CANONICAL root. macOS mktemp returns /var/..., git rev-parse resolves
    # the symlink to /private/var/... — comparing the two forms fails a script
    # that is behaving correctly, which is a test defect, not a code defect.
    d="$(git -C "$d" rev-parse --show-toplevel)"
    mkdir -p "$d/docs/plans"
    {
        echo "**Ticket:** IDS-18"
        echo "**Ledger:** .gaspol/progress/PROGRESS-IDS-18.md"
        [ -n "$spec_line" ] && echo "$spec_line"
        echo ""
        echo "## Goal"
    } > "$d/docs/plans/x-plan.md"
    if [ -n "$spec_body" ]; then
        mkdir -p "$d/$(dirname "$spec_name")"
        printf '%s\n' "$spec_body" > "$d/$spec_name"
    fi
    echo "$d"
}

# Runs the pointer from INSIDE the repo, captures stdout, stderr and exit code.
# Deliberately does not `cd` back: each call is a subshell.
run_pointer() {
    local dir="$1" plan="${2:-docs/plans/x-plan.md}"
    OUT=""; ERR=""; RC=0
    OUT="$( cd "$dir" && "$POINTER" "$plan" 2>"$TMPROOT/err" )" || RC=$?
    ERR="$(cat "$TMPROOT/err")"
    return 0
}

GOOD_SPEC='**Ticket:** IDS-18

# Title

## Design

- first requirement
- second requirement'

echo "test-spec-pointer: the script exists and self-tests..."
[ -x "$POINTER" ] || fail "spec-pointer is not present or not executable at $POINTER"
bash "$POINTER" --self-test >/dev/null 2>&1 || fail "spec-pointer --self-test did not exit 0"

echo "test-spec-pointer: case 1 — pointer resolves, content parseable -> exit 0..."
d="$(make_repo '**Spec:** docs/plans/x-spec.md' "$GOOD_SPEC")"
run_pointer "$d"
[ "$RC" = 0 ] || fail "case1 expected exit 0, got $RC (stderr: $ERR)"
[ "$OUT" = "$d/docs/plans/x-spec.md" ] \
    || fail "case1 stdout must be the ABSOLUTE spec path, got '$OUT'"

echo "test-spec-pointer: case 2 — no **Spec:** line -> exit 4, not a failure..."
d="$(make_repo '' '')"
run_pointer "$d"
[ "$RC" = 4 ] || fail "case2 (standalone plan) expected exit 4, got $RC"
[ -z "$OUT" ] || fail "case2 must print no path on stdout, got '$OUT'"

echo "test-spec-pointer: case 3 — empty value after the colon -> exit 3..."
d="$(make_repo '**Spec:**' "$GOOD_SPEC")"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case3 (bare label) expected exit 3, got $RC — a label with nothing after it is not a pointer"

echo "test-spec-pointer: case 4 — whitespace-only value -> exit 3..."
d="$(make_repo '**Spec:**    ' "$GOOD_SPEC")"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case4 (whitespace value) expected exit 3, got $RC"

echo "test-spec-pointer: case 5 — trailing HTML comment is stripped -> exit 0..."
# This is the COMMON case, not an exotic one: gaspol-plan's own header template
# at skills/gaspol-plan/SKILL.md:126 ships the comment on the same line.
d="$(make_repo '**Spec:** docs/plans/x-spec.md <!-- omit entirely if standalone -->' "$GOOD_SPEC")"
run_pointer "$d"
[ "$RC" = 0 ] || fail "case5 (trailing HTML comment) expected exit 0, got $RC (stderr: $ERR)"
[ "$OUT" = "$d/docs/plans/x-spec.md" ] \
    || fail "case5 did not strip the trailing comment, got '$OUT'"

echo "test-spec-pointer: case 6 — pointer names a file that does not exist -> exit 3..."
d="$(make_repo '**Spec:** docs/plans/nope-spec.md' "$GOOD_SPEC")"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case6 (missing spec file) expected exit 3, got $RC — must NEVER degrade to exit 4"

echo "test-spec-pointer: case 7 — two **Spec:** lines -> exit 3..."
d="$(make_repo '**Spec:** docs/plans/x-spec.md' "$GOOD_SPEC")"
printf '**Spec:** docs/plans/other-spec.md\n' >> "$d/docs/plans/x-plan.md"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case7 (ambiguous pointer) expected exit 3, got $RC"

echo "test-spec-pointer: case 8 — plan file itself missing -> exit 3..."
d="$(make_repo '' '')"
run_pointer "$d" "docs/plans/does-not-exist-plan.md"
[ "$RC" = 3 ] || fail "case8 (missing plan) expected exit 3, got $RC — distinct from 'the plan has no spec'"

echo "test-spec-pointer: case 9 — spec file is empty -> exit 3..."
d="$(make_repo '**Spec:** docs/plans/x-spec.md' '')"
: > "$d/docs/plans/x-spec.md"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case9 (empty spec) expected exit 3, got $RC — zero requirements must not read as 'satisfied'"

echo "test-spec-pointer: case 10 — spec has prose but no structure -> exit 3..."
d="$(make_repo '**Spec:** docs/plans/x-spec.md' 'just a sentence
and another sentence
and a third one')"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case10 (no bullet, table or heading) expected exit 3, got $RC"

echo "test-spec-pointer: case 11 — spec of exactly one line -> exit 3..."
d="$(make_repo '**Spec:** docs/plans/x-spec.md' '# Title')"
run_pointer "$d"
[ "$RC" = 3 ] || fail "case11 (one-line spec) expected exit 3, got $RC"

echo "test-spec-pointer: case 12 — repo-relative path resolved from a foreign CWD -> exit 0..."
# The whole point: an agent runs the caller with the TARGET PROJECT as its CWD.
# Resolving against \$PWD instead of the repo root is the IDS-8 hazard class.
d="$(make_repo '**Spec:** docs/plans/x-spec.md' "$GOOD_SPEC")"
foreign="$(mktemp -d "$TMPROOT/foreign.XXXXXX")"
RC=0
OUT="$( cd "$foreign" && "$POINTER" "$d/docs/plans/x-plan.md" 2>/dev/null )" || RC=$?
[ "$RC" = 0 ] || fail "case12 (foreign CWD) expected exit 0, got $RC"
[ "$OUT" = "$d/docs/plans/x-spec.md" ] \
    || fail "case12 resolved against the wrong root, got '$OUT'"

echo "test-spec-pointer: case 13 — absolute spec path in the header -> exit 0..."
d="$(make_repo '' "$GOOD_SPEC")"
printf '**Spec:** %s\n' "$d/docs/plans/x-spec.md" >> "$d/docs/plans/x-plan.md"
run_pointer "$d"
[ "$RC" = 0 ] || fail "case13 (absolute path) expected exit 0, got $RC (stderr: $ERR)"
[ "$OUT" = "$d/docs/plans/x-spec.md" ] || fail "case13 got '$OUT'"

echo "test-spec-pointer: case 14 — spec path containing spaces -> exit 0..."
d="$(make_repo '**Spec:** docs/plans/my spec-spec.md' "$GOOD_SPEC" 'docs/plans/my spec-spec.md')"
run_pointer "$d"
[ "$RC" = 0 ] || fail "case14 (path with spaces) expected exit 0, got $RC (stderr: $ERR)"
[ "$OUT" = "$d/docs/plans/my spec-spec.md" ] || fail "case14 got '$OUT'"

echo "test-spec-pointer: a report line is written on EVERY exit path..."
# Captured so a caller can record the state unconditionally, the way
# regression-gate's report line is. On stderr, so stdout stays a clean path.
for spec_line in '**Spec:** docs/plans/x-spec.md' '' '**Spec:**' '**Spec:** docs/plans/nope-spec.md'; do
    d="$(make_repo "$spec_line" "$GOOD_SPEC")"
    run_pointer "$d"
    case "$ERR" in
        *"spec-pointer:"*) ;;
        *) fail "no 'spec-pointer:' report line for header [$spec_line] (exit $RC)" ;;
    esac
done

echo "test-spec-pointer: resolution never uses \$PWD..."
# Positive control first: prove the search can see the file's contents at all,
# otherwise a clean result below proves nothing (KB: vacuous-assertion-proves-nothing).
CONTROL=$(grep -c 'spec-pointer' "$POINTER" || true)
[ "${CONTROL:-0}" -ge 3 ] \
    || fail "positive control matched only ${CONTROL:-0} line(s) — the search is broken, so the check below would be vacuous"
# COMMENT LINES ARE EXCLUDED, and that is not an exemption — it is the shape.
# The script's own docstring explains the hazard by NAMING $PWD, and a gate that
# trips on prose describing the thing it forbids is the failure this repository
# has already hit five times on one branch (test-kb-no-hardcoded-path.sh carries
# the same reasoning for the same reason). A line that RUNS is a line that is not
# a comment.
USES_PWD="$(grep -nE '\$PWD|`pwd`|\$\(pwd\)' "$POINTER" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
[ -z "$USES_PWD" ] \
    || { echo "$USES_PWD" >&2; fail "spec-pointer resolves against the working directory — an agent runs this with the TARGET PROJECT as CWD; use git rev-parse --show-toplevel"; }

echo "PASS: test-spec-pointer"
