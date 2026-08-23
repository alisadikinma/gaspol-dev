#!/usr/bin/env bash
# test-spec-pointer-branches-run.sh — EXECUTE the bash in plan-verifier.md Step 1b,
#                                     do not merely read it (IDS-18, review round)
#
# Every other test on this branch asserts what the prose SAYS. This one runs it.
# The distinction is not academic: Tier 1 review found that the documented
# invocation was
#
#     SPEC="$(spec-pointer "$PLAN_FILE")"
#     case $? in 0) … 3) … 4) … esac
#
# and under `set -e` — the convention every script in this repo uses — the exit
# status of a plain assignment IS the command's status, so a non-zero exit aborts
# the block AT the assignment. The `case` never runs. Exit 3 (STOP and ask) and
# exit 4 (continue) both silently truncated the block instead of doing either,
# and exit 4 is the COMMON case: every plan with no preceding brainstorm.
#
# Six text assertions in test-plan-verifier-spec.sh all passed against that
# broken snippet, because each one asked whether a sentence was present. This is
# the same lesson test-kb-state4-continues.sh was written for, one ticket later:
# a text assertion cannot catch a control-flow bug.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PV="$REPO_ROOT/agents/plan-verifier.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "test-spec-pointer-branches-run: extracting the Step 1b bash block..."
# The block is the first fenced ```bash in the Step 1b section that invokes
# spec-pointer. Extracted rather than duplicated: a copy of the snippet in this
# test would keep passing after the real one drifted, which is the failure this
# whole file exists to prevent.
python3 - "$PV" "$TMP/block.sh" <<'PYEOF' || fail "could not extract a spec-pointer bash block from agents/plan-verifier.md"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = [b for b in re.findall(r"```bash\n(.*?)```", text, re.S) if "spec-pointer" in b]
if not blocks:
    print("    no ```bash block invoking spec-pointer", file=sys.stderr)
    sys.exit(1)
pathlib.Path(sys.argv[2]).write_text(blocks[0], encoding="utf-8")
sys.exit(0)
PYEOF
[ -s "$TMP/block.sh" ] || fail "the extracted block is empty"

# A stub standing in for the real resolver, so each exit code can be forced.
# $STUB_RC decides what it returns; it echoes a path first, exactly as the real
# script does on exit 0.
mkdir -p "$TMP/skills/gaspol-verify/scripts"
cat > "$TMP/skills/gaspol-verify/scripts/spec-pointer" <<'STUB'
#!/usr/bin/env bash
echo "/resolved/spec.md"
exit "${STUB_RC:?STUB_RC unset}"
STUB
chmod +x "$TMP/skills/gaspol-verify/scripts/spec-pointer"

# Run the extracted block under THIS REPO'S convention — set -euo pipefail —
# with each branch marked so we can see which one was actually taken.
run_block() {
    local rc_want="$1"
    {
        echo 'set -euo pipefail'
        echo 'PLAN_FILE=/does/not/matter'
        # mark each branch; the block's own `case` bodies are `:` placeholders
        sed -E 's|^( *)0\) : ;;|\10) echo BRANCH_0 ;;|; s|^( *)3\) : ;;|\13) echo BRANCH_3 ;;|; s|^( *)4\) : ;;|\14) echo BRANCH_4 ;;|' "$TMP/block.sh"
        echo 'echo BLOCK_COMPLETED'
    } > "$TMP/run.sh"
    STUB_RC="$rc_want" CLAUDE_PLUGIN_ROOT="$TMP" bash "$TMP/run.sh" 2>/dev/null || true
}

for rc in 0 3 4; do
    echo "test-spec-pointer-branches-run: exit $rc reaches its branch AND finishes the block..."
    out="$(run_block "$rc")"
    case "$out" in
        *"BRANCH_$rc"*) ;;
        *) fail "exit $rc did not reach its case branch — the block aborted early. Output: [$out]" ;;
    esac
    case "$out" in
        *BLOCK_COMPLETED*) ;;
        *) fail "exit $rc reached its branch but the block did not run to completion — everything after the case is dead. Output: [$out]" ;;
    esac
done

echo "test-spec-pointer-branches-run: the three branches are DISTINGUISHABLE..."
# Guards the collapse this repository has already shipped once: exit 3 must not
# take exit 4's path. If the marking above ever produced the same branch for two
# different codes, the loop would still pass, so compare them.
o0="$(run_block 0)"; o3="$(run_block 3)"; o4="$(run_block 4)"
[ "$o3" != "$o4" ] || fail "exit 3 and exit 4 produce identical behaviour — the STOP-and-ask state collapsed into the continue state"
[ "$o0" != "$o3" ] || fail "exit 0 and exit 3 produce identical behaviour"

echo "test-spec-pointer-branches-run: positive control — the harness can see a break..."
# The historical BROKEN form, written literally rather than reconstructed from the
# fixed one by regex. Its job is to prove THIS HARNESS can detect the bug shape --
# not to track the real file, which the extraction above already does. Regex
# surgery on the live snippet was tried first and was too brittle to trust as a
# control, and a control you cannot trust is worse than none.
cat > "$TMP/broken.sh" <<'BROKEN'
SPEC="$("${CLAUDE_PLUGIN_ROOT:?unset}/skills/gaspol-verify/scripts/spec-pointer" "$PLAN_FILE")"
case $? in
  0) : ;;
  3) : ;;
  4) : ;;
esac
BROKEN
{
    echo 'set -euo pipefail'
    echo 'PLAN_FILE=/x'
    sed -E 's|^( *)4\) : ;;|\14) echo BRANCH_4 ;;|' "$TMP/broken.sh"
    echo 'echo BLOCK_COMPLETED'
} > "$TMP/runbroken.sh"
bout="$(STUB_RC=4 CLAUDE_PLUGIN_ROOT="$TMP" bash "$TMP/runbroken.sh" 2>/dev/null || true)"
case "$bout" in
    *BLOCK_COMPLETED*)
        fail "the positive control did NOT fail on the known-broken bare-assignment form — this harness cannot detect the bug it was written for, so its green above proves nothing" ;;
    *BRANCH_4*)
        fail "the broken form reached branch 4 — the control is not exercising the set -e abort" ;;
    *) ;;
esac

echo "PASS: test-spec-pointer-branches-run"
