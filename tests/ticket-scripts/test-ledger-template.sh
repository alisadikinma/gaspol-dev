#!/usr/bin/env bash
# test-ledger-template.sh — the ledger template gaspol-plan writes (IDS-19 Phase C)
#
# The template used to be one `## Checklist` LINE per phase. IND-117's ledger,
# written by hand in a consumer project, was one checkbox per STEP plus narrative
# sections recording the baseline, the mid-run decisions, the real commit SHAs and
# the debt deliberately left open. That shape is now the standard, and its content
# is COPIED from the plan's own `**Steps:**` and `**Verification:**` blocks rather
# than authored fresh — the Verification block is already `- [ ]` checkboxes.
#
# These are text assertions over a skill file. They cannot catch a control-flow
# bug (that is what test-kb-state4-continues.sh and
# test-spec-pointer-branches-run.sh exist for), and they are not claimed to: what
# they catch is a mandatory section quietly disappearing from the contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAN_SKILL="$REPO_ROOT/skills/gaspol-plan/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$PLAN_SKILL" ] || fail "skills/gaspol-plan/SKILL.md not found"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "test-ledger-template: extracting the ledger template block..."
# Extracted, never duplicated. A copy of the template inside this test would keep
# passing after the real one drifted — the exact failure this file exists to
# prevent, and the reason test-spec-pointer-branches-run.sh extracts too.
python3 - "$PLAN_SKILL" "$TMP/template.md" <<'PYEOF' || fail "could not extract the ledger template from skills/gaspol-plan/SKILL.md"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = [b for b in re.findall(r"```markdown\n(.*?)```", text, re.S)
          if "# PROGRESS" in b and "## Checklist" in b]
if not blocks:
    print("    no ```markdown block containing '# PROGRESS' and '## Checklist'", file=sys.stderr)
    sys.exit(1)
if len(blocks) > 1:
    print(f"    {len(blocks)} candidate template blocks — which one is the contract?", file=sys.stderr)
    sys.exit(1)
pathlib.Path(sys.argv[2]).write_text(blocks[0], encoding="utf-8")
PYEOF
[ -s "$TMP/template.md" ] || fail "the extracted template is empty"
TEMPLATE="$TMP/template.md"

# 1 — the four mandatory sections are present.
echo "test-ledger-template: 1. four mandatory sections..."
for section in "## Pre-flight" "## Keputusan saat jalan" "## Phase log" "## Utang terbuka"; do
    grep -qF "$section" "$TEMPLATE" || fail "missing mandatory section: $section"
    echo "  ok — $section"
done

# 2 — ## Log comes after all four. scan-active-ledgers reads the file's last
#     non-empty line; a mandatory section below ## Log would break it, and a
#     template that ships that mistake teaches every ledger to repeat it.
echo "test-ledger-template: 2. ## Log is last..."
LOG_LINE="$(grep -n '^## Log' "$TEMPLATE" | tail -1 | cut -d: -f1)"
[ -n "$LOG_LINE" ] || fail "the template has no '## Log' heading"
LAST_HEADING="$(grep -n '^## ' "$TEMPLATE" | tail -1 | cut -d: -f1)"
[ "$LAST_HEADING" = "$LOG_LINE" ] \
    || fail "a '## ' block appears after '## Log' in the template — scan-active-ledgers reads the last non-empty line and would report every ticket's state wrongly"
echo "  ok — '## Log' is the last '## ' block"

# 3 — all four state markers still documented.
echo "test-ledger-template: 3. four state markers..."
for marker in '`\[ \]`' '`\[>\]`' '`\[x\]`' '`\[~\]`'; do
    grep -qE "$marker" "$PLAN_SKILL" || fail "state marker $marker is no longer documented"
done
echo "  ok — [ ] [>] [x] [~]"

# 4 — the cancelled state still demands a reason. This is the rule the knowledge
#     note `ledger-states-require-non-empty-reasons` exists for: a bare label with
#     nothing after it is "(if possible)" wearing a new name.
echo "test-ledger-template: 4. [~] still requires a reason..."
grep -nE '\[~\]' "$PLAN_SKILL" | grep -qiE 'mandatory|wajib' \
    || fail "the [~] state no longer says a reason is MANDATORY"
