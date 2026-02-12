---
name: gaspol-write-skill
description: "Use when creating new skills, editing existing skills, or verifying skills work before deployment. Writing skills IS TDD applied to process documentation."
---

# Writing Skills

## The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing. A skill that was never tested against failure is a skill that might encode the wrong lessons.

---

## Core Principle

Writing skills IS TDD applied to process documentation.

| TDD Concept | Skill Writing Equivalent |
|-------------|------------------------|
| Test case | Pressure scenario (situation where agent makes mistakes) |
| Production code | SKILL.md content |
| RED phase | Agent violates desired behavior without the skill |
| GREEN phase | Agent complies with desired behavior with the skill |
| REFACTOR phase | Close loopholes, tighten language, re-test |

The same discipline that prevents bugs in code prevents gaps in skills.

---

## Skill Types

### Technique Skills
Concrete, step-by-step procedures. The agent follows these exactly.

**Examples:** gaspol-tdd, gaspol-debug, gaspol-verify
**Characteristics:** Numbered steps, mandatory checkpoints, red flags, verification checklists
**Voice:** Imperative ("Do X. Then Y. Never Z.")

### Pattern Skills
Ways of thinking applied to varying situations. The agent adapts these.

**Examples:** gaspol-brainstorm, gaspol-design, gaspol-review
**Characteristics:** Principles, heuristics, examples, anti-patterns
**Voice:** Descriptive ("When X occurs, consider Y because Z.")

### Reference Skills
Lookup data, API documentation, configuration guides. The agent consults these.

**Examples:** testing-anti-patterns.md, design-system references
**Characteristics:** Tables, code examples, specs, searchable structure
**Voice:** Declarative ("X is Y. X supports Z.")

---

## SKILL.md Structure

### YAML Frontmatter (REQUIRED)

```yaml
---
name: gaspol-skill-name
description: "Use when [triggering conditions]. [What the skill does]."
---
```

**Frontmatter Rules:**
- `name`: kebab-case, prefixed with `gaspol-`
- `description`: Maximum 1024 characters
- Description MUST start with "Use when..." (triggering conditions ONLY)

**CRITICAL:** The description must NOT summarize the workflow or steps. Claude uses the description to decide whether to load the skill. If the description contains the workflow, Claude may follow the description instead of reading the full skill content.

```
BAD description:
"Use when implementing features. First write a failing test, then write
minimal code to pass, then refactor. Follow RED-GREEN-REFACTOR cycle."
(Claude will follow this summary instead of reading the skill)

GOOD description:
"Use when implementing any feature or bugfix, before writing implementation
code. Enforces RED-GREEN-REFACTOR cycle."
(Claude must read the skill to know the actual steps)
```

### Content Sections

A complete skill should include most of these sections:

1. **Iron Law** -- The one non-negotiable rule (1-2 sentences)
2. **Core Principle** -- Why this skill exists (1 paragraph)
3. **When to Use** -- Triggering conditions (bulleted list)
4. **When NOT to Use** -- Explicit exclusions (bulleted list)
5. **The Pattern/Process** -- Core workflow (numbered steps with detail)
6. **Quick Reference** -- Condensed version (for agents that already know the skill)
7. **Red Flags** -- Warning signs of deviation (numbered list)
8. **Rationalization Prevention Table** -- Excuses vs reality (table format)
9. **Verification Checklist** -- How to confirm the skill was followed correctly
10. **Integration** -- How this skill relates to other skills
11. **Common Mistakes** -- Specific anti-patterns with fixes

Not every skill needs every section. Technique skills need all of them. Pattern skills may skip Quick Reference. Reference skills mainly need structured data.

---

## Claude Search Optimization (CSO)

Claude finds skills by matching user intent against skill descriptions and content. Optimize for this.

### Description = Triggering Conditions ONLY

The description is a search index, not a summary. It should contain the SYMPTOMS or SITUATIONS that trigger the skill.

```
GOOD: "Use when tests are failing with unclear root causes, when debugging
       complex multi-file issues, or when a fix in one place breaks another."
(Contains symptoms: "tests failing", "unclear root causes", "debugging",
 "complex multi-file", "fix breaks another")

BAD: "A systematic debugging methodology that uses binary search and
      hypothesis testing to find root causes efficiently."
(Contains process description, not triggering conditions)
```

### Keywords Throughout

Scatter keywords that match how users describe problems:

- Error messages they might paste
- Symptoms they might describe
- Synonyms for the same concept
- Common misspellings or alternative names

### Descriptive Naming

Skill names should be verb-first or describe the activity:

```
GOOD: gaspol-debug, gaspol-finish, gaspol-dispatch
BAD:  gaspol-utility-3, gaspol-misc, gaspol-helper
```

