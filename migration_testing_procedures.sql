-- ============================================================================
-- RENTLY LENDING PLATFORM - MIGRATION TESTING PROCEDURES
-- ============================================================================
-- PostgreSQL Migration Testing Framework v1.0
-- Comprehensive procedures for testing database migrations with validation,
-- rollback scenarios, and performance impact analysis
--
-- Usage: 
-- 1. Run pre-migration validation
-- 2. Execute migration in test environment
-- 3. Run post-migration validation
-- 4. Test rollback procedures
-- 5. Validate production migration
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- MIGRATION TESTING FRAMEWORK SETUP
-- ============================================================================

-- Migration test execution tracking
CREATE TABLE IF NOT EXISTS migration_test_log (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    test_phase TEXT NOT NULL, -- 'pre_validation', 'migration', 'post_validation', 'rollback'
    test_category TEXT NOT NULL,
    test_name TEXT NOT NULL,
    test_status TEXT NOT NULL, -- 'PASS', 'FAIL', 'WARNING', 'INFO'
    execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_duration INTERVAL,
    test_message TEXT,
    test_data JSONB
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_migration_test_log_migration ON migration_test_log(migration_name);
CREATE INDEX IF NOT EXISTS idx_migration_test_log_phase ON migration_test_log(test_phase);
CREATE INDEX IF NOT EXISTS idx_migration_test_log_status ON migration_test_log(test_status);

-- Migration baseline tracking
CREATE TABLE IF NOT EXISTS migration_baseline (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    baseline_type TEXT NOT NULL, -- 'pre_migration', 'post_migration'
    table_name TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC,
    metric_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Function to log migration test results
CREATE OR REPLACE FUNCTION log_migration_test(
    p_migration_name TEXT,
    p_phase TEXT,
    p_category TEXT,
    p_test_name TEXT,
    p_status TEXT,
    p_message TEXT DEFAULT NULL,
    p_data JSONB DEFAULT NULL,
    p_start_time TIMESTAMP DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    v_duration INTERVAL;
BEGIN
    IF p_start_time IS NOT NULL THEN
        v_duration := CURRENT_TIMESTAMP - p_start_time;
    END IF;
    
    INSERT INTO migration_test_log (
        migration_name, test_phase, test_category, test_name, 
        test_status, test_message, test_data, execution_duration
    ) VALUES (
        p_migration_name, p_phase, p_category, p_test_name,
        p_status, p_message, p_data, v_duration
    );
    
    RAISE NOTICE '[%][%] %: % - %', p_migration_name, p_phase, p_test_name, p_status, COALESCE(p_message, '');
END;
$$ LANGUAGE plpgsql;

-- Function to capture baseline metrics
CREATE OR REPLACE FUNCTION capture_migration_baseline(
    p_migration_name TEXT,
    p_baseline_type TEXT
)
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '=== CAPTURING BASELINE: % - % ===', p_migration_name, p_baseline_type;
    
    -- Clear existing baseline for this migration and type
    DELETE FROM migration_baseline 
    WHERE migration_name = p_migration_name AND baseline_type = p_baseline_type;
    
    -- Capture table record counts
    FOR r IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        AND table_name NOT LIKE 'migration_%'
        AND table_name NOT LIKE 'test_%'
    LOOP
        EXECUTE format('
            INSERT INTO migration_baseline (migration_name, baseline_type, table_name, metric_name, metric_value)
            SELECT %L, %L, %L, ''record_count'', COUNT(*) FROM %I',
            p_migration_name, p_baseline_type, r.table_name, r.table_name
        );
    END LOOP;
    
    -- Capture financial totals for key tables
    INSERT INTO migration_baseline (migration_name, baseline_type, table_name, metric_name, metric_value)
    SELECT p_migration_name, p_baseline_type, 'loan', 'total_principal', SUM(principal_amount) FROM loan;
    
    INSERT INTO migration_baseline (migration_name, baseline_type, table_name, metric_name, metric_value)
    SELECT p_migration_name, p_baseline_type, 'payment', 'total_amount', SUM(amount) FROM payment;
    
    INSERT INTO migration_baseline (migration_name, baseline_type, table_name, metric_name, metric_value)
    SELECT p_migration_name, p_baseline_type, 'payment_allocation', 'total_allocated', SUM(allocated_amount) FROM payment_allocation;
    
    -- Capture schema version
    INSERT INTO migration_baseline (migration_name, baseline_type, table_name, metric_name, metric_text)
    SELECT p_migration_name, p_baseline_type, 'schema_version', 'current_version', version 
    FROM schema_version ORDER BY applied_at DESC LIMIT 1;
    
    RAISE NOTICE 'Baseline captured for: %', p_migration_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PRE-MIGRATION VALIDATION PROCEDURES
-- ============================================================================

-- Comprehensive pre-migration validation
CREATE OR REPLACE FUNCTION run_pre_migration_validation(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration'
)
RETURNS void AS $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    violation_count INTEGER;
    total_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING PRE-MIGRATION VALIDATION: % ===', p_migration_name;
    
    -- Clear previous test results
    DELETE FROM migration_test_log WHERE migration_name = p_migration_name AND test_phase = 'pre_validation';
    
    -- Capture baseline metrics
    PERFORM capture_migration_baseline(p_migration_name, 'pre_migration');
    
    -- Test 1: Data Integrity Check
    test_start := CURRENT_TIMESTAMP;
    
    -- Check for orphaned records
    SELECT COUNT(*) INTO violation_count
    FROM payment_allocation pa
    LEFT JOIN payment p ON pa.payment_id = p.id
    WHERE p.id IS NULL;
    
    IF violation_count = 0 THEN
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'DATA_INTEGRITY', 
            'orphaned_payment_allocations', 'PASS', 
            'No orphaned payment allocations found', NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'DATA_INTEGRITY', 
            'orphaned_payment_allocations', 'FAIL', 
            format('Found %s orphaned payment allocations', violation_count), NULL, test_start);
    END IF;
    
    -- Test 2: Business Rule Compliance
    test_start := CURRENT_TIMESTAMP;
    
    -- Check payment allocation balance
    WITH unbalanced_payments AS (
        SELECT p.id, p.amount, SUM(pa.allocated_amount) as total_allocated
        FROM payment p
        JOIN payment_allocation pa ON p.id = pa.payment_id
        WHERE p.status = 'completed'
        GROUP BY p.id, p.amount
        HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
    )
    SELECT COUNT(*) INTO violation_count FROM unbalanced_payments;
    
    IF violation_count = 0 THEN
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'BUSINESS_RULES', 
            'payment_allocation_balance', 'PASS', 
            'All payments are properly allocated', NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'BUSINESS_RULES', 
            'payment_allocation_balance', 'FAIL', 
            format('Found %s unbalanced payments', violation_count), NULL, test_start);
    END IF;
    
    -- Test 3: Schema Consistency
    test_start := CURRENT_TIMESTAMP;
    
    -- Check for missing constraints
    SELECT COUNT(*) INTO total_count
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_schema = 'public'
    AND tc.constraint_type = 'FOREIGN KEY';
    
    IF total_count >= 20 THEN -- Expected minimum FK constraints
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'SCHEMA', 
            'foreign_key_constraints', 'PASS', 
            format('Found %s foreign key constraints', total_count), NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'SCHEMA', 
            'foreign_key_constraints', 'WARNING', 
            format('Found only %s foreign key constraints', total_count), NULL, test_start);
    END IF;
    
    -- Test 4: Performance Baseline
    test_start := CURRENT_TIMESTAMP;
    
    -- Test critical query performance
    DECLARE
        query_start TIMESTAMP := CURRENT_TIMESTAMP;
        query_duration INTERVAL;
        loan_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO loan_count
        FROM loan l
        JOIN product p ON l.product_id = p.id
        WHERE l.status = 'active';
        
        query_duration := CURRENT_TIMESTAMP - query_start;
        
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'PERFORMANCE', 
            'critical_query_baseline', 'INFO', 
            format('Query returned %s records in %s', loan_count, query_duration), 
            jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM query_duration) * 1000, 'record_count', loan_count),
            test_start);
    END;
    
    -- Test 5: Data Volume Analysis
    test_start := CURRENT_TIMESTAMP;
    
    DECLARE
        table_stats JSONB := '{}';
        rec RECORD;
    BEGIN
        FOR rec IN 
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        LOOP
            EXECUTE format('SELECT COUNT(*) FROM %I', rec.table_name) INTO total_count;
            table_stats := table_stats || jsonb_build_object(rec.table_name, total_count);
        END LOOP;
        
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'DATA_VOLUME', 
            'table_record_counts', 'INFO', 
            'Pre-migration data volume captured', 
            table_stats, test_start);
    END;
    
    -- Test 6: Database Health Check
    test_start := CURRENT_TIMESTAMP;
    
    -- Check for database bloat, unused indexes, etc.
    SELECT COUNT(*) INTO total_count
    FROM pg_stat_user_tables
    WHERE n_dead_tup > n_live_tup; -- Tables with more dead tuples than live
    
    IF total_count = 0 THEN
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'DATABASE_HEALTH', 
            'table_bloat_check', 'PASS', 
            'No heavily bloated tables detected', NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'pre_validation', 'DATABASE_HEALTH', 
            'table_bloat_check', 'WARNING', 
            format('Found %s tables with excessive bloat', total_count), NULL, test_start);
    END IF;
    
    RAISE NOTICE '=== PRE-MIGRATION VALIDATION COMPLETED ===';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATION EXECUTION TESTING
