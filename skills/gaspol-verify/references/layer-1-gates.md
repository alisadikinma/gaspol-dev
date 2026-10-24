# Layer 1 gates: detail

`SKILL.md` states each gate's condition and consequence. This file holds the state tables, the
line formats and the reasons.

## detect-stack: the three result shapes

```bash
skills/gaspol-execute/scripts/detect-stack <project-root>
```

Layer 1 does NOT hardcode `npm run build` / `npx tsc --noEmit` / `npm test` / `npm run lint`.
Those are one stack's commands, and hardcoding them silently skips verification on every
non-node project. Run every line `detect-stack` prints. Never conflate the three shapes:

1. **`<level>: <command>`** (for example `unit: npm test`, `static: npx tsc --noEmit`,
   `build: npm run build`, `lint: npm run lint`; these are EXAMPLE outputs for a node project,
   not required commands in themselves). Run it. The exit code must be 0.
2. **`<level>: UNKNOWN`**. The marker file proves the stack but nothing backs the command (no
   `.scripts` key, no vendor binary, no tool on PATH). **STOP and ask the user** what the
   correct command is for that level. Never guess, never silently skip it.
3. **Zero lines** (no stack markers at all, such as the gaspol-dev repo itself, a pure-markdown
   plugin). No automated command can be derived. Fall back to the commands the plan wrote into
   each phase's `Verification` block (`gaspol-plan` copies `detect-stack` output into the plan
   at write time for exactly this case). Record `detect-stack: no stack markers, using
   plan-declared commands`. Do not silently skip Layer 1.

Report every executed check the same way regardless of level name: exit code 0, zero errors,
warnings reported but not blocking.

## Runtime verification

- If a dev server is running, check the browser console for errors.
- Check for unhandled promise rejections.
- Check for React key warnings or hook order violations.

## Live App Check

Everything else in Layer 1 is static: it compiles, the tests pass, the build succeeds. All of
that can be true of an app that does not work. This is the only check that answers *does it
actually run*, and defects have shipped past green unit tests and per-feature e2e, surfacing only
in real browser or device use.

Derive the lane, never assume it:

```bash
skills/gaspol-execute/scripts/detect-app-target <project-root>
```

The full protocol is [skills/_shared/live-app-check.md](../../_shared/live-app-check.md). Read it
rather than improvising: the two lanes have different preconditions and one of them gaspol cannot
satisfy on its own.

- **web**: start the app, wait **by condition** (never a fixed sleep), drive the changed surface
  through the **Playwright MCP**, capture a screenshot + console output + failed requests.
- **android / ios / flutter**: probe first (`adb devices`, `xcrun simctl list devices booted`). A
  run needs **a device connected over USB with debugging enabled, or a booted emulator**, and
  gaspol cannot plug in a phone. No device: **AskUserQuestion** with connect one / let gaspol
  *offer* to boot a simulator / skip. Tooling missing: `UNKNOWN`, STOP and ask.
- **no lines printed**: `live-app-check: no app surface`. Not a failure, not a pass.

**The rule that outranks the rest:** a check that did not run is recorded as **not run**, never
as passed. This is the rule the chain already applies to an unavailable `/security-review`. A
lane that could not run and got summarised as "verified" leaves the gate worse than useless,
because now somebody believes it was checked.

`N/A` stays available for pure backend, config and docs changes, **with the reason written
down**: `live-app-check: N/A — no UI or user-visible surface (<reason>)`. An unusable gate gets
switched off, which costs more than the false alarms it prevents.

## Regression Gate

Does this branch fix a bug, and if so did it leave a regression test? `gaspol-debug` Phase 4
used to say "(if possible)", with nothing checking whether it was possible or whether one was
written. This is the machine:

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it this would run whatever
script the target project happens to ship at a matching relative path}"
"$CLAUDE_PLUGIN_ROOT/skills/gaspol-debug/scripts/regression-gate" <BASE>
```

Record the verdict beside `live-app-check:`.

| Exit | Meaning |
|---|---|
| 0 | satisfied |
| 1 | BLOCKING. A fix commit exists in `<BASE>..HEAD` with no `regression-test:` line in the ledger, or only a bare `N/A`/`not run` with no reason |
| 3 | UNKNOWN. The ledger could not be resolved or read. STOP and ask, never treat this as satisfied |
| 4 | not applicable, no fix commits in range. **Never counted as a pass**, the same reason `live-app-check: no app surface` is not one |

## Ledger Gate

Does this branch's ticket have a progress ledger at all, and is it structurally sound? The
ledger had exactly ONE creator (`gaspol-plan` step 7) and no reader that checked it existed.
Measured across all 18 IDS tickets in this repository, the ledger was present if and only if a
plan file was: IDS-3, IDS-5, IDS-9 and IDS-15 had neither. Every path that reaches code without
passing through `gaspol-plan` produced no ledger, and nothing noticed. This is the machine:

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it this would run whatever
script the target project happens to ship at a matching relative path}"
"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/ledger-gate" <BASE>
```

Record the verdict as `ledger:` beside `live-app-check:`.

