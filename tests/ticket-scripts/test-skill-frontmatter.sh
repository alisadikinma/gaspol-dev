#!/usr/bin/env bash
# test-skill-frontmatter.sh — every skill still LOADS (IDS-8, /security-review round)
#
# IDS-8 inserted an explanatory blockquote into gaspol-kb-audit BETWEEN the
# opening `---` and `name:`, which is inside the YAML frontmatter. Claude Code
# reads `name` and `description` from that block to route a skill, so the skill
# most likely stopped loading at all — and nothing in a 28-test suite noticed,
# because every test asked what the prose SAYS and none asked whether the file is
# still a valid skill.
#
# The same edit landed correctly in four other skills, below the closing `---`.
# One file out of five is exactly the shape a reviewer's eye slides over.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

count=0
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    count=$((count + 1))
    n="$(basename "$(dirname "$f")")"
    python3 - "$f" "$n" <<'PYEOF' || exit 1
import sys
path, name = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
def die(msg):
    print(f"FAIL: {name}/SKILL.md {msg}", file=sys.stderr); sys.exit(1)
if not lines or lines[0].strip() != "---":
    die("does not open with a `---` frontmatter fence; Claude Code cannot read its name or description")
try:
    close = next(i for i, l in enumerate(lines[1:], 1) if l.strip() == "---")
except StopIteration:
    die("has an unterminated frontmatter block")
body = lines[1:close]
if not body:
    die("has an empty frontmatter block")
for i, l in enumerate(body):
    if not l.strip():
        die(f"has a blank line inside its frontmatter (line {i+2})")
    # a key line, or the continuation of a folded value
    if not (l[0].isalpha() and ":" in l.split(" ")[0] + ":") and not l.startswith((" ", "\t", "-")):
        die(f"has a non-YAML line inside its frontmatter (line {i+2}): {l[:70]!r}")
keys = [l.split(":", 1)[0].strip() for l in body if l[:1].isalpha()]
for required in ("name", "description"):
    if required not in keys:
        die(f"frontmatter has no `{required}:` key — routing needs it")
PYEOF
done

# Positive control. A loop over a glob that matches nothing passes silently, which
# is this repo's own vacuous-assertion-proves-nothing.
[ "$count" -ge 15 ] \
    || fail "only $count SKILL.md files were checked — the glob is broken, so a clean result proves nothing"

echo "PASS: test-skill-frontmatter ($count skills, frontmatter parses and carries name + description)"
