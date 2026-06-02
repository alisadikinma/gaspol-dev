# Persuasion Principles for Skill Authoring

> Research-backed principles for making skills that reliably change agent behavior.
> Based on Cialdini (2021) and Meincke et al. (2025) — LLMs exhibit "parahuman"
> responses to the same persuasion patterns that influence humans.

---

## Research Foundation

Meincke et al. (2025) demonstrated that LLMs respond to persuasion techniques
at rates comparable to humans. This means skill authors can use established
influence principles to make instructions more effective — not as manipulation,
but as clarity amplification.

Key finding: **Authority** and **Commitment/Consistency** have the strongest
effect on LLM compliance. **Liking** (friendly tone) has negligible or negative
effect on process adherence.

---

## The Seven Principles

### 1. Authority (HIGH IMPACT)

LLMs treat authoritative, imperative language as higher priority than
suggestions or explanations.

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| Imperative verbs | "MUST", "NEVER", "ALWAYS" | Treated as hard constraints |
| No exceptions framing | "No exceptions. Not negotiable." | Prevents rationalization |
| Code block rules | `RULE: Test before deploy` | Visual emphasis = priority |
| Iron Laws | Numbered, boxed, separated rules | Creates hierarchy of importance |
| Absolute language | "Under NO circumstances" | Eliminates interpretation space |

**Application in skills:**

```markdown
## Iron Laws (NEVER violate)

1. **NEVER deploy without permission.** No exceptions. Not for hotfixes,
   not for one-line changes, not for "obvious" fixes.

2. **NEVER skip type checking.** Run `tsc --noEmit` after every TypeScript
   edit. Zero errors required before proceeding.

3. **NEVER use AI purple (#7C3AED).** Sparkfluence uses emerald (#10B981).
   Even if the user's mockup shows purple, use emerald and explain why.
```

**Why it works:** LLMs parse imperative + absolute language as the highest
priority tier in their instruction hierarchy. "NEVER" is processed differently
than "try to avoid" — the former creates a hard boundary, the latter creates
a soft preference.

**Calibration:** Overuse dilutes impact. Reserve MUST/NEVER for genuine
non-negotiables (5-7 per skill maximum). Everything else can use "should"
or "prefer."

---

### 2. Commitment & Consistency (HIGH IMPACT)

Once an agent publicly commits to a course of action, deviating from that
commitment creates cognitive dissonance (in LLMs, this manifests as
self-contradiction avoidance).

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| Announcement requirement | "State: 'I am following the X skill...'" | Creates public commitment |
| TodoWrite tracking | "Create a todo list with all required steps" | Makes commitments visible |
| Explicit choice forcing | "Choose A or B and explain your reasoning" | Locks in a position |
| Progress declarations | "Confirm completion of Step 1 before Step 2" | Sequential commitment chain |
| Pre-commitment prompts | "Before starting, list what you will NOT do" | Prevents future rationalization |

**Application in skills:**

```markdown
## Commitment Protocol

BEFORE writing any code:
1. Announce: "I am following the gaspol-tdd skill. I will write
   tests BEFORE implementation."
2. Create a TodoWrite with all required steps
3. Mark each step as you complete it

This announcement is your commitment. Deviating from it requires
explicitly stating: "I am choosing to deviate from my commitment
because [reason]." If you cannot state a valid reason, do not deviate.
```

**Why it works:** LLMs strongly avoid self-contradiction. Once they've stated
"I will write tests first," producing code without tests requires them to
contradict their own statement — which they resist more strongly than
contradicting an external instruction.

**Calibration:** Require announcements for discipline skills (TDD, deploy).
Skip for creative skills (brainstorming) where flexibility matters more
than consistency.

---

### 3. Scarcity (MEDIUM IMPACT)

Creating urgency around process compliance — framing steps as time-sensitive
gates rather than optional enhancements.

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| BEFORE gates | "BEFORE writing code, you MUST..." | Creates temporal urgency |
| Only-then framing | "Only THEN proceed to implementation" | Gates forward progress |
| Checkpoint deadlines | "This must be done NOW, not deferred" | Prevents postponement |
| Exclusivity | "This check catches 80% of production bugs" | Makes step feel valuable |