| Exit | Meaning | What you must do |
|---|---|---|
| **0** | a ledger exists for this branch's ticket and its structure is sound | proceed |
| **1** | **BLOCKING**: a ticket resolved, the branch changed code, and no ledger exists | create the ledger before claiming anything is verified. Do not tick a checklist retroactively from memory: write what you can actually evidence, and record the rest as unknown |
| **3** | **UNKNOWN, STOP and ask.** The ledger exists but is empty, has no `## Checklist`, carries a block below `## Log`, or cannot be read; or BASE is not a valid ref; or two plans in the diff name different tickets | never treat this as satisfied. A ledger with a block below `## Log` still exists, so `scan-active-ledgers` reads the wrong last line and reports this ticket's state **wrongly**. That is worse than an absent file, which at least reports nothing |
| **4** | not applicable: no ticket on this branch, or nothing but ignored paths changed. **Never counted as a pass** | record the line with its reason: `ledger: N/A — no ticket on this branch` or `ledger: N/A — docs-only branch, no code commits`. A bare `N/A` with nothing after the dash is refused |

**What this gate does NOT do.** It checks that a ledger EXISTS and has the right SHAPE. It never
checks whether its content is honest: a checklist ticked without the work being done passes
with exit 0. This closes the silent-skip hole, not the recorded-but-false hole.

## Model Tier Gate

Does every model declaration sit on the tier the rule assigns it? The rule is two tiers, **Opus
judges, Sonnet works**. Until IDS-20 it was an "auto-rubric to choose from" that had drifted in
ten places, including four reviewer prompt files and a sentence instructing an override to a
tier nobody had chosen deliberately in months. This is the machine:

```bash
: "${CLAUDE_PLUGIN_ROOT:?set by Claude Code for plugin skills. Without it this would run whatever
script the target project happens to ship at a matching relative path}"
"$CLAUDE_PLUGIN_ROOT/skills/gaspol-verify/scripts/model-gate"
```

Record the verdict as `model-tier:` beside `ledger:`.

| Exit | Meaning | What you must do |
|---|---|---|
| **0** | every declaration is on its tier | proceed. Unrecognised values are listed and not blocked |
| **1** | **BLOCKING**: a declaration names the wrong tier, or the deleted third tier appears anywhere in markdown | fix the declaration. Where a reason accompanied the old model, rewrite the reason too: a justification for the old tier left standing under the new one documents the opposite of what the file does |
| **3** | **UNKNOWN, STOP and ask.** A declaration whose tier cannot be determined, or an agent with no `model:` field | do not guess a tier. Guessing is what the rule exists to stop. Either the path/line makes the role clear, or the file declares its own tier with a `model-tier: judge` / `model-tier: exec` line |
| **4** | not applicable: nothing declares a model. **Never counted as a pass** | record `model-tier: N/A — <reason>` |

**What this gate does NOT do.** It reads **declarations**, never the model a dispatched subagent
was actually served. If the harness ignores the field, this still passes. It closes the drift
hole, not the execution hole. The full rule, and what each of its choices gives up, is in
[docs/rubric-model-switching.md](../../../docs/rubric-model-switching.md).

## Evidence Format

```
TECHNICAL VERIFICATION (detect-stack: node):
  static: PASS (npx tsc --noEmit, exit 0, 0 errors)
  lint:   PASS (npm run lint, 0 errors, 1 warning)
  unit:   PASS (npm test, 14 suites, 47 tests, 0 failures, 2 skipped)
  build:  PASS (npm run build, exit 0, 0 errors, 3 warnings)
  live-app-check: PASS (web lane, screenshot attached)
  regression-test: tests/auth.spec.ts::rejects expired token — RED at 4f2a1c9, GREEN after fix
  ledger: ok — IDS-19 has a valid ledger at .gaspol/progress/PROGRESS-IDS-19.md
  model-tier: ok — 19 declaration(s) on the correct tier; 2 unrecognised value(s) reported
```

Or, when no stack markers exist:

```
TECHNICAL VERIFICATION (detect-stack: no stack markers, using plan-declared commands):
  <phase's plan-declared command>: PASS (exit 0)
```

## Evals (non-deterministic / LLM features)

If the work includes an LLM/prompt/agent feature, deterministic tests are not sufficient
evidence. Run the evals defined for it (`docs/evals/<feature>.md`) and report pass@k. A single
successful demo is not verification.

```
EVAL VERIFICATION (feature: ticket-classifier):
  Capability:  3/3 passed (pass@3: 100%)
  Regression:  3/3 passed (pass^3: 100%)
```

If no LLM/non-deterministic feature is involved, note "Evals: N/A" and proceed.

## Why these gates exist

Every rule in `SKILL.md` prevents an observed failure: "Done!" over 5 TODOs and 3 hardcoded arrays; "All integrated!" from a component that imported zero hooks; "Plan followed!" with 2 of 8 phases skipped; "Tests pass!" because every test had `test.skip()`; "Build clean!" while `tsc --noEmit` showed 14 errors hidden by `any` casts.
