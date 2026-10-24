#!/usr/bin/env bash
# test-skill-trim-finish.sh — gaspol-finish must stay under the compaction cut (IDS-23 Phase H).
#
# Claude Code keeps only the first 20,000 characters of a SKILL.md after /compact, so any gate
# that sits past the cut vanishes. The ceiling is 18,000 bytes, which leaves headroom. A trim is
# only legitimate if every gate survives IN THE BODY, so the GATES table below pins one fixed
# string per gate (the sentence that states its condition and consequence) and a size pass
# without a gate pass is a failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="skills/gaspol-finish/SKILL.md"
SKILL="$REPO_ROOT/$SKILL_REL"
SKILL_DIR="$REPO_ROOT/skills/gaspol-finish"
LIMIT=18000

FAILURES=0
fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

# has FILE STRING — fixed-string match, no regex surprises.
has() { grep -qF -- "$2" "$1"; }

# Format: 'gate name|fixed string'. Matched with grep -qF, at least 25 characters, one line of the
# body that states the gate's condition AND consequence, not a heading.
GATES=(
  'chain-in-order|complete this chain **in order, all four steps**. Do not skip'
  'chain-none-optional|steps. None of the four is optional or conditional on the diff'"'"'s contents.'
  'step1-heading|### Step 1: Run gaspol-verify (all 4 layers)'
  'step1-sole-owner|This step is the only owner of the full suite: `gaspol-execute` and'
  'step1-ledger-line|After a pass, append `verified: PASS @ \`<sha>\`` to the ledger `## Log` (SHA from'
  'reuse-only-when|**Reuse on a later entry** (for example after `[Nanti]`): a recorded line is reused ONLY when its'
  'reuse-sha-clean|`<sha>` equals `git rev-parse HEAD` AND `git status --porcelain` prints nothing. Same SHA means'
  'reuse-from-ledger|full suite. Read the line from the ledger; never accept it from memory. A missing or unreadable'
  'reuse-no-line|ledger, a different SHA, a dirty tree, or a line whose SHA is unbackticked or garbled all count as'
  'reuse-logged|no line: run it again. A reuse writes `verified: reused @ \`<sha>\`` to the Log, so nothing is'
  'step2-heading|### Step 2: Run plan-verifier agent BLOCKING (step-level, evidence-based, spot-check 3 random FOUND items)'
  'step2-skip-only|plan**: no `**Plan:**` header in a ledger for this branch, **and** no `docs/plans/*-plan.md`'
  'step2-skip-line|When you skip it, record `plan-verifier: skipped — no plan referenced by this branch` in the'
  'step2-silent|ledger and continue. A silent omission is indistinguishable from a gate that ran and passed.'
  'step2-clean-line|After a CLEAN verdict, append `plan-verifier: CLEAN @ \`<sha>\`` to the ledger `## Log`. The reuse'
  'step2-reuse|rule is Step 1'"'"'s, unchanged: reuse a recorded verdict only when its `<sha>` equals'
  'step2-reuse-clean|`git rev-parse HEAD` and `git status --porcelain` is empty, read from the ledger and never from'
  'step2-blocking|**This step is BLOCKING.** You CANNOT present merge/PR options until the verdict is `CLEAN`.'
  'step2-spot-check|**Anti-hallucination spot-check (mandatory):** After plan-verifier reports, sample 3 random FOUND items and Read the quoted file:line to verify quote accuracy. Fabricated quotes → auto-downgrade to MISSING + re-evaluate verdict.'
  'step2-no-waste|plan-verifier. Do NOT proceed to Step 3 — don'"'"'t waste a review pass on code that'"'"'s about to'
  'step3-heading|### Step 3: Run gaspol-review AT TIER 1 -- BLOCKING on any surviving Critical finding'
  'step3-blocking|**This step is BLOCKING.** Any surviving (post-refutation, CONFIRMED or unverifiable) Critical'
  'step3-stops|finding STOPS the chain here.'
  'step3-refutation|Findings must clear gaspol-review'"'"'s own Step 2.5 adversarial refutation before they count.'
  'step3-no-step4|not proceed to Step 4 until it is clean.'
  'step4-heading|### Step 4: Run gaspol-sync-docs (update CLAUDE.md) -- evidence-gated'
  'step4-evidence|or altered a routing table, a chain step,'
  'step4-in-diff|then **CLAUDE.md must appear in the branch diff**:'
  'step4-not-complete|If that check fails on a structural change, Step 4 is NOT complete: run `gaspol-sync-docs`'
  'step4-never-bare|"no doc-visible change", and it must say which — never a bare COMPLETED.'
  'offer-options|[Jalankan /security-review]  [Lewati]'
  'offer-declining|**Declining records nothing.** No ledger line, no reason demanded (IDS-17). That is a real'
  'offer-blocks|**Unchanged when it IS run:** a finding still BLOCKS. Resolve via AskUserQuestion —'
  'offer-no-merge|Never present merge options with an unresolved security finding.'
  'offer-not-passed|**never record it as passed when it did not run.**'
  'fix-loop-canonical|**Canonical rule: [skills/_shared/fix-loop.md](../_shared/fix-loop.md).** `gaspol-parallel`'
  'fix-loop-adjudicate|tier above. The final round **adjudicates** the still-open findings against the plan and'
  'fix-loop-never-checker|**Never go looking for a checker to run**'
  'chain-incomplete|**If plan-verifier (step 2) returned BLOCKING**, the chain is incomplete. Do NOT present options.'
  'chain-incomplete-3|do not proceed to step 4 until clean.'
  'present-askuser|After the verification chain passes, use the **AskUserQuestion** tool (MANDATORY) to present exactly these 4 options'
  'option-3|Leave the branch and worktree in place. Continue work later.'
  'derive-cmd|# Verify tests still pass after merge. DERIVE the command -- never assume npm.'
  'detect-stack-call|skills/gaspol-execute/scripts/detect-stack .'
  'not-publishing|**Merging is not publishing.** A local merge leaves the work on this machine only.'
  'before-shipped|Before reporting the branch as shipped:'
  'plugin-update|claude plugin update <plugin>@<marketplace>   # the full id; the bare name fails'
  'plugin-restart|Restart Claude Code afterwards; an updated plugin does not take effect in the'
  'discard-typed|**Requires explicit confirmation:** The user must type "discard" to confirm.'
  'discard-irreversible|Delete all work on this branch. This is destructive and irreversible.'
  'ledger-close|`— NEXT: DONE`. State which option was taken and the merge/PR reference, e.g.'
  'ledger-checklist|2. Confirm every `## Checklist` line is `[x]` or `[~]`. A `[ ]` or `[>]` left at'
  'ledger-scan|skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress'
  'red-no-failing|1. **Never merge with failing tests** -- Fix the tests first. No exceptions.'
  'red-no-discard|5. **Never discard without typed confirmation**'
  'red-no-cleanup|6. **Never clean up worktree before confirming the merge succeeded**'
)

