# Prior-Art Gate — nothing gets built in-house before somebody looks

> Extracted from `gaspol-write-skill` Step 0 when that skill was removed (IDS-11), and generalised
> in the move. Bound to skill-authoring the rule would have died with its host; two live skills
> already referenced it — `gaspol-brainstorm` Phase 1.5 (`NEW` branch) and `gaspol-research` gather
> lane 6 — and its supply-chain rules are the plugin's only ones.
>
> The wider framing is `gstack/ETHOS.md` §2, "Search Before Building": *the 1000x engineer's first
> instinct is "has someone already solved this?" not "let me design it from scratch." The cost of
> checking is near-zero. The cost of not checking is reinventing something worse.*

## When this gate runs (BLOCKING)

Before building **anything** in-house that a package, a platform feature, an installed dependency,
a built-in command, or a published skill might already provide. In practice:

| Trigger | Who invokes it |
|---|---|
| A new skill is about to be authored | whoever is authoring it |
| Brainstorm classifies novelty as `NEW` — no KB hit, no project pattern | `gaspol-brainstorm` Phase 1.5 |
| Research is gathering candidates | `gaspol-research` gather lane 6 |
| A plan phase proposes writing a mechanism from scratch | `gaspol-plan` |

```
NOTHING GETS BUILT IN-HOUSE BEFORE A PRIOR-ART SEARCH
```

The baseline failure here is not hypothetical, it is this repo's own history.
Both skills deleted in v1.14 existed because nobody looked first: `gaspol-design`
was a 1.4MB fork of data the `ui-ux-pro-max` plugin already publishes — the fork
drifted, upstream did not — and a 12KB forked security checklist duplicated the
`/security-review` command already compiled into the Claude Code binary. Two
builds, two deletions, zero searches.

Run **all three** lookups. One is not enough, and they fail in different
directions: "is it installed?" cannot see a built-in slash command, and neither
can see the marketplace.

1. **Installed already?** Check the session's skill/plugin listing and `skills/`.
2. **Built into the harness?** Built-in slash commands appear in no skill
   listing — check for a matching `/command` before assuming absence.
3. **On the marketplace?** `npx skills find "<domain> <task>"` (the vercel-labs
   `skills` CLI; browse at https://skills.sh). Optional, never required:
   if the command is unavailable, say so, run a web search instead, and
   continue — never record the search as done when it did not run.

**Record the verdict before any code or SKILL.md is written:**

| Verdict | Meaning | Action |
|---|---|---|
| `NONE` | three lookups, no match | build it — and you now know why it must exist |
| `EXISTS` | something already does this | do not build. Route to it, soft-referenced |
| `DELTA` | an existing thing covers most of it | build ONLY the delta, and name the delta in the new skill's Integration section |

`DELTA` is the usual verdict and the one most often faked. Naming the delta is
what makes it real: `anti-ai-slop.md` survived the IDS-2 deletion because someone
checked and found `ui-ux-pro-max` ships no anti-slop layer at all — zero "never
use" lists. "Ours needs to be more opinionated" without that check is exactly how
a 1.4MB fork gets built.

Route to what exists the way `ui-ux-pro-max` is routed to: named in the routing
tables, **never** a `dependencies` entry in `plugin.json`. That field is
all-or-nothing — a renamed or yanked third-party package would disable every
unrelated skill in the plugin.

### Installing what you find — never automatically

A skill is a prompt that runs inside your agent. Installing one from an unknown
repo is a supply-chain and prompt-injection decision, not a convenience.

- **NEVER** run `npx skills add ... -y`, and never `-g -y`. Upstream's own
  `find-skills` documents that exact flag pair. Do not follow it.
- Present the candidate through **AskUserQuestion**. The user decides.
- **READ the candidate's SKILL.md before recommending it.** Install count is
  popularity, not an audit — a widely-installed prompt is still a prompt you
  have not read.
- Check last commit date, owner, and whether the skill shells out, fetches the
  network, or writes outside the project.
- Weigh the standing cost: every installed skill's description loads into
  **every** session. A skill used twice a year is a permanent context tax, and
  "it might be handy" is not a reason to pay it.


### Checklist (copy into whatever RED notes or plan phase invokes this gate)

- [ ] Prior-art search run — verdict `NONE` / `EXISTS` / `DELTA` recorded
- [ ] On `DELTA`, the delta is named explicitly (what the existing thing does NOT do)
- [ ] Nothing installed without the user choosing it through AskUserQuestion

### Rationalizations that skip this gate

| What you'll think | Why it's wrong |
|---|---|
| "I'd remember if something existed for this" | Two skills were built and deleted in one release on exactly that memory. |
| "Ours needs to be different" | Probably true, and it argues for `DELTA` — build the difference, not the other 95%. |
| "Searching costs more than writing it" | One `npx skills find` against a 1.4MB fork that later had to be deleted. |
| "It's small, not worth a search" | Small things rot unnoticed. The 12KB security checklist was the small one. |
| "The marketplace is full of junk" | Then the search returns junk and the verdict is `NONE` — recorded, in thirty seconds. |
| "I'll search after I draft it" | After drafting, `EXISTS` costs you the draft, so you'll rationalize `DELTA` instead. |

