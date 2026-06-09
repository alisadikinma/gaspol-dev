---
name: gaspol-kb-audit
description: "Use quarterly, on-demand, or auto-triggered when KB size exceeds 500 entries. Scans knowledge base for stale entries, duplicates, conflicts, orphans, and broken references. Generates audit report with per-finding resolution options (archive, merge, supersede, keep)."
---

# gaspol-kb-audit

## Iron Law

```
KB ACCUMULATION WITHOUT AUDIT = POLLUTION
```

KB tumbuh tanpa maintenance = stale precedents surfaced as current, duplicates causing inconsistency, broken references linking to archived entries. Audit periodic keeps KB self-curating, not just accumulating.

---

## Core Principle

Every KB entry has a shelf life. Some patterns become outdated (framework evolution), some get superseded (better pattern discovered), some were project-specific (shouldn't generalize). Audit detects these conditions and surfaces them for user decision — not auto-deleting, but bringing to attention.

## When to Use

- **Scheduled**: Quarterly (manual or cron). User invokes `/gaspol-kb-audit`.
- **Size-triggered**: Auto-offer audit when KB INDEX.md entry count > 500.
- **Pre-brainstorm hint**: If last audit > 90 days, brainstorm Phase 0 suggests running audit.
- **Post-major-shift**: After framework version bump or major dependency change, audit entries tagged for affected tech.

## When NOT to Use

- KB very small (<50 entries) — low maintenance value
- Audit run within last 30 days (too frequent)
- No KB initialized (Phase A not resolved)

---

## Process Flow

### Step 1: Scope

Use AskUserQuestion to determine audit scope:

```
Audit scope?
  [Full audit — all entries]
  [Category audit — pick one: ui-patterns, architecture, design-decisions, research, reusable-snippets]
  [Domain audit — pick domain: auth, state-management, image-gen, ...]
  [Since last audit only — incremental]
```

### Step 2: Scan Entries in Scope

Read all entries matching scope. For each, run these checks:

#### Check 1: Stale (status: accepted, last_validated > 180 days)

```
Status: accepted
last_validated: 2025-10-01 (198 days ago)
→ Flag as STALE
```

#### Check 2: Duplicate Detection

Compare entries pairwise within same category:
- Title Levenshtein distance < 20% → likely duplicate
- Tag overlap ≥80% AND similar content (cosine similarity on body) → duplicate

Report pairs for merge/consolidation decision.

#### Check 3: Conflict Detection

Entries with same tag+domain but different verdicts:
```
ADR-2026-01-08: "Use React Query for data fetching" (tags: [data-fetching, react])
ADR-2026-03-22: "Use SWR for data fetching" (tags: [data-fetching, react])
→ CONFLICT: same tag, different verdicts
```

Not auto-resolved — user decides: supersede, keep-both-with-context-tags, merge.

#### Check 4: Orphan Detection

Entries tagged for tech that no active project uses:
- Extract all project names from frontmatter `source_project` fields
- Compare to active project directories (heuristic: `d:/Projects/*` dirs)
- If source_project no longer exists locally → flag orphan

#### Check 5: Broken References

For each entry with `supersedes: <id>` or `superseded_by: <id>` or `related: [<ids>]`:
- Verify referenced entry exists
- If not found → broken ref

#### Check 6: Missing Validation (proposed entries)

Entries with `status: proposed` > 90 days without promotion to `accepted`:
- Either entry never validated in a second project (should be archived)
- Or user forgot to promote after reuse (should be accepted)

### Step 3: Generate Audit Report

Write to `~/.claude/gaspol-knowledge/_audit/audit-YYYY-MM-DD.md`:

```markdown
# KB Audit Report — 2026-04-17

**Scope:** Full audit
**Entries scanned:** 127
**Issues found:** 23

## Summary by Type

| Type | Count | Severity |
|---|---|---|
| Stale | 12 | Medium |
| Duplicates | 3 pairs | Medium |
| Conflicts | 2 pairs | High |
| Orphans | 5 | Low |
| Broken refs | 1 | High |
| Unpromoted proposed | 7 | Low |

## Details

### Stale (accepted >180 days without validation)

- **[zustand-vs-redux](research/zustand-vs-redux.md)** — last_validated 2025-10-01 (198 days)
  Options:
  - [Verify freshness (mini-research)]
  - [Full re-research]
  - [Mark deprecated]
  - [Keep as-is, bump last_validated]

- ...

### Duplicates

- **[image-gen-ui-a](ui-patterns/image-gen-ui-a.md)** ↔ **[image-gen-ui-b](ui-patterns/image-gen-ui-b.md)**
  Title overlap: 87%
  Tag overlap: 100% ([image-gen, gallery, 3-pane])
  Options:
  - [Merge into single entry]
  - [Differentiate tags]
  - [Supersede one with the other]

- ...

### Conflicts

- **ADR-2026-01-08** (React Query) vs **ADR-2026-03-22** (SWR)
  Both tagged [data-fetching, react], accepted.
  Options:
  - [Supersede older with newer]
  - [Differentiate by context tags (SSR-needed vs no-SSR)]
  - [Capture as divergence ADR documenting both]

- ...

### Orphans

- **[laravel-forge-deployment](architecture/laravel-forge-deployment.md)**
  source_project: old-portfolio-v1
  Local dir d:/Projects/old-portfolio-v1/ not found.
  Options:
  - [Archive (move to _archive/)]
  - [Update source_project to current project]
  - [Keep as historical reference]

### Broken Refs

- **ADR-2026-02-10** references `superseded_by: ADR-2026-05-15-nonexistent`
  Target entry not found in KB.
  Options:
  - [Remove broken ref]
  - [Find correct target]
  - [Restore archived target]

### Unpromoted Proposed

- **[custom-hook-pagination](reusable-snippets/custom-hook-pagination.md)**
  status: proposed, 127 days old, never reused.
  Options:
  - [Promote to accepted (you've used it in another project)]
  - [Archive (wasn't actually reusable)]
  - [Keep as proposed, extend validation window]
```

### Step 4: Interactive Resolution

For each finding, use AskUserQuestion with per-finding options. Apply chosen action:

- **Promote**: update status frontmatter `proposed` → `accepted`
- **Supersede**: old gets `superseded_by: <new-id>`, new gets `supersedes: <old-id>`, both stay in KB
- **Archive**: move file to `_archive/<category>/<slug>.md`, remove from INDEX.md (but audit trail retained in git history)
- **Merge**: consolidate body content, delete one file, update INDEX.md
- **Keep**: update `last_validated: YYYY-MM-DD` without other change

### Step 5: Commit Changes

Batch commit with audit message:

```bash
git add .
git commit -m "$(cat <<'EOF'
audit: KB maintenance 2026-04-17

Resolved 23 findings:
- 12 stale entries: 8 validated, 4 archived
- 3 duplicate pairs: 2 merged, 1 differentiated
- 2 conflicts: 1 superseded, 1 divergence ADR captured
- 5 orphans: 5 archived
- 1 broken ref: corrected
- 7 unpromoted: 3 promoted, 4 archived

Health score: 🟢 GREEN (was 🟡 YELLOW pre-audit)
EOF
)"
# push only in synced mode — see docs/kb-setup.md; local-only audits stay local with no error
[ -n "$REMOTE" ] && git push --quiet || true
```

### Step 6: Update Health Metrics

Track in `~/.claude/gaspol-knowledge/_audit/health-metrics.md`:

```markdown
# KB Health Metrics

| Date | Total | Accepted | Proposed | Superseded | Deprecated | Stale % | Dup % | Broken Ref % | Score |
|---|---|---|---|---|---|---|---|---|---|
| 2026-01-15 | 89 | 72 | 12 | 4 | 1 | 8% | 3% | 0% | 🟢 |
| 2026-04-17 | 127 | 108 | 14 | 4 | 1 | 2% | 0% | 0% | 🟢 |
```

Health thresholds:
- 🟢 Green: <10% stale, <5% duplicates, <2% broken refs
- 🟡 Yellow: 10-25% stale OR 5-15% duplicates → audit recommended
- 🔴 Red: >25% stale → mandatory audit blocks new captures until cleaned

---

## Red Flags

| Red Flag | Fix |
|---|---|
| Auditing without user interaction (silent bulk delete) | Reject — every finding needs user approval |
| Archive without git audit trail | Always commit archival action (don't just delete) |
| Conflict auto-resolved without user | Conflicts always need user decision |
| Health threshold ignored (RED state) | Block new captures until audit run |
| Audit report not committed | All audit results must be committed for traceability |

---

## Integration

| Skill | Interaction |
|---|---|
| `gaspol-brainstorm` Phase 0 | Suggests audit if last one >90 days |
| `gaspol-learn` | Proposed entries become audit candidates at 90 days |
| `gaspol-research` | Freshness tiers inform stale detection |
| `gaspol-adr` | Supersession handling shared with audit |
| Local KB (default) or git remote `$GASPOL_KB_REMOTE` (synced mode) | All audit actions committed locally; pushed only in synced mode — see [docs/kb-setup.md](../../docs/kb-setup.md) |

---

## Verification Checklist

Before completing audit:

- [ ] All scoped entries scanned (count matches)
- [ ] Every finding has user decision
- [ ] Archives moved to `_archive/`, not deleted
- [ ] Supersede links bidirectional
- [ ] INDEX.md updated
- [ ] Audit report written to `_audit/audit-YYYY-MM-DD.md`
- [ ] Health metrics updated
- [ ] Git committed with descriptive message
- [ ] Committed locally (always); pushed to remote KB repo only if in synced mode (see [docs/kb-setup.md](../../docs/kb-setup.md))
