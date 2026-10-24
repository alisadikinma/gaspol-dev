#!/usr/bin/env bash
# test-skill-trim-plan.sh — gaspol-plan must stay under the compaction cut (IDS-23 Phase D).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The target ceiling was 18,000 bytes. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-plan/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-plan"
# LIMIT is 20000, not the 18000 the plan asked for. Past the ledger template and the execution
# handoff, what remains in the body is the plan header template (about 4.3 KB), the phase template,
# the plan-waves and verification-lint exit tables (about 1.3 KB) and one sentence per gate. Getting
# from about 19.9 KB to under 18 KB means moving a gate out of the body (the completeness rungs, the
# Deps and Complexity rules, an exit table column), which is what this test exists to refuse. 20000
# is the compaction cut itself, in characters, and the file is measured in bytes (every multi-byte
# character counts more), so staying under it in bytes stays under it in characters.
LIMIT=20000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# has FILE STRING — fixed-string match, no regex surprises.
has() { grep -qF -- "$2" "$1"; }

# Format: 'gate name|fixed string'. The string is matched with grep -qF and must be at least 25
# characters. It is a sentence from the body that states the gate's condition AND consequence,
# not a heading — a heading survives a trim that gutted the gate underneath it.
GATES=(
  'completeness-not-applicable|A rung that genuinely does not apply is written down as **not applicable, with the reason**'
  'completeness-register-same-phase|also registers it, in the same phase.'
  'completeness-fidelity|and no phase turns a real data source into a placeholder'
  'claude-md-first-must|Before writing a single line of the plan, you MUST:'
  'ticket-glob|Glob `docs/plans/*-<TICKET>-*-spec.md`.'
  'ticket-more-than-one-stop|**More than one match → STOP and ask the user which spec this plan continues. Never pick'
  'ticket-exit-2-ask|**Exit 2** — no `## gaspol Ticket Counter` section'
  'ticket-no-default-guess|(no default guess — never invent'
  'header-mandatory|Every plan document MUST start with this header:'
  'header-never-substitute|NEVER substitute placeholders for real data sources without explicit'
  'header-per-phase-gate|**Progress ledger — HARD PER-PHASE GATE:**'
  'header-blocking|This is **blocking**, like a test gate: no next phase until both are written.'
  'header-format-waves-v1|**Format:** waves-v1 <!-- always present in a new plan'
  'header-verification-commands|**Verification commands:**'
  'ledger-at-plan-write|**Create the ledger file now, at plan-write time** — do not defer this to the executor.'
  'ledger-no-verification-stop|block means the plan is incomplete: **STOP and ask**, never invent one to fill the gap.'
  'detect-stack-unknown-resolve|for that level and resolve it with AskUserQuestion before the plan is presented as final.'
  'detect-stack-nothing|`detect-stack` prints nothing → write'
  'ledger-copy-not-summarise|**Copy, do not summarise.** Both blocks already exist in the plan you just wrote, and'
  'ledger-four-sections|**Four mandatory sections, all ABOVE `## Log`:**'
  'ledger-log-last|**Structural rule — `## Log` is ALWAYS the last block in the file.**'
  'ledger-never-append|never append a section after `## Log`.'
  'ledger-reason-mandatory|a short reason is MANDATORY on the line + detail in the Log'
  'dim-mandatory|## Data Integration Map (MANDATORY in Every Plan)'
  'dim-stops|**If not possible:** Executor STOPS and asks the user. Never silently stub it out.'
  'dim-incomplete|A plan without a Data Integration Map is **INCOMPLETE**. Do not proceed to phases without it.'
  'deps-complexity-mandatory|**Deps and Complexity (MANDATORY, `waves-v1`):**'
  'bare-label-refused|Rule: a bare label with no reason is refused. `plan-waves` exits 1 on it'
  'tdd-step-1-gate|**TDD Step 1 Hard Gate (MANDATORY):** Every phase MUST have step 1 in this exact format:'
  'tdd-refused|phase without proper TDD step 1 will be refused at execution time (Step 2 hard gate)'
  'tdd-self-check-regex|`^1\. Write failing test for .+ Expected error: `'
  'tdd-self-check-count|must equal the number of `### Phase` headings'
  'security-line|phase'"'"'s Verification block MUST include a security line'
  'verification-must-end|Every phase MUST end with a Verification block'
  'verification-incomplete|is **INCOMPLETE**: the executor will'
  'waves-never-hand-schedule|compute the schedule, and never hand-schedule it'
  'waves-anchored-call|"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/plan-waves" <plan-file>'
  'waves-exit-0|| 0 | `plan-waves: OK — <n> phase(s), <m> wave(s)` |'
  'waves-exit-1-blocking|| 1 | `plan-waves: BLOCKING — <problem>` | fix the plan'
  'waves-exit-3-stop|| 3 | `plan-waves: UNKNOWN — <why>` | **STOP and ask.**'
  'waves-exit-4-never-pass|the `**Format:** waves-v1` line is missing from a new plan: add it and re-run. Exit 4 is never a pass'
  'lint-anchored-call|"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/skills/gaspol-plan/scripts/verification-lint" <plan-file>'
  'lint-exit-0|| 0 | `verification-lint: OK — <n> phase(s)` |'
  'lint-exit-1-blocking|| 1 | `verification-lint: BLOCKING — phase <id> has no phase-specific verification` | fix the plan'
  'lint-exit-3-stop|| 3 | `verification-lint: UNKNOWN — <why>` | **STOP and ask.**'
  'lint-exit-4-never-pass|header block is missing from a new plan: add it and re-run. Exit 4 is never a pass'
  'offer-one-question|present exactly one `AskUserQuestion` carrying'
  'offer-parallel-condition|only when `plan-waves` printed a wave with two or more lanes'
  'offer-skipped-line|design-artifact: skipped — <reason>'
  'offer-empty-reason-refused|An empty reason is refused: ask again.'
  'offer-save-later-no-line|`[Simpan buat sesi lain]` writes **NO line at all**.'
  'red-flags-check|Before presenting the plan, verify none of these red flags are present:'
  'red-flags-pointer|Read `references/plan-details.md` when you run this self-check: it holds the table.'
  'ledger-pointer|use exactly the template in `references/ledger-format.md`. Read it when you write the ledger in step 7'
  'handoff-pointer|Read `references/execution-handoff.md` when you present this offer'
  'verification-bullets-pointer|What counts as specific, and what does not, is in `references/plan-details.md`; read it when you write'
)

