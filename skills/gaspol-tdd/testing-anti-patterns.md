# Testing Anti-Patterns Reference

## Iron Laws

1. **NEVER test mock behavior** -- Assert on real outcomes, not on what you told the mock to return.
2. **NEVER add test-only methods to production classes** -- If a method exists solely for testing, your design is wrong.
3. **NEVER mock without understanding dependencies** -- Mocking hides structural problems. Understand first, mock second.

---

## Anti-Pattern 1: Testing Mock Behavior

### Description

You create a mock, configure it to return a value, then assert that the value you configured was returned. You are testing your own mock setup, not your production code.

### Example (BAD)

```python
def test_user_service_returns_user():
    mock_repo = Mock()
    mock_repo.find_by_id.return_value = User(id=1, name="Alice")

    service = UserService(mock_repo)
    result = service.get_user(1)

    # BAD: You're asserting on the value YOU told the mock to return
    assert result.name == "Alice"
    assert result.id == 1
```

This test will ALWAYS pass. It proves nothing about `UserService.get_user()`. It only proves that Python's Mock class works correctly.

### Gate Function: How to Detect

Ask yourself: "If I delete the implementation of the method under test and replace it with `return self.repo.find_by_id(id)`, does the test still pass?"

If yes, you're testing mock behavior.

### Fix

Test the actual behavior the service adds on top of the repository:

```python
def test_user_service_raises_on_missing_user():
    mock_repo = Mock()
    mock_repo.find_by_id.return_value = None

    service = UserService(mock_repo)

    # GOOD: Testing that the service handles None correctly
    with pytest.raises(UserNotFoundError):
        service.get_user(999)

def test_user_service_formats_display_name():
    mock_repo = Mock()
    mock_repo.find_by_id.return_value = User(id=1, first="Alice", last="Smith")

    service = UserService(mock_repo)
    result = service.get_user(1)

    # GOOD: Testing transformation logic the service provides
    assert result.display_name == "Alice S."
```

---

## Anti-Pattern 2: Test-Only Methods in Production

### Description

You add a method like `destroy()`, `reset()`, `_get_internal_state()`, or `set_test_mode()` to a production class solely to make testing easier. This pollutes your production API and signals a design problem.

### Example (BAD)

```typescript
class ConnectionPool {
  private connections: Connection[] = [];

  acquire(): Connection { /* ... */ }
  release(conn: Connection): void { /* ... */ }

  // BAD: This method exists ONLY for tests
  _getConnectionCount(): number {
    return this.connections.length;
  }

  // BAD: This method exists ONLY for tests
  destroy(): void {
    this.connections.forEach(c => c.close());
    this.connections = [];
  }
}

// Test
test('pool manages connections', () => {
  const pool = new ConnectionPool();
  const conn = pool.acquire();
  expect(pool._getConnectionCount()).toBe(1);  // BAD
  pool.release(conn);
  pool.destroy();  // BAD: cleanup that only tests need
});
```

### Gate Function: How to Detect

Search your production code for callers of the method. If the ONLY callers are test files, the method is a test-only method.

```bash
# If this returns only test files, it's a test-only method
grep -rn "destroy\(\)" --include="*.ts" --exclude-dir="__tests__"
```

### Fix

Redesign so tests observe behavior through the public API:

```typescript
class ConnectionPool {
  private connections: Connection[] = [];
  readonly maxConnections: number;

  acquire(): Connection { /* ... */ }
  release(conn: Connection): void { /* ... */ }

  // PUBLIC API that production code also uses
  get availableCount(): number {
    return this.maxConnections - this.connections.length;
  }
}

// Test uses public API
test('acquiring a connection reduces available count', () => {
  const pool = new ConnectionPool({ max: 5 });
  expect(pool.availableCount).toBe(5);

  const conn = pool.acquire();
  expect(pool.availableCount).toBe(4);

  pool.release(conn);
  expect(pool.availableCount).toBe(5);
});
```

For cleanup, use proper lifecycle management (dependency injection, test fixtures, `afterEach` hooks) instead of test-only methods.

---

## Anti-Pattern 3: Mocking Without Understanding

### Description

You encounter a dependency that's hard to test with, so you immediately mock it without understanding WHY it's hard to test. The mock hides a structural problem in your code -- tight coupling, hidden dependencies, or mixed concerns.

### Example (BAD)

```python
def test_order_processor():
    # Mocking 6 dependencies without asking "why does this need 6 dependencies?"
    mock_db = Mock()
    mock_email = Mock()
    mock_payment = Mock()
    mock_inventory = Mock()
    mock_logger = Mock()
    mock_analytics = Mock()

    processor = OrderProcessor(
        mock_db, mock_email, mock_payment,
        mock_inventory, mock_logger, mock_analytics
    )

    processor.process(order)

    mock_payment.charge.assert_called_once()
    mock_inventory.reserve.assert_called_once()
    mock_email.send.assert_called_once()
```

### Gate Function: How to Detect

Count the mocks in your test setup. If you need more than 2-3 mocks for a unit test, your production class has too many responsibilities.

**Warning thresholds:**
- 1-2 mocks: Normal
- 3-4 mocks: Review the class design
- 5+ mocks: Class needs to be split

### Fix

Split the class by responsibility, then test each piece with minimal mocking:

```python
class PaymentProcessor:
    def __init__(self, payment_gateway):
        self.gateway = payment_gateway

    def charge(self, order) -> PaymentResult:
        return self.gateway.charge(order.total)

class InventoryManager:
    def __init__(self, inventory_service):
        self.inventory = inventory_service

    def reserve(self, items) -> ReservationResult:
        return self.inventory.reserve(items)

# Each test now needs only 1 mock
def test_payment_charges_correct_amount():
    mock_gateway = Mock()
    mock_gateway.charge.return_value = PaymentResult(success=True)

    processor = PaymentProcessor(mock_gateway)
    result = processor.charge(Order(total=29.99))

    mock_gateway.charge.assert_called_with(29.99)
    assert result.success is True
```

