#!/usr/bin/env bash
# test-prior-art-gate.sh — TDD test for ticket IDS-4: nothing gets built in-house
# before somebody looks whether it already exists.
#
# The baseline failure is not hypothetical. Both skills deleted in v1.14 (IDS-2)
# existed because nobody searched first: one was a 1.4MB fork of design data
# ui-ux-pro-max already publishes, the other a 12KB checklist for a
# /security-review command already compiled into the Claude Code binary.
# Two builds, two deletions, zero prior-art searches.
#
#   test_prior_art_gate      (Phase A) — the BLOCKING gate at _shared/prior-art-gate.md
#                              (IDS-11 moved it out of gaspol-write-skill, which was deleted;
#                              bound to skill-authoring the rule would have died with its host)
#   test_brainstorm_probe    (Phase B) — NEW branch of Phase 1.5 probes the market
#   test_research_lane       (Phase C) — gaspol-research treats skills as a source
#   test_docs_consistent     (Phase D) — counts, versions, ticket counter agree
#
# Same exclusions as test-skill-delegation.sh: docs/plans/ and CHANGELOG.md are a
# historical record, not a place to keep current.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

GATE="skills/_shared/prior-art-gate.md"
BRAINSTORM="skills/gaspol-brainstorm/SKILL.md"
RESEARCH="skills/gaspol-research/SKILL.md"

FAILURES=0

pass() { echo "PASS: $1"; }

