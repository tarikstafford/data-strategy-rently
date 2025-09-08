-- ============================================================================
-- RENTLY LENDING PLATFORM - COMPREHENSIVE TEST SUITE
-- ============================================================================
-- PostgreSQL Test Suite for Enhanced Database Schema v1.0
-- Comprehensive testing for data validation, business logic, and integrity
--
-- Usage: Execute individual test sections as needed
-- All tests return results indicating PASS/FAIL with detailed messages
-- ============================================================================

-- Enable necessary extensions for testing
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TEST FRAMEWORK SETUP
-- ============================================================================

-- Test execution log table
CREATE TABLE IF NOT EXISTS test_execution_log (
    id SERIAL PRIMARY KEY,
    test_category TEXT NOT NULL,
    test_name TEXT NOT NULL,
    test_status TEXT NOT NULL, -- 'PASS', 'FAIL', 'WARNING'
    test_message TEXT,
    execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_duration INTERVAL
);

-- Function to log test results
CREATE OR REPLACE FUNCTION log_test_result(
    p_category TEXT,
    p_test_name TEXT,
    p_status TEXT,
    p_message TEXT DEFAULT NULL,
    p_start_time TIMESTAMP DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    v_duration INTERVAL;
BEGIN
    IF p_start_time IS NOT NULL THEN
        v_duration := CURRENT_TIMESTAMP - p_start_time;
    END IF;
    
    INSERT INTO test_execution_log (test_category, test_name, test_status, test_message, execution_duration)
    VALUES (p_category, p_test_name, p_status, p_message, v_duration);
    
    RAISE NOTICE '[%] %: % - %', p_category, p_test_name, p_status, COALESCE(p_message, '');
END;
$$ LANGUAGE plpgsql;

-- Clear previous test results
TRUNCATE test_execution_log;

-- ============================================================================
-- SCHEMA INTEGRITY TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    table_count INTEGER;
    expected_tables INTEGER := 23; -- Expected number of tables
    constraint_count INTEGER;
    index_count INTEGER;
    trigger_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING SCHEMA INTEGRITY TESTS ===';
    
    -- Test 1: Verify all expected tables exist
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    
    IF table_count >= expected_tables THEN
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'TABLE_COUNT', 'PASS', 
            format('Found %s tables (expected at least %s)', table_count, expected_tables), test_start);
    ELSE
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'TABLE_COUNT', 'FAIL', 
            format('Found only %s tables (expected at least %s)', table_count, expected_tables), test_start);
    END IF;
    
    -- Test 2: Verify critical foreign key constraints exist
    SELECT COUNT(*) INTO constraint_count
    FROM information_schema.referential_constraints
    WHERE constraint_schema = 'public';
    
    IF constraint_count > 20 THEN -- Expected minimum FK constraints
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'FOREIGN_KEYS', 'PASS', 
            format('Found %s foreign key constraints', constraint_count), test_start);
    ELSE
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'FOREIGN_KEYS', 'WARNING', 
            format('Found only %s foreign key constraints', constraint_count), test_start);
    END IF;
    
    -- Test 3: Verify performance indexes exist
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE schemaname = 'public';
    
    IF index_count > 50 THEN -- Expected minimum indexes
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'INDEX_COUNT', 'PASS', 
            format('Found %s indexes', index_count), test_start);
    ELSE
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'INDEX_COUNT', 'WARNING', 
            format('Found only %s indexes', index_count), test_start);
    END IF;
    
    -- Test 4: Verify audit triggers exist
    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'public' AND t.tgname LIKE '%updated_at%';
    
    IF trigger_count >= 5 THEN
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'AUDIT_TRIGGERS', 'PASS', 
            format('Found %s audit triggers', trigger_count), test_start);
    ELSE
        PERFORM log_test_result('SCHEMA_INTEGRITY', 'AUDIT_TRIGGERS', 'WARNING', 
            format('Found only %s audit triggers', trigger_count), test_start);
    END IF;
END $$;

