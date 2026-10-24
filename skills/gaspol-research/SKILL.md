---
name: gaspol-research
description: "Use when evaluating external libraries, APIs, patterns, or approaches that are unfamiliar or where training data may be outdated. Performs structured deep research with multi-source citation, anti-hallucination safeguards, and freshness-aware caching to cross-project knowledge base."
---

<!-- model-tier: exec — gathering is execution: Firecrawl finds and reads pages, notebooklm indexes and answers. Read by skills/gaspol-verify/scripts/model-gate. -->

# gaspol-research

## Iron Law

```
NO RESEARCH CLAIMS WITHOUT SOURCE CITATION + CACHE DECISION
```

Every claim needs a URL or file:line reference. Every research output gets cached to KB with TTL. Never rely solely on training memory for industry-current state — verify via `firecrawl_scrape`.

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
- Simple fact lookup (use `firecrawl_search` directly)
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

**Ownership guard (IDS-8):** before these git commands run, compare `$KB` against
`git -C "$KB" rev-parse --show-toplevel`. A mismatch means the store is a guest inside a repo
gaspol **does not own** — a vault, a monorepo — so the write-side git operations are refused with
`kb-sync: skipped — KB lives inside a repo gaspol does not own (<toplevel>)` and reads continue.
Full snippet and rationale: `skills/_shared/kb-path.md`.

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it the resolver would be taken from whatever repo happens to be open, and its stdout becomes the path gaspol commits}"
KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")"; rc=$?
case $rc in
  0) : ;;                                                    # available
  3) echo "knowledge-store: UNKNOWN — configured path unreadable"; exit 1 ;;
  4) echo "knowledge-store: none — not configured"; KB="" ;;  # research without precedent
esac
# rc=3 STOPS and rc=4 CONTINUES. A read finds nothing either way, but only one of
# them is honest about WHY, and "no store" must never be reported as "no precedent".
# rc=4 creates nothing here: this block only reads, and an empty directory nobody
# asked for is not a store.
if [ -n "$KB" ]; then
  REMOTE="${GASPOL_KB_REMOTE:-$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/gaspol-config.json"))).get("kb_remote",""))' 2>/dev/null)}"
  [ -n "$REMOTE" ] && git -C "$KB" pull --quiet || true   # synced mode only
  # Grep the flat notes for matching tags: grep -ril "<tag>" "$KB"/*.md