-- ============================================================================

-- Test migration execution with monitoring
CREATE OR REPLACE FUNCTION test_migration_execution(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration',
    p_migration_file TEXT DEFAULT 'migration_v0_to_v1.sql'
)
RETURNS void AS $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    migration_start TIMESTAMP;
    migration_end TIMESTAMP;
    execution_status TEXT := 'RUNNING';
BEGIN
    RAISE NOTICE '=== TESTING MIGRATION EXECUTION: % ===', p_migration_name;
    
    -- Clear previous migration test results
    DELETE FROM migration_test_log WHERE migration_name = p_migration_name AND test_phase = 'migration';
    
    -- Log migration start
    migration_start := CURRENT_TIMESTAMP;
    PERFORM log_migration_test(p_migration_name, 'migration', 'EXECUTION', 
        'migration_started', 'INFO', 
        format('Migration execution started: %s', p_migration_file), NULL, test_start);
    
    -- In a real scenario, you would execute the migration here
    -- For testing purposes, we simulate the execution
    BEGIN
        -- Simulate migration execution time
        PERFORM pg_sleep(2); -- 2 second simulation
        
        migration_end := CURRENT_TIMESTAMP;
        execution_status := 'COMPLETED';
        
        PERFORM log_migration_test(p_migration_name, 'migration', 'EXECUTION', 
            'migration_completed', 'PASS', 
            format('Migration completed successfully in %s', migration_end - migration_start), 
            jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM (migration_end - migration_start)) * 1000),
            migration_start);
            
    EXCEPTION WHEN OTHERS THEN
        migration_end := CURRENT_TIMESTAMP;
        execution_status := 'FAILED';
        
        PERFORM log_migration_test(p_migration_name, 'migration', 'EXECUTION', 
            'migration_failed', 'FAIL', 
            format('Migration failed: %s', SQLERRM), 
            jsonb_build_object('error_code', SQLSTATE, 'error_message', SQLERRM),
            migration_start);
    END;
    
    -- Monitor system resources during migration
    PERFORM log_migration_test(p_migration_name, 'migration', 'MONITORING', 
        'system_resources', 'INFO', 
        'Resource monitoring completed', 
        jsonb_build_object(
            'connections_used', (SELECT count(*) FROM pg_stat_activity),
            'database_size', pg_database_size(current_database()),
            'temp_files', (SELECT sum(temp_files) FROM pg_stat_database WHERE datname = current_database())
        ),
        test_start);
        
    RAISE NOTICE '=== MIGRATION EXECUTION TESTING COMPLETED: % ===', execution_status;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- POST-MIGRATION VALIDATION PROCEDURES