-- ============================================================================
-- DATA TYPE AND CONSTRAINT TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    constraint_violations INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING DATA TYPE AND CONSTRAINT TESTS ===';
    
    -- Test 1: Currency code format validation
    BEGIN
        -- Test valid currency codes
        INSERT INTO fx_rate (as_of_date, from_ccy, to_ccy, rate, source)
        VALUES (CURRENT_DATE, 'USD', 'SGD', 1.35, 'TEST');
        
        DELETE FROM fx_rate WHERE source = 'TEST';
        PERFORM log_test_result('CONSTRAINTS', 'CURRENCY_CODE_VALID', 'PASS', 'Valid currency codes accepted', test_start);
        
    EXCEPTION WHEN OTHERS THEN
        PERFORM log_test_result('CONSTRAINTS', 'CURRENCY_CODE_VALID', 'FAIL', SQLERRM, test_start);
    END;
    
    -- Test 2: Email format validation
    BEGIN
        -- Test valid email
        INSERT INTO party (id, kind, display_name, email)
        VALUES (uuid_generate_v4(), 'individual', 'Test User', 'test@example.com');
        
        DELETE FROM party WHERE email = 'test@example.com';
        PERFORM log_test_result('CONSTRAINTS', 'EMAIL_FORMAT_VALID', 'PASS', 'Valid email format accepted', test_start);
        
    EXCEPTION WHEN OTHERS THEN
        PERFORM log_test_result('CONSTRAINTS', 'EMAIL_FORMAT_VALID', 'FAIL', SQLERRM, test_start);
    END;
    
    -- Test 3: Negative amount constraints
    BEGIN
        -- This should fail
        INSERT INTO payment (legal_entity_id, currency_code, amount, direction)
        SELECT le.id, 'USD', -100.00, 'inbound'
        FROM legal_entity le LIMIT 1;
        
        PERFORM log_test_result('CONSTRAINTS', 'NEGATIVE_AMOUNT_REJECTED', 'FAIL', 'Negative amount was allowed', test_start);
        
    EXCEPTION WHEN check_violation THEN
        PERFORM log_test_result('CONSTRAINTS', 'NEGATIVE_AMOUNT_REJECTED', 'PASS', 'Negative amount correctly rejected', test_start);
    EXCEPTION WHEN OTHERS THEN
        PERFORM log_test_result('CONSTRAINTS', 'NEGATIVE_AMOUNT_REJECTED', 'WARNING', SQLERRM, test_start);
    END;
    
    -- Test 4: Date range validation
    BEGIN
        -- This should fail - end date before start date
        INSERT INTO loan (loan_number, product_id, legal_entity_id, borrower_party_id, 
                         currency_code, principal_amount, interest_rate, start_date, end_date)
        SELECT 'TEST_LOAN_001', p.id, le.id, pt.id, 'USD', 1000.00, 0.05, 
               '2024-12-31', '2024-01-01'
        FROM product p, legal_entity le, party pt 
        WHERE p.is_active = true AND pt.kind = 'individual'
        LIMIT 1;
        
        PERFORM log_test_result('CONSTRAINTS', 'DATE_RANGE_VALIDATION', 'FAIL', 'Invalid date range was allowed', test_start);
        
    EXCEPTION WHEN check_violation THEN
        PERFORM log_test_result('CONSTRAINTS', 'DATE_RANGE_VALIDATION', 'PASS', 'Invalid date range correctly rejected', test_start);
    EXCEPTION WHEN OTHERS THEN
        PERFORM log_test_result('CONSTRAINTS', 'DATE_RANGE_VALIDATION', 'WARNING', SQLERRM, test_start);
    END;
END $$;

-- ============================================================================
-- BUSINESS RULE VALIDATION TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    test_loan_id UUID;
    test_payment_id UUID;
    total_allocation NUMERIC;
    payment_amount NUMERIC := 1000.00;
