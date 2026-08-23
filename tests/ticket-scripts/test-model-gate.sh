#!/usr/bin/env bash
# test-model-gate.sh — the four exit states of skills/gaspol-verify/scripts/model-gate
#                      (IDS-20)
#
# The rubric at docs/rubric-model-switching.md has been advice nobody enforced.
# It drifted from what the owner wants in TEN places, six of which the first
# survey missed: four reviewer prompt files under gaspol-review,
# code-quality-reviewer-prompt.md, and a sentence in implementer-prompt.md
# instructing a `haiku` override for a tier the rule deletes.
#
# The rule is two tiers: Opus judges, Sonnet works.
#
# Each case builds a throwaway git repo under mktemp -d. Nothing here touches the
# real repository. Case 16 runs the gate from a subdirectory, because the tree it
# scans must resolve against the repo root and never $PWD — the IDS-8 hazard.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/skills/gaspol-verify/scripts/model-gate"

fail() { echo "FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

CASE_N=0
REPO=""

new_repo() {
    CASE_N=$((CASE_N + 1))
    REPO="$WORK/case-$CASE_N"
    mkdir -p "$REPO/agents" "$REPO/skills/thing"
    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.email "t@example.invalid"
    git -C "$REPO" config user.name "t"
}

# agent <filename> <model value>
agent() {
    printf -- '---\nname: %s\ndescription: x\nmodel: %s\n---\n\nbody\n' \
        "${1%.md}" "$2" > "$REPO/agents/$1"
}

run_gate() {
    set +e
    OUT="$(cd "${1:-$REPO}" && "$GATE" 2>/dev/null)"
    RC=$?
    set -e
}

# expect <want_rc> <label> [substring]
expect() {
    local want="$1" label="$2" needle="${3:-}"
    [ "$RC" = "$want" ] || fail "$label: expected exit $want, got $RC (stdout: $OUT)"
    case "$OUT" in
        "model-gate: "*) : ;;
        *) fail "$label: stdout must start with 'model-gate: ', got: $OUT" ;;
    esac
    if [ -n "$needle" ]; then
        case "$OUT" in
            *"$needle"*) : ;;
            *) fail "$label: expected stdout to contain '$needle', got: $OUT" ;;
        esac
    fi
    echo "  ok — $label (exit $want)"
}

echo "test-model-gate: 18 cases"

# 1 — a judging agent on opus.
new_repo
agent "code-reviewer.md" "opus"
run_gate
expect 0 "case 1: reviewer on opus"

# 2 — a judging agent on sonnet. This is the live defect in agents/code-reviewer.md.
new_repo
agent "code-reviewer.md" "sonnet"
run_gate
expect 1 "case 2: reviewer on sonnet BLOCKS" "code-reviewer.md"

# 3 — every judging suffix is recognised, not just "reviewer".
new_repo
agent "plan-verifier.md" "sonnet"
run_gate
expect 1 "case 3: verifier on sonnet BLOCKS"

new_repo
agent "code-simplifier.md" "sonnet"
run_gate
expect 1 "case 4: simplifier on sonnet BLOCKS"

# 5 — an execution surface must be sonnet, not opus.
new_repo
printf 'x\n\nmodel: "opus"\n' > "$REPO/skills/thing/implementer-prompt.md"
run_gate
expect 1 "case 5: implementer on opus BLOCKS"

# 6 — the same file on sonnet is correct.
new_repo
printf 'x\n\nmodel: "sonnet"\n' > "$REPO/skills/thing/implementer-prompt.md"
run_gate
expect 0 "case 6: implementer on sonnet"

# 7 — haiku is a DELETED tier, so it BLOCKS rather than reporting UNKNOWN.
#     Reporting it as unknown invites a case-by-case exemption, which is how a
#     deleted tier comes back one row at a time.
new_repo
agent "code-reviewer.md" "opus"
printf 'x\n\nmodel: haiku\n' > "$REPO/skills/thing/sync-prompt.md"
run_gate
expect 1 "case 7: model: haiku BLOCKS" "haiku"

# 8 — haiku in PROSE also blocks. This is the live defect at
#     implementer-prompt.md:10, "Override to `haiku` when: ...". An instruction to
#     use a deleted tier IS the tier still being available.
new_repo
agent "code-reviewer.md" "opus"
printf 'Override to `haiku` when: mechanical rename/format changes.\n' \
    > "$REPO/skills/thing/notes.md"