---

## Anti-Pattern 4: Incomplete Mocks

### Description

You mock part of a dependency but not all the parts your code uses. The test passes because the unmocked parts return `Mock()` objects (which are truthy, have all attributes, and don't raise exceptions). Your test hides incorrect assumptions about the dependency.

### Example (BAD)

```typescript
test('user registration', () => {
  const mockDb = {
    insert: jest.fn().mockResolvedValue({ id: 1 }),
    // Forgot to mock: findByEmail, beginTransaction, commit
  };

  const service = new RegistrationService(mockDb as any);  // `as any` = red flag

  // This passes because mockDb.findByEmail returns undefined (falsy)
  // which accidentally makes the "user doesn't exist" check pass
  await service.register({ email: 'test@example.com', password: 'secret' });

  expect(mockDb.insert).toHaveBeenCalled();
});
```

### Gate Function: How to Detect

1. Search for `as any` type casts on mocks -- these hide missing properties
2. Check if the mock has ALL methods that the production code calls
3. Ask: "If the dependency's API changes, will this test catch it?"

### Fix

Use typed mocks or factory functions that enforce completeness:

```typescript
// Create a typed mock factory
function createMockDb(): jest.Mocked<Database> {
  return {
    insert: jest.fn(),
    findByEmail: jest.fn(),
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
  };
}

test('user registration checks for existing email', () => {
  const mockDb = createMockDb();
  mockDb.findByEmail.mockResolvedValue(null);  // Explicit: no existing user
  mockDb.insert.mockResolvedValue({ id: 1 });
  mockDb.beginTransaction.mockResolvedValue(undefined);
  mockDb.commit.mockResolvedValue(undefined);

  const service = new RegistrationService(mockDb);
  await service.register({ email: 'test@example.com', password: 'secret' });

  expect(mockDb.findByEmail).toHaveBeenCalledWith('test@example.com');
  expect(mockDb.insert).toHaveBeenCalled();
  expect(mockDb.commit).toHaveBeenCalled();
});
```

---

## Anti-Pattern 5: Integration Tests as Afterthought

### Description

You have thorough unit tests with mocks for every dependency, but zero integration tests that verify the pieces work together. Each unit works perfectly in isolation, but the system fails when assembled because the mocks don't match reality.

### Example (BAD)

```python
# Unit test: PaymentService (mocked gateway)
def test_payment_service():
    mock_gateway = Mock()
    mock_gateway.charge.return_value = {"status": "success", "id": "txn_123"}
    service = PaymentService(mock_gateway)
    result = service.process_payment(100)
    assert result["status"] == "success"

# Unit test: OrderService (mocked payment)
def test_order_service():
    mock_payment = Mock()
    mock_payment.process_payment.return_value = {"paid": True}  # DIFFERENT SHAPE!
    service = OrderService(mock_payment)
    result = service.complete_order(order)
    assert result.is_complete

# Both tests pass! But PaymentService returns {"status": "success"}
# while OrderService expects {"paid": True}. Production will crash.
```

### Gate Function: How to Detect

For each mock in your unit tests, ask: "Is there an integration test that verifies this mock matches the real dependency's behavior?"

If the answer is "no" for any mock, you have a gap.

**Check:**
1. List all mocked dependencies in unit tests
2. For each, find the corresponding integration test
3. If no integration test exists, the mock's return values are unverified assumptions

### Fix

Add integration tests for critical paths:

```python
# Integration test: Real PaymentService + Real OrderService
@pytest.mark.integration
def test_order_payment_integration():
    # Use test doubles that match production behavior
    test_gateway = TestPaymentGateway()  # Sandbox/test mode, real API shape
    payment_service = PaymentService(test_gateway)
    order_service = OrderService(payment_service)

    result = order_service.complete_order(test_order)

    assert result.is_complete
    assert result.payment_id.startswith("txn_")
```

---

## Quick Detection Checklist

Before committing any test, run through these questions:

| Question | If YES | Anti-Pattern |
|----------|--------|-------------|
| Am I asserting on a value I configured the mock to return? | Stop. | #1: Testing Mock Behavior |
| Does this method only get called from test files? | Stop. | #2: Test-Only Methods |
| Am I casting my mock with `as any` or ignoring type errors? | Stop. | #4: Incomplete Mocks |
| Do I have more than 3 mocks in this test setup? | Review. | #3: Mocking Without Understanding |
| Are ALL my tests unit tests with mocks? | Add integration tests. | #5: Integration Tests as Afterthought |

---

## The Mock Spectrum

Use this to decide your mocking strategy:

```
No mocks                                                    Everything mocked
|---------|-----------|------------|------------|-----------|
Pure      Simple     External     Complex      Over-
functions  deps      APIs         systems      mocked

GOOD <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< BAD

Move LEFT whenever possible:
- Can you use a real dependency? Use it.
- Can you use an in-memory substitute? Use it.
- Must you mock? Mock the minimum surface area.
```

---

## Summary

| Anti-Pattern | Root Cause | Fix |
|-------------|-----------|-----|
| Testing Mock Behavior | Asserting on mock config | Assert on real transformation/behavior |
| Test-Only Methods | Leaky abstraction | Redesign public API |
| Mocking Without Understanding | Too many responsibilities | Split classes by concern |
| Incomplete Mocks | Type safety bypassed | Use typed mock factories |
| Integration Tests as Afterthought | Unit tests only | Add integration tests for critical paths |
