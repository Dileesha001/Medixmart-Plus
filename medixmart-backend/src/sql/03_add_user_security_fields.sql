-- Medixmart Plus - Migration 03: Security Lifecycle Fields
-- Adds session invalidation tracking (token_version) and password audit timestamp

ALTER TABLE users 
    ADD COLUMN IF NOT EXISTS token_version INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
