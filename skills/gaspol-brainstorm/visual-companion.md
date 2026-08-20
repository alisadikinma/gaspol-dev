# Visual Companion Guide (gaspol-brainstorm)

Browser-based companion for showing mockups, diagrams, and options during brainstorming/design.
Server adapted from obra/superpowers (MIT) — see [NOTICE.md](../../NOTICE.md). Rebranded for
gaspol: session files live under `.gaspol/brainstorm/`, brand is text-only (no remote
assets/telemetry), version reads the gaspol plugin manifest.

## When to use (decide per-question, not per-session)

Test: **would the user understand this better by seeing it than reading it?**

- **Browser** — content that IS visual: UI mockups/wireframes/layouts, architecture diagrams,
  side-by-side style/layout comparisons, spatial relationships (state machines, flows).
- **Terminal** — content that is words/tabular: requirements/scope, conceptual A/B/C choices,
  tradeoff lists, API/data-model decisions, clarifying questions.

A question *about* a UI topic is not automatically a visual question.

## Offering it (just-in-time)

Do NOT offer upfront. Wait until a question would genuinely be clearer shown than told. The
first time that happens, offer it as **its own message** — nothing else — and wait for the
answer. On accept, start with `--open`; on decline, continue text-only and don't re-offer.

## Starting

```bash
skills/gaspol-brainstorm/visual-companion/scripts/start-server.sh \
  --project-dir <repo-root> --open
# → prints JSON: {"type":"server-started","url":"http://localhost:PORT/?key=…",
#                 "screen_dir":".../.gaspol/brainstorm/<id>/content",
#                 "state_dir":".../state", ...}
```

Save `screen_dir` and `state_dir`. **Always give the user the COMPLETE `url` including
`?key=…`** — the server returns 403 without it (the key gates HTTP and WebSocket). With
`--open` the browser opens itself; still share the URL as a fallback. Pass `--project-dir` so
mockups persist under `.gaspol/brainstorm/` and a restart reuses the same port (an open tab
reconnects on its own). Add `.gaspol/` to `.gitignore` if absent. Remote/containerized:
`--host 0.0.0.0 --url-host localhost`.

If the URL is unreachable from your browser, the server may have self-exited (it shuts down
when its owner process dies, or after 4h idle). Re-run `start-server.sh` with the same
`--project-dir`.

## The loop

1. **Write HTML to a NEW file in `screen_dir`** (use your file tool, never `cat`/heredoc).
   Semantic filenames (`layout.html`, `style-a-vs-b.html`); never reuse a name. The server
   serves the newest file and pushes it to the browser over WebSocket. Write a **content
   fragment** by default — the server wraps it in the frame (header, theme, click
   infrastructure); only write a full `<!DOCTYPE>`/`<html>` doc when you need full control.
   Feed `ui-ux-pro-max` output (palette, layout blueprint, UX rules) into the markup.
2. **Tell the user what's on screen, remind them of the URL, end your turn.** Ask them to look
   and respond in the terminal (they can click to select).
3. **Next turn:** read `$STATE_DIR/events` (JSON lines) for their clicks/selections.

## Stopping

```bash
skills/gaspol-brainstorm/visual-companion/scripts/stop-server.sh <session_dir>
# session_dir = dirname of screen_dir. Mockups under .gaspol/ are kept for later review.
```

## Verify

`scripts/smoke-test.sh` proves the server boots, serves the keyed bootstrap (200), rejects
unkeyed requests (403 — the auth gate), and stops clean. Screen rendering itself is
WebSocket+browser — validated live when you use the companion.
