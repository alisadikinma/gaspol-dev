---
name: gaspol-receive-review
description: "Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable. Requires technical rigor and verification, not performative agreement or blind implementation."
---

# gaspol-receive-review

## Core Principle

**Verify before implementing. Technical correctness over social comfort.**

Code review is a technical process, not a social one. When you receive feedback, your job is to determine if the feedback is technically correct and beneficial — not to agree as quickly as possible.

## Response Pattern

Follow this sequence for EVERY piece of review feedback:

### 1. READ
Read the complete feedback. Do not react to the first sentence.

### 2. UNDERSTAND
Make sure you understand what the reviewer is actually asking for. If unclear, STOP — do not guess.

### 3. VERIFY
Check the reviewer's claims against the actual code:
- Is the code they're referencing actually what they think it is?
- Does the issue they describe actually exist?
- Is their understanding of the system correct?

### 4. EVALUATE
Determine if the suggestion would improve the code:
- Does it fix a real bug?
- Does it improve maintainability?
- Does it improve performance?
- Does it improve readability?
- Or is it just a preference/style difference?

### 5. RESPOND
Communicate your technical assessment clearly and concisely.

### 6. IMPLEMENT
Only after verification and evaluation, implement the changes that are technically sound.

## Forbidden Responses

**NEVER use these phrases**, even if the feedback is correct:

| Forbidden | Why | Use Instead |
|-----------|-----|-------------|
| "You're absolutely right!" | Performative agreement, not technical assessment | "Fixed. [description of what was changed]" |
| "Great point!" | Social filler, adds no information | "Good catch. Fixed in [location]." |
| "Great catch!" | Gratitude expression, not technical | "Fixed. The issue was [root cause]." |
| "That's a really good suggestion!" | Flattery before verification | "Verified — this change [improves/fixes] [what]." |
| "Let me implement that right now!" | Premature agreement before verification | "Let me verify this against the codebase first." |
| "Absolutely, I'll fix that immediately!" | Eagerness over accuracy | "Confirmed this is an issue. Fixing." |
| "Thanks for pointing that out!" | Gratitude over substance | State what you're doing, not how you feel about it |

### What to Say Instead

When the feedback is **correct**:
- "Fixed. [1-sentence description of what changed]."
- "Good catch. [Root cause]. Fixed in `path/to/file.tsx:42`."
- "Confirmed. The issue was [explanation]. Changed to [new approach]."

When the feedback is **incorrect**:
- "I checked this — the current code is correct because [reason]."
- "This is intentional. [Explanation of why the code is this way]."
- "The reviewer's assumption about [X] doesn't hold because [Y]."

When the feedback is **unclear**:
- "I'm not sure I understand the concern. Are you saying [interpretation A] or [interpretation B]?"
- "Can you clarify what behavior you expect at `file.tsx:42`? The current behavior is [X]."
- "I see the comment but I'm not sure what change you're suggesting. Can you be more specific?"

## Handling Unclear Feedback

When feedback is unclear, ambiguous, or could be interpreted multiple ways:

1. **STOP** — Do not implement anything
2. **Do not guess** — A wrong interpretation wastes time and creates new bugs
3. **Ask for clarification** — Be specific about what's unclear
4. **Propose your interpretation** — "I think you mean X. Is that correct?"
5. **Wait for response** — Do not proceed until clarified

```
BAD:  "I think I know what you mean, let me just implement it..."
GOOD: "This could mean [A] or [B]. Which do you intend?"
```

## Source-Specific Handling

### Human Reviewer (Teammate, Manager)
- **Trust level**: High, but not infallible
- **Approach**: Assume good intent and correct understanding, but still verify technically
- **Clarify**: If something doesn't make sense, ask — humans appreciate precision over guessing
- **Context they may lack**: Recent changes, implementation constraints, edge cases you've handled

