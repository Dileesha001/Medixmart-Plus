/**
 * Standardized API Response Builders.
 * Enforces the contract defined in docs/api/conventions.md.
 */

/**
 * Send a standardized success JSON response.
 * @param {import('express').Response} res
 * @param {any} data
 * @param {object} [meta]
 * @param {number} [statusCode=200]
 */
const successResponse = (res, data, meta = {}, statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    data,
    meta: {
      timestamp: new Date().toISOString(),
      ...meta
    }
  });
};

/**
 * Send a standardized paginated list response.
 * @param {import('express').Response} res
 * @param {Array} data
 * @param {{ page: number, limit: number, total: number }} pagination
 * @param {number} [statusCode=200]
 */
const paginatedResponse = (res, data, { page, limit, total }, statusCode = 200) => {
  const totalPages = Math.ceil(total / limit) || 1;
  return res.status(statusCode).json({
    success: true,
    data,
    meta: {
      page: Number(page),
      limit: Number(limit),
      totalRecords: Number(total),
      totalPages,
      hasNextPage: page < totalPages,
      hasPrevPage: page > 1,
      timestamp: new Date().toISOString()
    }
  });
};

/**
 * Send a standardized error JSON response.
 * @param {import('express').Response} res
 * @param {string} code - Application error code string (e.g. 'VALIDATION_ERROR')
 * @param {string} message - Human-readable error message
 * @param {number} [statusCode=500] - HTTP status code
 * @param {Array|object} [details=null] - Optional detailed field validation errors
 */
const errorResponse = (res, code, message, statusCode = 500, details = null) => {
  const payload = {
    success: false,
    error: {
      code,
      message,
      timestamp: new Date().toISOString()
    }
  };

  if (details) {
    payload.error.details = details;
  }

  return res.status(statusCode).json(payload);
};

module.exports = {
  successResponse,
  paginatedResponse,
  errorResponse
};

