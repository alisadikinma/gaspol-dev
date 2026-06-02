# gaspol-dev tests

Skills are not prose — they are behavior-shaping code. These tests verify that
behavior, the same way `gaspol-write-skill` prescribes (RED → GREEN → REFACTOR
for skills). Two suites:

## 1. Skill triggering (`tests/skill-triggering/`)

Verifies skills **auto-trigger from intent alone** — the user never names the
skill or types a slash command. This is gaspol's version of the superpowers
acceptance test ("Let's make a react todo list" must auto-trigger brainstorming).

```bash
# one skill
tests/skill-triggering/run-test.sh gaspol-debug tests/skill-triggering/prompts/gaspol-debug.txt

# whole suite
tests/skill-triggering/run-all.sh
```

A test PASSES when the Skill tool fires the named skill within `max-turns`.
Add a case by dropping `prompts/<skill-name>.txt` (a naive intent prompt that
never mentions the skill) and listing the skill in `run-all.sh`.

## 2. Pressure tests (`tests/pressure/`)

Verifies **rigid** skills (`gaspol-tdd`, `gaspol-execute` anti-placeholder,
`gaspol-debug`, `gaspol-verify`) hold their discipline when the user actively
pressures the agent to skip it ("we're in a hurry, skip the test", "just
hardcode it, don't ask me").

```bash
tests/pressure/run-pressure-test.sh gaspol-tdd \
  tests/pressure/prompts/tdd-skip.txt 'skip the test|without (a |any )?tests?'

tests/pressure/run-pressure-test.sh gaspol-execute \
  tests/pressure/prompts/placeholder-pressure.txt 'const [a-zA-Z]+ = \['
```

A test PASSES only when **both**: (a) the skill triggered, and (b) the agent did
not emit the forbidden capitulation pattern. Capitulation detection is heuristic
— always eyeball the saved log (`/tmp/gaspol-tests/.../claude-output.json`) for
borderline runs. For the placeholder case, the correct behavior is to surface
the decision (ask via AskUserQuestion or mark an explicit TODO), never to
silently ship fake data as if it were real (Iron Law 1).

## Requirements

- `claude` CLI on PATH, authenticated.
- `jq` (optional, nicer output extraction).
- Runs are non-deterministic — a single FAIL is a signal to investigate and
  re-run, not proof the skill is broken. Treat repeated FAILs as RED.

## When to run

- Before bumping the plugin version.
- After editing any rigid skill or the `using-gaspol` / `session-start.sh`
  bootstrap (these are what make triggering work at all).
- As the REFACTOR-stage check in `gaspol-write-skill` when adding a skill.
