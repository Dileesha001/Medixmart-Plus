/**
 * Authentication & Login Integration Test Suite.
 * Verifies schema creation, admin seeding, and POST /api/auth/login behavior.
 */
const request = require('supertest');
const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('../../src/app');
const db = require('../../src/config/db');
const config = require('../../src/config/environment');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runAuthTests() {
  console.log('====================================================');
  console.log(' Starting M1-W2-01 Authentication & Login Tests');
  console.log('====================================================');

  // Step 1: Apply users table schema
  console.log('\n[1/7] Applying users table schema...');
  await applySchema();

  // Step 2: Seed admin and test accounts
  console.log('\n[2/7] Seeding administrator and test accounts...');
  await seedUsers({ seedPharmacist: true });

  // Create an explicitly disabled account for testing 403 status
  const bcrypt = require('bcrypt');
  const disabledHash = await bcrypt.hash('Disabled@123', 10);
  await db.query(
    `INSERT INTO users (username, password_hash, role, is_active)
     VALUES ('disabled_user', $1, 'pharmacist', FALSE)
     ON CONFLICT (username) DO UPDATE SET is_active = FALSE`,
    [disabledHash]
  );
  console.log('      Created/verified test disabled_user.');

  // Step 3: Test validation error on empty fields
  console.log('\n[3/7] Testing validation errors on empty fields...');
  const emptyRes = await request(app)
    .post('/api/auth/login')
    .send({});
  assert.strictEqual(emptyRes.statusCode, 400, 'Empty body should return 400');
  assert.strictEqual(emptyRes.body.success, false);
  assert.strictEqual(emptyRes.body.error.code, 'VALIDATION_ERROR');
  console.log('      Passed: empty body rejected with 400 and VALIDATION_ERROR.');

  // Step 4: Test non-existent user
  console.log('\n[4/7] Testing non-existent user...');
  const notFoundRes = await request(app)
    .post('/api/auth/login')
    .send({ username: 'non_existent_user_999', password: 'Password123!' });
  assert.strictEqual(notFoundRes.statusCode, 401, 'Unknown user should return 401');
  assert.strictEqual(notFoundRes.body.success, false);
  assert.strictEqual(notFoundRes.body.error.code, 'AUTH_INVALID_CREDENTIALS');
  console.log('      Passed: unknown user rejected with 401 and AUTH_INVALID_CREDENTIALS.');

  // Step 5: Test wrong password for valid user
  console.log('\n[5/7] Testing wrong password for valid user...');
  const wrongPassRes = await request(app)
    .post('/api/auth/login')
    .send({ username: 'admin', password: 'IncorrectPassword!123' });
  assert.strictEqual(wrongPassRes.statusCode, 401, 'Wrong password should return 401');
  assert.strictEqual(wrongPassRes.body.success, false);
  assert.strictEqual(wrongPassRes.body.error.code, 'AUTH_INVALID_CREDENTIALS');
  console.log('      Passed: wrong password rejected with 401 and AUTH_INVALID_CREDENTIALS.');

  // Step 6: Test disabled user
  console.log('\n[6/7] Testing disabled user...');
  const disabledRes = await request(app)
    .post('/api/auth/login')
    .send({ username: 'disabled_user', password: 'Disabled@123' });
  assert.strictEqual(disabledRes.statusCode, 403, 'Disabled user should return 403');
  assert.strictEqual(disabledRes.body.success, false);
  assert.strictEqual(disabledRes.body.error.code, 'AUTH_ACCOUNT_DISABLED');
  console.log('      Passed: disabled user rejected with 403 and AUTH_ACCOUNT_DISABLED.');

  // Step 7: Test valid login for admin
  console.log('\n[7/7] Testing valid admin login...');
  const validRes = await request(app)
    .post('/api/auth/login')
    .send({ username: 'admin', password: 'Admin@Medix123' });
  assert.strictEqual(validRes.statusCode, 200, 'Valid login should return 200');
  assert.strictEqual(validRes.body.success, true);
  assert.ok(validRes.body.data.token, 'Token must be present in response');
  assert.strictEqual(validRes.body.data.user.username, 'admin');
  assert.strictEqual(validRes.body.data.user.role, 'admin');

  // Verify JWT signature and claims
  const decoded = jwt.verify(validRes.body.data.token, config.jwt.secret);
  assert.strictEqual(decoded.username, 'admin');
  assert.strictEqual(decoded.role, 'admin');
  assert.ok(decoded.exp, 'Expiration claim must exist');
  console.log('      Passed: valid admin login issued valid JWT with role claim.');

  console.log('\n====================================================');
  console.log(' All M1-W2-01 tests passed successfully!');
  console.log('====================================================');
}

runAuthTests()
  .then(async () => {
    await db.closePool();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error('\n[TEST FAILED]', err);
    await db.closePool();
    process.exit(1);
  });

