---
name: gaspol-tdd
description: "Use when implementing any feature or bugfix, before writing implementation code. Enforces RED-GREEN-REFACTOR cycle — no production code without a failing test first."
---

# Test-Driven Development

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before test? **Delete it. Start over. No exceptions.**

This is not a suggestion. This is not a guideline. This is the non-negotiable foundation of TDD. If you wrote production code before writing a failing test, that code must be deleted regardless of how correct it appears, how long it took, or how "obvious" the implementation is.

---

## RED-GREEN-REFACTOR Cycle

### RED: Write ONE Minimal Failing Test

Write exactly one test that captures a single behavior you want to implement.

**Rules:**
- One behavior per test. Not two. Not "a few related ones." One.
- Clear, descriptive name that reads like a specification: `test_empty_cart_returns_zero_total`
- Use real code, not mocks, unless the dependency is external (API, database, filesystem)
- The test MUST fail. If it passes immediately, you either wrote the wrong test or the behavior already exists.
- Before writing the test, you MUST be able to articulate WHY it will fail and WHAT error you expect.

```
BEFORE writing the test, state:
"This test will fail because [specific reason] with [expected error]"

If you cannot complete this sentence, you do not understand the requirement.
Stop. Clarify. Then write the test.
```

### Verify RED (MANDATORY)

Run the test. Confirm it fails. Confirm it fails **for the expected reason.**

This step is not optional. You must see the failure output. You must verify the failure message matches your prediction.

**Why this matters:**
- A test that fails for an unexpected reason means your test is wrong
- A test that passes immediately means you didn't need to write code (or your test is wrong)
- A test that errors (not fails) means your setup is wrong

```
Expected: Test FAILS with "NameError: name 'calculate_total' is not defined"
Actual:   Test FAILS with "NameError: name 'calculate_total' is not defined"
          ^^^ This is correct. Proceed to GREEN.

Expected: Test FAILS with "AssertionError: 0 != 15.99"
Actual:   Test ERRORS with "ImportError: cannot import 'cart'"
          ^^^ This is WRONG. Fix setup first. Do NOT proceed.
```

### GREEN: Write the SIMPLEST Code to Pass

Write the absolute minimum production code to make the failing test pass.

**Rules:**
- No extra features. If the test doesn't require it, don't write it.
- No refactoring. Not yet. Ugly code that passes is better than beautiful code you haven't tested.
- No "while I'm here" additions. Stay focused on the one failing test.
- "Simplest" means simplest. Return a hardcoded value if that's what passes. The next test will force real logic.

```
BAD (overengineering in GREEN):
def calculate_total(items):
    subtotal = sum(item.price * item.quantity for item in items)
    tax = subtotal * 0.08
    discount = self.apply_loyalty_discount(subtotal)
    return subtotal + tax - discount

GOOD (minimal to pass):
def calculate_total(items):
    return sum(item.price for item in items)
```

### Verify GREEN (MANDATORY)

Run ALL tests. Every single one must pass. Output must be pristine.

**"Pristine" means:**
- Zero failures
- Zero errors
- Zero warnings (address warnings before proceeding)
- Zero skipped tests (unless explicitly marked as pending future work)

If any test fails, you are not GREEN. Fix it before proceeding.

### REFACTOR: Improve Code Quality

Now, and ONLY now, improve the code.

**Allowed:**
- Remove duplication (DRY)
- Improve variable/function names
- Extract helper functions
- Simplify conditionals
- Reorganize file structure