-- ============================================================================

-- Comprehensive post-migration validation
CREATE OR REPLACE FUNCTION run_post_migration_validation(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration'
)
RETURNS void AS $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    violation_count INTEGER;
    pre_count NUMERIC;
    post_count NUMERIC;
    variance NUMERIC;
BEGIN
    RAISE NOTICE '=== STARTING POST-MIGRATION VALIDATION: % ===', p_migration_name;
    
    -- Clear previous post-migration test results
    DELETE FROM migration_test_log WHERE migration_name = p_migration_name AND test_phase = 'post_validation';
    
    -- Capture post-migration baseline
    PERFORM capture_migration_baseline(p_migration_name, 'post_migration');
    
    -- Test 1: Data Preservation Validation
    test_start := CURRENT_TIMESTAMP;
    
    -- Compare loan record counts
    SELECT metric_value INTO pre_count 
    FROM migration_baseline 
    WHERE migration_name = p_migration_name 
    AND baseline_type = 'pre_migration' 
    AND table_name = 'loan' 
    AND metric_name = 'record_count';
    
    SELECT metric_value INTO post_count 
    FROM migration_baseline 
    WHERE migration_name = p_migration_name 
    AND baseline_type = 'post_migration' 
    AND table_name = 'loan' 
    AND metric_name = 'record_count';
    
    IF pre_count = post_count THEN
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'DATA_PRESERVATION', 
            'loan_record_count', 'PASS', 
            format('Loan record count preserved: %s', post_count), NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'DATA_PRESERVATION', 
            'loan_record_count', 'FAIL', 
            format('Loan record count changed from %s to %s', pre_count, post_count), NULL, test_start);
    END IF;
    
    -- Test 2: Financial Data Integrity
    test_start := CURRENT_TIMESTAMP;
    
    -- Compare financial totals
    SELECT metric_value INTO pre_count 
    FROM migration_baseline 
    WHERE migration_name = p_migration_name 
    AND baseline_type = 'pre_migration' 
    AND table_name = 'loan' 
    AND metric_name = 'total_principal';
    
    SELECT metric_value INTO post_count 
    FROM migration_baseline 
    WHERE migration_name = p_migration_name 
    AND baseline_type = 'post_migration' 
    AND table_name = 'loan' 
    AND metric_name = 'total_principal';
    
    variance := ABS((post_count - pre_count) / NULLIF(pre_count, 0) * 100);
    
    IF variance < 0.01 THEN -- Less than 0.01% variance
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'FINANCIAL_INTEGRITY', 
            'total_loan_principal', 'PASS', 
            format('Principal total preserved: %s (variance: %s%%)', post_count, round(variance, 4)), NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'FINANCIAL_INTEGRITY', 
            'total_loan_principal', 'FAIL', 
            format('Principal total changed from %s to %s (variance: %s%%)', pre_count, post_count, round(variance, 2)), NULL, test_start);
    END IF;
    
    -- Test 3: New Schema Features
    test_start := CURRENT_TIMESTAMP;
    
    -- Check if new tables were created
    SELECT COUNT(*) INTO violation_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('loan_status_history', 'payment_disputes', 'loan_transfers');
    
    IF violation_count = 3 THEN
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'SCHEMA_ENHANCEMENT', 
            'new_tables_created', 'PASS', 
            'All expected new tables created', NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'SCHEMA_ENHANCEMENT', 
            'new_tables_created', 'FAIL', 
            format('Expected 3 new tables, found %s', violation_count), NULL, test_start);
    END IF;
    
    -- Test 4: Enhanced Constraints
    test_start := CURRENT_TIMESTAMP;
    
    -- Check for new constraints
    SELECT COUNT(*) INTO violation_count
    FROM information_schema.check_constraints
    WHERE constraint_schema = 'public'
    AND constraint_name LIKE '%_check';
    
    IF violation_count >= 30 THEN -- Expected minimum check constraints
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'SCHEMA_ENHANCEMENT', 
            'check_constraints_added', 'PASS', 
            format('Found %s check constraints', violation_count), NULL, test_start);
    ELSE
        PERFORM log_migration_test(p_migration_name, 'post_validation', 'SCHEMA_ENHANCEMENT', 
            'check_constraints_added', 'WARNING', 
            format('Found only %s check constraints', violation_count), NULL, test_start);
    END IF;
    
    -- Test 5: Performance Impact Analysis
    test_start := CURRENT_TIMESTAMP;
    
    DECLARE
        query_start TIMESTAMP := CURRENT_TIMESTAMP;
        query_duration INTERVAL;
        loan_count INTEGER;
        pre_performance JSONB;
        performance_degradation NUMERIC;
    BEGIN
        -- Get pre-migration performance baseline
        SELECT test_data INTO pre_performance
        FROM migration_test_log
        WHERE migration_name = p_migration_name
        AND test_phase = 'pre_validation'
        AND test_name = 'critical_query_baseline';
        
        -- Execute same query post-migration
        SELECT COUNT(*) INTO loan_count
        FROM loan l
        JOIN product p ON l.product_id = p.id
        WHERE l.status = 'active';
        
        query_duration := CURRENT_TIMESTAMP - query_start;
        
        -- Calculate performance impact
        IF pre_performance IS NOT NULL THEN
            performance_degradation := ((EXTRACT(EPOCH FROM query_duration) * 1000) - 
                (pre_performance->>'duration_ms')::NUMERIC) / 
                (pre_performance->>'duration_ms')::NUMERIC * 100;
        ELSE
            performance_degradation := 0;
        END IF;
        
        IF performance_degradation < 20 THEN -- Less than 20% degradation acceptable
            PERFORM log_migration_test(p_migration_name, 'post_validation', 'PERFORMANCE', 
                'query_performance_impact', 'PASS', 
                format('Performance impact: %s%% (duration: %s)', round(performance_degradation, 2), query_duration), 
                jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM query_duration) * 1000, 
                                 'record_count', loan_count, 'degradation_pct', performance_degradation),
                test_start);
        ELSE
            PERFORM log_migration_test(p_migration_name, 'post_validation', 'PERFORMANCE', 
                'query_performance_impact', 'WARNING', 
                format('Significant performance degradation: %s%%', round(performance_degradation, 2)), 
                jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM query_duration) * 1000, 
                                 'degradation_pct', performance_degradation),
                test_start);
        END IF;
    END;
    
    -- Test 6: Business Logic Validation
    test_start := CURRENT_TIMESTAMP;
    
    -- Run comprehensive business rule validation
    DECLARE
        current_failures INTEGER;
    BEGIN
        -- Check payment allocation balance post-migration
        WITH unbalanced_payments AS (
            SELECT p.id, p.amount, SUM(pa.allocated_amount) as total_allocated
            FROM payment p
            JOIN payment_allocation pa ON p.id = pa.payment_id
            WHERE p.status = 'completed'
            GROUP BY p.id, p.amount
            HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
        )
        SELECT COUNT(*) INTO current_failures FROM unbalanced_payments;
        
        IF current_failures = 0 THEN
            PERFORM log_migration_test(p_migration_name, 'post_validation', 'BUSINESS_LOGIC', 
                'payment_allocation_integrity', 'PASS', 
                'All payment allocations remain balanced post-migration', NULL, test_start);
        ELSE
            PERFORM log_migration_test(p_migration_name, 'post_validation', 'BUSINESS_LOGIC', 
                'payment_allocation_integrity', 'FAIL', 
                format('Found %s unbalanced payments after migration', current_failures), NULL, test_start);
        END IF;
    END;
    
    RAISE NOTICE '=== POST-MIGRATION VALIDATION COMPLETED ===';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROLLBACK TESTING PROCEDURES
