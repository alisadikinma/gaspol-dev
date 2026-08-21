#!/usr/bin/env bash
# test-kb-state4-continues.sh — the SKILL.md bash is RUN, not read (IDS-8, review round)
#
# Tier 0 review found the defect this file exists to prevent: all three KB skills
# embedded
#
#     KB="$(skills/_shared/kb-root)" || { echo ...; exit 1; }
#
# whose own inline comment named three states while the code had two. Exit 4
# ("nothing configured") is the FIRST RUN of the plugin on any fresh machine, and
# it aborted the capture — contradicting kb-root's docstring, docs/kb-setup.md's
# auto-init block, and gaspol-learn's own Red Flags row in the same commit.
#
# It survived because every existing test exercised kb-root STANDALONE. The
# resolver was right; its three callers were wrong. So this test extracts the
# fenced bash out of the SKILL.md files and EXECUTES it under an isolated HOME.
# Text assertions cannot catch a control-flow bug.
#
# READ THIS BEFORE EDITING A KB BLOCK: in this repository a fenced ```bash block
# in a SKILL.md is not documentation, it is the instruction an agent runs -- and
# this test runs it too. So a pull request that "only touches markdown" is a pull
# request that changes code the suite executes on a maintainer's machine. The
# extractor is anchored on the block's FIRST line and asserts exactly one match,
# so it cannot be silently pointed at a different block; it cannot make the block
# itself safe, and nothing can. Review these blocks as code.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

SKILLS=(gaspol-learn gaspol-adr gaspol-research)
# learn and adr WRITE, so state 4 must auto-init the default store and capture
# locally. research only READS, so it reports and continues without creating an
# empty directory nobody asked for. Plain case, not `declare -A`: the macOS
# system bash is 3.2 and has no associative arrays, and a test that only runs on
# the author's machine is not a gate.
must_create() { case "$1" in gaspol-learn|gaspol-adr) echo yes ;; *) echo no ;; esac; }

# The ONE fenced bash block whose FIRST line assigns from the resolver. Anchored
# on that opening line rather than on "contains kb-root anywhere", because this
# function EXECUTES what it returns: a substring match would run any block that
# merely mentions the resolver in a comment, so a PR that only edits prose would
# become code the suite runs. Anchoring means the author has to change the
# block's first line -- a line a reviewer reads as code -- to redirect it.
extract() {
    awk '/^```bash$/{inb=1;first=1;buf="";next}
         /^```$/{if(inb&&hit)print buf; inb=0; hit=0; next}
         inb{if(first){hit=($0 ~ /^KB="\$\(.*kb-root/); first=0}; buf=buf"\n"$0}' "$1"
}
count_blocks() {   # how many blocks the anchor matched, so "exactly one" is asserted, not assumed
    awk '/^```bash$/{inb=1;first=1;next}
         /^```$/{if(inb&&hit)c++; inb=0; hit=0; next}
         inb{if(first){hit=($0 ~ /^KB="\$\(.*kb-root/); first=0}}
         END{print c+0}' "$1"
}

for s in "${SKILLS[@]}"; do
    f="skills/$s/SKILL.md"
    blk="$(extract "$f")"

    # Positive control. An extractor that silently matches nothing would "prove"
    # all three skills correct while examining zero lines — this repo's own
    # vacuous-assertion-proves-nothing, and the shape that made the defect above
    # invisible for a whole ticket.
    [ -n "$blk" ] || fail "$f — extracted no bash block calling kb-root; the extractor is broken, so every verdict below would be vacuous"
    printf '%s' "$blk" | grep -q 'kb-root' \
        || fail "$f — extracted block does not call kb-root; wrong block matched"
    nb="$(count_blocks "$f")"
    [ "$nb" = "1" ] \
        || fail "$f — the anchor matched $nb blocks, expected exactly 1. This function's output is EXECUTED; an ambiguous match means the suite runs a block nobody chose"

    # ---- state 4: nothing configured, no default dir. NOT a failure. ----
    H="$(mktemp -d)"
    printf '%s\n' "$blk" > "$H/blk.sh"
    rc=0
    ( env -u GASPOL_KB_LOCAL HOME="$H" bash "$H/blk.sh" >/dev/null 2>&1 ) || rc=$?
    [ "$rc" -eq 0 ] \
        || { rm -rf "$H"; fail "$f — state 4 (nothing configured) exited $rc. That is a fresh machine's FIRST RUN; kb-root's docstring, docs/kb-setup.md and this skill's own Red Flags all say report-and-continue"; }

    if [ "$(must_create "$s")" = "yes" ]; then
        [ -d "$H/.claude/gaspol-knowledge" ] \
            || { rm -rf "$H"; fail "$f — state 4 did not auto-init \$HOME/.claude/gaspol-knowledge, so the capture had nowhere to go and was silently lost"; }
        # A bare directory, nothing else (IDS-8): no git init, no category dirs,
        # no INDEX.md. Auto-init that ships any of those reintroduces the second
        # pipeline this ticket removed.
        [ ! -e "$H/.claude/gaspol-knowledge/.git" ] \
            || { rm -rf "$H"; fail "$f — auto-init ran git init inside the store; kb_local may point inside a repo gaspol does not own"; }
        [ ! -e "$H/.claude/gaspol-knowledge/INDEX.md" ] \
            || { rm -rf "$H"; fail "$f — auto-init wrote an INDEX.md; gaspol writes no index"; }
    fi
    rm -rf "$H"

    # ---- state 3 must STILL abort. Fixing 4 must not collapse 3 into it. ----
    # An empty store reads as "no precedent exists", which is exactly when a
    # documented mistake gets repeated. This is the assertion that keeps the fix
    # above from becoming "continue on everything".
    H="$(mktemp -d)"
    printf '%s\n' "$blk" > "$H/blk.sh"
    rc=0
    ( env HOME="$H" GASPOL_KB_LOCAL="$H/definitely-not-here" bash "$H/blk.sh" >/dev/null 2>&1 ) || rc=$?
    [ "$rc" -ne 0 ] \
        || { rm -rf "$H"; fail "$f — state 3 (configured path unreadable) exited 0; a broken store must STOP and ask, never degrade to an empty one"; }
    rm -rf "$H"
done

echo "PASS: test-kb-state4-continues (3 skills; state 4 continues, state 3 still stops)"
