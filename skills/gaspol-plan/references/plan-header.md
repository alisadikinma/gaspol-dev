# Plan header: template

The header every plan starts with, copied verbatim. `SKILL.md` states the rule for each field.

```markdown
> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-<TICKET>.md` (TICKET = this plan's ticket, from the header below; created by `gaspol-plan` at plan-write time — see Plan Document Header step 7). After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's `## Checklist` line, (b) append a `## Log` line ending with the handoff cursor. This is **blocking**, like a test gate: no next phase until both are written. **Never batch all updates at the end** — a crash mid-run must leave a truthful state, not a stale one. Update ONLY this file — never the shared `.gaspol/progress.md` (that keeps concurrent plans from clobbering each other). **Backward compatibility:** older ledgers at `.gaspol/progress/<slug>.md` or the shared `.gaspol/progress.md` are STILL READ when a plan's header names them — only NEW plans write the `PROGRESS-<TICKET>.md` path.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat or read a linked PDF. Every file path, contract, config key, and convention it needs is written here **verbatim**, not merely referenced. If it lives only in the conversation, copy it in.

**Ticket:** IND-81
**Ledger:** .gaspol/progress/PROGRESS-IND-81.md
**Spec:** docs/plans/2026-08-20-IND-81-<topic>-spec.md <!-- omit entirely if this plan is standalone (no preceding brainstorm spec file) -->
**Artifact:** https://claude.ai/public/artifacts/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx <!-- present ONLY when the post-plan offer's [Render design artifact dulu] option was taken and the artifact was approved; omit the whole line otherwise, and never write "n/a" -- a declined artifact is recorded in the LEDGER as `design-artifact: skipped — <reason>`, not here -->
**Format:** waves-v1 <!-- always present in a new plan: it is what tells `plan-waves` and the executors that every phase below carries `**Deps:**` and `**Complexity:**` -->

**Verification commands:**
- static: npx tsc --noEmit
- unit: npm test

## Goal

[One paragraph describing what this plan achieves and why it matters]

## Architecture Context

[Key info pulled from CLAUDE.md: relevant tables, hooks, contexts, routes, design system tokens]

## Tech Stack

[Frameworks, libraries, patterns to use — reference existing choices from CLAUDE.md]
```