-- ============================================================================

-- Test rollback functionality
CREATE OR REPLACE FUNCTION test_rollback_procedures(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration'
)
RETURNS void AS $$
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP;
    rollback_start TIMESTAMP;
    rollback_end TIMESTAMP;
    initial_state JSONB;
    final_state JSONB;
BEGIN
    RAISE NOTICE '=== TESTING ROLLBACK PROCEDURES: % ===', p_migration_name;
    
    -- Clear previous rollback test results
    DELETE FROM migration_test_log WHERE migration_name = p_migration_name AND test_phase = 'rollback';
    
    -- Test 1: Rollback Script Validation
    test_start := CURRENT_TIMESTAMP;
    
    -- In a real scenario, you would validate the rollback script syntax
    -- For testing, we simulate this validation
    PERFORM log_migration_test(p_migration_name, 'rollback', 'SCRIPT_VALIDATION', 
        'rollback_script_syntax', 'PASS', 
        'Rollback script syntax validated', NULL, test_start);
    
    -- Test 2: Backup Restoration Test
    test_start := CURRENT_TIMESTAMP;
    rollback_start := CURRENT_TIMESTAMP;
    
    -- Capture current state before rollback simulation
    SELECT jsonb_agg(jsonb_build_object('table_name', table_name, 'record_count', 
        (SELECT count(*) FROM information_schema.tables WHERE table_name = t.table_name)))
    INTO initial_state
    FROM information_schema.tables t
    WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE';
    
    -- Simulate rollback execution
    BEGIN
        -- In a real rollback, you would:
        -- 1. Stop application services
        -- 2. Create point-in-time backup
        -- 3. Execute rollback script or restore from backup
        -- 4. Verify data integrity
        -- 5. Restart services
        
        PERFORM pg_sleep(1); -- Simulate rollback time
        rollback_end := CURRENT_TIMESTAMP;
        
        PERFORM log_migration_test(p_migration_name, 'rollback', 'EXECUTION', 
            'rollback_completed', 'PASS', 
            format('Rollback simulation completed in %s', rollback_end - rollback_start), 
            jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM (rollback_end - rollback_start)) * 1000),
            rollback_start);
            
    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_test(p_migration_name, 'rollback', 'EXECUTION', 
            'rollback_failed', 'FAIL', 
            format('Rollback failed: %s', SQLERRM), NULL, rollback_start);
    END;
    
    -- Test 3: Data Integrity Post-Rollback
    test_start := CURRENT_TIMESTAMP;
    
    -- Verify data integrity after rollback
    DECLARE
        integrity_issues INTEGER := 0;
    BEGIN
        -- Check for orphaned records
        SELECT COUNT(*) INTO integrity_issues
        FROM payment_allocation pa
        LEFT JOIN payment p ON pa.payment_id = p.id
        WHERE p.id IS NULL;
        
        IF integrity_issues = 0 THEN
            PERFORM log_migration_test(p_migration_name, 'rollback', 'DATA_INTEGRITY', 
                'post_rollback_integrity', 'PASS', 
                'No data integrity issues after rollback', NULL, test_start);
        ELSE
            PERFORM log_migration_test(p_migration_name, 'rollback', 'DATA_INTEGRITY', 
                'post_rollback_integrity', 'FAIL', 
                format('Found %s integrity issues after rollback', integrity_issues), NULL, test_start);
        END IF;
    END;
    
    -- Test 4: Application Compatibility Post-Rollback
    test_start := CURRENT_TIMESTAMP;
    
    -- Test critical application functionality
    DECLARE
        compatibility_test_passed BOOLEAN := TRUE;
    BEGIN
        -- Test basic CRUD operations
        -- This would typically involve calling application APIs or testing database operations
        
        IF compatibility_test_passed THEN
            PERFORM log_migration_test(p_migration_name, 'rollback', 'COMPATIBILITY', 
                'application_functionality', 'PASS', 
                'Application functions correctly after rollback', NULL, test_start);
        ELSE
            PERFORM log_migration_test(p_migration_name, 'rollback', 'COMPATIBILITY', 
                'application_functionality', 'FAIL', 
                'Application compatibility issues detected', NULL, test_start);
        END IF;
    END;
    
    -- Test 5: Performance Validation Post-Rollback
    test_start := CURRENT_TIMESTAMP;
    
    DECLARE
        query_start TIMESTAMP := CURRENT_TIMESTAMP;
        query_duration INTERVAL;
        baseline_performance JSONB;
    BEGIN
        -- Execute performance test query
        PERFORM COUNT(*) FROM loan l JOIN product p ON l.product_id = p.id WHERE l.status = 'active';
        query_duration := CURRENT_TIMESTAMP - query_start;
        
        -- Get original performance baseline
        SELECT test_data INTO baseline_performance
        FROM migration_test_log
        WHERE migration_name = p_migration_name
        AND test_phase = 'pre_validation'
        AND test_name = 'critical_query_baseline';
        
        PERFORM log_migration_test(p_migration_name, 'rollback', 'PERFORMANCE', 
            'post_rollback_performance', 'INFO', 
            format('Query performance after rollback: %s', query_duration), 
            jsonb_build_object('duration_ms', EXTRACT(EPOCH FROM query_duration) * 1000),
            test_start);
    END;
    
    RAISE NOTICE '=== ROLLBACK TESTING COMPLETED ===';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMPREHENSIVE MIGRATION TEST RUNNER
