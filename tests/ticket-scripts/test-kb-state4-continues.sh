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

extract() {   # the ONE fenced bash block that calls the resolver
    awk '/^```bash$/{inb=1;buf="";next} /^```$/{if(inb&&buf ~ /kb-root/)print buf; inb=0; next} inb{buf=buf"\n"$0}' "$1"
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
