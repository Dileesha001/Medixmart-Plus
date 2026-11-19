/**
 * Client/Server Connectivity & Cross-Device Access Integration Test Suite.
 * Verifies M1-W4-01 deliverables:
 * - Express binding to 0.0.0.0 (all interfaces)
 * - Multi-device and cross-origin CORS support (Flutter Web, Emulators, LAN subnets)
 * - Helmet Cross-Origin Resource Policy (cross-origin)
 * - Live loopback and real LAN IP HTTP connectivity
 */
const http = require('http');
const os = require('os');
const request = require('supertest');
const assert = require('assert');
const app = require('../../src/app');
const db = require('../../src/config/db');

async function runConnectivityTests() {
  console.log('====================================================');
  console.log(' Starting M1-W4-01 Client/Server Connectivity Tests');
  console.log('====================================================');

  try {
    // 1. Loopback health endpoint check
    console.log('\n[1/6] Testing local loopback /api/health...');
    const healthRes = await request(app).get('/api/health');
    assert.strictEqual(healthRes.statusCode, 200);
    assert.strictEqual(healthRes.body.success, true);
    assert.strictEqual(healthRes.body.status, 'healthy');
    console.log('      Passed: /api/health returns 200 healthy.');

    // 2. Helmet CORP header check
    console.log('\n[2/6] Verifying Cross-Origin-Resource-Policy header...');
    const corpHeader = healthRes.headers['cross-origin-resource-policy'];
    assert.strictEqual(corpHeader, 'cross-origin', 'CORP must be set to cross-origin for client assets');
    console.log('      Passed: Cross-Origin-Resource-Policy is "cross-origin".');

    // 3. Preflight OPTIONS check for Flutter Web (localhost dev port)
    console.log('\n[3/6] Testing CORS preflight for Flutter Web (localhost:55000)...');
    const flutterWebRes = await request(app)
      .options('/api/health')
      .set('Origin', 'http://localhost:55000')
      .set('Access-Control-Request-Method', 'GET');

    assert.ok([200, 204].includes(flutterWebRes.statusCode), `Preflight must return 200 or 204 (got ${flutterWebRes.statusCode})`);
    assert.strictEqual(
      flutterWebRes.headers['access-control-allow-origin'],
      'http://localhost:55000',
      'CORS must allow localhost origin'
    );
    console.log('      Passed: Flutter Web preflight allowed with matching origin.');

    // 4. Preflight OPTIONS check for LAN mobile client (192.168.x.x / 172.x.x.x)
    console.log('\n[4/6] Testing CORS preflight for LAN mobile client (192.168.1.105:8080)...');
    const lanRes = await request(app)
      .options('/api/medicines')
      .set('Origin', 'http://192.168.1.105:8080')
      .set('Access-Control-Request-Method', 'GET');

    assert.ok([200, 204].includes(lanRes.statusCode));
    assert.strictEqual(
      lanRes.headers['access-control-allow-origin'],
      'http://192.168.1.105:8080',
      'CORS must allow LAN origin'
    );
    console.log('      Passed: LAN client preflight allowed.');

    // 5. Native mobile request without Origin header (curl / Dio / http)
    console.log('\n[5/6] Testing request with no Origin header (native mobile client)...');
    const noOriginRes = await request(app)
      .get('/api/health');
    assert.strictEqual(noOriginRes.statusCode, 200);
    console.log('      Passed: Native mobile client without Origin header permitted.');

    // 6. Live server binding to 0.0.0.0 and multi-interface reachability
    console.log('\n[6/6] Testing live HTTP server socket binding to 0.0.0.0...');
    const liveServer = http.createServer(app);

    await new Promise((resolve, reject) => {
      liveServer.listen(0, '0.0.0.0', () => resolve());
      liveServer.on('error', reject);
    });

    const assignedPort = liveServer.address().port;
    console.log(`      Live test server bound on 0.0.0.0:${assignedPort}`);

    // Test loopback reachability via http.get
    await new Promise((resolve, reject) => {
      http.get(`http://127.0.0.1:${assignedPort}/api/health`, (res) => {
        assert.strictEqual(res.statusCode, 200);
        res.resume();
        resolve();
      }).on('error', reject);
    });
    console.log(`      Passed: Verified reachability on 127.0.0.1:${assignedPort}`);

    // Discover first available non-internal IPv4 interface
    const interfaces = os.networkInterfaces();
    let externalIp = null;
    let ifaceName = null;

    for (const name of Object.keys(interfaces)) {
      for (const net of interfaces[name]) {
        if (net.family === 'IPv4' && !net.internal) {
          externalIp = net.address;
          ifaceName = name;
          break;
        }
      }
      if (externalIp) break;
    }

    if (externalIp) {
      console.log(`      Testing reachability on active LAN interface (${ifaceName}: ${externalIp}:${assignedPort})...`);
      await new Promise((resolve, reject) => {
        http.get(`http://${externalIp}:${assignedPort}/api/health`, (res) => {
          assert.strictEqual(res.statusCode, 200);
          res.resume();
          resolve();
        }).on('error', reject);
      });
      console.log(`      Passed: Live request to http://${externalIp}:${assignedPort}/api/health returned 200 OK.`);
    } else {
      console.log('      No external IPv4 interface found; skipped LAN probe.');
    }

    // Close live test server
    await new Promise((resolve) => liveServer.close(resolve));
    console.log('      Live test server closed cleanly.');

    console.log('\n====================================================');
    console.log(' All M1-W4-01 Connectivity Tests Passed (6/6)!');
    console.log('====================================================');
  } finally {
    await db.closePool();
  }
}

if (require.main === module) {
  runConnectivityTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Connectivity test error:', err);
      process.exit(1);
    });
}

module.exports = runConnectivityTests;

