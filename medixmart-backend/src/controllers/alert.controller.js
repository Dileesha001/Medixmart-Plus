/**
 * Alert Controller.
 * Exposes endpoints for alert feeds, dashboard summaries, resolution,
 * and on-demand expiry calculation runs.
 */
const alertService = require('../services/alert.service');
const { successResponse, paginatedResponse } = require('../utils/response');
const { ValidationError } = require('../utils/errors');

/**
 * List alerts with optional filters and pagination.
 * GET /api/alerts
 */
const listAlerts = async (req, res) => {
  const {
    is_resolved,
    alert_type,
    severity,
    page = 1,
    limit = 20
  } = req.query;

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const offset = (pageNum - 1) * limitNum;

  const resolvedFilter = is_resolved !== undefined ? is_resolved === 'true' : false;

  const { alerts, total } = await alertService.getAlerts({
    is_resolved: resolvedFilter,
    alert_type,
    severity,
    limit: limitNum,
    offset
  });

  return paginatedResponse(res, alerts, {
    page: pageNum,
    limit: limitNum,
    total,
    totalPages: Math.ceil(total / limitNum),
    hasNext: offset + limitNum < total,
    hasPrev: pageNum > 1
  });
};

/**
 * Get active alerts summary for dashboard counters.
 * GET /api/alerts/summary
 */
const getAlertSummary = async (req, res) => {
  const summary = await alertService.getAlertSummary();
  return successResponse(res, summary, {}, 200);
};

/**
 * Resolve an active alert.
 * PATCH /api/alerts/:id/resolve
 */
const resolveAlert = async (req, res) => {
  const alertId = parseInt(req.params.id, 10);
  if (isNaN(alertId)) {
    throw new ValidationError('Invalid alert ID parameter.');
  }

  const updatedAlert = await alertService.resolveAlert(alertId);
  return successResponse(res, {
    message: 'Alert marked as resolved.',
    alert: updatedAlert
  }, {}, 200);
};

/**
 * Trigger the expiry alert engine on-demand.
 * POST /api/alerts/generate-expiry
 * Admin only.
 */
const runExpiryEngine = async (req, res) => {
  const { months_ahead } = req.body;
  const parsedMonths = months_ahead !== undefined ? parseInt(months_ahead, 10) : undefined;

  if (parsedMonths !== undefined && (isNaN(parsedMonths) || parsedMonths <= 0)) {
    throw new ValidationError('months_ahead must be a positive integer.');
  }

  const result = await alertService.generateExpiryAlerts(parsedMonths);

  return successResponse(res, {
    message: 'Expiry alert engine executed successfully.',
    stats: {
      expired_alerts_created: result.expired_alerts_created,
      warning_alerts_created: result.warning_alerts_created,
      alerts_auto_resolved: result.alerts_auto_resolved
    }
  }, {}, 200);
};

module.exports = {
  listAlerts,
  getAlertSummary,
  resolveAlert,
  runExpiryEngine
};

