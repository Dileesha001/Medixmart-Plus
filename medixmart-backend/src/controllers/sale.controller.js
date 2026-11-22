/**
 * Sales Controller.
 * Handles POS checkout operations, invoice generation, and sales history.
 */
const saleService = require('../services/sale.service');
const { successResponse, paginatedResponse } = require('../utils/response');
const { ValidationError } = require('../utils/errors');

/**
 * Execute POS checkout transaction.
 * POST /api/sales
 */
const checkout = async (req, res) => {
  const userId = req.user.id;
  const result = await saleService.createSale(req.body, userId);

  return successResponse(
    res,
    {
      message: 'Sale transaction completed successfully.',
      invoice_number: result.sale.invoice_number,
      sale: result.sale,
      items: result.items
    },
    {},
    201
  );
};

/**
 * Retrieve sale by ID.
 * GET /api/sales/:id
 */
const getSale = async (req, res) => {
  const saleId = parseInt(req.params.id, 10);
  if (isNaN(saleId)) {
    throw new ValidationError('Invalid sale ID parameter.');
  }

  const result = await saleService.getSaleById(saleId);
  return successResponse(res, result, {}, 200);
};

/**
 * List sales with pagination and filtering.
 * GET /api/sales
 */
const listSales = async (req, res) => {
  const {
    page = 1,
    limit = 20,
    customer_id,
    payment_type,
    payment_status,
    date_from,
    date_to
  } = req.query;

  const result = await saleService.listSales({
    page: parseInt(page, 10) || 1,
    limit: parseInt(limit, 10) || 20,
    customer_id: customer_id ? parseInt(customer_id, 10) : undefined,
    payment_type,
    payment_status,
    date_from,
    date_to
  });

  return paginatedResponse(res, result.sales, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: Math.ceil(result.total / result.limit),
    hasNext: (result.page * result.limit) < result.total,
    hasPrev: result.page > 1
  });
};

module.exports = {
  checkout,
  getSale,
  listSales
};

