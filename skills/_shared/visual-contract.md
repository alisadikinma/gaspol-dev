# Visual Contract — the canvas format `geometry-diff` reads

**Origin: IDS-6 Part B.** "Compare the screenshot to the mockup" turned out to have a missing
left-hand side — there was nothing to compare against. IDS-6 specified a canvas carrying
`data-vv` markers as that reference; that format existed nowhere in this repository until now.
This file states the format once, so `geometry-diff` (`skills/gaspol-verify/scripts/`) and
`live-app-check.md`'s web lane read the same contract instead of each guessing at it.

## The five things this file is the single source for

### 1. Marker naming

Every element the diff should compare carries `data-vv="<screen>.<element>"` — a screen name, a
dot, an element name (`hero.cta`, `pricing.plan-pro-button`). This is the ONLY attribute
`geometry-diff`'s extractor reads (`document.querySelectorAll('[data-vv]')`); an element with no
marker is invisible to the diff, and that is by design — not every element on a screen needs a
comparison, only the ones the design actually commits to.

### 2. Markup in the project's own stack

Write the canvas markup in the target project's real stack (React/Vue/Svelte/plain HTML —
whatever it actually is), not a stack-neutral sketch. The implementer must be able to COPY the
canvas markup into the real component rather than TRANSLATE it from one syntax to another —
translation is where drift enters before a single review has happened.

### 3. Realistic worst-case content

Fill every marked element with the longest or busiest content the design must actually survive —
a real name instead of "John Doe", a full paragraph instead of "Lorem ipsum", a five-digit price
instead of "$9.99" — never placeholder-shaped placeholder content. A canvas that only ever shows
its best case cannot catch the layout break its worst case would have caused.

### 4. Where the file lives

`docs/plans/YYYY-MM-DD-<TICKET>-<topic>-canvas.html`, on the ticket branch — the same
date-first, ticket-prefixed convention every other plan artifact in this repository already
follows (see the root CLAUDE.md's "Worktree + ticket documents" standard). It is a versioned
artifact, not working-tree scratch: committed on the branch, it appears in `main` at merge, same
as the spec and plan files beside it.

### 5. What this ticket (IDS-14) does NOT build

Naming the deferral here is what keeps it from being mistaken for completion — the same shape
IDS-7's design gate sat unwired for five versions without anyone noticing. Not built by this
ticket, still open under IDS-6 Part B:

- **`gaspol-visual-verify` as a skill** — a dedicated skill orchestrating canvas authoring and
  comparison. This ticket wires `geometry-diff` directly into `live-app-check.md` instead.
- **The two-fidelity restructure of `gaspol-brainstorm` and `gaspol-plan`** — splitting design
  work into a low-fidelity and high-fidelity pass, with the canvas as the high-fidelity
  deliverable. Brainstorm and plan are unchanged by this ticket.
- **The pixel-diff trigger** — a stored reference image and a pixel-comparison library, answering
  *that* something differs outside what geometry alone measures. Worth building only once the
  geometry pass (this ticket) is trusted; not worth anything before that.
- **The `§ Execution` / `§ Mapping` canvas sections** — additional canvas metadata IDS-6 sketched
  for richer authoring context. The marker format above (`data-vv` naming, stack, content, path)
  is the whole of what this ticket's machine reads.

The machine had to exist before the process depending on it was worth changing — the same order
IDS-13 used for Live App Check (`detect-app-target` before the protocol before the wiring). This
file and `geometry-diff` are that machine. The rest of Part B stays a decision for later, made
easier because there is now something real to decide about.

## What reads this file

- `python3 skills/gaspol-verify/scripts/geometry-diff --emit-extractor` — the extractor this
  contract's markers feed.
- `skills/_shared/live-app-check.md`, web lane — runs the extractor against the canvas (if one
  exists for the ticket) and against the running app, then diffs the two snapshots.
