# Anthropic Best Practices for Skill Authoring

> Adapted for the Sparkfluence ecosystem. These principles govern how every
> skill in `gaspol-dev` should be written, structured, and maintained.

---

## 1. Conciseness is Key

Context window is a shared resource. Every token in a skill displaces tokens
available for the user's actual work — code, reasoning, file contents. Skills
must earn their place.

### Token Budget Guidelines

| Skill Category | Max Words | Rationale |
|---------------|-----------|-----------|
| Getting-started / onboarding | < 150 | Loaded on every session, amortized across all work |
| Frequently-loaded (brainstorming, debugging) | < 200 | Loaded often, must be lean |
| Specialized (write-skill, deploy) | < 500 | Loaded rarely, can be more detailed |
| Reference files (like this one) | No hard limit | Only loaded when skill explicitly references them |

### How to Stay Concise

- **Cut preamble.** No "This skill helps you..." — Claude already knows from the description.
- **Use tables over prose.** A 5-row table replaces 10 sentences.
- **Use code blocks for rules.** Visual distinction = faster parsing.
- **Prefer examples over explanations.** Show, don't tell.
- **One instruction per line.** Compound sentences hide requirements.

### The Conciseness Test

After writing a skill, ask:
1. Can I remove this sentence without losing behavior? Remove it.
2. Can I replace this paragraph with a table? Replace it.
3. Is this instruction already implied by another? Delete the weaker one.
4. Would Claude do this anyway without being told? Remove it.

---

## 2. Setting Degrees of Freedom

Every skill sits on a spectrum from "follow these exact steps" to "here are
principles, figure it out." Choosing the right degree of freedom is the most
important authoring decision.

### High Freedom (Principles + Goals)

```
USE WHEN:
- Task requires creativity (brainstorming, design)
- Many valid approaches exist
- Context varies heavily between uses
- You trust Claude's judgment for the domain

PATTERN:
"Generate ideas that satisfy these constraints: [X, Y, Z].
 Prefer approaches that [principle]. Avoid [anti-pattern]."

RISK: Claude may choose unexpected approaches
BENEFIT: Adapts to novel situations
```

### Medium Freedom (Patterns with Flexibility)

```
USE WHEN:
- Task has a known good structure but variable content
- Consistency matters but creativity helps
- You want guardrails without rigidity

PATTERN:
"Follow this structure: [template].
 For each section, apply [principle].
 Adapt the depth based on [context signal]."

RISK: Inconsistency between invocations
BENEFIT: Balances reliability with adaptability
```

### Low Freedom (Exact Steps)

```
USE WHEN:
- Discipline skills (TDD, commit conventions)
- Compliance matters more than creativity
- Mistakes are costly or hard to detect
- Process must be reproducible

PATTERN:
"Step 1: Do X. Step 2: Do Y. Step 3: Verify Z.
 NEVER skip Step 2. NEVER proceed without Step 3 passing."

RISK: Fragile when context doesn't match expectations
BENEFIT: Predictable, auditable, teachable
```

### Freedom Level by Sparkfluence Skill Type

| Skill | Freedom | Why |
|-------|---------|-----|
| gaspol-brainstorm | High | Creative exploration |
| gaspol-frontend-design | Medium | Design system constraints + creative layout |
| gaspol-write-skill | Medium | Structure matters, content varies |
| gaspol-tdd | Low | Discipline must be enforced |
| gaspol-deploy | Low | Production safety requires exact steps |

---

## 3. Skill Structure Best Practices

### Naming Convention

Use **gerund form** (present participle) for skill names:

```
CORRECT                    INCORRECT
brainstorming              brainstorm-ideas
debugging                  debug-helper
writing-skills             skill-writer
deploying                  deploy-tool
```

Why: Gerunds describe an activity, which maps naturally to "Use this skill
when you are [gerund]." Non-gerund names sound like tool names and create
confusion about whether the skill is a tool or a guide.

