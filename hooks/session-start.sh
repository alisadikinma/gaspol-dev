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
  design UI / colors / layout ................. gaspol-design
  plan / break down a task .................... gaspol-plan
  execute a plan (checkpoints) ................ gaspol-execute
  execute fully autonomously .................. gaspol-auto
  parallel / independent work ................. gaspol-worktree → gaspol-parallel
  isolate workspace / protect branch .......... gaspol-worktree
  implement or fix (before code) .............. gaspol-tdd
  bug / error / test failure .................. gaspol-debug
  review code ................................. gaspol-review
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
═══════════════════════════════════════════════════════════════
EOF