echo "  ok — [~] requires a reason"

# 5 — the structural rule survives in prose, not only by example.
echo "test-ledger-template: 5. the '## Log is always last' rule..."
grep -qiE '`## Log` is ALWAYS the last block' "$PLAN_SKILL" \
    || fail "the '## Log is ALWAYS the last block' rule is gone from the prose"
echo "  ok — the rule is stated, not merely demonstrated"

# 6 — step 7 no longer promises one line per phase.
echo "test-ledger-template: 6. step 7 no longer says one line per phase..."
if grep -qF 'a `## Checklist` line for EVERY phase' "$PLAN_SKILL"; then
    fail "step 7 still says 'a \`## Checklist\` line for EVERY phase' — the checklist is now a sub-block per phase"
fi
echo "  ok — the one-line-per-phase promise is gone"

# 7 — step 7 names the copy source. This is what makes the richer ledger free:
#     the plan already carries both blocks, so nothing is authored twice.
echo "test-ledger-template: 7. step 7 names the copy source..."
STEP7="$(python3 - "$PLAN_SKILL" <<'PYEOF'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"\n7\. \*\*Create the ledger file now.*?(?=\n\nEvery plan document)", text, re.S)
print(m.group(0) if m else "")
PYEOF
)"
[ -n "$STEP7" ] || fail "could not locate step 7 in skills/gaspol-plan/SKILL.md"
case "$STEP7" in
    *'**Steps:**'*) : ;;
    *) fail "step 7 does not name '**Steps:**' as a copy source" ;;
esac
case "$STEP7" in
    *'**Verification:**'*) : ;;
    *) fail "step 7 does not name '**Verification:**' as a copy source" ;;
esac
echo "  ok — step 7 names both **Steps:** and **Verification:**"

# 8 — the template demonstrates the per-phase sub-heading.
echo "test-ledger-template: 8. per-phase sub-block..."
grep -qE '^### \[[ x>~]\] Phase ' "$TEMPLATE" \
    || fail "the template shows no '### [ ] Phase <N>: <name>' sub-heading"
echo "  ok — the template shows a per-phase sub-block"

# 9 — IDS-23: the example Phase A checklist holds phase-specific lines only. The
#     generic commands are written once in the plan header's `**Verification
#     commands:**` block and recorded once in `## Pre-flight`; copying them into
#     every phase's checklist is what buried the phase-specific checks.
echo "test-ledger-template: 9. the template copies no generic verification lines..."
for generic in 'npx tsc --noEmit passes' 'npm test passes' 'No placeholder/TODO comments in new code'; do
    # backticks stripped: the template writes `npx tsc --noEmit` passes
    if tr -d '`' < "$TEMPLATE" | grep -qF "$generic"; then
        fail "ledger template still copies generic verification lines (found: $generic)"
    fi
done
echo "  ok — no generic line in the example checklist"

# 10 — the commands are recorded exactly once, in the Pre-flight table.
echo "test-ledger-template: 10. detect-stack row stays in ## Pre-flight..."
PREFLIGHT="$(awk '/^## Pre-flight/ {on=1; next} /^## / {on=0} on' "$TEMPLATE")"
case "$PREFLIGHT" in
    *'| detect-stack |'*) : ;;
    *) fail "the ## Pre-flight table lost its detect-stack row — that is where the commands are recorded once" ;;
esac
echo "  ok — the detect-stack row is in ## Pre-flight"

# Positive control: the extractor must actually be reading a real template, or
# every assertion above is vacuous against an empty file.
echo "test-ledger-template: positive control — the extractor read something real..."
LINES="$(wc -l < "$TEMPLATE" | tr -d ' ')"
[ "$LINES" -ge 15 ] \
    || fail "the extracted template is only $LINES lines — the extractor is broken, so a clean result proves nothing"
echo "  ok — extracted $LINES lines"

echo "test-ledger-template: PASS (10 assertions)"