echo "test-skill-trim-plan: positive control (has must reject a string the file lacks)..."
if has "$SKILL" "zzz-this-string-is-not-in-any-skill-zzz"; then
  fail "positive control: has() matched a string that cannot exist"
fi

echo "test-skill-trim-plan: size ceiling..."
[ -f "$SKILL" ] || { echo "FAIL: $SKILL_REL missing" >&2; exit 1; }
BYTES=$(wc -c < "$SKILL" | tr -d ' ')
if [ "$BYTES" -lt "$LIMIT" ]; then
  pass "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
else
  fail "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
fi

echo "test-skill-trim-plan: every gate survives in the body..."
for entry in "${GATES[@]}"; do
  name="${entry%%|*}"
  needle="${entry#*|}"
  if [ "${#needle}" -lt 25 ]; then
    fail "gate '$name': fixed string is under 25 characters (${#needle}) — too weak to prove the gate"
  elif has "$SKILL" "$needle"; then
    pass "gate '$name' present in SKILL.md body"
  else
    fail "gate '$name' missing from SKILL.md body: $needle"
  fi
done

echo "test-skill-trim-plan: the header template, the plan-waves call and the verification-lint call are in the body..."
python3 - "$SKILL" <<'PYEOF' || fail "the body lost the header template, the Verification commands block, or one of the two gate script calls"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = re.findall(r"```markdown\n(.*?)```", text, re.S)
hdr = [b for b in blocks if "**Format:** waves-v1" in b and "**Verification commands:**" in b and "**Ticket:**" in b]
bad = []
if len(hdr) != 1:
    bad.append("expected exactly one header template block with Ticket, Format and Verification commands, saw %d" % len(hdr))
