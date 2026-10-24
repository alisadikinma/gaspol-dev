#!/usr/bin/env bash
# test-verification-lint.sh — TDD test for skills/gaspol-plan/scripts/verification-lint (IDS-23 Phase B)
#
# verification-lint reads a plan and refuses a phase whose Verification block holds
# nothing but generic lines (the header-block commands, `static:`/`unit:` lines,
# the placeholder-comment line, an unfilled `real data from [`). The generic lines
# live ONCE in the plan header's `**Verification commands:**` block; each phase
# carries only what is specific to it.
#
# Four exit states on the house contract, ONE `verification-lint: <verdict>` stdout
# line on every path:
#   0 OK   1 BLOCKING   3 UNKNOWN   4 N/A (legacy plan, never a pass)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$REPO_ROOT/skills/gaspol-plan/scripts/verification-lint"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$LINT" ] || fail "verification-lint: No such file or directory (or not executable): $LINT"

# run_lint <plan> -> sets RC, OUT (stdout), ERR (stderr)
run_lint() {
    set +e
    OUT="$("$LINT" "$@" 2>"$TMP/stderr")"
    RC=$?
    set -e
    ERR="$(cat "$TMP/stderr")"
}

# expect <label> <exit> <stdout-exact-or-prefix> -- <lint args...>
expect() {
    local label="$1" want_rc="$2" want_out="$3"
    shift 3
    run_lint "$@"
    [ "$RC" = "$want_rc" ] || fail "$label: expected exit $want_rc, got $RC (stdout: $OUT)"
    case "$OUT" in
        "$want_out"*) : ;;
        *) fail "$label: expected stdout starting '$want_out', got '$OUT'" ;;
    esac
    # The contract: exactly ONE stdout line, and it carries the prefix.
    local lines
    lines="$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
    [ "$lines" = "1" ] || fail "$label: stdout must be exactly one line, got $lines: $OUT"
    case "$OUT" in
        "verification-lint: "*) : ;;
        *) fail "$label: stdout does not start with 'verification-lint: ': $OUT" ;;
    esac
    echo "  ok — $label"
}

HEADER='**Format:** waves-v1

**Verification commands:**
- static: npx tsc --noEmit
- unit: npm test

## Goal

demo
'

# --- exit 0: every phase carries a phase-specific line -----------------------
GOOD="$TMP/good-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: first thing

**Steps:**
1. Write failing test for the first thing. Expected error: `not defined`.

**Verification:**
- [ ] `npx tsc --noEmit` passes
- [ ] SegmentCard renders with real data from WorkspaceContext
- [x] No placeholder/TODO comments in new code

---

### Phase B: second thing

**Verification:**
- [ ] the retry loop stops after 3 attempts and returns exit 5
EOF
} > "$GOOD"

# --- exit 1: one phase has only generic lines --------------------------------
GENERIC="$TMP/generic-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: specific enough

**Verification:**
- [ ] the parser rejects an empty heading

---

### Phase B: nothing but boilerplate

**Verification:**
- [ ] `npx tsc --noEmit` passes
- [ ] `npm test` passes
- [ ] static: npx tsc --noEmit passes
- [ ] unit: anything passes
- [ ] No placeholder/TODO comments in new code
- [ ] Component renders with real data from [specific source]
EOF
} > "$GENERIC"

# --- exit 1: a phase with no Verification lines at all -----------------------
NOVERIF="$TMP/noverif-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: has a block

**Verification:**
- [ ] the writer flushes before exit

---

### Phase C: has no block

**Steps:**
1. Write failing test for something. Expected error: `x`.
EOF
} > "$NOVERIF"

# --- exit 1: the Verification: marker exists but holds zero items ------------
EMPTYBLOCK="$TMP/emptyblock-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase D: empty block

**Verification:**
EOF
} > "$EMPTYBLOCK"

# --- exit 4: legacy plan, no header block ------------------------------------
LEGACY="$TMP/legacy-plan.md"
cat > "$LEGACY" <<'EOF'
**Ticket:** XYZ-1

### Phase A: old style

**Verification:**
- [ ] `npm test` passes
- [ ] No placeholder/TODO comments in new code
EOF

# --- exit 3: header block present, zero phases -------------------------------
NOPHASES="$TMP/nophases-plan.md"
printf '%s\n' "$HEADER" > "$NOPHASES"

# --- exit 3: header block with no `- ` lines ---------------------------------
EMPTYHEAD="$TMP/emptyhead-plan.md"
cat > "$EMPTYHEAD" <<'EOF'
**Verification commands:**

### Phase A: x

