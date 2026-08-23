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
#
# FIVE, not the one the plan first specified (IDS-8, review round). The two
# resolver files spell the default path because that is their job; the three
# documentation files EXPLAIN it, and are separately gated below — a doc may name
# the path in prose but may not carry runnable bash that uses it. The widening is
# recorded here and in the plan rather than left to be discovered, because "an
# exemption added to keep a gate usable becomes the way through it" is this
# ticket's own recurring failure and an undocumented allow-list is its first step.
ALLOWED_SET="_shared/kb-path.md _shared/kb-root docs/kb-setup.md CLAUDE.md README.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-no-hardcoded-path: every resolver invocation goes through the plugin root..."
# /security-review, IDS-8: an agent runs a SKILL.md bash block with the TARGET
# PROJECT as its working directory, so `$(skills/_shared/kb-root)` executes
# whatever a repo carrying that path happens to ship -- and the script's stdout
# becomes the path gaspol runs `git commit`/`git push` against. A missing file
# fails safe (127, and every caller's `case *)` stops); a PRESENT one that is not
# ours does not, and skill repositories are exactly the repos gaspol users open.
# LINE-START ANCHORED, like the `git add .` gate. The first version matched the
# string anywhere and immediately flagged CLAUDE.md's own prose DESCRIBING the
# hazard -- and it did so in the commit that introduced it, which is the fifth
# time on this branch that a gate's fix tripped over prose. A line that RUNS is an
# assignment starting the line; prose wraps the same text in backticks
# mid-sentence. Shape, not exemption.
# WIDENED in IDS-18. The gate knew only kb-root, so the two newest scripts --
# whose stdout is likewise read back and acted on -- were outside it. IDS-8
# recorded that anchoring one call site is not what closes the surface; widening
# the gate is. spec-pointer's stdout becomes a path plan-verifier then reads.
ANCHORED_SCRIPTS='skills/(_shared/kb-root|gaspol-verify/scripts/(spec-pointer|blast-radius-diff))'
UNANCHORED="$(grep -rnE "^[[:space:]]*[A-Za-z_][A-Za-z_0-9]*=\"[\$][(]\"?$ANCHORED_SCRIPTS" \
        "$REPO_ROOT"/skills "$REPO_ROOT/agents" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" "$REPO_ROOT/CLAUDE.md" 2>/dev/null || true)"
[ -z "$UNANCHORED" ] || { echo "$UNANCHORED" >&2; fail "a resolver invocation uses a relative path — prefix it with \"\$CLAUDE_PLUGIN_ROOT/\", the same anchor hooks/hooks.json already uses"; }

# Positive control: the scan must be able to SEE invocations at all.
# Counts ALL THREE anchored scripts, not kb-root alone. IDS-18 widened the
# UNANCHORED regex above; a control that still watched only kb-root would keep
# passing while the newly added half of that regex was broken, which is exactly
# the vacuous green this control exists to prevent. 17 present at IDS-18.
ANCHORED=$(grep -rhoE 'CLAUDE_PLUGIN_ROOT[^"]*/'"$ANCHORED_SCRIPTS" \
        "$REPO_ROOT"/skills "$REPO_ROOT/agents" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null | wc -l | tr -d ' ')
[ "${ANCHORED:-0}" -ge 15 ] \
    || fail "the scan found only ${ANCHORED:-0} anchored invocation(s), expected at least 15 — it is broken, so a clean result proves nothing"
# And each script must be seen individually: a combined count stays healthy on
# kb-root's eight alone while both new patterns match nothing.
for s in _shared/kb-root gaspol-verify/scripts/spec-pointer gaspol-verify/scripts/blast-radius-diff; do
    n=$(grep -rhoE "CLAUDE_PLUGIN_ROOT[^\"]*/skills/$s" \
            "$REPO_ROOT"/skills "$REPO_ROOT/agents" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "${n:-0}" -ge 1 ] \
        || fail "the scan sees zero anchored invocations of $s — that half of the widened gate is dead, so its clean result proves nothing"
done

