#!/usr/bin/env bash
# test-gate-mutations.sh — the gates are themselves under test (IDS-8, round 3)
#
# WHY THIS EXISTS, in one sentence: during IDS-8 the documentation gates
# regressed TWICE while being repaired, and both times a review caught it rather
# than the suite.
#
#   round 2 — closing the INDEX.md finding added `grep -viE 'hot[.]md|30-Knowledge'`,
#             so "update INDEX.md with a new entry, then hot.md" passed, while the
#             version BEFORE that commit had caught it.
#   round 3 — replacing that with `grep -vE "read"` exempted "…for tags already
#             captured", because "already" CONTAINS "read". At the same time a
#             block parser replaced four file-wide greps, and the hazards escaped
#             into ```console and ~~~bash fences.
#
# Both were loosenings introduced BY a fix, in the gate NEXT TO the one being
# fixed. Reviewing the diff does not catch that; only running the old attacks
# does. So the attacks live here, as a table, and run on every commit.
#
# The table is the contract. Adding an exemption to any gate means adding its
# attack here first and watching it fail — an exemption with no attack beside it
# is how both regressions shipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

TARGET_SKILL="$REPO_ROOT/skills/gaspol-research/SKILL.md"
TARGET_DOC="$REPO_ROOT/docs/kb-setup.md"
BACKUP="$(mktemp -d)"
cp "$TARGET_SKILL" "$BACKUP/skill.md"
cp "$TARGET_DOC"   "$BACKUP/doc.md"
restore() { cp "$BACKUP/skill.md" "$TARGET_SKILL"; cp "$BACKUP/doc.md" "$TARGET_DOC"; }
trap 'restore; rm -rf "$BACKUP"' EXIT

# --- baseline first. Mutating a tree that is already red proves nothing -------
# An earlier sabotage round in this very ticket "confirmed" three catches against
# a file that was failing before it was touched.
echo "test-gate-mutations: green baseline..."
bash "$SCRIPT_DIR/test-kb-write-format.sh"     >/dev/null 2>&1 || fail "test-kb-write-format is already failing — every verdict below would be meaningless"
bash "$SCRIPT_DIR/test-kb-no-hardcoded-path.sh" >/dev/null 2>&1 || fail "test-kb-no-hardcoded-path is already failing — every verdict below would be meaningless"

pass=0
# plant <where> <gate> <expect: caught|allowed> <text>
plant() {
    local where="$1" gate="$2" expect="$3" text="$4"
    local file; [ "$where" = "skill" ] && file="$TARGET_SKILL" || file="$TARGET_DOC"
    printf '\n%s\n' "$text" >> "$file"
    local got="allowed"
    bash "$SCRIPT_DIR/$gate" >/dev/null 2>&1 || got="caught"
    restore
    if [ "$got" != "$expect" ]; then
        fail "$gate expected '$expect' but got '$got' for: $text"
    fi
    pass=$((pass + 1))
}

G_FMT="test-kb-write-format.sh"
G_PATH="test-kb-no-hardcoded-path.sh"

echo "test-gate-mutations: index gate — a gaspol index is a defect, read or write..."
# The distinction was never the verb. A gaspol-KB index and the vault's master
# map are BOTH read; only WHOSE index differs.
plant skill "$G_FMT" caught 'Grep INDEX.md for tag matches.'
plant skill "$G_FMT" caught 'Grep INDEX.md for tags already captured.'
plant skill "$G_FMT" caught 'Consult the KB INDEX.md; the thread may already list it.'
plant skill "$G_FMT" caught 'Grep the store INDEX.md for matching tags before you read the notes.'
plant skill "$G_FMT" caught 'The entry is read back from `INDEX.md` after being written.'
plant skill "$G_FMT" caught 'update INDEX.md with a new entry, then hot.md'
plant skill "$G_FMT" caught 'Write an INDEX.md entry for every capture (see 30-Knowledge)'
plant skill "$G_FMT" caught 'Maintain the INDEX.md master map for each capture'
plant skill "$G_FMT" caught 'Append the capture to INDEX.md.'

# PIGGYBACKS on the exemptions themselves. Round 4: the arrow-chain exemption
# fired on any line with an arrow between the two names, so a WRITE instruction
# wearing an arrow walked through. Third round running that an exemption added
# to keep a gate usable became the way past it -- a noun, then a substring, then
# an arrow. Exemptions are therefore anchored to the LITERAL shapes present in
# the tree, and every one of them has an attack row here.
plant skill "$G_FMT" caught 'Update INDEX.md -> then also refresh hot.md after each capture.'
plant skill "$G_FMT" caught 'Write INDEX.md -> hot.md'
plant skill "$G_FMT" caught 'Regenerate INDEX.md → then hot.md'
plant skill "$G_FMT" caught 'gaspol no longer writes plans, so update INDEX.md after each capture.'
plant skill "$G_FMT" caught 'Index caveat aside, update INDEX.md on every capture.'
plant skill "$G_FMT" caught 'There is no index for plans, so maintain INDEX.md.'

# The exemption STRING itself, worn by a write. Round 4 added piggyback rows
# that used neither backticks nor parens, so they never exercised the exemption
# they shipped beside — the same gap that let round 3's fence narrowing pass an
# earlier version of this table. An attack row must wear the exemption verbatim.
plant skill "$G_FMT" caught 'Maintain `INDEX.md` (master map) on every capture.'
plant skill "$G_FMT" caught 'Grep `INDEX.md` (master map) for tag matches.'
plant skill "$G_FMT" caught 'Regenerate `INDEX.md` (master map) after each capture.'
plant skill "$G_FMT" caught 'Rebuild `INDEX.md` -> `hot.md` after every capture.'

