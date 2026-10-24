# Proposal: do not repeat verification at an unchanged HEAD

**Status:** proposed, not released. The edits are in the working tree (`git diff`), uncommitted, untested.
**Touches:** `skills/gaspol-finish/SKILL.md`, `skills/gaspol-auto/SKILL.md`

## What the owner saw

At the end of one large ticket the chain ran the same checks several times on the same commit:

1. `gaspol-auto` post-run: `gaspol-verify` and `plan-verifier`.
2. `gaspol-finish` Step 1: `gaspol-verify` again, including the full test suite.
3. `gaspol-finish` Step 2: `plan-verifier` again.
4. `gaspol-finish` Step 3: a Tier 1 `code-reviewer` pass over the same diff.

On top of that, `plan-verifier` was re-run three times after fixes, each time over the whole
branch instead of the fix diff. A `plan-verifier` or reviewer pass cost roughly 80-180 thousand
tokens each; the full suite took about six minutes per round. The owner stopped the run and said
the layering was spending tokens without telling them anything new.

## What changed

1. `gaspol-auto` appends `verified: PASS @ <sha>` and `plan-verifier: CLEAN @ <sha>` to the ledger
   when both pass.
2. `gaspol-finish` Step 1 and Step 2 reuse those lines when `<sha>` equals `git rev-parse HEAD` and
   the working tree is clean. Any other case runs the check again.
3. `gaspol-finish` Step 3 (Tier 1 review) is skipped when Step 2 is CLEAN for the current HEAD and
   the user did not ask for a review. It stays mandatory when there is no plan, because then nothing
   else read the diff.

## Why this is safe against the reason it was once forbidden

IDS-17 removed "skip verify if it already passed this session" because "it passed earlier" had no
anchor and could be stale. The commit SHA is that anchor: the same SHA with a clean tree means the
code is byte-identical to what was verified, so a second run cannot find anything new. A different
SHA, a missing line, or an uncommitted change still forces a re-run. The line must be read from the
ledger, never taken from memory.

## What this gives up

- A second independent reader of the diff. `plan-verifier` checks the diff against the spec and the
  plan; it does not hunt for general bugs. In the ticket above it did catch one real defect, but that
  one was close to a spec requirement. If bugs that a Tier 1 review would have caught start to
  appear after merge, revisit item 3.
- A ledger line can be written wrongly. The gate trusts the ledger the same way `ledger-gate` and
  `regression-gate` already do.

## Still to do

- Add to `gaspol-finish` that a re-run of `plan-verifier` after a fix covers `<SHA>..HEAD` only, as
  `skills/_shared/fix-loop.md` already says. The ticket above re-audited the whole branch each time.
- Prove it on the next ticket that runs `gaspol-auto` through `gaspol-finish`; there is no automated
  test for skill text.
- Leak check, version bump, commit, push (steps 6-8 of `plugin-improve`) after the owner reviews.
