#!/usr/bin/env bash
# test-reference-loading.sh — asserts gaspol-write-skill's heavy references are
# reachable AND explicitly on-demand (IDS-6 C2).
#
# The 2026-08-21 audit expected these three files (~11.9k tokens, the heaviest
# reference set in the plugin) to be eagerly loaded. They were not — SKILL.md did
# not mention them at all. They were orphans: no runtime cost, and no way for
# anyone to find them either.
#
# The fix is a pointer per file naming the QUESTION it answers, read only when that
# question is live. A pointer without the question is just a filename, and gets
# opened speculatively — which is the eager loading we did not want.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIR="$REPO_ROOT/skills/gaspol-write-skill"
SKILL="$DIR/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -qi -- "$2" "$1" || fail "$3"; }

for ref in testing-skills-with-subagents.md anthropic-best-practices.md persuasion-principles.md; do
    [ -s "$DIR/$ref" ] || fail "$ref is missing or empty"
    has "$SKILL" "$ref" "expected SKILL.md to point at $ref — an unreferenced file is an orphan, not a reference"
done

has "$SKILL" "read .*when\|only when\|on demand\|when that question" \
    "expected SKILL.md to mark these references as read-when-needed, not read-up-front"

# Each pointer states the question it answers, so nobody opens it speculatively.
has "$SKILL" "how do I know the skill actually works\|does the skill actually work\|verify a skill works" \
    "expected the testing-skills-with-subagents pointer to name the question it answers"
has "$SKILL" "frontmatter\|description field\|structure a skill" \
    "expected the anthropic-best-practices pointer to name the question it answers"
has "$SKILL" "ignore the rule\|resist\|rationalis\|rationaliz" \
    "expected the persuasion-principles pointer to name the question it answers"

echo "PASS: test-reference-loading"
