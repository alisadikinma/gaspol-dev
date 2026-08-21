#!/usr/bin/env bash
# test-kb-path-resolver.sh — one KB path resolver, three honest states (IDS-8 Phase A)
#
# Why this test exists: `kb_local` was documented in README.md, CLAUDE.md and
# docs/kb-setup.md as the way to relocate the knowledge base, and grep for it
# under skills/ returned ZERO hits. A setting that is promised and read by
# nothing is the same defect IDS-7 found in `--design-system` — the knob turns
# and nothing moves. Relocating the KB is this whole ticket, so the resolver has
# to be real before anything depends on it.
#
# The three states carry the same weight as the order. KB precedent
# `marker-file-is-not-proof-tool-installed`: a configured-but-unreadable store
# must never degrade into "nothing found", because an empty result reads as
# "no precedent exists" — and that is exactly when a known mistake gets repeated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KBPATH="$REPO_ROOT/skills/_shared/kb-path.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qiF -- "$2" "$1" || fail "$3"; }

echo "test-kb-path-resolver: file exists..."
[ -f "$KBPATH" ] \
    || fail "skills/_shared/kb-path.md does not exist — the KB skills have no single place that says where the store lives"

echo "test-kb-path-resolver: all three rungs named..."
has "$KBPATH" 'GASPOL_KB_LOCAL' \
    "the environment override GASPOL_KB_LOCAL is not named"
has "$KBPATH" 'kb_local' \
    "the config key kb_local is not named — that is the rung that was documented everywhere and read nowhere"
has "$KBPATH" 'gaspol-config.json' \
    "the config FILE is not named; the key alone does not tell a reader where to put it"
has "$KBPATH" '.claude/gaspol-knowledge' \
    "the default is not named — a resolver with no final rung is undefined for a fresh install"

# --- ORDER, not merely presence ---------------------------------------------
# A file that mentions three rungs in any order has not specified a resolution.
# Assert the config rung sits BETWEEN env and default, which is the whole fix:
# an env var alone is shell-scoped, so a durable relocation needs the file.
echo "test-kb-path-resolver: resolution order is specified, not merely listed..."
# Measure INSIDE the "## Resolution order" section. Comparing first-occurrence
# across the whole file measures prose position, not the order of the rungs —
# the file legitimately names the default earlier, in the rule forbidding other
# files from naming it.
ORDER="$(awk '/^## Resolution order/{f=1;next} /^## /{f=0} f' "$KBPATH")"
[ -n "$ORDER" ] || fail "kb-path.md has no '## Resolution order' section to read the rungs from"
env_line=$(printf '%s\n' "$ORDER" | grep -n 'GASPOL_KB_LOCAL' | head -1 | cut -d: -f1)
cfg_line=$(printf '%s\n' "$ORDER" | grep -n 'kb_local'        | head -1 | cut -d: -f1)
def_line=$(printf '%s\n' "$ORDER" | grep -n '\.claude/gaspol-knowledge' | head -1 | cut -d: -f1)
[ -n "$env_line" ] && [ -n "$cfg_line" ] && [ -n "$def_line" ] \
    || fail "could not locate all three rungs to compare their order"
[ "$env_line" -lt "$cfg_line" ] \
    || fail "GASPOL_KB_LOCAL (line $env_line) must be documented BEFORE kb_local (line $cfg_line) — the env var is the override"
[ "$cfg_line" -lt "$def_line" ] \
    || fail "kb_local (line $cfg_line) must be documented BEFORE the default (line $def_line) — otherwise the config key is decoration again"

# --- the three states -------------------------------------------------------
echo "test-kb-path-resolver: three states, kept distinct..."
grep -qF 'knowledge-store: none' "$KBPATH" \
    || fail "the no-store state has no exact record string — a silent skip is indistinguishable from a store that was read and found empty"
grep -qF 'knowledge-store: UNKNOWN' "$KBPATH" \
    || fail "the configured-but-unreadable state is missing — it must be UNKNOWN and STOP, never an empty result"
has "$KBPATH" 'not a failure' \
    "the no-store state must be stated as NOT a failure; a public plugin cannot require a vault"
has "$KBPATH" 'STOP' \
    "the UNKNOWN state must STOP and ask rather than continue with an empty store"

# --- the negative half ------------------------------------------------------
# Presence checks above prove the states are described. They cannot fail if text
# CONTRADICTING them is added later, which is the failure mode that matters.
#
# Two things this has to get right, both learned by watching it fail:
#   1. Sentence scope, not line scope. The prohibition wraps across a newline
#      ("must **never** be / treated as an empty store"), so a per-line negation
#      check flags the CORRECT text.
#   2. English puts the subject before a passive verb. An earlier version
#      required "unreadable" to sit BETWEEN "treat" and "as", so flipping the
#      sentence to "should be treated as an empty store" sailed through.
echo "test-kb-path-resolver: no unnegated instruction to treat a broken store as empty..."
python3 - "$KBPATH" <<'PYEOF' || fail "kb-path.md endorses treating an unreadable store as empty — that is exactly the silent pass the UNKNOWN state exists to prevent"
import re, sys
text = re.sub(r"\s+", " ", open(sys.argv[1], encoding="utf-8").read())
sentences = re.split(r"(?<=[.:;])\s+", text)
# Only negations that attach to the INSTRUCTION. A broad list matched
# "a store that CANNOT be read" — the subject, not a prohibition — and let an
# endorsement pass as if it were negated. Same trap as IDS-7's wig-lane draft.
NEG = re.compile(r"\bnever\b|\bmust not\b|\bshould not\b|\bis not\b|\bare not\b|rather than|instead of", re.I)
BAD = re.compile(r"treat(?:ed|s|ing)?\s+as\s+(?:an?\s+)?(?:empty|none)", re.I)
offenders = [s for s in sentences if BAD.search(s) and not NEG.search(s)]
if offenders:
    print("  offending sentence: " + offenders[0][:160], file=sys.stderr)
    sys.exit(1)
PYEOF

echo "PASS: test-kb-path-resolver"
