---
name: gaspol-verify
description: "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs."
---

# Sparkfluence Verify

Enhanced verification that goes beyond "does it compile?" to "does it match what was planned?"

Three verification layers ensure nothing slips through:
1. **Technical** -- builds, tests, type checks pass
2. **Plan Fidelity** -- implementation matches the plan, phase by phase
3. **Integration** -- real data flows end-to-end, no static stubs

Plus a dedicated **Placeholder Scan** that catches TODO debris before it reaches a commit.

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

"Fresh" means executed RIGHT NOW in this session, not remembered from earlier, not assumed from a subagent report, not inferred from a partial check. Run the command. Read the output. Only then speak.

---

## The Gate Function

Every claim of completion, success, or readiness must pass through these five steps in order. No shortcuts. No skipping.

### Step 1: IDENTIFY
What specific command proves this claim? Write it down before running it. If you cannot name a command, you cannot make the claim.

### Step 2: RUN
Execute the FULL command. Not a subset. Not a dry run. Not from cache. Fresh execution, full scope.

### Step 3: READ
Read the COMPLETE output. Check the exit code. Count failures, warnings, and errors. Do not skim. Do not stop at the first green line.

### Step 4: VERIFY
Does the output actually confirm the specific claim you want to make? "0 failures" confirms "tests pass." "Build complete" with 12 warnings does NOT confirm "build is clean."

### Step 5: ONLY THEN
Make the claim. Quote the evidence. Show the output. Let the user see what you saw.

---

## Layer 1: Technical Verification

Run every applicable check. All must pass before proceeding to Layer 2.

### Build Check
```bash
npm run build
```
- Exit code must be 0
- Zero errors in output (warnings are reported but do not block)
- Check for "Failed to compile" or "Build failed" strings

### Type Check
```bash
npx tsc --noEmit
```
- Exit code must be 0
- Zero type errors
- Report any `any` type warnings if strict mode is on

### Test Suite
```bash
npm test -- --watchAll=false
```
- Exit code must be 0
- All test suites pass
- Zero failing tests (skipped tests are reported)
- Check snapshot mismatches

### Lint Check
```bash
npm run lint
```
- Report error count
- Lint passing does NOT replace build or type check

### Runtime Verification
- If a dev server is running, check browser console for errors
- Check for unhandled promise rejections
- Check for React key warnings or hook order violations

### Evidence Format
```
TECHNICAL VERIFICATION:
  Build:      PASS (exit 0, 0 errors, 3 warnings)
  TypeCheck:  PASS (exit 0, 0 errors)
  Tests:      PASS (14 suites, 47 tests, 0 failures, 2 skipped)
  Lint:       PASS (0 errors, 1 warning)
```

### Evals (for non-deterministic / LLM features)

If the work includes an LLM/prompt/agent feature, deterministic tests are not
sufficient evidence. Run the evals defined for it (`gaspol-eval`, `docs/evals/<feature>.md`)
and report pass@k — a single successful demo is not verification.

```
EVAL VERIFICATION (feature: ticket-classifier):
  Capability:  3/3 passed (pass@3: 100%)
  Regression:  3/3 passed (pass^3: 100%)
```

If no LLM/non-deterministic feature is involved, note "Evals: N/A" and proceed.

---

## Layer 2: Plan Fidelity Check

This is the layer most verification systems skip. It answers: "Did we build what the plan said we would build?"

### Process
1. **Read the plan file** -- locate the plan in `docs/plans/` or wherever it was stored
2. **Extract planned deliverables** -- list every feature, file, component, function, or behavior the plan specifies
3. **Check each deliverable** against the actual implementation:
   - Is the file created/modified as planned?
   - Does the function exist with the correct signature?
   - Does the component render the planned elements?
   - Are the planned data flows connected?
4. **Check the Data Integration Map** -- if the plan specifies which data sources connect to which components, verify each connection exists
5. **Report gaps** -- anything planned but not implemented, or implemented differently than planned

### Deliverable Status Codes
| Status | Meaning |
|--------|---------|
| DONE | Implemented exactly as planned |
| PARTIAL | Implemented but missing planned elements |
| SKIPPED | Not implemented, not mentioned |
| DIVERGED | Implemented differently than planned (explain why) |

### Evidence Format
```
PLAN FIDELITY CHECK (plan: docs/plans/2026-02-10-feature-x.md)
  Phase 1: Component scaffolding ........... DONE (3/3 files)
  Phase 2: Hook integration ................ DONE (2/2 hooks)
  Phase 3: API connection .................. PARTIAL (missing error handler)
  Phase 4: Polish & animations ............. DONE (4/4 items)
  Phase 5: Tests ........................... SKIPPED (0/3 test files)

  Overall: 4/5 phases complete, 1 skipped
  Action required: Phase 3 error handler, Phase 5 tests
```

See `plan-verification.md` in this skill directory for the detailed process, including how to parse plan files and compare against git diff.