Exception: When the skill wraps a specific command, use the command name
(e.g., `deploy-edge-function` not `deploying-edge-functions`).

### Description: The Most Important Field

The description field is Claude's search index. When a user's request arrives,
Claude scans descriptions to decide which skills to load. A bad description
means the skill never gets used — or gets used at the wrong time.

#### CSO: Claude Search Optimization

Think of skill descriptions like SEO for Claude's skill selection:

```
GOOD DESCRIPTION (specific triggers):
"Use when creating new UI components, fixing layout issues, or implementing
 responsive designs. Covers Tailwind patterns, Shadcn UI integration, emerald
 color system, glassmorphism rules, and 9:16 media preview ratios."

BAD DESCRIPTION (summarizes workflow):
"This skill guides you through the frontend development process. First it
 analyzes requirements, then creates components, then reviews them."
```

**Why workflow summaries are dangerous:** Claude reads the description and
follows the summary INSTEAD of loading the full skill. The description becomes
a lossy compression of the actual skill.

#### Description Rules

| DO | DON'T |
|----|-------|
| List trigger conditions ("Use when...") | Summarize the workflow |
| Include specific terms, error messages | Use generic terms ("code quality") |
| Mention tool names if relevant | List steps |
| Keep under 1024 characters | Write an abstract |
| Use domain-specific vocabulary | Use marketing language |

#### Sparkfluence-Specific Trigger Terms

Include these when relevant to improve skill discovery:

```
Frontend: Tailwind, Shadcn, emerald, glassmorphism, 9:16, dark mode,
          responsive, segment card, retention border, workspace layout
Backend:  Edge Function, Deno, CORS, RLS, api_keys_pool, rotation,
          fal.ai, OpenRouter, Gemini, pgvector
Process:  deploy, migrate, test, commit, PR, review, brainstorm
```

### Progressive Disclosure

Structure skills in layers:

```
Layer 1: SKILL.md (always loaded)
  - Core workflow (< 500 words)
  - Decision points
  - Cross-references to Layer 2

Layer 2: Reference files (loaded on demand)
  - Detailed patterns
  - Examples
  - Checklists
  - Templates

Layer 3: External docs (never loaded, human reference)
  - Design specs
  - API documentation
  - Research papers
```

**Rule:** SKILL.md should be self-sufficient for the happy path. Reference
files handle edge cases, advanced patterns, and comprehensive examples.

### Domain-Specific Organization

Group related patterns together, not by abstraction level:

```
GOOD (grouped by domain):
## Image Generation Patterns
- Model selection (nano-banana vs seedream)
- Reference image handling
- Fallback chains

BAD (grouped by abstraction):
## High-Level Patterns
- Image model selection
- Video model selection
## Low-Level Patterns
- Image reference handling
- Video duration params
```

---

## 4. Workflows and Feedback Loops

Skills that produce consistent results include built-in verification.

### Checklists

Concrete, binary items that can be verified:

```markdown
## Pre-Deploy Checklist
- [ ] All TypeScript files pass `tsc --noEmit`
- [ ] CORS headers include required fields
- [ ] OPTIONS method handler exists
- [ ] Response follows `{ success, data/error }` format
- [ ] No hardcoded API keys (uses pool or Deno.env)
- [ ] Error codes are SCREAMING_SNAKE_CASE
```

**Checklist rules:**
- Each item must be verifiable (not "code is clean")
- Order matters (check dependencies first)
- Include the verification command where applicable
- Keep to 5-10 items (more = skipped)

### Validate-Fix-Repeat Loops

Build iteration into the skill:

```markdown
## Validation Loop
1. Run validation: `npm run build`
2. If errors:
   a. Fix the FIRST error only
   b. Re-run validation
   c. Repeat until clean
3. Only then proceed to next step
```

**Why first error only:** Later errors are often caused by earlier ones.
Fixing all at once leads to over-correction.

### Checkpoints (User Review Points)

Pause points where the user should review before continuing:

