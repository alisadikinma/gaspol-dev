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

# --- the executable half -----------------------------------------------------
# The doc states the order; the script is what runnable bash actually calls.
# Documented-but-unexecutable is the defect class this ticket opened with.
KBROOT="$REPO_ROOT/skills/_shared/kb-root"
echo "test-kb-path-resolver: resolver script exists and is executable AS GIT RECORDS IT..."
[ -f "$KBROOT" ] || fail "skills/_shared/kb-root does not exist — the bash blocks in the KB skills would call a function that is not in scope and resolve to an empty path"
MODE="$(git -C "$REPO_ROOT" ls-files -s skills/_shared/kb-root | cut -d' ' -f1)"
[ "$MODE" = "100755" ] \
    || fail "kb-root is recorded in git as '${MODE:-<untracked>}', not 100755 — it will not be executable on checkout (IDS-6 shipped task-brief exactly this way)"

echo "test-kb-path-resolver: three states are reported by EXIT CODE, not by text..."
set +e
OUT_UNKNOWN=$(GASPOL_KB_LOCAL=/tmp/gaspol-nonexistent-$$ "$KBROOT" 2>&1); RC_UNKNOWN=$?
TMPHOME=$(mktemp -d); OUT_NONE=$(env -u GASPOL_KB_LOCAL HOME="$TMPHOME" "$KBROOT" 2>&1); RC_NONE=$?
BADHOME=$(mktemp -d); mkdir -p "$BADHOME/.claude"; printf '{not json' > "$BADHOME/.claude/gaspol-config.json"
OUT_BAD=$(env -u GASPOL_KB_LOCAL HOME="$BADHOME" "$KBROOT" 2>&1); RC_BAD=$?
GOODHOME=$(mktemp -d); mkdir -p "$GOODHOME/.claude" "$GOODHOME/store"
printf '{"kb_local": "%s/store"}' "$GOODHOME" > "$GOODHOME/.claude/gaspol-config.json"
OUT_CFG=$(env -u GASPOL_KB_LOCAL HOME="$GOODHOME" "$KBROOT" 2>/dev/null); RC_CFG=$?
set -e
rm -rf "$TMPHOME" "$BADHOME" "$GOODHOME"

[ "$RC_UNKNOWN" = "3" ] || fail "a configured-but-missing path exited $RC_UNKNOWN, expected 3 (UNKNOWN) — it must never share an exit code with 'none'"
[ "$RC_NONE" = "4" ]    || fail "an unconfigured store with no default exited $RC_NONE, expected 4 (none) — not a failure, but distinct from UNKNOWN"
[ "$RC_UNKNOWN" != "$RC_NONE" ] || fail "UNKNOWN and none share an exit code — a caller cannot tell a broken store from an absent one, which is the entire point"
[ "$RC_BAD" = "3" ]     || fail "an unparseable gaspol-config.json exited $RC_BAD, expected 3 — silently ignoring it would send every write back to the default folder"
[ "$RC_CFG" = "0" ]     || fail "a valid kb_local pointing at a real directory exited $RC_CFG, expected 0 — the config rung must actually resolve, which is the defect that opened this ticket"
case "$OUT_CFG" in */store) : ;; *) fail "kb_local resolved to '$OUT_CFG', expected the configured directory — stdout must carry the path and nothing else" ;; esac


# --- --init: state 4 creates, state 3 refuses to (IDS-8, review round) -------
# The two write skills call `kb-root --init` precisely so they never spell the
# default path themselves. If --init also swallowed state 3 it would create a
# directory over a relocation the user configured, and every later read would
# answer "no precedent exists" for a store that has precedent in it.
H4="$(mktemp -d)"
OUT="$(env -u GASPOL_KB_LOCAL HOME="$H4" "$KBROOT" --init)"; rc=$?
[ "$rc" -eq 0 ] || { rm -rf "$H4"; fail "--init on a fresh HOME exited $rc, expected 0 — this is the plugin's first run, not an error"; }
[ -d "$H4/.claude/gaspol-knowledge" ] || { rm -rf "$H4"; fail "--init exited 0 without creating the store; the capture would have nowhere to go"; }
[ "$OUT" = "$H4/.claude/gaspol-knowledge" ] || { rm -rf "$H4"; fail "--init printed '$OUT', expected the created path"; }
[ ! -e "$H4/.claude/gaspol-knowledge/.git" ] || { rm -rf "$H4"; fail "--init ran git init inside the store"; }
[ -z "$(ls -A "$H4/.claude/gaspol-knowledge")" ] || { rm -rf "$H4"; fail "--init created more than a bare directory: $(ls -A "$H4/.claude/gaspol-knowledge")"; }
rm -rf "$H4"

H3="$(mktemp -d)"
rc=0
env HOME="$H3" GASPOL_KB_LOCAL="$H3/relocated-and-gone" "$KBROOT" --init >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || { rm -rf "$H3"; fail "--init on a CONFIGURED unreadable path exited $rc, expected 3 — it must never create a store over a broken relocation"; }
[ ! -d "$H3/relocated-and-gone" ] || { rm -rf "$H3"; fail "--init created the configured-but-unreadable path; state 3 must stop, not repair"; }
rm -rf "$H3"
# A plain FILE sitting where the store belongs must stay inside the exit
# contract. An unhandled traceback here would exit 1 -- a code the three states
# do not define -- and reporting 4 ("none") for an OCCUPIED path would be the
# blurring this whole resolver exists to prevent.
HF="$(mktemp -d)"
mkdir -p "$HF/.claude"; : > "$HF/.claude/gaspol-knowledge"
rc=0
ERR="$(env -u GASPOL_KB_LOCAL HOME="$HF" "$KBROOT" --init 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 3 ] || { rm -rf "$HF"; fail "--init over a plain file exited $rc, expected 3 — 0/3/4 is the whole contract, and 1 is not one of them"; }
printf '%s' "$ERR" | grep -q "UNKNOWN" || { rm -rf "$HF"; fail "--init over a plain file did not report UNKNOWN; an occupied path is not an empty store"; }
rm -rf "$HF"

echo "test-kb-path-resolver: --init creates on state 4, refuses on state 3"

echo "PASS: test-kb-path-resolver"
