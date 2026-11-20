/**
 * Expiry Alert Background Cron Job.
 * Schedules daily calculation of 7-month return windows and expired stock.
 * 
 * Features:
 * - Daily scheduled execution at 06:00 (Asia/Colombo timezone)
 * - Automatic startup catch-up execution to handle host downtime during scheduled hours
 * - Concurrency execution lock to prevent overlapping runs
 * - Structured audit logging (records checked, alerts created, execution time, errors)
 */
const cron = require('node-cron');
const alertService = require('../services/alert.service');
const config = require('../config/environment');

let isRunning = false;
let cronTask = null;
let lastRunTime = null;
let lastRunStats = null;
let lastRunStatus = 'idle';

/**
 * Execute the expiry check run with execution lock.
 * @param {string} [triggerSource='cron'] - Source of trigger ('cron', 'startup_catchup', 'manual')
 * @returns {Promise<object>} Execution summary
 */
const executeExpiryCheck = async (triggerSource = 'cron') => {
  if (isRunning) {
    console.warn(`[JOB:EXPIRY] Execution skipped (${triggerSource}): An expiry check run is already active.`);
    return { skipped: true, reason: 'CONCURRENCY_LOCK' };
  }

  isRunning = true;
  lastRunStatus = 'running';
  const startTime = Date.now();
  console.log(`[JOB:EXPIRY] Starting automated expiry check (Trigger: ${triggerSource}, Window: ${config.business.expiryWindowMonths}M, Timezone: ${config.business.timezone})...`);

  try {
    const stats = await alertService.generateExpiryAlerts(config.business.expiryWindowMonths);
    const durationMs = Date.now() - startTime;

    lastRunTime = new Date().toISOString();
    lastRunStats = stats;
    lastRunStatus = 'success';

    console.log(`[JOB:EXPIRY] Expiry check completed in ${durationMs}ms:`);
    console.log(`            - Expired alerts created: ${stats.expired_alerts_created}`);
    console.log(`            - Near-expiry warnings created: ${stats.warning_alerts_created}`);
    console.log(`            - Depleted/graduated alerts auto-resolved: ${stats.alerts_auto_resolved}`);

    return {
      success: true,
      triggerSource,
      stats,
      durationMs,
      completedAt: lastRunTime
    };
  } catch (err) {
    const durationMs = Date.now() - startTime;
    lastRunStatus = 'failed';
    console.error(`[JOB:EXPIRY ERROR] Failed during expiry check (${durationMs}ms):`, err.message);

    return {
      success: false,
      triggerSource,
      error: err.message,
      durationMs
    };
  } finally {
    isRunning = false;
  }
};

/**
 * Start the scheduled cron job and optionally run startup catch-up.
 * @param {object} [options]
 * @param {string} [options.cronExpression] - Custom cron expression
 * @param {boolean} [options.runOnStartup] - Whether to fire catch-up run immediately
 */
const start = (options = {}) => {
  const cronExpression = options.cronExpression || (config.jobs && config.jobs.expiryCron) || '0 6 * * *';
  const runOnStartup = options.runOnStartup !== undefined 
    ? options.runOnStartup 
    : (config.jobs ? config.jobs.runExpiryOnStartup : true);

  if (cronTask) {
    console.warn('[JOB:EXPIRY] Job is already scheduled.');
    return cronTask;
  }

  if (!cron.validate(cronExpression)) {
    console.error(`[JOB:EXPIRY ERROR] Invalid cron expression: '${cronExpression}'. Job not scheduled.`);
    return null;
  }

  cronTask = cron.schedule(
    cronExpression,
    () => {
      executeExpiryCheck('cron');
    },
    {
      scheduled: true,
      timezone: config.business.timezone
    }
  );

  console.log(`[JOB:EXPIRY] Scheduled daily background check with pattern '${cronExpression}' (${config.business.timezone}).`);

  // Catch-up check on server startup to handle downtime during scheduled 06:00 window
  if (runOnStartup) {
    setImmediate(() => {
      executeExpiryCheck('startup_catchup');
    });
  }

  return cronTask;
};

/**
 * Stop the scheduled cron job cleanly.
 */
const stop = () => {
  if (cronTask) {
    cronTask.stop();
    cronTask = null;
    console.log('[JOB:EXPIRY] Cron job stopped.');
  }
};

/**
 * Trigger an immediate manual run.
 */
const triggerNow = () => {
  return executeExpiryCheck('manual');
};

/**
 * Get current scheduler status.
 */
const getStatus = () => {
  return {
    isScheduled: Boolean(cronTask),
    isRunning,
    cronExpression: config.jobs ? config.jobs.expiryCron : '0 6 * * *',
    timezone: config.business.timezone,
    expiryWindowMonths: config.business.expiryWindowMonths,
    lastRunTime,
    lastRunStatus,
    lastRunStats
  };
};

module.exports = {
  start,
  stop,
  triggerNow,
  getStatus,
  executeExpiryCheck
};

