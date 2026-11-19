/**
 * Categories Resource Routes.
 * Mounts endpoints on /api/categories.
 */
const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/category.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');

// Read access: Admin & Pharmacist
router.get(
  '/',
  authenticate,
  requireRole('admin', 'pharmacist'),
  asyncHandler(categoryController.listCategories)
);

router.get(
  '/:id',
  authenticate,
  requireRole('admin', 'pharmacist'),
  asyncHandler(categoryController.getCategoryById)
);

// Write access: Admin only
router.post(
  '/',
  authenticate,
  requireRole('admin'),
  asyncHandler(categoryController.createCategory)
);

module.exports = router;