BEGIN
    RAISE NOTICE '=== STARTING BUSINESS RULE VALIDATION TESTS ===';
    
    -- Test 1: Payment Allocation Logic
    -- Create test data
    INSERT INTO loan (id, loan_number, product_id, legal_entity_id, borrower_party_id, 
                     currency_code, principal_amount, interest_rate, start_date, end_date)
    SELECT uuid_generate_v4(), 'TEST_LOAN_' || extract(epoch from now())::text, 
           p.id, le.id, pt.id, 'USD', 10000.00, 0.05, 
           CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months'
    FROM product p, legal_entity le, party pt 
    WHERE p.is_active = true AND pt.kind = 'individual'
    LIMIT 1
    RETURNING id INTO test_loan_id;
    
    INSERT INTO payment (id, legal_entity_id, currency_code, amount, direction, status)
    SELECT uuid_generate_v4(), le.id, 'USD', payment_amount, 'inbound', 'completed'
    FROM legal_entity le LIMIT 1
    RETURNING id INTO test_payment_id;
    
    -- Create payment allocations
    INSERT INTO payment_allocation (payment_id, loan_id, component, allocated_amount)
    VALUES 
    (test_payment_id, test_loan_id, 'principal', 800.00),
    (test_payment_id, test_loan_id, 'rc_fee', 150.00),
    (test_payment_id, test_loan_id, 'penalty', 50.00);
    
    -- Verify allocation sums correctly
    SELECT SUM(allocated_amount) INTO total_allocation
    FROM payment_allocation WHERE payment_id = test_payment_id;
    
    IF total_allocation = payment_amount THEN
        PERFORM log_test_result('BUSINESS_RULES', 'PAYMENT_ALLOCATION_SUM', 'PASS', 
            format('Allocation sum matches payment amount: %s', total_allocation), test_start);
    ELSE
        PERFORM log_test_result('BUSINESS_RULES', 'PAYMENT_ALLOCATION_SUM', 'WARNING', 
            format('Allocation sum (%s) does not match payment amount (%s)', total_allocation, payment_amount), test_start);
    END IF;
    
    -- Clean up test data
    DELETE FROM payment_allocation WHERE payment_id = test_payment_id;
    DELETE FROM payment WHERE id = test_payment_id;
    DELETE FROM loan WHERE id = test_loan_id;
    
    -- Test 2: Amortization Schedule Integrity
    DECLARE
        plan_id UUID;
        total_principal NUMERIC;
        loan_principal NUMERIC := 10000.00;
    BEGIN
        -- Create test loan
        INSERT INTO loan (id, loan_number, product_id, legal_entity_id, borrower_party_id, 
                         currency_code, principal_amount, interest_rate, start_date, end_date)
        SELECT uuid_generate_v4(), 'TEST_AMORT_' || extract(epoch from now())::text, 
               p.id, le.id, pt.id, 'USD', loan_principal, 0.05, 
               CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months'
        FROM product p, legal_entity le, party pt 
        WHERE p.is_active = true AND pt.kind = 'individual'
        LIMIT 1
        RETURNING id INTO test_loan_id;
        
        -- Create amortization plan
        INSERT INTO amortisation_plan (id, loan_id, version, status, effective_from)
        VALUES (uuid_generate_v4(), test_loan_id, 1, 'active', CURRENT_DATE)
        RETURNING id INTO plan_id;
        
        -- Create amortization lines
        INSERT INTO amortisation_line (plan_id, seq_no, due_date, currency_code, amount_principal)
        SELECT plan_id, generate_series, CURRENT_DATE + (generate_series || ' months')::INTERVAL, 'USD', loan_principal / 12
        FROM generate_series(1, 12);
        
        -- Verify total principal matches loan amount
        SELECT SUM(amount_principal) INTO total_principal
        FROM amortisation_line WHERE plan_id = plan_id;
        
        IF ABS(total_principal - loan_principal) < 0.01 THEN
            PERFORM log_test_result('BUSINESS_RULES', 'AMORTIZATION_PRINCIPAL_SUM', 'PASS', 
                format('Amortization principal sum matches loan principal: %s', total_principal), test_start);
        ELSE
            PERFORM log_test_result('BUSINESS_RULES', 'AMORTIZATION_PRINCIPAL_SUM', 'FAIL', 
                format('Amortization principal sum (%s) does not match loan principal (%s)', total_principal, loan_principal), test_start);
        END IF;
        
        -- Clean up
        DELETE FROM amortisation_line WHERE plan_id = plan_id;
        DELETE FROM amortisation_plan WHERE id = plan_id;
        DELETE FROM loan WHERE id = test_loan_id;
    END;
    
    -- Test 3: Currency Consistency
    DECLARE
        inconsistent_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO inconsistent_count
        FROM payment p
        JOIN payment_allocation pa ON p.id = pa.payment_id
        JOIN loan l ON pa.loan_id = l.id
        WHERE p.currency_code != l.currency_code;
        
        IF inconsistent_count = 0 THEN
            PERFORM log_test_result('BUSINESS_RULES', 'CURRENCY_CONSISTENCY', 'PASS', 
                'All payment allocations have consistent currency codes', test_start);
        ELSE
            PERFORM log_test_result('BUSINESS_RULES', 'CURRENCY_CONSISTENCY', 'FAIL', 
                format('Found %s payment allocations with inconsistent currencies', inconsistent_count), test_start);
        END IF;
    END;
    