---

## Layer 3: Placeholder Scan

Automated detection of incomplete work that should not be committed.

### Pattern Scan
Search the changed files for these patterns:
```
// TODO
// FIXME
// HACK
// XXX
// placeholder
// mock
// dummy
// temp
// stub
// fake
// hardcoded
// PLACEHOLDER
```

Command:
```bash
git diff --name-only HEAD | xargs grep -n -i -E "(TODO|FIXME|HACK|XXX|placeholder|mock data|dummy|temp|stub|hardcoded)" --include="*.ts" --include="*.tsx"
```

### Structural Scan
Detect hardcoded data that should come from hooks, context, or API:
- Arrays/objects defined inline in components with more than 3 items that look like real data (not config)
- String literals that look like API responses or database records
- Numbers that look like IDs or counts but are not constants

### Import Scan
For each component modified, check:
- Does the plan say it should import a hook or context?
- Does it actually import that hook or context?
- If it renders data, where does that data come from? (props, hook, context, or hardcoded?)

### Dead Code Scan
Check for:
- Functions defined but never called in the same file or imported elsewhere
- Variables assigned but never read
- Imports that are not used
- Event handlers attached to nothing

### Debug Scan
Check for development artifacts:
```
console.log
console.warn (non-intentional)
console.error (non-intentional)
debugger
alert(
// @ts-ignore (without justification comment)
// @ts-expect-error (without justification comment)
// eslint-disable (without justification comment)
```

### Evidence Format
```
PLACEHOLDER SCAN:
  Pattern matches:    0 TODOs, 0 FIXMEs, 0 placeholders
  Structural issues:  1 hardcoded array (TopicList.tsx:45 - should use useTrending hook)
  Import gaps:        0
  Dead code:          1 unused function (utils.ts:120 - formatLegacyDate)
  Debug artifacts:    2 console.log statements (Dashboard.tsx:88, Dashboard.tsx:112)

  Status: 3 issues found, must resolve before completion claim
```

---

## Layer 4: Integration + Design Compliance Verification

For every component that connects to a backend service, verify the full data flow. For every UI component, additionally verify design system compliance.

### Hook/Context Connection
For each component:
1. Does it import the correct hook or context?
2. Does it destructure the correct values from that hook?
3. Does it call the hook with the correct arguments?
4. Does it handle the return values (data, loading, error)?

### Data Flow Completeness
Trace the data from source to render:
```
Source (API/DB) --> Hook/Context --> Component Props --> Rendered Output
```
Every link in this chain must exist. A broken chain means the component renders static or stale data.

### State Management
- Are state updates going through the correct dispatch/setter?
- Is derived state computed from the correct sources?
- Are side effects (useEffect) triggered by the correct dependencies?

### Error & Loading States
Every async data flow must handle:
- Loading state (spinner, skeleton, or placeholder)
- Error state (error message, retry button, or fallback)
- Empty state (no data message or call-to-action)

### Evidence Format
```
INTEGRATION VERIFICATION:
  TopicRecommendations:
    Hook:     useTrending() -- CONNECTED
    Data:     topics array from hook -- FLOWING
    Loading:  Skeleton component -- PRESENT
    Error:    Error banner with retry -- PRESENT
    Empty:    "No topics" message -- PRESENT

  ScriptStep:
    Hook:     useWorkspace() -- CONNECTED
    Data:     segments from context -- FLOWING
    Loading:  Not needed (sync) -- N/A
    Error:    N/A (local state) -- N/A
    Empty:    "Generate script" CTA -- PRESENT
```

### Design Compliance Sub-Check (NEW in v1.2 — for UI changesets only)

If the changeset includes any file matching UI extensions (`.tsx/.jsx/.vue/.svelte/.astro/.css/.scss/.sass`), run design compliance audit:

```bash
python3 skills/gaspol-design/scripts/design_audit.py <project-root> --json
```

Validates per file:
- **Design tokens** — all colors/fonts/spacing use tokens from CLAUDE.md design system (no hardcoded `#7C3AED`, no `font-family: Inter`)
- **Responsive breakpoints** — layouts include `sm:/md:/lg:/xl:` breakpoints (Tailwind) or equivalent
- **Component states** — loading, error, empty states implemented per design spec
- **Accessibility** — semantic HTML (`<nav>`, `<main>`, `<button>`), ARIA labels on interactive elements, keyboard navigation (`onKeyDown`, `tabIndex`), WCAG AA contrast ratios

### Evidence Format (Design Sub-Check)
```
DESIGN COMPLIANCE (UI changeset):
  Hardcoded colors:       0 violations                   ✓
  Hardcoded fonts:        0 violations                   ✓
  Responsive breakpoints: 5/5 files                      ✓
  States coverage:
    loading:              5/5 files                      ✓
    error:                4/5 files (LoginForm missing)  ✗
    empty:                3/5 files (2 N/A)              ✓
  A11y:
    aria labels:          5/5 files                      ✓
    semantic HTML:        5/5 files                      ✓
    keyboard nav:         4/5 files (Modal missing)      ✗

  Verdict: 🟡 PARTIAL COMPLIANCE (2 gaps: LoginForm error state, Modal keyboard nav)
  Status: Must resolve or document override before completion claim
```

