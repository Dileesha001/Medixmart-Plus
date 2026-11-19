/**
 * Medicines Resource Routes.
 * Mounts endpoints on /api/medicines.
 */
const express = require('express');
const router = express.Router();
const medicineController = require('../controllers/medicine.controller');
const asyncHandler = require('../utils/asyncHandler');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');

// Read access: Admin & Pharmacist
router.get(
  '/',
  authenticate,
  requireRole('admin', 'pharmacist'),
  asyncHandler(medicineController.listMedicines)
);

router.get(
  '/:id',
  authenticate,
  requireRole('admin', 'pharmacist'),
  asyncHandler(medicineController.getMedicineById)
);

// Write/Mutate access: Admin only
router.post(
  '/',
  authenticate,
  requireRole('admin'),
  asyncHandler(medicineController.createMedicine)
);

router.put(
  '/:id',
  authenticate,
  requireRole('admin'),
  asyncHandler(medicineController.updateMedicine)
);

router.patch(
  '/:id/deactivate',
  authenticate,
  requireRole('admin'),
  asyncHandler(medicineController.deactivateMedicine)
);

module.exports = router;