```markdown
## Checkpoint: Script Structure Review
Present the segment breakdown to the user:
- Show segment types, durations, word counts
- Highlight any segments over word limit
- Ask: "Does this structure look right? Should I adjust any segments?"
- WAIT for user response before generating content
```

**When to add checkpoints:**
- Before irreversible actions (deploy, delete, publish)
- After creative generation (user taste matters)
- At phase boundaries (script done, moving to images)
- When cost is involved (API calls, token usage)

---

## 5. Content Guidelines

### Avoid Time-Sensitive Information

```
BAD:  "As of February 2026, the latest Kling model is v2.5"
GOOD: "Check aiModels.ts for current model versions"

BAD:  "OpenRouter currently charges $0.001/token"
GOOD: "OpenRouter is the paid provider (see api_keys_pool)"
```

**Why:** Skills persist across sessions. Outdated facts cause wrong decisions.
Point to source-of-truth files instead.

### Consistent Terminology

Use the same terms across all gaspol skills:

| Canonical Term | NOT |
|---------------|-----|
| Edge Function | serverless function, cloud function |
| segment | section, part, block, chunk |
| workspace | editor, dashboard, main view |
| session | project, document, file |
| pool (api_keys_pool) | rotation table, key store |
| reference image | source image, input image, avatar |

### Cross-References

When one skill depends on another:

```markdown
CORRECT:
**REQUIRED SKILL:** Use `gaspol-frontend-design` for component styling.

INCORRECT:
@gaspol-frontend-design    (@ links don't work)
See gaspol-frontend-design (too vague, no action)
```

**Cross-reference rules:**
- Bold the "REQUIRED SKILL" label
- Use backtick-quoted skill name
- State WHAT to use it for
- Never use @ notation

---

## 6. Common Patterns

### Template Pattern

Provide fill-in-the-blank structures:

```markdown
## Edge Function Response Template
\`\`\`typescript
return new Response(
  JSON.stringify({
    success: {{true_or_false}},
    {{#if success}}
    data: { {{response_fields}} }
    {{else}}
    error: { code: '{{ERROR_CODE}}', message: '{{human_message}}' }
    {{/if}}
  }),
  { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
);
\`\`\`
```

### Example Pattern (Good vs Bad)

Show contrasts to calibrate judgment:

```markdown
## Hook Writing Examples

GOOD (specific, emotional, curiosity gap):
"I lost $50,000 in 3 seconds because of ONE setting"

BAD (generic, no stakes, no gap):
"Here are 5 tips for better video editing"

WHY: The good hook has personal stakes ($50K), urgency (3 seconds),
and a curiosity gap (which setting?). The bad hook is a listicle
promise with no emotional investment.
```

### Conditional Workflow

Branch based on detected context:

```markdown
## Model Selection
IF segment has creator face (CREATOR shot):
  → Use nano-banana/edit with reference images
ELSE IF segment is B-ROLL:
  → Use seedream-v4 (no reference)
ELSE IF segment has negative prompt needs:
  → Use qwen-image
```

### Escalation Pattern

When to stop and ask:

```markdown
## When to STOP and Ask the User
- All API keys exhausted (no automatic reset)
- Build fails with errors outside changed files
- Test failures in code you didn't modify
- Ambiguous requirements with costly wrong guesses
- Any action affecting production data
```

---

## 7. Evaluation and Iteration

### Build Evaluations First

Before writing the skill, define what success looks like:

1. **Write 3-5 pressure scenarios** (see testing-skills-with-subagents.md)
2. **Run without skill** — document failures
3. **Write minimal skill** — just enough to pass scenarios
4. **Expand** — add edge cases found during testing
5. **Re-test** — verify no regressions

### The A/B Pattern

Test skill effectiveness:

```
Session A (control): Complete task WITHOUT skill loaded
Session B (treatment): Complete task WITH skill loaded

Compare:
- Did the agent follow the desired process?
- Did the output meet quality standards?
- Were there any process violations?
- How many tokens did the skill add?
```

