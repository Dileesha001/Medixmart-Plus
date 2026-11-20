/**
 * Alert Routes.
 * Mounts endpoints on /api/alerts.
 */
const express = require('express');
const router = express.Router();
const alertController = require('../controllers/alert.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');

// Require authentication for all alert routes
router.use(authenticate);

// GET /api/alerts - List alerts (Staff access)
router.get('/', asyncHandler(alertController.listAlerts));

// GET /api/alerts/summary - Summary counts for dashboard badges
router.get('/summary', asyncHandler(alertController.getAlertSummary));

// PATCH /api/alerts/:id/resolve - Resolve alert (Staff access)
router.patch('/:id/resolve', asyncHandler(alertController.resolveAlert));

// POST /api/alerts/generate-expiry - Trigger expiry calculation engine (Admin only)
router.post('/generate-expiry', requireRole('admin'), asyncHandler(alertController.runExpiryEngine));

module.exports = router;

