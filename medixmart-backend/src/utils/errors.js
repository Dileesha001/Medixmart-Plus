/**
 * Centralized Application Error Classes.
 * Standardizes operational errors with HTTP status codes and API error codes.
 */

class AppError extends Error {
  /**
   * @param {string} message - Human-readable error message
   * @param {number} [statusCode=500] - HTTP status code
   * @param {string} [code='INTERNAL_SERVER_ERROR'] - Application error code
   * @param {Array|object} [details=null] - Optional detailed error list
   */
  constructor(message, statusCode = 500, code = 'INTERNAL_SERVER_ERROR', details = null) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true; // Marks trusted operational errors
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends AppError {
  constructor(message = 'Validation failed.', details = null) {
    super(message, 400, 'VALIDATION_ERROR', details);
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required.', code = 'AUTH_UNAUTHORIZED') {
    super(message, 401, code);
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Access denied. Insufficient permissions.', code = 'AUTH_FORBIDDEN_ROLE') {
    super(message, 403, code);
  }
}

class NotFoundError extends AppError {
  constructor(message = 'The requested resource was not found.', code = 'RESOURCE_NOT_FOUND') {
    super(message, 404, code);
  }
}

class ConflictError extends AppError {
  constructor(message = 'A resource conflict occurred.', code = 'RESOURCE_CONFLICT', details = null) {
    super(message, 409, code, details);
  }
}

class DatabaseError extends AppError {
  constructor(message = 'Database operation failed.', details = null) {
    super(message, 500, 'DATABASE_ERROR', details);
  }
}

module.exports = {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  DatabaseError
};

