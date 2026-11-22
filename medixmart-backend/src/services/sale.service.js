/**
 * Sales & Checkout Service.
 * Implements atomic transactional sales, pessimistic row locking with FOR UPDATE,
 * Expiry-First (FEFO) batch allocation, customer credit enforcement, and guaranteed rollback.
 * Architectural Lead: Member 1
 */
const db = require('../config/db');
const { ValidationError, NotFoundError } = require('../utils/errors');

/**
 * Execute an atomic POS checkout transaction.
 * @param {object} saleData
 * @param {number} userId - Cashier/User ID
 * @returns {Promise<{ sale: object, items: Array }>}
 */
const createSale = async (saleData, userId) => {
  const {
    customer_id,
    payment_type = 'cash',
    paid_amount = 0,
    discount_amount = 0,
    items
  } = saleData;

  // 1. Basic validation
  if (!Array.isArray(items) || items.length === 0) {
    throw new ValidationError('Sale must contain at least one line item.', [
      { field: 'items', message: 'Items array cannot be empty.' }
    ]);
  }

  const validPaymentTypes = ['cash', 'card', 'credit', 'split'];
  if (!validPaymentTypes.includes(payment_type)) {
    throw new ValidationError(`Invalid payment type. Must be one of: ${validPaymentTypes.join(', ')}.`, [
      { field: 'payment_type', message: 'Unsupported payment type.' }
    ]);
  }

  // Acquire dedicated client from connection pool for atomic transaction
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    // 2. Lock customer row if credit is involved
    let customer = null;
    const isCreditSale = payment_type === 'credit' || payment_type === 'split';

    if (customer_id || isCreditSale) {
      if (!customer_id) {
        throw new ValidationError('Customer ID is required for credit transactions.', [
          { field: 'customer_id', message: 'A registered customer must be assigned for credit or split sales.' }
        ]);
      }

      const custRes = await client.query(
        `SELECT id, name, credit_limit, current_balance, is_active
         FROM customers
         WHERE id = $1
         FOR UPDATE`,
        [customer_id]
      );

      if (custRes.rows.length === 0) {
        throw new NotFoundError(`Customer with ID ${customer_id} was not found.`);
      }

      customer = custRes.rows[0];

      if (!customer.is_active) {
        throw new ValidationError(`Customer account '${customer.name}' is inactive.`, [
          { field: 'customer_id', message: 'Customer account has been deactivated.' }
        ]);
      }
    }

    // 3. Process and allocate items with FEFO row locking
    const allocatedLines = [];

    // Sort items by medicine_id to prevent deadlocks across concurrent transactions
    const sortedItems = [...items].sort((a, b) => a.medicine_id - b.medicine_id);

    for (const item of sortedItems) {
      const { medicine_id, quantity, batch_id, unit_price } = item;

      if (!medicine_id || isNaN(medicine_id)) {
        throw new ValidationError('Invalid medicine ID.', [{ field: 'medicine_id', message: 'Medicine ID is required.' }]);
      }

      const requestedQty = parseInt(quantity, 10);
      if (isNaN(requestedQty) || requestedQty <= 0) {
        throw new ValidationError(`Invalid quantity for medicine ID ${medicine_id}.`, [
          { field: 'quantity', message: 'Quantity must be a positive integer.' }
        ]);
      }

      // Case A: Specific batch ID specified
      if (batch_id) {
        const batchRes = await client.query(
          `SELECT b.id, b.batch_number, b.current_quantity, b.selling_price, b.expiry_date, b.is_active, m.name AS medicine_name
           FROM batches b
           JOIN medicines m ON b.medicine_id = m.id
           WHERE b.id = $1 AND b.medicine_id = $2
           FOR UPDATE`,
          [batch_id, medicine_id]
        );

        if (batchRes.rows.length === 0) {
          throw new NotFoundError(`Batch ID ${batch_id} for medicine ID ${medicine_id} not found.`);
        }

        const batch = batchRes.rows[0];

        if (!batch.is_active) {
          throw new ValidationError(`Batch ${batch.batch_number} is inactive.`, [
            { field: 'batch_id', message: 'Specified batch has been deactivated.' }
          ]);
        }

        // Expiry check: Never allocate expired batches
        const today = new Date().toISOString().split('T')[0];
        const batchExpiry = new Date(batch.expiry_date).toISOString().split('T')[0];
        if (batchExpiry < today) {
          throw new ValidationError(`Batch ${batch.batch_number} expired on ${batchExpiry} and cannot be dispensed.`, [
            { field: 'batch_id', message: 'Cannot allocate an expired batch.' }
          ]);
        }

        if (batch.current_quantity < requestedQty) {
          throw new ValidationError(
            `Insufficient stock in batch ${batch.batch_number} for '${batch.medicine_name}'. Available: ${batch.current_quantity}, Requested: ${requestedQty}.`,
            [{ field: 'quantity', message: 'Requested quantity exceeds available batch stock.' }]
          );
        }

        // Deduct from batch
        await client.query(
          `UPDATE batches
           SET current_quantity = current_quantity - $1,
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $2`,
          [requestedQty, batch.id]
        );

        const price = unit_price !== undefined ? parseFloat(unit_price) : parseFloat(batch.selling_price);
        allocatedLines.push({
          medicine_id,
          batch_id: batch.id,
          quantity: requestedQty,
          unit_price: price,
          subtotal: parseFloat((requestedQty * price).toFixed(2))
        });
      } else {
        // Case B: Auto-allocation using Expiry-First (FEFO: ORDER BY expiry_date ASC, id ASC)
        const batchesRes = await client.query(
          `SELECT b.id, b.batch_number, b.current_quantity, b.selling_price, b.expiry_date, m.name AS medicine_name
           FROM batches b
           JOIN medicines m ON b.medicine_id = m.id
           WHERE b.medicine_id = $1 
             AND b.current_quantity > 0 
             AND b.is_active = TRUE 
             AND b.expiry_date >= CURRENT_DATE
           ORDER BY b.expiry_date ASC, b.id ASC
           FOR UPDATE`,
          [medicine_id]
        );

        const availableBatches = batchesRes.rows;
        const totalAvailable = availableBatches.reduce((sum, b) => sum + b.current_quantity, 0);

        if (totalAvailable < requestedQty) {
          const medName = availableBatches[0] ? availableBatches[0].medicine_name : `ID ${medicine_id}`;
          throw new ValidationError(
            `Insufficient stock for '${medName}'. Available: ${totalAvailable}, Requested: ${requestedQty}.`,
            [{ field: 'quantity', message: `Insufficient total stock available (${totalAvailable} available).` }]
          );
        }

        // Deduct sequentially from earliest expiring batches first
        let remainingToDeduct = requestedQty;
        for (const batch of availableBatches) {
          if (remainingToDeduct <= 0) break;

          const deductQty = Math.min(remainingToDeduct, batch.current_quantity);
          await client.query(
            `UPDATE batches
             SET current_quantity = current_quantity - $1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $2`,
            [deductQty, batch.id]
          );

          const price = unit_price !== undefined ? parseFloat(unit_price) : parseFloat(batch.selling_price);
          allocatedLines.push({
            medicine_id,
            batch_id: batch.id,
            quantity: deductQty,
            unit_price: price,
            subtotal: parseFloat((deductQty * price).toFixed(2))
          });

          remainingToDeduct -= deductQty;
        }
      }
    }

    // 4. Calculate financial totals
    const subtotal = parseFloat(allocatedLines.reduce((acc, l) => acc + l.subtotal, 0).toFixed(2));
    const discount = parseFloat((parseFloat(discount_amount) || 0).toFixed(2));
    const totalAmount = parseFloat(Math.max(0, subtotal - discount).toFixed(2));

    let finalPaid = 0.00;
    let finalCredit = 0.00;
    let paymentStatus = 'paid';

    if (payment_type === 'cash' || payment_type === 'card') {
      finalPaid = totalAmount;
      finalCredit = 0.00;
      paymentStatus = 'paid';
    } else if (payment_type === 'credit') {
      finalPaid = 0.00;
      finalCredit = totalAmount;
      paymentStatus = 'unpaid';
    } else if (payment_type === 'split') {
      finalPaid = parseFloat(Math.min(totalAmount, Math.max(0, parseFloat(paid_amount) || 0)).toFixed(2));
      finalCredit = parseFloat((totalAmount - finalPaid).toFixed(2));
      paymentStatus = finalCredit === 0 ? 'paid' : (finalPaid > 0 ? 'partial' : 'unpaid');
    }

    // 5. Customer credit limit validation
    if (finalCredit > 0) {
      const currentBalance = parseFloat(customer.current_balance);
      const creditLimit = parseFloat(customer.credit_limit);
      const newBalance = parseFloat((currentBalance + finalCredit).toFixed(2));

      if (newBalance > creditLimit) {
        throw new ValidationError(
          `Credit limit exceeded for customer '${customer.name}'. Limit: Rs. ${creditLimit.toFixed(2)}, Current Debt: Rs. ${currentBalance.toFixed(2)}, Proposed Debt: Rs. ${newBalance.toFixed(2)}.`,
          [{ field: 'credit_limit', message: 'Transaction would exceed customer credit limit.' }]
        );
      }

      // Update customer debt balance inside this transaction
      await client.query(
        `UPDATE customers
         SET current_balance = current_balance + $1,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [finalCredit, customer.id]
      );
    }

    // 6. Generate Invoice Number (e.g. INV-YYYYMMDD-XXXX)
    const datePrefix = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const invoiceNumber = `INV-${datePrefix}-${randomSuffix}`;

    // 7. Insert Sale Header
    const saleInsertQuery = `
      INSERT INTO sales (
        invoice_number,
        user_id,
        customer_id,
        subtotal,
        discount_amount,
        total_amount,
        payment_type,
        paid_amount,
        credit_amount,
        payment_status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING id, invoice_number, user_id, customer_id, subtotal, discount_amount, total_amount, payment_type, paid_amount, credit_amount, payment_status, created_at
    `;

    const saleRes = await client.query(saleInsertQuery, [
      invoiceNumber,
      userId,
      customer ? customer.id : null,
      subtotal,
      discount,
      totalAmount,
      payment_type,
      finalPaid,
      finalCredit,
      paymentStatus
    ]);

    const createdSale = saleRes.rows[0];

    // 8. Insert Line Items
    const itemInsertQuery = `
      INSERT INTO sale_items (sale_id, medicine_id, batch_id, quantity, unit_price, subtotal)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, sale_id, medicine_id, batch_id, quantity, unit_price, subtotal
    `;

    const createdItems = [];
    for (const line of allocatedLines) {
      const lineRes = await client.query(itemInsertQuery, [
        createdSale.id,
        line.medicine_id,
        line.batch_id,
        line.quantity,
        line.unit_price,
        line.subtotal
      ]);
      createdItems.push(lineRes.rows[0]);
    }

    // 9. Commit atomic transaction
    await client.query('COMMIT');

    return {
      sale: createdSale,
      items: createdItems
    };
  } catch (err) {
    // Guaranteed rollback on any error
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

/**
 * Retrieve sale by ID with items, customer, and cashier details.
 * @param {number} saleId
 */
const getSaleById = async (saleId) => {
  const saleQuery = `
    SELECT 
      s.id,
      s.invoice_number,
      s.user_id,
      u.username AS cashier_name,
      s.customer_id,
      c.name AS customer_name,
      s.subtotal,
      s.discount_amount,
      s.total_amount,
      s.payment_type,
      s.paid_amount,
      s.credit_amount,
      s.payment_status,
      s.created_at
    FROM sales s
    JOIN users u ON s.user_id = u.id
    LEFT JOIN customers c ON s.customer_id = c.id
    WHERE s.id = $1
  `;
  const saleRes = await db.query(saleQuery, [saleId]);

  if (saleRes.rows.length === 0) {
    throw new NotFoundError(`Sale with ID ${saleId} was not found.`);
  }

  const itemsQuery = `
    SELECT 
      si.id,
      si.medicine_id,
      m.name AS medicine_name,
      m.strength,
      si.batch_id,
      b.batch_number,
      b.expiry_date,
      si.quantity,
      si.unit_price,
      si.subtotal
    FROM sale_items si
    JOIN medicines m ON si.medicine_id = m.id
    JOIN batches b ON si.batch_id = b.id
    WHERE si.sale_id = $1
    ORDER BY si.id ASC
  `;
  const itemsRes = await db.query(itemsQuery, [saleId]);

  return {
    sale: saleRes.rows[0],
    items: itemsRes.rows
  };
};

/**
 * List sales with pagination and optional filters.
 */
const listSales = async (filters = {}) => {
  const {
    page = 1,
    limit = 20,
    customer_id,
    payment_type,
    payment_status,
    date_from,
    date_to
  } = filters;

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const offset = (pageNum - 1) * limitNum;

  const conditions = [];
  const params = [];
  let paramIdx = 1;

  if (customer_id) {
    conditions.push(`s.customer_id = $${paramIdx}`);
    params.push(customer_id);
    paramIdx++;
  }

  if (payment_type) {
    conditions.push(`s.payment_type = $${paramIdx}`);
    params.push(payment_type);
    paramIdx++;
  }

  if (payment_status) {
    conditions.push(`s.payment_status = $${paramIdx}`);
    params.push(payment_status);
    paramIdx++;
  }

  if (date_from) {
    conditions.push(`s.created_at >= $${paramIdx}`);
    params.push(date_from);
    paramIdx++;
  }

  if (date_to) {
    conditions.push(`s.created_at <= $${paramIdx}`);
    params.push(date_to);
    paramIdx++;
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const dataQuery = `
    SELECT 
      s.id,
      s.invoice_number,
      s.user_id,
      u.username AS cashier_name,
      s.customer_id,
      c.name AS customer_name,
      s.subtotal,
      s.discount_amount,
      s.total_amount,
      s.payment_type,
      s.paid_amount,
      s.credit_amount,
      s.payment_status,
      s.created_at
    FROM sales s
    JOIN users u ON s.user_id = u.id
    LEFT JOIN customers c ON s.customer_id = c.id
    ${whereClause}
    ORDER BY s.created_at DESC
    LIMIT $${paramIdx} OFFSET $${paramIdx + 1}
  `;

  params.push(limitNum, offset);

  const countQuery = `
    SELECT COUNT(*)::int AS total
    FROM sales s
    ${whereClause}
  `;

  const [dataRes, countRes] = await Promise.all([
    db.query(dataQuery, params),
    db.query(countQuery, params.slice(0, paramIdx - 1))
  ]);

  return {
    sales: dataRes.rows,
    total: countRes.rows[0].total,
    page: pageNum,
    limit: limitNum
  };
};

module.exports = {
  createSale,
  getSaleById,
  listSales
};

