/**
 * Medicines Controller.
 * Manages medicine catalogue search, retrieval, creation, updates, and soft-deactivation.
 */
const db = require('../config/db');
const { successResponse, paginatedResponse } = require('../utils/response');
const { ValidationError, NotFoundError } = require('../utils/errors');

/**
 * List and search medicines with category filtering and pagination.
 * GET /api/medicines
 * Accessible to Admin and Pharmacist.
 */
const listMedicines = async (req, res) => {
  const {
    search,
    category_id,
    is_active,
    page = 1,
    limit = 20,
    sortBy = 'name',
    sortOrder = 'asc'
  } = req.query;

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const offset = (pageNum - 1) * limitNum;

  // Allowed sort columns whitelist against SQL injection
  const allowedSortCols = {
    name: 'm.name',
    selling_price: 'm.selling_price',
    reorder_level: 'm.reorder_level',
    created_at: 'm.created_at',
    id: 'm.id'
  };
  const sortCol = allowedSortCols[sortBy] || 'm.name';
  const sortDir = sortOrder.toLowerCase() === 'desc' ? 'DESC' : 'ASC';

  const conditions = [];
  const params = [];
  let paramIdx = 1;

  // Filter: search text
  if (search && search.trim() !== '') {
    conditions.push(`(m.name ILIKE $${paramIdx} OR m.generic_name ILIKE $${paramIdx} OR m.brand ILIKE $${paramIdx})`);
    params.push(`%${search.trim()}%`);
    paramIdx++;
  }

  // Filter: category
  if (category_id) {
    conditions.push(`m.category_id = $${paramIdx}`);
    params.push(parseInt(category_id, 10));
    paramIdx++;
  }

  // Filter: is_active (default to active medicines only unless specified)
  if (is_active !== undefined) {
    if (is_active === 'true' || is_active === true) {
      conditions.push(`m.is_active = TRUE`);
    } else if (is_active === 'false' || is_active === false) {
      conditions.push(`m.is_active = FALSE`);
    }
  } else {
    // Default view: only show active medicines
    conditions.push(`m.is_active = TRUE`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  // Count total matching records
  const countQuery = `
    SELECT COUNT(*) AS total
    FROM medicines m
    ${whereClause}
  `;
  const countResult = await db.query(countQuery, params);
  const totalRecords = parseInt(countResult.rows[0].total, 10);

  // Fetch paginated records with category join
  const dataQuery = `
    SELECT 
      m.id,
      m.category_id,
      c.name AS category_name,
      m.name,
      m.generic_name,
      m.brand,
      m.dosage_form,
      m.strength,
      m.selling_price,
      m.cost_price,
      m.reorder_level,
      m.is_active,
      m.created_at,
      m.updated_at
    FROM medicines m
    LEFT JOIN categories c ON m.category_id = c.id
    ${whereClause}
    ORDER BY ${sortCol} ${sortDir}
    LIMIT $${paramIdx} OFFSET $${paramIdx + 1}
  `;

  params.push(limitNum, offset);
  const dataResult = await db.query(dataQuery, params);

  return paginatedResponse(res, dataResult.rows, {
    page: pageNum,
    limit: limitNum,
    total: totalRecords
  });
};

/**
 * Get single medicine by ID.
 * GET /api/medicines/:id
 * Accessible to Admin and Pharmacist.
 */
const getMedicineById = async (req, res) => {
  const { id } = req.params;

  const queryText = `
    SELECT 
      m.id,
      m.category_id,
      c.name AS category_name,
      m.name,
      m.generic_name,
      m.brand,
      m.dosage_form,
      m.strength,
      m.selling_price,
      m.cost_price,
      m.reorder_level,
      m.is_active,
      m.created_at,
      m.updated_at
    FROM medicines m
    LEFT JOIN categories c ON m.category_id = c.id
    WHERE m.id = $1
  `;

  const result = await db.query(queryText, [id]);

  if (result.rows.length === 0) {
    throw new NotFoundError(`Medicine with ID '${id}' was not found.`);
  }

  return successResponse(res, result.rows[0], {}, 200);
};

/**
 * Create a new medicine.
 * POST /api/medicines
 * Restricted to Admin.
 */
const createMedicine = async (req, res) => {
  const {
    category_id,
    name,
    generic_name,
    brand,
    dosage_form = 'Tablet',
    strength,
    selling_price,
    cost_price = 0.00,
    reorder_level = 10
  } = req.body;

  // Validation
  const errors = [];
  if (!name || typeof name !== 'string' || name.trim() === '') {
    errors.push({ field: 'name', message: 'Medicine name is required.' });
  }
  if (!category_id || isNaN(parseInt(category_id, 10))) {
    errors.push({ field: 'category_id', message: 'Valid category_id is required.' });
  }
  if (selling_price === undefined || isNaN(parseFloat(selling_price)) || parseFloat(selling_price) < 0) {
    errors.push({ field: 'selling_price', message: 'Selling price must be a non-negative number.' });
  }
  if (cost_price !== undefined && (isNaN(parseFloat(cost_price)) || parseFloat(cost_price) < 0)) {
    errors.push({ field: 'cost_price', message: 'Cost price must be a non-negative number.' });
  }
  if (reorder_level !== undefined && (isNaN(parseInt(reorder_level, 10)) || parseInt(reorder_level, 10) < 0)) {
    errors.push({ field: 'reorder_level', message: 'Reorder level must be a non-negative integer.' });
  }

  if (errors.length > 0) {
    throw new ValidationError('Invalid medicine details provided.', errors);
  }

  // Verify category exists
  const catCheck = await db.query('SELECT id FROM categories WHERE id = $1', [category_id]);
  if (catCheck.rows.length === 0) {
    throw new ValidationError(`Category with ID '${category_id}' does not exist.`, [
      { field: 'category_id', message: 'Category not found.' }
    ]);
  }

  const queryText = `
    INSERT INTO medicines (
      category_id, name, generic_name, brand, dosage_form, strength,
      selling_price, cost_price, reorder_level, is_active
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE)
    RETURNING *
  `;

  const values = [
    parseInt(category_id, 10),
    name.trim(),
    generic_name ? generic_name.trim() : null,
    brand ? brand.trim() : null,
    dosage_form ? dosage_form.trim() : 'Tablet',
    strength ? strength.trim() : null,
    parseFloat(selling_price),
    parseFloat(cost_price),
    parseInt(reorder_level, 10)
  ];

  const result = await db.query(queryText, values);

  return successResponse(res, result.rows[0], {}, 201);
};

/**
 * Update medicine details.
 * PUT /api/medicines/:id
 * Restricted to Admin.
 */
const updateMedicine = async (req, res) => {
  const { id } = req.params;
  const {
    category_id,
    name,
    generic_name,
    brand,
    dosage_form,
    strength,
    selling_price,
    cost_price,
    reorder_level,
    is_active
  } = req.body;

  // Check medicine exists
  const checkRes = await db.query('SELECT * FROM medicines WHERE id = $1', [id]);
  if (checkRes.rows.length === 0) {
    throw new NotFoundError(`Medicine with ID '${id}' was not found.`);
  }

  const existing = checkRes.rows[0];

  // If category_id changed, verify it exists
  const newCatId = category_id !== undefined ? parseInt(category_id, 10) : existing.category_id;
  if (category_id !== undefined && newCatId !== existing.category_id) {
    const catCheck = await db.query('SELECT id FROM categories WHERE id = $1', [newCatId]);
    if (catCheck.rows.length === 0) {
      throw new ValidationError(`Category with ID '${newCatId}' does not exist.`);
    }
  }

  // Validate prices if provided
  if (selling_price !== undefined && (isNaN(parseFloat(selling_price)) || parseFloat(selling_price) < 0)) {
    throw new ValidationError('Selling price must be a non-negative number.');
  }

  const queryText = `
    UPDATE medicines
    SET
      category_id = $1,
      name = $2,
      generic_name = $3,
      brand = $4,
      dosage_form = $5,
      strength = $6,
      selling_price = $7,
      cost_price = $8,
      reorder_level = $9,
      is_active = $10,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = $11
    RETURNING *
  `;

  const values = [
    newCatId,
    name !== undefined ? name.trim() : existing.name,
    generic_name !== undefined ? (generic_name ? generic_name.trim() : null) : existing.generic_name,
    brand !== undefined ? (brand ? brand.trim() : null) : existing.brand,
    dosage_form !== undefined ? (dosage_form ? dosage_form.trim() : existing.dosage_form) : existing.dosage_form,
    strength !== undefined ? (strength ? strength.trim() : null) : existing.strength,
    selling_price !== undefined ? parseFloat(selling_price) : existing.selling_price,
    cost_price !== undefined ? parseFloat(cost_price) : existing.cost_price,
    reorder_level !== undefined ? parseInt(reorder_level, 10) : existing.reorder_level,
    is_active !== undefined ? Boolean(is_active) : existing.is_active,
    id
  ];

  const result = await db.query(queryText, values);

  return successResponse(res, result.rows[0], {}, 200);
};

/**
 * Soft-deactivate a medicine (prevents deletion, preserves sales history).
 * PATCH /api/medicines/:id/deactivate
 * Restricted to Admin.
 */
const deactivateMedicine = async (req, res) => {
  const { id } = req.params;

  const result = await db.query(
    `UPDATE medicines
     SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
     WHERE id = $1
     RETURNING id, name, is_active, updated_at`,
    [id]
  );

  if (result.rows.length === 0) {
    throw new NotFoundError(`Medicine with ID '${id}' was not found.`);
  }

  return successResponse(
    res,
    {
      medicine: result.rows[0],
      message: `Medicine '${result.rows[0].name}' has been safely deactivated.`
    },
    {},
    200
  );
};

module.exports = {
  listMedicines,
  getMedicineById,
  createMedicine,
  updateMedicine,
  deactivateMedicine
};

