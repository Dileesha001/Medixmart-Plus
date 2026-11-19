/**
 * Multi-Member Schema Harmonization & Joint Integration Smoke Test Suite.
 * Verifies M1-W4-03 deliverables:
 * - End-to-end relational schema integrity across:
 *   - M3: Suppliers & Batches (Inventory & Expiry)
 *   - M4: Sales & Sale Items (POS & FEFO Deductions)
 *   - M5: Customers & Credit Payments (Debt & Repayments)
 *   - M1: Users & Alerts (Cashier attribution & Notifications)
 * - Atomic transaction consistency and FEFO allocation order
 * - Foreign key restriction safeguards and check constraint enforcement
 */
const assert = require('assert');
const db = require('../../src/config/db');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runSchemaHarmonizationTests() {
  console.log('====================================================');
  console.log(' Starting M1-W4-03 Schema Harmonization Smoke Tests');
  console.log('====================================================');

  const client = await db.getClient();

  try {
    // Step 0: Ensure all schema migrations and initial users are applied
    console.log('\n[1/9] Applying all database migrations...');
    await applySchema();
    const adminUser = await seedUsers({ seedPharmacist: true });
    console.log('      Schema migrations and admin seed verified.');

    // Step 1: Register a new supplier (M3 domain)
    console.log('\n[2/9] Registering supplier (M3: Stock & Purchase)...');
    const supplierRes = await client.query(
      `INSERT INTO suppliers (name, contact_person, phone, email, address, is_active)
       VALUES ($1, $2, $3, $4, $5, TRUE)
       RETURNING id, name, phone, is_active`,
      [
        `State Pharmaceuticals Manufacturing - ${Date.now()}`,
        'Dr. N. Fernando',
        `+94112${Math.floor(100000 + Math.random() * 900000)}`,
        'supplies@spmc.gov.lk',
        'No. 11, Sir John Kotelawala Mawatha, Ratmalana'
      ]
    );
    const supplierId = supplierRes.rows[0].id;
    assert.ok(supplierId > 0);
    console.log(`      Passed: Supplier created with ID ${supplierId}.`);

    // Step 2: Ensure Category and Medicine exist (M1/M3 domain)
    console.log('\n[3/9] Establishing Category and Medicine...');
    const catRes = await client.query(
      `INSERT INTO categories (name, description)
       VALUES ($1, $2)
       ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description
       RETURNING id`,
      ['Cardiovascular', 'Heart and blood pressure treatments']
    );
    const categoryId = catRes.rows[0].id;

    const medRes = await client.query(
      `INSERT INTO medicines (name, generic_name, brand, strength, category_id, selling_price, cost_price, reorder_level)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 20)
       ON CONFLICT (name, strength) DO UPDATE SET generic_name = EXCLUDED.generic_name
       RETURNING id, name, strength, selling_price`,
      [`Atorva_${Date.now()}`, 'Atorvastatin', 'Pfizer', '20mg', categoryId, 25.00, 18.50]
    );
    const medicineId = medRes.rows[0].id;
    console.log(`      Passed: Medicine created with ID ${medicineId} in Category ${categoryId}.`);

    // Step 3: Receive multiple Batches with different expiry dates (FEFO setup)
    console.log('\n[4/9] Receiving stock batches with FEFO expiry variations...');
    // Batch 1: Expiring in 8 months (nearer)
    const batch1Res = await client.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, received_date, expiry_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_DATE, CURRENT_DATE + INTERVAL '8 months')
       RETURNING id, batch_number, current_quantity, expiry_date`,
      [medicineId, supplierId, `B-EARLY-${Date.now()}`, 100, 100, 18.50, 25.00]
    );
    const batchEarly = batch1Res.rows[0];

    // Batch 2: Expiring in 24 months (later)
    const batch2Res = await client.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, received_date, expiry_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_DATE, CURRENT_DATE + INTERVAL '24 months')
       RETURNING id, batch_number, current_quantity, expiry_date`,
      [medicineId, supplierId, `B-LATE-${Date.now()}`, 200, 200, 18.00, 25.00]
    );
    const batchLate = batch2Res.rows[0];
    console.log(`      Passed: Received Batch 1 (Early expiry, ID: ${batchEarly.id}) and Batch 2 (Late expiry, ID: ${batchLate.id}).`);

    // Step 4: Register a Customer with credit limit (M5 domain)
    console.log('\n[5/9] Registering customer with credit limit (M5: Credit Management)...');
    const custPhone = `077${Math.floor(1000000 + Math.random() * 9000000)}`;
    const custRes = await client.query(
      `INSERT INTO customers (name, phone, email, address, date_of_birth, credit_limit, current_balance)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, name, phone, credit_limit, current_balance`,
      ['Sunil Perera', custPhone, 'sunil.perera@example.com', 'Kandy Road, Kiribathgoda', '1985-06-15', 10000.00, 0.00]
    );
    const customer = custRes.rows[0];
    assert.strictEqual(parseFloat(customer.current_balance), 0.00);
    console.log(`      Passed: Customer created (ID: ${customer.id}, Balance: ${customer.current_balance}, Limit: ${customer.credit_limit}).`);

    // Step 5: Execute atomic POS checkout transaction with FEFO allocation
    console.log('\n[6/9] Executing atomic POS credit sale with FEFO batch allocation...');
    await client.query('BEGIN');

    // 5a. FEFO Allocation: Select earliest expiring batch with row locking
    const fefoQuery = `
      SELECT id, batch_number, current_quantity, selling_price, expiry_date
      FROM batches
      WHERE medicine_id = $1 AND current_quantity > 0 AND is_active = TRUE
      ORDER BY expiry_date ASC, id ASC
      FOR UPDATE
    `;
    const allocRes = await client.query(fefoQuery, [medicineId]);
    assert.ok(allocRes.rows.length >= 2);
    // Crucial: First batch selected MUST be the earlier expiring batch!
    const allocatedBatch = allocRes.rows[0];
    assert.strictEqual(allocatedBatch.id, batchEarly.id, 'FEFO must select earliest expiring batch first');

    // 5b. Deduct quantity from batch
    const saleQty = 10;
    const unitPrice = parseFloat(allocatedBatch.selling_price);
    const subtotal = saleQty * unitPrice;

    await client.query(
      `UPDATE batches
       SET current_quantity = current_quantity - $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [saleQty, allocatedBatch.id]
    );

    // 5c. Create Sale record
    const invoiceNumber = `INV-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;
    const saleInsert = `
      INSERT INTO sales (invoice_number, user_id, customer_id, subtotal, discount_amount, total_amount, payment_type, paid_amount, credit_amount, payment_status)
      VALUES ($1, $2, $3, $4, 0.00, $5, 'credit', 0.00, $6, 'unpaid')
      RETURNING id, invoice_number, total_amount, credit_amount, payment_status
    `;
    const saleRes = await client.query(saleInsert, [
      invoiceNumber,
      adminUser.id,
      customer.id,
      subtotal,
      subtotal,
      subtotal
    ]);
    const saleId = saleRes.rows[0].id;

    // 5d. Create Sale Item linking exact batch and medicine
    await client.query(
      `INSERT INTO sale_items (sale_id, medicine_id, batch_id, quantity, unit_price, subtotal)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [saleId, medicineId, allocatedBatch.id, saleQty, unitPrice, subtotal]
    );

    // 5e. Update customer outstanding balance
    await client.query(
      `UPDATE customers
       SET current_balance = current_balance + $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [subtotal, customer.id]
    );

    await client.query('COMMIT');
    console.log(`      Passed: Sale ${invoiceNumber} completed atomically. Batch stock deducted to 90. Customer balance increased by ${subtotal}.`);

    // Verify post-sale states
    const postBatchRes = await client.query('SELECT current_quantity FROM batches WHERE id = $1', [batchEarly.id]);
    assert.strictEqual(postBatchRes.rows[0].current_quantity, 90);

    const postCustRes = await client.query('SELECT current_balance FROM customers WHERE id = $1', [customer.id]);
    assert.strictEqual(parseFloat(postCustRes.rows[0].current_balance), subtotal);

    // Step 6: Customer Debt Repayment (M5 domain)
    console.log('\n[7/9] Recording customer debt repayment (M5: Credit Payments)...');
    await client.query('BEGIN');
    const paymentAmount = 150.00; // Partial repayment
    await client.query(
      `INSERT INTO credit_payments (customer_id, sale_id, amount, payment_method, reference_note, recorded_by)
       VALUES ($1, $2, $3, 'cash', 'Partial bill settlement', $4)`,
      [customer.id, saleId, paymentAmount, adminUser.id]
    );

    await client.query(
      `UPDATE customers
       SET current_balance = current_balance - $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [paymentAmount, customer.id]
    );
    await client.query('COMMIT');

    const expectedBalance = subtotal - paymentAmount;
    const finalCustRes = await client.query('SELECT current_balance FROM customers WHERE id = $1', [customer.id]);
    assert.strictEqual(parseFloat(finalCustRes.rows[0].current_balance), expectedBalance);
    console.log(`      Passed: Repayment of Rs. ${paymentAmount} recorded. Updated balance: Rs. ${expectedBalance}.`);

    // Step 7: Alert Subsystem Integration (M3/M4 domain)
    console.log('\n[8/9] Testing alerts table integration (M3/M4: Expiry & Stock Alerts)...');
    const alertRes = await client.query(
      `INSERT INTO alerts (alert_type, severity, title, message, reference_table, reference_id)
       VALUES ('expiry_warning', 'warning', $1, $2, 'batches', $3)
       RETURNING id, alert_type, is_resolved`,
      [
        `Batch ${batchEarly.batch_number} Expiring Soon`,
        `Batch ${batchEarly.batch_number} of Atorvastatin reaches 7-month return window on ${batchEarly.expiry_date}.`,
        batchEarly.id
      ]
    );
    const alertId = alertRes.rows[0].id;
    assert.strictEqual(alertRes.rows[0].is_resolved, false);

    // Resolve alert
    await client.query(
      'UPDATE alerts SET is_resolved = TRUE, resolved_at = CURRENT_TIMESTAMP WHERE id = $1',
      [alertId]
    );
    console.log('      Passed: Expiry warning alert created and marked resolved.');

    // Step 8: Foreign Key & Constraint Safeguards Verification
    console.log('\n[9/9] Verifying Foreign Key & Check Constraint integrity safeguards...');

    // 8a. Deleting a supplier with batches must fail (FK ON DELETE RESTRICT)
    let supplierDeleteBlocked = false;
    try {
      await client.query('DELETE FROM suppliers WHERE id = $1', [supplierId]);
    } catch (err) {
      if (err.code === '23503') supplierDeleteBlocked = true;
    }
    assert.ok(supplierDeleteBlocked, 'Supplier deletion must be blocked by foreign key constraint (23503)');
    console.log('      Passed: FK ON DELETE RESTRICT prevented deleting active supplier.');

    // 8b. Negative batch quantity must fail (CHECK constraint)
    let checkViolationCaught = false;
    try {
      await client.query(
        `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
         VALUES ($1, $2, 'INVALID_QTY', -5, -5, 10, 15, CURRENT_DATE + INTERVAL '1 year')`,
        [medicineId, supplierId]
      );
    } catch (err) {
      if (err.code === '23514') checkViolationCaught = true;
    }
    assert.ok(checkViolationCaught, 'Negative batch quantity must trigger CHECK constraint violation (23514)');
    console.log('      Passed: CHECK constraint prevented negative batch quantity.');

    // 8c. Duplicate batch number for same medicine must fail (UNIQUE constraint)
    let duplicateBatchCaught = false;
    try {
      await client.query(
        `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
         VALUES ($1, $2, $3, 50, 50, 10, 15, CURRENT_DATE + INTERVAL '1 year')`,
        [medicineId, supplierId, batchEarly.batch_number]
      );
    } catch (err) {
      if (err.code === '23505') duplicateBatchCaught = true;
    }
    assert.ok(duplicateBatchCaught, 'Duplicate batch number for same medicine must trigger UNIQUE violation (23505)');
    console.log('      Passed: UNIQUE constraint prevented duplicate batch number.');

    console.log('\n====================================================');
    console.log(' All M1-W4-03 Schema Harmonization Tests Passed (9/9)!');
    console.log('====================================================');
  } finally {
    client.release();
    await db.closePool();
  }
}

if (require.main === module) {
  runSchemaHarmonizationTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Schema harmonization test error:', err);
      process.exit(1);
    });
}

module.exports = runSchemaHarmonizationTests;
