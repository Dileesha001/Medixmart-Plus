/**
 * Authentication Routes.
 * Mounts endpoints on /api/auth.
 */
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const { successResponse } = require('../utils/response');

// POST /api/auth/login - Public login
router.post('/login', asyncHandler(authController.login));

// GET /api/auth/me - Protected session verification
router.get('/me', authenticate, asyncHandler(authController.getProfile));

// POST /api/auth/logout - Session logout
router.post('/logout', authenticate, asyncHandler(authController.logout));

// Role authorization verification endpoints
router.get(
  '/admin-only',
  authenticate,
  requireRole('admin'),
  (req, res) => successResponse(res, { message: 'Admin access granted.', user: req.user })
);

router.get(
  '/staff-only',
  authenticate,
  requireRole('admin', 'pharmacist'),
  (req, res) => successResponse(res, { message: 'Staff access granted.', user: req.user })
);

module.exports = router;

