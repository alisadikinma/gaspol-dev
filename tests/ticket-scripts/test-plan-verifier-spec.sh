#!/usr/bin/env bash
# test-plan-verifier-spec.sh — plan-verifier audits the SPEC, not only the plan
#                              (IDS-18 Phases C and D)
#
# The chain is spec -> plan -> code and only the second link was guarded. This
# asserts the agent prose that closes the first, plus the Layer 2 recording that
# makes the result visible afterwards.
#
# An agent file is prose the harness executes, so text assertions ARE the test
# here — the same reason test-finish-gates.sh and test-execute-trim.sh work this
# way. Every assertion below carries a positive control or an anchored pattern,
# because "the string is absent" passes trivially when the search is broken and
# this repository has shipped that vacuous green before.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PV="$REPO_ROOT/agents/plan-verifier.md"
VERIFY="$REPO_ROOT/skills/gaspol-verify/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-plan-verifier-spec: positive control — the files are readable and non-trivial..."
for f in "$PV" "$VERIFY"; do
    [ -f "$f" ] || fail "$f does not exist"
    n=$(grep -c . "$f" || echo 0)
    [ "$n" -gt 100 ] || fail "$f has only $n non-blank lines — the search below would be vacuous"
done

# ---------------------------------------------------------------- Phase C ----
echo "test-plan-verifier-spec: the DROPPED verdict is defined..."
grep -q 'DROPPED' "$PV" \
    || fail "agents/plan-verifier.md does not define the DROPPED verdict"

echo "test-plan-verifier-spec: DROPPED means spec-present, plan-absent..."
# Not the same as MISSING. MISSING is "the plan asked, the code did not deliver";
# DROPPED is "the spec asked, the plan never carried it forward". Collapsing them
# loses the only signal that the planner, not the implementer, lost the item.
grep -qiE 'DROPPED.*(spec|specification)' "$PV" \
    || fail "DROPPED appears but is not tied to the spec — it must name the spec as the source the requirement came from"

echo "test-plan-verifier-spec: DROPPED is BLOCKING..."
grep -qE 'BLOCKING.*DROPPED|DROPPED.*BLOCKING' "$PV" \
    || fail "DROPPED is not wired into the BLOCKING rule — a requirement lost at plan time is still a requirement lost"

echo "test-plan-verifier-spec: both scripts are invoked, and ANCHORED..."
for s in spec-pointer blast-radius-diff; do
    grep -q "$s" "$PV" || fail "agents/plan-verifier.md never invokes $s"
    grep -qE "CLAUDE_PLUGIN_ROOT[^\"']*/skills/gaspol-verify/scripts/$s" "$PV" \
        || fail "$s is invoked without the \$CLAUDE_PLUGIN_ROOT anchor — an agent runs this with the TARGET PROJECT as CWD, so a relative path executes whatever that repo happens to ship"
done

echo "test-plan-verifier-spec: relative invocation is absent (line-anchored, prose allowed)..."
# Line-start anchored for the reason test-kb-no-hardcoded-path.sh is: prose
# describing the hazard wraps the same text in backticks mid-sentence, and a gate
# that trips on its own explanation gets weakened until it stops working.
REL="$(grep -nE '^[[:space:]]*[`"$(]*skills/gaspol-verify/scripts/(spec-pointer|blast-radius-diff)' "$PV" || true)"
[ -z "$REL" ] || { echo "$REL" >&2; fail "a relative invocation of a new script starts a line in plan-verifier.md"; }

echo "test-plan-verifier-spec: all three spec-pointer states have distinct documented behaviour..."
grep -qiE 'exit 3|UNKNOWN' "$PV" || fail "plan-verifier.md does not document the UNKNOWN state of spec-pointer"
grep -qiE 'exit 4|standalone' "$PV" || fail "plan-verifier.md does not document the 'no spec' state"
# The bug this guards: every KB caller once merged exit 3 into exit 4, so a
# fresh machine's first run aborted silently (test-kb-state4-continues.sh).
# Exit 3 must STOP; exit 4 must CONTINUE. Same word for both = the bug.
grep -qiE '(exit 3|UNKNOWN)[^.]*(STOP|ask)' "$PV" \
    || fail "exit 3 does not STOP-and-ask — an unresolved pointer must never be treated as 'no spec'"
grep -qiE '(exit 4|no .{0,12}Spec.{0,12} line|standalone)[^.]*(continue|proceed|not a failure)' "$PV" \
    || fail "exit 4 does not continue — a standalone plan legitimately has no spec and must not be blocked"

echo "test-plan-verifier-spec: a deliberate narrowing must be written back to the spec..."
grep -qiE 'spec' "$PV" && grep -qiE 'narrow|scope reduction|out of scope' "$PV" \
    || fail "plan-verifier.md does not state that a deliberate scope reduction belongs in the SPEC — without it, DROPPED reads as a bug rather than a contract change"

echo "test-plan-verifier-spec: blast-radius exit 1 is reported, NOT blocking..."
# Scoped to the blast-radius step rather than matched as one flat regex. A
# single-line pattern cannot see a claim that spans a sentence boundary, and
# contorting the prose to satisfy the regex would be fitting the document to the
# test instead of the other way round.
python3 - "$PV" <<'PYEOF' || fail "the blast-radius step does not state that its finding is reported rather than blocking — overstating a WARN makes it read as a gate"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^###[^\n]*Blast Radius[^\n]*\n(.*?)^###\s", text, re.S | re.M)
if not m:
    print("    no '### ... Blast Radius' step found at all", file=sys.stderr)
    sys.exit(1)
