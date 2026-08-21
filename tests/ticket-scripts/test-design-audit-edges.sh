#!/usr/bin/env bash
# test-design-audit-edges.sh — the five defects the Tier 1 review found (IDS-7)
#
# All five were reproduced before being fixed. Each is the same shape as the
# defects this ticket exists to close: the tool reports a clean-looking number
# for a case it never actually handled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/skills/gaspol-verify/scripts"
AUDIT="$AUDIT_DIR/design_audit.py"

TMP_DIR="$(mktemp -d)"; trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
fail() { echo "FAIL: $*" >&2; exit 1; }

# --- C1: project_root is a SUBDIRECTORY of the git repo ---------------------
# git diff --name-only returns paths relative to the REPO ROOT regardless of
# -C, so joining them onto a subdirectory doubles the prefix and every path
# vanishes via is_file(). Silently zero files scanned: not a gate that always
# fails (defect D3) but a gate that always PASSES, on any monorepo.

echo "test-design-audit-edges: C1 monorepo subdirectory..."
R="$TMP_DIR/mono"; mkdir -p "$R/apps/web/src"
git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
printf 'x\n' >"$R/README"; git -C "$R" add -A; git -C "$R" commit -qm base
B="$(git -C "$R" rev-parse HEAD)"
printf '<div className="bg-[#123456]">x</div>\n' >"$R/apps/web/src/A.tsx"
git -C "$R" add -A; git -C "$R" commit -qm branch

# design_audit exits 1 on a non-compliant verdict, so `|| echo ERR` would fire
# on a perfectly good run. Capture stdout, ignore the gate's own exit code.
set +e
RAW="$(python3 "$AUDIT" "$R/apps/web" --changed-files "$B" --json 2>/dev/null)"
set -e
N="$(printf '%s' "$RAW" | python3 -c "import json,sys;print(len(json.load(sys.stdin)['findings']))" 2>/dev/null || echo ERR)"
[ "$N" = "1" ] \
    || fail "scanning from a repo SUBDIRECTORY found $N changed files, expected 1 — git reports repo-relative paths, so joining them onto the subdir doubles the prefix and the gate silently passes on every monorepo"

# A file outside project_root must NOT be pulled in by the fix.
printf '.z { background: #abcdef; }\n' >"$R/other.css"
git -C "$R" add -A; git -C "$R" commit -qm other
OUT="$(python3 "$AUDIT" "$R/apps/web" --changed-files "$B" --json 2>/dev/null || true)"
echo "$OUT" | grep -q 'other.css' \
    && fail "the fix over-corrected: a changed file OUTSIDE project_root was scanned"

# --- C2: an inline # comment must not corrupt a token -----------------------

echo "test-design-audit-edges: C2 inline comment..."
C="$TMP_DIR/comment"; mkdir -p "$C"
printf -- '---\ncolors:\n  text: "#1F2937"  # ink\n  bare: #2563EB  # no quotes\n---\n' >"$C/DESIGN.md"
PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('$C')
assert c['colors']['text'] == '#1f2937', f\"inline comment corrupted the token: {c['colors']['text']!r}\"
assert c['colors']['bare'] == '#2563eb', f\"unquoted value with comment corrupted: {c['colors']['bare']!r}\"
v = d._colour_severity('color: #1F2937', '.x { color: #1F2937; }', c)
assert v is None, f'the contract\'s OWN declared token was reported {v} — a false BLOCKING on correct code'
" || fail "C2: inline comment handling"

# --- I1: a purely generic font stack claims no brand font -------------------

echo "test-design-audit-edges: I1 generic-only font..."
F="$TMP_DIR/fonts"; mkdir -p "$F"
printf -- '---\ncolors:\n  p: "#2563eb"\nfonts:\n  body: "Inter"\n---\n' >"$F/DESIGN.md"
PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('$F')
for v in ['inherit', 'unset', 'sans-serif', 'initial']:
    s = d._font_severity('.x { font-family: %s; }' % v, c)
    assert s is None, f'font-family: {v} was reported {s} — it makes no brand-font claim at all, and inherit is idiomatic in a CSS reset'
