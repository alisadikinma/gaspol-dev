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
# Scanning ONLY skills/ was this ticket's own blind spot: docs/kb-setup.md kept a
# runnable block with the two-rung resolver, a `git init` into the store, and an
# unguarded commit+push — and all three syncing skills link to that file as the
# authority. Every gate below therefore covers docs/ and the root markdown too.
SCAN_PATHS="$REPO_ROOT/skills $REPO_ROOT/docs $REPO_ROOT/README.md $REPO_ROOT/CLAUDE.md"
# docs/plans/ is excluded: those are DATED RECORDS of what was decided, including this
# ticket's own spec quoting the defect verbatim. Rewriting history to satisfy a lint
# would destroy the audit trail. Instructions get linted; records do not.
EXCLUDE_RE='docs/plans/'

# The ONLY files permitted to spell the default path — they ARE the resolver:
# the doc that states the order and states, and the script that executes it.
# Pinned as an exact set so the exemption cannot quietly grow to cover the very
# skills this test polices.
ALLOWED_SET="_shared/kb-path.md _shared/kb-root docs/kb-setup.md CLAUDE.md README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-no-hardcoded-path: positive control — the search works..."
# Grep a term that is true BEFORE and AFTER this phase. An earlier draft
# controlled on "kb-path.md", which only exists once the fix lands — a control
# that depends on the fix cannot prove the search worked while it was red.
CONTROL=$(grep -rl "gaspol" $SCAN_PATHS 2>/dev/null | wc -l | tr -d ' ')
[ "$CONTROL" -gt 5 ] \
    || fail "positive control matched only $CONTROL file(s) under skills/ — the recursive search is broken, so a clean result below would prove nothing"

echo "test-kb-no-hardcoded-path: allow-list holds exactly the two resolver files..."
for a in $ALLOWED_SET; do
    # entries are either skills/-relative (the two resolver files) or repo-relative (the docs)
    [ -f "$SKILLS/$a" ] || [ -f "$REPO_ROOT/$a" ] \
        || fail "allow-listed file $a does not exist — Phase A must land first"
done
[ "$(printf '%s\n' $ALLOWED_SET | wc -l | tr -d ' ')" = "5" ] \
    || fail "the allow-list changed size — every added exemption is a place the old path can hide"
# The three documentation files are allowed to NAME the default (they explain the
# resolution order) but must never carry runnable bash that USES it. That is checked
# separately below, because naming and executing are different risks.

echo "test-kb-no-hardcoded-path: no skill outside the resolver names the default path..."
OFFENDERS=$(grep -rl "gaspol-knowledge" $SCAN_PATHS 2>/dev/null \
            | grep -v "$EXCLUDE_RE" \
            | sed "s|^$REPO_ROOT/||;s|^skills/||" \
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
INLINE=$(grep -rln 'GASPOL_KB_LOCAL:-' $SCAN_PATHS 2>/dev/null \
         | grep -v "$EXCLUDE_RE" \
         | sed "s|^$REPO_ROOT/||;s|^skills/||" | grep -vxF "$(printf '%s\n' $ALLOWED_SET)" || true)
[ -z "$INLINE" ] \
    || fail "inlined two-rung resolver still present in: $INLINE — it skips the config rung, which is the only durable way to relocate the store"

echo "test-kb-no-hardcoded-path: the KB skills point AT the resolver..."
for s in gaspol-learn gaspol-adr gaspol-research gaspol-kb-audit gaspol-brainstorm; do
    grep -q "kb-path.md" "$SKILLS/$s/SKILL.md" \
        || fail "$s/SKILL.md does not reference _shared/kb-path.md — removing the literal path without pointing anywhere leaves the skill with no way to find the store at all"
done

# --- documentation must not SHIP the hazard it describes ---------------------
echo "test-kb-no-hardcoded-path: no doc runs git init / unguarded commit against the store..."
for d in "$REPO_ROOT/docs/kb-setup.md" "$REPO_ROOT/README.md" "$REPO_ROOT/CLAUDE.md"; do
    [ -f "$d" ] || continue
    if grep -nE '^\s*git -C "\$KB" init' "$d"; then
        fail "$(basename "$d") instructs 'git init' on the store — with kb_local pointing into a vault that creates a repository inside it"
    fi
    if grep -nE '^\s*git -C "\$KB" (add|commit|push)' "$d" >/dev/null; then
        grep -qF 'rev-parse --show-toplevel' "$d" \
            || fail "$(basename "$d") runs a write-side git command against the store with NO ownership guard — the skills link to this file as the authority"
    fi
    if grep -nE 'mkdir -p "\$KB"/\{' "$d" >/dev/null; then
        fail "$(basename "$d") recreates the category directories abolished in v1.18"
    fi
done

echo "PASS: test-kb-no-hardcoded-path"
