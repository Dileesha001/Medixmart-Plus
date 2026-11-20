/**
 * Alert Management Service.
 * Provides programmatic execution of the expiry calculation engine,
 * alert retrieval, filtering, and resolution.
 */
const db = require('../config/db');
const config = require('../config/environment');
const { NotFoundError } = require('../utils/errors');

/**
 * Execute the stored procedure to generate expiry and return-window alerts.
 * @param {number} [monthsAhead] - Expiry window in months (defaults to config.business.expiryWindowMonths or 7)
 * @returns {Promise<{ expired_alerts_created: number, warning_alerts_created: number, alerts_auto_resolved: number }>}
 */
const generateExpiryAlerts = async (monthsAhead) => {
  const windowMonths = monthsAhead !== undefined ? monthsAhead : (config.business.expiryWindowMonths || 7);
  const query = 'SELECT * FROM generate_expiry_alerts($1)';
  const result = await db.query(query, [windowMonths]);
  return result.rows[0];
};

/**
 * Retrieve active or historical alerts with optional filtering.
 * @param {object} [filters]
 * @param {boolean} [filters.is_resolved=false]
 * @param {string} [filters.alert_type]
 * @param {string} [filters.severity]
 * @param {number} [filters.limit=50]
 * @param {number} [filters.offset=0]
 */
const getAlerts = async (filters = {}) => {
  const {
    is_resolved = false,
    alert_type,
    severity,
    limit = 50,
    offset = 0
  } = filters;

  const conditions = [];
  const params = [];
  let paramIdx = 1;

  if (is_resolved !== undefined && is_resolved !== null) {
    conditions.push(`a.is_resolved = $${paramIdx}`);
    params.push(Boolean(is_resolved));
    paramIdx++;
  }

  if (alert_type) {
    conditions.push(`a.alert_type = $${paramIdx}`);
    params.push(alert_type);
    paramIdx++;
  }

  if (severity) {
    conditions.push(`a.severity = $${paramIdx}`);
    params.push(severity);
    paramIdx++;
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const dataQuery = `
    SELECT 
      a.id,
      a.alert_type,
      a.severity,
      a.title,
      a.message,
      a.reference_table,
      a.reference_id,
      a.is_resolved,
      a.resolved_at,
      a.created_at
    FROM alerts a
    ${whereClause}
    ORDER BY 
      CASE a.severity
        WHEN 'danger' THEN 1
        WHEN 'warning' THEN 2
        WHEN 'info' THEN 3
        ELSE 4
      END,
      a.created_at DESC
    LIMIT $${paramIdx} OFFSET $${paramIdx + 1}
  `;

  params.push(limit, offset);

  const countQuery = `
    SELECT COUNT(*)::int AS total
    FROM alerts a
    ${whereClause}
  `;

  const [dataRes, countRes] = await Promise.all([
    db.query(dataQuery, params),
    db.query(countQuery, params.slice(0, paramIdx - 1))
  ]);

  return {
    alerts: dataRes.rows,
    total: countRes.rows[0].total
  };
};

/**
 * Resolve an active alert by ID.
 * @param {number} alertId
 */
const resolveAlert = async (alertId) => {
  const updateQuery = `
    UPDATE alerts
    SET is_resolved = TRUE,
        resolved_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING id, alert_type, severity, title, is_resolved, resolved_at
  `;
  const result = await db.query(updateQuery, [alertId]);

  if (result.rows.length === 0) {
    throw new NotFoundError(`Alert with ID ${alertId} was not found.`);
  }

  return result.rows[0];
};

/**
 * Get count summary of active alerts for dashboard widgets.
 */
const getAlertSummary = async () => {
  const query = `
    SELECT 
      COUNT(*)::int AS total_active,
      COUNT(*) FILTER (WHERE severity = 'danger')::int AS danger_count,
      COUNT(*) FILTER (WHERE severity = 'warning')::int AS warning_count,
      COUNT(*) FILTER (WHERE severity = 'info')::int AS info_count,
      COUNT(*) FILTER (WHERE alert_type = 'expired')::int AS expired_count,
      COUNT(*) FILTER (WHERE alert_type = 'expiry_warning')::int AS expiring_soon_count,
      COUNT(*) FILTER (WHERE alert_type = 'low_stock')::int AS low_stock_count
    FROM alerts
    WHERE is_resolved = FALSE
  `;
  const result = await db.query(query);
  return result.rows[0];
};

module.exports = {
  generateExpiryAlerts,
  getAlerts,
  resolveAlert,
  getAlertSummary
};

