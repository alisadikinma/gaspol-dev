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

## The page skeleton — copy this, do not reinvent it

The artifact is a tabbed page. **The Logic tab is always present.** A change that touches UI files
gets a second tab holding the mockup; a logic-only change ships **satu tab** — the Logic tab alone,
with no empty Design tab beside it.

The mockup is mounted in an `<iframe srcdoc>`, and that choice is load-bearing rather than
stylistic. A mockup carries its own CSS — `body { background: … }`, bare element selectors — which
would repaint the artifact page itself if pasted inline. `srcdoc` gives it its own document, so its
styles cannot escape. It is `srcdoc` rather than `src` because a published artifact blocks every
request to an external host: `src` would need a URL, and `srcdoc` needs none.

```html
<title>IDS-00 — subject of the ticket</title>
<style>
  :root { --ink:#1a1a1a; --bg:#fff; --line:#d9d9d9; --accent:#1a5fb4; }
  :root:not([data-theme="light"]) { }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) { --ink:#e8e8e8; --bg:#1c1c1c; --line:#3a3a3a; --accent:#78aeed; }
  }
  :root[data-theme="dark"] { --ink:#e8e8e8; --bg:#1c1c1c; --line:#3a3a3a; --accent:#78aeed; }
  body { background:var(--bg); color:var(--ink); font:16px/1.6 system-ui,sans-serif; margin:0; padding:24px; }
  [role="tablist"] { display:flex; gap:4px; border-bottom:1px solid var(--line); margin-bottom:24px; }
  [role="tab"] { background:none; border:0; border-bottom:2px solid transparent; color:inherit;
                 font:inherit; padding:10px 16px; cursor:pointer; }
  [role="tab"][aria-selected="true"] { border-bottom-color:var(--accent); color:var(--accent); }
  [role="tabpanel"][hidden] { display:none; }
  .mockup-frame { width:100%; height:70vh; border:1px solid var(--line); background:#fff; }
</style>

<div role="tablist" aria-label="Design artifact">
  <button role="tab" id="tab-logic" aria-controls="panel-logic" aria-selected="true">Logic</button>
  <button role="tab" id="tab-design" aria-controls="panel-design" aria-selected="false">Design</button>
</div>

<div role="tabpanel" id="panel-logic" aria-labelledby="tab-logic">
  <!-- the five mandatory sections go here -->
</div>

<div role="tabpanel" id="panel-design" aria-labelledby="tab-design" hidden>
  <iframe class="mockup-frame" title="Mockup" srcdoc="&lt;style&gt;body{margin:0}&lt;/style&gt;&lt;p&gt;mockup markup, escaped&lt;/p&gt;"></iframe>
</div>

<script>
  const tabs = [...document.querySelectorAll('[role="tab"]')];
  tabs.forEach(t => t.addEventListener('click', () => {
    tabs.forEach(o => {
      const panel = document.getElementById(o.getAttribute('aria-controls'));
      const on = o === t;
      o.setAttribute('aria-selected', String(on));
      panel.hidden = !on;
    });
  }));
</script>
```

**Dropping the Design tab for a logic-only change** means deleting its `<button role="tab">` and its
`<div role="tabpanel">`. Leave the tablist in place with the single Logic tab; do not leave an empty
Design panel, which reads as "the mockup is missing" rather than "no mockup was owed".

### Escaping the mockup into `srcdoc`

`srcdoc` is an HTML attribute, so the mockup's own markup must be escaped before it goes in: `&`
becomes `&amp;`, `"` becomes `&quot;`, `<` becomes `&lt;`, `>` becomes `&gt;`. Escape `&` first, or
the later replacements get double-escaped.

Where a mockup is too large or too awkward to escape safely, mount it instead as an inline block
whose CSS you have scoped by hand to a wrapper class — **and record which of the two you used** in
the ledger line. A silent switch between the two mechanisms is how the isolation guarantee this
section exists for gets lost without anyone noticing.

## The language the artifact is written in

The artifact is read by a person deciding whether the design is right, so its prose is **plain
Indonesian**: short sentences, one idea each, no process jargon that carries no meaning for the
reader.

**Technical terms stay in English.** Two classes, and the second is the one an over-eager translator
gets wrong:

1. **Literals** — file names, tool names, CLI commands, skill names, error strings, variable names,
   config keys. These must match something real; translating one makes it wrong, not merely awkward.
2. **Ordinary technical vocabulary** — `framework`, `hardisk`, `cache`, `deploy`, `commit`, `branch`,
   `endpoint`, `query`, `build`. Indonesian dictionary equivalents exist (*kerangka kerja*, *cakram
   keras*, *singgahan*) and using them is **worse**: the reader has to translate back to know what is
   meant, so the sentence gets slower, not simpler.

The test for a borderline term is not *"does an Indonesian word exist"* but **"which form does the
reader recognise faster"**. Where the Indonesian word is the everyday one, use it. Where the English
word is what the reader would say out loud, keep the English word.

This applies to the artifact only. `docs/plans/*.md` stay in English — those are read by whoever
maintains the code, and that is a different audience.

## Publishing and approval

1. Write the five sections into the Logic panel of the skeleton above (mermaid blocks render
   natively in artifacts via `<pre class="mermaid">`).
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
