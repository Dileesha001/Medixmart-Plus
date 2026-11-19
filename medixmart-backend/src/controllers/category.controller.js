/**
 * Categories Controller.
 * Manages medicine category retrieval and administrative creation.
 */
const db = require('../config/db');
const { successResponse } = require('../utils/response');
const { ValidationError, NotFoundError } = require('../utils/errors');

/**
 * List all categories.
 * GET /api/categories
 * Accessible to Admin and Pharmacist.
 */
const listCategories = async (req, res) => {
  const queryText = `
    SELECT id, name, description, created_at
    FROM categories
    ORDER BY name ASC
  `;
  const result = await db.query(queryText);

  return successResponse(res, result.rows, { total: result.rows.length }, 200);
};

/**
 * Get category by ID.
 * GET /api/categories/:id
 * Accessible to Admin and Pharmacist.
 */
const getCategoryById = async (req, res) => {
  const { id } = req.params;

  const result = await db.query(
    'SELECT id, name, description, created_at FROM categories WHERE id = $1',
    [id]
  );

  if (result.rows.length === 0) {
    throw new NotFoundError(`Category with ID '${id}' was not found.`);
  }

  return successResponse(res, result.rows[0], {}, 200);
};

/**
 * Create a new category.
 * POST /api/categories
 * Restricted to Admin.
 */
const createCategory = async (req, res) => {
  const { name, description } = req.body;

  if (!name || typeof name !== 'string' || name.trim() === '') {
    throw new ValidationError('Category name is required and cannot be empty.', [
      { field: 'name', message: 'Name is required.' }
    ]);
  }

  const cleanName = name.trim();
  const cleanDesc = description && typeof description === 'string' ? description.trim() : null;

  const queryText = `
    INSERT INTO categories (name, description)
    VALUES ($1, $2)
    RETURNING id, name, description, created_at
  `;

  const result = await db.query(queryText, [cleanName, cleanDesc]);

  return successResponse(res, result.rows[0], {}, 201);
};

module.exports = {
  listCategories,
  getCategoryById,
  createCategory
};

