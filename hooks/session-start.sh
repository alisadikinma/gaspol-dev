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
  LLM / prompt / agent (non-deterministic) .... gaspol-llm-test
  bug / error / test failure .................. gaspol-debug
  review code ................................. gaspol-review
  auth/secrets/input/endpoint/payment ........ /security-review (CLI built-in)
  received review feedback .................... gaspol-receive-review
  claim done / ready to commit ................ gaspol-verify
  merge / PR / cleanup a branch ............... gaspol-finish
  sync CLAUDE.md .............................. gaspol-sync-docs
  create / edit a skill ....................... gaspol-write-skill
  research a lib / API / pattern .............. gaspol-research
  architectural decision ...................... gaspol-adr
  capture patterns after shipping ............. gaspol-learn
  audit the knowledge base .................... gaspol-kb-audit

REMINDERS:
  • Read the target project's CLAUDE.md FIRST before exploring its codebase.
  • Anti-placeholder enforcement is active — no fake/mock/dummy data when a
    real integration is specified. The 3 Iron Laws apply to every skill.
  • Use AskUserQuestion (interactive modal) for all confirmations/choices.

LAZINESS LADDER (always-on scope governor — absorbed from ponytail):
  Write the laziest code that actually works. Before any code, stop at the
  first rung that holds: (1) does it need to exist? YAGNI → skip. (2) stdlib?
  (3) native platform feature? (4) already-installed dep? (5) one line? (6) only
  then minimum code. Fewest files, shortest diff, no unrequested abstractions.
  BOUNDARY: lazy cuts SCOPE, never FIDELITY — the ladder never excuses
  placeholder data, skipped validation/security/tests, or an Iron Law breach.
  Mark deliberate cuts with a `ponytail:` comment. Full text + fidelity
  boundary: skills/_shared/laziness-ladder.md.
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
