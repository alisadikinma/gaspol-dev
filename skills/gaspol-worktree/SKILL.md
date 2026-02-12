---
name: gaspol-worktree
description: "Use when starting feature work that needs isolation from current workspace or before executing implementation plans. Creates isolated git worktrees with smart directory selection and safety verification."
---

# Git Worktree Management

## Core Principle

Systematic directory selection + safety verification = reliable isolation.

Worktrees let you work on multiple branches simultaneously without stashing, switching, or losing context. Each worktree is a full working copy of the repository at a different branch.

---

## When to Use

- Starting a new feature that should not affect current work
- Before executing an implementation plan (gaspol-execute)
- Running experimental changes alongside stable code
- Parallel work on multiple features
- Isolating risky changes (migrations, refactors, dependency upgrades)

## When NOT to Use

- Quick single-file fixes on the current branch
- Work that is a direct continuation of current branch
- When the repository is too large for multiple working copies
- When the feature requires shared state with current workspace

---

## Directory Selection Priority

The worktree directory must be OUTSIDE the main repository but discoverable. Use this priority order:

1. **`.worktrees/` directory** (in repo root, if gitignored)
2. **`worktrees/` directory** (in repo root, if gitignored)
3. **CLAUDE.md config** (if the project defines a custom worktree path)
4. **Ask the user** (if none of the above exist)

```
IMPORTANT: The worktree directory MUST be gitignored.
If it is not gitignored, creating a worktree inside it will
cause git to track the worktree's files as part of the main repo.
```

---

## Safety Verification (MANDATORY)

Before creating any worktree, you MUST verify:

1. **Directory is gitignored**
   ```bash
   # Check if the worktree directory would be ignored by git
   git check-ignore -q .worktrees
   echo $?  # 0 = ignored (SAFE), 1 = NOT ignored (STOP)
   ```

2. **Branch does not already exist** (unless intentionally using existing branch)
   ```bash
   git branch --list "feature/my-branch"
   ```

3. **No existing worktree at the target path**
   ```bash
   git worktree list
   ```

4. **Clean working directory** (warn if dirty, don't block)
   ```bash
   git status --porcelain
   ```

If any safety check fails, stop and inform the user before proceeding.

---

## Worktree Creation Steps

### Step 1: Detect Project Name and Base Branch

```bash
# Get repo name for labeling
basename $(git rev-parse --show-toplevel)

# Determine base branch
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo "main"
```

### Step 2: Ensure Worktree Directory Exists and Is Ignored

```bash
# Check for existing worktree directory
ls -d .worktrees 2>/dev/null || ls -d worktrees 2>/dev/null

# If neither exists, create and gitignore
mkdir .worktrees

# Verify it's in .gitignore
git check-ignore -q .worktrees
# If NOT ignored, add to .gitignore:
# echo ".worktrees/" >> .gitignore
```

### Step 3: Create Worktree with Branch

```bash
# Create new branch + worktree in one command
git worktree add .worktrees/feature-name -b feature/feature-name

# Or use existing branch
git worktree add .worktrees/feature-name feature/existing-branch
```

### Step 4: Run Project Setup in Worktree

```bash
cd .worktrees/feature-name

# Install dependencies (project-specific)
npm install        # Node.js
pip install -r requirements.txt  # Python
cargo build        # Rust

# Copy environment files if needed
cp ../../.env .env
```

### Step 5: Verify Baseline Tests Pass

```bash
cd .worktrees/feature-name

# Run the project's test suite
npm test           # or pytest, cargo test, etc.

# If tests fail, the worktree setup is wrong -- fix before proceeding
```

### Step 6: Report Location

Tell the user:
- Worktree path (absolute)
- Branch name
- Base branch it was created from
- Test status (pass/fail)
- How to switch between main and worktree

---

## Worktree Lifecycle

```
CREATE          WORK            FINISH          CLEAN UP
   |               |               |               |
   v               v               v               v
git worktree   normal git      merge/PR        git worktree
add            add/commit      (gaspol-  remove
               in worktree     finish)         + delete dir
                                               + delete branch
```

---

## Cleanup

After work is merged or discarded:

```bash
# Remove worktree registration
git worktree remove .worktrees/feature-name

# If the above fails (dirty worktree), force it
git worktree remove --force .worktrees/feature-name

# Delete the branch if merged
git branch -d feature/feature-name

# Delete the branch if discarded (force)
git branch -D feature/feature-name
```

---

## Common Commands Reference

| Action | Command |
|--------|---------|
| List all worktrees | `git worktree list` |
| Create with new branch | `git worktree add <path> -b <branch>` |
| Create with existing branch | `git worktree add <path> <branch>` |
| Remove worktree | `git worktree remove <path>` |
| Force remove | `git worktree remove --force <path>` |
| Prune stale entries | `git worktree prune` |

---

## Red Flags

1. **Never create a worktree without verifying the directory is gitignored** -- Files will leak into the main repo's tracked files.
2. **Never skip baseline tests** -- If tests fail in a fresh worktree, the environment setup is wrong, and all subsequent work will be built on a broken foundation.
3. **Never leave stale worktrees** -- They consume disk space and can cause branch lock conflicts.
4. **Never force-remove without checking for uncommitted work** -- Uncommitted changes will be permanently lost.
5. **Never create worktrees inside another worktree** -- This creates nested git state that is nearly impossible to untangle.

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-execute` | Creates worktree before executing multi-phase implementation |
| `gaspol-finish` | Handles merge/PR/cleanup of worktree branch |
| `gaspol-tdd` | TDD cycle runs inside the worktree |
| `gaspol-plan` | Plan identifies whether worktree isolation is needed |