**Verification:**
- [ ] a thing only this phase does
EOF

: > "$TMP/empty.md"

echo "test-verification-lint: exit 0 — every phase has a phase-specific line..."
expect "good plan" 0 "verification-lint: OK — 2 phase(s)" "$GOOD"

echo "test-verification-lint: exit 1 — generic-only and missing blocks..."
expect "generic-only phase" 1 "verification-lint: BLOCKING — phase B has no phase-specific verification" "$GENERIC"
expect "phase with no Verification lines" 1 "verification-lint: BLOCKING — phase C has no phase-specific verification" "$NOVERIF"
expect "Verification marker, zero items" 1 "verification-lint: BLOCKING — phase D has no phase-specific verification" "$EMPTYBLOCK"

echo "test-verification-lint: exit 4 — a legacy plan is never a pass..."
expect "legacy plan" 4 "verification-lint: N/A — no Verification commands header; legacy plan, never a pass" "$LEGACY"

echo "test-verification-lint: exit 3 — unknown states stop..."
expect "unreadable path" 3 "verification-lint: UNKNOWN — " "$TMP/does-not-exist.md"
expect "a directory" 3 "verification-lint: UNKNOWN — " "$TMP"
expect "empty file" 3 "verification-lint: UNKNOWN — " "$TMP/empty.md"
expect "header block, zero phases" 3 "verification-lint: UNKNOWN — " "$NOPHASES"
expect "header block with no commands" 3 "verification-lint: UNKNOWN — " "$EMPTYHEAD"
expect "no argument" 3 "verification-lint: UNKNOWN — "
expect "two arguments" 3 "verification-lint: UNKNOWN — " "$GOOD" "$GOOD"

printf '\xff\xfe not utf8\n' > "$TMP/binary.md"
expect "non-UTF-8 plan" 3 "verification-lint: UNKNOWN — " "$TMP/binary.md"

echo "test-verification-lint: header-block boundaries..."
# The block ends at the first blank line or non-`- ` line. A `- unit: npm test`
# bullet AFTER the blank line is not a header command, so a phase line made of it
# is specific.
AFTERBLANK="$TMP/afterblank-plan.md"
cat > "$AFTERBLANK" <<'EOF'
**Verification commands:**
- static: npx tsc --noEmit

- unit: npm test

### Phase A: x

**Verification:**
- [ ] `npm test` passes
EOF
expect "bullet after the blank line is not a header command" 0 "verification-lint: OK — 1 phase(s)" "$AFTERBLANK"

echo "test-verification-lint: generic-line rules..."
RULES="$TMP/rules-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: a real line next to a TODO-comment line

**Verification:**
- [ ] No placeholder in new code
- [ ] the importer skips rows with a blank id
EOF
} > "$RULES"
expect "specific line beside a generic one" 0 "verification-lint: OK — 1 phase(s)" "$RULES"

PREFIXES="$TMP/prefixes-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: prefix lines only

**Verification:**
- [ ] lint: eslint src
- [ ] build: make all
- [ ] detect-stack: no stack markers for this project — verification is plan-declared only
- [ ] TODO comments absent
EOF
} > "$PREFIXES"
expect "lint:/build:/detect-stack:/TODO-comments are generic" 1 "verification-lint: BLOCKING — phase A has no phase-specific verification" "$PREFIXES"

# "real data from [" is generic only while the bracket is unfilled.
FILLED="$TMP/filled-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: a concrete source

**Verification:**
- [ ] Component renders with real data from useWorkspace()
EOF
} > "$FILLED"
expect "a concrete source is specific" 0 "verification-lint: OK — 1 phase(s)" "$FILLED"

# UNKNOWN / no-markers header variants must not turn every line generic.
VARIANTS="$TMP/variants-plan.md"
cat > "$VARIANTS" <<'EOF'
**Verification commands:**
- unit: UNKNOWN — ask user before Verification can run
- detect-stack: no stack markers for this project — verification is plan-declared only

### Phase A: x

**Verification:**
- [ ] the report lists 3 rows
EOF
expect "UNKNOWN header variant leaves other lines specific" 0 "verification-lint: OK — 1 phase(s)" "$VARIANTS"

echo "test-verification-lint: fenced blocks are not phases..."
FENCED="$TMP/fenced-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase A: real

**Verification:**
- [ ] a check only phase A makes

Example of the template:

```markdown
### Phase Z: example inside a fence

**Verification:**
- [ ] `npm test` passes
```
EOF
} > "$FENCED"
expect "a phase heading inside a fence is ignored" 0 "verification-lint: OK — 1 phase(s)" "$FENCED"

