**Ticket:** IDS-13

# Live App Check — two lanes, real preconditions

## Why

IDS-12 made the in-session path run its checks. All of them are static: the code compiles, the
tests pass, the build succeeds. **Every one of those can be true of an app that does not work.**

`gaspol-verify` already had the gate meant to close that — "Live App Check (mandatory for UI /
user-visible changes)", since v1.14 — and its entire content was an instruction:

> *"invoke the `run` skill to actually launch the app and observe the feature live"*

Nothing detected what kind of app it was. Nothing checked whether launching was possible. Nothing
recorded what was observed. IDS-7 shipped a design gate that was never wired up; IDS-8 shipped a
setting nothing read. Same shape, third time.

## The two lanes are not symmetrical, and that is the design

| Lane | Precondition | Can gaspol satisfy it alone? |
|---|---|---|
| web | an app serving a URL | **yes** — start it, wait, drive it via the Playwright MCP |
| android / ios / flutter | a device connected over **USB debugging**, or a booted emulator | **no.** gaspol cannot plug in a phone |

Treating the mobile lane as if gaspol could just run it is how a gate starts lying. It probes,
**offers** to boot a simulator, and asks — never boots one silently, the same restraint
`extract-design-tokens` applies to writing a file into someone's repository.

## Two defects the first real run surfaced

Both were found by running the thing, not by reading it — which is this ticket's own point.

**1. `command -v adb` is wrong in the COMMON case.** On the first machine this ran on, adb sat at
`~/Library/Android/sdk/platform-tools/adb`, `ANDROID_HOME` was unset, and PATH had nothing. Android
Studio does not add adb to PATH and most people never export the variable. Under this plugin's own
contract a false `UNKNOWN` means STOP-and-ask — gaspol halting to ask for a tool sitting right
there. **A detector that is wrong in the common case is worse than no detector, because its
wrongness looks like a finding.** Resolution order is now `$ADB` → PATH → `$ANDROID_HOME` →
`$ANDROID_SDK_ROOT` → macOS default → Linux default, and a resolved path containing a space is
printed quoted.

**2. `adb devices` has four outcomes, not two.** `device` (ready) · `unauthorized` (plugged in, RSA
prompt not accepted) · `offline` (stale server) · nothing (no device). Answering `unauthorized`
with "please connect a device" tells the user to plug in a phone they already plugged in — the
single most wasteful reply available.

## Definition of done

- The lane is derived by `detect-app-target`, never assumed; zero lines means "no app surface",
  which is neither failure nor pass.
- The web lane drives **the changed surface**, not the home page, and captures screenshot +
  console + failed requests.
- The mobile lane distinguishes all four probe outcomes and asks rather than guessing.
- **A check that did not run is recorded as not run, never as passed** — the `/security-review`
  rule, applied here.
- `N/A` survives for non-UI changes, with the reason written down.