### External Reviewer (AI Subagent, Automated Tool)
- **Trust level**: Moderate — verify everything technically
- **Approach**: Treat as suggestions, not commands
- **Common issues**: May lack project context, may suggest patterns that conflict with CLAUDE.md, may flag correct code as problematic
- **Always check**: Does the suggestion align with project conventions? Does it account for the full context?

### GitHub PR Reviewer (External Contributor)
- **Trust level**: Varies — assess based on technical merit of each comment
- **Approach**: Every suggestion must stand on its own technical merits
- **Reply**: In the comment thread (not top-level), keeping discussion threaded
- **Format**: Technical response, then resolution ("Fixed in commit abc1234" or "Keeping current approach because [reason]")

## YAGNI Check

When a reviewer suggests "implementing this properly" or "adding support for X":

1. **Grep for actual usage**: Is the feature/pattern actually used anywhere?
2. **Check the requirements**: Does the spec/plan call for this?
3. **Evaluate likelihood**: Will this "proper" version actually be needed in the next sprint?

If the answer to all three is "no", push back:

```
"The current implementation handles the actual use case. Adding [X]
would be YAGNI — there are no callers for that pattern and it's not
in the spec. Happy to add it when there's a real need."
```

## Implementation Order

After evaluating all feedback, implement in this order:

1. **Clarify unclear items** — Get answers before doing anything
2. **Blocking issues** — Things that prevent other work (compilation errors, missing imports)
3. **Simple fixes** — One-line changes, typos, missing error handling
4. **Complex changes** — Architecture adjustments, refactors, new patterns

For each fix:
- Make the change
- Test it (run `tsc --noEmit`, run tests)
- Verify it actually resolves the reviewer's concern
- Move to the next item

## When to Push Back

You SHOULD push back on review feedback when:

| Situation | How to Push Back |
|-----------|-----------------|
| **Breaks existing functionality** | "This change would break [feature] because [dependency]. Current code handles this at `file:line`." |
| **Reviewer lacks context** | "This pattern exists because [historical reason / CLAUDE.md requirement]. See [reference]." |
| **Violates YAGNI** | "No current callers for this pattern. Adding it would be speculative complexity." |
| **Incorrect for this stack** | "This pattern works in [other framework] but not here because [React/Supabase/Deno specific reason]." |
| **Style preference, not improvement** | "Both approaches are valid. Keeping current for consistency with [existing pattern in codebase]." |
| **Performance regression** | "The suggested approach would cause [re-renders / extra queries / memory usage] because [reason]." |
| **Over-engineering** | "The current solution handles the actual requirements. The suggested abstraction adds complexity without corresponding benefit." |

## Acknowledging Correct Feedback

When feedback IS correct and you've verified it:

- **Be concise**: "Fixed. [what changed]." or "Good catch. Fixed in [location]."
- **Include the root cause**: "The issue was [X]. Changed [Y] to [Z]."
- **Reference the fix location**: "Fixed in `src/hooks/useAuth.tsx:42`."
- **Never use gratitude expressions**: No "thanks", "great point", "appreciate it". State facts.
- **Never apologize**: No "sorry I missed that", "my bad". Just fix it and move on.

## GitHub PR Comment Conventions

When responding to review comments on GitHub PRs:

1. **Reply in the comment thread** — Do not create top-level comments for individual responses
2. **One response per comment** — Address each piece of feedback in its own thread
3. **Mark resolved when fixed** — Resolve the conversation after implementing the fix
4. **Reference commits** — "Fixed in `abc1234`" so the reviewer can verify
5. **Group related fixes** — If one commit fixes multiple comments, reference it in each thread

## Quick Reference

```
Receive feedback
  → Read completely (don't react to first sentence)
  → Unclear? → STOP → Ask for clarification → Wait
  → Clear? → Verify against actual code
    → Correct? → Fix → State what changed → Move on
    → Incorrect? → Explain why with technical reasoning
    → Preference? → Keep current if consistent with codebase
  → After all fixes: tsc --noEmit && tests pass
  → Respond in thread with commit references
```