If Session A produces the same quality as Session B, the skill is adding
tokens without adding value. Simplify or remove it.

### Iteration Cadence

```
v0.1: Minimal viable skill (pass 1 pressure scenario)
v0.2: Handle edge cases (pass 3 pressure scenarios)
v0.3: Add rationalization prevention (close loopholes)
v1.0: Stable (passes all scenarios, reviewed by user)
```

---

## 8. Anti-Patterns

### Path Specificity

```
BAD:  Run `D:\Projects\gaspol_platform\node_modules\.bin\tsc`
GOOD: Run `tsc --noEmit` (assumes proper PATH/npx setup)
```

Skills should work across environments unless explicitly platform-specific.
Sparkfluence uses Windows CMD, but skills should reference commands generically
where possible.

### Decision Paralysis

```
BAD:  "Choose between Option A, B, C, D, E, or F based on..."
GOOD: "Default to Option A. Use Option B only when [specific condition]."
```

More than 3 options requires a decision tree, not a list.

### Vague Instructions

```
BAD:  "Write clean, maintainable code"
GOOD: "Each function must: (1) do one thing, (2) be < 50 lines,
       (3) have typed parameters, (4) return typed results"
```

If you can't verify compliance, the instruction is too vague.

### Combining Concerns

```
BAD:  One skill for "frontend development" (styling + state + routing + testing)
GOOD: Separate skills for styling, state management, routing, testing
```

Each skill should have ONE clear purpose. If the description needs "and" more
than once, consider splitting.

---

## 9. Advanced Topics

### Executable Code in Skills

Skills can include shell scripts or code snippets that Claude executes:

```markdown
## Validate Before Deploy
Run this check:
\`\`\`bash
npx tsc --noEmit 2>&1 | head -20
\`\`\`
If any errors appear, fix them before proceeding.
```

**Rules for executable code:**
- Must be safe to run (no side effects without user consent)
- Include error handling guidance
- Specify what "success" output looks like

### MCP Tool References

When a skill uses specific MCP tools:

```markdown
## Required Tools
This skill uses:
- `supabase` MCP server for database operations
- `context7` MCP server for library documentation
- `github` MCP server for PR creation

If any tool is unavailable, inform the user and suggest alternatives.
```

### Hook Integration

Skills can reference pre/post hooks:

```markdown
## Automatic Validation
The `type-check-on-edit` hook runs `tsc --noEmit` after every TypeScript edit.
If it reports errors, fix them before continuing to the next file.
Do NOT disable the hook.
```

### Agent Templates

For skills that dispatch subagents:

```markdown
## Parallel Review
Dispatch these agents simultaneously:
1. `security-reviewer`: Check for RLS gaps, exposed secrets
2. `edge-function-reviewer`: Validate CORS, response format, key rotation

Wait for both to complete. Address ALL findings before proceeding.
```

---

## 10. Sparkfluence-Specific Conventions

### Always Reference CLAUDE.md

Skills should point to CLAUDE.md for project-specific details rather than
duplicating them:

```
GOOD: "Follow the design system colors defined in CLAUDE.md"
BAD:  "--accent: #10B981 (emerald)" (duplicates CLAUDE.md)
```

### Respect the Permission Model

Every skill must honor the CLAUDE.md permission rules:

```
- Local file changes: proceed
- Server/production changes: ASK PERMISSION
- npm/pip install: ASK PERMISSION
- Deploy commands: ASK PERMISSION
```

Skills that include deployment steps must include explicit permission
checkpoints, not assume consent.

### Windows CMD Awareness

When skills include shell commands, prefer cross-platform syntax. When
platform-specific commands are needed, use Windows CMD (not PowerShell,
not bash) as the default for Sparkfluence:

```
PREFERRED: npx tsc --noEmit (cross-platform)
IF NEEDED: dir /s /b *.tsx (Windows CMD)
NEVER:     ls -la *.tsx (Linux/Mac)
```

---

*Last updated: February 2026*
*Applies to: All skills in gaspol-dev repository*