echo "test-kb-no-hardcoded-path: positive control — the search works..."
# Grep a term that is true BEFORE and AFTER this phase. An earlier draft
# controlled on "kb-path.md", which only exists once the fix lands — a control
# that depends on the fix cannot prove the search worked while it was red.
CONTROL=$(grep -rl "gaspol" $SCAN_PATHS 2>/dev/null | wc -l | tr -d ' ')
[ "$CONTROL" -gt 5 ] \
    || fail "positive control matched only $CONTROL file(s) under skills/ — the recursive search is broken, so a clean result below would prove nothing"

echo "test-kb-no-hardcoded-path: allow-list holds exactly five files — 2 resolver + 3 docs..."
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
for s in gaspol-learn gaspol-adr gaspol-research gaspol-brainstorm; do
    grep -q "kb-path.md" "$SKILLS/$s/SKILL.md" \
        || fail "$s/SKILL.md does not reference _shared/kb-path.md — removing the literal path without pointing anywhere leaves the skill with no way to find the store at all"
done

# --- documentation must not SHIP the hazard it describes ---------------------
# TWO checks, deliberately, because they need different scopes and trading one
# for the other has now cost a regression twice:
#
#   * four hazards are unconditional — they are wrong wherever they appear, so
#     they stay on FILE-WIDE greps and cannot be hidden in an exotic fence.
#     Round 3 caught them escaping into ```console and ~~~bash after a block
#     parser replaced the greps.
#   * one hazard is contextual — a write-side git command is fine WITH the guard
#     beside it — so it needs BLOCK scope. A file-wide grep for the guard phrase
#     was defeated by moving the phrase into a prose sentence.
echo "test-kb-no-hardcoded-path: unconditional hazards, fence-independent..."
for d in "$REPO_ROOT/docs/kb-setup.md" "$REPO_ROOT/README.md" "$REPO_ROOT/CLAUDE.md"; do
    [ -f "$d" ] || continue
    n=$(basename "$d")
    grep -qE 'git -C "\$KB" init'   "$d" && fail "$n instructs 'git init' on the store — with kb_local pointing into a vault that creates a repository inside it"
    grep -qE 'mkdir -p "\$KB"/\{'   "$d" && fail "$n recreates the category directories abolished in v1.18"
    grep -qE 'GASPOL_KB_LOCAL:-'    "$d" && fail "$n inlines the two-rung resolver — it skips the config rung, the only durable way to relocate the store"
    grep -qE '> *"\$KB/INDEX[.]md"' "$d" && fail "$n writes an INDEX.md gaspol does not maintain"
    # Indented (4-space) code blocks are not fenced, so the block parser below
    # never sees them. One grep covers them; the reviewer was willing to accept
    # this gap, but a line is cheaper than a named risk.
    grep -qE '^ {4,}git -C "\$KB" (add|commit|push)' "$d" \
        && fail "$n runs write-side git in an INDENTED block — the block parser only sees fenced code, so no ownership guard can be required there"
done

echo "test-kb-no-hardcoded-path: write-side git needs the guard IN THE SAME BLOCK..."
python3 - "$REPO_ROOT" <<'PYEOF' || fail "a documentation code block runs write-side git with no ownership guard beside it"
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
# Every fence flavour, plus tilde fences. A parser that only knows ```bash is a
# parser an exotic fence walks straight past.
FENCE = re.compile(r"(?:```|~~~)[a-zA-Z]*\n(.*?)(?:```|~~~)", re.S)
bad = []
for rel in ["docs/kb-setup.md", "README.md", "CLAUDE.md"]:
    f = root / rel
    if not f.is_file():
        continue
    for block in FENCE.findall(f.read_text(encoding="utf-8")):
        if re.search(r'git -C "\$KB" (add|commit|push)', block):
            if not (re.search(r"rev-parse --show-toplevel", block)
                    and "kb-sync: skipped" in block
                    and re.search(r"^\s*else\s*$", block, re.M)):
                bad.append((rel, "write-side git with no guard in the same block"))
for rel, why in bad:
    print(f"    {rel}: {why}", file=sys.stderr)
sys.exit(1 if bad else 0)
PYEOF

echo "PASS: test-kb-no-hardcoded-path"
