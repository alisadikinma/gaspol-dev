#!/bin/bash
# gaspol-dev session start hook — bootstrap loader
# Injects the gaspol auto-trigger directive into every session so skills
# fire at the right moment without the user typing a slash command.

cat <<'EOF'
═══════════════════════════════════════════════════════════════
gaspol-dev active — process discipline for real code, not placeholders.
═══════════════════════════════════════════════════════════════

THE RULE (non-negotiable): If there is even a 1% chance a gaspol skill
applies to what you are about to do, invoke it via the Skill tool BEFORE
responding — before clarifying questions, before reading files, before
"just one quick thing." For the full bootstrap, invoke `using-gaspol`.

ROUTING — match the user's intent, invoke BEFORE acting:
  build / add feature / new component ......... gaspol-brainstorm
  design UI / colors / layout ................. ui-ux-pro-max (plugin)
  plan / break down a task .................... gaspol-plan
  execute a plan (checkpoints) ................ gaspol-execute
  execute fully autonomously .................. gaspol-auto
  parallel / independent work ................. gaspol-worktree → gaspol-parallel
  isolate workspace / protect branch .......... gaspol-worktree
  implement or fix (before code) .............. gaspol-tdd
  bug / error / test failure .................. gaspol-debug
  review code ................................. gaspol-review
  auth/secrets/input/endpoint/payment ........ /security-review (CLI built-in)
  received review feedback .................... gaspol-receive-review
  claim done / ready to commit ................ gaspol-verify
  merge / PR / cleanup a branch ............... gaspol-finish
  sync CLAUDE.md .............................. gaspol-sync-docs
  research a lib / API / pattern .............. gaspol-research
  architectural decision ...................... gaspol-adr
  capture patterns after shipping ............. gaspol-learn

REMINDERS:
  • Read the target project's CLAUDE.md FIRST before exploring its codebase.
  • Anti-placeholder enforcement is active — no fake/mock/dummy data when a
    real integration is specified. The 3 Iron Laws apply to every skill.
  • Use AskUserQuestion (interactive modal) for all confirmations/choices.

COMPLETENESS LADDER (always-on coverage governor):
  Do the complete thing — completeness is cheap now, the shortcut is not.
  Walk DOWN and do every rung: (1) happy path, real integration. (2) every
  error path that can actually happen. (3) every edge case the input space
  allows — enumerate, don't sample. (4) the tests that prove 1-3, written
  first. (5) the observability a 3am debugger needs. (6) the one comment that
  explains WHY. Stop only at genuinely unrelated work — flag it as separate
  scope, never as a reason to ship a shortcut.
  REUSE: prefer stdlib → native feature → already-installed dep over code you
  author. No interface with one implementation. Reuse cuts cleverness, never
  coverage.
  BOUNDARY: completeness is depth on the REQUESTED work, never new features,
  and never an excuse for a placeholder or a skipped Iron Law.
  Full text: skills/_shared/completeness-ladder.md.
═══════════════════════════════════════════════════════════════
EOF

# --- KB status (cross-project knowledge base) -------------------------------
CFG="$HOME/.claude/gaspol-config.json"
KB="$HOME/.claude/gaspol-knowledge"
if grep -q '"kb_mode"[[:space:]]*:[[:space:]]*"off"' "$CFG" 2>/dev/null; then
  echo "KB: off (disabled via gaspol-config.json). adr/learn/research/kb-audit inactive."
elif grep -q '"kb_remote"' "$CFG" 2>/dev/null || [ -n "$GASPOL_KB_REMOTE" ]; then
  echo "KB: synced (GitHub) — adr/learn/research compounding cross-machine."
elif [ -d "$KB" ]; then
  echo "KB: local-only — capturing to ~/.claude/gaspol-knowledge (add a remote to sync; see docs/kb-setup.md)."
else
  echo "KB: local-only (default) — auto-creates on first adr/learn capture. No setup needed."
fi