### Token Efficiency

Skills consume context window. Be concise:

| Skill Category | Target Token Count |
|---------------|-------------------|
| Getting-started / kickstart | < 150 words description |
| Frequently-loaded (tdd, debug) | < 200 words description |
| Specialized (write-skill, dispatch) | < 500 words description |

The description is loaded for ALL skills when Claude searches. Keep it tight. The full content is only loaded when the skill is invoked.

### Cross-References

When a skill depends on another, make it explicit:

```markdown
**REQUIRED SKILL:** Before proceeding, invoke `gaspol-tdd`.

**SEE ALSO:** `gaspol-verify` for post-implementation checks.

**PAIRS WITH:** `gaspol-debug` for regression test creation.
```

---

## RED-GREEN-REFACTOR for Skills

### RED Phase: Baseline Testing

Before writing the skill, test what happens without it.

1. **Create a pressure scenario** -- a realistic task that requires the behavior the skill teaches
2. **Run an agent on the scenario WITHOUT the skill** -- no hints, no guidance
3. **Document failures** -- what did the agent do wrong? What did it skip? What did it get backwards?

```
PRESSURE SCENARIO: "Fix the authentication bug where JWT tokens with array
roles are rejected."

WITHOUT SKILL (gaspol-debug):
- Agent immediately edited auth.ts without understanding the bug
- Agent made 3 incorrect fixes before finding the real issue
- Agent didn't write a regression test
- Agent didn't verify the fix didn't break other auth flows

FAILURES DOCUMENTED:
1. Jumped to implementation without diagnosis
2. No hypothesis testing
3. No regression test
4. No verification of related functionality
```

### GREEN Phase: Write Minimal Skill

Write the minimal skill content that addresses EACH documented failure.

For each failure, the skill must contain:
- An instruction that prevents it
- A red flag that catches it
- A rationalization table entry that blocks the excuse

```
Failure: "Jumped to implementation without diagnosis"
Skill instruction: "Step 1: DIAGNOSE. Read error messages. Form hypothesis.
                    Do NOT edit code until you can state the root cause."
Red flag: "Editing code before stating a hypothesis"
Rationalization: "I can see the fix" → "If you can see it, you can state it first"
```

### REFACTOR Phase: Close Loopholes

Re-test the skill. Look for:
- Agents following the letter but not the spirit
- Edge cases the skill doesn't address
- Ambiguous instructions that could be interpreted wrong
- Missing context that causes confusion

Tighten the language. Add examples. Re-test.

---

## Bulletproofing

### Close Every Loophole Explicitly

Agents will find creative interpretations. For every instruction, ask:
"How could an agent follow this literally while violating the intent?"

```
INSTRUCTION: "Write a failing test first"
LOOPHOLE: Agent writes a test that tests nothing, then writes code
FIX: "Write a failing test that tests REAL BEHAVIOR. If the test would
      pass with an empty implementation, it's not testing anything."
```

### Address "Spirit vs Letter"

State the foundational principle before the rules. When rules conflict, the principle resolves the ambiguity.

```
FOUNDATIONAL PRINCIPLE: "No production code without verified behavioral testing."

RULES: (derive from the principle)
1. Write test first
2. Test must fail
3. Test must fail for the expected reason
...

When in doubt, return to the principle: "Am I writing production code
without verified behavioral testing? If yes, stop."
```

### Build Rationalization Table from Baseline Testing

Every excuse the agent made during RED phase becomes a table entry:

| What Agent Said | What Skill Says |
|----------------|----------------|
| "I can see the obvious fix" | "If it's obvious, stating it first costs nothing" |
| "Testing this is overkill" | "If it's too simple to test, it's too simple to break. Test it." |
| "I'll come back to the test" | "Coming back = never. Write it now." |

### Create Red Flags List

Red flags are observable behaviors that indicate the skill is being violated. They should be specific enough that an observer (or the agent itself) can spot them.

```
RED FLAGS:
1. Editing production code before a test exists ← specific, observable
2. "Not following best practices" ← vague, useless
```

---

## Skill Creation Checklist

### RED Phase
- [ ] Pressure scenario defined (realistic task)
- [ ] Baseline test run (agent without skill)
- [ ] Failures documented (specific, numbered)
- [ ] Pressure points identified (where the agent goes wrong)