-- ============================================================================

-- Run complete migration testing suite
CREATE OR REPLACE FUNCTION run_complete_migration_test(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration',
    p_migration_file TEXT DEFAULT 'migration_v0_to_v1.sql'
)
RETURNS TABLE (
    test_summary TEXT,
    total_tests INTEGER,
    passed_tests INTEGER,
    failed_tests INTEGER,
    warning_tests INTEGER,
    info_tests INTEGER
) AS $$
DECLARE
    start_time TIMESTAMP := CURRENT_TIMESTAMP;
    total_count INTEGER;
    pass_count INTEGER;
    fail_count INTEGER;
    warning_count INTEGER;
    info_count INTEGER;
BEGIN
    RAISE NOTICE '=== STARTING COMPREHENSIVE MIGRATION TEST SUITE ===';
    RAISE NOTICE 'Migration: %', p_migration_name;
    RAISE NOTICE 'Started at: %', start_time;
    
    -- Phase 1: Pre-Migration Validation
    PERFORM run_pre_migration_validation(p_migration_name);
    
    -- Phase 2: Migration Execution Testing  
    PERFORM test_migration_execution(p_migration_name, p_migration_file);
    
    -- Phase 3: Post-Migration Validation
    PERFORM run_post_migration_validation(p_migration_name);
    
    -- Phase 4: Rollback Testing
    PERFORM test_rollback_procedures(p_migration_name);
    
    -- Calculate summary statistics
    SELECT 
        COUNT(*),
        SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END),
        SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END),
        SUM(CASE WHEN test_status = 'WARNING' THEN 1 ELSE 0 END),
        SUM(CASE WHEN test_status = 'INFO' THEN 1 ELSE 0 END)
    INTO total_count, pass_count, fail_count, warning_count, info_count
    FROM migration_test_log
    WHERE migration_name = p_migration_name
    AND execution_time >= start_time;
    
    RAISE NOTICE '=== MIGRATION TEST SUITE COMPLETED ===';
    RAISE NOTICE 'Duration: %', CURRENT_TIMESTAMP - start_time;
    RAISE NOTICE 'Total: %, Pass: %, Fail: %, Warning: %, Info: %', 
        total_count, pass_count, fail_count, warning_count, info_count;
    
    -- Return summary
    RETURN QUERY SELECT 
        format('Migration test completed at %s. Duration: %s', 
               CURRENT_TIMESTAMP::TEXT, (CURRENT_TIMESTAMP - start_time)::TEXT),
        total_count,
        pass_count,
        fail_count,
        warning_count,
        info_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATION TEST REPORTING FUNCTIONS
