#!/usr/bin/env bash
# tests/description-audit.sh
#
# A skill `description` field must contain ONLY triggering conditions
# ("Use when ...") — never a workflow/mechanism summary. The description
# loads into every session and Claude follows it as a shortcut instead of
# reading the full skill body.
#
# For each skills/gaspol-*/SKILL.md, extracts the YAML `description` value,
# strips the leading "Use when ..." (trigger-condition) clause, and FAILS
# if the remainder still contains mechanism-narration prose.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MARKERS=(
  "Dispatches"
  "Guides completion with"
  "Distills"
  "two-stage review"
  "DAG lane scheduling"
  "adversarial refutation pass"
  "enhanced placeholder detection"
)

fail_count=0

for skill_md in "$REPO_ROOT"/skills/gaspol-*/SKILL.md; do
  skill_name="$(basename "$(dirname "$skill_md")")"

  # Extract the YAML description value (single-line, optionally quoted).
  raw="$(grep -m1 '^description:' "$skill_md" | sed -E 's/^description:[[:space:]]*//')"
  # Strip surrounding double quotes if present.
  desc="$(echo "$raw" | sed -E 's/^"(.*)"$/\1/')"

  # Strip the leading "Use when ..." (or "Use ...") trigger-condition clause:
  # everything up to and including the first ". " (end of first sentence).
  remainder="$(echo "$desc" | sed -E 's/^[^.]*\.[[:space:]]*//')"

  for marker in "${MARKERS[@]}"; do
    if [[ "$remainder" == *"$marker"* ]]; then
      echo "FAIL: $skill_name — description contains mechanism-narration marker: \"$marker\""
      fail_count=$((fail_count + 1))
      break
    fi
  done
done

if [[ "$fail_count" -gt 0 ]]; then
  echo ""
  echo "$fail_count skill(s) have mechanism-narration in their description. Trigger conditions only — move mechanism prose into the skill body."
  exit 1
fi

echo "PASS: all skill descriptions contain only trigger conditions."
exit 0
