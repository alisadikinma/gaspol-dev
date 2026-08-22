# Live App Check — running the thing, on the two lanes that actually exist

> Read by `gaspol-verify` Layer 1. Stated once here.
>
> Everything else gaspol verifies is **static**: the code compiles, the tests pass, the build
> succeeds, the plan's items are present. All of that can be true of an app that does not work.
> This is the only check that answers *does it actually run.*

## Why this exists (IDS-13)

`gaspol-verify` has carried a "Live App Check (mandatory for UI / user-visible changes)" since
v1.14, and its entire content was an instruction: *"invoke the `run` skill to actually launch the
app and observe the feature live."* Nothing detected what kind of app it was, nothing checked
whether launching was even possible, and nothing recorded what was seen. A rule that tells you to,
with no machine that does — the shape IDS-7 (a design gate never wired up) and IDS-8 (a setting
nothing read) were both about.

## The lane is derived, never assumed

```bash
skills/gaspol-execute/scripts/detect-app-target <project-root>
```

Sibling of `detect-stack`, same security invariant (every printed command is a literal; nothing
read out of a scanned project file reaches stdout, because the caller **runs** what it prints).

| It prints | Meaning |
|---|---|
| `web: npm run dev` | web lane, and how to bring the app up |
| `android: <resolved adb> devices` | Android lane, and its readiness probe — bare `adb` when on PATH, an absolute SDK path otherwise |
| `ios: xcrun simctl list devices booted` | iOS lane, and its readiness probe |
| `flutter: flutter devices` | one lane for a Flutter app, not three |
| `<lane>: UNKNOWN — <tool> not installed` | the marker is there, the tool is not |
| **nothing at all** | no runnable app surface — a library, a docs repo, a skills repo |

Zero lines is **not** a failure and **not** a pass. Record `live-app-check: no app surface`.

---

## Web lane — Playwright MCP

gaspol can satisfy this lane's precondition itself: it starts the app.

1. **Bring the app up** with the printed start command, in the background.
2. **Wait by condition, never by a fixed sleep.** Poll the URL until it answers, with a timeout
   and a stated failure. `skills/gaspol-debug/condition-based-waiting.md` already explains why a
   fixed sleep is a flake generator: it is simultaneously too short on a slow machine and wasted
   time on a fast one, and when it fails it fails *intermittently*, which is the most expensive
   kind of failure to chase.
3. **Drive it through the Playwright MCP tools** — navigate, snapshot, interact with the feature
   the change actually touched. Not the home page. The thing that changed.
4. **Capture, every run:**
   - a **screenshot** of the changed surface
   - the browser **console** output — any error or unhandled rejection is a finding, even when the
     page looks fine
   - **failed network requests** — a 4xx/5xx behind a page that renders is exactly the defect that
     survives a green test suite
5. Tear the app back down.

**If the MCP is not connected**, say so and record `live-app-check: web lane not run — Playwright
MCP unavailable`. Do the closest honest thing (start the app, curl the route, report what came
back) and label it as the lesser check it is.

---

## Mobile lane — a precondition gaspol cannot satisfy

This is the part that makes the two lanes genuinely different, and it must not be papered over.
An Android or iOS E2E run needs **a real device connected over USB with debugging enabled, or a
booted emulator/simulator.** gaspol cannot plug in a phone. It can detect, offer, and ask.

### Finding adb — `command -v adb` is not enough

`detect-app-target` resolves adb in this order: `$ADB` → PATH → `$ANDROID_HOME` →
`$ANDROID_SDK_ROOT` → `~/Library/Android/sdk/platform-tools/adb` (macOS) →
`~/Android/Sdk/platform-tools/adb` (Linux), and prints the resolved path.

The order exists because PATH-only detection **failed on the first machine this ran on**: adb was
installed at `~/Library/Android/sdk/platform-tools/adb`, `ANDROID_HOME` was unset, and nothing was
on PATH. Android Studio does not add adb to PATH and most people never export `ANDROID_HOME`, so
that is the *common* case, not the exotic one. Under this file's own contract a false `UNKNOWN`
means "STOP and ask the user" — gaspol halting to ask for a tool sitting right there. A detector
that is wrong in the common case is worse than no detector, because its wrongness looks like a
finding.

### Probe first

Run the probe `detect-app-target` printed. `adb devices` has **four** meaningful outcomes, not two:

