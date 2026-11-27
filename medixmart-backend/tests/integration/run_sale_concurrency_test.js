/**
 * Sales Concurrency, FEFO Allocation, and Rollback Integration Test Suite.
 * Verifies M1-W5-03 deliverables:
 * - Single-client transactional boundaries with BEGIN / COMMIT / ROLLBACK
 * - Pessimistic row locking (SELECT ... FOR UPDATE) preventing inventory oversell
 * - Automatic Expiry-First (FEFO) batch consumption
 * - Atomic customer credit limit enforcement and balance updates
 * - High-concurrency race condition testing (5 simultaneous checkouts competing for limited stock)
 * - Expired batch quarantine and exclusion
 */
const request = require('supertest');
const assert = require('assert');
const app = require('../../src/app');
const db = require('../../src/config/db');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runSaleConcurrencyTests() {
  console.log('====================================================');
  console.log(' Starting M1-W5-03 Sale Concurrency & Locking Tests');
  console.log('====================================================');

  try {
    // Step 0: Ensure schema and admin seed
    console.log('\n[1/7] Initializing database and acquiring auth token...');
    await applySchema();
    await seedUsers({ seedPharmacist: true });

    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Admin@Medix123' });
    assert.strictEqual(loginRes.statusCode, 200);
    const token = loginRes.body.data.token;
    console.log('      Admin authenticated successfully.');

    // Step 1: Create test supplier, category, and medicine
    console.log('\n[2/7] Creating test inventory fixtures...');
    const suppRes = await db.query(
      `INSERT INTO suppliers (name, contact_person, phone)
       VALUES ($1, 'Sales Test Lead', '0112334455')
       RETURNING id`,
      [`Concurrency Supplier - ${Date.now()}`]
    );
    const supplierId = suppRes.rows[0].id;

    const catRes = await db.query(
      `INSERT INTO categories (name, description)
       VALUES ($1, 'Analgesics')
       ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description
       RETURNING id`,
      ['Analgesics & Pain']
    );
    const categoryId = catRes.rows[0].id;

    const medRes = await db.query(
      `INSERT INTO medicines (name, generic_name, brand, strength, category_id, selling_price, cost_price)
       VALUES ($1, 'Paracetamol', 'Panadol', '500mg', $2, 20.00, 14.00)
       RETURNING id, name`,
      [`Panadol Concurrency ${Date.now()}`, categoryId]
    );
    const medicineId = medRes.rows[0].id;

    // Batch 1 (Early expiry: 2 months ahead), qty = 10
    const b1Res = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 10, 10, 14.00, 20.00, CURRENT_DATE + INTERVAL '2 months')
       RETURNING id, current_quantity`,
      [medicineId, supplierId, `B-FEFO-EARLY-${Date.now()}`]
    );
    const batchEarlyId = b1Res.rows[0].id;

    // Batch 2 (Late expiry: 12 months ahead), qty = 20
    const b2Res = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 20, 20, 14.00, 20.00, CURRENT_DATE + INTERVAL '12 months')
       RETURNING id, current_quantity`,
      [medicineId, supplierId, `B-FEFO-LATE-${Date.now()}`]
    );
    const batchLateId = b2Res.rows[0].id;
    console.log(`      Created Batch Early (ID: ${batchEarlyId}, Qty: 10) and Batch Late (ID: ${batchLateId}, Qty: 20).`);

    // Step 2: Test FEFO Auto-Allocation (Buy 15 units across 2 batches)
    console.log('\n[3/7] Testing FEFO multi-batch auto-allocation (Buying 15 units)...');
    const fefoSaleRes = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${token}`)
      .send({
        payment_type: 'cash',
        items: [{ medicine_id: medicineId, quantity: 15 }]
      });

    assert.strictEqual(fefoSaleRes.statusCode, 201);
    assert.strictEqual(fefoSaleRes.body.success, true);
    assert.ok(fefoSaleRes.body.data.invoice_number.startsWith('INV-'));

    // Verify batch deductions: Early batch must be depleted to 0, Late batch must be reduced to 15
    const b1Check = await db.query('SELECT current_quantity FROM batches WHERE id = $1', [batchEarlyId]);
    const b2Check = await db.query('SELECT current_quantity FROM batches WHERE id = $1', [batchLateId]);

    assert.strictEqual(b1Check.rows[0].current_quantity, 0, 'Early expiring batch must be fully consumed first (0 left)');
    assert.strictEqual(b2Check.rows[0].current_quantity, 15, 'Late expiring batch must supply remainder (15 left)');
    console.log('      Passed: FEFO correctly depleted earlier batch (10 -> 0) and late batch (20 -> 15).');

    // Step 3: Test Atomic Customer Credit Limit Enforcement
    console.log('\n[4/7] Testing atomic credit sale and credit limit enforcement...');
    const custPhone = `071${Math.floor(1000000 + Math.random() * 9000000)}`;
    const custRes = await db.query(
      `INSERT INTO customers (name, phone, credit_limit, current_balance)
       VALUES ('Nimal Perera', $1, 200.00, 150.00)
       RETURNING id, current_balance, credit_limit`,
      [custPhone]
    );
    const customerId = custRes.rows[0].id;

    // Attempt credit sale of 4 units @ Rs. 20 = Rs. 80.
    // Current debt (150) + 80 = 230 > limit (200). Must fail and roll back!
    const overLimitRes = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${token}`)
      .send({
        customer_id: customerId,
        payment_type: 'credit',
        items: [{ medicine_id: medicineId, quantity: 4 }]
      });

    assert.strictEqual(overLimitRes.statusCode, 400);
    assert.strictEqual(overLimitRes.body.error.code, 'VALIDATION_ERROR');

    // Verify rollback: customer balance must remain 150, late batch quantity must remain 15
    const custCheck = await db.query('SELECT current_balance FROM customers WHERE id = $1', [customerId]);
    const b2CheckRollback = await db.query('SELECT current_quantity FROM batches WHERE id = $1', [batchLateId]);

    assert.strictEqual(parseFloat(custCheck.rows[0].current_balance), 150.00, 'Customer balance must not change on failure');
    assert.strictEqual(b2CheckRollback.rows[0].current_quantity, 15, 'Batch stock must not be deducted on failure');
    console.log('      Passed: Credit limit violation cleanly rolled back both balance and inventory.');

    // Valid credit sale: buy 2 units @ Rs. 20 = Rs. 40.
    // Current debt (150) + 40 = 190 <= 200 limit. Must succeed!
    const validCreditRes = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${token}`)
      .send({
        customer_id: customerId,
        payment_type: 'credit',
        items: [{ medicine_id: medicineId, quantity: 2 }]
      });

    assert.strictEqual(validCreditRes.statusCode, 201);
    const custUpdated = await db.query('SELECT current_balance FROM customers WHERE id = $1', [customerId]);
    assert.strictEqual(parseFloat(custUpdated.rows[0].current_balance), 190.00);
    console.log('      Passed: Valid credit sale atomically increased customer balance to Rs. 190.00.');

    // Step 4: Test High-Concurrency Race Condition (Oversell Prevention)
    console.log('\n[5/7] Testing high-concurrency race conditions (5 simultaneous checkouts competing for 10 units)...');
    // Setup a specific competition medicine with exactly 10 units in stock
    const compMedRes = await db.query(
      `INSERT INTO medicines (name, generic_name, brand, strength, category_id, selling_price, cost_price)
       VALUES ($1, 'Omeprazole', 'Losec', '20mg', $2, 50.00, 35.00)
       RETURNING id`,
      [`Losec Race ${Date.now()}`, categoryId]
    );
    const compMedId = compMedRes.rows[0].id;

    const compBatchRes = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 10, 10, 35.00, 50.00, CURRENT_DATE + INTERVAL '10 months')
       RETURNING id`,
      [compMedId, supplierId, `B-RACE-${Date.now()}`]
    );
    const compBatchId = compBatchRes.rows[0].id;

    // Launch 5 simultaneous checkout requests, each asking for 4 units. Total demand = 20 units against 10 in stock.
    console.log('      Dispatching 5 concurrent requests (4 units each, total demand 20, available 10)...');
    const checkoutPromises = [1, 2, 3, 4, 5].map(() =>
      request(app)
        .post('/api/sales')
        .set('Authorization', `Bearer ${token}`)
        .send({
          payment_type: 'cash',
          items: [{ medicine_id: compMedId, quantity: 4 }]
        })
    );

    const responses = await Promise.all(checkoutPromises);

    const successResponses = responses.filter((r) => r.statusCode === 201);
    const failedResponses = responses.filter((r) => r.statusCode === 400);

    console.log(`      Concurrency results: ${successResponses.length} succeeded, ${failedResponses.length} failed.`);

    // Exactly 2 checkouts can succeed (4 + 4 = 8 units). The third would need 4 units but only 2 remain, so it must fail.
    assert.strictEqual(successResponses.length, 2, 'Exactly 2 checkouts must succeed');
    assert.strictEqual(failedResponses.length, 3, 'Remaining 3 checkouts must be rejected with 400');

    // Verify final database state: exactly 2 units remaining (10 - 8 = 2), NEVER negative!
    const finalBatch = await db.query('SELECT current_quantity FROM batches WHERE id = $1', [compBatchId]);
    assert.strictEqual(finalBatch.rows[0].current_quantity, 2, 'Final batch quantity must be exactly 2');

    // Count sale items created
    const saleItemsCount = await db.query(
      'SELECT COUNT(*)::int AS count FROM sale_items WHERE batch_id = $1',
      [compBatchId]
    );
    assert.strictEqual(saleItemsCount.rows[0].count, 2, 'Exactly 2 sale item records must exist');
    console.log('      Passed: Pessimistic locking (FOR UPDATE) completely prevented overselling!');

    // Step 5: Test Expired Batch Protection
    console.log('\n[6/7] Testing expired batch exclusion...');
    const expBatchRes = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 50, 50, 35.00, 50.00, CURRENT_DATE - INTERVAL '3 days')
       RETURNING id`,
      [compMedId, supplierId, `B-EXPIRED-TEST-${Date.now()}`]
    );
    const expBatchId = expBatchRes.rows[0].id;

    // Explicitly requesting the expired batch must fail
    const explicitExpRes = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${token}`)
      .send({
        payment_type: 'cash',
        items: [{ medicine_id: compMedId, batch_id: expBatchId, quantity: 1 }]
      });

    assert.strictEqual(explicitExpRes.statusCode, 400);
    console.log('      Passed: Expired batch rejected with 400 validation error.');

    // Step 6: Test Sales Retrieval Endpoints
    console.log('\n[7/7] Testing GET /api/sales and GET /api/sales/:id...');
    const listSalesRes = await request(app)
      .get('/api/sales?limit=10')
      .set('Authorization', `Bearer ${token}`);

    assert.strictEqual(listSalesRes.statusCode, 200);
    assert.ok(listSalesRes.body.data.length >= 3);
    const firstSaleId = listSalesRes.body.data[0].id;

    const detailSaleRes = await request(app)
      .get(`/api/sales/${firstSaleId}`)
      .set('Authorization', `Bearer ${token}`);

    assert.strictEqual(detailSaleRes.statusCode, 200);
    assert.strictEqual(detailSaleRes.body.data.sale.id, firstSaleId);
    assert.ok(Array.isArray(detailSaleRes.body.data.items));
    assert.ok(detailSaleRes.body.data.items.length > 0);
    console.log(`      Passed: Retrieved sale ID ${firstSaleId} with ${detailSaleRes.body.data.items.length} line item(s).`);

    console.log('\n====================================================');
    console.log(' All M1-W5-03 Sale Concurrency Tests Passed (7/7)!');
    console.log('====================================================');
  } finally {
    await db.closePool();
  }
}

if (require.main === module) {
  runSaleConcurrencyTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Sale concurrency test error:', err);
      process.exit(1);
    });
}

module.exports = runSaleConcurrencyTests;

