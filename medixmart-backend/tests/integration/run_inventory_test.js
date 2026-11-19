/**
 * Inventory APIs Integration Test Suite (Categories & Medicines).
 * Verifies M1-W3-02 requirements:
 * - Category CRUD & uniqueness constraint (409 DUPLICATE_ENTRY)
 * - Medicine CRUD, input validation, and search/pagination
 * - Role enforcement: Pharmacist read-only, Admin mutate
 * - Safe soft-deactivation (is_active = false) preserving historical record
 */
const request = require('supertest');
const assert = require('assert');
const app = require('../../src/app');
const db = require('../../src/config/db');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runInventoryTests() {
  console.log('====================================================');
  console.log(' Starting M1-W3-02 Inventory APIs Integration Tests');
  console.log('====================================================');

  // Step 1: Ensure database schema is applied
  console.log('\n[1/12] Initializing database schema and seeds...');
  await applySchema();
  await seedUsers({ seedPharmacist: true });

  // Step 2: Log in as admin and pharmacist
  console.log('\n[2/12] Authenticating Admin and Pharmacist...');
  const adminLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: 'admin', password: 'Admin@Medix123' });
  assert.strictEqual(adminLogin.statusCode, 200);
  const adminToken = adminLogin.body.data.token;

  const pharmLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: 'pharmacist1', password: 'Pharm@Medix123' });
  assert.strictEqual(pharmLogin.statusCode, 200);
  const pharmToken = pharmLogin.body.data.token;
  console.log('       Tokens acquired successfully.');

  // Step 3: Pharmacist blocked from creating categories
  console.log('\n[3/12] Testing Pharmacist blocked from category creation (403)...');
  const pharmCatBlock = await request(app)
    .post('/api/categories')
    .set('Authorization', `Bearer ${pharmToken}`)
    .send({ name: 'Analgesics' });
  assert.strictEqual(pharmCatBlock.statusCode, 403);
  assert.strictEqual(pharmCatBlock.body.error.code, 'AUTH_FORBIDDEN_ROLE');
  console.log('       Passed: Pharmacist blocked with 403 AUTH_FORBIDDEN_ROLE.');

  // Step 4: Admin creates a valid category
  console.log('\n[4/12] Testing Admin creating valid category (201)...');
  const catName = `Category_${Date.now()}`;
  const catCreateRes = await request(app)
    .post('/api/categories')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ name: catName, description: 'General therapeutic category' });
  assert.strictEqual(catCreateRes.statusCode, 201);
  assert.strictEqual(catCreateRes.body.success, true);
  assert.strictEqual(catCreateRes.body.data.name, catName);
  const categoryId = catCreateRes.body.data.id;
  console.log(`       Passed: Category '${catName}' created with ID ${categoryId}.`);

  // Step 5: Duplicate category name returns 409 DUPLICATE_ENTRY
  console.log('\n[5/12] Testing duplicate category rejection (409)...');
  const dupCatRes = await request(app)
    .post('/api/categories')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ name: catName });
  assert.strictEqual(dupCatRes.statusCode, 409);
  assert.strictEqual(dupCatRes.body.error.code, 'DUPLICATE_ENTRY');
  console.log('       Passed: Duplicate category rejected with 409 DUPLICATE_ENTRY.');

  // Step 6: Pharmacist can list categories
  console.log('\n[6/12] Testing Pharmacist reading category list (200)...');
  const listCatRes = await request(app)
    .get('/api/categories')
    .set('Authorization', `Bearer ${pharmToken}`);
  assert.strictEqual(listCatRes.statusCode, 200);
  assert.strictEqual(listCatRes.body.success, true);
  assert.ok(Array.isArray(listCatRes.body.data));
  assert.ok(listCatRes.body.data.some((c) => c.id === categoryId));
  console.log('       Passed: Pharmacist listed categories successfully.');

  // Step 7: Medicine validation on non-existent category
  console.log('\n[7/12] Testing medicine creation with invalid category...');
  const invalidCatMedRes = await request(app)
    .post('/api/medicines')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      category_id: 999999,
      name: 'NonExistentMed',
      selling_price: 15.00
    });
  assert.strictEqual(invalidCatMedRes.statusCode, 400);
  assert.strictEqual(invalidCatMedRes.body.error.code, 'VALIDATION_ERROR');
  console.log('       Passed: Invalid category rejected with 400 VALIDATION_ERROR.');

  // Step 8: Admin creates a valid medicine
  console.log('\n[8/12] Testing Admin creating valid medicine (201)...');
  const medName = `Paracetamol_${Date.now()}`;
  const medCreateRes = await request(app)
    .post('/api/medicines')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      category_id: categoryId,
      name: medName,
      generic_name: 'Acetaminophen',
      brand: 'Panadol',
      dosage_form: 'Tablet',
      strength: '500mg',
      selling_price: 12.50,
      cost_price: 8.00,
      reorder_level: 25
    });
  assert.strictEqual(medCreateRes.statusCode, 201);
  assert.strictEqual(medCreateRes.body.success, true);
  assert.strictEqual(medCreateRes.body.data.name, medName);
  const medicineId = medCreateRes.body.data.id;
  console.log(`       Passed: Medicine '${medName}' created with ID ${medicineId}.`);

  // Step 9: Duplicate medicine (name + strength) returns 409
  console.log('\n[9/12] Testing duplicate medicine rejection (409)...');
  const dupMedRes = await request(app)
    .post('/api/medicines')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      category_id: categoryId,
      name: medName,
      strength: '500mg',
      selling_price: 12.50
    });
  assert.strictEqual(dupMedRes.statusCode, 409);
  assert.strictEqual(dupMedRes.body.error.code, 'DUPLICATE_ENTRY');
  console.log('       Passed: Duplicate medicine rejected with 409 DUPLICATE_ENTRY.');

  // Step 10: Pharmacist searches medicines with pagination
  console.log('\n[10/12] Testing Pharmacist search and pagination (200)...');
  const searchMedRes = await request(app)
    .get(`/api/medicines?search=${medName}&category_id=${categoryId}&page=1&limit=10`)
    .set('Authorization', `Bearer ${pharmToken}`);
  assert.strictEqual(searchMedRes.statusCode, 200);
  assert.strictEqual(searchMedRes.body.success, true);
  assert.strictEqual(searchMedRes.body.data.length, 1);
  assert.strictEqual(searchMedRes.body.data[0].id, medicineId);
  assert.strictEqual(searchMedRes.body.data[0].category_name, catName);
  assert.strictEqual(searchMedRes.body.meta.page, 1);
  assert.strictEqual(searchMedRes.body.meta.totalRecords, 1);
  console.log('       Passed: Pharmacist searched medicine with joined category name and pagination metadata.');

  // Step 11: Admin updates medicine details
  console.log('\n[11/12] Testing Admin updating medicine details (200)...');
  const updateMedRes = await request(app)
    .put(`/api/medicines/${medicineId}`)
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      selling_price: 14.00,
      reorder_level: 30
    });
  assert.strictEqual(updateMedRes.statusCode, 200);
  assert.strictEqual(parseFloat(updateMedRes.body.data.selling_price), 14.00);
  assert.strictEqual(parseInt(updateMedRes.body.data.reorder_level, 10), 30);
  console.log('       Passed: Medicine updated successfully.');

  // Step 12: Admin safely soft-deactivates medicine (never deleted)
  console.log('\n[12/12] Testing safe medicine soft-deactivation (PATCH)...');
  const deactRes = await request(app)
    .patch(`/api/medicines/${medicineId}/deactivate`)
    .set('Authorization', `Bearer ${adminToken}`);
  assert.strictEqual(deactRes.statusCode, 200);
  assert.strictEqual(deactRes.body.data.medicine.is_active, false);

  // Verify default active list no longer includes deactivated medicine
  const activeListRes = await request(app)
    .get(`/api/medicines?search=${medName}`)
    .set('Authorization', `Bearer ${pharmToken}`);
  assert.strictEqual(activeListRes.body.data.length, 0);

  // Verify row still exists in database (preserves historical references)
  const dbCheck = await db.query('SELECT id, name, is_active FROM medicines WHERE id = $1', [medicineId]);
  assert.strictEqual(dbCheck.rows.length, 1);
  assert.strictEqual(dbCheck.rows[0].is_active, false);
  console.log('       Passed: Medicine soft-deactivated; preserved in database for sales history.');

  console.log('\n====================================================');
  console.log(' All M1-W3-02 Inventory API tests passed successfully!');
  console.log('====================================================');
}

runInventoryTests()
  .then(async () => {
    await db.closePool();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error('\n[TEST FAILED]', err);
    await db.closePool();
    process.exit(1);
  });

