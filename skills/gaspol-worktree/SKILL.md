---
name: gaspol-worktree
description: "Use when starting feature work that needs isolation from the current workspace, before dispatching parallel implementer subagents (gaspol-parallel), or before executing a plan that touches many files. Ensures an isolated git worktree exists via the harness native tool or a safe git fallback — so parallel work never collides and the current branch stays clean."
---

# gaspol-worktree

## Iron Law

`NO PARALLEL OR ISOLATED WORK WITHOUT A VERIFIED ISOLATED WORKSPACE FIRST`

Detect existing isolation before creating anything. Prefer the harness native tool. Fall back to `git worktree` only when no native tool exists. Never fight the harness, never commit worktree contents.

## Core Principle

Isolation is a precondition, not an afterthought. Two implementer subagents editing the same working directory race on the same files — one overwrites the other, tests pass against a half-merged tree, and the failure surfaces hours later as "it worked a second ago." A worktree gives each line of work its own checked-out branch on disk, so concurrent edits cannot collide and `main`/the current branch stays pristine.

**Announce at start:** "Using gaspol-worktree to set up an isolated workspace."

---

## When to Use

- Before `gaspol-parallel` dispatches concurrent implementer subagents (mode `independent-domains`, or mode `plan-phases` when phases touch overlapping files).
- Before `gaspol-execute` / `gaspol-auto` on a plan that rewrites many files, where you want the current branch protected.
- Whenever the user asks for "an isolated branch", "don't touch my current work", or "work in a sandbox".

## When NOT to Use

- Trivial single-file edits on a branch you already own.
- You are already inside a linked worktree (Step 0 detects this — do not nest).
- The repo is not a git repository (offer `git init` or skip isolation).

---

## Process

### Step 0: Detect Existing Isolation (MANDATORY FIRST)

Before creating anything, check whether you are already isolated:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is *also* true inside a git submodule. Confirm you are not in a submodule before concluding "already in a worktree":

