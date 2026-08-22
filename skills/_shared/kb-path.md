# Where the knowledge store lives — one resolver, three states

Shared reference for every skill that reads or writes the cross-project knowledge base:
`gaspol-learn`, `gaspol-adr`, `gaspol-research`, and `gaspol-brainstorm`
Phase 0.5. Same role as `skills/_shared/completeness-ladder.md` — one source, referenced, never
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
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it the resolver would be taken from whatever repo happens to be open, and its stdout becomes the path gaspol commits}"
KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")" || {   # 0=available  3=UNKNOWN (STOP+ask)  4=none (report+continue)
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

## Never commit a repository gaspol does not own

Resolving to a readable directory says nothing about **who owns it**. Point the store at a folder
inside someone's Obsidian vault — which this plugin now actively encourages — and
`git -C "$KB" add . && git -C "$KB" commit` operates on the **vault** repository. gaspol would
commit, and in synced mode push, an entire second brain nobody asked it to touch.

`--init` — **writes only.** `kb-root --init` turns state 4 into "created it, here is the path,
exit 0", so a first capture on a fresh machine has somewhere to go. It deliberately does **not**
touch state 3: creating a directory over a relocation the user configured and that is currently
unreadable would answer *"no precedent exists"* for a store that has precedent in it. It creates a
**bare** directory — no `git init`, no category folders, no `INDEX.md`. Callers use the flag
instead of spelling `~/.claude/gaspol-knowledge` themselves; the second place a path lives is the
one that goes stale.

Before any `git commit` / `git push` against the store:

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it the resolver would be taken from whatever repo happens to be open, and its stdout becomes the path gaspol commits}"
KB="$("$CLAUDE_PLUGIN_ROOT/skills/_shared/kb-root")" || exit 1
NOTE="$KB/$(date +%F)-<slug>.md"        # the ONE file this capture wrote
TOP="$(git -C "$KB" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" != "$(cd "$KB" && pwd -P)" ]; then
  echo "kb-sync: skipped — KB lives inside a repo gaspol does not own ($TOP)"
else
  git -C "$KB" add -- "$NOTE" && git -C "$KB" commit -q -m "<message>" -- "$NOTE" || true
  [ -n "${REMOTE:-}" ] && git -C "$KB" push --quiet || true
fi
```

Three properties this must keep:

- **Reads stay allowed.** Only the write-side git operations are refused. Refusing reads as well
  would silently disable precedent lookup — the capability this whole change exists to strengthen,
  which would make the guard a bigger regression than the hazard.
- **The skip is recorded, never silent.** `kb-sync: skipped` is an exact string. A silent skip is
  indistinguishable from a sync that ran, which is the reporting failure `gaspol-finish` already
  forbids for an unavailable `/security-review`.
- **Stage by pathspec, never `git add .`** (IDS-8, `/security-review`). The comparison above asks
  *"is `$KB` the repository ROOT?"*, and answers yes for two very different things: a dedicated KB
  repository gaspol may commit, and somebody's **vault root** pointed at by a mis-set `kb_local`.
  Structure alone cannot tell them apart, and it never will — so the guard is not the last line of
  defence. Staging only the note just written is: a wrong ruling then commits one gaspol file
  instead of the whole working tree, private and untracked files included. A symlinked `kb_local`
  reaches the same place, since both sides are normalised with `pwd -P`.
- **`$TOP` empty means not a repo at all** — that is the ordinary case for a plain KB directory,
  and committing is fine there. Only a *mismatch* triggers the refusal.

**The guard stops gaspol, not the host.** Observed during IDS-8's own migration: seventeen files
were written into a vault and, minutes later, appeared in a commit titled `vault: auto-sync` —
made and pushed by the vault's own timer, not by gaspol. So the guard prevents gaspol from
authoring a commit; it does **not** buy the user a review window, and must never be described as
if it did. Where that matters, say what was written and let the person decide what to do about it
before their own sync runs.

The hazard is inert today: with no `gaspol-config.json` the mode is local-only and there is no
remote to push to. It arms itself the day `kb_remote` is set, which is exactly when nobody will
remember the connection.
