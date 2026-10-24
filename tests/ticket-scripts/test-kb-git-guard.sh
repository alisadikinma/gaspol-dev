#!/usr/bin/env bash
# test-kb-git-guard.sh — gaspol never commits a repository it does not own (IDS-8 Phase D)
#
# The KB skills run `git -C "$KB" add . && git -C "$KB" commit` and, in synced
# mode, `git push`. That was harmless while the KB was its own little repo under
# ~/.claude. The moment the store points into the owner's Obsidian vault — which
# is a git repository, and which this ticket deliberately makes the target — the
# same commands operate on the VAULT repo. gaspol would commit and push someone's
# entire second brain unasked.
#
# The hazard is currently inert: with no gaspol-config.json the mode is
# local-only and no remote exists. It arms itself the day kb_remote is set. A
# hazard that only fires later is still this change's responsibility, because by
# then nobody will remember the connection.
#
# Guard: compare the KB root against `git rev-parse --show-toplevel`. Not equal
# means the store is a GUEST inside somebody else's repository — writes are fine,
# git is not.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KBPATH="$REPO_ROOT/skills/_shared/kb-path.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-kb-git-guard: nothing stages the whole tree..."
# `git add .` inside a KB block commits every untracked file in whatever repo $KB
# turned out to be. The ownership guard cannot prevent that: it asks whether $KB
# is the repo ROOT, which is true for a dedicated KB repo AND for a vault root a
# mis-set kb_local points at. The pathspec is what bounds the blast radius.
#
# ANCHORED AT LINE START, not fence-scoped. A fence parser was written first and
# silently desynced -- a since-deleted capture skill (IDS-21) had an odd number of ``` markers, so
# its real bash block counted as OUTSIDE a block and a planted `add .` passed. A
# parser that can desync is worse than no parser, because it fails OPEN.
# Anchoring needs no state: a line that RUNS starts the line, while the prose that
# describes the hazard wraps it in backticks mid-sentence. That is a property of
# the two shapes, not an exemption carved out for one file.
BAD="$(grep -rnE '^[[:space:]]*git -C "\$KB" add \.' \
        "$REPO_ROOT"/skills/*/SKILL.md "$REPO_ROOT/skills/_shared/kb-path.md" "$REPO_ROOT/docs/kb-setup.md" 2>/dev/null || true)"
[ -z "$BAD" ] || { echo "$BAD" >&2; fail "a runnable line stages the entire tree with \`git -C \"\$KB\" add .\` — stage the note by pathspec instead"; }

# Positive control: the anchored search must be able to SEE runnable git lines.
RUNNABLE=$(grep -rcE '^[[:space:]]*git -C "\$KB" ' \
        "$REPO_ROOT"/skills/*/SKILL.md "$REPO_ROOT/skills/_shared/kb-path.md" "$REPO_ROOT/docs/kb-setup.md" 2>/dev/null \
        | awk -F: '{n+=$2} END{print n+0}')
[ "${RUNNABLE:-0}" -ge 3 ] \
    || fail "the anchored scan found only ${RUNNABLE:-0} runnable \`git -C \"\$KB\"\` line(s) — it is broken, so a clean result proves nothing"

echo "test-kb-git-guard: the guard is documented in the shared resolver..."
grep -qF 'rev-parse --show-toplevel' "$KBPATH" \
    || fail "no skill checks git rev-parse --show-toplevel before committing the KB — pointed at a vault, gaspol would commit the owner's entire second brain"
grep -qF 'kb-sync: skipped' "$KBPATH" \
    || fail "the refusal has no exact record string — a silent skip is indistinguishable from a sync that ran"

echo "test-kb-git-guard: reads stay allowed when the guard fires..."
grep -qiE 'read[s]? (stay|remain)|reading (is|stays)' "$KBPATH" \
    || fail "the guard does not say reads stay allowed — refusing reads too would silently disable precedent lookup, which is the capability this ticket is trying to strengthen"

echo "test-kb-git-guard: every syncing skill references the guard..."
# IDS-21: gaspol-adr and gaspol-research are the remaining KB writers.
for s in gaspol-adr gaspol-research; do
    f="$REPO_ROOT/skills/$s/SKILL.md"
    grep -qE 'show-toplevel|git guard|does not own' "$f" \
        || fail "$s/SKILL.md runs git against the KB but never mentions the ownership guard — the guard has to be where the git command is, not only in a file someone might read"
done

# --- the guard's PREMISE, verified live rather than assumed ------------------
echo "test-kb-git-guard: premise holds — a vault subfolder's toplevel is not itself..."
PROBE="$(mktemp -d)/repo"; mkdir -p "$PROBE/sub/store"
git -C "$PROBE" init -q 2>/dev/null || fail "could not create a probe repository"
TOP="$(git -C "$PROBE/sub/store" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$TOP" ] || fail "rev-parse returned nothing inside a repo — the guard's mechanism does not work here"
[ "$(cd "$TOP" && pwd -P)" != "$(cd "$PROBE/sub/store" && pwd -P)" ] \
    || fail "a nested directory reported itself as the repo toplevel — the comparison the guard relies on would never fire"
rm -rf "$(dirname "$PROBE")"

echo "PASS: test-kb-git-guard"
