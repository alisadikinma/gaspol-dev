#!/usr/bin/env bash
# IDS-21 Phase B: every end-of-ticket gate has ONE owner, gaspol-finish.
# gaspol-execute Step 7 and gaspol-auto post-run hand off; they do not run
# gaspol-verify / plan-verifier / gaspol-review / gaspol-sync-docs themselves.
# Sections are captured into variables first (pipefail-safe), then grepped.
set -euo pipefail
cd "$(dirname "$0")/../.."

fails=0
fail() { echo "FAIL: $1"; fails=$((fails+1)); }
has()  { printf '%s' "$2" | grep -qF -- "$1"; }
# Paragraphs (blank-line separated) that name $1 but do not name gaspol-finish.
unowned() {
  printf '%s\n' "$2" | awk -v n="$1" 'BEGIN{RS="";ORS="\n"} index($0,n) && !index($0,"gaspol-finish")'
}

EXEC=skills/gaspol-execute/SKILL.md
AUTO=skills/gaspol-auto/SKILL.md
FIN=skills/gaspol-finish/SKILL.md

# (a) execute Step 7 (Execution Flow copy, not the Pre-Execution baseline step)
step7=$(awk '/^### Step 7: (Auto-Invoke|Hand Off)/{f=1;next} /^### Step 8/{f=0} f' "$EXEC")
[ -n "$step7" ] || fail "gaspol-execute has no Execution Flow Step 7 section"
for n in plan-verifier gaspol-verify gaspol-review gaspol-sync-docs; do
  # A mention is allowed only in a paragraph that also names gaspol-finish as owner.
  bad=$(unowned "$n" "$step7")
  if [ -n "$bad" ]; then
    case "$n" in
      plan-verifier) fail "gaspol-execute Step 7 still dispatches plan-verifier" ;;
      *) fail "gaspol-execute Step 7 still runs $n" ;;
    esac
  fi
done
has 'gaspol-finish' "$step7" || fail "gaspol-execute Step 7 does not name gaspol-finish as owner"
heading=$(grep -F '### Step 7: Hand Off to gaspol-finish' "$EXEC" || true)
[ -n "$heading" ] || fail "gaspol-execute Step 7 not retitled 'Hand Off to gaspol-finish'"
step8=$(awk '/^### Step 8/{f=1;print;next} /^---/{f=0} f' "$EXEC")
has '_shared/finish-offer.md' "$step8" || fail "gaspol-execute Step 8 lost the finish offer"

# (b) auto post-run
post=$(awk '/^### Post-Run Consolidated Report/{f=1;next} /^### Rollback on Abort/{f=0} f' "$AUTO")
[ -n "$post" ] || fail "gaspol-auto has no post-run section"
for n in plan-verifier gaspol-verify; do
  bad=$(unowned "$n" "$post")
  [ -z "$bad" ] || fail "gaspol-auto post-run still dispatches $n"
done
has '_shared/finish-offer.md' "$post" || fail "gaspol-auto post-run no longer ends in the finish offer"
has 'gaspol-finish' "$post" || fail "gaspol-auto post-run does not say the gates run in gaspol-finish"
drop=$(git diff -- "$AUTO" | grep -F 'verified: PASS @' || true)
[ -z "$drop" ] || fail "gaspol-auto still carries the uncommitted ledger-line proposal edit"

# (c) finish contract
fin=$(cat "$FIN")
for lit in 'verified: PASS @' 'plan-verifier: CLEAN @' 'git rev-parse HEAD' 'git status --porcelain' \
           'gaspol-review: skipped — plan-verifier CLEAN @'; do
  has "$lit" "$fin" || fail "gaspol-finish missing literal: $lit"
done
# IDS-21: reuse line read from the ledger, never from memory
mem=$(printf '%s\n' "$fin" | grep -iF 'never' | grep -iF 'memory' || true)
[ -n "$mem" ] || fail "gaspol-finish does not say the line is read from the ledger, never from memory"
rerun=$(printf '%s\n' "$fin" | grep -F 'plan-verifier' | grep -F '<SHA>..HEAD' || true)
[ -n "$rerun" ] || fail "gaspol-finish plan-verifier re-run sentence lacks <SHA>..HEAD"
nop=$(printf '%s\n' "$fin" | tr '\n' ' ' | grep -oiE 'mandatory[^.]{0,60}(no plan|Step 2 was skipped)[^.]*' || true)
[ -n "$nop" ] || fail "gaspol-finish does not make the review mandatory when there is no plan"
bt=$(printf '%s\n' "$fin" | grep -iE 'unbackticked|garbled' || true)
[ -n "$bt" ] || fail "gaspol-finish does not treat an unbackticked/garbled SHA as missing"
nanti=$(printf '%s\n' "$fin" | grep -F 'Nanti' | grep -iF 'plan-verifier' || true)
[ -n "$nanti" ] || fail "gaspol-finish does not state the [Nanti] cost"

