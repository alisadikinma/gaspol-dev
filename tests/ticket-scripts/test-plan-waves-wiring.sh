#!/usr/bin/env bash
# test-plan-waves-wiring.sh — gaspol-plan carries the waves-v1 contract (IDS-22 Phase C)
#
# plan-waves (skills/gaspol-plan/scripts/plan-waves) is only useful if the skill that
# writes plans (a) emits the fields it validates, (b) runs it, and (c) never schedules
# by hand. This test reads skills/gaspol-plan/SKILL.md and asserts those three things.
#
# It also guards two properties that rot silently:
#   - the model/effort/review mapping lives ONLY in plan-waves and the rubric doc, so the
#     skill must not restate it (a second copy is a second place to drift)
#   - every plan-waves invocation is anchored on ${CLAUDE_PLUGIN_ROOT:?...}, because the
#     working directory during a skill run is the target project, which may ship its own
#     script of the same name (the IDS-8 hazard; test-kb-no-hardcoded-path.sh gates the
#     assignment form, this gates the prose form too)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/gaspol-plan/SKILL.md"
REL="skills/gaspol-plan/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$SKILL" ] || fail "$REL is missing"

# has <fixed string> <label>
has() {
    grep -qF -- "$1" "$SKILL" || fail "$REL does not mention $1 ($2)"
    echo "  ok — $2"
}

# lacks <fixed string> <label>
lacks() {
    if grep -qF -- "$1" "$SKILL"; then fail "$REL must not contain: $1 ($2)"; fi
    echo "  ok — $2"
}

# line_of <fixed string> — first line number, or empty
line_of() { grep -nF -- "$1" "$SKILL" | head -n 1 | cut -d: -f1 || true; }

echo "test-plan-waves-wiring: the fields"
has '**Complexity:**' "Complexity line is in the skill"
has '**Deps:**' "Deps line is in the skill"
has '**Format:** waves-v1' "Format header is in the skill"

# Template placement: Format after Spec/Artifact in the plan header; Deps and Complexity
# between a phase heading and its Files block.
L_SPEC="$(line_of '**Spec:** docs/plans/')"
L_ART="$(line_of '**Artifact:** https://')"
L_FMT="$(line_of '**Format:** waves-v1')"
[ -n "$L_SPEC" ] && [ -n "$L_ART" ] && [ -n "$L_FMT" ] || fail "header template lines not found"
[ "$L_FMT" -gt "$L_SPEC" ] && [ "$L_FMT" -gt "$L_ART" ] \
    || fail "$REL: **Format:** waves-v1 must come after the **Spec:** and **Artifact:** lines in the header template"
echo "  ok — Format sits after Spec and Artifact"

PHASE_TEMPLATE_START="$(line_of '### Phase A: [Phase Name]')"
[ -n "$PHASE_TEMPLATE_START" ] || fail "phase template heading not found"
TEMPLATE="$(sed -n "${PHASE_TEMPLATE_START},\$p" "$SKILL" | sed -n '1,/^\*\*Steps:\*\*/p')"
for need in '**Deps:**' '**Complexity:**' '**Files:**'; do
    printf '%s\n' "$TEMPLATE" | grep -qF -- "$need" || fail "$REL: phase template lacks $need before **Steps:**"
done
D="$(printf '%s\n' "$TEMPLATE" | grep -nF '**Deps:**' | head -n 1 | cut -d: -f1)"
C="$(printf '%s\n' "$TEMPLATE" | grep -nF '**Complexity:**' | head -n 1 | cut -d: -f1)"
F="$(printf '%s\n' "$TEMPLATE" | grep -nF '**Files:**' | head -n 1 | cut -d: -f1)"
[ "$D" -lt "$C" ] && [ "$C" -lt "$F" ] || fail "$REL: phase template order must be Deps, Complexity, Files"
echo "  ok — phase template order is Deps, Complexity, Files"

has 'a bare label with no reason is refused' "bare-label rule"
has 'light = one file, no design decision' "rubric: light"
has 'medium = several files, pattern already in the repo' "rubric: medium"
has 'complex = new logic; money, auth or security; many interlinked files; an interface other phases consume' "rubric: complex"

echo "test-plan-waves-wiring: the self-check"
has '`**Deps:**`' "self-check names Deps"
has 'must equal the number of `### Phase` headings' "self-check equality rule survives"
grep -nF 'Deps:' "$SKILL" | grep -qF 'Complexity:' \
    || grep -qE 'Deps:.*Complexity:|Complexity:.*Deps:' "$SKILL" \
    || fail "$REL: the self-check must count Deps: and Complexity: lines together"

echo "test-plan-waves-wiring: the Execution Waves section"
has '## Execution Waves (MANDATORY)' "section heading"
INVOKE='"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves"'
has "$INVOKE" "anchored invocation"
has '## Execution Waves' "plan section name"
has '## Waves' "ledger section name"
has 'never hand-schedule' "no hand scheduling"
has 'exit 3' "exit 3 handled"
has 'STOP and ask' "exit 3 stops"

# Every line that names the script path must carry the anchor.
UNANCHORED="$(grep -nF 'scripts/plan-waves' "$SKILL" | grep -vF 'CLAUDE_PLUGIN_ROOT' || true)"
[ -z "$UNANCHORED" ] || { echo "$UNANCHORED" >&2; fail "$REL: a plan-waves path appears without \${CLAUDE_PLUGIN_ROOT:?...}"; }
echo "  ok — every plan-waves path is anchored"

N="$(grep -o 'plan-waves' "$SKILL" | wc -l | tr -d ' ')"
[ "${N:-0}" -ge 3 ] || fail "$REL mentions plan-waves only ${N:-0} time(s), expected at least 3"
echo "  ok — plan-waves mentioned $N times"

echo "test-plan-waves-wiring: the parallel offer"
has 'only when `plan-waves` printed a wave with two or more lanes' "new offer condition"
lacks 'only when the plan has independent phases' "old offer condition is gone"

echo "test-plan-waves-wiring: the mapping lives elsewhere"
has 'the orchestrator reads the `phase' "skill defers to the phase lines"
lacks '| light |' "no mapping table row for light"
lacks '| complex |' "no mapping table row for complex"
lacks 'effort=' "no restated effort values"
lacks 'model=sonnet' "no restated model values"

echo "test-plan-waves-wiring: all cases passed"