| Probe result | State | What to do |
|---|---|---|
| a device or emulator listed as `device` | **ready** | run the E2E |
| a device listed as **`unauthorized`** | **needs a tap** | the phone is plugged in and the RSA prompt has not been accepted. Tell the user to unlock the phone and accept *"Allow USB debugging"*, then re-probe. This is NOT "no device", and telling them to plug in a phone they already plugged in is the reply that wastes their time |
| a device listed as **`offline`** | **stale connection** | `adb kill-server && adb start-server`, re-probe once; if still offline, treat as no device and ask |
| nothing listed | **no device** | **AskUserQuestion** — see below |
| `adb` / `xcrun` / `flutter` cannot be resolved | **UNKNOWN** | record `live-app-check: UNKNOWN — <tool> not installed`, **STOP and ask**. A missing tool is not an absent device, and neither is a pass |

**On "no device", ask — do not guess:**

- `[Saya colokin HP sekarang]` — the user connects a device with USB debugging enabled, then the
  probe is re-run. Physical device is the higher-fidelity option and the only one that catches
  real hardware behaviour.
- `[Boot an emulator/simulator for me]` — gaspol **offers** this and runs it only on acceptance
  (`xcrun simctl boot <device>`, or the project's emulator launch command). Booting a simulator
  starts a heavy process on someone's machine; it is offered, never taken silently — the same
  restraint `extract-design-tokens` applies to writing a file into a repository.
- `[Skip the live check this time]` — allowed, and recorded as
  `live-app-check: mobile lane not run — no device connected`. Never as passed.

### The adb run, once a device is ready

Literal commands, in order. `<adb>` is whatever `detect-app-target` resolved:

```bash
<adb> devices                                   # 1. confirm state is `device`
<adb> logcat -c                                 # 2. clear the log FIRST, or you
                                                #    read yesterday's errors and
                                                #    chase a bug that is not there
# 3. install / launch — whichever the project uses:
#    <adb> install -r <path/to/app.apk>
#    flutter run -d <device-id>
#    npx react-native run-android
<adb> exec-out screencap -p > <shot>.png        # 4. evidence of the changed screen
<adb> logcat -d                                 # 5. everything since the clear
```

Two practical notes that decide whether this works at all:

- **Clear the log before, dump it after.** Without `logcat -c` first, the dump carries hours of
  unrelated output and the real error is invisible inside it.
- **`exec-out`, not `shell`.** `adb shell screencap` mangles the PNG through the terminal's line
  endings on some hosts and produces a corrupt file that opens as garbage; `exec-out` is binary-safe.

**Capture, every run:** the **screenshot**, the **logcat dump** for the app under test, and any
crash or ANR. Same reasoning as the web lane — a screen that renders over a swallowed exception is
the defect static checks cannot see.

---

## The rule that outranks the rest

**A check that did not run is recorded as not run. Never as passed.**

This is the rule `gaspol-finish` already applies to an unavailable `/security-review`, and it is
the whole reason this file can be trusted. The failure mode it prevents is specific and it is the
one that actually happens: a mobile lane that could not run gets summarised as "verified", the
branch merges, and the gate has made things *worse* than having no gate — because now somebody
believes it was checked.

Every outcome is one of:

```
live-app-check: web lane pass — <screenshot path>, console clean, 0 failed requests
live-app-check: android lane pass — <screenshot path>, logcat clean (device <id>)
live-app-check: android lane not run — device connected but unauthorized (USB prompt not accepted)
live-app-check: mobile lane not run — no device connected
live-app-check: UNKNOWN — adb not installed
live-app-check: no app surface
live-app-check: N/A — no UI or user-visible surface in this change (<reason>)
```

`N/A` stays available for pure backend, config, and docs changes, with the reason written down.
Removing it would make the gate unusable on the majority of changes, and an unusable gate gets
switched off — which costs more than the false alarms it was meant to prevent.

## Forbidden verdicts

| Never write | Why |
|---|---|
| "looks right" / "looks good" / "looks fine" | An adjective is not an observation. Say what you saw, on which screen, with the screenshot attached. |
| "should work now" | Then it was not run. Say that instead. |
| "the tests pass so the app works" | This file exists precisely because that inference is false. |
| a pass with no screenshot | The screenshot **is** the evidence. Without it the claim is unverifiable, which Iron Law 3 treats as no claim at all. |
