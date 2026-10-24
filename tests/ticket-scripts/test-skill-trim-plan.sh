#!/usr/bin/env bash
# test-skill-trim-plan.sh — gaspol-plan must stay under the compaction cut (IDS-23 Phase D).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The ceiling is 18,000 bytes, which leaves headroom. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-plan/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-plan"
LIMIT=18000

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
  'header-never-substitute|NEVER substitute placeholders for real data sources without explicit'
  'header-copied-verbatim|are copied verbatim into every plan.'
  'header-hard-gate-named|the **Progress ledger — HARD PER-PHASE GATE**'
  'header-verification-commands|**Verification commands — written ONCE per plan, never per phase.**'
  'ledger-at-plan-write|**Create the ledger file now, at plan-write time** — do not defer this to the executor.'
  'ledger-no-verification-stop|block means the plan is incomplete: **STOP and ask**, never invent one to fill the gap.'
  'detect-stack-unknown-resolve|for that level and resolve it with AskUserQuestion before the plan is presented as final.'
  'detect-stack-nothing|`detect-stack` prints nothing → write'
  'ledger-copy-not-summarise|**Copy, do not summarise.** Both blocks already exist in the plan you just wrote, and'
  'ledger-four-sections|**Four mandatory sections, all ABOVE `## Log`:**'
  'ledger-step7-sections|the four mandatory sections, a `### [ ] Phase <N>: <name>` **sub-block per phase**'
  'ledger-log-last|**Structural rule — `## Log` is ALWAYS the last block in the file.**'
  'ledger-never-append|never append a section after `## Log`.'
  'ledger-reason-mandatory|a short reason is MANDATORY on the line + detail in the Log'
  'dim-mandatory|Every plan MUST include a Data Integration Map table:'
  'dim-stops|**If not possible:** Executor STOPS and asks the user. Never silently stub it out.'
  'dim-incomplete|A plan without a Data Integration Map is **INCOMPLETE**. Do not proceed to phases without it.'
  'deps-complexity-mandatory|**Deps and Complexity (MANDATORY, `waves-v1`):** every phase declares what it waits for and how'
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
  'offer-skipped-line|`[Eksekusi parallel]`, `[Serahkan ke executor luar]` — write one line to the ledger before handing'
  'offer-empty-reason-refused|An empty reason is refused: ask again.'
  'offer-save-later-no-line|`[Simpan buat sesi lain]` writes **NO line at all**.'
  'red-flags-check|Before presenting the plan, verify none of these red flags are present:'
  'red-flags-pointer|Read `references/plan-details.md` when you run this self-check: it holds the table.'
  'ledger-pointer|MUST use exactly the template in `references/ledger-format.md`. Read `references/ledger-format.md` when you write the ledger in step 7.'
  'handoff-pointer|Read `references/execution-handoff.md` when you present this offer'
  'verification-pointer|Read `references/plan-details.md` when you write a phase'"'"'s Verification block or fill the `**Verification commands:**` block.'
  'phase-template-pointer|Each phase MUST follow the exact structure in `references/phase-template.md`, copied verbatim.'
  'header-field-spec|`**Spec:**` only when a spec preceded this plan; omit the line entirely when the plan is standalone.'
  'header-field-artifact|omit the whole line otherwise, and never write "n/a".'
  'header-field-format|`**Format:** waves-v1` is always present in a new plan.'
  'header-pointer|Every plan MUST start with the header in `references/plan-header.md`, copied verbatim.'
  'date-is-creation-date|`YYYY-MM-DD` is the date this file is created — not the date the ticket was minted.'
  'completeness-rung-error|**Error paths** — which failures can actually happen here? Name them. Each becomes a step, not a footnote.'
  'completeness-rung-edge|**Edge cases** — enumerate the input space'
  'completeness-rung-tests|**Tests** — step 1 of the phase is still the failing test; rungs 2 and 3 each need a covering case.'
  'completeness-rung-happy|**Happy path** — which real integration does it deliver?'
  'completeness-rung-observability|**Observability** — what does a 3am debugger need to see?'
  'reuse-rule|prefer stdlib → native platform feature → already-installed dependency over new code, and plan no interface with one implementation'
  'ticket-exactly-one|read its `**Ticket:**` header field and reuse that ticket. Do not mint a new one.'
  'bite-sized-too-large|If a step takes longer than 5 minutes to describe, it is too large. Break it down further.'
  'phase-too-large|A phase estimated over 15 minutes is too large: break it into smaller phases.'
  'design-deliverable-must|the Phase table MUST include a Design Deliverable column'
  'ui-ux-once|`ui-ux-pro-max` is invoked at most once per ticket.'
  'evals-not-unit|**evals, not unit tests** — write `docs/evals/<feature>.md`'
  'complexity-rubric-complex|complex = new logic; money, auth or security; many interlinked files; an interface other phases consume'
  'self-check-deps-complexity|also count the `**Deps:**` lines and the `**Complexity:**` lines, which must each'
  'verification-generic-refused|An unfilled `real data from [specific source]` is generic and is refused.'
  'offer-auto-always|[Eksekusi otomatis]             → gaspol-auto, autonomous with hard-stop guardrails — ALWAYS offered'
  'executor-left-out|**neither set → leave this option out of the modal entirely.**'
  'executor-command-approval|the concrete command for approval before running.'
  'executor-never-commits|The external tool **NEVER commits/pushes**'
  'executor-review-not-skipped|and review is never skipped.'
  'artifact-two-places|record it in **two** places'
  'ledger-other-sections|**Every other section is added when it has content, never as an empty heading.**'
  'ledger-old-shape-rule|tick its line, append to its `## Log`, and leave its shape alone. Only a ledger you CREATE uses the new shape.'
  'save-later-complete|Nothing was skipped, because nothing executed.'
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