step = m.group(1).lower()
if not re.search(r"(never blocking|not blocking|non-blocking|do not block|reported, never)", step):
    print("    the step never says the finding does not block", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PYEOF

echo "test-plan-verifier-spec: the artifact cross-check has all four states..."
# Added after round 1. The re-review closed this finding but noted it shipped as
# prose with no assertion, unlike DROPPED -- which is the rule-with-no-enforcer
# shape this whole ticket exists to close. Asserting it here so a later edit
# cannot quietly drop a state.
python3 - "$PV" <<'PYEOF2' || fail "the artifact cross-check is missing a state, or its disagreement path does not STOP"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^####[^\n]*Artifact cross-check[^\n]*\n(.*?)^#{2,4}\s", text, re.S | re.M)
if not m:
    print("    no '#### ... Artifact cross-check' subsection at all", file=sys.stderr)
    sys.exit(1)
sec = m.group(1).lower()
problems = []
if "none" not in sec:                       problems.append("no 'none' state for a missing URL")
if "not run" not in sec:                    problems.append("no 'not run' state for a failed read")
if "agree" not in sec:                      problems.append("no agreement state")
# The load-bearing one: a disagreement must STOP, never silently pick a side.
if not re.search(r"disagree", sec):         problems.append("no disagreement state")
if not re.search(r"stop and ask", sec):     problems.append("the disagreement path does not STOP and ask")
if not re.search(r"never.{0,40}passed|never record it as passed", sec):
    problems.append("a failed read is not explicitly barred from counting as passed")
for x in problems:
    print("    " + x, file=sys.stderr)
sys.exit(1 if problems else 0)
PYEOF2

# ---------------------------------------------------------------- Phase D ----
echo "test-plan-verifier-spec: gaspol-verify Layer 2 records spec-fidelity..."
grep -q 'spec-fidelity:' "$VERIFY" \
    || fail "gaspol-verify Layer 2 records no spec-fidelity line"

echo "test-plan-verifier-spec: gaspol-verify Layer 2 records blast-radius..."
grep -q 'blast-radius:' "$VERIFY" \
    || fail "gaspol-verify Layer 2 records no blast-radius line"

echo "test-plan-verifier-spec: both lines appear in the Evidence Format block, not only in prose..."
# A state documented in prose but absent from the example output is a state
# nobody actually writes. The Evidence Format block is what gets copied.
python3 - "$VERIFY" <<'PYEOF' || fail "spec-fidelity: and blast-radius: are described but absent from Layer 2's Evidence Format block"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
# Layer 2 runs from its heading to the next Layer heading.
m = re.search(r"^##[^\n]*Layer 2[^\n]*\n(.*?)^##\s", text, re.S | re.M)
layer2 = m.group(1) if m else ""
blocks = re.findall(r"(?:```|~~~)[a-zA-Z]*\n(.*?)(?:```|~~~)", layer2, re.S)
joined = "\n".join(blocks)
missing = [k for k in ("spec-fidelity:", "blast-radius:") if k not in joined]
if missing:
    print("    missing from Layer 2 fenced blocks: " + ", ".join(missing), file=sys.stderr)
sys.exit(1 if missing else 0)
PYEOF

echo "test-plan-verifier-spec: a state that did not run is never recorded as passed..."
grep -qiE 'not run' "$VERIFY" \
    || fail "gaspol-verify does not carry the 'not run' vocabulary — the rule it already applies to an unavailable /security-review"

echo "test-plan-verifier-spec: the 'none' state is not a failure, for both lines..."
grep -qiE 'spec-fidelity:[^\n]*none|spec: none' "$VERIFY" \
    || fail "the standalone-plan state is not documented for spec-fidelity"
grep -qiE 'blast-radius:[^\n]*none' "$VERIFY" \
    || fail "the no-file-list state is not documented for blast-radius"

# ---------------------------------------------------------------- Phase F ----
echo "test-plan-verifier-spec: CLAUDE.md documents both new scripts..."
CL="$REPO_ROOT/CLAUDE.md"
for s in spec-pointer blast-radius-diff; do
    grep -q "$s" "$CL" || fail "CLAUDE.md does not document $s"
done

echo "test-plan-verifier-spec: CLAUDE.md names what the ticket does NOT close..."
# A deferral that is not written down is indistinguishable from completion, and
# this repository has had to undo that shape more than once.
grep -qiE 'DROPPED' "$CL" \
    || fail "CLAUDE.md never mentions the DROPPED verdict — the gate is undocumented where every session reads"

echo "test-plan-verifier-spec: the version is consistent between plugin.json and CLAUDE.md..."
PJ="$REPO_ROOT/.claude-plugin/plugin.json"
V_JSON="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$PJ" | head -1)"
V_MD="$(sed -nE 's/^\*\*Version:\*\*[[:space:]]*(.+)$/\1/p' "$CL" | head -1)"
[ -n "$V_JSON" ] || fail "no version found in .claude-plugin/plugin.json"
[ -n "$V_MD" ] || fail "no **Version:** line found in CLAUDE.md"
[ "$V_JSON" = "$V_MD" ] \
    || fail "version mismatch: plugin.json says '$V_JSON', CLAUDE.md says '$V_MD' — a reader cannot tell which is real"

echo "PASS: test-plan-verifier-spec"