# (d) positive control: all four mandatory step names still in finish's chain
chain=$(awk '/^## Pre-Finish Verification Chain/{f=1;next} /^## The Offers/{f=0} f' "$FIN")
for n in gaspol-verify plan-verifier gaspol-review gaspol-sync-docs; do
  has "$n" "$chain" || fail "gaspol-finish chain lost mandatory step: $n"
done

# (e) the fix-loop round cap number lives in fix-loop.md only
cap=$(printf '%s\n' "$fin" | grep -iE '(cap|rounds?)[^.]*\b(five|5)\b' || true)
[ -z "$cap" ] || fail "gaspol-finish restates the fix-loop round cap"

# (f) edge cases as executable reuse rule: same sha+clean reuse, else rerun
reuse() { # $1 ledger sha  $2 head sha  $3 dirty(0/1)
  case "$1" in \`[0-9a-f]*\`) s=${1//\`/} ;; *) echo rerun; return ;; esac
  if [ "$s" = "$2" ] && [ "$3" = 0 ]; then echo reuse; else echo rerun; fi
}
[ "$(reuse '`abc1234`' abc1234 0)" = reuse ] || fail "same SHA + clean tree must reuse"
[ "$(reuse '`abc1234`' abc1234 1)" = rerun ] || fail "same SHA + dirty tree must rerun"
[ "$(reuse '`abc1234`' def5678 0)" = rerun ] || fail "different SHA must rerun"
[ "$(reuse 'abc1234' abc1234 0)" = rerun ] || fail "unbackticked SHA must be treated as missing"
[ "$(reuse '' abc1234 0)" = rerun ] || fail "missing line must rerun"

# (g) ledger-gate must still accept a ledger carrying the new finish lines
GATE="$PWD/skills/gaspol-verify/scripts/ledger-gate"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C "$W" init -q -b main
git -C "$W" config user.email t@example.invalid; git -C "$W" config user.name t
mkdir -p "$W/docs/plans" "$W/skills/foo" "$W/.gaspol/progress"
echo seed > "$W/seed.txt"; git -C "$W" add -A; git -C "$W" commit -q -m base
BASE=$(git -C "$W" rev-parse HEAD)
printf '**Ticket:** TST-1\n\n## Goal\n\nx\n' > "$W/docs/plans/2026-10-24-TST-1-x-plan.md"
echo code > "$W/skills/foo/a.sh"; git -C "$W" add -A; git -C "$W" commit -q -m work
SHA=$(git -C "$W" rev-parse HEAD)
cat > "$W/.gaspol/progress/PROGRESS-TST-1.md" <<LEDGER
# PROGRESS — TST-1: contoh

**Ticket:** TST-1

## Pre-flight

| Gate | Result |
|---|---|
| Git clean | PASS |

## Keputusan saat jalan

(kosong)

## Checklist

### [x] Phase A: contoh
- [x] satu langkah

## Phase log

| Phase | Status | Commit |
|---|---|---|

## Utang terbuka

(kosong)

## Log
- phase A done — NEXT: gaspol-finish
- verified: PASS @ \`$SHA\`
- plan-verifier: CLEAN @ \`$SHA\`
- gaspol-review: skipped — plan-verifier CLEAN @ \`$SHA\`
LEDGER
set +e; gout=$(cd "$W" && "$GATE" "$BASE" 2>&1); grc=$?; set -e
echo "ledger-gate: exit $grc: $gout"
[ "$grc" = 0 ] || fail "ledger-gate rejects the new finish lines (exit $grc: $gout)"

# IDS-21 audit round: per-phase auto-review fires only on the big triggers.
# The classifier used to REVIEW every non-docs diff ("REVIEW otherwise"); the owner approved
# "only big phases", and plan-verifier reported the decision DROPPED when no step carried it.
classifier="$(awk '/^### Step 3: Phase Checkpoint Report/{f=1} /^On REVIEW:/{f=0} f' "$EXEC")"
[ -n "$classifier" ] || fail "could not capture the Step 3 classifier text (positive control)"
case "$classifier" in *"REVIEW** otherwise"*) fail "classifier still reviews every non-docs diff ('REVIEW otherwise')" ;; esac
for trigger in "more than 3 files" "more than 100 lines" "new work"; do
  case "$classifier" in *"$trigger"*) : ;; *) fail "classifier no longer names the trigger: $trigger" ;; esac
done
case "$classifier" in *"REVIEW** only when"*) : ;; *) fail "classifier does not say REVIEW only when a trigger fires" ;; esac
case "$classifier" in *"below the review triggers"*) : ;; *) fail "classifier does not record a skip reason for a small phase" ;; esac

if [ "$fails" -ne 0 ]; then echo "$fails failure(s)"; exit 1; fi
echo "PASS: single-owner gates"