fi
```

If cache hit found:
- Check age → freshness tier (🟢/🟡/🟠/🔴)
- Present to user via AskUserQuestion:
  - `[Use cached as-is]` (if FRESH)
  - `[Verify freshness — mini research]` (if AMBER)
  - `[Re-research — cache stale]` (if STALE)
  - `[Force full re-research]` (always available)

If no cache, proceed to Phase 3.

### Phase 3: Gather with Firecrawl, synthesize with notebooklm

Two tools, no others. Firecrawl finds and reads pages. The `notebooklm` CLI indexes the sources and answers with citations. **There is no fallback to `WebSearch` or `WebFetch`**: if either tool is missing, research does not run.

1. **Tool check.** Run `notebooklm doctor`, and confirm the Firecrawl MCP tools (`firecrawl_search`, `firecrawl_scrape`) are present in this session. Either one missing or unauthenticated: state `research-tools: UNKNOWN — <which one>`, **STOP and ask**, and name the fix (`notebooklm login`; enable the Firecrawl MCP). Never degrade to another search tool.
2. **Notebook.** Run `notebooklm list`. If a notebook for this topic exists, reuse it (`notebooklm use <id>`). Otherwise run `notebooklm create "gaspol-research: <topic>" --use`.
3. **Collect candidate URLs** with `firecrawl_search`, one query per lane:
   - official documentation and home page
   - GitHub repository (stars, last commit, open-issue trend)
   - comparisons and benchmarks ("X vs Y")
   - anti-pattern check ("problems with X", "X deprecated", "X alternatives")
   - case studies and migration stories

   Read freshness-critical pages (release notes, pricing, deprecation notices, repo metrics) with `firecrawl_scrape` and `maxAge: 0`, so a cached copy is never mistaken for current state.
4. **Add sources.** For each candidate, run `notebooklm source add <public url>`, then `notebooklm source wait <source-id>` (the id is printed by `source add`).
   - **Only PUBLIC URLs become sources.** NotebookLM is an external service. Never add project files, secrets, credentials, internal URLs, or private repo contents.
5. **Synthesize.** Run `notebooklm ask "<prompt>"` with a prompt that demands a cited comparison: options, a matrix on the same dimensions per option, a recommendation tied to the constraints from Phase 1, and an inline citation for every claim.

Only the `ask` answer and one status line per source enter the conversation. Page bodies stay in Firecrawl and NotebookLM.

**Error paths — each is a step, not a footnote:**

| Event | Action |
|---|---|
| `source add` fails for a URL (paywall, blocked, timeout) | Record `not added — <reason>` for that source and continue. If fewer sources remain than the Phase 5 minimum, report the gap and **STOP**. |
| `notebooklm source wait` times out (exit 2) or fails (exit 1) | Report the sources still processing. Do not synthesize from a partial set silently. |
| `ask` returns claims without citations | Reject the answer under the Phase 5 citation gate, re-ask once, then report the failure. |
| Firecrawl credits exhausted or rate-limited | **STOP** and relay Firecrawl's own message verbatim. |
| `notebooklm` reports expired auth | **STOP** and ask the user to run `notebooklm login`. |

6. **Agent-skill marketplace** — `npx skills find "<topic>"` (skills.sh). "Somebody
   already packaged this as an agent skill" is a research finding like any other,
   and the cheapest recommendation available. Report it as a candidate with its
   source and install count; never install it as part of research (install rules:
   `skills/_shared/prior-art-gate.md`). If the CLI is unavailable, say so — an unrun
   lane is reported as unrun, never as empty.

### Phase 4: Validate and Record the Answer

Validate the `notebooklm ask` answer and shape it into:

- Context (what decision this informs)
- Options considered (name, summary, sources)
- Comparison matrix (feature/cost/community/maintenance)
- Recommendation (with project-fit reasoning)
- Open questions (things research couldn't resolve)
- Sources (complete URL list with fetch dates, including every `not added — <reason>` line)

Do not add claims the answer did not make. A claim you want to add needs its own source first.

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

Write to `<KB_ROOT>/YYYY-MM-DD-<slug>.md` — flat, no category directory; the category becomes the first tag. `status: proposed`, never `accepted` — promotion is the human gate's call, not the skill's. Shape below must keep frontmatter + `# Title` + `tags: [...]`, which is what `superbrain-promote`'s scan reads:

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

No index is written. The freshness badge lives in the note's own frontmatter (`date:`), which is where a reader computes the tier from — an index gaspol must keep in sync is a drift source with no reader.

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
1. `firecrawl_scrape` each cached source URL with `maxAge: 0` → check last-updated date
2. `firecrawl_search` "[topic] 2026" → check breaking changes
3. No change → bump `researched_at`, extend `expires_at`
4. Change detected → full re-research, old cache marked `superseded_by: <new-id>`

---

## Anti-Hallucination Measures

1. **`firecrawl_scrape` the actual page** (`maxAge: 0`) for claims critical to decision — don't cite from memory
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
| Fabricated benchmark numbers | `firecrawl_scrape` the actual comparison pages |
| Training-data citation ("in 2024 React Hooks were popular") | Replace with a current-year `firecrawl_search` |
| Skipping quality gate check | All gates must pass before caching |
| Recommending a build when a packaged skill already does it | Run the marketplace lane before recommending; report the candidate |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-brainstorm` Phase 1.5 | Auto-invoked when novelty = NEW |
| `gaspol-adr` | Research verdict captured as ADR input |
| freshness tiers (in this skill) | Every cached entry carries its age tier; a stale entry is re-fetched at read time rather than swept on a schedule |

---

## Verification Checklist

Before returning research output:

- [ ] ≥4 sources with URLs
- [ ] Each library/tool has recency signal (last commit, latest release)
- [ ] Anti-pattern search completed
- [ ] Comparison matrix uses same dimensions per option
- [ ] Recommendation references project constraints explicitly
- [ ] Cache file has full frontmatter with TTL
- [ ] Freshness derivable from the note's own `date:` frontmatter — no index to update
- [ ] Git committed + pushed to KB repo