### GREEN Phase
- [ ] YAML frontmatter with name and description
- [ ] Description starts with "Use when..."
- [ ] Description does NOT summarize the workflow
- [ ] Iron law stated (1-2 sentences)
- [ ] Core principle explained (1 paragraph)
- [ ] When to use / When NOT to use sections
- [ ] Core pattern/process (numbered steps)
- [ ] Every baseline failure addressed by an instruction
- [ ] Red flags list (specific, observable behaviors)
- [ ] Rationalization prevention table
- [ ] Verification checklist
- [ ] Integration section (how it connects to other skills)
- [ ] Examples where helpful

### REFACTOR Phase
- [ ] Loopholes identified and closed
- [ ] Re-tested with agent (skill loaded)
- [ ] Agent follows skill correctly
- [ ] No ambiguous instructions remain
- [ ] Spirit vs letter addressed (foundational principle stated)
- [ ] Meta-test: skill is internally consistent

### Quality Checks
- [ ] Token count within budget (see CSO section)
- [ ] Description optimized for Claude search (symptoms, not process)
- [ ] Cross-references to related skills are explicit
- [ ] Flowcharts or diagrams included where process is complex
- [ ] Code examples are realistic and correct
- [ ] Tables are used for structured comparisons
- [ ] No redundant sections (each section earns its place)

---

## Common Mistakes When Writing Skills

### 1. Summary in Description

**Mistake:** Putting the workflow in the description.
**Result:** Claude follows the summary and never reads the full skill.
**Fix:** Description = triggering conditions only. "Use when X."

### 2. Vague Red Flags

**Mistake:** "Not following the process correctly."
**Result:** Neither Claude nor the user can detect the violation.
**Fix:** "Editing production code before a test file exists for the feature."

### 3. Missing Rationalization Table

**Mistake:** Only stating what to do, not addressing why agents might not.
**Result:** Agent finds creative excuses to skip steps.
**Fix:** Document every excuse from baseline testing and counter each one.

### 4. No Baseline Testing

**Mistake:** Writing a skill based on what you THINK agents get wrong.
**Result:** Skill addresses imaginary problems, misses real ones.
**Fix:** Always run RED phase first. Document actual failures.

### 5. Over-Engineering

**Mistake:** 1000+ line skill with every edge case covered.
**Result:** Agent gets lost in the skill, follows none of it.
**Fix:** Keep to essential instructions. If it's > 500 lines, split into main skill + reference files.

### 6. No Integration Section

**Mistake:** Skill exists in isolation, doesn't reference other skills.
**Result:** Agent doesn't know when to chain skills together.
**Fix:** Explicitly state which skills this one requires, enables, or pairs with.

### 7. Untestable Verification

**Mistake:** "Verify the code is high quality."
**Result:** Agent says "verified" without checking anything.
**Fix:** "Run `npm test`. All tests pass. Run `npm run lint`. Zero warnings."

---

## Skill File Organization

```
skills/
  gaspol-skill-name/
    SKILL.md              # Main skill content (REQUIRED)
    reference-data.md     # Supporting reference material (OPTIONAL)
    examples.md           # Extended examples (OPTIONAL)
```

- `SKILL.md` is always the entry point
- Supporting files are referenced from SKILL.md with explicit paths
- Keep SKILL.md focused; move reference data to separate files
- Name supporting files descriptively (not `data.md` or `extra.md`)

---

## Testing Skills After Creation

### Manual Testing

1. Create a new conversation without the skill loaded
2. Give the agent a task that requires the skill's behavior
3. Observe: does the agent follow the skill's process?
4. If not: identify what the skill failed to communicate
5. Fix the skill and re-test

### Automated Testing (with subagents)

1. Dispatch a subagent with the skill loaded and a pressure scenario
2. Review the subagent's output against the skill's verification checklist
3. Document any deviations
4. Fix the skill for clarity

### Meta-Testing

Ask: "If I gave this skill to a new agent who has never seen the codebase, would they be able to follow it correctly?"

If the answer is "no," the skill needs more context, clearer instructions, or better examples.

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-tdd` | TDD principles applied to skill writing (RED-GREEN-REFACTOR) |
| `gaspol-verify` | Verify skills work correctly before deployment |
| `gaspol-kickstart` | New skills must be added to the complete skill list |
| `gaspol-sync-docs` | New skills may require CLAUDE.md updates |
| `gaspol-review` | Skills can be reviewed like code |

---

## Quick Reference

```
1. RED:     Define pressure scenario
2. RED:     Run agent WITHOUT skill, document failures
3. GREEN:   Write SKILL.md addressing each failure
4. GREEN:   Include: iron law, process, red flags, rationalization table
5. REFACTOR: Re-test WITH skill loaded
6. REFACTOR: Close loopholes found during re-test
7. VERIFY:  Run quality checks (CSO, token count, cross-references)
8. DEPLOY:  Add to skill directory, update gaspol-kickstart list
```
