/**
 * Sales Routes.
 * Mounts endpoints on /api/sales.
 */
const express = require('express');
const router = express.Router();
const saleController = require('../controllers/sale.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');

// Require authentication for all sales routes (accessible by admin and pharmacist)
router.use(authenticate);
router.use(requireRole('admin', 'pharmacist'));

// POST /api/sales - Checkout transaction
router.post('/', asyncHandler(saleController.checkout));

// GET /api/sales - List sales
router.get('/', asyncHandler(saleController.listSales));

// GET /api/sales/:id - Retrieve sale details
router.get('/:id', asyncHandler(saleController.getSale));

module.exports = router;