bash = re.findall(r"```bash\n(.*?)```", text, re.S)
for script in ("plan-waves", "verification-lint"):
    if not any("/skills/gaspol-plan/scripts/%s" % script in b for b in bash):
        bad.append("no bash block runs %s" % script)
for m in bad:
    print("    " + m, file=sys.stderr)
sys.exit(1 if bad else 0)
PYEOF

echo "test-skill-trim-plan: every references/ file named in the body exists..."
REFS=$(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$SKILL" | sort -u || true)
if [ -z "$REFS" ]; then
  fail "SKILL.md names no references/ file — the moved detail has no pointer"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    pass "skills/gaspol-plan/$ref exists"
  else
    fail "SKILL.md names skills/gaspol-plan/$ref but the file does not exist"
  fi
done

echo "test-skill-trim-plan: the two moved sections have their reference files..."
for ref in references/ledger-format.md references/execution-handoff.md; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    pass "skills/gaspol-plan/$ref exists"
  else
    fail "skills/gaspol-plan/$ref does not exist"
  fi
  if ! grep -qF -- "$ref" "$SKILL" 2>/dev/null; then
    fail "SKILL.md never points at $ref"
  fi
done

echo "test-skill-trim-plan: the moved text is really in the references..."
for pair in 'references/ledger-format.md|## Pre-flight' 'references/ledger-format.md|## Keputusan saat jalan' 'references/execution-handoff.md|design-artifact: approved' 'references/execution-handoff.md|design-artifact: pending' 'references/plan-details.md|2026-04-17-gaspol-improvements.md' 'references/plan-details.md|| No Data Integration Map |'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-plan: relative links in SKILL.md and references/ resolve..."
LINKS=0
for f in "$SKILL" "$SKILL_DIR"/references/*.md; do
  [ -f "$f" ] || continue
  dir="$(dirname "$f")"
  for target in $(grep -oE '\]\([^)#]+\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    LINKS=$((LINKS + 1))
    if [ -f "$dir/$target" ]; then
      pass "$(basename "$f") link $target resolves"
    else
      fail "$(basename "$f") links to $target which does not resolve from $dir"
    fi
  done
done

echo "test-skill-trim-plan: each gate script runs in its own guarded block (exit codes stay visible)..."
python3 - "$SKILL" <<'PYEOF' || fail "a bash block runs more than one anchored gate script, or runs one without the CLAUDE_PLUGIN_ROOT guard"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = re.findall(r"```bash\n(.*?)```", text, re.S)
calls = 0
bad = []
for b in blocks:
    n = len(re.findall(r'^"\$\{?CLAUDE_PLUGIN_ROOT[:?}]', b, re.M))
    if n == 0:
        continue
    calls += n
    if n > 1:
        bad.append("block runs %d scripts: %s" % (n, b.strip().splitlines()[0]))
    if "CLAUDE_PLUGIN_ROOT:?" not in b:
        bad.append("block has no guard: " + b.strip().splitlines()[0])
if calls < 2:
    bad.append("saw only %d anchored call(s), expected at least 2 (plan-waves, verification-lint)" % calls)
for m in bad:
    print("    " + m, file=sys.stderr)
sys.exit(1 if bad else 0)
PYEOF

echo "test-skill-trim-plan: references do not claim precedence over the body..."
if grep -qiE 'where the two disagree|SKILL\.md wins' "$SKILL_DIR"/references/*.md 2>/dev/null; then
  fail "a references/ file claims precedence over SKILL.md — that makes every shortening in the body binding on the full text"
else
  pass "no references/ file claims precedence over SKILL.md"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "test-skill-trim-plan: $FAILURES failure(s)" >&2
  exit 1
fi
echo "test-skill-trim-plan: OK"