**Not Allowed:**
- Adding new behavior (that's a new RED)
- Changing what the code does (only how)
- Breaking any existing test

**After every refactor change, run ALL tests.** If any fail, undo the refactor.

---

## Why Order Matters: Answering 5 Common Objections

### 1. "I'll write tests after"

Tests written after implementation are unconsciously designed to pass. You already know what the code does, so you write tests that confirm it -- including its bugs. Tests-first verify behavior. Tests-after rationalize implementation.

**The proof:** Try writing a test for code you already wrote that you EXPECT to fail. You can't. Your brain won't let you. You'll write a test that passes and call it "good coverage."

### 2. "I already manually tested"

Manual testing is:
- Not repeatable (you'll forget the exact steps)
- Not documented (no one else knows what you tested)
- Not automated (you'll have to redo it every time)
- Not comprehensive (you tested the happy path, maybe one edge case)

A manual test that passes today proves nothing about tomorrow.

### 3. "Deleting X hours of code is wasteful"

This is the sunk cost fallacy. The time is already spent. The question is: will building on an untested foundation cost MORE time later? The answer is always yes.

Code without tests is technical debt with compound interest. Delete it now, pay the small cost. Keep it, pay the large cost later -- with interest.

### 4. "TDD is dogmatic"

TDD is a process discipline, not a belief system. You don't "believe in" TDD any more than you "believe in" washing your hands before surgery. It's a practice with measurable outcomes:
- Fewer defects (40-90% reduction in studies)
- Faster debugging (you know exactly what broke)
- Better design (testable code is modular code)
- Living documentation (tests explain behavior)

### 5. "Tests after achieve the same goals"

They achieve DIFFERENT goals:
- Tests-first: Verify behavior meets specification
- Tests-after: Document existing behavior (including bugs)
- Tests-first: Drive design (code must be testable)
- Tests-after: Describe design (whatever shape it took)
- Tests-first: Catch regressions before they ship
- Tests-after: Catch regressions after they ship (maybe)

---

## Rationalization Prevention Table

| Excuse | Reality |
|--------|---------|
| "Code before test, just this once" | Delete it. Rewrite. No exceptions. |
| "I'll write the test right after" | After = never. Write the test now. |
| "The test passes immediately" | Then you didn't write a failing test. Investigate. |
| "I can't explain why it should fail" | You don't understand the requirement. Stop and clarify. |
| "I already manually tested" | Manual testing is not automated testing. Write the test. |
| "Keep as reference" | Delete means delete. Rewrite from scratch. |
| "Already spent X hours" | Sunk cost fallacy. Delete and rewrite correctly. |
| "TDD is dogmatic" | It's discipline, not dogma. Follow the process. |
| "Spirit not ritual" | The ritual IS the spirit. The discipline IS the value. |
| "Tests after achieve same purpose" | Prove it by deleting all code first, then writing tests. |
| "This is too simple to test" | Simple things break too. Write the test. |

---

## Red Flags

Stop immediately if any of these occur:

1. **Code written before test** -- Delete the code. Write the test first.
2. **Test passes immediately** -- Your test is wrong or the behavior already exists. Investigate.
3. **Can't explain expected failure** -- You don't understand the requirement. Clarify before proceeding.
4. **"Just this once"** -- There is no "just this once." Follow the process every time.
5. **"I already manually tested"** -- Manual testing is not a substitute. Write the automated test.
6. **"Keep as reference"** -- If code was written before tests, it cannot be kept as reference. Delete it.
7. **Multiple behaviors in one test** -- Split into separate tests. One behavior per test.
8. **Mocking everything** -- If you're mocking more than external dependencies, your design needs work.
9. **Skipping REFACTOR** -- Technical debt accumulates. Refactor while tests are green.
10. **Not running the neighbours** -- Run the new test, then the rest of its test file and module group. The full suite is the final gate (see `_shared/verification-loop.md` Cadence), not a per-step or per-phase run.

---

## Verification Checklist

Before declaring a feature complete:

- [ ] Every function/method has at least one test
- [ ] Watched each test fail first (RED phase verified)
- [ ] Each test failed for the expected reason
- [ ] Wrote minimal code to pass each test (no overengineering)
- [ ] All tests pass (GREEN phase verified)
- [ ] Output is pristine (no warnings, no skipped tests)
- [ ] Used real code, not mocks (where possible)
- [ ] Edge cases covered (empty input, null, boundaries, error cases)
- [ ] Refactored with confidence (tests still green after every change)
- [ ] No production code exists without a corresponding test

---

## Test Naming Convention

Tests should read like specifications:

```
GOOD:
test_empty_cart_returns_zero_total
test_adding_item_increases_count_by_one
test_removing_last_item_empties_cart
test_discount_applies_only_above_threshold
test_invalid_coupon_raises_error

BAD:
test_cart
test_add
test_remove
test1
test_it_works
```

---

## When to Use Mocks (and When Not To)

**Use mocks for:**
- External APIs (HTTP calls, third-party services)
- Databases (in unit tests; use real DB in integration tests)
- Filesystem operations (in unit tests)
- Time-dependent behavior (freeze time)
- Expensive operations (ML inference, video processing)

**Do NOT mock:**
- Your own code (test the real implementation)
- Simple data structures (use real objects)
- Pure functions (no side effects = no need to mock)
- Anything you can test with real code in < 1 second

**See also:** `testing-anti-patterns.md` for detailed anti-pattern guide.

---

## TDD Cycle Timing

| Phase | Typical Duration | Warning Sign |
|-------|-----------------|--------------|
| RED | 1-5 minutes | > 10 min = test is too complex, split it |
| GREEN | 1-10 minutes | > 20 min = multiple behaviors, split the test |
| REFACTOR | 2-10 minutes | > 15 min = too much accumulated debt, refactor more frequently |

If a full RED-GREEN-REFACTOR cycle takes more than 30 minutes, you're taking steps that are too large. Break down the behavior into smaller pieces.

---

## Integration with Other Skills

| Skill | Interaction |
|-------|-------------|
| `gaspol-execute` | TDD cycle runs inside each implementation phase |
| `gaspol-debug` | After fixing a bug, write a regression test (RED: reproduce bug, GREEN: fix, REFACTOR) |
| `gaspol-plan` | Plan identifies WHAT to test; TDD determines HOW and WHEN |
| `gaspol-verify` | Final verification runs full test suite, confirms TDD was followed |
| `gaspol-dispatch` | Each dispatched agent follows TDD independently |

---

## Quick Reference

```
1. STATE what the test will verify (one behavior)
2. STATE why it will fail and what error to expect
3. WRITE the test
4. RUN it -- confirm it FAILS for the expected reason
5. WRITE the simplest code to pass
6. RUN all tests -- confirm ALL pass with pristine output
7. REFACTOR -- improve code quality
8. RUN all tests -- confirm still green
9. REPEAT from step 1 for next behavior
```
