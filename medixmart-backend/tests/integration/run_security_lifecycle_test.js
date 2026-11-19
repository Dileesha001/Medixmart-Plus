/**
 * Security Lifecycle & Credential Invalidation Integration Test Suite.
 * Verifies M1-W3-03 deliverables:
 * - Password change endpoint PUT /api/auth/change-password
 * - Password strength and confirmation validation
 * - Instant session invalidation via token_version revocation
 * - Administrative self-lockout safeguards on user deactivation and role demotion
 */
const request = require('supertest');
const assert = require('assert');
const bcrypt = require('bcrypt');
const app = require('../../src/app');
const db = require('../../src/config/db');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runSecurityLifecycleTests() {
  console.log('====================================================');
  console.log(' Starting M1-W3-03 Security Lifecycle Test Suite');
  console.log('====================================================');

  try {
    // 1. Initialize schema & seed accounts
    console.log('\n[1/10] Verifying database schema and initial accounts...');
    await applySchema();
    await seedUsers({ seedPharmacist: true });

    // Reset admin password to baseline 'Admin@Medix123' and token_version to 1
    const baselineHash = await bcrypt.hash('Admin@Medix123', 10);
    await db.query(
      `UPDATE users 
       SET password_hash = $1, token_version = 1, is_active = TRUE, role = 'admin' 
       WHERE username = 'admin'`,
      [baselineHash]
    );

    // Clean up any test users from prior runs
    await db.query("DELETE FROM users WHERE username IN ('temp_admin_2', 'temp_pharmacist_test')");

    // 2. Log in as admin and obtain initial token
    console.log('\n[2/10] Authenticating as Admin to obtain baseline session...');
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Admin@Medix123' });

    assert.strictEqual(loginRes.statusCode, 200);
    assert.strictEqual(loginRes.body.success, true);
    const initialToken = loginRes.body.data.token;
    assert.ok(initialToken, 'JWT token must be present');
    console.log('       Admin authenticated successfully with initial token.');

    // Verify initial token works on protected route
    const meRes1 = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${initialToken}`);
    assert.strictEqual(meRes1.statusCode, 200);
    assert.strictEqual(meRes1.body.data.user.username, 'admin');
    console.log('       Initial token verified against GET /api/auth/me.');

    // 3. Test password change validation errors
    console.log('\n[3/10] Testing validation errors on PUT /api/auth/change-password...');
    
    // Missing fields
    const missingRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({ current_password: 'Admin@Medix123' });
    assert.strictEqual(missingRes.statusCode, 400);
    assert.strictEqual(missingRes.body.error.code, 'VALIDATION_ERROR');
    console.log('       Passed: Missing fields rejected with 400 VALIDATION_ERROR.');

    // Short password (< 8 chars)
    const shortRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({
        current_password: 'Admin@Medix123',
        new_password: 'Short1',
        confirm_password: 'Short1'
      });
    assert.strictEqual(shortRes.statusCode, 400);
    assert.strictEqual(shortRes.body.error.code, 'VALIDATION_ERROR');
    console.log('       Passed: Short password (<8 chars) rejected with 400 VALIDATION_ERROR.');

    // Mismatched confirmation
    const mismatchRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({
        current_password: 'Admin@Medix123',
        new_password: 'NewPassword123!',
        confirm_password: 'WrongConfirmation123!'
      });
    assert.strictEqual(mismatchRes.statusCode, 400);
    assert.strictEqual(mismatchRes.body.error.code, 'VALIDATION_ERROR');
    console.log('       Passed: Mismatched confirm_password rejected with 400 VALIDATION_ERROR.');

    // New password identical to current password
    const sameRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({
        current_password: 'Admin@Medix123',
        new_password: 'Admin@Medix123',
        confirm_password: 'Admin@Medix123'
      });
    assert.strictEqual(sameRes.statusCode, 400);
    assert.strictEqual(sameRes.body.error.code, 'VALIDATION_ERROR');
    console.log('       Passed: Identical new password rejected with 400 VALIDATION_ERROR.');

    // 4. Test wrong current password
    console.log('\n[4/10] Testing wrong current password rejection...');
    const wrongCurrentRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({
        current_password: 'IncorrectOldPassword123',
        new_password: 'BrandNewSecurePassword123!',
        confirm_password: 'BrandNewSecurePassword123!'
      });
    assert.strictEqual(wrongCurrentRes.statusCode, 401);
    assert.strictEqual(wrongCurrentRes.body.error.code, 'AUTH_INVALID_CREDENTIALS');
    console.log('       Passed: Incorrect current password rejected with 401 AUTH_INVALID_CREDENTIALS.');

    // 5. Successfully change password
    console.log('\n[5/10] Testing successful password change and new token issuance...');
    const changeSuccessRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${initialToken}`)
      .send({
        current_password: 'Admin@Medix123',
        new_password: 'BrandNewSecurePassword123!',
        confirm_password: 'BrandNewSecurePassword123!'
      });

    assert.strictEqual(changeSuccessRes.statusCode, 200);
    assert.strictEqual(changeSuccessRes.body.success, true);
    const newToken = changeSuccessRes.body.data.token;
    assert.ok(newToken, 'New JWT token must be returned');
    assert.notStrictEqual(newToken, initialToken, 'New token must differ from initial token');
    console.log('       Passed: Password updated successfully and new token issued.');

    // 6. Test session invalidation: Initial token MUST be rejected now!
    console.log('\n[6/10] Testing session invalidation: Prior token must be rejected with 401...');
    const staleRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${initialToken}`);

    assert.strictEqual(staleRes.statusCode, 401, 'Prior token must be rejected after password change');
    assert.strictEqual(staleRes.body.error.code, 'AUTH_SESSION_REVOKED');
    console.log('       Passed: Prior token rejected with 401 AUTH_SESSION_REVOKED.');

    // 7. Test new token works on protected endpoints
    console.log('\n[7/10] Testing that newly minted token functions correctly...');
    const meRes2 = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${newToken}`);
    assert.strictEqual(meRes2.statusCode, 200);
    assert.strictEqual(meRes2.body.data.user.username, 'admin');
    console.log('       Passed: New session token operates normally.');

    // 8. Test credential authentication with new vs old password
    console.log('\n[8/10] Testing login credentials post-rotation...');
    const oldLoginRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Admin@Medix123' });
    assert.strictEqual(oldLoginRes.statusCode, 401);
    assert.strictEqual(oldLoginRes.body.error.code, 'AUTH_INVALID_CREDENTIALS');
    console.log('       Passed: Old password rejected with 401.');

    const newLoginRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'BrandNewSecurePassword123!' });
    assert.strictEqual(newLoginRes.statusCode, 200);
    assert.ok(newLoginRes.body.data.token);
    console.log('       Passed: New password authenticates successfully.');

    // 9. Administrative Self-Lockout Safeguards
    console.log('\n[9/10] Testing Administrative Self-Lockout Safeguards...');
    
    // Attempt to deactivate the only active admin account
    const deactivateRes = await request(app)
      .patch('/api/users/1/status')
      .set('Authorization', `Bearer ${newToken}`)
      .send({ is_active: false });

    assert.strictEqual(deactivateRes.statusCode, 403, 'Last admin deactivation must be blocked');
    assert.strictEqual(deactivateRes.body.error.code, 'AUTH_LAST_ADMIN_PROTECTED');
    console.log('       Passed: Last admin deactivation prevented with 403 AUTH_LAST_ADMIN_PROTECTED.');

    // Attempt to demote the only active admin account
    const demoteRes = await request(app)
      .patch('/api/users/1/role')
      .set('Authorization', `Bearer ${newToken}`)
      .send({ role: 'pharmacist' });

    assert.strictEqual(demoteRes.statusCode, 403, 'Last admin role demotion must be blocked');
    assert.strictEqual(demoteRes.body.error.code, 'AUTH_LAST_ADMIN_PROTECTED');
    console.log('       Passed: Last admin demotion prevented with 403 AUTH_LAST_ADMIN_PROTECTED.');

    // 10. Multi-Admin Deactivation & Immediate Session Termination
    console.log('\n[10/10] Testing secondary admin creation, deactivation, and session termination...');
    
    // Create a secondary admin
    const secondAdminHash = await bcrypt.hash('SecondAdminPass123!', 10);
    const insertRes = await db.query(
      `INSERT INTO users (username, password_hash, role, is_active)
       VALUES ('temp_admin_2', $1, 'admin', TRUE)
       RETURNING id, username`,
      [secondAdminHash]
    );
    const tempAdmin2Id = insertRes.rows[0].id;

    // Login as temp_admin_2
    const admin2Login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'temp_admin_2', password: 'SecondAdminPass123!' });
    assert.strictEqual(admin2Login.statusCode, 200);
    const admin2Token = admin2Login.body.data.token;

    // Now deactivating temp_admin_2 by primary admin SHOULD succeed because 1 active admin still remains!
    const deact2Res = await request(app)
      .patch(`/api/users/${tempAdmin2Id}/status`)
      .set('Authorization', `Bearer ${newToken}`)
      .send({ is_active: false });

    assert.strictEqual(deact2Res.statusCode, 200);
    assert.strictEqual(deact2Res.body.data.user.is_active, false);
    console.log('       Passed: Secondary admin deactivation allowed when another active admin remains.');

    // Verify temp_admin_2's token is immediately revoked
    const admin2MeRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${admin2Token}`);
    assert.strictEqual(admin2MeRes.statusCode, 403);
    assert.strictEqual(admin2MeRes.body.error.code, 'AUTH_ACCOUNT_DISABLED');
    console.log('       Passed: Deactivated user session immediately blocked with 403 AUTH_ACCOUNT_DISABLED.');

    // Cleanup: restore admin password to baseline 'Admin@Medix123'
    console.log('\n[CLEANUP] Restoring admin password and removing test users...');
    await db.query(
      `UPDATE users 
       SET password_hash = $1, token_version = 1, is_active = TRUE, role = 'admin' 
       WHERE username = 'admin'`,
      [baselineHash]
    );
    await db.query("DELETE FROM users WHERE username = 'temp_admin_2'");
    console.log('       Cleanup completed successfully.');

    console.log('\n====================================================');
    console.log(' All M1-W3-03 Security Lifecycle Tests Passed (10/10)!');
    console.log('====================================================');
  } finally {
    await db.closePool();
  }
}

if (require.main === module) {
  runSecurityLifecycleTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Security lifecycle test error:', err);
      process.exit(1);
    });
}

module.exports = runSecurityLifecycleTests;

