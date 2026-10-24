**Ticket:** IDS-21

# IDS-21 — one owner per gate, drop gaspol-learn, research through notebooklm + Firecrawl

Source proposal: `docs/proposals/2026-10-24-reuse-verification-at-same-head.md`.
Batch Gate ruling: three items, **one ticket** — same subsystem (`skills/`), one plan under the phase threshold.

## Problem

1. One large `gaspol-auto` ticket ran `gaspol-verify` and `plan-verifier` in `gaspol-auto` post-run, then again in
   `gaspol-finish` Steps 1-2, then Tier 1 review (2 agents) over the same diff; `plan-verifier` was re-run three more
   times after fixes, each over the whole branch. A pass costs ~80-180k tokens; the suite ~6 min.
2. `gaspol-learn` (13KB) is referenced in 12 live files and the owner judges it useless.
3. `gaspol-research` gathers with `WebSearch`/`WebFetch` via Sonnet subagents; the owner requires `notebooklm` CLI + Firecrawl.

## Decisions (owner-approved in brainstorm)

| # | Decision |
|---|---|
| 1 | Scope: **one gate, one place** — duplicates are deleted, not skipped. |
| 2 | Owner of full `gaspol-verify` + `plan-verifier` is **`gaspol-finish`**. |
| 3 | Tier 1 review at finish is skipped when `plan-verifier` is CLEAN at HEAD and the user did not ask; mandatory with no plan. Per-phase auto-review only on big triggers (files>3 / LoC>100 / new feature). |
| 4 | `gaspol-learn` is deleted. |
| 5 | Missing `notebooklm` / Firecrawl in research: STOP and ask. No silent fallback. |

## Design

### A. Single owner per gate

- `gaspol-finish` Step 1 runs `gaspol-verify`, Step 2 runs `plan-verifier`. After a pass each appends
  `verified: PASS @ <sha>` / `plan-verifier: CLEAN @ <sha>` to the ledger `## Log` (SHA backticked, per v1.29.2).
- Re-entry reuse: on a later `gaspol-finish` call (e.g. after `[Nanti]`) a line is reused only when `<sha>` equals
  `git rev-parse HEAD` **and** the working tree is clean. Otherwise run again. The line is read from the ledger, never
  from memory. (The SHA is the anchor IDS-17 said "passed earlier" lacked.)
- `gaspol-execute` Step 7 stops dispatching `plan-verifier`; it keeps the per-phase ladder, the completion gate and the
  finish offer. `gaspol-auto` post-run stops running the verify chain and `plan-verifier`; it keeps the report and the
  finish offer. The uncommitted `gaspol-auto` ledger-line edit in the working tree is reverted.
- Fix rounds: `plan-verifier` re-run after a fix reads `<SHA>..HEAD` only (`skills/_shared/fix-loop.md` already says it;
  `gaspol-finish` states it).
- Step 3: skip with `gaspol-review: skipped — plan-verifier CLEAN @ <sha>`; mandatory when Step 2 was skipped for no plan, or the user asks.
- `gaspol-execute` Step 3 auto-review (amended after the plan-verifier audit, owner-approved): the classifier now REVIEWs only when a big trigger fires (files>3, LoC>100, new work); a smaller non-docs phase is SKIPped with the reason `below the review triggers`. No second review of the same diff at finish.

### B. Delete `gaspol-learn`

Delete `skills/gaspol-learn/`. Remove every reference: `gaspol-finish` (offer, report line, integration row),
`gaspol-debug:309`, `gaspol-adr:240`, `gaspol-research:229`, `using-gaspol`, `hooks/session-start.sh`, `rules/AGENTS.md`,
`agents/plan-verifier.md:376`, `README.md`, `docs/kb-setup.md`, `docs/rubric-model-switching.md`, tests, `CLAUDE.md`.
The finish modal keeps one offer: `/security-review`. KB writes remain via `gaspol-adr` and `gaspol-research`.
Skill count 17 → 16. Historical files (`CHANGELOG.md` past entries, `.gaspol/progress/*`, `docs/plans/*`, `graphify-out/`) are not edited.

### C. `gaspol-research` through notebooklm + Firecrawl

- Phase 3 gather: `firecrawl_search` / `firecrawl_scrape` (`maxAge: 0` for freshness-critical pages) collect sources; the
  Sonnet gather subagents are removed.
- Synthesis: `notebooklm create`, `source add`, `source wait`, `ask` (with citations). Only the `ask` answer enters context.
- Anti-hallucination spot-check, quality gates (>=4 sources, recency, citations), freshness tiers and KB cache stay.
- `gaspol-brainstorm` Phase 1.5 SEMI-NEW light research uses `firecrawl_search`, not `WebSearch`.
- Tool check before gather: `notebooklm status`/`doctor` and the Firecrawl tool being present. Failure = state UNKNOWN →
  STOP and ask, naming the fix (`notebooklm login`, enable the Firecrawl MCP). Never degrade to `WebSearch`.
- `model-tier: exec` header stays (gathering is execution).

### Data Integration Map

| Component | Data source | Existing? | Notes |
|---|---|---|---|
| finish reuse lines | ledger `## Log` | yes (ledger) | new line formats only |
| research gather | Firecrawl MCP, `notebooklm` CLI | yes (installed) | no new code, skill text only |
| learn removal | grep of references | yes | tests assert absence |

### Edge cases

| Case | Behaviour |
|---|---|
| Finish re-entered, same SHA, clean tree | reuse both lines |
| Same SHA, dirty tree | run again |
| Ledger line missing / unreadable | run again; ledger unresolved = UNKNOWN per `ledger-gate`, ask |
| Fix commit after CLEAN | HEAD moved → re-run `plan-verifier` over `<SHA>..HEAD` |
| No plan on branch | `plan-verifier` skipped as today; Tier 1 review mandatory |
| `[Nanti]` chosen | no `plan-verifier` ran yet; accepted cost, recorded in the deferral cursor |
| `notebooklm` not logged in | STOP, ask, name `notebooklm login` |
| Firecrawl MCP absent | STOP, ask |
| Stale `gaspol-learn` mention left anywhere live | new test fails |

### Blast radius

`skills/gaspol-finish`, `gaspol-execute`, `gaspol-auto`, `gaspol-research`, `gaspol-brainstorm` (Phase 1.5 line),
`gaspol-debug`, `gaspol-adr`, `using-gaspol`, `hooks/session-start.sh`, `rules/AGENTS.md`, `agents/plan-verifier.md`,
`skills/gaspol-learn/` (deleted), `README.md`, `docs/`, `CLAUDE.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`,
`tests/ticket-scripts/*` (finish-gates, finish-fix-loop, kb-*, model-gate, frontmatter), `tests/skill-triggering/run-all.sh`.
Marketplace entry in gaspol-one is updated separately after release.

## What this gives up (stated, not discovered later)

- A second reader of the diff: `plan-verifier` checks spec/plan fit, not general bugs. If bugs a Tier 1 review would catch
  appear after merge, revisit decision 3.
- `[Nanti]` tickets reach merge-ready with no `plan-verifier` pass until finish runs.
- A ledger line can be written wrongly; the gate trusts the ledger as `ledger-gate` and `regression-gate` do.
- Savings are estimated (1-2 `plan-verifier` passes, one full suite, two review agents per auto ticket), **not measured**;
  no automated test measures skill-text token cost. Prove on the next `gaspol-auto` → `gaspol-finish` ticket.

## Out of scope

Shrinking large skill texts (verify/plan/execute/parallel/brainstorm) — declined by the owner for this ticket.
