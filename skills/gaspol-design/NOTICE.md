# Attribution & License

## Incorporated Work

This skill (`gaspol-design`) incorporates data files, templates, and reasoning engine scripts adapted from **ui-ux-pro-max-skill v2.0** by Next Level Builder:

- Source: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- License: MIT License (Copyright (c) 2024 Next Level Builder)
- Specifically incorporated:
  - `data/*.csv` — 15 CSV files (styles, colors, typography, charts, UX guidelines, reasoning rules, etc.)
  - `scripts/core.py`, `scripts/design_system.py`, `scripts/search.py` — reasoning engine foundation
  - `templates/base/` and `templates/platforms/` — multi-framework component templates

## Extensions and Modifications (gaspol-dev)

The gaspol-design skill extends the base ui-ux-pro-max functionality with:

1. **Project context integration** — reads CLAUDE.md from target project to respect existing design tokens
2. **KB cross-project learning** — queries `~/.claude/gaspol-knowledge/ui-patterns/` for past project patterns
3. **Anti-AI-slop enforcement rules** — `rules/anti-ai-slop.md` (hard enforcement: no Inter default, no purple gradient on white, etc.)
4. **Planning integration** — active during `gaspol-plan` for per-UI-phase design deliverable
5. **Execute fidelity check** — `scripts/design-audit.py` scans codebase vs design system during execution
6. **Verify Layer 4 extension** — design system compliance sub-check
7. **KB capture integration** — UI patterns auto-captured by `gaspol-learn` after `gaspol-finish`

## MIT License

```
MIT License

Copyright (c) 2024 Next Level Builder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## gaspol-dev License

The gaspol-dev extensions are licensed under MIT License (Copyright (c) 2026 Ali Sadikin Ma), compatible with the incorporated ui-ux-pro-max-skill license.