**Application in skills:**

```markdown
## Pre-Implementation Gate

BEFORE writing any implementation code:
1. Read the existing tests (if any)
2. Write a failing test for the new behavior
3. Verify the test actually fails

Only THEN write implementation code. This gate catches 80% of cases
where developers "accidentally" write implementation without tests
and then "add tests later" (they never do).
```

**Why it works:** BEFORE/only-then framing creates a sequence dependency
that LLMs respect more strongly than "also do X" instructions, which feel
additive and optional.

**Calibration:** Use for process gates (test before code, check before deploy).
Don't use for creative phases where sequence flexibility helps.

---

### 4. Social Proof (MEDIUM IMPACT)

LLMs calibrate their behavior against described norms. Showing what others
do wrong (and the consequences) is more effective than describing ideals.

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| Common failures list | "Common failures: skipping tests, deploying untested..." | Calibrates against anti-norms |
| Rationalization tables | "When agents say X, the real issue is Y" | Pre-empts known excuses |
| Real-world consequences | "This caused a 4-hour outage in Project Z" | Makes abstract rules concrete |
| Pattern recognition | "If you're thinking X, that's a red flag" | Self-monitoring triggers |

**Application in skills:**

```markdown
## Common Rationalizations (recognize and resist)

| What You'll Think | Why It's Wrong | What To Do Instead |
|-------------------|----------------|-------------------|
| "It's a one-line fix, no test needed" | One-line fixes cause 30% of prod bugs | Write a one-line test |
| "I'll add tests after" | You won't. Nobody does. | Write tests now |
| "The user wants speed" | The user wants correctness. Speed without correctness = rework | Follow process; it's faster long-term |
| "This is too simple to break" | Simple code in complex systems breaks in complex ways | Test the integration, not the line |
```

**Why it works:** LLMs use described failure patterns as negative examples
to avoid. Showing what "bad agents" do creates a reference class that
the agent actively distances itself from.

**Calibration:** 3-5 rationalizations per skill is sufficient. More than 7
becomes a wall of text that gets skimmed.

---

### 5. Unity (LOW-MEDIUM IMPACT)

Shared identity language creates a sense of belonging to a quality standard,
making deviation feel like betrayal rather than pragmatism.

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| "We" language | "We don't skip tests in this codebase" | Creates team identity |
| Future impact | "The next session depends on this being right" | Responsibility framing |
| Codebase personification | "This codebase has standards" | Anthropomorphizes quality |
| Legacy framing | "This is how we maintain quality at Sparkfluence" | Tradition-based compliance |

**Application in skills:**

```markdown
## Our Standards

In the Sparkfluence codebase, we follow these standards not because
they're rules, but because the next developer (or the next Claude session)
depends on them:

- We update CLAUDE.md after every change session
- We never deploy without explicit permission
- We use emerald, not purple
- We write Edge Functions with CORS, error handling, and rotation

These aren't aspirational — they're the baseline.
```

**Why it works:** Unity framing shifts the motivation from "following rules"
to "maintaining team standards." Agents resist letting down a team more
than they resist breaking an abstract rule.

**Calibration:** Most effective in introductory sections. Loses impact if
used throughout (feels manipulative). One "we" section per skill.

---

### 6. Reciprocity (USE SPARINGLY)

Explaining WHY rules exist (providing value) increases compliance more than
bare commands — but only up to a point. Too much explanation dilutes authority.

**Techniques:**

| Technique | Example | Effect |
|-----------|---------|--------|
| Benefit statements | "This saves 10-50k tokens per session" | Concrete motivation |
| Consequence warnings | "Without this, the next session repeats mistakes" | Loss aversion |
| Efficiency framing | "5 minutes now saves 2 hours of debugging" | ROI calculation |
| Understanding, not just obedience | "Here's WHY we do it this way..." | Builds internal motivation |

**Application in skills:**

