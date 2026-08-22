**Ticket:** IDS-13
**Artifact:** https://claude.ai/code/artifact/9c895807-fe80-4c40-babd-95cf22960efd
**Spec:** [2026-08-22-IDS-13-live-app-check-web-mobile-spec.md](2026-08-22-IDS-13-live-app-check-web-mobile-spec.md)
**Ledger:** `.gaspol/progress/PROGRESS-IDS-13.md`
**Execute with:** `gaspol-execute`

# Plan — Live App Check

## Data Integration Map

| Feature | Data Source | Read by | Exists? | Action |
|---|---|---|---|---|
| Lane detection | `scripts/detect-app-target` | the rule | no | add, sibling of detect-stack |
| adb path | `$ADB` / PATH / `$ANDROID_HOME` / SDK defaults | the detector | no | add — PATH alone was wrong |
| Web driving | Playwright MCP | the rule | yes, session-provided | reference softly |
| Readiness wait | `gaspol-debug/condition-based-waiting.md` | the rule | yes | reuse, never a fixed sleep |
| The gate | `gaspol-verify` Layer 1 Live App Check | the verify chain | yes, as prose only | give it the mechanism |

## Checklist

- [x] Phase A — failing test
- [x] Phase B — `detect-app-target` with `--self-test`
- [x] Phase C — `skills/_shared/live-app-check.md`, both lanes
- [x] Phase D — wire into `gaspol-verify`; docs, 1.23.0

## Phase A: Failing test

`test-live-app-check.sh` asserts the detector exists and self-tests, the security invariant, both
lanes and their literal probes, three states with "not run" never a pass, AskUserQuestion on no
device, condition-based waiting with a negative assertion against a fixed sleep, evidence
(screenshot/console) and the forbidden adjective verdict, and that `gaspol-verify` defers to the
shared rule while keeping its `N/A` path.

## Phase B: The detector

Marker-driven lanes; Flutter checked BEFORE android/ios so one app does not report three lanes.
`--self-test` covers: bare dir emits nothing; a `package.json` script **body** never leaks into
stdout; an android marker yields a probe or `UNKNOWN`, never silence; a Flutter project emits
exactly one lane; adb under `$ANDROID_HOME` resolves with PATH empty; a spaced path comes back
quoted; a missing directory exits 1.

## Phase C: The rule

Web lane (start → condition-wait → Playwright → capture → tear down), mobile lane (resolve adb →
four-outcome probe → ask/offer → the literal adb run), the never-as-passed rule, the outcome
vocabulary, and the forbidden verdicts.

## Phase D: Wire and document

`gaspol-verify` Layer 1 derives the lane and defers to the shared rule. CLAUDE.md section,
CHANGELOG, version 1.23.0 across plugin.json and the gaspol-one listing.

## Red Flags

- Describing the mobile lane as if gaspol could run it unaided would be the gate starting to lie.
- Deleting the `N/A` path to make the gate stricter would make it unusable, and an unusable gate
  gets switched off — costing more than the false alarms it prevents.
