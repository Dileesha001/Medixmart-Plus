-- Medixmart Plus - Inventory Tables Schema (Categories & Medicines)
-- Member 1 (Architecture / Review) & Member 3 (Inventory & Batches)

-- 1. Categories Table
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);

-- 2. Medicines Table
CREATE TABLE IF NOT EXISTS medicines (
    id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    generic_name VARCHAR(150),
    brand VARCHAR(100),
    dosage_form VARCHAR(50) DEFAULT 'Tablet',
    strength VARCHAR(50),
    selling_price NUMERIC(10, 2) NOT NULL CHECK (selling_price >= 0),
    cost_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (cost_price >= 0),
    reorder_level INT NOT NULL DEFAULT 10 CHECK (reorder_level >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_medicine_name_strength UNIQUE (name, strength)
);

-- Indexes for search, foreign key joins, and active filters
CREATE INDEX IF NOT EXISTS idx_medicines_name ON medicines(name);
CREATE INDEX IF NOT EXISTS idx_medicines_generic_name ON medicines(generic_name);
CREATE INDEX IF NOT EXISTS idx_medicines_category_id ON medicines(category_id);
CREATE INDEX IF NOT EXISTS idx_medicines_is_active ON medicines(is_active);

