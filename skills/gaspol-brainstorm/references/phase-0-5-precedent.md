# Phase 0.5 detail: precedent query

Moved verbatim from `SKILL.md`. Read it when the body sends you here.

## Rationale

**Why bounded now runs it too (IDS-8).** This phase used to be architectural-only. Bounded fixes are
the majority of day-to-day work and are exactly where a documented gotcha gets re-hit — the
mechanism behind "we solved this already and did it wrong again". A grep over an index-free set of
notes is cheap; re-making a recorded mistake is not.

**Spike stays exempt**, deliberately. A feasibility probe answers a question and keeps no code, so
there is no precedent to apply to it. Widening this gate to *every* path would be a different,
unrequested change.


## Status filter and freshness

4. **Filter by status** — show `proposed` **and** `accepted`. `proposed` is not a lesser tier here: gaspol writes `proposed` exclusively (promotion belongs to the human gate), so filtering it out would hide every capture from the query built to find it. Mark the tier when surfacing so the user can weigh a promoted note above a pending one.
5. **Freshness check** — for research/ entries, check age tier (🟢 FRESH / 🟡 AMBER / 🟠 STALE / 🔴 EXPIRED)

## Surfacing template and the user's choices


```
Found relevant past work:
  • [image-generation-ui](ui-patterns/image-generation-ui.md)
    Tags: [image-gen, gallery, 3-pane]
    Source: <project> 2026-03 — 🟢 accepted
    Hook: 3-pane layout (prompt + preview + history) works best

  • [ADR-2026-02-10: state-mgmt-zustand](design-decisions/...)
    Tags: [state-management, react]
    🟢 accepted, last_validated: 2026-03-15

[Apply precedent — use as reference]
[Override with reason — capture divergence ADR]
[Skip precedent — start fresh]
```

If user chooses "Override with reason":
- Prompt for 1-2 sentence reason
- Call `gaspol-adr` to capture divergence ADR with `diverges_from: <precedent-id>`
- Old precedent NOT superseded — both coexist

If user chooses "Skip precedent":
- Proceed without applying past patterns
- No ADR captured

If no KB matches, proceed silently to Phase 1.

Saves additional 10-30k tokens per session by avoiding re-exploration of solved problems.
