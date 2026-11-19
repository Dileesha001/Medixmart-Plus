/**
 * User Management Routes.
 * Mounts endpoints on /api/users.
 * All user management routes require Admin privileges.
 */
const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');

// Apply authentication and Admin role enforcement to all user management routes
router.use(authenticate);
router.use(requireRole('admin'));

// GET /api/users - List all users
router.get('/', asyncHandler(userController.listUsers));

// PATCH /api/users/:id/status - Activate or deactivate account (with self-lockout guard)
router.patch('/:id/status', asyncHandler(userController.updateUserStatus));

// PATCH /api/users/:id/role - Update user role (with last-admin guard)
router.patch('/:id/role', asyncHandler(userController.updateUserRole));

module.exports = router;
