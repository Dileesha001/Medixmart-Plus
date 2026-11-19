/**
 * User Management Controller.
 * Provides user listing, status updates, and administrative self-lockout protection.
 */
const db = require('../config/db');
const { successResponse } = require('../utils/response');
const { ValidationError, NotFoundError, ForbiddenError } = require('../utils/errors');

/**
 * List all users.
 * GET /api/users
 */
const listUsers = async (req, res) => {
  const query = `
    SELECT id, username, role, is_active, token_version, password_changed_at, created_at, updated_at
    FROM users
    ORDER BY id ASC
  `;
  const result = await db.query(query);

  return successResponse(
    res,
    {
      users: result.rows
    },
    { total: result.rows.length },
    200
  );
};

/**
 * Update user active status (activate / deactivate).
 * Enforces last-admin safeguard to prevent administrative self-lockout.
 * PATCH /api/users/:id/status
 */
const updateUserStatus = async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  const { is_active } = req.body;

  if (isNaN(userId)) {
    throw new ValidationError('Invalid user ID parameter.');
  }

  if (typeof is_active !== 'boolean') {
    throw new ValidationError('Field "is_active" must be a boolean (true or false).');
  }

  // 1. Fetch target user
  const userQuery = 'SELECT id, username, role, is_active FROM users WHERE id = $1';
  const userResult = await db.query(userQuery, [userId]);

  if (userResult.rows.length === 0) {
    throw new NotFoundError(`User with ID ${userId} was not found.`);
  }

  const targetUser = userResult.rows[0];

  // 2. Administrative self-lockout protection:
  // If attempting to deactivate an admin, verify at least one other active admin exists
  if (targetUser.role === 'admin' && targetUser.is_active && !is_active) {
    const adminCountQuery = `
      SELECT COUNT(*)::int AS count
      FROM users
      WHERE role = 'admin' AND is_active = TRUE AND id != $1
    `;
    const countResult = await db.query(adminCountQuery, [userId]);
    const remainingAdmins = countResult.rows[0].count;

    if (remainingAdmins === 0) {
      throw new ForbiddenError(
        'Cannot disable the last remaining active Administrator account. Self-lockout prevented.',
        'AUTH_LAST_ADMIN_PROTECTED'
      );
    }
  }

  // 3. Update status and increment token_version to invalidate existing tokens if deactivated
  const updateQuery = `
    UPDATE users
    SET is_active = $1,
        token_version = token_version + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $2
    RETURNING id, username, role, is_active, token_version, updated_at
  `;

  const updatedResult = await db.query(updateQuery, [is_active, userId]);

  return successResponse(
    res,
    {
      message: `User account has been successfully ${is_active ? 'activated' : 'deactivated'}.`,
      user: updatedResult.rows[0]
    },
    {},
    200
  );
};

/**
 * Update user role.
 * Enforces last-admin safeguard to prevent administrative self-lockout.
 * PATCH /api/users/:id/role
 */
const updateUserRole = async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  const { role } = req.body;

  if (isNaN(userId)) {
    throw new ValidationError('Invalid user ID parameter.');
  }

  if (!['admin', 'pharmacist'].includes(role)) {
    throw new ValidationError('Role must be either "admin" or "pharmacist".');
  }

  // 1. Fetch target user
  const userQuery = 'SELECT id, username, role, is_active FROM users WHERE id = $1';
  const userResult = await db.query(userQuery, [userId]);

  if (userResult.rows.length === 0) {
    throw new NotFoundError(`User with ID ${userId} was not found.`);
  }

  const targetUser = userResult.rows[0];

  // 2. Safeguard against demoting the last active administrator
  if (targetUser.role === 'admin' && targetUser.is_active && role !== 'admin') {
    const adminCountQuery = `
      SELECT COUNT(*)::int AS count
      FROM users
      WHERE role = 'admin' AND is_active = TRUE AND id != $1
    `;
    const countResult = await db.query(adminCountQuery, [userId]);
    const remainingAdmins = countResult.rows[0].count;

    if (remainingAdmins === 0) {
      throw new ForbiddenError(
        'Cannot demote the last remaining active Administrator account. Self-lockout prevented.',
        'AUTH_LAST_ADMIN_PROTECTED'
      );
    }
  }

  // 3. Update role and bump token_version so new permissions take effect on next login
  const updateQuery = `
    UPDATE users
    SET role = $1,
        token_version = token_version + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $2
    RETURNING id, username, role, is_active, token_version, updated_at
  `;

  const updatedResult = await db.query(updateQuery, [role, userId]);

  return successResponse(
    res,
    {
      message: `User role successfully updated to "${role}".`,
      user: updatedResult.rows[0]
    },
    {},
    200
  );
};

module.exports = {
  listUsers,
  updateUserStatus,
  updateUserRole
};

