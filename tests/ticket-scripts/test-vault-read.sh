#!/usr/bin/env bash
# test-vault-read.sh — brainstorm reads the second brain, on bounded work too (IDS-8 Phase E)
#
# Phase 0.5 was headed "architectural path only". Bounded fixes — the majority of
# day-to-day work, and precisely where a documented gotcha is most likely to be
# re-hit — never queried the knowledge base at all. That is the mechanism behind
# the owner's complaint about repeating the same mistake twice.
#
# Spike keeps its exemption: a feasibility probe that answers a question and keeps
# no code has nothing to look precedent up for. Widening the gate to *everything*
# would be a different, unrequested change.
#
# Two coherence traps this test also closes, both created one phase earlier:
#   - Phase 0.5 filtered to `status: accepted`, and Phase C made gaspol write
#     `proposed` only. Left alone, every gaspol capture would be invisible to the
#     lookup that exists to find it.
#   - Step 0 said "auto-init ... git init". Against a store inside someone's
#     vault, that creates a git repository INSIDE their vault.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
B="$REPO_ROOT/skills/gaspol-brainstorm/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-vault-read: Phase 0.5 is no longer architectural-only..."
grep -n '^## Phase 0.5' "$B" | grep -qi 'architectural path only' \
    && fail "Phase 0.5 is still headed \"architectural path only\" — bounded work, where a known gotcha is most likely to be re-hit, would keep skipping the precedent query"

echo "test-vault-read: bounded runs the query, spike stays exempt..."
grep -qiE 'bounded' "$B" || fail "the bounded path is not mentioned in Phase 0.5's applicability at all"
# Scope to Phase 0.5. Searching the whole file matched line ~395's unrelated
# "Spike/bounded paths ... skip ticket-minting", so deleting the real exemption
# still passed.
SEC="$(awk '/^## Phase 0.5/{f=1;next} /^## /{f=0} f' "$B")"
[ -n "$SEC" ] || fail "could not locate the Phase 0.5 section to check spike's exemption inside it"
printf '%s\n' "$SEC" | grep -qiE 'spike (stays|remains|is) exempt' \
    || fail "spike's exemption is not stated INSIDE Phase 0.5 — widening the gate to every path is a different, unrequested change and must not happen by omission"

echo "test-vault-read: the vault read order is spelled out..."
for token in 'INDEX.md' 'hot.md' '30-Knowledge' '20-Projects'; do
    grep -qF "$token" "$B" || fail "the vault read order does not name $token — the owner's documented order is the contract, not a paraphrase"
done
grep -qiE 'stop.{0,40}enough|as soon as .{0,20}enough|progressive disclosure' "$B" \
    || fail "the read order does not say to stop once there is enough — reading a whole vault every brainstorm is the token cost this was meant to avoid"

echo "test-vault-read: the plugin stays agnostic — no absolute vault path..."
grep -nE '/Users/[a-zA-Z]+/|Drive-D|Obsidian-Vault' "$B" \
    && fail "an absolute vault path leaked into a public, agnostic plugin skill"

echo "test-vault-read: a missing vault is soft-referenced, never fatal..."
grep -qiE 'not a failure|never .{0,20}fail|continue' "$B" \
    || fail "a missing vault must be reported and stepped over, the way ui-ux-pro-max already is; a public plugin cannot require anyone to keep one"

# --- coherence with Phase C -------------------------------------------------
echo "test-vault-read: proposed captures are visible to the lookup..."
if grep -qiE 'only .{0,15}status: accepted|default show only .{0,10}`?status: accepted' "$B"; then
    fail "Phase 0.5 still filters to status: accepted only — gaspol now writes 'proposed' exclusively, so its own captures would be invisible to the query built to find them"
fi
grep -qF 'proposed' "$B" \
    || fail "Phase 0.5 never mentions 'proposed', the only status gaspol writes"

echo "test-vault-read: no git init into a store gaspol does not own..."
# Assert the PROHIBITION itself, not "some negation appears on the same line".
# The prohibition shares a line with "gaspol does not own", so a line-scoped
# negation check still saw a negation after the prohibition was deleted.
grep -qiE 'never .{0,6}git init|not .{0,6}git init|no .{0,6}git init' "$B" \
    || fail "the explicit prohibition on 'git init' is gone — pointed at a vault subfolder, an auto-init creates a git repository inside the owner's vault"
if grep -qiE '(auto-init|initialis|initializ|run) .{0,30}git init' "$B" \
   && ! grep -qiE 'never .{0,6}git init' "$B"; then
    fail "Phase 0.5 instructs an unconditional 'git init' on the store"
fi

echo "PASS: test-vault-read"
