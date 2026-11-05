/**
 * Role-Based Access Control (RBAC) Middleware.
 * Enforces allowed roles for restricted endpoints.
 */
const { errorResponse } = require('../utils/response');

/**
 * Middleware factory that restricts route access to specified roles.
 * Usage: requireRole('admin') or requireRole('admin', 'pharmacist') or requireRole(['admin', 'pharmacist'])
 * @param {...(string|string[])} roles - Allowed roles
 * @returns {Function} Express middleware
 */
const requireRole = (...roles) => {
  // Flatten array arguments in case roles are passed as an array
  const allowedRoles = roles.flat().map((r) => r.toLowerCase());

  return (req, res, next) => {
    if (!req.user) {
      return errorResponse(
        res,
        'INTERNAL_SERVER_ERROR',
        'Authentication middleware must be executed before role authorization.',
        500
      );
    }

    const userRole = (req.user.role || '').toLowerCase();

    if (!allowedRoles.includes(userRole)) {
      return errorResponse(
        res,
        'AUTH_FORBIDDEN_ROLE',
        `Access denied. This resource requires one of the following roles: [${allowedRoles.join(', ')}]. Your role is '${userRole}'.`,
        403
      );
    }

    next();
  };
};

module.exports = requireRole;

