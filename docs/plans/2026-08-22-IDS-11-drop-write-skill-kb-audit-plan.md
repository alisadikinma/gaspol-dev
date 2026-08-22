**Ticket:** IDS-11
**Artifact:** https://claude.ai/code/artifact/2be9bfdd-a156-442c-a2dc-ba57fec50830
**Spec:** [2026-08-22-IDS-11-drop-write-skill-kb-audit-spec.md](2026-08-22-IDS-11-drop-write-skill-kb-audit-spec.md)
**Ledger:** `.gaspol/progress/PROGRESS-IDS-11.md`
**Execute with:** `gaspol-execute`

# Plan — drop two skills, rescue one gate

## Goal

Remove `gaspol-write-skill` and `gaspol-kb-audit` without leaving a single dangling reference, and
without losing the supply-chain rules or the KB promotion path that happened to live inside them.

## Data Integration Map

| Feature | Data Source | Read by | Exists? | Action |
|---|---|---|---|---|
| Prior-Art Gate | `skills/_shared/prior-art-gate.md` | brainstorm 1.5, research lane 6 | no | extract from write-skill Step 0 |
| KB promotion gate | `superbrain-promote` (vault) or manual | learn / adr / research | yes (outside gaspol) | repoint, honestly |
| Skill count | filesystem `skills/*/` | 4 test scripts, CLAUDE.md, README | yes | 20 → 17 |
| Eval rule | `gaspol-plan` + `gaspol-verify`, inline | planner, verifier | yes | kept, skill dropped |

## Checklist

- [x] Phase A — extract the Prior-Art Gate to `_shared/`, repoint both referrers
- [x] Phase B — delete `gaspol-write-skill`, clean 14 reference sites
- [x] Phase C — delete `gaspol-kb-audit` AND `gaspol-llm-test`, repoint the promotion path and the eval rule
- [x] Phase D — docs, counts, version 1.21.0, suite green

## Phase A: Rescue the Prior-Art Gate

1. Write failing test: `skills/_shared/prior-art-gate.md` exists, carries all three lookups, the
   three verdicts, and every install rule verbatim (`-y` forbidden, AskUserQuestion, read the
   SKILL.md, install count is not an audit, standing context cost). Expected error: file not found.
2. Extract Step 0 from `gaspol-write-skill/SKILL.md`; generalise the framing from "before any skill
   is written" to "before anything is built in-house", keeping the skill-install subsection intact.
3. Repoint `gaspol-brainstorm:210` and `gaspol-research:103` to the new path.
4. Rewrite `tests/ticket-scripts/test-prior-art-gate.sh` to assert against `_shared/`, not the skill.

**Verification:** `test-prior-art-gate.sh` exits 0 with `gaspol-write-skill` still present, proving
the extraction is complete before anything is deleted.

## Phase B: Delete gaspol-write-skill

1. `git rm -r skills/gaspol-write-skill`.
2. Clean: `hooks/session-start.sh:33`, `using-gaspol` routing table + Meta list, `CLAUDE.md`
   (7 sites), `README.md` (4 sites), `tests/README.md` (2), `tests/description-audit.sh:7`.
3. Delete `tests/ticket-scripts/test-reference-loading.sh` — it tests only that skill's reference
   files. Deleting the subject means deleting the test, not neutering it.

**Verification:** `grep -r gaspol-write-skill` over live paths returns nothing.

## Phase C: Delete gaspol-kb-audit

1. `git rm -r skills/gaspol-kb-audit`.
2. **Repoint the promotion path first** — `gaspol-learn:232,259`, `gaspol-adr:239`,
   `gaspol-research:226`: promotion is the human gate, named as `superbrain-promote` where a vault
   is configured, manual otherwise. Never a dangling skill name.
3. Clean: `hooks/session-start.sh:37`, `using-gaspol` (2), `_shared/kb-path.md:4`, `CLAUDE.md`
   (9 sites incl. the KB Self-Maintenance section and the health thresholds), `README.md:105`.
4. Update `test-kb-no-hardcoded-path.sh:116` skill list and `test-skill-frontmatter.sh`'s comment.
5. `test-ids8-docs.sh:49` asserts CLAUDE.md records the overlap as *deferred*. Change the assertion
   to record that it was **resolved by deletion** — keep the assertion, change what it asserts.

**Verification:** `grep -r gaspol-kb-audit` over live paths returns nothing; no skill promises a
promotion route that does not exist.

## Phase D: Docs, counts, version

1. Skill count 20 → 17 in CLAUDE.md, README.md, and the `gaspol-one` marketplace description.
2. CLAUDE.md: remove the "KB Self-Maintenance" section and the audit-overdue debugging row; add an
   IDS-11 note recording WHY both were removed, so the next reader does not rebuild them.
3. Version 1.21.0 in `plugin.json`, CLAUDE.md footer, CHANGELOG.
4. Run the whole suite.

**Verification:** every test green; `marketplace-manifest` gate agrees on 1.21.0.

## Red Flags

- Deleting `test-reference-loading.sh` is correct (its subject is gone). Deleting
  `test-prior-art-gate.sh` would NOT be — its subject survives, relocated.
- A reference "cleaned" by deleting the sentence around it can silently drop a real rule. Every site
  is either repointed or explicitly judged unnecessary; none is deleted for tidiness.