```bash
# If this prints a path, you are in a submodule — treat as a normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

- **`GIT_DIR != GIT_COMMON` and not a submodule** → you are already in a linked worktree. Skip to Step 3. Do NOT create another worktree. Report: `Already in isolated workspace at <path> on branch <name>.`
- **`GIT_DIR == GIT_COMMON` (or in a submodule)** → normal checkout. Continue to consent.

**Consent (MANDATORY — use AskUserQuestion):** If the user has not already declared a worktree preference in their instructions, ask before creating one:

> "Set up an isolated worktree? It protects your current branch from changes."
> `[Yes — create worktree]` `[No — work in place]` `[Use my existing .worktrees/ dir]`

Honor any pre-declared preference without asking. If the user declines, work in place and skip to Step 3.

### Step 1: Create the Isolated Workspace

Try these two mechanisms **in order**.

#### 1a. Native Worktree Tool (PREFERRED)

If the harness exposes a native worktree tool — a tool named like `EnterWorktree` / `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag — **use it and skip to Step 3**. Native tools manage directory placement, branch creation, and cleanup so the harness can see and track the worktree. Using raw `git worktree add` when a native tool exists creates phantom state the harness cannot manage (this is the #1 mistake).

Only proceed to 1b if no native tool is available.

#### 1b. Git Worktree Fallback

**Directory selection** (explicit user preference always wins over filesystem state):

1. Declared preference in instructions → use it.
2. Existing project-local dir: prefer `.worktrees/` (hidden), else `worktrees/`. If both exist, `.worktrees/` wins.
3. Existing legacy global dir: `~/.config/gaspol/worktrees/<project>/`.
4. No guidance → default to `.worktrees/` at project root.

**Safety verification (project-local only) — BLOCKING:** the worktree directory MUST be gitignored before creation, or its contents leak into the repo:

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

If NOT ignored → add the directory to `.gitignore`, commit that change, then proceed. Global dirs need no verification.

**Create it:**

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
# project-local: path="$LOCATION/$BRANCH_NAME"   |   global: path="~/.config/gaspol/worktrees/$project/$BRANCH_NAME"
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

**Sandbox fallback:** if `git worktree add` fails with a permission/sandbox error, tell the user the sandbox blocked worktree creation and you are working in the current directory instead; then run setup and baseline in place.

### Step 2: Project Setup

Auto-detect and run the appropriate install (read the target project's CLAUDE.md first per the CLAUDE.md-first rule):

```bash
[ -f package.json ]      && npm install
[ -f Cargo.toml ]        && cargo build
[ -f requirements.txt ]  && pip install -r requirements.txt
[ -f pyproject.toml ]    && poetry install
[ -f go.mod ]            && go mod download
[ -f composer.json ]     && composer install   # Laravel / PHP
```

### Step 3: Verify Clean Baseline (MANDATORY)

Run the project test command once before any implementation, so new failures are distinguishable from pre-existing ones:

```bash
# project-appropriate: npm test / cargo test / pytest / go test ./... / php artisan test
```

- **Tests fail** → report the failures and use AskUserQuestion: `[Investigate first]` / `[Proceed anyway]`. Do not silently proceed.
- **Tests pass** → report ready.

```
Worktree ready at <full-path>
Baseline: <N> tests passing, 0 failures
Ready to implement <feature-name>
```

### Step 4: Ticket Documents Inside the Worktree

Once the worktree is live, IDS-1's naming conventions apply inside it exactly as they would on any branch:

- Spec: `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md`
- Plan: `docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md`
- Ledger: `.gaspol/progress/PROGRESS-<TICKET>.md`

**Spec and plan are version-controlled artifacts that stay ON THE BRANCH.** They get committed in the worktree's branch and reach the default branch only via the merge — never copy them into the main working tree. An untracked file of the same name sitting in the main tree blocks the merge with `untracked working tree files would be overwritten by merge`. To read one from the default branch without merging: `git show <branch>:docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md`.

**The ledger is different — it is gitignored working-tree scratch.** Because `.gaspol/` sits under the gitignore this skill's Step 1b safety verification already covers, the ledger never collides and never merges; each worktree gets its own copy. If the operator wants to watch progress from the default branch, the ledger is the only one of the three that may be mirrored there.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree | Skip creation (Step 0) |
| Inside a submodule | Treat as normal repo (Step 0 guard) |
| Native worktree tool available | Use it (Step 1a) — never raw `git worktree add` |
| No native tool | Git fallback (Step 1b) |
| `.worktrees/` and `worktrees/` both exist | Use `.worktrees/` |
| Directory not gitignored | Add to `.gitignore` + commit, THEN create |
| Permission/sandbox error on create | Work in place, tell the user |
| Baseline tests fail | Report + AskUserQuestion before proceeding |

---

## Red Flags

| Red Flag | Why It's Dangerous |
|----------|-------------------|
| Dispatching parallel implementers without isolating them | Race conditions — agents overwrite each other's files |
| `git worktree add` when a native `EnterWorktree` tool exists | Phantom state the harness can't see or clean up |
| Skipping Step 0 detection | Creates a nested worktree inside an existing one |
| Creating a project-local worktree without `git check-ignore` | Worktree contents get committed and pollute the repo |
| Assuming the worktree directory location | Violates project convention; inconsistent state |
| Proceeding past a failing baseline without asking | Can't tell new bugs from pre-existing ones |
| Cleaning up the worktree before the merge is confirmed | If the merge fails, you need the worktree to fix it (see gaspol-finish) |
| Copying spec/plan into the main working tree | Blocks the merge (`untracked working tree files would be overwritten by merge`) — keep them on the branch, use `git show` to read them |

## Rationalization Table

| Rationalization | Why It's Wrong |
|----------------|----------------|
| "It's just one agent, no need to isolate" | gaspol-parallel often escalates to many; isolate once, safely |
| "The current branch is fine to work on" | Half-finished work on the active branch blocks the user's other work |
| "I'll add it to .gitignore later" | "Later" = the worktree is already committed. Verify BEFORE creating |
| "Native tool vs git, same thing" | Raw git creates state the harness can't manage — cleanup breaks |
| "Baseline tests probably pass" | "Probably" is not evidence. Run them. Iron Law: evidence before claims |

---

## Integration

| Skill | Interaction |
|-------|-------------|
| `gaspol-parallel` | Call gaspol-worktree BEFORE concurrent dispatch — each domain/phase that touches overlapping files gets isolation |
| `gaspol-execute` / `gaspol-auto` | Optional pre-step to protect the current branch on large plans |
| `gaspol-finish` | Owns teardown — `git worktree remove` happens there after the merge/PR decision, never before |

### Copy the ledger out BEFORE `git worktree remove`, never after

`.gaspol/` is gitignored, so the progress ledger lives **only** in the worktree's own directory
and is destroyed with it. `git worktree remove` deletes the one record of what was observed
during the run — the baseline, the mid-run decisions, the debt left open — and nothing warns you,
because a gitignored file is invisible to `git status`.

```bash
cp .claude/worktrees/<slug>/.gaspol/progress/PROGRESS-<TICKET>.md \
   <main checkout>/.gaspol/progress/PROGRESS-<TICKET>.md
git worktree remove .claude/worktrees/<slug>
git worktree prune
```

The order is the whole instruction. IND-98's ledger had to be reconstructed from session context
because the copy was attempted after the removal, and a reconstruction is not a record — it is
what somebody remembers, which is exactly what a ledger exists to replace.
| `gaspol-brainstorm` | Phase 0 CLAUDE.md read informs Step 2 setup commands |