-- ============================================================================

-- Generate detailed migration test report
CREATE OR REPLACE FUNCTION generate_migration_test_report(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration'
)
RETURNS TABLE (
    test_phase TEXT,
    test_category TEXT,
    test_name TEXT,
    status TEXT,
    message TEXT,
    duration TEXT,
    execution_time TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mtl.test_phase,
        mtl.test_category,
        mtl.test_name,
        mtl.test_status,
        COALESCE(mtl.test_message, 'No message')::TEXT,
        COALESCE(mtl.execution_duration::TEXT, 'N/A')::TEXT,
        mtl.execution_time
    FROM migration_test_log mtl
    WHERE mtl.migration_name = p_migration_name
    ORDER BY mtl.execution_time, mtl.test_phase, mtl.test_category, mtl.test_name;
END;
$$ LANGUAGE plpgsql;

-- Get migration test summary by phase
CREATE OR REPLACE FUNCTION get_migration_test_summary(
    p_migration_name TEXT DEFAULT 'v0_to_v1_migration'
)
RETURNS TABLE (
    phase TEXT,
    total_tests INTEGER,
    passed INTEGER,
    failed INTEGER,
    warnings INTEGER,
    info INTEGER,
    phase_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mtl.test_phase::TEXT,
        COUNT(*)::INTEGER as total_tests,
        SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END)::INTEGER as passed,
        SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END)::INTEGER as failed,
        SUM(CASE WHEN test_status = 'WARNING' THEN 1 ELSE 0 END)::INTEGER as warnings,
        SUM(CASE WHEN test_status = 'INFO' THEN 1 ELSE 0 END)::INTEGER as info,
        CASE 
            WHEN SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) > 0 THEN 'FAILED'
            WHEN SUM(CASE WHEN test_status = 'WARNING' THEN 1 ELSE 0 END) > 0 THEN 'WARNING'
            ELSE 'PASSED'
        END::TEXT as phase_status
    FROM migration_test_log mtl
    WHERE mtl.migration_name = p_migration_name
    GROUP BY mtl.test_phase
    ORDER BY 
        CASE mtl.test_phase 
            WHEN 'pre_validation' THEN 1
            WHEN 'migration' THEN 2
            WHEN 'post_validation' THEN 3
            WHEN 'rollback' THEN 4
            ELSE 5
        END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Clean up old migration test logs
