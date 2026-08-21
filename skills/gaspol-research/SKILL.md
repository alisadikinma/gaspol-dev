---
name: gaspol-research
description: "Use when evaluating external libraries, APIs, patterns, or approaches that are unfamiliar or where training data may be outdated. Performs structured deep research with multi-source citation, anti-hallucination safeguards, and freshness-aware caching to cross-project knowledge base."
---

# gaspol-research

## Iron Law

```
NO RESEARCH CLAIMS WITHOUT SOURCE CITATION + CACHE DECISION
```

Every claim needs a URL or file:line reference. Every research output gets cached to KB with TTL. Never rely solely on training memory for industry-current state — verify via web fetch.

---

## Core Principle

Training data has a cutoff. Industry moves fast. Research grounds approach proposals in *current* state, not *remembered* state. Cache results so next project with similar need skips re-research — with freshness-aware invalidation preventing stale data.

## When to Use

- Evaluating unfamiliar library / framework / tool before adoption
- Industry practice for a domain has evolved rapidly (JS ecosystem, AI/ML tooling, cloud infra)
- Training data cutoff may have missed important developments
- Need to compare multiple options with real-world signal (stars, downloads, maintenance activity)
- Architectural decision where wrong choice has high reversal cost
- Auto-triggered from `gaspol-brainstorm` Phase 1.5 when novelty classified as NEW

## When NOT to Use

- Familiar domain with existing project precedent (check KB first)
- Simple fact lookup (use WebSearch directly)
- Task is routine within well-known codebase patterns
- Cache already has fresh (🟢 <90 days) research on the same topic

---

## Process Flow

### Phase 1: Scope

Use `AskUserQuestion` to clarify:
1. What specific decision will this research inform?
2. What constraints already known (stack, team size, scale)?
3. What options are being considered (if any starting list)?

Don't start broad research without defined question.

### Phase 2: Check Cache

Before fetching anything, query KB (auto-init local dir if missing; see [docs/kb-setup.md](../../docs/kb-setup.md)):

```bash
KB="$(skills/_shared/kb-root)" || {   # 0=available 3=UNKNOWN(STOP+ask) 4=none(report+continue)
  # Never continue with an empty $KB: git -C "" is a silent wrong answer.
  echo "see skills/_shared/kb-path.md for the three states"; return 2>/dev/null || exit 1; }
[ -n "$REMOTE" ] && git -C "$KB" pull --quiet || true   # synced mode only
# Grep $KB/INDEX.md for matching tags (local-only mode reads local cache directly)
```

If cache hit found:
- Check age → freshness tier (🟢/🟡/🟠/🔴)
- Present to user via AskUserQuestion:
  - `[Use cached as-is]` (if FRESH)
  - `[Verify freshness — mini research]` (if AMBER)
  - `[Re-research — cache stale]` (if STALE)
  - `[Force full re-research]` (always available)

If no cache, proceed to Phase 3.

### Phase 3: Parallel Gather (Sonnet subagents)

Dispatch 3-5 parallel subagents (model: sonnet) to gather from different source types:

1. Official documentation (`WebFetch` home URL + key docs pages)
2. GitHub repository analysis (stars, last commit, open issues trend)
3. Comparables / benchmarks (search for "X vs Y", existing comparisons)
4. Anti-pattern check (search for "problems with X", "X deprecated", "X alternatives")
5. Real-world usage (search for case studies, migration stories)
6. **Agent-skill marketplace** — `npx skills find "<topic>"` (skills.sh). "Somebody
   already packaged this as an agent skill" is a research finding like any other,
   and the cheapest recommendation available. Report it as a candidate with its
   source and install count; never install it as part of research (install rules:
   `gaspol-write-skill` Step 0). If the CLI is unavailable, say so — an unrun
   lane is reported as unrun, never as empty.

Each subagent returns structured findings with URL citations.

### Phase 4: Synthesize (Opus orchestrator)

Consolidate parallel findings into structured output:

- Context (what decision this informs)
- Options considered (name, summary, sources)
- Comparison matrix (feature/cost/community/maintenance)
- Recommendation (with project-fit reasoning)
- Open questions (things research couldn't resolve)
- Sources (complete URL list with fetch dates)

### Phase 5: Quality Gate Check

Before writing to cache, validate output against Research Quality Gates:

| Gate | Rule | Reject if |
|---|---|---|
| Multi-source | ≥4 sources | <4 sources |
| Recency | Sources <18 months preferred | All sources >3 years old |
| Signal filter | GitHub metrics for each lib (stars, last commit) | Missing for key libraries |
| Anti-pattern | "X vs Y" and "problems with X" searches done | Only "X is great" sources |
| Constraint fit | Recommendation references project constraints | Generic "which is better" framing |
| Citation mandatory | Every claim has URL or file:line | Unsupported claims |

If any gate fails → fix or escalate to user before caching.

### Phase 6: Cache Write

> **`<KB_ROOT>`** is the resolved knowledge-base root. Resolve it with `skills/_shared/kb-path.md` (`$GASPOL_KB_LOCAL` → `kb_local` in `~/.claude/gaspol-config.json` → default), and honour its three states — `available` / `none` / `UNKNOWN`. Never spell the default path here: doing so is why a correct setting still wrote to the old folder.

Write to `<KB_ROOT>/research/<slug>.md` with frontmatter:

```yaml
---
id: research-2026-04-17-zustand-vs-redux
title: Zustand vs Redux for State Management
researched_at: 2026-04-17
expires_at: 2026-10-14    # researched_at + 180 days default
status: proposed          # user promotes to accepted via AskUserQuestion
sources:
  - https://zustand.docs.pmnd.rs (fetched 2026-04-17)
  - https://github.com/pmndrs/zustand (23k stars, last commit 2026-04-10)
  - ...
tags: [state-management, react, zustand, redux]
verdict: prefer-zustand-for-apps-under-10k-loc
project_fit: [project-context]
supersedes: null
superseded_by: null
---

## Context
## Options Compared
## Comparison Matrix
## Recommendation
## Open Questions
## Sources
```

Update `INDEX.md` with new entry + freshness badge.

Commit the cache entry locally (always); push only in synced mode (`kb_remote` / `$GASPOL_KB_REMOTE` configured). See [docs/kb-setup.md](../../docs/kb-setup.md). In local-only mode the cache persists locally and still serves future cache hits on this machine — no remote required.

### Phase 7: Return to Caller

Return synthesized recommendation to caller skill (usually `gaspol-brainstorm`) for use in Phase 2 approach proposal.

---

## Freshness Lifecycle (see spec Poin 9)

When called and cache exists:

| Age | Tier | Default Behavior |
|---|---|---|
| 0-90 days | 🟢 FRESH | Use as-is |
| 90-180 days | 🟡 AMBER | Offer mini-research (2-3 queries verify key sources unchanged) |
| 180-365 days | 🟠 STALE | Offer full re-research or use-with-warning |
| >365 days | 🔴 EXPIRED | Mandatory re-research; archive old to `research/_archive/` |

Mini-research (AMBER path):
1. WebSearch each cached source URL domain → check last-updated date
2. WebSearch "[topic] 2026" → check breaking changes
3. No change → bump `researched_at`, extend `expires_at`
4. Change detected → full re-research, old cache marked `superseded_by: <new-id>`

---

## Anti-Hallucination Measures

1. **WebFetch actual pages** for claims critical to decision — don't cite from memory
2. **GitHub metrics** must be fetched from actual repo page, not estimated
3. **Orchestrator spot-check** — sample 2 random claims from cache output, verify URLs still resolve
4. **Citation format enforced** — every claim ends with `([src](URL))` format
5. **Explicit staleness disclosure** — if a source >2 years old, prefix claim with "(as of [date])"

---

## Red Flags

| Red Flag | Fix |
|---|---|
| "Generally X is used for Y" without citation | Reject claim, demand URL |
| Single-source research | Require ≥4 sources |
| Only pro-X or only con-X sources | Balance with "X vs Y" and "problems with X" |
| Cache hit used without age check | Show freshness tier to user |
| Fabricated benchmark numbers | WebFetch actual comparison pages |
| Training-data citation ("in 2024 React Hooks were popular") | Replace with current-year WebSearch |
| Skipping quality gate check | All gates must pass before caching |
| Recommending a build when a packaged skill already does it | Run the marketplace lane before recommending; report the candidate |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-brainstorm` Phase 1.5 | Auto-invoked when novelty = NEW |
| `gaspol-adr` | Research verdict captured as ADR input |
| `gaspol-kb-audit` | Research freshness tracked, stale items flagged |
| `gaspol-learn` | Research output captured to KB (this skill does it directly) |

---

## Verification Checklist

Before returning research output:

- [ ] ≥4 sources with URLs
- [ ] Each library/tool has recency signal (last commit, latest release)
- [ ] Anti-pattern search completed
- [ ] Comparison matrix uses same dimensions per option
- [ ] Recommendation references project constraints explicitly
- [ ] Cache file has full frontmatter with TTL
- [ ] INDEX.md updated with freshness badge
- [ ] Git committed + pushed to KB repo