# THE ACCEPTED FLOOR, recorded as `allowed` rather than left latent. A write verb
# wearing the complete read-order shape gets through, and Tier 0 review
# demonstrated it. Requiring a third arrow was tried and rejected: the real
# brainstorm line WRAPS, so grep sees two arrows on it and the tightening turned a
# legitimate line red. Four rounds of alternative signals (noun, substring, arrow,
# literal) each traded this narrow floor for a wider hole.
#
# These rows expect `allowed` because that is the truth. Their job is that the
# next person tightening this regex sees the limit in the table instead of
# rediscovering it, and that a future fix which DOES close it flips these two rows
# deliberately rather than by accident.
plant skill "$G_FMT" allowed 'Update `INDEX.md` -> `hot.md` -> `30-Knowledge/` after every capture.'
plant skill "$G_FMT" allowed 'Rebuild `INDEX.md` (master map) → `hot.md` → `30-Knowledge/` on capture.'

echo "test-gate-mutations: index gate — the two legitimate shapes still pass..."
plant skill "$G_FMT" allowed 'Read the vault: `INDEX.md` (master map) → `hot.md` (recent) → `30-Knowledge/`'
plant skill "$G_FMT" allowed 'gaspol writes no index — there is no INDEX.md to update.'

echo "test-gate-mutations: resolver-anchor gate — runnable vs prose..."
# The plugin-root anchor gate, both directions. Its first version matched the
# string anywhere and flagged CLAUDE.md's own prose about the hazard; the fix must
# not be a text exemption, so these rows pin the SHAPE distinction instead.
plant skill "$G_PATH" caught 'KB="$(skills/_shared/kb-root)" || exit 1'
plant skill "$G_PATH" caught '  KB="$(skills/_shared/kb-root --init)"; rc=$?'
plant skill "$G_PATH" allowed 'An agent would otherwise run `$(skills/_shared/kb-root)` from the open repo.'

echo "test-gate-mutations: status gate..."
plant skill "$G_FMT" caught 'status: accepted'

echo "test-gate-mutations: unconditional doc hazards, in every fence flavour..."
# Fence-independence is the property round 3 lost. Each hazard is wrong wherever
# it appears, so none of these may depend on the fence being ```bash.
for fence in '```bash' '```sh' '```shell' '```console' '```' '~~~bash'; do
    close='```'; [ "$fence" = '~~~bash' ] && close='~~~'
    plant doc "$G_PATH" caught "$fence
git -C \"\$KB\" init -q
$close"
    plant doc "$G_PATH" caught "$fence
mkdir -p \"\$KB\"/{ui-patterns,architecture}
$close"
    plant doc "$G_PATH" caught "$fence
KB=\"\${GASPOL_KB_LOCAL:-\$HOME/.claude/gaspol-knowledge}\"
$close"
done

echo "test-gate-mutations: contextual hazard — write-side git needs the guard beside it..."
plant doc "$G_PATH" caught '```bash
git -C "$KB" add . && git -C "$KB" commit -q -m "x"
```'
# The round-2 survivor: guard deleted from the block, phrase parked in prose.
plant doc "$G_PATH" caught '```bash
git -C "$KB" add . && git -C "$KB" commit -q -m "x"
```

See the ownership guard, which uses `git rev-parse --show-toplevel` and records `kb-sync: skipped`.'
# Split across two blocks — the guard must be in the SAME block.
plant doc "$G_PATH" caught '```bash
TOP="$(git -C "$KB" rev-parse --show-toplevel)"
echo "kb-sync: skipped"
else
```

```bash
git -C "$KB" add . && git -C "$KB" commit -q -m "x"
```'
# The CONTEXTUAL check needs fence-independence too. Without these rows,
# narrowing the fence regex back to bash-only passes the harness -- verified:
# it did, which is exactly why they are here.
for f in '```shell' '```console' '```zsh' '~~~bash'; do
    c='```'; [ "$f" = '~~~bash' ] && c='~~~'
    plant doc "$G_PATH" caught "$f
git -C \"\$KB\" add . && git -C \"\$KB\" commit -q -m \"x\"
$c"
done

# A correctly guarded block must NOT be flagged, or the gate is unusable.
plant doc "$G_PATH" allowed '```bash
TOP="$(git -C "$KB" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" != "$(cd "$KB" && pwd -P)" ]; then
  echo "kb-sync: skipped — KB lives inside a repo gaspol does not own ($TOP)"
else
  git -C "$KB" add . && git -C "$KB" commit -q -m "x"
fi
```'

# The table defends its own size. Flipping an expectation already fails, but
# DELETING rows did not — the harness passed with nine index attacks removed.
# A gate whose attack table can be quietly trimmed is a gate that can be quietly
# loosened, which is the whole failure mode this file exists for.
MIN_ROWS=53
[ "$pass" -ge "$MIN_ROWS" ] \
    || fail "only $pass mutations ran, expected at least $MIN_ROWS — attack rows were removed. Raise MIN_ROWS deliberately when adding rows; never lower it to make a run pass."

echo "PASS: test-gate-mutations ($pass mutations, all verdicts as expected)"