assert d._font_severity('.x { font-family: Comic Sans; }', c) == 'BLOCKING'
assert d._font_severity('.x { font-family: Inter, sans-serif; }', c) is None
" || fail "I1: generic-only font classification"

# --- I2: border/outline SHORTHAND carries the colour ------------------------
# `border: 1px solid #999` is the standard syntax and was invisible, so the
# blocking verdict the whole feature rests on missed the commonest form.

echo "test-design-audit-edges: I2 shorthand..."
S="$TMP_DIR/shorthand"; mkdir -p "$S"
printf -- '---\ncolors:\n  ok: "#2563eb"\n---\n' >"$S/DESIGN.md"
for css in "border: 1px solid #999999;" "outline: 2px solid #999999;" "border-bottom: 1px dashed #999999;"; do
    printf '.x { %s }\n' "$css" >"$S/t.css"
    N="$(cd "$S" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('.')
f = d.scan_file(__import__('pathlib').Path('t.css'), c)
print(len(f['hardcoded_colors']), f['hardcoded_colors'][0]['severity'] if f['hardcoded_colors'] else '')
")"
    echo "$N" | grep -q '^1 BLOCKING' \
        || fail "'$css' produced [$N], expected exactly 1 BLOCKING — shorthand is the commonest border syntax and was invisible to the gate"
done
# An in-contract colour in shorthand stays silent, and nothing double-counts.
printf '.x { border: 1px solid #2563EB; }\n' >"$S/t.css"
N="$(cd "$S" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d, pathlib
print(len(d.scan_file(pathlib.Path('t.css'), d.load_design_contract('.'))['hardcoded_colors']))")"
[ "$N" = "0" ] || fail "an in-contract colour in shorthand produced $N findings, expected 0"
printf '.x { border-color: #999999; }\n' >"$S/t.css"
N="$(cd "$S" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d, pathlib
print(len(d.scan_file(pathlib.Path('t.css'), d.load_design_contract('.'))['hardcoded_colors']))")"
[ "$N" = "1" ] || fail "border-color: #999999 produced $N findings, expected exactly 1 — the new shorthand pattern is double-counting with the existing one"

# --- I3: an 8-digit hex must not be graded as if opaque ---------------------

echo "test-design-audit-edges: I3 alpha in contrast..."
A8="$TMP_DIR/alpha"; mkdir -p "$A8"
printf -- '---\ncolors:\n  text: "#00000010"\n  surface: "#ffffff"\n---\n' >"$A8/DESIGN.md"
OUT="$(PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
for f in d.check_contract_contrast(d.load_design_contract('$A8')):
    print(f['severity'], f['message'])
")"
echo "$OUT" | grep -qi 'alpha\|not graded\|translucen' \
    || fail "a token with alpha (#00000010) was graded as if opaque — 6% black on white reported 21:1, a number with no relation to what renders. Got: $OUT"

# --- A4: contrast has the same inference-from-absence hole font_gate closed ---
# check_contract_contrast returned [] for "no contract" AND for "every pair
# passes". Round 3 was ruled BLOCKING for exactly this shape on fonts. Same
# defect, one key over.

echo "test-design-audit-edges: A4 contrast_gate..."
for state in nocontract nopair clean fail; do
    G="$TMP_DIR/cg-$state"; mkdir -p "$G/src"; printf '.x{color:#123456;}\n' >"$G/src/a.css"
    case $state in
        nocontract) : ;;
        nopair)  printf -- '---\ncolors:\n  brand: "#2563eb"\n---\n' >"$G/DESIGN.md";;
        clean)   printf -- '---\ncolors:\n  text: "#000000"\n  surface: "#ffffff"\n---\n' >"$G/DESIGN.md";;
        fail)    printf -- '---\ncolors:\n  text: "#777777"\n  surface: "#ffffff"\n---\n' >"$G/DESIGN.md";;
    esac
    set +e; J="$(cd "$G" && python3 "$AUDIT" . --json 2>/dev/null)"; set -e
    echo "$J" | grep -q '"contrast_gate"' \
        || fail "state '$state': --json carries no contrast_gate key — an empty contrast list means both 'not run' and 'all clean', which is the hole font_gate was added to close"
