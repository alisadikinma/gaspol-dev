#!/usr/bin/env bash
# test-graphify-lane.sh — keep the code index current from the existing slot (IDS-8 Phase F)
#
# Two brains go stale the same way. The WHY brain (vault) is fed by Phase C; the
# HOW brain (graphify / CodeGraph) is refreshed here. gaspol-sync-docs already
# owns "update the documentation after code changed", and gaspol-finish already
# calls it at Step 5, so this adds no new gate.
#
# Detection carries NO configuration: a graphify-out/ directory at the project
# root IS the opt-in, created deliberately by whoever ran the indexer. Nothing is
# written into a repository that does not already have one.
#
# The asymmetry with the vault suggestion is deliberate and asserted below: this
# repo knows ui-ux-pro-max's exact install command and can point at it, but it
# does NOT know how graphify is installed — that is the owner's own tooling. A
# fabricated install command is worse than saying nothing, so the absent case
# names what is missing and what it would buy, and invents no command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
S="$REPO_ROOT/skills/gaspol-sync-docs/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-graphify-lane: a refusal is recorded as not-updated, never as updated..."
# Found by RUNNING the lane on this repo, not by reading it: graphify exited after
# refusing to overwrite a larger existing graph ("new graph has 1792 nodes but
# existing graph.json has 2132"). CLI present, marker present, command returned --
# everything looks like a pass except the outcome, which is the exact shape
# gaspol-finish forbids for an unavailable /security-review.
#
# Both assertions read WHITESPACE-NORMALISED text. Two earlier drafts were wrong
# in instructive ways: a line-scoped grep lost to the sentence WRAPPING across two
# source lines, and a paragraph-scoped replacement passed a VERIFIED sabotage,
# because the states table happens to contain both "--force" and a "never" and so
# satisfied a mere co-occurrence. Co-occurrence in a block is not a claim.
python3 - "$S" <<'PYEOF' || fail "gaspol-sync-docs is missing one of the two graphify-refusal claims — a refusal recorded as an update is a completion claim for work that did not happen, and reaching for --force to make the line green overwrites an index that may be more complete than its replacement"
import sys
text = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
need = [
    "graphify: not updated",
    "Never pass `--force` to make the line look green",
]
missing = [n for n in need if n not in text]
if missing:
    for m in missing:
        print(f"  missing claim: {m}", file=sys.stderr)
    sys.exit(1)
PYEOF


echo "test-graphify-lane: the lane exists..."
grep -qi 'graphify' "$S" || fail "gaspol-sync-docs never mentions graphify — the code index goes stale on every branch and nothing in the chain refreshes it"

echo "test-graphify-lane: three states, kept distinct..."
grep -qF 'graphify: updated' "$S" || fail "no exact record string for a successful refresh"
grep -qF 'graphify: UNKNOWN' "$S" || fail "the index-present-but-CLI-missing state is missing — it must STOP and ask, never pass silently, because a stale index that reports clean is worse than an absent one"
grep -qiE 'no .{0,15}graphify-out|graphify-out.{0,20}(absent|missing)|without .{0,15}graphify-out' "$S" \
    || fail "the no-index state is not described — it must be skipped, and skipping must be distinguishable from having run"
grep -qiE 'not a failure|never a failure' "$S" \
    || fail "the no-index state must be stated as NOT a failure; a repo without an index simply opted out"

echo "test-graphify-lane: detection is by marker + CLI, both required..."
grep -qiE 'graphify-out' "$S" || fail "the marker directory is not named"
grep -qiE 'PATH|installed|available' "$S" \
    || fail "the CLI presence check is not described — a marker proves the project TYPE, never that the tool is installed (KB: marker-file-is-not-proof-tool-installed)"

echo "test-graphify-lane: the federated refresh is OFFERED, never automatic..."
grep -qF 'graphify global add' "$S" || fail "the cross-project refresh is not mentioned"
grep -qF 'AskUserQuestion' "$S" \
    || fail "the global refresh writes OUTSIDE the repository (~/.graphify) and must be offered, not taken — the same boundary extract-design-tokens respects"
if grep -inE 'automatically run .{0,30}graphify global|graphify global add.{0,40}automatic' "$S" \
     | grep -qivE 'never|not |must not'; then
    fail "the global refresh is described as automatic somewhere — it crosses out of the repository and needs a decision"
fi

echo "test-graphify-lane: no fabricated install command..."
if grep -inE '(npm i|npm install|brew install|pip install|cargo install|curl .{0,40}\| ?sh).{0,30}graphify' "$S"; then
    fail "an install command for graphify was invented — this repo does not know how the owner's own tooling is installed, and a wrong command is worse than none"
fi

echo "test-graphify-lane: a skipped lane is never recorded as passed..."
if grep -inE 'record[a-z]* .{0,40}as passed|graphify: (passed|ok)' "$S" \
     | grep -qivE 'never|not |must not|prohibit'; then
    fail "gaspol-sync-docs contains an UNNEGATED instruction recording the graphify lane as passed — a lane that did not run must never be recorded as passing"
fi

echo "PASS: test-graphify-lane"
