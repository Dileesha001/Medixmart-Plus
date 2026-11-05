/**
 * Centralized Express Error Handling Middleware.
 * Catches all errors, maps database and authentication codes, and sanitizes output.
 */
const config = require('../config/environment');
const { errorResponse } = require('../utils/response');

/**
 * Global 4-argument Express error handling middleware.
 */
const errorHandler = (err, req, res, next) => {
  let statusCode = err.statusCode || err.status || 500;
  let code = err.code || 'INTERNAL_SERVER_ERROR';
  let message = err.message || 'An unexpected error occurred.';
  let details = err.details || null;

  // Log error on server (safe logs: never log passwords or credentials)
  if (statusCode >= 500) {
    console.error(`[SERVER ERROR] ${req.method} ${req.originalUrl}:`, err);
  } else if (!config.isProduction) {
    console.warn(`[CLIENT ERROR ${statusCode}] ${code}: ${message}`);
  }

  // 1. Handle JSON parse error (SyntaxError from express.json)
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    statusCode = 400;
    code = 'MALFORMED_JSON';
    message = 'Malformed JSON in request body. Please verify syntax.';
  }

  // 2. Handle JWT errors
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    code = 'AUTH_INVALID_TOKEN';
    message = 'Invalid authentication token signature or payload.';
  } else if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    code = 'AUTH_EXPIRED_TOKEN';
    message = 'Your authentication session has expired. Please log in again.';
  }

  // 3. Handle PostgreSQL errors (codes: https://www.postgresql.org/docs/current/errcodes-appendix.html)
  if (err.code && typeof err.code === 'string') {
    switch (err.code) {
      case '23505': { // Unique violation
        statusCode = 409;
        code = 'DUPLICATE_ENTRY';
        const match = err.detail ? err.detail.match(/Key \((.+?)\)=\((.+?)\) already exists/) : null;
        if (match) {
          message = `A record with ${match[1]} '${match[2]}' already exists.`;
          details = [{ field: match[1], value: match[2], message: 'Must be unique.' }];
        } else {
          message = 'A record with duplicate unique fields already exists.';
        }
        break;
      }
      case '23503': { // Foreign key violation
        statusCode = 409;
        code = 'FOREIGN_KEY_VIOLATION';
        message = 'The referenced entity does not exist or cannot be modified.';
        break;
      }
      case '23502': { // Not-null violation
        statusCode = 400;
        code = 'MISSING_REQUIRED_FIELD';
        message = `Required field '${err.column || 'unknown'}' cannot be null.`;
        details = [{ field: err.column, message: 'Field is required.' }];
        break;
      }
      case '22P02': { // Invalid text representation (e.g. invalid integer or uuid)
        statusCode = 400;
        code = 'INVALID_INPUT_FORMAT';
        message = 'Invalid data type or format provided for the parameter.';
        break;
      }
      case '40001': { // Serialization failure (concurrency conflict)
        statusCode = 409;
        code = 'CONCURRENCY_CONFLICT';
        message = 'Transaction conflict. Please retry the operation.';
        break;
      }
      case '57P01': // Admin shutdown
      case 'ECONNREFUSED': {
        statusCode = 503;
        code = 'DATABASE_UNAVAILABLE';
        message = 'The database service is currently unavailable. Please try again later.';
        break;
      }
      default:
        // Other DB error codes keep 500
        break;
    }
  }

  // 4. Sanitize production responses: never leak internal stack traces or SQL internals
  if (config.isProduction && statusCode >= 500 && !err.isOperational) {
    message = 'An internal server error occurred. Please contact system support.';
    code = 'INTERNAL_SERVER_ERROR';
    details = null;
  }

  return errorResponse(res, code, message, statusCode, details);
};

module.exports = errorHandler;

