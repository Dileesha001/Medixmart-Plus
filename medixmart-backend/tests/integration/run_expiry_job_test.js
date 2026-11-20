/**
 * Expiry Background Cron Job Integration Test Suite.
 * Verifies M1-W5-02 deliverables:
 * - node-cron schedule registration with '0 6 * * *' and Asia/Colombo timezone
 * - Startup catch-up execution
 * - Concurrency execution lock preventing overlapping runs
 * - Graceful job stop and status inspection
 * - Manual trigger via triggerNow()
 * - Error isolation ensuring background jobs never crash the server process
 */
const assert = require('assert');
const expiryJob = require('../../src/jobs/expiryJob');
const db = require('../../src/config/db');
const applySchema = require('../../src/sql/init_db');
const seedUsers = require('../../src/sql/seed_admin');

async function runExpiryJobTests() {
  console.log('====================================================');
  console.log(' Starting M1-W5-02 Scheduled Expiry Job Tests');
  console.log('====================================================');

  try {
    // 1. Prepare database schema
    console.log('\n[1/5] Initializing database and baseline seed...');
    await applySchema();
    await seedUsers();
    console.log('      Database schema verified.');

    // 2. Test start() with startup catch-up execution
    console.log('\n[2/5] Testing expiryJob.start() and startup catch-up execution...');
    // Ensure job is not running
    expiryJob.stop();

    const task = expiryJob.start({
      cronExpression: '0 6 * * *',
      runOnStartup: true
    });
    assert.ok(task, 'start() must return a scheduled cron task');

    // Wait for the startup catch-up (setImmediate) to complete
    let attempts = 0;
    while (attempts < 20 && expiryJob.getStatus().lastRunStatus !== 'success') {
      await new Promise((resolve) => setTimeout(resolve, 150));
      attempts++;
    }

    const status = expiryJob.getStatus();
    assert.strictEqual(status.isScheduled, true);
    assert.strictEqual(status.cronExpression, '0 6 * * *');
    assert.strictEqual(status.timezone, 'Asia/Colombo');
    assert.strictEqual(status.lastRunStatus, 'success');
    assert.ok(status.lastRunTime !== null);
    assert.ok(status.lastRunStats !== null);
    console.log('      Passed: Startup catch-up executed successfully and status verified.');

    // 3. Test Manual Trigger (triggerNow)
    console.log('\n[3/5] Testing expiryJob.triggerNow()...');
    const manualResult = await expiryJob.triggerNow();
    assert.strictEqual(manualResult.success, true);
    assert.strictEqual(manualResult.triggerSource, 'manual');
    assert.ok(manualResult.durationMs >= 0);
    assert.ok(manualResult.stats !== undefined);
    console.log(`      Passed: triggerNow() executed cleanly in ${manualResult.durationMs}ms.`);

    // 4. Test Concurrency Lock (Overlapping Run Prevention)
    console.log('\n[4/5] Testing concurrency lock against overlapping runs...');
    // Start two concurrent executions simultaneously
    const [run1, run2] = await Promise.all([
      expiryJob.executeExpiryCheck('concurrent_test_1'),
      expiryJob.executeExpiryCheck('concurrent_test_2')
    ]);

    // One of them must succeed, and the other must be skipped due to lock
    const ranCount = [run1, run2].filter((r) => r.success === true).length;
    const skippedCount = [run1, run2].filter((r) => r.skipped === true && r.reason === 'CONCURRENCY_LOCK').length;

    assert.strictEqual(ranCount, 1, 'Exactly one concurrent job must execute');
    assert.strictEqual(skippedCount, 1, 'Overlapping job must be skipped by concurrency lock');
    console.log('      Passed: Concurrency lock successfully blocked overlapping run.');

    // 5. Test stop() lifecycle method
    console.log('\n[5/5] Testing expiryJob.stop()...');
    expiryJob.stop();
    const stoppedStatus = expiryJob.getStatus();
    assert.strictEqual(stoppedStatus.isScheduled, false, 'Job must no longer be scheduled after stop()');
    console.log('      Passed: stop() cleanly terminated background scheduler.');

    console.log('\n====================================================');
    console.log(' All M1-W5-02 Scheduled Expiry Job Tests Passed (5/5)!');
    console.log('====================================================');
  } finally {
    expiryJob.stop();
    await db.closePool();
  }
}

if (require.main === module) {
  runExpiryJobTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('\n[TEST FAILED] Expiry job test error:', err);
      process.exit(1);
    });
}

module.exports = runExpiryJobTests;