echo "test-skill-trim-finish: positive control (has must reject a string the file lacks)..."
if has "$SKILL" "zzz-this-string-is-not-in-any-skill-zzz"; then
  fail "positive control: has() matched a string that cannot exist"
fi

echo "test-skill-trim-finish: size ceiling..."
[ -f "$SKILL" ] || { echo "FAIL: $SKILL_REL missing" >&2; exit 1; }
BYTES=$(wc -c < "$SKILL" | tr -d ' ')
if [ "$BYTES" -lt "$LIMIT" ]; then
  pass "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
else
  fail "$SKILL_REL is $BYTES bytes (limit: under $LIMIT)"
fi

echo "test-skill-trim-finish: every gate survives in the body..."
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

echo "test-skill-trim-finish: exact heading and command lines stay in the body..."
for exact in '### Option 1: Merge Locally' '### Option 2: Push and Create PR' '### Option 3: Keep As-Is' '### Option 4: Discard' 'git push origin main'; do
  if grep -qxF -- "$exact" "$SKILL"; then pass "line present: $exact"; else fail "line missing from SKILL.md body: $exact"; fi
done

echo "test-skill-trim-finish: the four mandatory steps stay in order..."
prev=0
for n in 1 2 3 4; do
  line=$(grep -nF -- "### Step $n: " "$SKILL" | head -1 | cut -d: -f1)
  if [ -z "$line" ]; then fail "Step $n heading missing"; continue; fi
  if [ "$line" -gt "$prev" ]; then pass "Step $n at line $line, after the previous step"; else fail "Step $n at line $line is not after the previous step"; fi
  prev=$line
