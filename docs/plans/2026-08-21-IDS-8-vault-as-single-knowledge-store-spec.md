**Ticket:** IDS-8

# IDS-8 — One knowledge store: gaspol feeds the vault's existing pipeline instead of running a second one

## Why this exists

The owner's words: *"seharusnya ini merge dgn obsidian vault biar gak 2x kerja… saya lebih percaya
dgn obsidian vault."*

That is not a preference. It is a correct reading of a duplication this repo created and never
noticed, and the evidence below is dated **today**.

## What the audit found (2026-08-21)

Every finding was produced by running a command, not by inference. Where a probe was used, it
carries a positive control — the first version of this audit's probe returned ten blank rows and
would have "proved" zero duplicates while actually being broken. That failure is itself an
instance of KB entry `vacuous-assertion-proves-nothing`, and it is why controls appear below.

**E1 — two extractors harvest the same session, on the same day.**
A SessionStart hook `~/.graphify/memory-extract.sh` has been writing session learnings to
`90-Inbox/agent-learnings/` since 2026-07-05 (`.rejected-log` records the runs; 62 notes are
pending). `gaspol-learn` writes the same class of lesson to `~/.claude/gaspol-knowledge/`. On
2026-08-21 both fired on the same material:

| Store | File |
|---|---|
| gaspol KB | `architecture/search-the-market-before-building-a-capability.md` (`status: accepted`) |
| vault inbox | `2026-08-21-title-prior-art-gate-for-skill-development.md` (`status: proposed`) |
| vault inbox | `2026-08-21-market-search-before-building-is-a-gating-decision.md` |
| vault inbox | `2026-08-21-supply-chain-stance-soft-route-never-hard-dependen.md` |

One lesson, four files, two pipelines. This is the "2x kerja".

**E2 — the knob that was supposed to prevent this is documented and never read.**
`kb_local` appears in `README.md`, `CLAUDE.md`, and `docs/kb-setup.md` as the way to relocate the
KB. Grep for it under `skills/`: **0 hits**. Grep for `gaspol-config` under `skills/`: **0 files**.
No skill reads the config file at all. Only the environment variables `GASPOL_KB_LOCAL` (3 hits)
and `GASPOL_KB_REMOTE` (4 hits) are honoured.

This is defect class D1 from IDS-7 — a setting parsed into documentation and consulted by nothing —
recurring one layer up. The relocation this ticket needs was *supposed* to already be possible.

**E3 — precedent lookup is switched off for exactly the work that repeats mistakes.**
`gaspol-brainstorm` Phase 0.5 is headed *"architectural path only"*. Bounded fixes and spikes —
the majority of day-to-day work, and the place a known gotcha is most likely to be re-hit — never
query the knowledge base at all.

**E4 — a latent hazard that must be closed in the same change.**
In synced mode the KB skills run `git pull` / `git commit && git push` **inside the KB directory**.
The vault is a git repository. The moment the KB root points anywhere inside it, those commands
operate on the *vault* repo — gaspol would commit and push the owner's entire second brain
unasked. Currently inert (no `gaspol-config.json` exists, so mode is local-only), it arms itself
the day `kb_remote` is set. A hazard that only fires later is still this change's responsibility.

**E5 — against the vault CORE there is no content duplication; the overlap is in the inbox.**
Ten topic probes of the 18 KB entries against the whole vault returned nil for the curated core,
with positive controls hitting (`superbrain-promote` → 23 files, `Per-stack conventions` → 1).
The only matches were in `90-Inbox/agent-learnings/` (E1) and in project READMEs. So the 18 entries
are *not* redundant content — they are a redundant *pipeline*.

## Prior-art verdict (gaspol-write-skill Step 0, three lookups)

