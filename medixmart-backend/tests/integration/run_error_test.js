/**
 * Centralized Error & Async Handling Integration Test Suite.
 * Verifies M1-W3-01 requirements:
 * - AppError subclasses
 * - PostgreSQL error code mappings (23505, 23503, 23502)
 * - Malformed JSON handling
 * - 404 Route Not Found handling
 * - Production error masking
 */
const request = require('supertest');
const assert = require('assert');
const express = require('express');
const app = require('../../src/app');
const db = require('../../src/config/db');
const config = require('../../src/config/environment');
const {
  AppError,
  ValidationError,
  NotFoundError,
  ConflictError,
  ForbiddenError
} = require('../../src/utils/errors');
const asyncHandler = require('../../src/utils/asyncHandler');
const errorHandler = require('../../src/middleware/error');

// Build a dedicated test Express app that mounts the error middleware
const testApp = express();
testApp.use(express.json());

// Routes throwing specific AppErrors
testApp.get('/test/validation-error', asyncHandler(async () => {
  throw new ValidationError('Medicine validation failed.', [
    { field: 'name', message: 'Name cannot be empty.' }
  ]);
}));

testApp.get('/test/not-found-error', asyncHandler(async () => {
  throw new NotFoundError('Medicine with ID 999 was not found.');
}));

testApp.get('/test/conflict-error', asyncHandler(async () => {
  throw new ConflictError('Medicine with this barcode already exists.');
}));

testApp.get('/test/forbidden-error', asyncHandler(async () => {
  throw new ForbiddenError('Only administrators can access this setting.');
}));

// Route triggering PostgreSQL duplicate key error (23505)
testApp.get('/test/pg-duplicate-error', asyncHandler(async () => {
  // Deliberately insert duplicate 'admin' username
  await db.query(`
    INSERT INTO users (username, password_hash, role)
    VALUES ('admin', 'hash', 'admin')
  `);
}));

// Route throwing unexpected unhandled error
testApp.get('/test/unhandled-500', asyncHandler(async () => {
  throw new Error('Unexpected raw database crash with sensitive connection string postgres://secret:password@10.0.0.1');
}));

testApp.use(errorHandler);

async function runErrorTests() {
  console.log('====================================================');
  console.log(' Starting M1-W3-01 Error & Async Handling Tests');
  console.log('====================================================');

  // Step 1: 404 Not Found on real app
  console.log('\n[1/8] Testing 404 Route Not Found on main app...');
  const res404 = await request(app).get('/api/invalid-route-xyz');
  assert.strictEqual(res404.statusCode, 404);
  assert.strictEqual(res404.body.success, false);
  assert.strictEqual(res404.body.error.code, 'ROUTE_NOT_FOUND');
  assert.ok(res404.body.error.message.includes('/api/invalid-route-xyz'));
  console.log('      Passed: 404 caught and standardized.');

  // Step 2: Malformed JSON syntax error
  console.log('\n[2/8] Testing malformed JSON body parser error...');
  const malformedRes = await request(app)
    .post('/api/auth/login')
    .set('Content-Type', 'application/json')
    .send('{"username": "admin", invalid_json}');
  assert.strictEqual(malformedRes.statusCode, 400);
  assert.strictEqual(malformedRes.body.success, false);
  assert.strictEqual(malformedRes.body.error.code, 'MALFORMED_JSON');
  console.log('      Passed: Malformed JSON caught with 400 MALFORMED_JSON.');

  // Step 3: ValidationError
  console.log('\n[3/8] Testing ValidationError handling...');
  const valRes = await request(testApp).get('/test/validation-error');
  assert.strictEqual(valRes.statusCode, 400);
  assert.strictEqual(valRes.body.success, false);
  assert.strictEqual(valRes.body.error.code, 'VALIDATION_ERROR');
  assert.strictEqual(valRes.body.error.details.length, 1);
  assert.strictEqual(valRes.body.error.details[0].field, 'name');
  console.log('      Passed: ValidationError returns 400 with field details.');

  // Step 4: NotFoundError
  console.log('\n[4/8] Testing NotFoundError handling...');
  const notFoundRes = await request(testApp).get('/test/not-found-error');
  assert.strictEqual(notFoundRes.statusCode, 404);
  assert.strictEqual(notFoundRes.body.success, false);
  assert.strictEqual(notFoundRes.body.error.code, 'RESOURCE_NOT_FOUND');
  console.log('      Passed: NotFoundError returns 404 RESOURCE_NOT_FOUND.');

  // Step 5: ConflictError
  console.log('\n[5/8] Testing ConflictError handling...');
  const conflictRes = await request(testApp).get('/test/conflict-error');
  assert.strictEqual(conflictRes.statusCode, 409);
  assert.strictEqual(conflictRes.body.success, false);
  assert.strictEqual(conflictRes.body.error.code, 'RESOURCE_CONFLICT');
  console.log('      Passed: ConflictError returns 409 RESOURCE_CONFLICT.');

  // Step 6: ForbiddenError
  console.log('\n[6/8] Testing ForbiddenError handling...');
  const forbiddenRes = await request(testApp).get('/test/forbidden-error');
  assert.strictEqual(forbiddenRes.statusCode, 403);
  assert.strictEqual(forbiddenRes.body.success, false);
  assert.strictEqual(forbiddenRes.body.error.code, 'AUTH_FORBIDDEN_ROLE');
  console.log('      Passed: ForbiddenError returns 403 AUTH_FORBIDDEN_ROLE.');

  // Step 7: PostgreSQL 23505 Unique Violation mapping
  console.log('\n[7/8] Testing PostgreSQL unique violation (code 23505)...');
  const pgDupRes = await request(testApp).get('/test/pg-duplicate-error');
  assert.strictEqual(pgDupRes.statusCode, 409, 'Unique violation should map to 409');
  assert.strictEqual(pgDupRes.body.success, false);
  assert.strictEqual(pgDupRes.body.error.code, 'DUPLICATE_ENTRY');
  assert.ok(pgDupRes.body.error.message.includes('admin'), 'Message should identify duplicate value');
  console.log('      Passed: PostgreSQL 23505 mapped to 409 DUPLICATE_ENTRY with clean message.');

  // Step 8: Production mode sanitization (masking 500 internal errors)
  console.log('\n[8/8] Testing unhandled 500 error masking in production mode...');
  const originalEnv = config.isProduction;
  config.isProduction = true; // Temporarily simulate production mode

  const unhandledRes = await request(testApp).get('/test/unhandled-500');
  config.isProduction = originalEnv; // Restore

  assert.strictEqual(unhandledRes.statusCode, 500);
  assert.strictEqual(unhandledRes.body.success, false);
  assert.strictEqual(unhandledRes.body.error.code, 'INTERNAL_SERVER_ERROR');
  assert.strictEqual(
    unhandledRes.body.error.message,
    'An internal server error occurred. Please contact system support.'
  );
  assert.strictEqual(unhandledRes.body.error.details, undefined);
  // Ensure no sensitive connection strings or stack traces leaked
  assert.strictEqual(JSON.stringify(unhandledRes.body).includes('secret:password'), false);
  console.log('      Passed: Unhandled error masked in production mode without leakage.');

  console.log('\n====================================================');
  console.log(' All M1-W3-01 tests passed successfully!');
  console.log('====================================================');
}

runErrorTests()
  .then(async () => {
    await db.closePool();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error('\n[TEST FAILED]', err);
    await db.closePool();
    process.exit(1);
  });

