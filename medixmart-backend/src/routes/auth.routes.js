/**
 * Authentication Routes.
 * Mounts endpoints on /api/auth.
 */
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const asyncHandler = require('../utils/asyncHandler');

// POST /api/auth/login
router.post('/login', asyncHandler(authController.login));

module.exports = router;

