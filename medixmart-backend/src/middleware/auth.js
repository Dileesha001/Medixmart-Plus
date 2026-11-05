/**
 * Bearer Token Authentication Middleware.
 * Extracts, validates, and decodes JWT tokens from Authorization header.
 * Verifies that the user exists and remains active in PostgreSQL.
 */
const jwt = require('jsonwebtoken');
const config = require('../config/environment');
const db = require('../config/db');
const { errorResponse } = require('../utils/response');

const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  // 1. Check for presence of Authorization header
  if (!authHeader) {
    return errorResponse(
      res,
      'AUTH_MISSING_TOKEN',
      'Authentication token is required. Please provide a Bearer token in the Authorization header.',
      401
    );
  }

  // 2. Validate Bearer format
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return errorResponse(
      res,
      'AUTH_INVALID_TOKEN',
      'Authorization header must follow the Bearer <token> format.',
      401
    );
  }

  const token = parts[1];

  try {
    // 3. Verify JWT signature and expiration
    const decoded = jwt.verify(token, config.jwt.secret);

    // 4. Verify that the user still exists and is active in the database
    const queryText = `
      SELECT id, username, role, is_active
      FROM users
      WHERE id = $1
    `;
    const result = await db.query(queryText, [decoded.sub]);

    if (result.rows.length === 0) {
      return errorResponse(
        res,
        'AUTH_INVALID_TOKEN',
        'User account associated with this token no longer exists.',
        401
      );
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return errorResponse(
        res,
        'AUTH_ACCOUNT_DISABLED',
        'This user account has been disabled. Please contact an administrator.',
        403
      );
    }

    // 5. Attach authenticated user object to the request
    req.user = {
      id: user.id,
      username: user.username,
      role: user.role
    };

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return errorResponse(
        res,
        'AUTH_EXPIRED_TOKEN',
        'Your authentication session has expired. Please log in again.',
        401
      );
    }

    if (err.name === 'JsonWebTokenError') {
      return errorResponse(
        res,
        'AUTH_INVALID_TOKEN',
        'Invalid authentication token signature or payload.',
        401
      );
    }

    // Unexpected error forwarding
    next(err);
  }
};

module.exports = authenticate;

