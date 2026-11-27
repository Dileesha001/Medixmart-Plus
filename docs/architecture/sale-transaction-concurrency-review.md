# Architectural Concurrency & Transaction Review: Sales Engine

**Document Role:** System Architecture Review (Member 1)  
**Target Module:** Member 4 (POS & Sales Engine)  
**Task Reference:** M1-W5-03  
**Effective Date:** 2026-11-22  

---

## 1. Executive Summary

In a high-throughput pharmacy environment, multiple cashier terminals simultaneously issue sales against shared inventory batches. Without rigorous transactional boundaries and concurrency controls, race conditions will cause **inventory overselling** (negative batch balances), **orphaned transactions**, and **inconsistent customer credit ledgers**.

This document validates the transaction boundaries, locking mechanics, rollback guarantees, and Expiry-First (FEFO) allocation rules implemented in the Medixmart Plus backend (`src/services/sale.service.js`).

---

## 2. Transaction Boundary Architecture

### 2.1 Single Dedicated Client Connection

A common anti-pattern in Node.js applications is calling `db.query('BEGIN')` on a connection pool instance. In `pg`, `pool.query()` picks an arbitrary connection from the pool for each call, meaning `BEGIN`, `UPDATE`, and `COMMIT` can execute on three entirely different database connections, destroying transactional isolation.

**Enforced Pattern:**
```javascript
// Correct: Acquire a dedicated connection for the entire transaction lifecycle
const client = await db.getClient();
try {
  await client.query('BEGIN');
  // ... all queries execute on 'client' ...
  await client.query('COMMIT');
} catch (err) {
  await client.query('ROLLBACK');
  throw err;
} finally {
  client.release(); // Crucial: release back to pool in all scenarios
}
```

---

## 3. Concurrency Control: Pessimistic Row Locking (`FOR UPDATE`)

Medixmart Plus uses PostgreSQL **Pessimistic Row-Level Locking** via `SELECT ... FOR UPDATE`.

### 3.1 Batch Row Locking

When evaluating available stock, batches are locked immediately upon read:

```sql
SELECT b.id, b.batch_number, b.current_quantity, b.selling_price, b.expiry_date
FROM batches b
WHERE b.medicine_id = $1 
  AND b.current_quantity > 0 
  AND b.is_active = TRUE 
  AND b.expiry_date >= CURRENT_DATE
ORDER BY b.expiry_date ASC, b.id ASC
FOR UPDATE;
```

#### Why `FOR UPDATE` is Essential:
1. When Cashier A and Cashier B attempt to buy the last 10 units of Panadol at the exact same millisecond:
   - Cashier A's transaction acquires an exclusive row lock on the batch row.
   - Cashier B's query pauses and waits until Cashier A completes (`COMMIT` or `ROLLBACK`).
   - When Cashier A commits, the quantity decreases to 0.
   - Cashier B's query unblocks and reads `current_quantity = 0`.
   - Cashier B's transaction detects insufficient stock and safely aborts with `400 VALIDATION_ERROR` (`INSUFFICIENT_STOCK`).
   - **Result:** Batch quantity never drops below zero; overselling is mathematically prevented.

### 3.2 Deadlock Prevention via Deterministic Sorting

When a sale contains multiple medicines (e.g. Medicine 10 and Medicine 5):
- Cashier A locks Medicine 10, then requests Medicine 5.
- Cashier B locks Medicine 5, then requests Medicine 10.
- This creates a classic database deadlock (`deadlock detected`, error code `40P01`).

**Enforced Mitigation:**
Before acquiring locks, the service sorts line items deterministically:
```javascript
const sortedItems = [...items].sort((a, b) => a.medicine_id - b.medicine_id);
```
All cashier processes acquire locks in the exact same ascending order, making deadlocks impossible.

---

## 4. Expiry-First (FEFO) Stock Allocation

Sri Lankan regulatory compliance and pharmacy profitability require dispensing medicines with the nearest expiration date first (FEFO: First-Expiry, First-Out).

```
Batches in Database for Paracetamol:
  - Batch 101: Expiry 2026-12-01 (Quantity: 10)  <-- Nearest expiry
  - Batch 102: Expiry 2027-06-01 (Quantity: 50)
  - Batch 103: Expiry 2026-10-01 (Expired)       <-- Filtered out (never allocated)

Checkout Request for 15 Units:
  1. Deduct 10 units from Batch 101 (Quantity becomes 0).
  2. Deduct 5 units from Batch 102 (Quantity becomes 45).
  3. Total allocated: 15 units.
```

The SQL query enforces:
```sql
WHERE b.expiry_date >= CURRENT_DATE
ORDER BY b.expiry_date ASC, b.id ASC
```

---

## 5. Atomicity & Customer Credit Ledger

When a customer makes a credit or split payment:
1. Customer row is locked:
   ```sql
   SELECT id, name, credit_limit, current_balance, is_active FROM customers WHERE id = $1 FOR UPDATE;
   ```
2. Credit limit calculation:
   ```javascript
   const newBalance = current_balance + credit_amount;
   if (newBalance > credit_limit) {
     throw new ValidationError('Credit limit exceeded...');
   }
   ```
3. Balance is updated in the **exact same transaction**:
   ```sql
   UPDATE customers SET current_balance = current_balance + $1 WHERE id = $2;
   ```

**Guaranteed Atomicity:**
If anything fails during the sale (e.g., a line item fails stock validation or the network drops), `ROLLBACK` reverts both the stock deductions AND the customer balance update. No customer is charged for items that were not dispensed.

---

## 6. Concurrency Verification Test Matrix

The automated integration test suite in [`tests/integration/run_sale_concurrency_test.js`](../../medixmart-backend/tests/integration/run_sale_concurrency_test.js) asserts:

| Scenario | Simulated Condition | Expected Behavior | Verification Status |
| :--- | :--- | :--- | :--- |
| **Normal Checkout** | Sufficient stock, cash payment | Stock deducted, sale created, invoice issued | Verified |
| **FEFO Allocation** | Multiple batches with near/far expiry | Earliest expiring batch consumed first | Verified |
| **Simultaneous Race Condition** | 5 concurrent checkouts for 4 units each on a batch of only 10 units | Exactly 2 checkouts succeed (8 units sold), 3 fail (`INSUFFICIENT_STOCK`). Final stock = 2 | Verified |
| **Credit Limit Safeguard** | Transaction exceeds customer credit limit | 400 error, zero stock deducted, zero balance increase | Verified |
| **Expired Batch Protection** | Batch expiry date < CURRENT_DATE | Excluded from FEFO queries; rejected if explicitly requested | Verified |
| **Atomic Rollback** | Exception triggered midway through multi-item checkout | Complete rollback, all batches restored to initial quantities | Verified |