done

echo "test-skill-trim-finish: every backticked references/ path in the body exists, and each file has a 'Read ... when' pointer..."
REFS=$(grep -oE '`references/[A-Za-z0-9_.-]+\.md`' "$SKILL" | tr -d '`' | sort -u || true)
NREFS=$(printf '%s\n' "$REFS" | grep -c . || true)
if [ "${NREFS:-0}" -lt 1 ]; then
  fail "SKILL.md names only ${NREFS:-0} references/ path(s), expected at least 1 — the scan is broken or the pointers are gone"
fi
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then pass "skills/gaspol-finish/$ref exists"; else fail "SKILL.md names skills/gaspol-finish/$ref but the file does not exist"; fi
  if grep -qF -- "Read \`$ref\` when" "$SKILL"; then pass "SKILL.md says when to read $ref"; else fail "SKILL.md has no 'Read \`$ref\` when ...' pointer"; fi
done
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || { fail "no references/*.md files exist"; break; }
  rel="references/$(basename "$f")"
  if printf '%s\n' "$REFS" | grep -qxF -- "$rel"; then :; else fail "$rel exists but SKILL.md never points at it"; fi
done

echo "test-skill-trim-finish: the moved text is really in the references..."
for pair in \
  'references/offers.md|**Where Step 0 went (IDS-17).**' \
  'references/offers.md|**Why it is an offer.** Not every ticket changes anything security-related' \
  'references/offers.md|**Not affected by this change:** `gaspol-execute` Step 3.6 still runs `/security-review`' \
  'references/offers.md|gh pr create --title "feat: description"' \
  'references/offers.md|**Use when:** Team review needed, CI/CD pipeline should run' \
  'references/offers.md|git branch -D feature/my-feature' \
  'references/offers.md|## Finish Summary'; do
  rf="${pair%%|*}"; needle="${pair#*|}"
  if [ -f "$SKILL_DIR/$rf" ] && has "$SKILL_DIR/$rf" "$needle"; then pass "$rf holds: $needle"; else fail "$rf lost: $needle"; fi
done

echo "test-skill-trim-finish: relative markdown links inside references/ resolve..."
for f in "$SKILL_DIR"/references/*.md; do
  [ -e "$f" ] || continue
  dir="$(dirname "$f")"
  for target in $(awk '/^```/{c=!c;next} !c' "$f" | grep -oE '\]\([^)#]+\.md\)' | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^https?:' || true); do
    if [ -f "$dir/$target" ]; then pass "$(basename "$f") link $target resolves"; else fail "$(basename "$f") links to $target which does not resolve"; fi
  done
done

echo "test-skill-trim-finish: references do not claim precedence over the body..."
if grep -qiE 'where the two disagree|SKILL\.md wins' "$SKILL_DIR"/references/*.md 2>/dev/null; then
  fail "a references/ file claims precedence over SKILL.md"
else
  pass "no references/ file claims precedence over SKILL.md"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "test-skill-trim-finish: $FAILURES failure(s)" >&2
  exit 1
fi
echo "test-skill-trim-finish: OK"