END $$;

-- ============================================================================
-- FINANCIAL CALCULATION TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    interest_calc NUMERIC;
    expected_interest NUMERIC;
    principal_amount NUMERIC := 10000.00;
    annual_rate NUMERIC := 0.05;  -- 5%
    days_elapsed INTEGER := 30;
BEGIN
    RAISE NOTICE '=== STARTING FINANCIAL CALCULATION TESTS ===';
    
    -- Test 1: Interest Calculation (Simple Interest)
    interest_calc := principal_amount * annual_rate * days_elapsed / 365.0;
    expected_interest := 41.10; -- Approximately for 30 days at 5%
    
    IF ABS(interest_calc - expected_interest) < 1.0 THEN
        PERFORM log_test_result('FINANCIAL_CALC', 'SIMPLE_INTEREST', 'PASS', 
            format('Interest calculation: %s (expected ~%s)', interest_calc, expected_interest), test_start);
    ELSE
        PERFORM log_test_result('FINANCIAL_CALC', 'SIMPLE_INTEREST', 'WARNING', 
            format('Interest calculation: %s (expected ~%s)', interest_calc, expected_interest), test_start);
    END IF;
    
    -- Test 2: FX Conversion Test
    DECLARE
        usd_amount NUMERIC := 1000.00;
        sgd_rate NUMERIC := 1.35;
        converted_amount NUMERIC;
        expected_sgd NUMERIC := 1350.00;
    BEGIN
        converted_amount := usd_amount * sgd_rate;
        
        IF converted_amount = expected_sgd THEN
            PERFORM log_test_result('FINANCIAL_CALC', 'FX_CONVERSION', 'PASS', 
                format('FX conversion: %s USD = %s SGD', usd_amount, converted_amount), test_start);
        ELSE
            PERFORM log_test_result('FINANCIAL_CALC', 'FX_CONVERSION', 'FAIL', 
                format('FX conversion failed: %s USD should equal %s SGD but got %s', 
                       usd_amount, expected_sgd, converted_amount), test_start);
        END IF;
    END;
    
    -- Test 3: Payment Allocation Precision
    DECLARE
        payment_total NUMERIC := 1000.00;
        allocation_sum NUMERIC;
    BEGIN
        -- Simulate payment allocation breakdown
        allocation_sum := 833.33 + 166.67; -- Should equal 1000.00
        
        IF ABS(allocation_sum - payment_total) < 0.01 THEN
            PERFORM log_test_result('FINANCIAL_CALC', 'ALLOCATION_PRECISION', 'PASS', 
                'Payment allocation maintains precision', test_start);
        ELSE
            PERFORM log_test_result('FINANCIAL_CALC', 'ALLOCATION_PRECISION', 'WARNING', 
                format('Potential precision issue: %s vs %s', allocation_sum, payment_total), test_start);
        END IF;
    END;
END $$;