run_gate
expect 1 "case 8: haiku in prose BLOCKS" "haiku"

# 9 — an unrecognised value is REPORTED, never blocked. model: selectedModel in
#     gaspol-debug is illustrative code in another language, and a gate that
#     fires on documentation is one somebody switches off.
new_repo
agent "code-reviewer.md" "opus"
printf 'const cfg = {\n  model: selectedModel,\n}\n' > "$REPO/skills/thing/example.md"
run_gate
expect 0 "case 9: unrecognised value is reported, not blocked" "unrecognised"

# 10 — tier from the SAME LINE when the path carries no tier pattern. This is
#      gaspol-parallel/SKILL.md:318's shape.
new_repo
printf 'Dispatch with subagent_type: "gaspol-dev:code-reviewer", model: "sonnet" today.\n' \
    > "$REPO/skills/thing/SKILL.md"
run_gate
expect 1 "case 10: tier from the same line catches a prose-adjacent dispatch"

# 11 — the same shape, correct tier.
new_repo
printf 'Dispatch with subagent_type: "gaspol-dev:spec-reviewer", model: "opus" today.\n' \
    > "$REPO/skills/thing/SKILL.md"
run_gate
expect 0 "case 11: same line, correct tier"

# 12 — neither path nor line yields a tier.
new_repo
printf 'model: "opus"\n' > "$REPO/skills/thing/SKILL.md"
run_gate
expect 3 "case 12: undeterminable tier is UNKNOWN"

# 13 — an agent with no model: field at all. Inheriting silently from the parent
#      is precisely what the rule forbids.
new_repo
printf -- '---\nname: code-reviewer\ndescription: x\n---\n\nbody\n' \
    > "$REPO/agents/code-reviewer.md"
run_gate
expect 3 "case 13: agent with no model: field is UNKNOWN"

# 14 — nothing declares a model anywhere.
new_repo
printf 'just prose\n' > "$REPO/skills/thing/SKILL.md"
run_gate
expect 4 "case 14: no model reference anywhere" "no model"

# 15 — case-insensitive key, value compared lowercased.
new_repo
agent "code-reviewer.md" "OPUS"
run_gate
expect 0 "case 15: value compared case-insensitively"

# 16 — run from a subdirectory: the tree resolves against the repo root.
new_repo
agent "code-reviewer.md" "sonnet"
mkdir -p "$REPO/sub/dir"
run_gate "$REPO/sub/dir"
expect 1 "case 16: run from a subdirectory, resolves against the repo root"

# 17 — a file the heuristics cannot classify declares its own tier. Added after
#      the first real run reported UNKNOWN for gaspol-learn and gaspol-research,
#      both correct and both merely unlabelled. Growing the keyword list would
#      drift; defaulting the unmatched case to exec would silently demand sonnet
#      of a judging surface nobody named carefully.
new_repo
printf '<!-- model-tier: exec — gathering is execution -->\n\nDispatch (model: sonnet) to gather.\n' \
    > "$REPO/skills/thing/SKILL.md"
run_gate
expect 0 "case 17: a file may declare its own tier"

# 18 — the declared tier is enforced, not merely accepted.
new_repo
printf '<!-- model-tier: judge -->\n\nDispatch (model: sonnet) to grade.\n' \
    > "$REPO/skills/thing/SKILL.md"
run_gate
expect 1 "case 18: a declared judging tier still BLOCKS a sonnet declaration"

echo "test-model-gate: running the script's own --self-test..."
"$GATE" --self-test >/dev/null || fail "model-gate --self-test failed"
echo "  ok — --self-test"

# The gate must be clean against THIS repository. Kept as a live assertion
# rather than a fixture: a gate green only on synthetic trees proves nothing
# about the repo it ships in, which is the vacuous-green shape IDS-19 found in
# test-kb-no-hardcoded-path.sh's own positive control.
echo "test-model-gate: the gate is clean against this repository..."
set +e
REAL_OUT="$(cd "$REPO_ROOT" && "$GATE" 2>&1 | head -3)"
REAL_RC=$?
set -e
[ "$REAL_RC" = 0 ] || fail "model-gate is not clean against this repo (exit $REAL_RC): $REAL_OUT"
echo "  ok — $REAL_OUT"

echo "test-model-gate: PASS (18 cases)"
