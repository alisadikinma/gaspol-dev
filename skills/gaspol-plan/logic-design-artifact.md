# Logic Design Artifact — the reviewable contract for work with no UI

> Read by `gaspol-plan`'s **Design Artifact (BLOCKING)** step when the plan has no UI phases.
> UI work takes the other lane (`ui-ux-pro-max` / `visual-companion.md`) and does not read this file.

## Why this exists (IDS-10)

`gaspol-brainstorm` Phase 2.5 used to offer `[No, pure backend/logic]`, and that branch skipped the
design phase entirely. `gaspol-plan` then emitted a markdown plan and execution began. For an
enhancement that changes behaviour but not pixels, **the first reviewable thing was the diff** — by
which point the wrong flow has already been built and tested.

Logic has a design. It is just not a picture of a screen: it is the path a request takes, the
states it can end in, and the cases nobody thought about. That is reviewable, and this is the
artifact that makes it so.

## The five sections — all mandatory

A section that does not apply is written down as **not applicable, with the reason**. A blank
section reads as "covered" and is the failure this artifact exists to prevent.

### 1. Before → After behaviour

One row per behaviour the ticket changes.

| # | Trigger | Behaviour NOW | Behaviour AFTER | Why |
|---|---|---|---|---|

The **NOW** column must be **quoted from real code** — file, line, and the actual expression —
never described from memory. If you cannot quote it, you have not read the path you are about to
change, and the design is a guess. This is the same evidence rule `plan-verifier` applies to its
FOUND verdicts.

### 2. Flow diagram

A `mermaid` `flowchart` or `sequenceDiagram` of the changed path, rendered in the artifact.
Sequence when the story is "who calls whom in what order"; flowchart when it is "which branch is
taken". Show the **after** state, with the changed edges marked. One diagram per changed path — a
single diagram covering four unrelated paths is decoration, not a design.

### 3. Data flow / contract table

Reuse the plan's **Data Integration Map** columns verbatim, so the artifact and the plan cannot
drift into disagreeing about the same integration:

| Feature | Data Source | Hook/API | Exists? | Action |
|---|---|---|---|---|

Then one row per **output**: what is produced, who consumes it, and whether that consumer changes.
An output nobody consumes is either dead code being added or a consumer nobody looked for.

### 4. Edge-case matrix

| Input / state | Expected behaviour | Phase that covers it | Test that proves it |
|---|---|---|---|

Enumerate — do not sample. The input space to walk: empty, null, zero, one, maximum, duplicate,
out-of-order, concurrent, malformed, unauthorised, timed-out. Every row names the plan phase that
owns it and the test that will fail if it regresses.

**An empty matrix is a failed gate, never a pass.** "No edge cases" means the enumeration was not
done; the input space of real code is never empty.

### 5. What is NOT changing (blast radius)

Every file the plan touches, and the behaviour in it that must survive unchanged. This is what a
reviewer checks the diff against, and what the regression tests protect. A ticket that cannot state
what it is not changing does not know what it is changing.

## Publishing and approval

1. Write the five sections into a self-contained HTML page (mermaid blocks render natively in
   artifacts via `<pre class="mermaid">`).
2. Publish with the **`Artifact`** tool. Title it after the ticket's subject, not "Design Doc".
3. Ask for approval with **`AskUserQuestion`**:
   `[Approved — start execution]` / `[Change something — say what]` / `[Wrong approach — back to plan]`
4. On approval, record BOTH:
   - `**Artifact:** <url>` in the plan file header, beside `**Ticket:**`
   - `design-artifact: approved — <url>` in the ledger, above `## Log`

`gaspol-execute` reads that ledger line. Until it says `approved`, execution does not start.

## Red Flags

| Rationalization | Why it is wrong |
|---|---|
| "It's just logic, there's nothing to draw" | Then draw the two paths. If they are identical, the ticket changes nothing. |
| "The plan already says this" | The plan says what to build in prose. This shows the flow, which is what a human can actually check. |
| "I'll write the matrix after implementing" | Then it documents what you built, not what it should do. It is a specification, not a report. |
| "The user won't read it" | It costs minutes and catches a wrong flow before it is built and tested. |
| "No edge cases apply here" | Enumerate the eleven listed above and say why each does not apply. Usually two of them do. |
