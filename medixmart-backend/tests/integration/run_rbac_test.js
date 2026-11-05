/**
 * Route Protection & Role-Based Access Control (RBAC) Integration Tests.
 * Verifies M1-W2-02 requirements.
 */
const request = require('supertest');
const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('../../src/app');
const db = require('../../src/config/db');
const config = require('../../src/config/environment');

async function runRBACTests() {
  console.log('====================================================');
  console.log(' Starting M1-W2-02 Route Protection & RBAC Tests');
  console.log('====================================================');

  // Step 1: Login as admin to obtain valid admin token
  console.log('\n[1/10] Obtaining valid Admin token...');
  const adminLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: 'admin', password: 'Admin@Medix123' });
  assert.strictEqual(adminLogin.statusCode, 200);
  const adminToken = adminLogin.body.data.token;
  console.log('       Admin token acquired.');

  // Step 2: Login as pharmacist to obtain valid pharmacist token
  console.log('\n[2/10] Obtaining valid Pharmacist token...');
  const pharmLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: 'pharmacist1', password: 'Pharm@Medix123' });
  assert.strictEqual(pharmLogin.statusCode, 200);
  const pharmToken = pharmLogin.body.data.token;
  console.log('       Pharmacist token acquired.');

  // Step 3: Unauthenticated request (no Authorization header)
  console.log('\n[3/10] Testing missing token on protected endpoint...');
  const missingRes = await request(app).get('/api/auth/me');
  assert.strictEqual(missingRes.statusCode, 401);
  assert.strictEqual(missingRes.body.success, false);
  assert.strictEqual(missingRes.body.error.code, 'AUTH_MISSING_TOKEN');
  console.log('       Passed: Missing token rejected with 401 AUTH_MISSING_TOKEN.');

  // Step 4: Malformed Authorization header
  console.log('\n[4/10] Testing malformed Authorization header...');
  const malformedRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', 'Basic invalidcredentials');
  assert.strictEqual(malformedRes.statusCode, 401);
  assert.strictEqual(malformedRes.body.success, false);
  assert.strictEqual(malformedRes.body.error.code, 'AUTH_INVALID_TOKEN');
  console.log('       Passed: Malformed header rejected with 401 AUTH_INVALID_TOKEN.');

  // Step 5: Invalid/tampered JWT signature
  console.log('\n[5/10] Testing tampered JWT signature...');
  const tamperedRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${adminToken}tampered`);
  assert.strictEqual(tamperedRes.statusCode, 401);
  assert.strictEqual(tamperedRes.body.success, false);
  assert.strictEqual(tamperedRes.body.error.code, 'AUTH_INVALID_TOKEN');
  console.log('       Passed: Tampered token rejected with 401 AUTH_INVALID_TOKEN.');

  // Step 6: Expired JWT token
  console.log('\n[6/10] Testing expired JWT token...');
  const expiredToken = jwt.sign(
    { sub: 1, username: 'admin', role: 'admin' },
    config.jwt.secret,
    { expiresIn: '0s' }
  );
  const expiredRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${expiredToken}`);
  assert.strictEqual(expiredRes.statusCode, 401);
  assert.strictEqual(expiredRes.body.success, false);
  assert.strictEqual(expiredRes.body.error.code, 'AUTH_EXPIRED_TOKEN');
  console.log('       Passed: Expired token rejected with 401 AUTH_EXPIRED_TOKEN.');

  // Step 7: Valid profile check via GET /api/auth/me
  console.log('\n[7/10] Testing profile retrieval with valid token...');
  const profileRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.strictEqual(profileRes.statusCode, 200);
  assert.strictEqual(profileRes.body.success, true);
  assert.strictEqual(profileRes.body.data.user.username, 'admin');
  assert.strictEqual(profileRes.body.data.user.role, 'admin');
  console.log('       Passed: Valid token retrieved user profile successfully.');

  // Step 8: Pharmacist blocked from admin-only endpoint
  console.log('\n[8/10] Testing Pharmacist blocked from admin-only route...');
  const pharmBlockedRes = await request(app)
    .get('/api/auth/admin-only')
    .set('Authorization', `Bearer ${pharmToken}`);
  assert.strictEqual(pharmBlockedRes.statusCode, 403);
  assert.strictEqual(pharmBlockedRes.body.success, false);
  assert.strictEqual(pharmBlockedRes.body.error.code, 'AUTH_FORBIDDEN_ROLE');
  console.log('       Passed: Pharmacist blocked from admin-only with 403 AUTH_FORBIDDEN_ROLE.');

  // Step 9: Admin allowed on admin-only endpoint
  console.log('\n[9/10] Testing Admin allowed on admin-only route...');
  const adminAllowedRes = await request(app)
    .get('/api/auth/admin-only')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.strictEqual(adminAllowedRes.statusCode, 200);
  assert.strictEqual(adminAllowedRes.body.success, true);
  assert.strictEqual(adminAllowedRes.body.data.message, 'Admin access granted.');
  console.log('       Passed: Admin access granted on admin-only route.');

  // Step 10: Both roles allowed on staff-only endpoint
  console.log('\n[10/11] Testing both roles on staff-only route...');
  const pharmStaffRes = await request(app)
    .get('/api/auth/staff-only')
    .set('Authorization', `Bearer ${pharmToken}`);
  assert.strictEqual(pharmStaffRes.statusCode, 200);
  assert.strictEqual(pharmStaffRes.body.data.message, 'Staff access granted.');

  const adminStaffRes = await request(app)
    .get('/api/auth/staff-only')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.strictEqual(adminStaffRes.statusCode, 200);
  assert.strictEqual(adminStaffRes.body.data.message, 'Staff access granted.');
  console.log('       Passed: Both Pharmacist and Admin granted access to staff-only route.');

  // Step 11: Test logout endpoint
  console.log('\n[11/11] Testing POST /api/auth/logout...');
  const unauthLogout = await request(app).post('/api/auth/logout');
  assert.strictEqual(unauthLogout.statusCode, 401, 'Unauthenticated logout should return 401');

  const authLogout = await request(app)
    .post('/api/auth/logout')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.strictEqual(authLogout.statusCode, 200, 'Authenticated logout should return 200');
  assert.strictEqual(authLogout.body.success, true);
  assert.strictEqual(authLogout.body.data.message, 'Successfully logged out.');
  console.log('       Passed: POST /api/auth/logout authenticated and verified.');

  console.log('\n====================================================');
  console.log(' All M1-W2-02 & M1-W2-03 tests passed successfully!');
  console.log('====================================================');
}

runRBACTests()
  .then(async () => {
    await db.closePool();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error('\n[TEST FAILED]', err);
    await db.closePool();
    process.exit(1);
  });