| Lookup | Result |
|---|---|
| Installed already? | **`superbrain-promote`** (`~/.claude/skills/`, the owner's private tooling) performs scan → cluster → per-cluster human decision → apply → audit log, with a routing table, dedup-before-append, and a contradiction check. `~/.graphify/memory-extract.sh` performs capture. |
| Built into the harness? | No built-in knowledge store or promotion command. |
| On the marketplace? | Not probed — the capability is already installed twice; a third source would not change the verdict. Recorded as **not run**, not as empty. |

**Verdict: DELTA, and the delta cuts both ways.**

`superbrain-promote`'s own SKILL.md says it *"mirrors the STRUCTURE of gaspol-kb-audit … but is
Ali's PRIVATE tooling — no gaspol-dev dependency."* The duplication was deliberate when written and
is now being collapsed.

What each side genuinely contributes, after the merge:

| Capability | Owner after this ticket | Why |
|---|---|---|
| Session-end capture | `memory-extract.sh` (vault) | Already running, already trusted |
| Ship-time capture with a quality gate (≥200 words, tags, status, dedup) | **gaspol-learn / adr / research** | The vault extractor has no quality gate; this is gaspol's real contribution |
| Promotion into the curated core | **`superbrain-promote`** — sole promoter | Human-gated, has routing + conflict check. gaspol must not bypass it |
| Read at design time | **gaspol-brainstorm** | Nothing on the vault side reads back into a brainstorm |
| Periodic KB health audit | **open question — see Deferred** | `gaspol-kb-audit` and `superbrain-promote` now overlap almost exactly |

## Design

### Part 1 — one path resolver, and it actually reads the config

A single documented resolution order, implemented once and referenced by every KB skill, mirroring
the existing `skills/_shared/laziness-ladder.md` precedent:

```
$GASPOL_KB_LOCAL  >  "kb_local" in ~/.claude/gaspol-config.json  >  ~/.claude/gaspol-knowledge
```

Middle rung is new — it closes E2. The 16 prose sites under `skills/` that spell
`~/.claude/gaspol-knowledge/` literally are the load-bearing fix: the environment variable can be
correct while the prose an agent actually reads still names the old folder.

**The config file is the durable mechanism, not the environment variable** (found during spec
self-review). `$GASPOL_KB_LOCAL` exported from a shell profile only exists for processes that
inherited that shell. Anywhere it does not, local-only mode **auto-initialises the default
directory** — and `~/.claude/gaspol-knowledge/` grows back, recreating the exact duplication Part 6
just deleted. So the relocation is written to `~/.claude/gaspol-config.json`, which every process
reads from disk; the environment variable stays as an override for CI. Part 6 is not complete until
a run with a clean environment resolves to the vault, asserted rather than assumed.

### Part 2 — write into the quarantine, in the quarantine's own format

Write target is the resolved KB root. On this machine that is
`<vault>/90-Inbox/agent-learnings/` (owner decision, 2026-08-21).

The notes must be **flat files matching the extractor's existing shape**, because
`superbrain-promote`'s scan reads frontmatter + H1 and must consume gaspol's output with **zero
changes on its side**:

```markdown
---
status: proposed
date: 2026-08-21
source: gaspol-learn (<project> <TICKET>)
---

# <Title>
tags: [<tag>, <tag>]

<body — the quality gate still applies: ≥200 words, concrete incident, no speculation>
```

Consequence, stated rather than discovered later: the four category directories
(`architecture/`, `design-decisions/`, `research/`, `reusable-snippets/`) stop being directories.
Category survives as a tag. Routing to a final home is `superbrain-promote`'s job and it already
has the table for it.

`status` is `proposed`, never `accepted` — gaspol no longer grants itself promotion. Only the
human gate does.

### Part 3 — read the whole second brain at design time

`gaspol-brainstorm` Phase 0 reads the target project's `CLAUDE.md`. It gains a vault read using
the owner's own documented order, stopping as soon as it has enough:
`INDEX.md` → `hot.md` → `10-Identity/` (identity work only) → `20-Projects/<name>/README.md` →
`30-Knowledge/`.

And Phase 0.5 loses the words **"architectural path only"** (closes E3). A grep against an index is
cheap; re-hitting a documented gotcha is not. Spike keeps its exemption — a feasibility probe that
answers a question and keeps no code has nothing to look precedent up for.

### Part 4 — no vault, no failure

A missing vault is reported, pointed at, and stepped over — never a hard error. This is the exact
soft-reference pattern the repo already applies to `ui-ux-pro-max`, and the reason is unchanged: a
public plugin must not make twenty unrelated skills depend on one third-party thing.

| State | Behaviour |
|---|---|
| Vault resolved and readable | Full read + write |
| No vault configured | `knowledge-store: none — vault not configured`. Say what Obsidian gives them, name the setting, continue. **Not a failure.** |
| Configured but unreadable/absent | `knowledge-store: UNKNOWN` → **STOP and ask.** A broken path must never degrade into "nothing found", which reads as "no precedent exists". |

The third row is KB precedent `marker-file-is-not-proof-tool-installed` applied verbatim. It is the
same three-state discipline IDS-7 used for `DESIGN.md`, and the same reason: an empty result and a
broken lookup must never print the same thing.

### Part 5 — gaspol never commits a repository it does not own

Closes E4. Before any git operation, compare the KB root against
`git -C <kb_root> rev-parse --show-toplevel`. If the repository's top level is **not** the KB root,
the KB is a guest inside somebody else's repository: refuse `commit`/`push`, record
`kb-sync: skipped — KB lives inside a repo gaspol does not own (<toplevel>)`, and continue. Reads
stay allowed.

### Part 6 — migrate the 18 existing entries through the existing routing table

Not a bulk move. Each entry is routed with `superbrain-promote`'s own targets, and deduped against
the 62 pending inbox notes first (E1 proves the overlap is real):

| Entries | Route |
|---|---|
| 7 × `architecture/`, 3 × `reusable-snippets/` | `30-Knowledge/coding-workflow-patterns.md` — its `## Review lessons` and `## Per-stack conventions` are the declared landing zones |
| 5 × `design-decisions/` | `20-Projects/<name>/` — four are project-specific (driver attendance, simulated clock, LinkedIn ingest, video worker); the B2B deck spine is judged against `deck-b2b-standard.md` |
| 2 × `research/` (`status: proposed`) | quarantine, to be judged by the human gate like any other note |

Duplicates found during this pass are **deleted, not kept in both places** — `superbrain-promote`'s
own iron rule: *"No note in two places."* Vault git history is the archive.

`~/.claude/gaspol-knowledge/` is removed once the routing is done. Its 5 commits of history are
lost; the value is negligible and the vault is itself a git repository, so history continues there.
Stated because it is a real loss, not zero.

### Part 7 — graphify: keep the code index current, from the slot that already exists

Both brains go stale the same way, so both are refreshed from the chain rather than from a new
skill. The WHY brain (vault) is written by Part 2; the HOW brain (graphify / CodeGraph) is
refreshed here.

**Where:** `gaspol-sync-docs`, which already owns "update the documentation after code changed".
`gaspol-finish` calls it at Step 5, so no new gate is introduced anywhere.

**Detection carries no configuration at all.** A `graphify-out/` directory at the target project
root IS the opt-in — the owner created it deliberately. Nothing is written into a repository that
does not already have one.

| State | Behaviour |
|---|---|
| `graphify-out/` present **and** `graphify` on PATH | Run `graphify update .`, record `graphify: updated` |
| `graphify-out/` present, CLI missing | `graphify: UNKNOWN — index present, CLI missing` → **STOP and ask.** A stale index that reports clean is worse than an absent one |
| No `graphify-out/` | Skipped silently. **Not a failure**, and not recorded as passed |

`graphify update` is AST-only and costs no API calls, which is why it can run unattended where a
model-driven step could not.

**The federated brain is offered, never taken.** Refreshing the cross-project graph
(`graphify global add <path>/graphify-out/graph.json --as <tag>`) writes outside the current
repository, into `~/.graphify/`. That crosses a boundary the project-local update does not, so it
is an `AskUserQuestion`, consistent with how `extract-design-tokens` offers a `DESIGN.md` write
rather than taking it.

**No MCP is required for either brain.** The vault is markdown on disk and is read with ordinary
file tools; graphify is a CLI. Requiring an MCP server to be configured would fail laziness-ladder
rung 3 (a native capability already does it) and would add a second way for the feature to be
"installed but not working".

## Data Integration Map

| Feature | Data source | Exists? | Action |
|---|---|---|---|
| KB root resolution | `$GASPOL_KB_LOCAL`, `~/.claude/gaspol-config.json` | Env yes / config key **read by nothing** | Implement the config rung |
| Capture destination | `<vault>/90-Inbox/agent-learnings/` | Yes — 62 notes, live since 2026-07-05 | Write into it, in its own format |
| Promotion | `~/.claude/skills/superbrain-promote/` | Yes | Leave untouched — it stays sole promoter |
| Design-time read | vault `INDEX.md`, `hot.md`, `30-Knowledge/`, `20-Projects/` | Yes | Read only |
| Existing gaspol entries | 18 files in `~/.claude/gaspol-knowledge/` | Yes | Route + dedup + delete source |
| Git ownership check | `git rev-parse --show-toplevel` | Yes (git) | Wire into the sync guard |
| Code-index refresh | `graphify-out/` + `graphify` CLI in the target repo | Varies per project | Run `graphify update .` from sync-docs when both present |
| Federated code brain | `~/.graphify/global-graph.json` | Yes (this machine) | **Offer** `graphify global add`, never automatic |

No placeholders: every input is a real file, a real command, or a real environment variable.

## Scope boundary — stated so it is not overclaimed later

This merges **gaspol's knowledge capture** into the vault pipeline (WHY brain) and keeps the
graphify code index current from the chain (HOW brain, Part 7). The two stay separate stores with
separate purposes — nothing here merges them into each other. It does **not** touch:

- `~/.claude/projects/<…>/memory/` — Claude Code operational feedback, whose boundary the global
  CLAUDE.md already defines
- `memory-extract.sh` itself — it keeps running exactly as it does now

Two capture sources feeding one quarantine is the intended end state, not a remaining defect. The
duplication being removed is *two stores*, not *two extractors*.

## Deferred, with a name

`gaspol-kb-audit` now overlaps `superbrain-promote` almost completely — both are
scan → cluster → per-finding human decision → apply → audit log. Deleting or narrowing it is the
honest follow-up, and it is the same call v1.14 made when a 1.4MB `gaspol-design` fork was deleted
rather than left to drift. It is **not** done in this ticket: `gaspol-kb-audit` is public and
agnostic while `superbrain-promote` is private and hardcoded to one vault, so the replacement is
not like-for-like. Recorded as an open question, not silently left alone.

## Risks

| Risk | Mitigation |
|---|---|
| gaspol floods the inbox and buries the 62 pending notes | The ≥200-word quality gate stays, `status: proposed` stays, and capture stays per-shipped-feature — not per-session |
| The env var is set but skills still write to the old path | Part 1's 16 prose sites are the actual fix; a test asserts no skill names the literal default without the resolver |
| gaspol commits the vault | Part 5, plus a test that the guard exists |
| Migration loses an entry | Route file-by-file against the routing table; delete a source only after its target is written |
| A missing vault breaks unrelated skills | Part 4 soft-reference — no `dependencies` key, same as `ui-ux-pro-max` |
| The deleted default directory silently grows back | Relocation lives in `gaspol-config.json`, not only a shell export; verified with a clean environment |
| `graphify update` runs in a repo that never opted in | Presence of `graphify-out/` is the only trigger; absent means skip, never create |
| A stale code index silently reports success | The `UNKNOWN` row stops and asks; a skip is recorded as a skip |
