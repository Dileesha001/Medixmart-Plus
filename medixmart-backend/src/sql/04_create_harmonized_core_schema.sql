-- Medixmart Plus - Schema Harmonization Migration 04
-- Establishes core relational contracts across Member 3 (Suppliers & Batches),
-- Member 4 (Sales & POS Transactions), and Member 5 (Customers & Credit Management).
-- System Architect: Member 1

-- 1. Suppliers Table (M3: Stock & Purchase Management)
CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON suppliers(is_active);

-- 2. Batches Table (M3: Stock & Expiry Tracking)
CREATE TABLE IF NOT EXISTS batches (
    id SERIAL PRIMARY KEY,
    medicine_id INT NOT NULL REFERENCES medicines(id) ON DELETE RESTRICT,
    supplier_id INT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    batch_number VARCHAR(50) NOT NULL,
    initial_quantity INT NOT NULL CHECK (initial_quantity > 0),
    current_quantity INT NOT NULL CHECK (current_quantity >= 0),
    purchase_price NUMERIC(10, 2) NOT NULL CHECK (purchase_price >= 0),
    selling_price NUMERIC(10, 2) NOT NULL CHECK (selling_price >= 0),
    received_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_medicine_batch UNIQUE (medicine_id, batch_number)
);

-- Indexes for FEFO allocation query and daily 06:00 expiry alerts
CREATE INDEX IF NOT EXISTS idx_batches_fefo ON batches(medicine_id, expiry_date, current_quantity) WHERE current_quantity > 0 AND is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_batches_expiry_date ON batches(expiry_date);
CREATE INDEX IF NOT EXISTS idx_batches_supplier_id ON batches(supplier_id);

-- 3. Customers Table (M5: Customer Management & Credit Tracking)
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100),
    address TEXT,
    date_of_birth DATE,
    credit_limit NUMERIC(10, 2) NOT NULL DEFAULT 5000.00 CHECK (credit_limit >= 0),
    current_balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (current_balance >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_dob ON customers(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_customers_current_balance ON customers(current_balance) WHERE current_balance > 0;

-- 4. Sales Table (M4: POS Checkout & Invoicing)
CREATE TABLE IF NOT EXISTS sales (
    id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    customer_id INT REFERENCES customers(id) ON DELETE RESTRICT,
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('cash', 'card', 'credit', 'split')),
    paid_amount NUMERIC(10, 2) NOT NULL CHECK (paid_amount >= 0),
    credit_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (credit_amount >= 0),
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('paid', 'partial', 'unpaid')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON sales(invoice_number);
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);

-- 5. Sale Items Table (M4: Batch-Level Line Items)
CREATE TABLE IF NOT EXISTS sale_items (
    id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    medicine_id INT NOT NULL REFERENCES medicines(id) ON DELETE RESTRICT,
    batch_id INT NOT NULL REFERENCES batches(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_batch_id ON sale_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_medicine_id ON sale_items(medicine_id);

-- 6. Credit Payments Table (M5: Debt Repayments)
CREATE TABLE IF NOT EXISTS credit_payments (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    sale_id INT REFERENCES sales(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'card', 'bank_transfer')),
    reference_note TEXT,
    recorded_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    payment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_credit_payments_customer_id ON credit_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_credit_payments_date ON credit_payments(payment_date);

-- 7. Alerts Table (M3 & M4: Expiry, Low Stock, Credit & Customer Alerts)
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_type VARCHAR(30) NOT NULL CHECK (alert_type IN ('expiry_warning', 'expired', 'low_stock', 'credit_overdue', 'birthday')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('info', 'warning', 'danger')),
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    reference_table VARCHAR(50),
    reference_id INT,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_alerts_active ON alerts(alert_type, is_resolved, created_at) WHERE is_resolved = FALSE;

