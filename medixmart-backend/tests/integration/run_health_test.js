const request = require('supertest');
const app = require('../../src/app');
const db = require('../../src/config/db');
const assert = require('assert');

async function run() {
  console.log('[TEST] Executing GET /api/health test...');
  const res = await request(app).get('/api/health');
  
  console.log(`[TEST] Status Code: ${res.statusCode}`);
  console.log('[TEST] Response Body:', JSON.stringify(res.body, null, 2));

  assert.ok(res.body.success === true, 'Response success should be true');
  assert.ok(typeof res.body.status === 'string', 'Status should be a string');
  assert.ok(typeof res.body.uptimeSeconds === 'number', 'Uptime should be a number');
  assert.ok(res.body.database && typeof res.body.database.connected === 'boolean', 'Database status must be reported');
  
  console.log('[TEST] Executing 404 handler test...');
  const res404 = await request(app).get('/api/unknown-endpoint');
  assert.strictEqual(res404.statusCode, 404, 'Status should be 404');
  assert.strictEqual(res404.body.success, false, 'Success should be false');
  assert.strictEqual(res404.body.error.code, 'ROUTE_NOT_FOUND', 'Code should be ROUTE_NOT_FOUND');

  console.log('[TEST] All assertions passed successfully!');
  await db.closePool();
  process.exit(0);
}

run().catch(async (err) => {
  console.error('[TEST FAILED]', err);
  await db.closePool();
  process.exit(1);
});