fail() {
  echo "FAIL: $1"
  shift
  [[ $# -gt 0 ]] && printf '%s\n' "$@" >&2
  FAILURES=$((FAILURES + 1))
}

# assert_grep <description> <fixed-string pattern> <file...>
assert_grep() {
  local desc="$1"; shift
  local pattern="$1"; shift
  if grep -qF -- "$pattern" "$@" 2>/dev/null; then pass "$desc"; else fail "$desc" "not found: $pattern"; fi
}

# assert_absent_grep <description> <fixed-string pattern> <file...>
assert_absent_grep() {
  local desc="$1"; shift
  local pattern="$1"; shift
  if grep -qF -- "$pattern" "$@" 2>/dev/null; then
    fail "$desc" "present but must not be: $pattern"
  else
    pass "$desc"
  fi
}

# self_check
# Guards every assert_grep above against a vacuous pass. If the target files were
# renamed or moved, grep on a missing path returns non-zero and each assertion
# would report a real-looking FAIL — but the reverse (a helper that never matches
# anything yet reports PASS) is the dangerous direction, so prove the helper can
# still find a string that is definitely there.
self_check() {
  local f
  for f in "$GATE" "$BRAINSTORM" "$RESEARCH"; do
    [[ -f "$f" ]] || { fail "self-check: target file exists" "missing: $f"; return; }
  done
  if grep -qF 'NOTHING GETS BUILT IN-HOUSE BEFORE A PRIOR-ART SEARCH' "$GATE"; then
    pass "self-check: grep helper still matches a known-present string"
  else
    fail "self-check: grep helper still matches a known-present string" \
      "every assertion in this file is meaningless"
  fi
}

# ---------------------------------------------------------------------------
# Phase A — the shared Prior-Art Gate is BLOCKING and complete
# ---------------------------------------------------------------------------
# Three lookups, not one. "Is it installed?" misses built-in slash commands
# (/security-review was never in any skill listing) and misses the marketplace
# (ui-ux-pro-max was one `npx skills find` away). Each lookup is asserted
# individually so a reword that quietly drops one cannot pass.
test_prior_art_gate() {
  assert_grep "the gate exists and is BLOCKING" \
    "NOTHING GETS BUILT IN-HOUSE BEFORE A PRIOR-ART SEARCH" "$GATE"

  # It must NOT be bound to skill-authoring any more: the two live referrers are
  # brainstorm and research, neither of which is writing a skill.
  assert_grep "the gate names its non-skill triggers" \
    "gaspol-brainstorm" "$GATE"

  assert_grep "lookup 1 — already installed" \
    "Installed already?" "$GATE"

  assert_grep "lookup 2 — built into the harness" \
    "Built into the harness?" "$GATE"

  assert_grep "lookup 3 — the marketplace" \
    "npx skills find" "$GATE"

  assert_grep "marketplace browse URL is named" \
    "https://skills.sh" "$GATE"

  # Three verdicts, because the interesting one is DELTA. A binary
  # exists/doesn't-exist verdict is what produced the 1.4MB fork: "ours needs to
  # be different" is true and still does not justify rebuilding the other 95%.
  assert_grep "verdict NONE defined" "\`NONE\`" "$GATE"
  assert_grep "verdict EXISTS defined" "\`EXISTS\`" "$GATE"
  assert_grep "verdict DELTA defined" "\`DELTA\`" "$GATE"
  assert_grep "DELTA requires naming the delta" "name the delta" "$GATE"

  # Install safety. Upstream find-skills documents `npx skills add <x> -g -y`
  # verbatim; a skill is a prompt that executes inside the agent, so an
  # unattended install of an unknown repo is a supply-chain decision.
  assert_grep "auto-install with -y is forbidden" \
    "npx skills add ... -y" "$GATE"
  assert_grep "install goes through AskUserQuestion" \
    "AskUserQuestion" "$GATE"
  assert_grep "candidate SKILL.md must be read before recommending" \
    "READ the candidate's SKILL.md" "$GATE"
  assert_grep "install count is not an audit" \
    "not an audit" "$GATE"
  assert_grep "standing context cost of an installed skill is stated" \
    "every** session" "$GATE"

  # Soft dependency, same rule the ui-ux-pro-max delegation established: the CLI
  # missing degrades the search, it never blocks the skill.
  assert_grep "missing CLI degrades gracefully" \
    "if the command is unavailable" "$GATE"
  assert_grep "an unrun search is never recorded as done" \
    "never record the search as done" "$GATE"

  # The gate has to survive contact with the checklist and the excuse table, or
  # it is prose nobody executes.
  assert_grep "RED-phase checklist carries the prior-art item" \
    "- [ ] Prior-art search run" "$GATE"
  assert_grep "rationalization table blocks 'I would remember it'" \
    "I'd remember if something existed" "$GATE"
  assert_grep "rationalization table blocks the ours-is-different excuse" \
    "Ours needs to be different" "$GATE"
}

# ---------------------------------------------------------------------------
# Phase B — brainstorm probes the market only where research already fires
# ---------------------------------------------------------------------------
# Deliberately NOT Phase 0.5. Phase 0.5 is product precedent (does this codebase
# already solve it); the marketplace holds agent capabilities. Running `npx
# skills find` on every feature request would add an npx round-trip and noise to
# brainstorms that have nothing to do with agent tooling. The NEW branch of Phase
# 1.5 is where the skill has already concluded it has no precedent at all.
test_brainstorm_probe() {
  assert_grep "Phase 1.5 NEW branch probes the skills marketplace" \
    "npx skills find" "$BRAINSTORM"

  assert_grep "probe defers install rules to the shared gate" \
    "_shared/prior-art-gate.md" "$BRAINSTORM"

  # The probe must not leak into the cheap paths.
  local phase05
  phase05="$(sed -n '/^## Phase 0.5/,/^## Phase 1:/p' "$BRAINSTORM" || true)"
  if [[ -n "$phase05" && "$phase05" == *"npx skills find"* ]]; then
    fail "marketplace probe stays out of Phase 0.5" \
      "Phase 0.5 is product precedent, not agent capability"
  else
    pass "marketplace probe stays out of Phase 0.5"
  fi
}

# ---------------------------------------------------------------------------
# Phase C — gaspol-research treats an existing skill as a research finding
# ---------------------------------------------------------------------------
# Research already gathers docs, GitHub signal, comparables, anti-patterns and
# case studies. "Somebody already packaged this as a skill" is the same class of
# finding and the cheapest possible recommendation.
test_research_lane() {
  assert_grep "gather phase has an agent-skill lane" \
    "Agent-skill marketplace" "$RESEARCH"

  assert_grep "research red flag catches a missed existing skill" \
    "Recommending a build when a packaged skill already does it" "$RESEARCH"
}

# ---------------------------------------------------------------------------
# Phase D — documentation agrees with the filesystem
# ---------------------------------------------------------------------------
test_docs_consistent() {
  local n
  n="$(ls skills | grep -v '^_shared$' | wc -l | tr -d ' ')"

  # This ticket adds a gate, not a skill. The count must be UNCHANGED — a bump
  # here would mean somebody built the thing the gate exists to prevent.
  if grep -q "\*\*${n} development skills" CLAUDE.md; then
    pass "CLAUDE.md skill count matches the filesystem (${n})"
  else
    fail "CLAUDE.md skill count matches the filesystem (${n})" \
      "$(grep -o '\*\*[0-9]* development skills' CLAUDE.md || echo 'no count line found')"
  fi

  local pv mv mm_path mm_rc
  pv="$(grep -m1 '"version"' .claude-plugin/plugin.json | tr -dc '0-9.')"
  # The marketplace manifest moved to the gaspol-one repo in 50fbbb1. Resolve
  # it and keep the three states apart -- "not present" is reported as not
  # checked, never as agreement.
  mm_path="$(tests/ticket-scripts/marketplace-manifest)"; mm_rc=$?
  case "$mm_rc" in
    0)
      mv="$(grep -m1 '"version"' "$mm_path" | tr -dc '0-9.')"
      if [[ -n "$pv" && "$pv" == "$mv" ]]; then
        pass "plugin.json and the marketplace manifest agree on version ($pv)"
      else
        fail "plugin.json and the marketplace manifest agree on version" "plugin=$pv marketplace=$mv"
      fi
      ;;
    3) fail "marketplace-manifest resolves" "UNKNOWN -- configured and unreadable" ;;
    4) echo "  SKIP: marketplace manifest not present -- version agreement NOT checked" ;;
  esac

  if grep -q "^\*\*Version:\*\* ${pv}$" CLAUDE.md; then
    pass "CLAUDE.md footer version matches ($pv)"
  else
    fail "CLAUDE.md footer version matches ($pv)" \
      "$(grep '^\*\*Version:\*\*' CLAUDE.md || echo 'no footer version')"
  fi

  assert_grep "CHANGELOG records this release" "## [$pv]" CHANGELOG.md

  # The counter is a shared repo-level fact, not this ticket's private property:
  # a later ticket minted in parallel legitimately pushes it past IDS-4. Assert
  # that it ADVANCED past IDS-3, not that it equals any one value.
  local last
  last="$(grep -m1 '^Last ticket: IDS-' CLAUDE.md | tr -dc '0-9')"
  if [[ -n "$last" && "$last" -ge 4 ]]; then
    pass "ticket counter advanced past IDS-3 (now IDS-$last)"
  else
    fail "ticket counter advanced past IDS-3" \
      "$(grep -m1 '^Last ticket:' CLAUDE.md || echo 'no counter line')"
  fi

  # IDS-11 moved the gate out of the deleted gaspol-write-skill, so the assertion
  # follows the gate to its new home rather than to the phrase it used to carry.
  assert_grep "CLAUDE.md documents the prior-art gate" \
    "Prior-Art Gate" CLAUDE.md
  assert_grep "CLAUDE.md names the gate's canonical file" \
    "_shared/prior-art-gate.md" CLAUDE.md

  # No hard dependency on the skills CLI, for the same all-or-nothing reason
  # ui-ux-pro-max was kept soft.
  if grep -q '"dependencies"' .claude-plugin/plugin.json 2>/dev/null; then
    fail "plugin.json declares no hard dependency" \
      "plugin.json gained a dependencies key — all-or-nothing failure mode"
  else
    pass "plugin.json declares no hard dependency"
  fi
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
self_check
test_prior_art_gate
test_brainstorm_probe
test_research_lane
test_docs_consistent

if [[ "$FAILURES" -gt 0 ]]; then
  echo "test-prior-art-gate: $FAILURES assertion(s) failed" >&2
  exit 1
fi

echo "PASS: test-prior-art-gate"
