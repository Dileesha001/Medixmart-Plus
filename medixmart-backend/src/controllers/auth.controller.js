/**
 * Authentication Controller.
 * Handles user login, credential verification, and JWT generation.
 */
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const config = require('../config/environment');
const db = require('../config/db');
const { successResponse, errorResponse } = require('../utils/response');
const { ValidationError, UnauthorizedError } = require('../utils/errors');

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
    SELECT id, username, password_hash, role, is_active, token_version
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

  // 5. Issue signed JWT token (8 hours) with token_version for session tracking
  const payload = {
    sub: user.id,
    username: user.username,
    role: user.role,
    token_version: user.token_version || 1
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
 * Change current user password and invalidate existing sessions.
 * PUT /api/auth/change-password
 */
const changePassword = async (req, res) => {
  const { current_password, new_password, confirm_password } = req.body;
  const userId = req.user.id;

  // 1. Validate inputs
  const errors = [];
  if (!current_password) {
    errors.push({ field: 'current_password', message: 'Current password is required.' });
  }
  if (!new_password) {
    errors.push({ field: 'new_password', message: 'New password is required.' });
  }
  if (!confirm_password) {
    errors.push({ field: 'confirm_password', message: 'Password confirmation is required.' });
  }

  if (errors.length > 0) {
    throw new ValidationError('All password fields are required.', errors);
  }

  // 2. Validate password strength and confirmation
  if (typeof new_password !== 'string' || new_password.length < 8) {
    throw new ValidationError('New password must be at least 8 characters long.', [
      { field: 'new_password', message: 'Password must be at least 8 characters long.' }
    ]);
  }

  if (new_password !== confirm_password) {
    throw new ValidationError('New password and confirmation do not match.', [
      { field: 'confirm_password', message: 'Confirmation password does not match.' }
    ]);
  }

  if (new_password === current_password) {
    throw new ValidationError('New password must be different from current password.', [
      { field: 'new_password', message: 'New password cannot be identical to the current password.' }
    ]);
  }

  // 3. Retrieve user record from database
  const userResult = await db.query(
    'SELECT id, username, password_hash, role, token_version FROM users WHERE id = $1',
    [userId]
  );

  if (userResult.rows.length === 0) {
    throw new UnauthorizedError('User account not found.', 'AUTH_INVALID_TOKEN');
  }

  const user = userResult.rows[0];

  // 4. Verify current password
  const isMatch = await bcrypt.compare(current_password, user.password_hash);
  if (!isMatch) {
    throw new UnauthorizedError('Current password is incorrect.', 'AUTH_INVALID_CREDENTIALS');
  }

  // 5. Hash new password (cost factor: 10)
  const saltRounds = 10;
  const newPasswordHash = await bcrypt.hash(new_password, saltRounds);

  // 6. Update password, increment token_version to invalidate prior sessions, update timestamp
  const updateQuery = `
    UPDATE users
    SET password_hash = $1,
        token_version = token_version + 1,
        password_changed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $2
    RETURNING id, username, role, token_version, password_changed_at
  `;

  const updatedResult = await db.query(updateQuery, [newPasswordHash, userId]);
  const updatedUser = updatedResult.rows[0];

  // 7. Mint new JWT token with updated token_version
  const newPayload = {
    sub: updatedUser.id,
    username: updatedUser.username,
    role: updatedUser.role,
    token_version: updatedUser.token_version
  };

  const newToken = jwt.sign(newPayload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn
  });

  return successResponse(
    res,
    {
      message: 'Password changed successfully. Prior sessions have been invalidated.',
      token: newToken,
      user: {
        id: updatedUser.id,
        username: updatedUser.username,
        role: updatedUser.role
      },
      expiresIn: config.jwt.expiresIn
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
  changePassword,
  logout
};

