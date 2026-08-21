# KB Modes & Setup

> **Resolution is implemented, not merely documented (IDS-8, 2026-08-21).** `kb_local` used to be
> described here, in `README.md` and in `CLAUDE.md` while **no skill read it** — `grep kb_local
> skills/` returned zero hits. The order and the three states now live in one place,
> `skills/_shared/kb-path.md`, and are executed by `skills/_shared/kb-root`, which prints the
> resolved path and reports `available` / `UNKNOWN` / `none` through exit codes 0/3/4. Prefer the
> config file over the environment variable: an export from a shell profile only exists for
> processes that inherited that shell, and everywhere else resolution falls through and recreates
> the store you moved away from.


The cross-project Knowledge Base (KB) is what makes gaspol *compound* — `gaspol-adr`
and `gaspol-learn` **write** to it, `gaspol-brainstorm` Phase 0.5 and `gaspol-research`
**read** from it, `gaspol-kb-audit` **maintains** it.

**As of v1.3.1 the KB works out of the box — no GitHub repo required.** GitHub sync is
an optional upgrade for cross-machine use.

## The 3 Modes (canonical resolution)

Every KB-touching skill resolves the mode like this, in order:

1. **`off`** — only if `~/.claude/gaspol-config.json` exists AND contains `"kb_mode": "off"`.
   → KB fully disabled. Skills skip silently. (For users who never want a KB.)

2. **`synced`** — if a remote is configured: `kb_remote` in `gaspol-config.json`, or the
   `GASPOL_KB_REMOTE` env var is set.
   → `git pull` before reads, `git commit && git push` after writes (cross-machine).

3. **`local-only`** (DEFAULT — no config, or config without a remote) —
   → Auto-init the local KB on first use, read/write **local files only**, **no pull,
   no push, never fail on a missing remote.** Cross-project learning works on this machine;
   add a remote later to go cross-machine.

> Resolution flips the old behavior: "no config → skip" is now "no config → local-only".
> The KB only disables on an explicit `kb_mode: off`.

## Auto-init (run when the store directory is missing)

```bash
KB="$(skills/_shared/kb-root --init)"; rc=$?
case $rc in
  0) : ;;                                   # available (--init created it if state 4)
  3) echo "knowledge-store: UNKNOWN — configured path unreadable"; exit 1 ;;   # STOP and ask
esac
```

`--init` does the creating, so the default path is spelled in `skills/_shared/kb-root`
and nowhere else — a caller that writes `$HOME/.claude/gaspol-knowledge` into its own bash is a
second place the path lives, and the second place is the one that goes stale. `--init` deliberately
does NOT touch state 3: creating a directory over a relocation the user configured and that is
currently unreadable would answer "no precedent exists" for a store that has precedent in it.

**A bare directory, and nothing else** (IDS-8). Three things this block used to do and must not:

- **No `git init`.** `kb_local` may point inside a repository you do not own — a vault, a monorepo
  — and initialising one there is the write-side hazard `skills/_shared/kb-path.md` exists to
  prevent.
- **No category subdirectories.** Captures are flat notes; the category is the first tag. Routing
  is the promoter's job.
- **No `INDEX.md`.** gaspol writes no index — the flat notes carry their own frontmatter and tags,
  and an index nothing reads can only drift.

## Conditional sync helper (skills use this instead of unconditional pull/push)

```bash
KB="$(skills/_shared/kb-root)" || exit 1
REMOTE="${GASPOL_KB_REMOTE:-$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/gaspol-config.json"))).get("kb_remote",""))' 2>/dev/null)}"

# before reads (synced only) — reads are always permitted:
[ -n "$REMOTE" ] && git -C "$KB" pull --quiet 2>/dev/null || true

NOTE="$KB/$(date +%F)-<slug>.md"     # the ONE file this capture wrote

# OWNERSHIP GUARD — before ANY write-side git operation:
TOP="$(git -C "$KB" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" != "$(cd "$KB" && pwd -P)" ]; then
  echo "kb-sync: skipped — KB lives inside a repo gaspol does not own ($TOP)"
else
  # PATHSPEC, never `add .`: the guard asks "is $KB the repo ROOT?", which is true
  # for a dedicated KB repo AND for a vault root a mis-set kb_local points at
  # (kb_local is resolved by skills/_shared/kb-root — see skills/_shared/kb-path.md).
  git -C "$KB" add -- "$NOTE" 2>/dev/null && git -C "$KB" commit -q -m "<msg>" -- "$NOTE" 2>/dev/null || true
  [ -n "$REMOTE" ] && git -C "$KB" push --quiet 2>/dev/null || true
fi
```

The guard is not optional decoration: with `kb_local` pointing into a vault, the unguarded version
of this block commits and pushes somebody's entire second brain. It stops **gaspol** from authoring
a commit — it does **not** give anyone a review window, because a vault may auto-sync on its own
timer. Full rationale: `skills/_shared/kb-path.md`.


## Upgrade: local-only → synced (cross-machine, optional)

```bash
# 1. create YOUR OWN private repo (per-user — never share a KB repo)
gh repo create <your-github-username>/gaspol-knowledge --private

# 2. point the existing local KB at it
git -C ~/.claude/gaspol-knowledge remote add origin \
  git@github.com:<your-github-username>/gaspol-knowledge.git
git -C ~/.claude/gaspol-knowledge push -u origin main

# 3. write config so skills switch to synced mode
cat > ~/.claude/gaspol-config.json <<EOF
{ "kb_remote": "git@github.com:<your-github-username>/gaspol-knowledge.git",
  "kb_local": "~/.claude/gaspol-knowledge",
  "kb_owner": "<your-github-username>" }
EOF
```
Resolution order and the three states live in `skills/_shared/kb-path.md` and are executed by
`skills/_shared/kb-root` (exit **0** available / **3** UNKNOWN / **4** none). Prefer this file over
the `GASPOL_KB_LOCAL` environment variable: a shell export only exists for processes that
inherited that shell, and everywhere else resolution falls through to the default and recreates
the store you moved away from.




Everything already captured locally comes along on the first push.
