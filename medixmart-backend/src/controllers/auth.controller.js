/**
 * Authentication Controller.
 * Handles user login, credential verification, and JWT generation.
 */
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const config = require('../config/environment');
const db = require('../config/db');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * Authenticate user and issue JWT token.
 * POST /api/auth/login
 */
const login = async (req, res) => {
  const { username, password } = req.body;

  // 1. Input validation
  const errors = [];
  if (!username || typeof username !== 'string' || username.trim() === '') {
    errors.push({ field: 'username', message: 'Username is required.' });
  }
  if (!password || typeof password !== 'string' || password === '') {
    errors.push({ field: 'password', message: 'Password is required.' });
  }

  if (errors.length > 0) {
    return errorResponse(res, 'VALIDATION_ERROR', 'Username and password are required.', 400, errors);
  }

  const cleanUsername = username.trim();

  // 2. Fetch user from PostgreSQL using parameterized query
  const queryText = `
    SELECT id, username, password_hash, role, is_active
    FROM users
    WHERE username = $1
  `;
  const result = await db.query(queryText, [cleanUsername]);

  if (result.rows.length === 0) {
    // Return generic error to avoid user enumeration
    return errorResponse(res, 'AUTH_INVALID_CREDENTIALS', 'Invalid username or password.', 401);
  }

  const user = result.rows[0];

  // 3. Check account status
  if (!user.is_active) {
    return errorResponse(
      res,
      'AUTH_ACCOUNT_DISABLED',
      'This user account has been disabled. Please contact an administrator.',
      403
    );
  }

  // 4. Verify password with bcrypt
  const isMatch = await bcrypt.compare(password, user.password_hash);
  if (!isMatch) {
    return errorResponse(res, 'AUTH_INVALID_CREDENTIALS', 'Invalid username or password.', 401);
  }

  // 5. Issue signed JWT token (8 hours)
  const payload = {
    sub: user.id,
    username: user.username,
    role: user.role
  };

  const token = jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn
  });

  // 6. Return response
  return successResponse(
    res,
    {
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role
      },
      expiresIn: config.jwt.expiresIn
    },
    {},
    200
  );
};

/**
 * Retrieve current authenticated user profile.
 * GET /api/auth/me
 */
const getProfile = async (req, res) => {
  return successResponse(
    res,
    {
      user: req.user
    },
    {},
    200
  );
};

/**
 * Log out user session.
 * POST /api/auth/logout
 */
const logout = async (req, res) => {
  return successResponse(
    res,
    {
      message: 'Successfully logged out.'
    },
    {},
    200
  );
};

module.exports = {
  login,
  getProfile,
  logout
};

