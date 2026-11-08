# Working Discipline — gaspol default behaviour around code and requests

Two rules for how to behave around code that is not yours to change, and around a request
that is not yet clear. Adapted from Andrej Karpathy's observations on LLM coding pitfalls
via github.com/multica-ai/andrej-karpathy-skills (MIT).

## Surgical changes

- Every changed line traces to the request.
- Do not tidy adjacent code, comments or formatting.
- Match the existing style, even if you would do it differently.
- Remove only the imports, variables and functions that YOUR change left unused.
- Unrelated dead code is reported in the hand-off, never deleted.

## Think before coding

- State your assumptions before writing code.
- When a request has two readings, name both instead of picking one silently.
- Say so when a simpler way exists.
- When confused, stop, name what is unclear, and ask through `AskUserQuestion`.

## Boundary with the Completeness Ladder

Surgical changes limits code OUTSIDE the task. The ladder in
`skills/_shared/completeness-ladder.md` demands depth INSIDE it. The two never conflict:
do all of the requested work completely, and touch nothing else.

Trivial changes (a typo, an obvious one-liner) need judgement, not the full ceremony.
