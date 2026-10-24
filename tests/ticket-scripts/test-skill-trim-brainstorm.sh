#!/usr/bin/env bash
# test-skill-trim-brainstorm.sh — gaspol-brainstorm must stay under the compaction cut (IDS-23 Phase G).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The ceiling is 18,000 bytes, which leaves headroom. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-brainstorm/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-brainstorm"
LIMIT=18000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# has FILE STRING — fixed-string match, no regex surprises.
has() { grep -qF -- "$2" "$1"; }

# Format: 'gate name|fixed string'. Matched with grep -qF, at least 25 characters, one line of the
# body that states the gate's condition AND consequence, not a heading.
GATES=(
  'hard-gate-1|gaspol-parallel), write any code, or scaffold anything until a design has been'
  'hard-gate-2|presented AND the user has approved it.'
  'hard-gate-every|## HARD-GATE (MANDATORY -- applies to EVERY request)'
  'hard-gate-weight|you present scales down (spec file → short in-chat design → probe plan), never whether'
  'claude-first|BEFORE exploring codebase, ALWAYS read CLAUDE.md first.'
  'vault-order|`INDEX.md` (master map) → `hot.md` (what changed lately) → `10-Identity/` (identity, voice and'
  'vault-not-failure|**No vault configured is not a failure.** Say so, name `kb_local` in'
  'kb-unknown-stop|`UNKNOWN` → **STOP and ask**, never treat an unreadable store as an empty one.'
  'kb-none|`none` → record `knowledge-store: none — not configured`'
  'kb-no-git-init|**Create the directory only, never `git init`.**'
  'kb-root-anchored|"$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")" || exit 1'
  'kb-off|Runs on the ARCHITECTURAL and BOUNDED paths. Only "kb_mode": "off" disables it.'
  'batch-default|A request carrying MORE THAN ONE item is ONE ticket by default.'
  'batch-ceiling|Splitting needs a reason from the closed list. The ceiling is two.'
  'batch-out-loud|State the ruling out loud before anything else'
  'batch-third|one: ask via **AskUserQuestion**.'
  'paths-classify|Classify every request into one of three paths BEFORE asking any clarifying question,'
  'paths-ratchet|**One-way ratchet:** hidden complexity discovered mid-task upgrades the path (spike →'
  'paths-no-downgrade|mid-task; once a heavier path is warranted you don'"'"'t talk yourself back down.'
  'decompose|- **Decompose gate (AFTER the Batch Gate, BEFORE refining details):** this gate is for a'
  'decompose-flag|When it really is multi-project: flag it immediately — do NOT spend clarifying questions on a'
  'one-question|- Ask questions ONE at a time using the **AskUserQuestion** tool (MANDATORY)'
  'no-plain-text|- NEVER ask questions as plain text output — always use the AskUserQuestion tool so the user gets the interactive selection UI'
  'novelty-precedent|  PRECEDENT: KB hit (Phase 0.5 surfaced match) AND project CLAUDE.md has similar pattern'
  'novelty-semi|  SEMI-NEW: KB hit but no project pattern, OR project pattern but no KB validation'
  'novelty-new|  NEW: No KB hit AND no project pattern'
  'never-auto-install|NEVER auto-install what it returns'
  'gate-routes|This gate routes; it decides WHICH design lane, not whether one exists.'
  'gate-ambiguous|If Phase 3 triggers are AMBIGUOUS (mixed signals — some UI, some backend):'
  'gate-non-ui|If clearly non-UI (pure backend/API/DB/business logic):'
  'phase3-detect|**Detection:** Phase 2.5 gate determined UI work needed → invoke the **`ui-ux-pro-max`** skill.'
  'phase3-soft-ref|**If it is not installed:** tell the user to run `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill`'
  'design-md-offer|Offer it with **AskUserQuestion**: `[Write DESIGN.md]` / `[Not now — keep the gate off]` /'
  'design-md-never|it without asking, and never write it before the palette is approved — a contract frozen around'
  'feasibility-real|- Can this be built with REAL data from existing backend?'
  'feasibility-placeholder|- Flag anything that would require placeholder implementation'
  'present-confirm|- After each section, use **AskUserQuestion** tool to confirm:'
  'present-cover|- Cover: architecture, components, data flow, error handling'
  'present-map|- Include Data Integration Map:'
  'ticket-once|**once per batch** — the Batch Gate in Phase 1 already decided how many tickets exist'
  'ticket-exit2|3. **Exit 2** — no `## gaspol Ticket Counter` section exists yet. Use **AskUserQuestion**'
  'ticket-prefix|to ask the user for a ticket prefix (no default guess).'
  'spec-path|- Write to `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md`, where `YYYY-MM-DD` is'
  'builder-opus|subagent with `model: "opus"` written at the call site (`model-tier: judge`). Its prompt is'
  'builder-nothing|"looks unnecessary" parts, or exactly `nothing important left`. Answer what the spec or'
  'builder-one-round|Run **one round** only: no re-dispatch loop (`skills/_shared/fix-loop.md`).'
  'user-reads-spec|changes; only proceed to gaspol-plan once they approve the written spec.'
)

