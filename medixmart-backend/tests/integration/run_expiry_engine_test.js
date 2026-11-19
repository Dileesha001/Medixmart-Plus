/**
 * Expiry Alert SQL Engine & Service Integration Test Suite.
 * Verifies M1-W5-01 deliverables:
 * - Stored procedure generate_expiry_alerts() execution
 * - Categorization into 'expired' (danger) and 'expiry_warning' (warning within 7-month window)
 * - Strict idempotency (no duplicate active alerts on subsequent runs)
 * - Automatic resolution on stock depletion and inactive batch status
 * - Alert transition from warning to expired when expiry date passes
 * - REST API endpoints: GET /api/alerts, GET /api/alerts/summary, PATCH /api/alerts/:id/resolve, POST /api/alerts/generate-expiry
 */
const request = require('supertest');
const assert = require('assert');
const app = require('../../src/app');
const db = require('../../src/config/db');
const alertService = require('../../src/services/alert.service');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runExpiryEngineTests() {
  console.log('====================================================');
  console.log(' Starting M1-W5-01 Expiry Alert SQL Engine Tests');
  console.log('====================================================');

  try {
    // 1. Initialize schema and admin credentials
    console.log('\n[1/7] Applying database schema & stored procedures...');
    await applySchema();
    await seedUsers({ seedPharmacist: true });

    // Login as Admin to get auth token
    const adminLogin = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Admin@Medix123' });
    assert.strictEqual(adminLogin.statusCode, 200);
    const adminToken = adminLogin.body.data.token;

    // Login as Pharmacist to test role restrictions
    const pharmLogin = await request(app)
      .post('/api/auth/login')
      .send({ username: 'pharmacist1', password: 'Pharm@Medix123' });
    assert.strictEqual(pharmLogin.statusCode, 200);
    const pharmToken = pharmLogin.body.data.token;
    console.log('      Admin and Pharmacist tokens acquired.');

    // 2. Set up test fixtures (Supplier, Category, Medicine, Batches)
    console.log('\n[2/7] Setting up test batches for expiry calculation...');
    const suppRes = await db.query(
      `INSERT INTO suppliers (name, contact_person, phone)
       VALUES ($1, 'Mr. Test Contact', '0112999888')
       RETURNING id`,
      [`Alert Test Supplier - ${Date.now()}`]
    );
    const supplierId = suppRes.rows[0].id;

    const catRes = await db.query(
      `INSERT INTO categories (name, description)
       VALUES ($1, 'Respiratory drugs')
       ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description
       RETURNING id`,
      ['Respiratory']
    );
    const categoryId = catRes.rows[0].id;

    const medRes = await db.query(
      `INSERT INTO medicines (name, generic_name, brand, strength, category_id, selling_price, cost_price)
       VALUES ($1, 'Salbutamol', 'Ventolin', '100mcg', $2, 350.00, 280.00)
       ON CONFLICT (name, strength) DO UPDATE SET generic_name = EXCLUDED.generic_name
       RETURNING id`,
      [`Ventolin Inhaler ${Date.now()}`, categoryId]
    );
    const medicineId = medRes.rows[0].id;

    // Clear alerts, sale_items, and batches for fresh, isolated assertions
    await db.query("DELETE FROM alerts");
    await db.query("DELETE FROM sale_items");
    await db.query("DELETE FROM batches");

    // Batch A: Expired (10 days ago), quantity 50
    const batchARes = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 50, 50, 280.00, 350.00, CURRENT_DATE - INTERVAL '10 days')
       RETURNING id`,
      [medicineId, supplierId, `B-EXPIRED-${Date.now()}`]
    );
    const batchAId = batchARes.rows[0].id;

    // Batch B: Near Expiry (3 months ahead - within 7-month window), quantity 100
    const batchBRes = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 100, 100, 280.00, 350.00, CURRENT_DATE + INTERVAL '3 months')
       RETURNING id`,
      [medicineId, supplierId, `B-WARN-3M-${Date.now()}`]
    );
    const batchBId = batchBRes.rows[0].id;

    // Batch C: Safe expiry (12 months ahead - outside 7-month window), quantity 200
    await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 200, 200, 280.00, 350.00, CURRENT_DATE + INTERVAL '12 months')`,
      [medicineId, supplierId, `B-SAFE-12M-${Date.now()}`]
    );

    // Batch D: Near Expiry (2 months ahead), but depleted (quantity 0)
    await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 50, 0, 280.00, 350.00, CURRENT_DATE + INTERVAL '2 months')`,
      [medicineId, supplierId, `B-DEPLETED-${Date.now()}`]
    );

    // Batch E: Expired, but inactive (is_active = FALSE)
    await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date, is_active)
       VALUES ($1, $2, $3, 30, 30, 280.00, 350.00, CURRENT_DATE - INTERVAL '5 days', FALSE)`,
      [medicineId, supplierId, `B-INACTIVE-${Date.now()}`]
    );
    console.log('      Test batches created: Expired, Warning, Safe, Depleted, and Inactive.');

    // 3. First Execution of generate_expiry_alerts()
    console.log('\n[3/7] Executing generate_expiry_alerts() for the first time...');
    const firstRun = await alertService.generateExpiryAlerts(7);
    console.log('      First run stats:', firstRun);

    assert.strictEqual(firstRun.expired_alerts_created, 1, 'Should create exactly 1 expired alert for Batch A');
    assert.strictEqual(firstRun.warning_alerts_created, 1, 'Should create exactly 1 warning alert for Batch B');

    // Verify created alerts in DB
    const activeAlerts = await db.query(
      "SELECT id, alert_type, severity, reference_id FROM alerts WHERE is_resolved = FALSE ORDER BY alert_type"
    );
    assert.strictEqual(activeAlerts.rows.length, 2, 'Exactly 2 active alerts must exist');
    assert.strictEqual(activeAlerts.rows[0].alert_type, 'expired');
    assert.strictEqual(activeAlerts.rows[0].severity, 'danger');
    assert.strictEqual(activeAlerts.rows[0].reference_id, batchAId);

    assert.strictEqual(activeAlerts.rows[1].alert_type, 'expiry_warning');
    assert.strictEqual(activeAlerts.rows[1].severity, 'warning');
    assert.strictEqual(activeAlerts.rows[1].reference_id, batchBId);
    console.log('      Passed: Expired (danger) and Warning (warning) alerts verified.');

    // 4. Test Idempotency (Second Execution)
    console.log('\n[4/7] Testing idempotency: Running engine second time on identical data...');
    const secondRun = await alertService.generateExpiryAlerts(7);
    console.log('      Second run stats:', secondRun);

    assert.strictEqual(secondRun.expired_alerts_created, 0, 'Must NOT create duplicate expired alerts');
    assert.strictEqual(secondRun.warning_alerts_created, 0, 'Must NOT create duplicate warning alerts');

    const totalActiveRes = await db.query("SELECT COUNT(*)::int AS count FROM alerts WHERE is_resolved = FALSE");
    assert.strictEqual(totalActiveRes.rows[0].count, 2, 'Total active alerts must remain unchanged at 2');
    console.log('      Passed: Engine is strictly idempotent. No duplicate alerts created.');

    // 5. Test Auto-Resolution on Stock Depletion
    console.log('\n[5/7] Testing auto-resolution when batch stock reaches 0...');
    await db.query("UPDATE batches SET current_quantity = 0 WHERE id = $1", [batchBId]);

    const thirdRun = await alertService.generateExpiryAlerts(7);
    console.log('      Third run stats (post-depletion):', thirdRun);
    assert.ok(thirdRun.alerts_auto_resolved >= 1, 'Should auto-resolve alert for depleted batch');

    const bAlertRes = await db.query(
      "SELECT is_resolved, resolved_at FROM alerts WHERE reference_table = 'batches' AND reference_id = $1",
      [batchBId]
    );
    assert.strictEqual(bAlertRes.rows[0].is_resolved, true);
    assert.ok(bAlertRes.rows[0].resolved_at !== null);
    console.log('      Passed: Depleted batch alert automatically resolved.');

    // 6. Test Warning Graduation to Expired
    console.log('\n[6/7] Testing warning graduation to expired alert over time...');
    // Create new batch expiring in 1 month
    const batchGradRes = await db.query(
      `INSERT INTO batches (medicine_id, supplier_id, batch_number, initial_quantity, current_quantity, purchase_price, selling_price, expiry_date)
       VALUES ($1, $2, $3, 40, 40, 200, 300, CURRENT_DATE + INTERVAL '1 month')
       RETURNING id`,
      [medicineId, supplierId, `B-GRAD-${Date.now()}`]
    );
    const gradBatchId = batchGradRes.rows[0].id;

    // Generate warning
    await alertService.generateExpiryAlerts(7);

    // Simulate passage of time past expiration
    await db.query("UPDATE batches SET expiry_date = CURRENT_DATE - INTERVAL '1 day' WHERE id = $1", [gradBatchId]);

    // Re-run engine
    const gradRun = await alertService.generateExpiryAlerts(7);
    assert.strictEqual(gradRun.expired_alerts_created, 1, 'Graduated batch must produce new expired alert');

    // Confirm old warning is resolved and new expired alert is active
    const gradAlerts = await db.query(
      "SELECT alert_type, severity, is_resolved FROM alerts WHERE reference_table = 'batches' AND reference_id = $1 ORDER BY id ASC",
      [gradBatchId]
    );
    assert.strictEqual(gradAlerts.rows.length, 2);
    assert.strictEqual(gradAlerts.rows[0].alert_type, 'expiry_warning');
    assert.strictEqual(gradAlerts.rows[0].is_resolved, true, 'Old warning must be resolved');
    assert.strictEqual(gradAlerts.rows[1].alert_type, 'expired');
    assert.strictEqual(gradAlerts.rows[1].is_resolved, false, 'New expired alert must be active');
    console.log('      Passed: Batch graduated from warning to active expired alert cleanly.');

    // 7. Test REST API Endpoints (/api/alerts)
    console.log('\n[7/7] Testing /api/alerts REST endpoints & role permissions...');

    // GET /api/alerts (Pharmacist allowed)
    const listRes = await request(app)
      .get('/api/alerts?is_resolved=false')
      .set('Authorization', `Bearer ${pharmToken}`);
    assert.strictEqual(listRes.statusCode, 200);
    assert.strictEqual(listRes.body.success, true);
    assert.ok(Array.isArray(listRes.body.data));
    console.log('      Passed: GET /api/alerts returned active alerts for Pharmacist.');

    // GET /api/alerts/summary
    const summaryRes = await request(app)
      .get('/api/alerts/summary')
      .set('Authorization', `Bearer ${pharmToken}`);
    assert.strictEqual(summaryRes.statusCode, 200);
    assert.ok(summaryRes.body.data.total_active >= 2);
    assert.ok(summaryRes.body.data.danger_count >= 1);
    console.log('      Passed: GET /api/alerts/summary returned aggregated badge counts.');

    // PATCH /api/alerts/:id/resolve
    const targetAlertId = listRes.body.data[0].id;
    const resolveRes = await request(app)
      .patch(`/api/alerts/${targetAlertId}/resolve`)
      .set('Authorization', `Bearer ${pharmToken}`);
    assert.strictEqual(resolveRes.statusCode, 200);
    assert.strictEqual(resolveRes.body.data.alert.is_resolved, true);
    console.log(`      Passed: PATCH /api/alerts/${targetAlertId}/resolve resolved alert successfully.`);

    // POST /api/alerts/generate-expiry - Pharmacist blocked (403)
    const pharmTriggerRes = await request(app)
      .post('/api/alerts/generate-expiry')
      .set('Authorization', `Bearer ${pharmToken}`)
      .send({ months_ahead: 7 });
    assert.strictEqual(pharmTriggerRes.statusCode, 403);
    assert.strictEqual(pharmTriggerRes.body.error.code, 'AUTH_FORBIDDEN_ROLE');
    console.log('      Passed: Pharmacist blocked from triggering alert engine with 403.');

    // POST /api/alerts/generate-expiry - Admin permitted (200)
    const adminTriggerRes = await request(app)
      .post('/api/alerts/generate-expiry')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ months_ahead: 7 });
    assert.strictEqual(adminTriggerRes.statusCode, 200);
    assert.strictEqual(adminTriggerRes.body.success, true);
    assert.ok(adminTriggerRes.body.data.stats);
    console.log('      Passed: Admin triggered alert engine successfully with 200.');

    console.log('\n====================================================');
    console.log(' All M1-W5-01 Expiry Alert Engine Tests Passed (7/7)!');
    console.log('====================================================');
  } finally {
    await db.closePool();
  }
}

if (require.main === module) {
  runExpiryEngineTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Expiry alert engine test error:', err);
      process.exit(1);
    });
}

module.exports = runExpiryEngineTests;
