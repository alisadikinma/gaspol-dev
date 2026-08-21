#!/usr/bin/env bash
# test-design-diff-scope.sh — diff-scoped design audit (IDS-7 Phase B)
#
# Defect D3: scan_project(root) walked the whole tree and `grep git
# design_audit.py` returned zero hits. On any repository with existing code
# Layer 4 collected hundreds of pre-existing findings, and because Layer 4 FAILS
# below score 60 the gate failed permanently -- so it got ignored. A gate that
# always fails is indistinguishable from no gate.
#
# Defect D4 (found while implementing Phase A): is_ui_file() tested only
# UI_EXTENSIONS. STYLE_EXTENSIONS was defined and never used for scanning, so
# .css and .scss files were never audited at all -- while the docs claimed they
# were. Same defect class as the unread --design-system flag.
#
# The load-bearing assertion is the NEGATIVE one: a violation in an unchanged
# file must NOT be reported. Asserting only that changed files are found would
# pass just as well against the old whole-project scan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT="$REPO_ROOT/skills/gaspol-verify/scripts/design_audit.py"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# design_audit.py exits 1 when the verdict is non-compliant -- which is the
# whole point of a gate. Capture output without letting `set -e` abort on it.
audit() { local out rc; set +e; out="$(python3 "$AUDIT" "$@" 2>&1)"; rc=$?; set -e; printf '%s' "$out"; return $rc; }

# --- fixture repo: one violating file committed at BASE, one added after -----

REPO="$TMP_DIR/repo"
mkdir -p "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t

# Pre-existing violation. Not this branch's fault, must never be reported.
printf '<div className="bg-[#aabbcc]">legacy</div>\n' >"$REPO/src/Legacy.tsx"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m base
BASE="$(git -C "$REPO" rev-parse HEAD)"

# This branch's own violation, plus a CSS file (D4 -- never scanned before).
printf '<div className="bg-[#123456]">fresh</div>\n' >"$REPO/src/Fresh.tsx"
printf '.card { color: #ff0000; }\n' >"$REPO/src/card.css"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m branch

# --- D4: style extensions are actually scanned ------------------------------

echo "test-design-diff-scope: style extensions (D4)..."
OUT="$(audit "$REPO" --json || true)"
echo "$OUT" | grep -q 'card.css' \
    || fail "a .css file was not scanned -- STYLE_EXTENSIONS is defined but unused, so CSS was never audited despite the docs claiming it was"

# --- D3: changed-files mode reports ONLY the changed file -------------------

echo "test-design-diff-scope: diff scope (D3)..."
OUT="$(audit "$REPO" --changed-files "$BASE" --json || true)"
 echo "$OUT" | grep -q "unrecognized arguments\|invalid choice" \
    && fail "--changed-files is not supported yet"

echo "$OUT" | grep -q 'Fresh.tsx' \
    || fail "the changed file was not scanned under --changed-files"
echo "$OUT" | grep -q 'card.css' \
    || fail "the changed .css file was not scanned under --changed-files"

if echo "$OUT" | grep -q 'Legacy.tsx'; then
    fail "an UNCHANGED violating file was reported under --changed-files -- the scan is still whole-project, which is exactly defect D3"
fi

# Whole-project mode still sees it, proving the SCOPE changed and not the detection.
WHOLE="$(audit "$REPO" --json || true)"
echo "$WHOLE" | grep -q 'Legacy.tsx' \
    || fail "whole-project mode stopped finding the legacy violation -- the fix removed detection instead of narrowing scope"

# --- a bad BASE must fail loudly, never fall back to scanning everything -----

echo "test-design-diff-scope: bad BASE..."
set +e
BAD_OUT="$(python3 "$AUDIT" "$REPO" --changed-files nonexistent-sha --json 2>&1)"
rc=$?
set -e
[ "$rc" != "0" ] \
    || fail "a bad BASE exited 0 -- an unresolvable diff must fail loudly, not silently widen to the whole project"
echo "$BAD_OUT" | grep -qi 'nonexistent-sha\|git diff\|not a\|unknown revision' \
    || fail "the bad-BASE error does not say what went wrong: $BAD_OUT"

# --- a BASE that looks like a git option is rejected, not passed through ----
#
# f"{base}..HEAD" is one argv element, so a base of "--output=/tmp/x" reaches
# git as the option --output=/tmp/x..HEAD. argparse blocks the space-separated
# form, but "--changed-files=--output=..." goes straight through — so the guard
# has to live in the code, not in argparse. Not reachable from untrusted input
# today (BASE is an operator-supplied CLI flag), but it is a trust boundary and
# those do not get the lazy treatment.

echo "test-design-diff-scope: option-shaped BASE..."
set +e
OPT_OUT="$(python3 "$AUDIT" "$REPO" "--changed-files=--output=$TMP_DIR/pwned" --json 2>&1)"
rc=$?
set -e
[ "$rc" != "0" ] || fail "an option-shaped BASE was accepted — it reaches git as an option, not a revision"
[ -e "$TMP_DIR/pwned..HEAD" ] && fail "git wrote a file: the option-shaped BASE was passed through to git"
echo "$OPT_OUT" | grep -qi "revision" \
    || fail "the rejection message does not say why: $OPT_OUT"

# --- scan_project still exists: one code path, both modes -------------------

PYTHONPATH="$(dirname "$AUDIT")" python3 -c "
import design_audit as d
assert callable(d.scan_project), 'scan_project was deleted'
assert callable(d.scan_files), 'scan_files is missing'
" || fail "scan_project/scan_files contract broken"

echo "PASS: test-design-diff-scope"