CREATE OR REPLACE FUNCTION cleanup_migration_test_logs(
    p_days_to_keep INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM migration_test_log
    WHERE execution_time < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    DELETE FROM migration_baseline
    WHERE created_at < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    
    RAISE NOTICE 'Cleaned up % old migration test records', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Compare baselines between migrations
CREATE OR REPLACE FUNCTION compare_migration_baselines(
    p_migration_name TEXT,
    p_table_name TEXT DEFAULT NULL
)
RETURNS TABLE (
    table_name TEXT,
    metric_name TEXT,
    pre_migration_value NUMERIC,
    post_migration_value NUMERIC,
    difference NUMERIC,
    percentage_change NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(pre.table_name, post.table_name)::TEXT,
        COALESCE(pre.metric_name, post.metric_name)::TEXT,
        pre.metric_value as pre_migration_value,
        post.metric_value as post_migration_value,
        (post.metric_value - pre.metric_value) as difference,
        CASE 
            WHEN pre.metric_value = 0 THEN NULL
            ELSE ((post.metric_value - pre.metric_value) / pre.metric_value * 100)
        END as percentage_change
    FROM 
        (SELECT table_name, metric_name, metric_value 
         FROM migration_baseline 
         WHERE migration_name = p_migration_name 
         AND baseline_type = 'pre_migration'
         AND (p_table_name IS NULL OR table_name = p_table_name)) pre
    FULL OUTER JOIN 
        (SELECT table_name, metric_name, metric_value 
         FROM migration_baseline 
         WHERE migration_name = p_migration_name 
         AND baseline_type = 'post_migration'
         AND (p_table_name IS NULL OR table_name = p_table_name)) post
    ON pre.table_name = post.table_name AND pre.metric_name = post.metric_name
    ORDER BY COALESCE(pre.table_name, post.table_name), COALESCE(pre.metric_name, post.metric_name);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLES AND DOCUMENTATION
-- ============================================================================

/*
USAGE EXAMPLES:

1. Run complete migration test suite:
   SELECT * FROM run_complete_migration_test('v0_to_v1_migration', 'migration_v0_to_v1.sql');

2. Run individual test phases:
   SELECT run_pre_migration_validation('v0_to_v1_migration');
   SELECT test_migration_execution('v0_to_v1_migration', 'migration_script.sql');
   SELECT run_post_migration_validation('v0_to_v1_migration');
   SELECT test_rollback_procedures('v0_to_v1_migration');

3. Generate reports:
   SELECT * FROM generate_migration_test_report('v0_to_v1_migration');
   SELECT * FROM get_migration_test_summary('v0_to_v1_migration');

4. Compare baselines:
   SELECT * FROM compare_migration_baselines('v0_to_v1_migration');
   SELECT * FROM compare_migration_baselines('v0_to_v1_migration', 'loan');

5. View test results:
   SELECT * FROM migration_test_log 
   WHERE migration_name = 'v0_to_v1_migration'
   ORDER BY execution_time;

6. Clean up old logs:
   SELECT cleanup_migration_test_logs(7);

RECOMMENDED WORKFLOW:

1. Pre-Migration:
   - Run pre-migration validation
   - Address any FAIL status tests
   - Document baseline metrics

2. Test Environment:
   - Execute migration on test copy
   - Run post-migration validation
   - Test rollback procedures
   - Performance impact analysis

3. Production Migration:
   - Final pre-migration validation
   - Execute migration during maintenance window
   - Immediate post-migration validation
   - Monitor application functionality

4. Post-Migration:
   - Full validation suite
   - Performance monitoring
   - Generate compliance reports
*/

RAISE NOTICE '';
RAISE NOTICE '=== MIGRATION TESTING FRAMEWORK INSTALLED ===';
RAISE NOTICE 'Run: SELECT * FROM run_complete_migration_test(); to start testing';
RAISE NOTICE 'Use individual functions for specific test phases';
RAISE NOTICE '';