done
# The four states must not all read the same.
DISTINCT="$(for state in nocontract nopair clean fail; do
    G="$TMP_DIR/cg-$state"
    set +e; (cd "$G" && python3 "$AUDIT" . --json 2>/dev/null) | python3 -c "import json,sys;print(json.load(sys.stdin)['contrast_gate'])" 2>/dev/null; set -e
done | sort -u | wc -l | tr -d ' ')"
[ "$DISTINCT" -ge 3 ] \
    || fail "contrast_gate has only $DISTINCT distinct values across 4 states — it cannot distinguish not-run from clean"

# --- A5: an off-contract colour in rgb() must not block when its hex twin is
#         declared. Comparison was hex-only, so the SAME colour written rgb()
#         blocked the branch — a false-alarm source, and false alarms get the
#         gate switched off.

echo "test-design-audit-edges: A5 rgb() notation..."
RGB="$TMP_DIR/rgb"; mkdir -p "$RGB"
printf -- '---\ncolors:\n  primary: "#2563eb"\n---\n' >"$RGB/DESIGN.md"
PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('$RGB')
v = d._colour_severity('color: rgb(', '.b { color: rgb(37, 99, 235); }', c)
assert v is None, f'rgb(37,99,235) is #2563eb, which IS in the contract, but was reported {v}'
v2 = d._colour_severity('color: rgb(', '.b { color: rgb(1, 2, 3); }', c)
assert v2 == 'BLOCKING', f'an off-contract rgb() must still block, got {v2}'
" || fail "A5: rgb() notation is not normalised before comparison"

# --- A6: rgba(...,0) is fully transparent and must WARN like any alpha -------

echo "test-design-audit-edges: A6 zero alpha..."
PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d
c = d.load_design_contract('$RGB')
v = d._colour_severity('color: rgba(', '.b { color: rgba(0, 0, 0, 0); }', c)
assert v == 'WARN', f'rgba(0,0,0,0) is fully transparent — docs say anything with alpha WARNs, got {v}'
" || fail "A6: integer-zero alpha not treated as translucent"

# --- A7: two distinct violations on ONE line are two findings ---------------
# The dedupe key was (line, literal), so two separate selectors sharing a line
# and a colour collapsed into one. Root cause runs deeper: _declaration_at used
# line.find(match), which always returns the FIRST occurrence — so the second
# declaration was also CLASSIFIED using the first one's scope.

echo "test-design-audit-edges: A7 two violations, one line..."
DUP="$TMP_DIR/dup"; mkdir -p "$DUP"
printf -- '---\ncolors:\n  ok: "#2563eb"\n---\n' >"$DUP/DESIGN.md"
printf '.x { border: 1px solid #999999; } .y { border: 1px solid #999999; }\n' >"$DUP/t.css"
N="$(cd "$DUP" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d, pathlib
print(len(d.scan_file(pathlib.Path('t.css'), d.load_design_contract('.'))['hardcoded_colors']))")"
[ "$N" = "2" ] || fail "two separate declarations sharing a line and a colour reported $N finding(s), expected 2 — the dedupe key collapses distinct violations"

# ...while ONE declaration matched by two overlapping patterns is still ONE.
printf '.x { border-color: #999999; }\n' >"$DUP/t.css"
N="$(cd "$DUP" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d, pathlib
print(len(d.scan_file(pathlib.Path('t.css'), d.load_design_contract('.'))['hardcoded_colors']))")"
[ "$N" = "1" ] || fail "one declaration matched by two patterns reported $N findings, expected 1 — the new key lost the overlap dedupe"

# The SECOND declaration must be classified on its OWN scope, not the first's.
printf '.x { box-shadow: 0 0 2px #999999; } .y { background: #999999; }\n' >"$DUP/t.css"
OUT="$(cd "$DUP" && PYTHONPATH="$AUDIT_DIR" python3 -c "
import design_audit as d, pathlib
for i in d.scan_file(pathlib.Path('t.css'), d.load_design_contract('.'))['hardcoded_colors']:
    print(i['severity'], i['match'])")"
echo "$OUT" | grep -q 'BLOCKING.*background' \
    || fail "the structural declaration was classified using the decorative one's scope — line.find() returns the FIRST occurrence. Got: $OUT"

echo "PASS: test-design-audit-edges"
