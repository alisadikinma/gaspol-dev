# gaspol-dev — Claude Project Instructions

## Project Overview

Claude Code plugin providing battle-tested development skills with anti-placeholder enforcement, per-phase checkpoints, plan verification, and design intelligence. Born from building a real AI-powered SaaS platform.

## Architecture

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, author) |
| `.claude-plugin/marketplace.json` | Marketplace listing |
| `hooks/hooks.json` | SessionStart hook definition |
| `hooks/session-start.sh` | Session start script — announces available skills |
| `skills/` | 16 skill directories, each with SKILL.md |
| `agents/` | 4 agent definitions |
| `README.md` | Repo README |
| `LICENSE` | MIT license |

## Skills

| Skill | When to Use |
|-------|-------------|
| `gaspol-kickstart` | Starting any conversation — establishes skill routing |
| `gaspol-brainstorm` | Before any creative work — features, components, modifications |
| `gaspol-design` | Frontend design tasks — distinctive, production-grade interfaces |
| `gaspol-plan` | Multi-step tasks with spec/requirements — before touching code |
| `gaspol-execute` | Executing a written implementation plan — anti-placeholder enforced |
| `gaspol-parallel` | Executing plans with independent tasks via subagents |
| `gaspol-dispatch` | 2+ independent tasks needing parallel resolution |
| `gaspol-tdd` | Any feature/bugfix — RED-GREEN-REFACTOR before production code |
| `gaspol-debug` | Any bug, test failure, unexpected behavior — systematic root cause |
| `gaspol-review` | After completing tasks — dispatches code-reviewer subagent |
| `gaspol-receive-review` | Receiving code review feedback — verify before implementing |
| `gaspol-verify` | Before claiming work complete — evidence before assertions |
| `gaspol-finish` | Implementation complete, tests pass — merge/PR/cleanup guidance |
| `gaspol-sync-docs` | After significant code changes — keep CLAUDE.md in sync |
| `gaspol-worktree` | Feature work needing isolation — git worktree management |
| `gaspol-write-skill` | Creating/editing skills — TDD for process documentation |

## Agents

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Code review between commits |
| `code-simplifier` | Simplify and refine code for clarity |
| `plan-verifier` | Compare plan vs actual code changes |
| `spec-reviewer` | Verify implementation matches specification |

## Core Principles

- **Anti-placeholder enforcement**: Never silently substitute placeholders for real integrations
- **CLAUDE.md-first**: Always read CLAUDE.md before exploring codebase
- **Evidence before assertions**: Run verification commands before claiming success
- **Per-phase checkpoints**: Validate each phase before proceeding