If design_audit.py reports 🔴 NON-COMPLIANT (score <60) → Layer 4 FAILS. Cannot claim completion until resolved or user approves ship-with-known-gaps.
If 🟡 PARTIAL (60-80) → Layer 4 conditional pass (gaps listed in report, user decides).
If 🟢 COMPLIANT (≥80) → Layer 4 passes for design dimension.

Skip design sub-check entirely if changeset has no UI files.

---

## Common Verification Failures

| Claim | Required Evidence |
|-------|------------------|
| "Tests pass" | Test command output showing 0 failures AND exit code 0 |
| "Build succeeds" | Build command output with exit code 0 and 0 errors |
| "Type check clean" | `tsc --noEmit` with exit code 0 |
| "Bug is fixed" | Reproduce original symptom, verify it no longer occurs |
| "Feature complete" | Plan fidelity check DONE + placeholder scan clean |
| "Ready to commit" | Layers 1-3 all pass |
| "Ready to merge" | All 4 layers pass |
| "Ready for PR" | All 4 layers pass + CLAUDE.md updated if needed |
| "Integration works" | Layer 4 shows all data flows connected |
| "No regressions" | Full test suite pass, not just new tests |

---

## Red Flags

Stop immediately if you catch yourself doing any of these:

- **Hedging language**: Using "should work", "probably fine", "seems to pass" -- RUN the verification
- **Premature satisfaction**: Feeling done before running commands -- you are NOT done
- **About to commit**: Reaching for `git add` without fresh verification -- STOP and verify
- **Trusting subagents**: A subagent said "success" -- verify independently with your own commands
- **Partial checking**: "Linter passed" does not mean "tests pass" does not mean "build succeeds" -- run ALL checks
- **Stale evidence**: "It passed 10 minutes ago" -- run it AGAIN, code changed since then
- **Scope reduction**: "I'll just check the files I changed" -- run FULL suite, you may have broken something else
- **Output skimming**: Reading the first line of test output and assuming the rest is fine -- read ALL of it

---

## Rationalization Prevention

When your internal monologue produces one of these excuses, override it with the reality column.

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification. "Should" is not evidence. |
| "I'm confident" | Confidence is not evidence. Run the command. |
| "Just this once" | No exceptions. The one time you skip is the time it fails. |
| "Linter passed" | Linter checks style. Compiler checks types. Tests check behavior. Three different things. |
| "Agent said success" | Agents can be wrong. Verify independently. |
| "Partial check is enough" | Partial proves nothing about what you did not check. |
| "Plan is basically followed" | Compare explicitly, line by line. "Basically" hides gaps. |
| "Only one placeholder, doesn't matter" | One placeholder is a symptom. There are probably more. Report it. |
| "The placeholder will be replaced later" | Later means never. Report it now. Fix it now. |
| "It's just a small change" | Small changes break big systems. Verify like any other change. |
| "The user is in a hurry" | A false completion claim wastes more time than verification takes. |
| "I already checked something similar" | Similar is not identical. Check THIS specific claim. |

---

## Why This Matters

These rules exist because of real failures, not theoretical concerns:

- **"Done!"** -- Review found 5 TODO comments and 3 hardcoded arrays that should have been hooked up to context. Two hours of rework.
- **"All integrated!"** -- Component imported zero hooks, rendered entirely static JSX. Looked complete in screenshots but did nothing.
- **"Plan followed!"** -- 2 of 8 planned phases quietly skipped. Discovered during user testing when features were missing.
- **"Tests pass!"** -- Tests passed because the new test file had `test.skip()` on every test. Zero actual coverage.
- **"Build clean!"** -- Build succeeded but `tsc --noEmit` revealed 14 type errors hidden by `any` casts.

Every rule here prevents a specific, observed failure mode. None are theoretical.

---

## Integration with Other Skills

### Called By
- `gaspol-execute` -- runs gaspol-verify after all implementation phases complete

### Calls (on success)
- `gaspol-sync-docs` -- triggers CLAUDE.md and documentation sync after verification passes

### Pairs With
- `gaspol-review` -- code quality review runs after verification confirms correctness

### Execution Order
```
gaspol-execute (implementation)
  --> gaspol-verify (this skill - correctness proof)
    --> gaspol-sync-docs (documentation sync)
    --> gaspol-review (code quality)
```

### Failure Handling
If any verification layer fails:
1. Do NOT proceed to sync-docs or review
2. Report the specific failures with evidence
3. Fix the issues
4. Re-run the FULL verification (not just the failed layer)
5. Only proceed when all layers pass