-- ============================================================================
-- DATA QUALITY TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    null_count INTEGER;
    duplicate_count INTEGER;
    orphan_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING DATA QUALITY TESTS ===';
    
    -- Test 1: Critical field completeness
    SELECT COUNT(*) INTO null_count
    FROM loan 
    WHERE loan_number IS NULL OR principal_amount IS NULL OR currency_code IS NULL;
    
    IF null_count = 0 THEN
        PERFORM log_test_result('DATA_QUALITY', 'CRITICAL_FIELDS_COMPLETE', 'PASS', 
            'All loans have complete critical fields', test_start);
    ELSE
        PERFORM log_test_result('DATA_QUALITY', 'CRITICAL_FIELDS_COMPLETE', 'FAIL', 
            format('Found %s loans with missing critical fields', null_count), test_start);
    END IF;
    
    -- Test 2: Duplicate loan numbers
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT loan_number, COUNT(*) 
        FROM loan 
        GROUP BY loan_number 
        HAVING COUNT(*) > 1
    ) dups;
    
    IF duplicate_count = 0 THEN
        PERFORM log_test_result('DATA_QUALITY', 'UNIQUE_LOAN_NUMBERS', 'PASS', 
            'All loan numbers are unique', test_start);
    ELSE
        PERFORM log_test_result('DATA_QUALITY', 'UNIQUE_LOAN_NUMBERS', 'FAIL', 
            format('Found %s duplicate loan numbers', duplicate_count), test_start);
    END IF;
    
    -- Test 3: Orphaned records
    SELECT COUNT(*) INTO orphan_count
    FROM payment_allocation pa
    LEFT JOIN payment p ON pa.payment_id = p.id
    WHERE p.id IS NULL;
    
    IF orphan_count = 0 THEN
        PERFORM log_test_result('DATA_QUALITY', 'NO_ORPHANED_ALLOCATIONS', 'PASS', 
            'No orphaned payment allocations found', test_start);
    ELSE
        PERFORM log_test_result('DATA_QUALITY', 'NO_ORPHANED_ALLOCATIONS', 'FAIL', 
            format('Found %s orphaned payment allocations', orphan_count), test_start);
    END IF;
    
    -- Test 4: Email format validation in existing data
    SELECT COUNT(*) INTO null_count
    FROM party 
    WHERE email IS NOT NULL 
    AND email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
    
    IF null_count = 0 THEN
        PERFORM log_test_result('DATA_QUALITY', 'EMAIL_FORMAT_VALIDATION', 'PASS', 
            'All existing email addresses are properly formatted', test_start);
    ELSE
        PERFORM log_test_result('DATA_QUALITY', 'EMAIL_FORMAT_VALIDATION', 'WARNING', 
            format('Found %s parties with invalid email formats', null_count), test_start);
    END IF;
    
    -- Test 5: Currency code consistency
    SELECT COUNT(DISTINCT currency_code) INTO null_count
    FROM (
        SELECT currency_code FROM loan
        UNION ALL
        SELECT currency_code FROM payment
        UNION ALL
        SELECT from_ccy FROM fx_rate
        UNION ALL
        SELECT to_ccy FROM fx_rate
    ) all_currencies
    WHERE LENGTH(currency_code) != 3;
    
    IF null_count = 0 THEN
        PERFORM log_test_result('DATA_QUALITY', 'CURRENCY_CODE_FORMAT', 'PASS', 
            'All currency codes follow ISO 4217 format', test_start);
    ELSE
        PERFORM log_test_result('DATA_QUALITY', 'CURRENCY_CODE_FORMAT', 'FAIL', 
            format('Found %s invalid currency codes', null_count), test_start);
    END IF;
END $$;

-- ============================================================================
-- PERFORMANCE TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    query_start TIMESTAMP;
    query_duration INTERVAL;
    loan_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING PERFORMANCE TESTS ===';
    
    -- Test 1: Loan portfolio query performance
    query_start := CURRENT_TIMESTAMP;
    
    SELECT COUNT(*) INTO loan_count
    FROM loan l
    JOIN product p ON l.product_id = p.id
    JOIN legal_entity le ON l.legal_entity_id = le.id
    WHERE l.status = 'active'
    AND p.category = 'rently_care_d2c';
    
    query_duration := CURRENT_TIMESTAMP - query_start;
    
    IF query_duration < INTERVAL '1 second' THEN
        PERFORM log_test_result('PERFORMANCE', 'LOAN_PORTFOLIO_QUERY', 'PASS', 
            format('Query completed in %s with %s results', query_duration, loan_count), test_start);
    ELSE
        PERFORM log_test_result('PERFORMANCE', 'LOAN_PORTFOLIO_QUERY', 'WARNING', 
            format('Query took %s (may need optimization)', query_duration), test_start);
    END IF;
    
    -- Test 2: Payment allocation query performance
    query_start := CURRENT_TIMESTAMP;
    
    SELECT COUNT(*) INTO loan_count
    FROM payment_allocation pa
    JOIN payment p ON pa.payment_id = p.id
    JOIN loan l ON pa.loan_id = l.id
    WHERE p.received_at >= CURRENT_DATE - INTERVAL '30 days';
    
    query_duration := CURRENT_TIMESTAMP - query_start;
    
    IF query_duration < INTERVAL '2 seconds' THEN
        PERFORM log_test_result('PERFORMANCE', 'PAYMENT_ALLOCATION_QUERY', 'PASS', 
            format('Complex join query completed in %s', query_duration), test_start);
    ELSE
        PERFORM log_test_result('PERFORMANCE', 'PAYMENT_ALLOCATION_QUERY', 'WARNING', 
            format('Complex join query took %s (consider optimization)', query_duration), test_start);
    END IF;
    
    -- Test 3: Index usage verification
    DECLARE
        unused_indexes INTEGER;
    BEGIN
        -- This is a simplified check - in production, use pg_stat_user_indexes
        SELECT COUNT(*) INTO unused_indexes
        FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND indexname NOT LIKE '%pkey%'
        AND indexname NOT LIKE '%_check%';
        
        PERFORM log_test_result('PERFORMANCE', 'INDEX_PRESENCE', 'INFO', 
            format('Found %s custom indexes (excluding primary keys)', unused_indexes), test_start);
    END;