echo "test-skill-trim-plan: the plan-waves and verification-lint calls are in the body..."
python3 - "$SKILL" <<'PYEOF' || fail "the body lost the plan-waves or verification-lint call"
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
bash = re.findall(r"```bash\n(.*?)```", text, re.S)
bad = []
for script in ("plan-waves", "verification-lint"):
    if not any("/skills/gaspol-plan/scripts/%s" % script in b for b in bash):
        bad.append("no bash block runs %s" % script)
for m in bad:
    print("    " + m, file=sys.stderr)
sys.exit(1 if bad else 0)
PYEOF

echo "test-skill-trim-plan: plan-header.md holds the header template, with the Artifact comment intact..."
HDR="$SKILL_DIR/references/plan-header.md"
python3 - "$HDR" <<'PYEOF' || fail "references/plan-header.md lost the header template or one of its parts"
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.is_file():
    print("    references/plan-header.md does not exist", file=sys.stderr); sys.exit(1)
text = p.read_text(encoding="utf-8")
blocks = re.findall(r"```markdown\n(.*?)```", text, re.S)
hdr = [b for b in blocks if "**Format:** waves-v1" in b and "**Verification commands:**" in b and "**Ticket:**" in b]
bad = []
if len(hdr) != 1:
    bad.append("expected exactly one header template block, saw %d" % len(hdr))
else:
    b = hdr[0]
    for need in ("NEVER substitute placeholders for real data sources without explicit",
                 "HARD PER-PHASE GATE",
                 "This is **blocking**, like a test gate: no next phase until both are written.",
                 "**Self-contained:**",
                 "**Spec:** docs/plans/",
                 "omit the whole line otherwise, and never write \"n/a\" -- a declined artifact is recorded in the LEDGER as `design-artifact: skipped — <reason>`, not here",
                 "present ONLY when the post-plan offer's [Render design artifact dulu] option was taken and the artifact was approved"):
        if need not in b:
            bad.append("header template lost: " + need)
    lines = b.splitlines()
    idx = {k: next((i for i, l in enumerate(lines) if l.startswith(k)), -1)
           for k in ("**Spec:**", "**Artifact:**", "**Format:**")}
    if min(idx.values()) < 0 or not (idx["**Format:**"] > idx["**Spec:**"] and idx["**Format:**"] > idx["**Artifact:**"]):
        bad.append("Format must come after Spec and Artifact in the template")
for m in bad:
    print("    " + m, file=sys.stderr)
sys.exit(1 if bad else 0)
PYEOF

echo "test-skill-trim-plan: phase-template.md holds the phase template in order..."
python3 - "$SKILL_DIR/references/phase-template.md" <<'PYEOF' || fail "references/phase-template.md lost the phase template or its field order"
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.is_file():
    print("    references/phase-template.md does not exist", file=sys.stderr); sys.exit(1)
blocks = [b for b in re.findall(r"```markdown\n(.*?)```", p.read_text(encoding="utf-8"), re.S) if b.startswith("### Phase A: [Phase Name]")]
if len(blocks) != 1:
    print("    expected exactly one phase template block, saw %d" % len(blocks), file=sys.stderr); sys.exit(1)
order = ["**Deps:**", "**Complexity:**", "**Estimated time:**", "**Files:**", "**Steps:**", "**Verification:**"]
pos = [blocks[0].find(k) for k in order]
if min(pos) < 0 or pos != sorted(pos):
    print("    field order broken: %s" % pos, file=sys.stderr); sys.exit(1)
PYEOF

echo "test-skill-trim-plan: every backticked references/ path in the body exists, and each file has a 'Read ... when' pointer..."
REFS=$(grep -oE '`references/[A-Za-z0-9_.-]+\.md`' "$SKILL" | tr -d '`' | sort -u || true)
NREFS=$(printf '%s\n' "$REFS" | grep -c . || true)
if [ "${NREFS:-0}" -lt 4 ]; then
  fail "SKILL.md names only ${NREFS:-0} references/ path(s), expected at least 4 — the scan is broken or the pointers are gone"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    pass "skills/gaspol-plan/$ref exists"
  else
    fail "SKILL.md names skills/gaspol-plan/$ref but the file does not exist"
  fi
  if grep -qF -- "Read \`$ref\` when" "$SKILL"; then
    pass "SKILL.md says when to read $ref"
  else
    fail "SKILL.md has no 'Read \`$ref\` when ...' pointer"
  fi
done
for f in "$SKILL_DIR"/references/*.md; do
  rel="references/$(basename "$f")"
  if printf '%s\n' "$REFS" | grep -qxF -- "$rel"; then :; else fail "$rel exists but SKILL.md never points at it"; fi
done

echo "test-skill-trim-plan: the moved text is really in the references..."
for pair in 'references/ledger-format.md|## Pre-flight' 'references/ledger-format.md|## Keputusan saat jalan' 'references/execution-handoff.md|design-artifact: approved' 'references/execution-handoff.md|design-artifact: pending' 'references/plan-details.md|2026-04-17-gaspol-improvements.md' 'references/plan-details.md|| No Data Integration Map |'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-plan: relative markdown links inside references/ resolve..."
for f in "$SKILL_DIR"/references/*.md; do
  dir="$(dirname "$f")"
  for target in $(grep -oE '\]\([^)#]+\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    if [ -f "$dir/$target" ]; then pass "$(basename "$f") link $target resolves"; else fail "$(basename "$f") links to $target which does not resolve"; fi
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