echo "test-skill-trim-brainstorm: positive control (has must reject a string the file lacks)..."
if has "$SKILL" "zzz-this-string-is-not-in-any-skill-zzz"; then
  fail "positive control: has() matched a string that cannot exist"
fi

echo "test-skill-trim-brainstorm: size ceiling..."
[ -f "$SKILL" ] || { echo "FAIL: $SKILL_REL missing" >&2; exit 1; }
BYTES=$(wc -c < "$SKILL" | tr -d ' ')
if [ "$BYTES" -lt "$LIMIT" ]; then
  pass "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
else
  fail "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
fi

echo "test-skill-trim-brainstorm: every gate survives in the body..."
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

echo "test-skill-trim-brainstorm: every backticked references/ path in the body exists, and each file has a 'Read ... when' pointer..."
REFS=$(grep -oE '`references/[A-Za-z0-9_.-]+\.md`' "$SKILL" | tr -d '`' | sort -u || true)
NREFS=$(printf '%s\n' "$REFS" | grep -c . || true)
if [ "${NREFS:-0}" -lt 3 ]; then
  fail "SKILL.md names only ${NREFS:-0} references/ path(s), expected at least 3 — the scan is broken or the pointers are gone"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then pass "skills/gaspol-brainstorm/$ref exists"; else fail "SKILL.md names skills/gaspol-brainstorm/$ref but the file does not exist"; fi
  if [ "$ref" = "references/builder-check-prompt.md" ]; then pass "builder-check-prompt is pointed at by the Phase 6 builder check";
  elif grep -qF -- "Read \`$ref\` when" "$SKILL"; then pass "SKILL.md says when to read $ref"; else fail "SKILL.md has no 'Read \`$ref\` when ...' pointer"; fi
done
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || { fail "no references/*.md files exist"; break; }
  rel="references/$(basename "$f")"
  if printf '%s\n' "$REFS" | grep -qxF -- "$rel"; then :; else fail "$rel exists but SKILL.md never points at it"; fi
done

echo "test-skill-trim-brainstorm: the moved text is really in the references..."
for pair in \
  'references/phase-0-5-precedent.md|Found relevant past work:' \
  'references/phase-0-5-precedent.md|[Override with reason — capture divergence ADR]' \
  'references/phase-0-5-precedent.md|**Spike stays exempt**, deliberately.' \
  'references/phase-3-design.md|### Freeze the approved palette into DESIGN.md (v1.17)' \
  'references/phase-3-design.md|### Visual Companion (just-in-time — v1.7)' \
  'references/phase-3-design.md|Expected back:' \
  'references/phase-3-design.md|- **Offer just-in-time, NEVER upfront.**' \
  'references/phase-detail.md|**Red flags (classification-dodging):**' \
  'references/phase-detail.md|Classification questions (internal — not asked to user):' \
  'references/phase-detail.md|**Source citation MANDATORY** per approach (when research done):' \
  'references/phase-detail.md|**UI keyword detection:**'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if [ -f "$SKILL_DIR/$rf" ] && has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-brainstorm: relative markdown links inside references/ resolve..."
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || continue
  dir="$(dirname "$f")"
  for target in $(awk '/^```/{c=!c;next} !c' "$f" | grep -oE '\]\([^)#]+\.md\)' | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    if [ -f "$dir/$target" ]; then pass "$(basename "$f") link $target resolves"; else fail "$(basename "$f") links to $target which does not resolve"; fi
  done
done

echo "test-skill-trim-brainstorm: references do not claim precedence over the body..."
if grep -qiE 'where the two disagree|SKILL\.md wins' "$SKILL_DIR"/references/*.md 2>/dev/null; then
  fail "a references/ file claims precedence over SKILL.md"
else
  pass "no references/ file claims precedence over SKILL.md"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "test-skill-trim-brainstorm: $FAILURES failure(s)" >&2
  exit 1
fi
echo "test-skill-trim-brainstorm: OK"