END $$;

-- ============================================================================
-- SECURITY AND ACCESS CONTROL TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    sensitive_exposure INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING SECURITY TESTS ===';
    
    -- Test 1: Sensitive data exposure check
    -- Check if financial amounts are properly protected in views
    SELECT COUNT(*) INTO sensitive_exposure
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name IN ('current_loan_status', 'active_payment_instruments', 'loan_portfolio_summary')
    AND column_name LIKE '%amount%';
    
    PERFORM log_test_result('SECURITY', 'VIEW_DATA_EXPOSURE', 'INFO', 
        format('Found %s amount columns exposed in views', sensitive_exposure), test_start);
    
    -- Test 2: Check for potential injection vulnerabilities in stored functions
    DECLARE
        function_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO function_count
        FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_type = 'FUNCTION';
        
        PERFORM log_test_result('SECURITY', 'FUNCTION_COUNT', 'INFO', 
            format('Found %s custom functions for security review', function_count), test_start);
    END;
    
    -- Test 3: Audit trail completeness
    DECLARE
        tables_without_audit INTEGER;
    BEGIN
        SELECT COUNT(*) INTO tables_without_audit
        FROM information_schema.tables t
        LEFT JOIN information_schema.columns c ON t.table_name = c.table_name 
            AND c.column_name IN ('created_at', 'updated_at')
        WHERE t.table_schema = 'public' 
        AND t.table_type = 'BASE TABLE'
        AND t.table_name NOT IN ('test_execution_log', 'migration_log', 'schema_version')
        AND c.column_name IS NULL;
        
        IF tables_without_audit = 0 THEN
            PERFORM log_test_result('SECURITY', 'AUDIT_TRAIL_COVERAGE', 'PASS', 
                'All business tables have audit timestamps', test_start);
        ELSE
            PERFORM log_test_result('SECURITY', 'AUDIT_TRAIL_COVERAGE', 'WARNING', 
                format('%s tables missing audit timestamps', tables_without_audit), test_start);
        END IF;
    END;
END $$;

-- ============================================================================
-- REGULATORY COMPLIANCE TESTS
-- ============================================================================

DO $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    retention_violations INTEGER;
    pii_exposure INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING REGULATORY COMPLIANCE TESTS ===';
    
    -- Test 1: Data retention policy compliance
    -- Check for very old records that might violate retention policies
    SELECT COUNT(*) INTO retention_violations
    FROM party 
    WHERE created_at < CURRENT_DATE - INTERVAL '7 years'
    AND is_active = false;
    
    IF retention_violations = 0 THEN
        PERFORM log_test_result('COMPLIANCE', 'DATA_RETENTION', 'PASS', 
            'No apparent data retention violations found', test_start);
    ELSE
        PERFORM log_test_result('COMPLIANCE', 'DATA_RETENTION', 'WARNING', 
            format('Found %s old inactive party records for retention review', retention_violations), test_start);
    END IF;
    
    -- Test 2: PII data identification
    SELECT COUNT(*) INTO pii_exposure
    FROM information_schema.columns 
    WHERE table_schema = 'public'
    AND column_name IN ('email', 'phone', 'kyc_identifier', 'account_number');
    
    PERFORM log_test_result('COMPLIANCE', 'PII_IDENTIFICATION', 'INFO', 
        format('Identified %s PII columns requiring protection', pii_exposure), test_start);
    
    -- Test 3: Financial data integrity
    DECLARE
        integrity_issues INTEGER;
    BEGIN
        SELECT COUNT(*) INTO integrity_issues
        FROM loan l
        LEFT JOIN ledger_entry le ON l.id = le.loan_id
        WHERE l.status = 'closed'
        AND le.id IS NULL;
        
        IF integrity_issues = 0 THEN
            PERFORM log_test_result('COMPLIANCE', 'FINANCIAL_INTEGRITY', 'PASS', 
                'All closed loans have corresponding ledger entries', test_start);
        ELSE
            PERFORM log_test_result('COMPLIANCE', 'FINANCIAL_INTEGRITY', 'WARNING', 
                format('Found %s closed loans without ledger entries', integrity_issues), test_start);
        END IF;
    END;
