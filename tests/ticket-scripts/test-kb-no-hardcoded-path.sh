#!/usr/bin/env bash
# test-kb-no-hardcoded-path.sh — skill prose reads the resolved KB root (IDS-8 Phase B)
#
# Phase A gave the plugin a resolver. This asserts the resolver is actually the
# thing skills consult. It is the load-bearing half: sixteen prose sites named
# ~/.claude/gaspol-knowledge literally, and prose is what an agent executes. A
# correct environment variable plus instructions naming the old folder produces
# writes to the old folder — the setting works and the behaviour does not.
#
# Three of those sites inline a TWO-rung resolver
# (`${GASPOL_KB_LOCAL:-$HOME/.claude/gaspol-knowledge}`), which skips the config
# file entirely. That idiom is the defect in miniature, not an exemption.
#
# Positive control is mandatory here. An assertion that "no file names the path"
# passes trivially when the grep is wrong, and this repo has shipped exactly that
# kind of vacuous green before (KB: vacuous-assertion-proves-nothing). The sites
# demonstrably exist in git history, so the control below greps a string that
# must be found, proving the search itself works.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS="$REPO_ROOT/skills"

# The ONLY files permitted to spell the default path — they ARE the resolver:
# the doc that states the order and states, and the script that executes it.
# Pinned as an exact set so the exemption cannot quietly grow to cover the very
# skills this test polices.
ALLOWED_SET="_shared/kb-path.md _shared/kb-root"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-no-hardcoded-path: positive control — the search works..."
# Grep a term that is true BEFORE and AFTER this phase. An earlier draft
# controlled on "kb-path.md", which only exists once the fix lands — a control
# that depends on the fix cannot prove the search worked while it was red.
CONTROL=$(grep -rl "gaspol" "$SKILLS" 2>/dev/null | wc -l | tr -d ' ')
[ "$CONTROL" -gt 5 ] \
    || fail "positive control matched only $CONTROL file(s) under skills/ — the recursive search is broken, so a clean result below would prove nothing"

echo "test-kb-no-hardcoded-path: allow-list holds exactly the two resolver files..."
for a in $ALLOWED_SET; do
    [ -f "$SKILLS/$a" ] || fail "allow-listed resolver file $a does not exist — Phase A must land first"
done
[ "$(printf '%s\n' $ALLOWED_SET | wc -l | tr -d ' ')" = "2" ] \
    || fail "the allow-list is no longer exactly two files — every added exemption is a place the old path can hide"

echo "test-kb-no-hardcoded-path: no skill outside the resolver names the default path..."
OFFENDERS=$(grep -rl "gaspol-knowledge" "$SKILLS" 2>/dev/null \
            | sed "s|^$SKILLS/||" \
            | grep -vxF "$(printf '%s\n' $ALLOWED_SET)" || true)
if [ -n "$OFFENDERS" ]; then
    COUNT=$(printf '%s\n' "$OFFENDERS" | wc -l | tr -d ' ')
    echo "  offending files:" >&2
    printf '%s\n' "$OFFENDERS" | sed 's/^/    /' >&2
    fail "$COUNT file(s) still name gaspol-knowledge without going through the resolver — the env var can be right while the prose an agent reads sends it to the old folder"
fi

echo "test-kb-no-hardcoded-path: no inlined two-rung resolver..."
# `${GASPOL_KB_LOCAL:-$HOME/.claude/gaspol-knowledge}` resolves env-or-default and
# never consults gaspol-config.json. Caught separately from the plain-path check
# so the failure message names the real problem rather than "a path appears".
INLINE=$(grep -rln 'GASPOL_KB_LOCAL:-' "$SKILLS" 2>/dev/null \
         | sed "s|^$SKILLS/||" | grep -vxF "$(printf '%s\n' $ALLOWED_SET)" || true)
[ -z "$INLINE" ] \
    || fail "inlined two-rung resolver still present in: $INLINE — it skips the config rung, which is the only durable way to relocate the store"

echo "test-kb-no-hardcoded-path: the KB skills point AT the resolver..."
for s in gaspol-learn gaspol-adr gaspol-research gaspol-kb-audit gaspol-brainstorm; do
    grep -q "kb-path.md" "$SKILLS/$s/SKILL.md" \
        || fail "$s/SKILL.md does not reference _shared/kb-path.md — removing the literal path without pointing anywhere leaves the skill with no way to find the store at all"
done

echo "PASS: test-kb-no-hardcoded-path"
