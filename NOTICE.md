# NOTICE

gaspol-dev (MIT) incorporates adapted third-party material:

## Visual brainstorm companion (v1.7)

`skills/gaspol-brainstorm/visual-companion/scripts/` (server.cjs, helper.js,
frame-template.html, start-server.sh, stop-server.sh) is adapted from
**obra/superpowers** (MIT License) — the `skills/brainstorming` visual companion.

Changes for gaspol: session files relocated to `.gaspol/brainstorm/`; brand reduced to
local text-only (the remote brand-image fetch to primeradiant.com and the telemetry
plumbing were removed — the server makes no outbound network requests); version reader
points at the gaspol plugin manifest. The interactive loop, session-key auth, WebSocket
protocol, and path-traversal guards are unchanged from the upstream MIT source.

Upstream: https://github.com/obra/superpowers (MIT, Jesse Vincent / Prime Radiant)

## UI/UX design data (v1.2)

gaspol-dev previously vendored a fork of the **ui-ux-pro-max** design data (MIT) inside its
own design skill. **That fork was removed in v1.14.0 (IDS-2)** — gaspol now delegates design
intelligence to the upstream `ui-ux-pro-max` plugin directly rather than carrying a copy that
drifts. The attribution stands for the versions that shipped the fork.

## ECC skill ports (v1.4)

`gaspol-security-review` and `gaspol-eval` are adapted from the **Everything Claude Code**
(ECC) `security-review` and `eval-harness` skills (MIT, Affaan Mustafa).