# task-brief matches the header line after stripping TRAILING blanks only; the lint must
# not be more lenient on the left, or the two disagree on whether a plan has the header.
INDENTED="$TMP/indented-plan.md"
printf '  **Verification commands:**\n- unit: npm test\n\n### Phase A: x\n\n**Verification:**\n- [ ] a check\n' > "$INDENTED"
expect "an indented header line is not the header" 4 "verification-lint: N/A — " "$INDENTED"

# task-brief strips only space, tab and CR from the end of a line. Python's bare rstrip() also
# strips NBSP and other Unicode spaces, so a header line ending in NBSP was a header for the
# lint and not for task-brief, and the brief silently lost the commands.
NBSP="$TMP/nbsp-plan.md"
printf '**Verification commands:**\xc2\xa0\n- unit: npm test\n\n### Phase A: x\n\n**Verification:**\n- [ ] a check\n' > "$NBSP"
expect "a header line ending in NBSP is not the header" 4 "verification-lint: N/A — " "$NBSP"

echo "test-verification-lint: a malformed phase heading is refused, never skipped..."
# A heading that LOOKS like a phase but fails the strict form used to fall into the
# "other heading" branch, so a phase made of generic lines was never checked.
n=0
for bad in '### Phase: Cleanup' '### Phase-B cleanup' '### phase a' '### Phase' '### Phase1: x' '### PhaseB x' '### Phase_B x'; do
    n=$((n + 1))
    MAL="$TMP/malformed-$n-plan.md"
    {
        printf '%s\n' "$HEADER"
        printf '### Phase A: good\n\n**Verification:**\n- [ ] the parser rejects an empty heading\n\n'
        printf '%s\n\n**Verification:**\n- [ ] `npm test` passes\n' "$bad"
    } > "$MAL"
    expect "malformed heading '$bad'" 3 "verification-lint: UNKNOWN — malformed phase heading" "$MAL"
    case "$OUT$ERR" in
        *Cleanup*|*"phase a"*|*Phase-B*|*Phase1*|*PhaseB*|*Phase_B*) fail "malformed heading '$bad': the heading text was echoed: $OUT $ERR" ;;
    esac
done
# "Phases overview" and other non-phase headings stay ordinary headings.
PLURAL="$TMP/plural-heading-plan.md"
{
    printf '%s\n' "$HEADER"
    printf '### Phases\n\ntext\n\n### Phase A: good\n\n**Verification:**\n- [ ] the parser rejects an empty heading\n'
} > "$PLURAL"
expect "'### Phases' alone is not a phase heading" 0 "verification-lint: OK — 1 phase(s)" "$PLURAL"
OTHER="$TMP/other-heading-plan.md"
{
    printf '%s\n' "$HEADER"
    printf '### Phases overview\n\ntext\n\n### Phase A: good\n\n**Verification:**\n- [ ] the parser rejects an empty heading\n'
} > "$OTHER"
expect "'### Phases overview' is not a phase heading" 0 "verification-lint: OK — 1 phase(s)" "$OTHER"

echo "test-verification-lint: plan text is never echoed or executed..."
EVIL="$TMP/evil-plan.md"
{
    printf '%s\n' "$HEADER"
    cat <<'EOF'
### Phase $(touch PWNED): boom

**Verification:**
- [ ] `npm test` passes
EOF
} > "$EVIL"
(cd "$TMP" && "$LINT" "$EVIL" >"$TMP/evil.out" 2>"$TMP/evil.err") && EVIL_RC=0 || EVIL_RC=$?
[ "$EVIL_RC" = "3" ] || fail "a phase id outside [A-Za-z0-9]+ must be UNKNOWN (3), got $EVIL_RC"
[ ! -e "$TMP/PWNED" ] || fail "plan text was executed"
grep -qF 'PWNED' "$TMP/evil.out" "$TMP/evil.err" && fail "the verdict echoed unvalidated plan text"

echo "test-verification-lint: the detail goes to stderr, not stdout..."
run_lint "$GENERIC"
case "$ERR" in
    *"phase B"*) echo "  ok — stderr names the offending phase" ;;
    *) fail "stderr does not name the offending phase: $ERR" ;;
esac

echo "test-verification-lint: mode recorded in git..."
MODE="$(git -C "$REPO_ROOT" ls-files -s skills/gaspol-plan/scripts/verification-lint | cut -d' ' -f1)"
[ "$MODE" = "100755" ] || fail "verification-lint is recorded in git as '$MODE', not 100755"

echo "PASS: test-verification-lint"
