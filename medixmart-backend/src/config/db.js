/**
 * PostgreSQL Connection Pool.
 * Manages connections, transactions, and error propagation.
 */
const { Pool } = require('pg');
const config = require('./environment');

const pool = new Pool(config.db);

// Pool error handling (idle client unexpected error)
pool.on('error', (err) => {
  console.error('[DB] Unexpected error on idle client:', err.message);
});

pool.on('connect', () => {
  if (!config.isProduction) {
    // Debug log in development only
    // console.log('[DB] New client connected to PostgreSQL pool');
  }
});

/**
 * Execute a single query using a pooled client.
 * @param {string} text - SQL statement with $1, $2 parameter placeholders
 * @param {Array} params - Array of parameters
 * @returns {Promise<import('pg').QueryResult>}
 */
const query = async (text, params) => {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (!config.isProduction && duration > 100) {
    console.warn(`[DB SLOW QUERY] ${duration}ms: ${text.slice(0, 100)}`);
  }
  return res;
};

/**
 * Acquire a dedicated client from the pool (required for multi-step transactions).
 * Caller MUST call client.release() when done!
 * @returns {Promise<import('pg').PoolClient>}
 */
const getClient = async () => {
  return await pool.connect();
};

/**
 * Verify database connectivity.
 * @returns {Promise<{ ok: boolean, timestamp?: string, error?: string }>}
 */
const testConnection = async () => {
  try {
    const res = await pool.query('SELECT NOW() AS now, current_database() AS db, current_user AS user');
    return {
      ok: true,
      timestamp: res.rows[0].now,
      database: res.rows[0].db,
      user: res.rows[0].user
    };
  } catch (err) {
    return {
      ok: false,
      error: err.message
    };
  }
};

/**
 * Gracefully drain and close the connection pool.
 */
const closePool = async () => {
  await pool.end();
  console.log('[DB] Connection pool closed.');
};

module.exports = {
  pool,
  query,
  getClient,
  testConnection,
  closePool
};

