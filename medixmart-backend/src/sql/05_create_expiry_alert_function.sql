-- Medixmart Plus - Expiry Alert Stored Procedure
-- Calculates 7-month return windows and expired stock idempotently.
-- System Architect: Member 1 (M1-W5-01)

CREATE OR REPLACE FUNCTION generate_expiry_alerts(p_months_ahead INT DEFAULT 7)
RETURNS TABLE (
    expired_alerts_created INT,
    warning_alerts_created INT,
    alerts_auto_resolved INT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_expired_count INT := 0;
    v_warning_count INT := 0;
    v_resolved_count INT := 0;
    v_target_interval INTERVAL;
BEGIN
    v_target_interval := (p_months_ahead || ' months')::INTERVAL;

    -- 1. Auto-resolve alerts for batches that are depleted (current_quantity = 0) or inactive
    WITH resolved_depleted AS (
        UPDATE alerts a
        SET is_resolved = TRUE,
            resolved_at = CURRENT_TIMESTAMP
        FROM batches b
        WHERE a.reference_table = 'batches'
          AND a.reference_id = b.id
          AND a.is_resolved = FALSE
          AND a.alert_type IN ('expiry_warning', 'expired')
          AND (b.current_quantity = 0 OR b.is_active = FALSE)
        RETURNING a.id
    )
    SELECT COUNT(*)::INT INTO v_resolved_count FROM resolved_depleted;

    -- 2. Auto-resolve old 'expiry_warning' alerts for batches that have now reached actual expiration (expiry_date < CURRENT_DATE)
    WITH resolved_graduated AS (
        UPDATE alerts a
        SET is_resolved = TRUE,
            resolved_at = CURRENT_TIMESTAMP
        FROM batches b
        WHERE a.reference_table = 'batches'
          AND a.reference_id = b.id
          AND a.is_resolved = FALSE
          AND a.alert_type = 'expiry_warning'
          AND b.expiry_date < CURRENT_DATE
        RETURNING a.id
    )
    SELECT v_resolved_count + COUNT(*)::INT INTO v_resolved_count FROM resolved_graduated;

    -- 3. Create 'expired' alerts for batches where expiry_date < CURRENT_DATE, current_quantity > 0, is_active = TRUE
    -- Idempotent: Only insert if no unresolved 'expired' alert already exists for this batch
    WITH inserted_expired AS (
        INSERT INTO alerts (
            alert_type,
            severity,
            title,
            message,
            reference_table,
            reference_id,
            is_resolved
        )
        SELECT 
            'expired',
            'danger',
            'Batch ' || b.batch_number || ' Expired',
            'Batch ' || b.batch_number || ' of ' || m.name || ' (' || COALESCE(m.strength, '') || ') expired on ' || TO_CHAR(b.expiry_date, 'YYYY-MM-DD') || '. Quantity remaining: ' || b.current_quantity || ' units. Immediate quarantine or disposal required.',
            'batches',
            b.id,
            FALSE
        FROM batches b
        JOIN medicines m ON b.medicine_id = m.id
        WHERE b.expiry_date < CURRENT_DATE
          AND b.current_quantity > 0
          AND b.is_active = TRUE
          AND NOT EXISTS (
              SELECT 1 
              FROM alerts a 
              WHERE a.reference_table = 'batches' 
                AND a.reference_id = b.id 
                AND a.alert_type = 'expired' 
                AND a.is_resolved = FALSE
          )
        RETURNING id
    )
    SELECT COUNT(*)::INT INTO v_expired_count FROM inserted_expired;

    -- 4. Create 'expiry_warning' alerts for batches where CURRENT_DATE <= expiry_date <= CURRENT_DATE + interval
    -- Idempotent: Only insert if no unresolved 'expiry_warning' alert already exists for this batch
    WITH inserted_warnings AS (
        INSERT INTO alerts (
            alert_type,
            severity,
            title,
            message,
            reference_table,
            reference_id,
            is_resolved
        )
        SELECT 
            'expiry_warning',
            'warning',
            'Batch ' || b.batch_number || ' Near Expiry (Return Window)',
            'Batch ' || b.batch_number || ' of ' || m.name || ' (' || COALESCE(m.strength, '') || ') expires on ' || TO_CHAR(b.expiry_date, 'YYYY-MM-DD') || ' (' || (b.expiry_date - CURRENT_DATE) || ' days remaining). Quantity: ' || b.current_quantity || ' units. Eligible for vendor return to ' || s.name || '.',
            'batches',
            b.id,
            FALSE
        FROM batches b
        JOIN medicines m ON b.medicine_id = m.id
        JOIN suppliers s ON b.supplier_id = s.id
        WHERE b.expiry_date >= CURRENT_DATE 
          AND b.expiry_date <= (CURRENT_DATE + v_target_interval)
          AND b.current_quantity > 0
          AND b.is_active = TRUE
          AND NOT EXISTS (
              SELECT 1 
              FROM alerts a 
              WHERE a.reference_table = 'batches' 
                AND a.reference_id = b.id 
                AND a.alert_type = 'expiry_warning' 
                AND a.is_resolved = FALSE
          )
        RETURNING id
    )
    SELECT COUNT(*)::INT INTO v_warning_count FROM inserted_warnings;

    RETURN QUERY SELECT v_expired_count, v_warning_count, v_resolved_count;
END;
$$;

