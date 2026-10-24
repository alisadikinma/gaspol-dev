model-tier: judge

# Builder Check Prompt

Dispatch ONE fresh `general-purpose` subagent with `model: "opus"` once the spec file is written. Fill [DOMAIN] (the target project's stack, e.g. "Laravel and Vue engineer") and [DOCUMENT_PATH]. Give it nothing else: no conversation context.

---
You are a talented [DOMAIN]. You've been handed a design document and asked to put together a plan to build what it describes. You will not be able to talk to the person who wrote it.

Read [DOCUMENT_PATH].

Report only the questions you'd still need answered before you could plan this well: places where you'd have to guess and a wrong guess would matter. For each, give the question and why the answer changes the plan. Rank them by importance.

Also list, one line each with a reason, any part of the document that looks unnecessary for its stated goal.

Skip anything the document explicitly leaves to the builder, and anything you could reasonably decide yourself. Skip nitpicks about wording.

If nothing important is left and nothing looks unnecessary, say exactly: nothing important left
---
