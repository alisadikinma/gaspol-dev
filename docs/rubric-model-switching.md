# Model Switching Rubric

Auto-rubric untuk pilih model berdasarkan task type. Orchestrator (main session) selalu Opus 4.7. Subagent dispatch pilih model sesuai kompleksitas task.

## Rubric Table

| Task Kind | Model | Justification |
|-----------|-------|---------------|
| Main orchestrator (current session) | `opus` (4.7) | Strategic reasoning, workflow decisions, multi-step planning |
| Architecture planning | `opus` | Deep multi-step analysis, trade-off evaluation |
| Spec review (spec-reviewer agent) | `opus` | Architectural judgment required |
| Plan fidelity audit (plan-verifier agent) | `opus` | Evidence-based step-level verification |
| Complex debugging (systematic root-cause) | `opus` | Hypothesis branching, non-linear |
| Research synthesis (gaspol-research) | `opus` | Cross-source consolidation + reasoning |
| Autonomous orchestration (gaspol-auto) | `opus` | Hard-stop decision-making |
| Feature implementation | `sonnet` (4.6) | Execute well-defined tasks efficiently |
| Code review (code-reviewer agent) | `sonnet` | Pattern matching, style check |
| Test writing | `sonnet` | Mechanical but precise |
| Research gathering (per-source) | `sonnet` | Parallel fetch + summarize per source |
| ADR capture (gaspol-adr) | `sonnet` | Structured template filling |
| Learn capture (gaspol-learn) | `sonnet` | Pattern extraction + validation |
| Design system reasoning | `sonnet` | Apply rules, match templates |
| Documentation sync (gaspol-sync-docs) | `haiku` (4.5) | Template-driven, low reasoning |
| Simple refactor (code-simplifier agent) | `haiku` | Mechanical transformation |
| Rename / format | `haiku` | Deterministic operation |
| Simple fact lookup (research light mode) | `haiku` | Bounded scope, single source |

## How to Apply

### In Skill Dispatch

When dispatching a subagent via Task tool, include `model` parameter:

```
Agent({
  description: "Code review task",
  prompt: "...",
  subagent_type: "code-reviewer",
  model: "sonnet"  // from rubric
})
```

### In Agent Frontmatter

Agents under `agents/` have YAML frontmatter specifying default model:

```yaml
---
name: code-reviewer
description: ...
model: sonnet
---
```

### Override Precedence

1. Explicit `model` param in Agent tool call (highest)
2. Agent's frontmatter `model` field
3. Inherited from parent session (fallback)

## When to Override

Rubric is default. Override kalau:
- Task genuinely more complex than typical (e.g., debugging an obscure race condition → force Opus even though it's "debugging")
- Task simpler than typical (e.g., trivial one-line doc fix → force Haiku even though it's "docs")

Log override reasoning kalau routinely deviating — might indicate rubric needs adjustment.

## Token/Cost Implications

Approximate cost ratio (Apr 2026):
- Opus : Sonnet : Haiku ≈ 15 : 3 : 1

Rubric targets ~15% Opus, ~60% Sonnet, ~25% Haiku across typical workflow — saving 3-5x vs all-Opus.

## Integration Points

- `agents/code-reviewer.md` — sonnet (frontmatter)
- `agents/code-simplifier.md` — haiku (frontmatter)
- `agents/plan-verifier.md` — opus (frontmatter)
- `agents/spec-reviewer.md` — opus (frontmatter)
- `skills/gaspol-execute/implementer-prompt.md` — dispatch with sonnet default
- `skills/gaspol-parallel/spec-reviewer-prompt.md` — dispatch with opus
- `skills/gaspol-parallel/code-quality-reviewer-prompt.md` — dispatch with sonnet
- `skills/gaspol-research/SKILL.md` — parallel gatherers sonnet, synthesizer opus
- `skills/gaspol-auto/SKILL.md` — orchestrator opus, implementers sonnet

## References

- Claude Code Agent tool: supports `model` parameter per dispatch
- Valid values: `opus`, `sonnet`, `haiku` (maps to current latest minor version)
- Explicit version IDs acceptable: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`
