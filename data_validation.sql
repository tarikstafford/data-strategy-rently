-- ============================================================================
-- RENTLY LENDING PLATFORM - DATA VALIDATION PROCEDURES
-- ============================================================================
-- PostgreSQL Data Validation Functions and Procedures v1.0
-- Continuous monitoring and validation procedures for business data integrity
--
-- Usage: 
-- - Execute setup section once to install validation framework
-- - Run individual validation functions as needed
-- - Schedule validation procedures for continuous monitoring
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- VALIDATION FRAMEWORK SETUP
-- ============================================================================

-- Data validation results tracking table
CREATE TABLE IF NOT EXISTS data_validation_log (
    id SERIAL PRIMARY KEY,
    validation_type TEXT NOT NULL,
    validation_name TEXT NOT NULL,
    table_name TEXT,
    column_name TEXT,
    validation_status TEXT NOT NULL, -- 'PASS', 'FAIL', 'WARNING', 'INFO'
    record_count INTEGER,
    violation_count INTEGER,
    validation_message TEXT,
    details JSONB,
    validation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_data_validation_log_time ON data_validation_log(validation_time);
CREATE INDEX IF NOT EXISTS idx_data_validation_log_status ON data_validation_log(validation_status);
CREATE INDEX IF NOT EXISTS idx_data_validation_log_type ON data_validation_log(validation_type);

-- Function to log validation results
CREATE OR REPLACE FUNCTION log_validation_result(
    p_type TEXT,
    p_name TEXT,
    p_table TEXT DEFAULT NULL,
    p_column TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'INFO',
    p_record_count INTEGER DEFAULT NULL,
    p_violation_count INTEGER DEFAULT NULL,
    p_message TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO data_validation_log (
        validation_type, validation_name, table_name, column_name,
        validation_status, record_count, violation_count, 
        validation_message, details
    ) VALUES (
        p_type, p_name, p_table, p_column,
        p_status, p_record_count, p_violation_count,
        p_message, p_details
    );
    
    RAISE NOTICE '[%] %: % - %', p_type, p_name, p_status, COALESCE(p_message, '');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CORE DATA INTEGRITY VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate referential integrity
CREATE OR REPLACE FUNCTION validate_referential_integrity()
RETURNS void AS $$
DECLARE
    r RECORD;
    violation_count INTEGER;
BEGIN
    RAISE NOTICE '=== VALIDATING REFERENTIAL INTEGRITY ===';
    
    -- Check for orphaned payment allocations
    SELECT COUNT(*) INTO violation_count
    FROM payment_allocation pa
    LEFT JOIN payment p ON pa.payment_id = p.id
    WHERE p.id IS NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('INTEGRITY', 'orphaned_payment_allocations', 
            'payment_allocation', NULL, 'PASS', NULL, 0, 'No orphaned payment allocations');
    ELSE
        PERFORM log_validation_result('INTEGRITY', 'orphaned_payment_allocations', 
            'payment_allocation', NULL, 'FAIL', NULL, violation_count, 
            'Found orphaned payment allocations');
    END IF;
    
    -- Check for orphaned loan status history
    SELECT COUNT(*) INTO violation_count
    FROM loan_status_history lsh
    LEFT JOIN loan l ON lsh.loan_id = l.id
    WHERE l.id IS NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('INTEGRITY', 'orphaned_loan_status', 
            'loan_status_history', NULL, 'PASS', NULL, 0, 'No orphaned loan status records');
    ELSE
        PERFORM log_validation_result('INTEGRITY', 'orphaned_loan_status', 
            'loan_status_history', NULL, 'FAIL', NULL, violation_count, 
            'Found orphaned loan status records');
    END IF;
    
    -- Check for orphaned amortization lines
    SELECT COUNT(*) INTO violation_count
    FROM amortisation_line al
    LEFT JOIN amortisation_plan ap ON al.plan_id = ap.id
    WHERE ap.id IS NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('INTEGRITY', 'orphaned_amortisation_lines', 
            'amortisation_line', NULL, 'PASS', NULL, 0, 'No orphaned amortization lines');
    ELSE
        PERFORM log_validation_result('INTEGRITY', 'orphaned_amortisation_lines', 
            'amortisation_line', NULL, 'FAIL', NULL, violation_count, 
            'Found orphaned amortization lines');
    END IF;
    
    -- Check for loans without borrowers
    SELECT COUNT(*) INTO violation_count
    FROM loan l
    LEFT JOIN party p ON l.borrower_party_id = p.id
    WHERE p.id IS NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('INTEGRITY', 'loans_without_borrowers', 
            'loan', 'borrower_party_id', 'PASS', NULL, 0, 'All loans have valid borrowers');
    ELSE
        PERFORM log_validation_result('INTEGRITY', 'loans_without_borrowers', 
            'loan', 'borrower_party_id', 'FAIL', NULL, violation_count, 
            'Found loans without valid borrowers');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to validate business rules
CREATE OR REPLACE FUNCTION validate_business_rules()
RETURNS void AS $$
DECLARE
    violation_count INTEGER;
    total_records INTEGER;
BEGIN
    RAISE NOTICE '=== VALIDATING BUSINESS RULES ===';
    
    -- Validate payment allocation totals
    WITH payment_totals AS (
        SELECT 
            p.id,
            p.amount as payment_amount,
            COALESCE(SUM(pa.allocated_amount), 0) as allocated_total
        FROM payment p
        LEFT JOIN payment_allocation pa ON p.id = pa.payment_id
        WHERE p.status = 'completed'
        GROUP BY p.id, p.amount
    )
    SELECT COUNT(*) INTO violation_count
    FROM payment_totals
    WHERE ABS(payment_amount - allocated_total) > 0.01;
    
    SELECT COUNT(*) INTO total_records FROM payment WHERE status = 'completed';
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('BUSINESS_RULES', 'payment_allocation_balance', 
            'payment', NULL, 'PASS', total_records, 0, 
            'All completed payments have balanced allocations');
    ELSE
        PERFORM log_validation_result('BUSINESS_RULES', 'payment_allocation_balance', 
            'payment', NULL, 'FAIL', total_records, violation_count, 
            'Found payments with unbalanced allocations');
    END IF;
    
    -- Validate loan date ranges
    SELECT COUNT(*) INTO violation_count
    FROM loan
    WHERE end_date <= start_date;
    
    SELECT COUNT(*) INTO total_records FROM loan;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('BUSINESS_RULES', 'loan_date_ranges', 
            'loan', 'start_date,end_date', 'PASS', total_records, 0, 
            'All loans have valid date ranges');
    ELSE
        PERFORM log_validation_result('BUSINESS_RULES', 'loan_date_ranges', 
            'loan', 'start_date,end_date', 'FAIL', total_records, violation_count, 
            'Found loans with invalid date ranges');
    END IF;
    
    -- Validate amortization plan totals
    WITH amortization_totals AS (
        SELECT 
            ap.id,
            l.principal_amount,
            COALESCE(SUM(al.amount_principal), 0) as total_scheduled
        FROM amortisation_plan ap
        JOIN loan l ON ap.loan_id = l.id
        LEFT JOIN amortisation_line al ON ap.id = al.plan_id
        WHERE ap.status = 'active'
        GROUP BY ap.id, l.principal_amount
    )
    SELECT COUNT(*) INTO violation_count
    FROM amortization_totals
    WHERE ABS(principal_amount - total_scheduled) > 0.01;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('BUSINESS_RULES', 'amortization_balance', 
            'amortisation_plan', NULL, 'PASS', NULL, 0, 
            'All active amortization plans are balanced');
    ELSE
        PERFORM log_validation_result('BUSINESS_RULES', 'amortization_balance', 
            'amortisation_plan', NULL, 'WARNING', NULL, violation_count, 
            'Found unbalanced amortization plans');
    END IF;
    
    -- Validate currency consistency
    SELECT COUNT(*) INTO violation_count
    FROM payment p
    JOIN payment_allocation pa ON p.id = pa.payment_id
    JOIN loan l ON pa.loan_id = l.id
    WHERE p.currency_code != l.currency_code;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('BUSINESS_RULES', 'currency_consistency', 
            'payment_allocation', NULL, 'PASS', NULL, 0, 
            'All payment allocations have consistent currencies');
    ELSE
        PERFORM log_validation_result('BUSINESS_RULES', 'currency_consistency', 
            'payment_allocation', NULL, 'FAIL', NULL, violation_count, 
            'Found currency inconsistencies in payment allocations');
    END IF;
    
    -- Validate interest rates
    SELECT COUNT(*) INTO violation_count
    FROM loan
    WHERE interest_rate < 0 OR interest_rate > 1; -- Assuming rates are stored as decimals (e.g., 0.05 for 5%)
    
    SELECT COUNT(*) INTO total_records FROM loan;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('BUSINESS_RULES', 'interest_rate_range', 
            'loan', 'interest_rate', 'PASS', total_records, 0, 
            'All interest rates are within valid range');
    ELSE
        PERFORM log_validation_result('BUSINESS_RULES', 'interest_rate_range', 
            'loan', 'interest_rate', 'WARNING', total_records, violation_count, 
            'Found potentially invalid interest rates');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to validate data quality
CREATE OR REPLACE FUNCTION validate_data_quality()
RETURNS void AS $$
DECLARE
    violation_count INTEGER;
    total_records INTEGER;
BEGIN
    RAISE NOTICE '=== VALIDATING DATA QUALITY ===';
    
    -- Check for required field completeness
    SELECT COUNT(*) INTO violation_count
    FROM loan
    WHERE loan_number IS NULL OR TRIM(loan_number) = '';
    
    SELECT COUNT(*) INTO total_records FROM loan;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('DATA_QUALITY', 'loan_number_completeness', 
            'loan', 'loan_number', 'PASS', total_records, 0, 
            'All loans have loan numbers');
    ELSE
        PERFORM log_validation_result('DATA_QUALITY', 'loan_number_completeness', 
            'loan', 'loan_number', 'FAIL', total_records, violation_count, 
            'Found loans without loan numbers');
    END IF;
    
    -- Check email format validation
    SELECT COUNT(*) INTO violation_count
    FROM party
    WHERE email IS NOT NULL 
    AND email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
    
    SELECT COUNT(*) INTO total_records FROM party WHERE email IS NOT NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('DATA_QUALITY', 'email_format', 
            'party', 'email', 'PASS', total_records, 0, 
            'All email addresses are properly formatted');
    ELSE
        PERFORM log_validation_result('DATA_QUALITY', 'email_format', 
            'party', 'email', 'WARNING', total_records, violation_count, 
            'Found invalid email formats');
    END IF;
    
    -- Check for duplicate loan numbers
    WITH duplicates AS (
        SELECT loan_number, COUNT(*) as dup_count
        FROM loan
        GROUP BY loan_number
        HAVING COUNT(*) > 1
    )
    SELECT COUNT(*) INTO violation_count FROM duplicates;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('DATA_QUALITY', 'loan_number_uniqueness', 
            'loan', 'loan_number', 'PASS', NULL, 0, 
            'All loan numbers are unique');
    ELSE
        PERFORM log_validation_result('DATA_QUALITY', 'loan_number_uniqueness', 
            'loan', 'loan_number', 'FAIL', NULL, violation_count, 
            'Found duplicate loan numbers');
    END IF;
    
    -- Check currency code format
    WITH all_currencies AS (
        SELECT DISTINCT currency_code FROM loan
        UNION
        SELECT DISTINCT currency_code FROM payment
        UNION
        SELECT DISTINCT from_ccy FROM fx_rate
        UNION
        SELECT DISTINCT to_ccy FROM fx_rate
    )
    SELECT COUNT(*) INTO violation_count
    FROM all_currencies
    WHERE currency_code IS NULL OR LENGTH(currency_code) != 3;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('DATA_QUALITY', 'currency_code_format', 
            NULL, NULL, 'PASS', NULL, 0, 
            'All currency codes follow ISO 4217 format');
    ELSE
        PERFORM log_validation_result('DATA_QUALITY', 'currency_code_format', 
            NULL, NULL, 'FAIL', NULL, violation_count, 
            'Found invalid currency codes');
    END IF;
    
    -- Check for reasonable payment amounts
    SELECT COUNT(*) INTO violation_count
    FROM payment
    WHERE amount <= 0 OR amount > 1000000; -- Adjust threshold as needed
    
    SELECT COUNT(*) INTO total_records FROM payment;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('DATA_QUALITY', 'payment_amount_range', 
            'payment', 'amount', 'PASS', total_records, 0, 
            'All payment amounts are within reasonable range');
    ELSE
        PERFORM log_validation_result('DATA_QUALITY', 'payment_amount_range', 
            'payment', 'amount', 'WARNING', total_records, violation_count, 
            'Found payments with unusual amounts');
    END IF;
    
    -- Check for recent data activity
    SELECT COUNT(*) INTO total_records
    FROM loan
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';
    
    PERFORM log_validation_result('DATA_QUALITY', 'recent_loan_activity', 
        'loan', 'created_at', 'INFO', total_records, NULL, 
        'Loans created in last 30 days');
        
    SELECT COUNT(*) INTO total_records
    FROM payment
    WHERE created_at >= CURRENT_DATE - INTERVAL '7 days';
    
    PERFORM log_validation_result('DATA_QUALITY', 'recent_payment_activity', 
        'payment', 'created_at', 'INFO', total_records, NULL, 
        'Payments created in last 7 days');
END;
$$ LANGUAGE plpgsql;

-- Function to validate financial calculations
CREATE OR REPLACE FUNCTION validate_financial_calculations()
RETURNS void AS $$
DECLARE
    violation_count INTEGER;
    calculation_errors RECORD;
BEGIN
    RAISE NOTICE '=== VALIDATING FINANCIAL CALCULATIONS ===';
    
    -- Validate payment allocation precision
    WITH precision_check AS (
        SELECT 
            p.id,
            p.amount,
            SUM(pa.allocated_amount) as total_allocated,
            ABS(p.amount - SUM(pa.allocated_amount)) as difference
        FROM payment p
        JOIN payment_allocation pa ON p.id = pa.payment_id
        WHERE p.status = 'completed'
        GROUP BY p.id, p.amount
        HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
    )
    SELECT COUNT(*) INTO violation_count FROM precision_check;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('FINANCIAL_CALC', 'allocation_precision', 
            'payment_allocation', NULL, 'PASS', NULL, 0, 
            'All payment allocations maintain proper precision');
    ELSE
        PERFORM log_validation_result('FINANCIAL_CALC', 'allocation_precision', 
            'payment_allocation', NULL, 'WARNING', NULL, violation_count, 
            'Found allocation precision issues');
    END IF;
    
    -- Validate FX rate reasonableness
    SELECT COUNT(*) INTO violation_count
    FROM fx_rate
    WHERE rate <= 0 OR rate > 1000; -- Extreme exchange rates
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('FINANCIAL_CALC', 'fx_rate_range', 
            'fx_rate', 'rate', 'PASS', NULL, 0, 
            'All FX rates are within reasonable range');
    ELSE
        PERFORM log_validation_result('FINANCIAL_CALC', 'fx_rate_range', 
            'fx_rate', 'rate', 'WARNING', NULL, violation_count, 
            'Found potentially invalid FX rates');
    END IF;
    
    -- Validate amortization schedule calculations
    WITH schedule_validation AS (
        SELECT 
            ap.id,
            ap.loan_id,
            l.principal_amount,
            COUNT(al.id) as line_count,
            SUM(al.amount_principal) as total_principal,
            SUM(al.amount_rc_fee) as total_fees
        FROM amortisation_plan ap
        JOIN loan l ON ap.loan_id = l.id
        LEFT JOIN amortisation_line al ON ap.id = al.plan_id
        WHERE ap.status = 'active'
        GROUP BY ap.id, ap.loan_id, l.principal_amount
    ),
    calculation_issues AS (
        SELECT *
        FROM schedule_validation
        WHERE ABS(principal_amount - total_principal) > 0.01
        OR line_count = 0
    )
    SELECT COUNT(*) INTO violation_count FROM calculation_issues;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('FINANCIAL_CALC', 'amortization_calculations', 
            'amortisation_plan', NULL, 'PASS', NULL, 0, 
            'All amortization calculations are correct');
    ELSE
        PERFORM log_validation_result('FINANCIAL_CALC', 'amortization_calculations', 
            'amortisation_plan', NULL, 'WARNING', NULL, violation_count, 
            'Found amortization calculation issues');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- LENDING-SPECIFIC VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate collections workflow
CREATE OR REPLACE FUNCTION validate_collections_workflow()
RETURNS void AS $$
DECLARE
    violation_count INTEGER;
    total_records INTEGER;
BEGIN
    RAISE NOTICE '=== VALIDATING COLLECTIONS WORKFLOW ===';
    
    -- Check for collections events without valid DPD
    SELECT COUNT(*) INTO violation_count
    FROM collections_event
    WHERE dpd_snapshot < 0;
    
    SELECT COUNT(*) INTO total_records FROM collections_event;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('COLLECTIONS', 'dpd_validity', 
            'collections_event', 'dpd_snapshot', 'PASS', total_records, 0, 
            'All collections events have valid DPD values');
    ELSE
        PERFORM log_validation_result('COLLECTIONS', 'dpd_validity', 
            'collections_event', 'dpd_snapshot', 'FAIL', total_records, violation_count, 
            'Found collections events with negative DPD');
    END IF;
    
    -- Check for escalation consistency
    SELECT COUNT(*) INTO violation_count
    FROM collections_event
    WHERE escalation_trigger IS NOT NULL 
    AND resolution_status IS NULL;
    
    IF violation_count > 0 THEN
        PERFORM log_validation_result('COLLECTIONS', 'escalation_tracking', 
            'collections_event', 'resolution_status', 'WARNING', NULL, violation_count, 
            'Found escalated events without resolution status');
    ELSE
        PERFORM log_validation_result('COLLECTIONS', 'escalation_tracking', 
            'collections_event', 'resolution_status', 'PASS', NULL, 0, 
            'All escalated events have resolution tracking');
    END IF;
    
    -- Check for future action dates in the past
    SELECT COUNT(*) INTO violation_count
    FROM collections_event
    WHERE next_action_date IS NOT NULL 
    AND next_action_date < CURRENT_DATE
    AND resolution_status NOT IN ('resolved', 'closed');
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('COLLECTIONS', 'action_date_validity', 
            'collections_event', 'next_action_date', 'PASS', NULL, 0, 
            'All pending actions have future or current dates');
    ELSE
        PERFORM log_validation_result('COLLECTIONS', 'action_date_validity', 
            'collections_event', 'next_action_date', 'WARNING', NULL, violation_count, 
            'Found overdue collection actions');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to validate loan status consistency
CREATE OR REPLACE FUNCTION validate_loan_status_consistency()
RETURNS void AS $$
DECLARE
    violation_count INTEGER;
    status_issues RECORD;
BEGIN
    RAISE NOTICE '=== VALIDATING LOAN STATUS CONSISTENCY ===';
    
    -- Check for multiple current status records
    WITH current_status_counts AS (
        SELECT 
            loan_id,
            status_type,
            COUNT(*) as count
        FROM loan_status_history
        WHERE effective_through IS NULL
        GROUP BY loan_id, status_type
        HAVING COUNT(*) > 1
    )
    SELECT COUNT(*) INTO violation_count FROM current_status_counts;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('LOAN_STATUS', 'unique_current_status', 
            'loan_status_history', NULL, 'PASS', NULL, 0, 
            'Each loan has unique current status per type');
    ELSE
        PERFORM log_validation_result('LOAN_STATUS', 'unique_current_status', 
            'loan_status_history', NULL, 'FAIL', NULL, violation_count, 
            'Found loans with multiple current status records');
    END IF;
    
    -- Check for status progression logic
    WITH status_progression AS (
        SELECT 
            loan_id,
            status_type,
            status_value,
            effective_from,
            LAG(status_value) OVER (PARTITION BY loan_id, status_type ORDER BY effective_from) as previous_status
        FROM loan_status_history
        WHERE status_type = 'collections_stage'
    ),
    invalid_progression AS (
        SELECT *
        FROM status_progression
        WHERE previous_status IS NOT NULL
        -- Add business logic for valid status progressions
        AND NOT (
            (previous_status = 'current' AND status_value IN ('overdue', 'default_level_1')) OR
            (previous_status = 'overdue' AND status_value IN ('current', 'default_level_1', 'default_level_2')) OR
            (previous_status = 'default_level_1' AND status_value IN ('current', 'overdue', 'default_level_2', 'legal_action'))
        )
    )
    SELECT COUNT(*) INTO violation_count FROM invalid_progression;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('LOAN_STATUS', 'status_progression', 
            'loan_status_history', 'status_value', 'PASS', NULL, 0, 
            'All status progressions follow business rules');
    ELSE
        PERFORM log_validation_result('LOAN_STATUS', 'status_progression', 
            'loan_status_history', 'status_value', 'WARNING', NULL, violation_count, 
            'Found potentially invalid status progressions');
    END IF;
    
    -- Check for loans without current status
    WITH loans_without_status AS (
        SELECT l.id
        FROM loan l
        LEFT JOIN loan_status_history lsh ON l.id = lsh.loan_id AND lsh.effective_through IS NULL
        WHERE lsh.loan_id IS NULL
        AND l.status = 'active'
    )
    SELECT COUNT(*) INTO violation_count FROM loans_without_status;
    
    IF violation_count = 0 THEN
        PERFORM log_validation_result('LOAN_STATUS', 'status_coverage', 
            'loan', NULL, 'PASS', NULL, 0, 
            'All active loans have current status records');
    ELSE
        PERFORM log_validation_result('LOAN_STATUS', 'status_coverage', 
            'loan', NULL, 'WARNING', NULL, violation_count, 
            'Found active loans without current status');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMPREHENSIVE VALIDATION RUNNER
-- ============================================================================

-- Main validation function that runs all checks
CREATE OR REPLACE FUNCTION run_all_validations()
RETURNS TABLE (
    validation_summary TEXT,
    total_checks INTEGER,
    passed_checks INTEGER,
    failed_checks INTEGER,
    warning_checks INTEGER,
    info_checks INTEGER
) AS $$
DECLARE
    start_time TIMESTAMP := CURRENT_TIMESTAMP;
    total_count INTEGER;
    pass_count INTEGER;
    fail_count INTEGER;
    warning_count INTEGER;
    info_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING COMPREHENSIVE DATA VALIDATION ===';
    RAISE NOTICE 'Started at: %', start_time;
    
    -- Clear previous validation results for this run
    DELETE FROM data_validation_log WHERE validation_time >= start_time - INTERVAL '1 minute';
    
    -- Run all validation functions
    PERFORM validate_referential_integrity();
    PERFORM validate_business_rules();
    PERFORM validate_data_quality();
    PERFORM validate_financial_calculations();
    PERFORM validate_collections_workflow();
    PERFORM validate_loan_status_consistency();
    
    -- Calculate summary statistics
    SELECT 
        COUNT(*),
        SUM(CASE WHEN validation_status = 'PASS' THEN 1 ELSE 0 END),
        SUM(CASE WHEN validation_status = 'FAIL' THEN 1 ELSE 0 END),
        SUM(CASE WHEN validation_status = 'WARNING' THEN 1 ELSE 0 END),
        SUM(CASE WHEN validation_status = 'INFO' THEN 1 ELSE 0 END)
    INTO total_count, pass_count, fail_count, warning_count, info_count
    FROM data_validation_log
    WHERE validation_time >= start_time;
    
    RAISE NOTICE '=== VALIDATION COMPLETED ===';
    RAISE NOTICE 'Total: %, Pass: %, Fail: %, Warning: %, Info: %', 
        total_count, pass_count, fail_count, warning_count, info_count;
    
    -- Return summary
    RETURN QUERY SELECT 
        'Data validation completed at ' || CURRENT_TIMESTAMP::TEXT ||
        '. Duration: ' || (CURRENT_TIMESTAMP - start_time)::TEXT,
        total_count,
        pass_count,
        fail_count,
        warning_count,
        info_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MONITORING AND ALERTING FUNCTIONS
-- ============================================================================

-- Function to check for critical data issues
CREATE OR REPLACE FUNCTION check_critical_data_issues()
RETURNS TABLE (
    issue_category TEXT,
    issue_description TEXT,
    severity TEXT,
    affected_records INTEGER,
    recommended_action TEXT
) AS $$
BEGIN
    -- Check for failed validations in the last 24 hours
    RETURN QUERY
    SELECT 
        dvl.validation_type::TEXT,
        dvl.validation_message::TEXT,
        dvl.validation_status::TEXT,
        dvl.violation_count,
        CASE 
            WHEN dvl.validation_status = 'FAIL' THEN 'IMMEDIATE ACTION REQUIRED'
            WHEN dvl.validation_status = 'WARNING' THEN 'INVESTIGATE WITHIN 24 HOURS'
            ELSE 'MONITOR'
        END::TEXT
    FROM data_validation_log dvl
    WHERE dvl.validation_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND dvl.validation_status IN ('FAIL', 'WARNING')
    ORDER BY 
        CASE dvl.validation_status WHEN 'FAIL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
        dvl.validation_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to generate validation report
CREATE OR REPLACE FUNCTION generate_validation_report(
    p_hours_back INTEGER DEFAULT 24
)
RETURNS TABLE (
    report_section TEXT,
    validation_type TEXT,
    validation_name TEXT,
    status TEXT,
    message TEXT,
    execution_time TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'VALIDATION_RESULTS'::TEXT,
        dvl.validation_type,
        dvl.validation_name,
        dvl.validation_status,
        COALESCE(dvl.validation_message, 'No message')::TEXT,
        dvl.validation_time
    FROM data_validation_log dvl
    WHERE dvl.validation_time >= CURRENT_TIMESTAMP - (p_hours_back || ' hours')::INTERVAL
    ORDER BY dvl.validation_time DESC, dvl.validation_type, dvl.validation_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUTOMATED MONITORING SETUP
-- ============================================================================

-- Function to create validation monitoring job (for pg_cron or external scheduler)
CREATE OR REPLACE FUNCTION setup_validation_monitoring()
RETURNS TEXT AS $$
BEGIN
    -- This would typically be set up with pg_cron extension
    -- Example: SELECT cron.schedule('validation-check', '0 */4 * * *', 'SELECT run_all_validations();');
    
    RETURN 'Validation monitoring setup complete. Configure with pg_cron or external scheduler:
    
    -- Run full validation every 4 hours
    SELECT cron.schedule(''full-validation'', ''0 */4 * * *'', ''SELECT run_all_validations();'');
    
    -- Run critical checks every 30 minutes
    SELECT cron.schedule(''critical-checks'', ''*/30 * * * *'', ''SELECT validate_referential_integrity(); SELECT validate_business_rules();'');
    
    -- Generate daily report
    SELECT cron.schedule(''daily-report'', ''0 6 * * *'', ''SELECT * FROM generate_validation_report(24);'');
    ';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to clear old validation logs
CREATE OR REPLACE FUNCTION cleanup_validation_logs(
    p_days_to_keep INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM data_validation_log
    WHERE validation_time < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Cleaned up % old validation log records', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get validation health status
CREATE OR REPLACE FUNCTION get_validation_health_status()
RETURNS TABLE (
    metric_name TEXT,
    metric_value TEXT,
    status TEXT
) AS $$
DECLARE
    recent_fails INTEGER;
    last_run TIMESTAMP;
    total_validations INTEGER;
BEGIN
    -- Check recent failures
    SELECT COUNT(*) INTO recent_fails
    FROM data_validation_log
    WHERE validation_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND validation_status = 'FAIL';
    
    -- Get last validation run
    SELECT MAX(validation_time) INTO last_run
    FROM data_validation_log;
    
    -- Get total validations
    SELECT COUNT(DISTINCT validation_name) INTO total_validations
    FROM data_validation_log
    WHERE validation_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours';
    
    -- Return health metrics
    RETURN QUERY VALUES 
        ('Recent Failures (24h)', recent_fails::TEXT, 
         CASE WHEN recent_fails = 0 THEN 'HEALTHY' WHEN recent_fails < 5 THEN 'WARNING' ELSE 'CRITICAL' END),
        ('Last Validation Run', COALESCE(last_run::TEXT, 'NEVER'), 
         CASE WHEN last_run > CURRENT_TIMESTAMP - INTERVAL '6 hours' THEN 'HEALTHY' 
              WHEN last_run > CURRENT_TIMESTAMP - INTERVAL '24 hours' THEN 'WARNING' 
              ELSE 'CRITICAL' END),
        ('Total Validations (24h)', total_validations::TEXT,
         CASE WHEN total_validations >= 20 THEN 'HEALTHY' 
              WHEN total_validations >= 10 THEN 'WARNING' 
              ELSE 'CRITICAL' END);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLES AND DOCUMENTATION
-- ============================================================================

/*
USAGE EXAMPLES:

1. Run all validations:
   SELECT * FROM run_all_validations();

2. Check for critical issues:
   SELECT * FROM check_critical_data_issues();

3. Generate validation report:
   SELECT * FROM generate_validation_report(48); -- Last 48 hours

4. Check system health:
   SELECT * FROM get_validation_health_status();

5. Run individual validation types:
   SELECT validate_referential_integrity();
   SELECT validate_business_rules();
   SELECT validate_data_quality();

6. Clean up old logs:
   SELECT cleanup_validation_logs(7); -- Keep only last 7 days

7. View recent validation results:
   SELECT * FROM data_validation_log 
   WHERE validation_time >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
   ORDER BY validation_time DESC;

MONITORING SETUP:
- Set up pg_cron jobs using setup_validation_monitoring()
- Configure external monitoring tools to query check_critical_data_issues()
- Set up alerts based on get_validation_health_status() results
- Schedule regular cleanup using cleanup_validation_logs()
*/

RAISE NOTICE '';
RAISE NOTICE '=== DATA VALIDATION FRAMEWORK INSTALLED ===';
RAISE NOTICE 'Run: SELECT * FROM run_all_validations(); to start validation';
RAISE NOTICE 'Run: SELECT setup_validation_monitoring(); for monitoring setup';
RAISE NOTICE '';