```markdown
## Why CLAUDE.md Updates Matter

Updating CLAUDE.md after changes isn't bureaucracy — it's the single
action that saves the most tokens across sessions:

- Without update: next session spends 10-50k tokens rediscovering
  what was changed, debugging outdated assumptions
- With update: next session starts with accurate context, zero rework

The 2 minutes you spend updating CLAUDE.md saves 20 minutes of the
next session's time. This is the highest-ROI action in the codebase.
```

**Why it works:** Understanding creates internal motivation that persists
even without the skill loaded. Agents that understand WHY are more likely
to apply the principle in novel situations.

**Calibration:** One brief WHY per major rule. Don't explain everything —
it bloats the skill and suggests rules are optional (only explained if
compliance is voluntary).

---

### 7. Liking (DON'T USE for compliance)

Friendly, warm tone does NOT increase process compliance in LLMs. It may
actually DECREASE adherence by making instructions feel conversational
and therefore optional.

**Evidence:**

| Tone | Compliance Rate | Why |
|------|----------------|-----|
| Authoritative ("MUST", "NEVER") | Highest | Parsed as hard constraints |
| Neutral ("do X, then Y") | Medium | Parsed as instructions |
| Friendly ("hey, it'd be great if...") | Lowest | Parsed as suggestions |

**When to use Liking:**

- Collaborative sections (brainstorming, ideation)
- User-facing messages (error messages, progress updates)
- Teaching/explaining (why sections)
- NEVER for enforcement ("please don't skip tests" = will skip tests)

**Application:**

```markdown
WRONG:
"Hey! It would be awesome if you could run the type checker before
proceeding. It really helps keep the codebase clean!"
→ Agent reads this as: optional, nice-to-have, skippable

RIGHT:
"Run `tsc --noEmit` before proceeding. Zero errors required."
→ Agent reads this as: mandatory gate, non-negotiable
```

---

## Principle Combinations by Skill Type

Different skill types benefit from different principle combinations:

| Skill Type | Primary | Secondary | Avoid |
|-----------|---------|-----------|-------|
| **Discipline** (TDD, deploy) | Authority + Commitment | Scarcity (gates) | Liking |
| **Pattern** (brainstorming, design) | Social Proof + Unity | Reciprocity (why) | Authority overkill |
| **Technique** (debugging, optimization) | Authority + Social Proof | Scarcity (check first) | Commitment (too rigid) |
| **Meta** (writing-skills) | All except Liking | - | - |
| **Process** (PR review, migration) | Authority + Commitment + Scarcity | Social Proof | Unity (too soft) |

### Sparkfluence Skill Mapping

| Skill | Recommended Combination |
|-------|------------------------|
| gaspol-tdd | Authority (iron laws) + Commitment (announce) + Scarcity (test-first gate) |
| gaspol-brainstorm | Social Proof (common failures) + Unity (our process) + Reciprocity (why explore) |
| gaspol-frontend-design | Authority (design system rules) + Social Proof (anti-patterns) |
| gaspol-deploy | Authority (permission gates) + Commitment (checklist) + Scarcity (pre-deploy) |
| gaspol-write-skill | All principles modeled in practice |

---

## Ethical Use Test

Every persuasion technique in a skill must pass this test:

> **"Would this serve the user's genuine interests if they fully understood
> how the skill influences Claude's behavior?"**

| Answer | Action |
|--------|--------|
| **Yes** | Use the principle |
| **No** | It's manipulation, not persuasion — remove it |
| **Uncertain** | Ask: does this make the OUTPUT better, or just the COMPLIANCE higher? |

### Sparkfluence Ethics Baseline

All gaspol skills exist to help users build better software. Every
persuasion technique serves one of these goals:

1. **Prevent production incidents** (deploy gates, type checking, testing)
2. **Maintain codebase quality** (design system, naming conventions, CLAUDE.md updates)
3. **Improve creative output** (brainstorming frameworks, scoring engines)
4. **Save user time** (automated checks, process efficiency)

If a persuasion technique doesn't serve one of these goals, it doesn't
belong in a gaspol skill.

---

*Last updated: February 2026*
*Companion to: anthropic-best-practices.md, testing-skills-with-subagents.md*
*References: Cialdini (2021) "Influence: New and Expanded"; Meincke et al. (2025) "Prompting Diverse Ideas"*
