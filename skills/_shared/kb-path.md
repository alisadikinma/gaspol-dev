# Where the knowledge store lives — one resolver, three states

Shared reference for every skill that reads or writes the cross-project knowledge base:
`gaspol-learn`, `gaspol-adr`, `gaspol-research`, `gaspol-kb-audit`, and `gaspol-brainstorm`
Phase 0.5. Same role as `skills/_shared/laziness-ladder.md` — one source, referenced, never
restated.

**Do not spell the default path anywhere else.** This file is the only place the literal
`~/.claude/gaspol-knowledge` may appear. Every other skill says "the resolved KB root" and points
here. The reason is concrete: sixteen prose sites used to name that folder directly, so relocating
the store left the setting correct and the instructions wrong.

## Resolution order

Stop at the first rung that yields a path:

1. **`$GASPOL_KB_LOCAL`** — environment override. For CI and one-off runs.
2. **`kb_local`** in `~/.claude/gaspol-config.json` — the durable, machine-wide setting.
3. **`~/.claude/gaspol-knowledge`** — the default, used when nothing is configured.

**Use the script, not a hand-rolled snippet:** `skills/_shared/kb-root` prints the resolved path
on stdout and reports the state through its exit code.

```bash
KB="$(skills/_shared/kb-root)" || {   # 0=available  3=UNKNOWN (STOP+ask)  4=none (report+continue)
  echo "resolve the state before continuing — see the table below"; exit 1; }
```

It is a script rather than a documented shell function for a concrete reason found while wiring
this up: the KB skills contain runnable bash that does `git -C "$KB" commit`. A function defined
only inside a markdown file is not in scope when that block runs, so `KB="$(kb_root)"` resolves to
the **empty string** and `git -C ""` becomes a silent wrong answer — the exact failure class this
ticket exists to remove. Exit codes make the three states impossible to conflate; an empty stdout
can never be mistaken for a path.


**Rung 2 is the one that matters for relocation, and it is the one that used to be fiction.**
`kb_local` was documented in `README.md`, `CLAUDE.md`, and `docs/kb-setup.md` while no skill read
it — grep under `skills/` returned zero hits. An environment variable exported from a shell profile
only exists for processes that inherited that shell; anywhere it does not, resolution silently falls
through to rung 3 and **recreates the store you just moved away from**. Write relocations to the
config file. Keep the variable for CI.

## Three states, never blurred

Resolving a path is not the same as having a store. Report which of these happened — the record
strings are exact, because a reader must be able to tell them apart at a glance:

| State | Condition | Behaviour |
|---|---|---|
| **available** | resolved path exists and is readable | Read and write normally. |
| **none** | nothing configured and the default does not exist | Record `knowledge-store: none — not configured`. **This is not a failure.** Say what is missing, name `kb_local`, continue. A public plugin cannot require anyone to keep a vault. |
| **UNKNOWN** | configured, but the path is absent or unreadable | Record `knowledge-store: UNKNOWN — configured path unreadable: <path>` and **STOP and ask the user.** |

The third row is the load-bearing one. A configured store that cannot be read must **never** be
treated as an empty store: an empty result reads as *"no precedent exists"*, which is precisely
when a documented mistake gets made a second time. KB precedent:
`marker-file-is-not-proof-tool-installed` — a marker proves intent, never that the thing works.

The same discipline `detect-stack` applies to build commands and IDS-7 applies to `DESIGN.md`. A
plausible pass is worse than an admitted gap, because nobody investigates a pass.

## What "available" does not mean

Resolving to a readable directory says nothing about **who owns it**. When the store lives inside
someone else's repository — a vault, a monorepo — writing files is fine and running git is not.
That guard is documented below this section once it exists; until then, do not add git operations
to a KB skill.
