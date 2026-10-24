**Ticket:** IDS-22

# IDS-22 — Parallel waves and per-phase complexity, decided at plan time

## Problem

Two things the owner assumed `gaspol-plan` and `gaspol-auto` already do. Verified by reading
the skills on 1.30.0: neither exists.

| Claim | Evidence |
|---|---|
| Plan decides which phases can run in parallel | `skills/gaspol-plan/SKILL.md` carries `**Files:**` (line 308) and one offer, `[Eksekusi parallel]` "only when the plan has independent phases" (line 422). Nothing decides which phases are independent. `dag-lanes` runs only inside `gaspol-parallel`, at execution time |
| `gaspol-auto` executes independent phases in parallel | `skills/gaspol-auto/SKILL.md:79` — `For each phase in plan (sequential)`. No parallel path |
| Plan rates phases by complexity and assigns a model | No `complexity` field in the plan. `gaspol-auto` and `implementer-prompt.md` hardcode `sonnet`. `gaspol-parallel` line 218 says "scale model to task class" but no class is ever written, so the orchestrator guesses at dispatch |

Same defect shape this repository has now fixed seven times: a rule stated in prose, nothing
produces or reads the record it needs.

## Design

### 1. Plan writes three fields per phase

- `deps:` phases that must finish first (one produces what the other consumes).
- `files:` files the phase touches (exists today; now also feeds conflict detection).
- `complexity:` `light` / `medium` / `complex`, **with a one-sentence reason**. A bare label is
  not accepted (`ledger-states-require-non-empty-reasons`).

Rubric for `complexity`:

| Level | When |
|---|---|
| light | one file, no design decision |
| medium | several files, pattern already in the repo |
| complex | new logic; money, auth or security; many interlinked files; an interface other phases consume |

### 2. Plan computes the waves

After writing phases, `gaspol-plan` runs `skills/gaspol-parallel/scripts/dag-lanes` (invoked via
`"$CLAUDE_PLUGIN_ROOT/..."`) and writes the result into the plan and the ledger:
`Wave 1: P1, P2 (parallel) · Wave 2: P3`. Cycle or unknown dep → the script errors, plan stops.

### 3. Model and effort follow complexity — still two tiers

IDS-20 stands: execution is Sonnet, Opus judges. Complexity changes **effort and review**, not tier.

| complexity | model | effort | review |
|---|---|---|---|
| light | sonnet | low | normal |
| medium | sonnet | medium | normal |
| complex | sonnet | high | Opus review per phase, mandatory |

The orchestrator reads the plan's `complexity` and passes `model` and `effort` on each dispatch.
It does not infer them. Plans written after this ticket carry a `**Format:** waves-v1` header line. A new script `skills/gaspol-plan/scripts/plan-waves` validates the `waves-v1` fields, because `model-gate` scans `skills/` and `agents/` and never reads a plan. In a `waves-v1` plan, a phase without `complexity` (or with a bare label and no
reason) is BLOCKING. Plans without that header are exempt (see section 5).

### 4. `gaspol-auto` runs waves

- Pre-flight reads the wave table.
- A wave with ≥2 phases: create a worktree via `gaspol-worktree`, dispatch one sub-agent per
  phase concurrently, wait for all, then start the next wave. One isolation worktree; lanes touch disjoint files; the orchestrator, not the sub-agents, commits each phase by its declared files.
- Existing hard-stops unchanged. One lane failing stops the wave; nothing from the next wave starts.
- A one-phase wave runs the way phases run today.

### 5. Backward compatibility

A plan with no `deps` / `complexity` is treated as fully sequential, all `medium`. Nothing breaks.

## Data Integration Map

| Piece | Source | Exists? | Action |
|---|---|---|---|
| DAG scheduling | `skills/gaspol-parallel/scripts/dag-lanes` | yes | call from `gaspol-plan` |
| Worktree isolation | `gaspol-worktree` | yes | call from `gaspol-auto` |
| Model/effort per dispatch | plan `complexity` column | no | add to plan template, read in auto/parallel/execute |
| Complexity check | `model-gate` | yes | extend |

## Accepted costs

- A wrongly declared `deps` is found at merge, not before. `dag-lanes` catches file collisions;
  a semantic dependency (phase B calls a function phase A changes) is caught only if `deps` is right.
- Complex phases cost an Opus review each. Chosen over "review only on failure" by the owner.
- Complexity is a judgement by the planner, not a measurement.
- Full static/build ladder runs once per wave, after the wave, because lanes share one tree.

## Does NOT close

- No post-hoc check that the declared complexity matched the actual diff size.
- `gaspol-execute` (per-phase checkpoints) still runs phases one at a time; only `gaspol-auto` and
  `gaspol-parallel` use waves.
- The main session's own model is still not enforceable.

## Testing approach

Deterministic bash tests under `tests/ticket-scripts/`: plan template carries the three fields;
`gaspol-auto` reads the wave table; a plan without `complexity` is handled as sequential/medium;
`model-gate` rejects a `complexity` label with no reason.
