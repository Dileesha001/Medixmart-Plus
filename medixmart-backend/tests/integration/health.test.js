/**
 * Health Check API Endpoint Integration Test
 */
const request = require('supertest');
const app = require('../../src/app');

describe('GET /api/health', () => {
  it('should respond with a health status payload', async () => {
    const res = await request(app).get('/api/health');
    
    // Status can be 200 (if DB connected) or 503 (if DB offline/sandboxed)
    expect([200, 503]).toContain(res.statusCode);
    expect(res.body).toHaveProperty('success', true);
    expect(res.body).toHaveProperty('status');
    expect(res.body).toHaveProperty('uptimeSeconds');
    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('database');
    expect(res.body.database).toHaveProperty('connected');
  });

  it('should respond to unknown routes with 404 and structured error envelope', async () => {
    const res = await request(app).get('/api/non-existent-route');
    expect(res.statusCode).toBe(404);
    expect(res.body).toHaveProperty('success', false);
    expect(res.body).toHaveProperty('error');
    expect(res.body.error).toHaveProperty('code', 'ROUTE_NOT_FOUND');
  });
});

