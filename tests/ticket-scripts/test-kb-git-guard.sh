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

echo "test-kb-git-guard: the guard is documented in the shared resolver..."
grep -qF 'rev-parse --show-toplevel' "$KBPATH" \
    || fail "no skill checks git rev-parse --show-toplevel before committing the KB — pointed at a vault, gaspol would commit the owner's entire second brain"
grep -qF 'kb-sync: skipped' "$KBPATH" \
    || fail "the refusal has no exact record string — a silent skip is indistinguishable from a sync that ran"

echo "test-kb-git-guard: reads stay allowed when the guard fires..."
grep -qiE 'read[s]? (stay|remain)|reading (is|stays)' "$KBPATH" \
    || fail "the guard does not say reads stay allowed — refusing reads too would silently disable precedent lookup, which is the capability this ticket is trying to strengthen"

echo "test-kb-git-guard: every syncing skill references the guard..."
for s in gaspol-learn gaspol-adr gaspol-research; do
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