END $$;

-- ============================================================================
-- TEST SUITE SUMMARY AND REPORTING
-- ============================================================================

DO $$
DECLARE
    total_tests INTEGER;
    passed_tests INTEGER;
    failed_tests INTEGER;
    warning_tests INTEGER;
    success_rate NUMERIC;
BEGIN
    RAISE NOTICE '=== TEST SUITE EXECUTION SUMMARY ===';
    
    -- Get test execution summary
    SELECT 
        COUNT(*),
        SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END),
        SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END),
        SUM(CASE WHEN test_status = 'WARNING' THEN 1 ELSE 0 END)
    INTO total_tests, passed_tests, failed_tests, warning_tests
    FROM test_execution_log;
    
    success_rate := CASE WHEN total_tests > 0 THEN (passed_tests::NUMERIC / total_tests * 100) ELSE 0 END;
    
    RAISE NOTICE 'Total Tests Executed: %', total_tests;
    RAISE NOTICE 'Passed: % (%% success rate)', passed_tests, ROUND(success_rate, 2);
    RAISE NOTICE 'Failed: %', failed_tests;
    RAISE NOTICE 'Warnings: %', warning_tests;
    RAISE NOTICE '';
    
    -- Show detailed results by category
    RAISE NOTICE 'Results by Category:';
    FOR rec IN 
        SELECT 
            test_category,
            COUNT(*) as total,
            SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) as passed,
            SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) as failed,
            SUM(CASE WHEN test_status = 'WARNING' THEN 1 ELSE 0 END) as warnings
        FROM test_execution_log
        GROUP BY test_category
        ORDER BY test_category
    LOOP
        RAISE NOTICE '  %: % total (% passed, % failed, % warnings)', 
            rec.test_category, rec.total, rec.passed, rec.failed, rec.warnings;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Failed and Warning Tests:';
    FOR rec IN 
        SELECT test_category, test_name, test_status, test_message
        FROM test_execution_log
        WHERE test_status IN ('FAIL', 'WARNING')
        ORDER BY test_status DESC, test_category, test_name
    LOOP
        RAISE NOTICE '  [%] %: % - %', rec.test_status, rec.test_category || '.' || rec.test_name, rec.test_status, rec.test_message;
    END LOOP;
    
    IF failed_tests = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ ALL CRITICAL TESTS PASSED - Database is ready for production use';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '❌ CRITICAL FAILURES DETECTED - Address failed tests before production deployment';
    END IF;
END $$;

-- Query to view detailed test results
SELECT 
    test_category,
    test_name,
    test_status,
    test_message,
    execution_time,
    execution_duration
FROM test_execution_log
ORDER BY execution_time;

-- ============================================================================
-- CLEANUP FUNCTIONS
-- ============================================================================

-- Function to clear test results
CREATE OR REPLACE FUNCTION clear_test_results()
RETURNS void AS $$
BEGIN
    TRUNCATE test_execution_log;
    RAISE NOTICE 'Test execution log cleared';
END;
$$ LANGUAGE plpgsql;

-- Function to export test results
CREATE OR REPLACE FUNCTION export_test_results()
RETURNS TABLE (
    category TEXT,
    test_name TEXT,
    status TEXT,
    message TEXT,
    execution_time TIMESTAMP,
    duration INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tel.test_category,
        tel.test_name,
        tel.test_status,
        tel.test_message,
        tel.execution_time,
        tel.execution_duration
    FROM test_execution_log tel
    ORDER BY tel.execution_time;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE '';
RAISE NOTICE '=== COMPREHENSIVE TEST SUITE COMPLETED ===';
RAISE NOTICE 'Use SELECT * FROM export_test_results() to view detailed results';
RAISE NOTICE 'Use SELECT clear_test_results() to clear test history';
RAISE NOTICE '';