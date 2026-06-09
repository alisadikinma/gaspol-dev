# KB Modes & Setup

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

## Auto-init (run when the local KB dir is missing)

```bash
KB="${GASPOL_KB_LOCAL:-$HOME/.claude/gaspol-knowledge}"
if [ ! -d "$KB" ]; then
  mkdir -p "$KB"/{ui-patterns,architecture,design-decisions,research,reusable-snippets}
  printf '# gaspol-knowledge INDEX (local)\n' > "$KB/INDEX.md"
  git -C "$KB" init -q 2>/dev/null || true   # local history; lets you add a remote later
fi
```

A local `git init` is best-effort — it gives you history and a clean upgrade path, but the
KB functions as plain files even if git is unavailable.

## Conditional sync helper (skills use this instead of unconditional pull/push)

```bash
KB="${GASPOL_KB_LOCAL:-$HOME/.claude/gaspol-knowledge}"
REMOTE="${GASPOL_KB_REMOTE:-$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/gaspol-config.json"))).get("kb_remote",""))' 2>/dev/null)}"

# before reads (synced only):
[ -n "$REMOTE" ] && git -C "$KB" pull --quiet 2>/dev/null || true

# after writes — always commit locally; push ONLY if a remote exists:
git -C "$KB" add . 2>/dev/null && git -C "$KB" commit -q -m "<msg>" 2>/dev/null || true
[ -n "$REMOTE" ] && git -C "$KB" push --quiet 2>/dev/null || true
```

Local commit always runs (free, gives history). Push runs only in `synced` mode. In
`local-only` mode there is **no fail-loud** for the absent remote — that is the expected state.

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

Everything already captured locally comes along on the first push.
