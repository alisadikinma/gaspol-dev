# Phase Checkpoint Report Template

Use this exact template after completing EACH phase. Do not batch phases. Do not skip sections. Do not mark sections as "N/A" unless truly not applicable.

---

## Template

```markdown
## Phase [X] Complete: [Phase Name]

### Summary
[One sentence describing what this phase accomplished.]

### Implemented
- [Feature/component] — [what it does] with [real data source]
- [Feature/component] — [what it does] with [real data source]
- [Feature/component] — [what it does] with [real data source]

### Data Sources
| Component | Data Needed | Data Source | Type |
|-----------|------------|-------------|------|
| [ComponentName] | [what data it uses] | [where data comes from] | REAL / PLACEHOLDER |
| [ComponentName] | [what data it uses] | [where data comes from] | REAL / PLACEHOLDER |

### Files Modified
| File | Action | Description |
|------|--------|-------------|
| `[absolute path]` | Created | [what the file does] |
| `[absolute path]` | Modified | [what changed and why] |

### Deviations from Plan
- None
OR
- [Description of deviation] — Justification: [why it was necessary]

### Placeholder Report
- Total REAL data sources: [N]
- Total PLACEHOLDER data sources: [N]
- If PLACEHOLDER > 0: [explanation and user approval status]

### Issues / Risks
- None
OR
- [Issue description] — Impact: [what this affects] — Proposed fix: [suggestion]

### Auto-Review (Tiered)

Complexity classifier result: `REVIEW` / `SKIP`

Triggered because (or skipped because):
- Files changed: [N] (threshold: >3 → review)
- LoC changed: [M] (threshold: >100 → review)
- Phase kind: [new-feature / refactor / docs-only / config-only / rename]

**If REVIEW:**
- [code-reviewer findings summary — 3-5 bullets]
- Critical: [count]
- Important: [count]
- Minor: [count]

**If SKIP:**
- Skipped because: [docs-only | config-only | <3 files | <100 LoC | rename-only]
- No review needed for trivial change.

### Next Phase: [X+1] — [Phase Name]
[One sentence describing what the next phase will do.]

-> Waiting for approval before proceeding.
```

**Then update the ledger** (the plan's resolved per-plan `.gaspol/progress/progress-<TICKET>.md`,
see gaspol-execute Checkpoint Rule 6): flip this phase's `## Checklist` line to `- [x] Phase [X]: [name] — DONE`,
then append the log line —
`Phase [X] [name] — COMPLETE — <summary> — NEXT: <phase X+1 name, or "DONE">`. The `### Next Phase`
value above IS the `NEXT:` cursor — carry it into the ledger so a resumed session knows where to pick up.

---

## Rules for Filling the Template

### Summary
- One sentence only.
- Must describe the outcome, not the process.
- Good: "Added SegmentCard component connected to WorkspaceContext for real-time segment display."
- Bad: "Worked on Phase 2 stuff."

### Implemented
- Each bullet is one feature or component.
- Must state the data source explicitly.
- Good: "SegmentCard displays segment text from `useWorkspace()` context"
- Bad: "SegmentCard displays segment text"

### Data Sources
- Every component that renders data must be listed.
- Pure layout components (wrappers, spacers) can be excluded.
- The "Type" column must be exactly `REAL` or `PLACEHOLDER`.
- If any row says `PLACEHOLDER`, the Placeholder Report section must explain why.

### Files Modified
- Use absolute file paths.
- Action must be exactly `Created` or `Modified`.
- Description should explain WHAT changed, not just the file name.

### Deviations from Plan
- If the implementation matches the plan exactly, write "None."
- If anything differs, describe:
  - What the plan said
  - What was actually done
  - Why the deviation was necessary
- The user decides if the deviation is acceptable.

### Placeholder Report
- Count every REAL and PLACEHOLDER data source from the Data Sources table.
- If PLACEHOLDER count is greater than zero, this is a gate.
- The phase cannot be marked complete with placeholders unless the user explicitly approves.

### Issues / Risks
- Report anything that could cause problems in future phases.
- Include: performance concerns, missing dependencies, unclear requirements, technical debt.

### Next Phase
- Must match the next phase in the plan and the TodoWrite list.
- If this is the final phase, replace with:
  ```
  ### All Phases Complete
  -> Proceeding to Completion Gate scan.
  ```

---

## Example: Filled Template

```markdown
## Phase 2 Complete: Segment Card Component

### Summary
Built the SegmentCard component with retention heatmap borders, word count indicators, and director chips, fully connected to WorkspaceContext.

### Implemented
- SegmentCard — renders individual script segments with real data from `useWorkspace()` context
- RetentionBorder — left border color based on segment.type from workspace state
- WaveformBar — word count visualization computed from segment.text.split(' ').length
- DirectorChips — parses segment.visualDirection from workspace state

### Data Sources
| Component | Data Needed | Data Source | Type |
|-----------|------------|-------------|------|
| SegmentCard | segment object | `useWorkspace().segments[i]` | REAL |
| RetentionBorder | segment.type | prop from SegmentCard (workspace source) | REAL |
| WaveformBar | segment.text | prop from SegmentCard (workspace source) | REAL |
| WaveformBar | maxWords limit | `WORD_LIMITS[duration]` from config | REAL |
| DirectorChips | segment.visualDirection | prop from SegmentCard (workspace source) | REAL |

### Files Modified
| File | Action | Description |
|------|--------|-------------|
| `D:\Projects\gaspol_platform\src\components\workspace\SegmentCard.tsx` | Created | Main segment card with retention border and data display |
| `D:\Projects\gaspol_platform\src\components\workspace\RetentionBorder.tsx` | Created | Color-coded left border based on segment type |
| `D:\Projects\gaspol_platform\src\components\workspace\WaveformBar.tsx` | Created | Word count progress bar with overflow indicator |
| `D:\Projects\gaspol_platform\src\components\workspace\DirectorChips.tsx` | Created | Visual direction tag chips |
| `D:\Projects\gaspol_platform\src\screens\Workspace\ScriptStep.tsx` | Modified | Added SegmentCard rendering loop |

### Deviations from Plan
- None

### Placeholder Report
- Total REAL data sources: 5
- Total PLACEHOLDER data sources: 0

### Issues / Risks
- None

### Next Phase: 3 — Hook Selector and Virality Score
Three-hook variant tabs with tinting and compact/expanded score display.

-> Waiting for approval before proceeding.
```

---

## Anti-Patterns

### Too Vague

```markdown
### Implemented
- Built the component
- Added styles
- Connected data
```

This tells the user nothing. Be specific about WHAT was built and WHERE data comes from.

### Missing Data Sources

```markdown
### Data Sources
| Component | Data Needed | Data Source | Type |
|-----------|------------|-------------|------|
| SegmentCard | segment data | props | REAL |
```

"props" is not a data source. WHERE do the props come from? Trace to the root.

### Hidden Placeholders

```markdown
### Placeholder Report
- Total REAL data sources: 5
- Total PLACEHOLDER data sources: 0
```

But the Data Sources table shows `WaveformBar` using `maxWords = 17` hardcoded. This is a placeholder, not a config lookup. Be honest.

### Skipped Sections

```markdown
### Deviations from Plan
N/A

### Issues / Risks
N/A
```

Write "None" explicitly. "N/A" suggests you did not check.
