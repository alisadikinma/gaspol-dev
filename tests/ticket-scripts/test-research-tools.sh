#!/usr/bin/env bash
# test-research-tools.sh — IDS-21 Phase C: gaspol-research gathers with Firecrawl and
# synthesizes with the notebooklm CLI, with NO fallback to WebSearch/WebFetch.
#
# Pure text assertions over skills/gaspol-research/SKILL.md and the brainstorm
# Phase 1.5 SEMI-NEW bullet. The forbidden-tool matcher matches the INSTRUCTION
# forms ("use WebSearch", "WebFetch actual pages"), not the bare word, because the
# skill must be allowed to name the tools once, in the sentence that forbids them.
# A positive control proves the matcher catches an old-style line.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

SKILL="skills/gaspol-research/SKILL.md"
BRAIN="skills/gaspol-brainstorm/SKILL.md"
FAILURES=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# has <file> <fixed string> <description>
has() {
  local out rc=0
  out="$(grep -cF -- "$2" "$1" 2>/dev/null)" || rc=$?
  if [[ $rc -eq 0 && "${out:-0}" -gt 0 ]]; then pass "$3"; else fail "$3"; fi
}

# lacks <file> <ERE> <description>
lacks() {
  local out rc=0
  out="$(grep -cE -- "$2" "$1" 2>/dev/null)" || rc=$?
  if [[ "${out:-0}" -eq 0 ]]; then pass "$3"; else fail "$3"; fi
}

# Instruction forms of the old tools. Bare mentions are allowed (the no-fallback sentence).
FORBIDDEN_RE='([Uu]se `?(WebSearch|WebFetch)|(WebFetch|WebSearch)`? (actual|each|home)|`?(WebFetch|WebSearch)`? (queries|directly)|[0-9]-[0-9] `?WebSearch|^[0-9]+\. `?WebSearch|`WebFetch` home|current-year `?WebSearch|Web(Fetch|Search) (the|each|every))'

# --- positive control: matcher must catch old-style instruction lines ---
control_hits=0
for line in \
  'Simple fact lookup (use WebSearch directly)' \
  '1. Official documentation (`WebFetch` home URL + key docs pages)' \
  '1. **WebFetch actual pages** for claims critical to decision' \
  'Replace with current-year WebSearch' \
  'do 2-3 WebSearch queries about industry'; do
  if printf '%s\n' "$line" | grep -qE -- "$FORBIDDEN_RE"; then control_hits=$((control_hits + 1)); fi
done
if [[ $control_hits -eq 5 ]]; then pass "positive control: matcher catches all 5 old-style lines"; else fail "positive control: matcher caught $control_hits of 5 old-style lines"; fi

# --- notebooklm contract ---
nb="$(grep -c 'notebooklm' "$SKILL" 2>/dev/null)" || nb=0
if [[ "${nb:-0}" -gt 0 ]]; then pass "gaspol-research calls notebooklm"; else fail "gaspol-research does not call notebooklm"; fi
has "$SKILL" 'notebooklm create' "skill calls notebooklm create"
has "$SKILL" 'notebooklm source add' "skill calls notebooklm source add"
has "$SKILL" 'notebooklm source wait' "skill calls notebooklm source wait"
has "$SKILL" 'notebooklm ask' "skill calls notebooklm ask"
has "$SKILL" 'notebooklm list' "skill calls notebooklm list (reuse before create)"
has "$SKILL" 'notebooklm doctor' "skill checks notebooklm doctor"

# --- firecrawl contract ---
has "$SKILL" 'firecrawl_search' "skill names firecrawl_search"
has "$SKILL" 'firecrawl_scrape' "skill names firecrawl_scrape"
has "$SKILL" 'maxAge: 0' "skill scrapes freshness-critical pages with maxAge: 0"

# --- STOP-and-ask, no fallback ---
has "$SKILL" 'notebooklm login' "STOP rule names notebooklm login"
has "$SKILL" 'Firecrawl MCP' "STOP rule names the Firecrawl MCP"
has "$SKILL" 'STOP' "skill carries a STOP rule"
nf="$(grep -cE -- 'no fallback|never fall back|No fallback' "$SKILL" 2>/dev/null)" || nf=0
if [[ "${nf:-0}" -gt 0 ]]; then pass "skill states there is no fallback"; else fail "skill states there is no fallback"; fi
nf2="$(grep -E -- 'fallback' "$SKILL" 2>/dev/null | grep -cE -- 'WebSearch' 2>/dev/null)" || nf2=0
if [[ "${nf2:-0}" -gt 0 ]]; then pass "no-fallback sentence names WebSearch"; else fail "no-fallback sentence names WebSearch"; fi

# --- old instruction forms gone ---
lacks "$SKILL" "$FORBIDDEN_RE" "skill has no WebSearch/WebFetch instruction"
lacks "$SKILL" 'Dispatch 3-5 parallel subagents' "skill no longer dispatches parallel subagents"

# --- public URLs only ---
has "$SKILL" 'PUBLIC' "skill states only PUBLIC URLs become sources"
nf3="$(grep -ciE -- 'secrets|private repo' "$SKILL" 2>/dev/null)" || nf3=0
if [[ "${nf3:-0}" -gt 0 ]]; then pass "skill forbids secrets / private content as sources"; else fail "skill forbids secrets / private content as sources"; fi

# --- error paths written as steps ---
has "$SKILL" 'not added —' "source add failure recorded as 'not added — <reason>'"
has "$SKILL" 're-ask once' "uncited answer is re-asked once"
has "$SKILL" 'credits' "Firecrawl credits exhaustion has a STOP step"
has "$SKILL" 'still processing' "source wait timeout reports sources still processing"

# --- retained: quality gates, tier header, lane 6 ---
has "$SKILL" '≥4 sources' "quality gate (≥4 sources) retained"
has "$SKILL" 'Citation mandatory' "citation gate retained"
has "$SKILL" 'model-tier:' "model-tier: header retained"
has "$SKILL" 'npx skills find' "marketplace lane retained"
lacks "$SKILL" 'each subagent' "header no longer says 'each subagent'"

# --- brainstorm Phase 1.5 SEMI-NEW ---
has "$BRAIN" '`firecrawl_search` queries' "brainstorm SEMI-NEW names firecrawl_search queries"
lacks "$BRAIN" 'WebSearch' "brainstorm has no WebSearch queries"

echo
if [[ $FAILURES -eq 0 ]]; then echo "ALL PASS"; exit 0; else echo "$FAILURES FAILED"; exit 1; fi
