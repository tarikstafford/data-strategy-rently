-- ============================================================================
-- RENTLY LENDING PLATFORM - AUTOMATED TESTING & MONITORING PROCEDURES
-- ============================================================================
-- PostgreSQL Automated Testing and Continuous Monitoring Framework v1.0
-- Comprehensive procedures for automated validation, monitoring, alerting,
-- and continuous quality assurance
--
-- Dependencies: pg_cron extension (for automated scheduling)
-- Usage: 
-- 1. Install framework
-- 2. Configure monitoring schedules
-- 3. Set up alerting mechanisms
-- 4. Monitor dashboard and reports
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- CREATE EXTENSION IF NOT EXISTS "pg_cron"; -- Uncomment if pg_cron is available

-- ============================================================================
-- AUTOMATED TESTING FRAMEWORK SETUP
-- ============================================================================

-- Automated test execution tracking
CREATE TABLE IF NOT EXISTS automated_test_execution (
    id SERIAL PRIMARY KEY,
    execution_id UUID DEFAULT uuid_generate_v4(),
    test_suite_name TEXT NOT NULL,
    scheduled_time TIMESTAMP NOT NULL,
    actual_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completion_time TIMESTAMP,
    execution_status TEXT NOT NULL DEFAULT 'RUNNING', -- 'RUNNING', 'COMPLETED', 'FAILED', 'TIMEOUT'
    total_tests INTEGER,
    passed_tests INTEGER,
    failed_tests INTEGER,
    warning_tests INTEGER,
    execution_duration INTERVAL,
    error_message TEXT,
    test_results JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Monitoring configuration table
CREATE TABLE IF NOT EXISTS monitoring_config (
    id SERIAL PRIMARY KEY,
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alert rules configuration
CREATE TABLE IF NOT EXISTS alert_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    rule_type TEXT NOT NULL, -- 'THRESHOLD', 'PATTERN', 'ANOMALY'
    condition_sql TEXT NOT NULL,
    severity TEXT NOT NULL, -- 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'
    threshold_value NUMERIC,
    alert_frequency TEXT DEFAULT 'IMMEDIATE', -- 'IMMEDIATE', 'HOURLY', 'DAILY'
    notification_channels TEXT[], -- 'EMAIL', 'SLACK', 'SMS', 'WEBHOOK'
    is_active BOOLEAN DEFAULT true,
    last_triggered TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alert history tracking
CREATE TABLE IF NOT EXISTS alert_history (
    id SERIAL PRIMARY KEY,
    alert_rule_id INTEGER REFERENCES alert_rules(id),
    alert_level TEXT NOT NULL,
    alert_message TEXT NOT NULL,
    alert_data JSONB,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    notification_sent BOOLEAN DEFAULT false
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_automated_test_execution_suite ON automated_test_execution(test_suite_name);
CREATE INDEX IF NOT EXISTS idx_automated_test_execution_status ON automated_test_execution(execution_status);
CREATE INDEX IF NOT EXISTS idx_automated_test_execution_time ON automated_test_execution(actual_start_time);
CREATE INDEX IF NOT EXISTS idx_alert_history_triggered ON alert_history(triggered_at);
CREATE INDEX IF NOT EXISTS idx_alert_history_rule ON alert_history(alert_rule_id);

-- ============================================================================
-- AUTOMATED TEST SUITE RUNNERS
-- ============================================================================

-- Function to run automated data validation suite
CREATE OR REPLACE FUNCTION run_automated_data_validation(
    p_suite_name TEXT DEFAULT 'daily_data_validation'
)
RETURNS UUID AS $$
DECLARE
    v_execution_id UUID := uuid_generate_v4();
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
    v_total INTEGER := 0;
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_warnings INTEGER := 0;
    v_test_results JSONB := '{}';
BEGIN
    -- Log execution start
    INSERT INTO automated_test_execution (
        execution_id, test_suite_name, scheduled_time, actual_start_time, execution_status
    ) VALUES (
        v_execution_id, p_suite_name, v_start_time, v_start_time, 'RUNNING'
    );
    
    BEGIN
        -- Run comprehensive data validation
        PERFORM run_all_validations();
        
        -- Collect results
        SELECT 
            COUNT(*),
            SUM(CASE WHEN validation_status = 'PASS' THEN 1 ELSE 0 END),
            SUM(CASE WHEN validation_status = 'FAIL' THEN 1 ELSE 0 END),
            SUM(CASE WHEN validation_status = 'WARNING' THEN 1 ELSE 0 END),
            jsonb_agg(jsonb_build_object(
                'validation_type', validation_type,
                'validation_name', validation_name,
                'status', validation_status,
                'message', validation_message
            ))
        INTO v_total, v_passed, v_failed, v_warnings, v_test_results
        FROM data_validation_log
        WHERE validation_time >= v_start_time;
        
        -- Update execution record
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'COMPLETED',
            total_tests = v_total,
            passed_tests = v_passed,
            failed_tests = v_failed,
            warning_tests = v_warnings,
            execution_duration = CURRENT_TIMESTAMP - v_start_time,
            test_results = v_test_results
        WHERE execution_id = v_execution_id;
        
    EXCEPTION WHEN OTHERS THEN
        -- Update with error status
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'FAILED',
            execution_duration = CURRENT_TIMESTAMP - v_start_time,
            error_message = SQLERRM
        WHERE execution_id = v_execution_id;
        
        RAISE NOTICE 'Automated validation failed: %', SQLERRM;
    END;
    
    RETURN v_execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function to run automated business rule validation
CREATE OR REPLACE FUNCTION run_automated_business_validation(
    p_suite_name TEXT DEFAULT 'business_rule_validation'
)
RETURNS UUID AS $$
DECLARE
    v_execution_id UUID := uuid_generate_v4();
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
    v_total INTEGER := 0;
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_warnings INTEGER := 0;
BEGIN
    -- Log execution start
    INSERT INTO automated_test_execution (
        execution_id, test_suite_name, scheduled_time, actual_start_time, execution_status
    ) VALUES (
        v_execution_id, p_suite_name, v_start_time, v_start_time, 'RUNNING'
    );
    
    BEGIN
        -- Run business rule validations
        PERFORM validate_business_rules();
        PERFORM validate_financial_calculations();
        PERFORM validate_collections_workflow();
        PERFORM validate_loan_status_consistency();
        
        -- Collect results
        SELECT 
            COUNT(*),
            SUM(CASE WHEN validation_status = 'PASS' THEN 1 ELSE 0 END),
            SUM(CASE WHEN validation_status = 'FAIL' THEN 1 ELSE 0 END),
            SUM(CASE WHEN validation_status = 'WARNING' THEN 1 ELSE 0 END)
        INTO v_total, v_passed, v_failed, v_warnings
        FROM data_validation_log
        WHERE validation_time >= v_start_time;
        
        -- Update execution record
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'COMPLETED',
            total_tests = v_total,
            passed_tests = v_passed,
            failed_tests = v_failed,
            warning_tests = v_warnings,
            execution_duration = CURRENT_TIMESTAMP - v_start_time
        WHERE execution_id = v_execution_id;
        
    EXCEPTION WHEN OTHERS THEN
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'FAILED',
            execution_duration = CURRENT_TIMESTAMP - v_start_time,
            error_message = SQLERRM
        WHERE execution_id = v_execution_id;
    END;
    
    RETURN v_execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function to run automated performance tests
CREATE OR REPLACE FUNCTION run_automated_performance_tests(
    p_suite_name TEXT DEFAULT 'performance_validation'
)
RETURNS UUID AS $$
DECLARE
    v_execution_id UUID := uuid_generate_v4();
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
    v_performance_results JSONB := '{}';
    v_query_start TIMESTAMP;
    v_query_duration INTERVAL;
    v_record_count INTEGER;
BEGIN
    -- Log execution start
    INSERT INTO automated_test_execution (
        execution_id, test_suite_name, scheduled_time, actual_start_time, execution_status
    ) VALUES (
        v_execution_id, p_suite_name, v_start_time, v_start_time, 'RUNNING'
    );
    
    BEGIN
        -- Test 1: Loan portfolio query performance
        v_query_start := CURRENT_TIMESTAMP;
        SELECT COUNT(*) INTO v_record_count
        FROM loan l
        JOIN product p ON l.product_id = p.id
        WHERE l.status = 'active';
        v_query_duration := CURRENT_TIMESTAMP - v_query_start;
        
        v_performance_results := v_performance_results || 
            jsonb_build_object('loan_portfolio_query', jsonb_build_object(
                'duration_ms', EXTRACT(EPOCH FROM v_query_duration) * 1000,
                'record_count', v_record_count,
                'status', CASE WHEN v_query_duration < INTERVAL '2 seconds' THEN 'PASS' ELSE 'WARNING' END
            ));
        
        -- Test 2: Payment allocation query performance
        v_query_start := CURRENT_TIMESTAMP;
        SELECT COUNT(*) INTO v_record_count
        FROM payment_allocation pa
        JOIN payment p ON pa.payment_id = p.id
        WHERE p.received_at >= CURRENT_DATE - INTERVAL '30 days';
        v_query_duration := CURRENT_TIMESTAMP - v_query_start;
        
        v_performance_results := v_performance_results || 
            jsonb_build_object('payment_allocation_query', jsonb_build_object(
                'duration_ms', EXTRACT(EPOCH FROM v_query_duration) * 1000,
                'record_count', v_record_count,
                'status', CASE WHEN v_query_duration < INTERVAL '3 seconds' THEN 'PASS' ELSE 'WARNING' END
            ));
        
        -- Test 3: Collections events query performance
        v_query_start := CURRENT_TIMESTAMP;
        SELECT COUNT(*) INTO v_record_count
        FROM collections_event ce
        JOIN loan l ON ce.loan_id = l.id
        WHERE ce.event_at >= CURRENT_DATE - INTERVAL '7 days';
        v_query_duration := CURRENT_TIMESTAMP - v_query_start;
        
        v_performance_results := v_performance_results || 
            jsonb_build_object('collections_query', jsonb_build_object(
                'duration_ms', EXTRACT(EPOCH FROM v_query_duration) * 1000,
                'record_count', v_record_count,
                'status', CASE WHEN v_query_duration < INTERVAL '1 second' THEN 'PASS' ELSE 'WARNING' END
            ));
        
        -- Update execution record
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'COMPLETED',
            total_tests = 3,
            passed_tests = (
                SELECT COUNT(*) FROM jsonb_each(v_performance_results) 
                WHERE value->>'status' = 'PASS'
            ),
            warning_tests = (
                SELECT COUNT(*) FROM jsonb_each(v_performance_results) 
                WHERE value->>'status' = 'WARNING'
            ),
            execution_duration = CURRENT_TIMESTAMP - v_start_time,
            test_results = v_performance_results
        WHERE execution_id = v_execution_id;
        
    EXCEPTION WHEN OTHERS THEN
        UPDATE automated_test_execution SET
            completion_time = CURRENT_TIMESTAMP,
            execution_status = 'FAILED',
            execution_duration = CURRENT_TIMESTAMP - v_start_time,
            error_message = SQLERRM
        WHERE execution_id = v_execution_id;
    END;
    
    RETURN v_execution_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MONITORING AND ALERTING SYSTEM
-- ============================================================================

-- Function to evaluate alert rules
CREATE OR REPLACE FUNCTION evaluate_alert_rules()
RETURNS INTEGER AS $$
DECLARE
    v_rule RECORD;
    v_result_count INTEGER;
    v_alert_message TEXT;
    v_alert_data JSONB;
    v_alerts_triggered INTEGER := 0;
BEGIN
    FOR v_rule IN 
        SELECT * FROM alert_rules WHERE is_active = true
    LOOP
        BEGIN
            -- Execute the condition SQL
            EXECUTE format('SELECT COUNT(*) FROM (%s) AS alert_query', v_rule.condition_sql) 
            INTO v_result_count;
            
            -- Check if threshold is exceeded
            IF (v_rule.rule_type = 'THRESHOLD' AND v_result_count > COALESCE(v_rule.threshold_value, 0)) OR
               (v_rule.rule_type = 'PATTERN' AND v_result_count > 0) THEN
                
                -- Prepare alert message
                v_alert_message := format('Alert Rule "%s" triggered: Found %s violations', 
                    v_rule.rule_name, v_result_count);
                
                v_alert_data := jsonb_build_object(
                    'rule_name', v_rule.rule_name,
                    'rule_type', v_rule.rule_type,
                    'violation_count', v_result_count,
                    'threshold', v_rule.threshold_value,
                    'condition_sql', v_rule.condition_sql
                );
                
                -- Insert alert record
                INSERT INTO alert_history (
                    alert_rule_id, alert_level, alert_message, alert_data
                ) VALUES (
                    v_rule.id, v_rule.severity, v_alert_message, v_alert_data
                );
                
                -- Update last triggered time
                UPDATE alert_rules SET last_triggered = CURRENT_TIMESTAMP WHERE id = v_rule.id;
                
                v_alerts_triggered := v_alerts_triggered + 1;
                
                RAISE NOTICE 'Alert triggered: %', v_alert_message;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            -- Log alert rule execution error
            INSERT INTO alert_history (
                alert_rule_id, alert_level, alert_message, alert_data
            ) VALUES (
                v_rule.id, 'CRITICAL', 
                format('Alert rule execution failed: %s', SQLERRM),
                jsonb_build_object('error_code', SQLSTATE, 'error_message', SQLERRM)
            );
        END;
    END LOOP;
    
    RETURN v_alerts_triggered;
END;
$$ LANGUAGE plpgsql;

-- Function to create standard alert rules
CREATE OR REPLACE FUNCTION setup_standard_alert_rules()
RETURNS INTEGER AS $$
DECLARE
    v_rules_created INTEGER := 0;
BEGIN
    -- Critical data integrity violations
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'orphaned_payment_allocations',
        'THRESHOLD',
        'SELECT COUNT(*) FROM payment_allocation pa LEFT JOIN payment p ON pa.payment_id = p.id WHERE p.id IS NULL',
        'CRITICAL',
        0
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Business rule violations
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'unbalanced_payment_allocations',
        'THRESHOLD',
        'SELECT COUNT(*) FROM (SELECT p.id FROM payment p JOIN payment_allocation pa ON p.id = pa.payment_id WHERE p.status = ''completed'' GROUP BY p.id, p.amount HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01) unbalanced',
        'HIGH',
        0
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Performance degradation
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'slow_queries_detected',
        'THRESHOLD',
        'SELECT COUNT(*) FROM pg_stat_statements WHERE mean_exec_time > 5000 AND calls > 10',
        'MEDIUM',
        5
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Data quality issues
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'loans_without_valid_borrowers',
        'THRESHOLD',
        'SELECT COUNT(*) FROM loan l LEFT JOIN party p ON l.borrower_party_id = p.id WHERE p.id IS NULL',
        'HIGH',
        0
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Recent validation failures
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'recent_validation_failures',
        'THRESHOLD',
        'SELECT COUNT(*) FROM data_validation_log WHERE validation_status = ''FAIL'' AND validation_time >= CURRENT_TIMESTAMP - INTERVAL ''1 hour''',
        'HIGH',
        5
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Unusual loan creation patterns
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'high_loan_creation_rate',
        'THRESHOLD',
        'SELECT COUNT(*) FROM loan WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL ''1 hour''',
        'MEDIUM',
        100
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    -- Payment processing errors
    INSERT INTO alert_rules (rule_name, rule_type, condition_sql, severity, threshold_value)
    VALUES (
        'failed_payments_spike',
        'THRESHOLD',
        'SELECT COUNT(*) FROM payment WHERE status = ''failed'' AND created_at >= CURRENT_TIMESTAMP - INTERVAL ''1 hour''',
        'HIGH',
        10
    ) ON CONFLICT (rule_name) DO NOTHING;
    
    GET DIAGNOSTICS v_rules_created = ROW_COUNT;
    RETURN v_rules_created;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CONTINUOUS MONITORING DASHBOARD FUNCTIONS
-- ============================================================================

-- Function to get system health overview
CREATE OR REPLACE FUNCTION get_system_health_overview()
RETURNS TABLE (
    metric_category TEXT,
    metric_name TEXT,
    current_value TEXT,
    status TEXT,
    last_updated TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    -- Data validation health
    WITH validation_health AS (
        SELECT 
            COUNT(*) FILTER (WHERE validation_status = 'FAIL') as failures,
            COUNT(*) FILTER (WHERE validation_status = 'WARNING') as warnings,
            MAX(validation_time) as last_validation
        FROM data_validation_log
        WHERE validation_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    )
    SELECT 
        'Data Validation'::TEXT,
        'Recent Failures (24h)'::TEXT,
        vh.failures::TEXT,
        CASE WHEN vh.failures = 0 THEN 'HEALTHY' 
             WHEN vh.failures < 5 THEN 'WARNING' 
             ELSE 'CRITICAL' END::TEXT,
        vh.last_validation
    FROM validation_health vh
    
    UNION ALL
    
    -- Performance metrics
    SELECT 
        'Performance'::TEXT,
        'Active Connections'::TEXT,
        (SELECT count(*)::TEXT FROM pg_stat_activity WHERE state = 'active'),
        CASE WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 50 THEN 'HEALTHY'
             WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 100 THEN 'WARNING'
             ELSE 'CRITICAL' END::TEXT,
        CURRENT_TIMESTAMP
    
    UNION ALL
    
    -- Data volume metrics
    SELECT 
        'Data Volume'::TEXT,
        'Total Loans'::TEXT,
        (SELECT COUNT(*)::TEXT FROM loan),
        'INFO'::TEXT,
        CURRENT_TIMESTAMP
    
    UNION ALL
    
    SELECT 
        'Data Volume'::TEXT,
        'Active Loans'::TEXT,
        (SELECT COUNT(*)::TEXT FROM loan WHERE status = 'active'),
        'INFO'::TEXT,
        CURRENT_TIMESTAMP
    
    UNION ALL
    
    -- Recent activity
    SELECT 
        'Activity'::TEXT,
        'Recent Payments (24h)'::TEXT,
        (SELECT COUNT(*)::TEXT FROM payment WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'),
        'INFO'::TEXT,
        CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to get data quality metrics
CREATE OR REPLACE FUNCTION get_data_quality_metrics()
RETURNS TABLE (
    table_name TEXT,
    total_records INTEGER,
    completeness_score NUMERIC,
    quality_issues INTEGER,
    last_validated TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    -- Loan table quality
    WITH loan_quality AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE loan_number IS NOT NULL AND TRIM(loan_number) != '') as complete_loan_numbers,
            COUNT(*) FILTER (WHERE principal_amount > 0) as valid_amounts,
            COUNT(*) FILTER (WHERE start_date < end_date) as valid_dates
        FROM loan
    )
    SELECT 
        'loan'::TEXT,
        lq.total::INTEGER,
        ROUND((lq.complete_loan_numbers + lq.valid_amounts + lq.valid_dates)::NUMERIC / (lq.total * 3) * 100, 2),
        (lq.total - lq.complete_loan_numbers + lq.total - lq.valid_amounts + lq.total - lq.valid_dates)::INTEGER,
        (SELECT MAX(validation_time) FROM data_validation_log WHERE table_name = 'loan')
    FROM loan_quality lq
    
    UNION ALL
    
    -- Payment table quality
    WITH payment_quality AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE amount > 0) as valid_amounts,
            COUNT(*) FILTER (WHERE currency_code IS NOT NULL AND LENGTH(currency_code) = 3) as valid_currencies
        FROM payment
    )
    SELECT 
        'payment'::TEXT,
        pq.total::INTEGER,
        ROUND((pq.valid_amounts + pq.valid_currencies)::NUMERIC / (pq.total * 2) * 100, 2),
        (pq.total - pq.valid_amounts + pq.total - pq.valid_currencies)::INTEGER,
        (SELECT MAX(validation_time) FROM data_validation_log WHERE table_name = 'payment')
    FROM payment_quality pq
    
    UNION ALL
    
    -- Party table quality
    WITH party_quality AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE display_name IS NOT NULL AND TRIM(display_name) != '') as complete_names,
            COUNT(*) FILTER (WHERE email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') as valid_emails
        FROM party
    )
    SELECT 
        'party'::TEXT,
        pq.total::INTEGER,
        ROUND((pq.complete_names + pq.valid_emails)::NUMERIC / (pq.total * 2) * 100, 2),
        (pq.total - pq.complete_names + pq.total - pq.valid_emails)::INTEGER,
        (SELECT MAX(validation_time) FROM data_validation_log WHERE table_name = 'party')
    FROM party_quality pq;
END;
$$ LANGUAGE plpgsql;

-- Function to get performance metrics
CREATE OR REPLACE FUNCTION get_performance_metrics()
RETURNS TABLE (
    metric_name TEXT,
    current_value TEXT,
    unit TEXT,
    status TEXT,
    benchmark TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Database size
    SELECT 
        'Database Size'::TEXT,
        pg_size_pretty(pg_database_size(current_database()))::TEXT,
        'bytes'::TEXT,
        'INFO'::TEXT,
        'Monitor growth trends'::TEXT
    
    UNION ALL
    
    -- Connection count
    SELECT 
        'Active Connections'::TEXT,
        (SELECT count(*)::TEXT FROM pg_stat_activity WHERE state = 'active'),
        'connections'::TEXT,
        CASE WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 20 THEN 'HEALTHY'
             WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 50 THEN 'WARNING'
             ELSE 'CRITICAL' END::TEXT,
        '< 50 connections'::TEXT
    
    UNION ALL
    
    -- Cache hit ratio
    SELECT 
        'Buffer Cache Hit Ratio'::TEXT,
        ROUND(
            100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)),
            2
        )::TEXT || '%',
        'percentage'::TEXT,
        CASE WHEN ROUND(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) >= 95 THEN 'HEALTHY'
             WHEN ROUND(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) >= 90 THEN 'WARNING'
             ELSE 'CRITICAL' END::TEXT,
        '> 95%'::TEXT
    FROM pg_stat_database
    WHERE datname = current_database()
    
    UNION ALL
    
    -- Index usage ratio
    SELECT 
        'Index Usage Ratio'::TEXT,
        COALESCE(
            ROUND(
                100.0 * sum(idx_scan) / (sum(seq_scan) + sum(idx_scan)),
                2
            ), 0
        )::TEXT || '%',
        'percentage'::TEXT,
        CASE WHEN COALESCE(ROUND(100.0 * sum(idx_scan) / (sum(seq_scan) + sum(idx_scan)), 2), 0) >= 80 THEN 'HEALTHY'
             WHEN COALESCE(ROUND(100.0 * sum(idx_scan) / (sum(seq_scan) + sum(idx_scan)), 2), 0) >= 60 THEN 'WARNING'
             ELSE 'CRITICAL' END::TEXT,
        '> 80%'::TEXT
    FROM pg_stat_user_tables;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUTOMATED TESTING SCHEDULER SETUP
-- ============================================================================

-- Function to setup automated testing schedules
CREATE OR REPLACE FUNCTION setup_automated_testing_schedules()
RETURNS TEXT AS $$
DECLARE
    v_setup_commands TEXT;
BEGIN
    v_setup_commands := '
-- PostgreSQL pg_cron extension required for scheduling
-- Install with: CREATE EXTENSION pg_cron;

-- Schedule comprehensive data validation every 4 hours
SELECT cron.schedule(''rently-data-validation'', ''0 */4 * * *'', ''SELECT run_automated_data_validation();'');

-- Schedule business rule validation every 2 hours
SELECT cron.schedule(''rently-business-validation'', ''0 */2 * * *'', ''SELECT run_automated_business_validation();'');

-- Schedule performance tests daily at 2 AM
SELECT cron.schedule(''rently-performance-tests'', ''0 2 * * *'', ''SELECT run_automated_performance_tests();'');

-- Schedule alert rule evaluation every 15 minutes
SELECT cron.schedule(''rently-alert-evaluation'', ''*/15 * * * *'', ''SELECT evaluate_alert_rules();'');

-- Schedule daily cleanup at 3 AM
SELECT cron.schedule(''rently-log-cleanup'', ''0 3 * * *'', ''SELECT cleanup_validation_logs(30); SELECT cleanup_migration_test_logs(30);'');

-- Schedule weekly comprehensive test suite on Sundays at 1 AM
SELECT cron.schedule(''rently-weekly-tests'', ''0 1 * * 0'', ''SELECT * FROM export_test_results();'');

-- View scheduled jobs
SELECT cron.jobname, cron.schedule, cron.command, cron.active FROM cron.job WHERE jobname LIKE ''rently-%'';
';

    RETURN v_setup_commands;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- REPORTING AND DASHBOARD FUNCTIONS
-- ============================================================================

-- Function to generate automated test execution report
CREATE OR REPLACE FUNCTION generate_test_execution_report(
    p_hours_back INTEGER DEFAULT 24
)
RETURNS TABLE (
    test_suite TEXT,
    executions INTEGER,
    success_rate NUMERIC,
    avg_duration TEXT,
    last_execution TIMESTAMP,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ate.test_suite_name::TEXT,
        COUNT(*)::INTEGER as executions,
        ROUND(
            COUNT(*) FILTER (WHERE execution_status = 'COMPLETED')::NUMERIC / COUNT(*) * 100, 
            2
        ) as success_rate,
        AVG(execution_duration)::TEXT as avg_duration,
        MAX(actual_start_time) as last_execution,
        CASE 
            WHEN COUNT(*) FILTER (WHERE execution_status = 'FAILED') > 0 THEN 'ISSUES'
            WHEN COUNT(*) FILTER (WHERE execution_status = 'COMPLETED') = COUNT(*) THEN 'HEALTHY'
            ELSE 'MIXED'
        END::TEXT as status
    FROM automated_test_execution ate
    WHERE ate.actual_start_time >= CURRENT_TIMESTAMP - (p_hours_back || ' hours')::INTERVAL
    GROUP BY ate.test_suite_name
    ORDER BY last_execution DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get active alerts summary
CREATE OR REPLACE FUNCTION get_active_alerts_summary()
RETURNS TABLE (
    severity TEXT,
    alert_count INTEGER,
    oldest_alert TIMESTAMP,
    most_recent TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ah.alert_level::TEXT,
        COUNT(*)::INTEGER,
        MIN(ah.triggered_at),
        MAX(ah.triggered_at)
    FROM alert_history ah
    WHERE ah.resolved_at IS NULL
    AND ah.triggered_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    GROUP BY ah.alert_level
    ORDER BY 
        CASE ah.alert_level 
            WHEN 'CRITICAL' THEN 1 
            WHEN 'HIGH' THEN 2 
            WHEN 'MEDIUM' THEN 3 
            WHEN 'LOW' THEN 4 
            ELSE 5 
        END;
END;
$$ LANGUAGE plpgsql;

-- Function to get trending metrics
CREATE OR REPLACE FUNCTION get_trending_metrics()
RETURNS TABLE (
    metric_name TEXT,
    current_value NUMERIC,
    previous_value NUMERIC,
    change_percent NUMERIC,
    trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Loan volume trend
    WITH loan_trends AS (
        SELECT 
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as current_week,
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '14 days' 
                            AND created_at < CURRENT_DATE - INTERVAL '7 days') as previous_week
        FROM loan
    )
    SELECT 
        'Weekly Loan Creation'::TEXT,
        lt.current_week::NUMERIC,
        lt.previous_week::NUMERIC,
        CASE WHEN lt.previous_week = 0 THEN NULL 
             ELSE ROUND((lt.current_week - lt.previous_week)::NUMERIC / lt.previous_week * 100, 2) 
        END,
        CASE WHEN lt.previous_week = 0 THEN 'NEW'
             WHEN lt.current_week > lt.previous_week THEN 'UP'
             WHEN lt.current_week < lt.previous_week THEN 'DOWN'
             ELSE 'STABLE'
        END::TEXT
    FROM loan_trends lt
    
    UNION ALL
    
    -- Payment volume trend
    WITH payment_trends AS (
        SELECT 
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as current_week,
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '14 days' 
                            AND created_at < CURRENT_DATE - INTERVAL '7 days') as previous_week
        FROM payment
    )
    SELECT 
        'Weekly Payment Volume'::TEXT,
        pt.current_week::NUMERIC,
        pt.previous_week::NUMERIC,
        CASE WHEN pt.previous_week = 0 THEN NULL 
             ELSE ROUND((pt.current_week - pt.previous_week)::NUMERIC / pt.previous_week * 100, 2) 
        END,
        CASE WHEN pt.previous_week = 0 THEN 'NEW'
             WHEN pt.current_week > pt.previous_week THEN 'UP'
             WHEN pt.current_week < pt.previous_week THEN 'DOWN'
             ELSE 'STABLE'
        END::TEXT
    FROM payment_trends pt;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UTILITY AND MAINTENANCE FUNCTIONS
-- ============================================================================

-- Function to cleanup old automation logs
CREATE OR REPLACE FUNCTION cleanup_automation_logs(
    p_days_to_keep INTEGER DEFAULT 30
)
RETURNS TABLE (
    table_name TEXT,
    records_deleted INTEGER
) AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    -- Clean automated test execution logs
    DELETE FROM automated_test_execution
    WHERE actual_start_time < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    
    RETURN QUERY SELECT 'automated_test_execution'::TEXT, v_deleted;
    
    -- Clean resolved alert history
    DELETE FROM alert_history
    WHERE resolved_at IS NOT NULL 
    AND resolved_at < CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    
    RETURN QUERY SELECT 'alert_history'::TEXT, v_deleted;
END;
$$ LANGUAGE plpgsql;

-- Function to get monitoring configuration
CREATE OR REPLACE FUNCTION get_monitoring_configuration()
RETURNS TABLE (
    config_key TEXT,
    config_value TEXT,
    description TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mc.config_key,
        mc.config_value,
        mc.config_description,
        mc.is_active
    FROM monitoring_config mc
    ORDER BY mc.config_key;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIALIZATION AND SETUP
-- ============================================================================

-- Function to initialize monitoring system
CREATE OR REPLACE FUNCTION initialize_monitoring_system()
RETURNS TEXT AS $$
BEGIN
    -- Insert default monitoring configuration
    INSERT INTO monitoring_config (config_key, config_value, config_description) VALUES
        ('alert_retention_days', '90', 'Days to retain alert history'),
        ('test_execution_retention_days', '60', 'Days to retain test execution logs'),
        ('performance_threshold_warning', '2000', 'Query duration warning threshold in ms'),
        ('performance_threshold_critical', '5000', 'Query duration critical threshold in ms'),
        ('validation_frequency_hours', '4', 'Hours between automated validation runs')
    ON CONFLICT (config_key) DO NOTHING;
    
    -- Setup standard alert rules
    PERFORM setup_standard_alert_rules();
    
    -- Initial system health check
    PERFORM run_automated_data_validation('initial_setup_validation');
    
    RETURN format('
=== MONITORING SYSTEM INITIALIZED ===

✅ Configuration tables created
✅ Standard alert rules configured  
✅ Initial validation completed

Next Steps:
1. Install pg_cron extension if not already installed
2. Run: SELECT setup_automated_testing_schedules();
3. Configure notification channels for alerts
4. Set up monitoring dashboards

View system status:
- SELECT * FROM get_system_health_overview();
- SELECT * FROM get_data_quality_metrics();  
- SELECT * FROM generate_test_execution_report();

Scheduled Jobs Setup:
%', setup_automated_testing_schedules());
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE DOCUMENTATION
-- ============================================================================

/*
AUTOMATED TESTING & MONITORING USAGE GUIDE

1. INITIAL SETUP:
   SELECT initialize_monitoring_system();

2. MANUAL TEST EXECUTION:
   SELECT run_automated_data_validation();
   SELECT run_automated_business_validation();
   SELECT run_automated_performance_tests();

3. MONITORING DASHBOARDS:
   SELECT * FROM get_system_health_overview();
   SELECT * FROM get_data_quality_metrics();
   SELECT * FROM get_performance_metrics();
   SELECT * FROM get_trending_metrics();

4. ALERT MANAGEMENT:
   SELECT evaluate_alert_rules();
   SELECT * FROM get_active_alerts_summary();
   SELECT * FROM alert_history WHERE resolved_at IS NULL;

5. REPORTING:
   SELECT * FROM generate_test_execution_report(48);
   SELECT * FROM generate_validation_report(24);
   
6. MAINTENANCE:
   SELECT * FROM cleanup_automation_logs(30);
   SELECT * FROM cleanup_validation_logs(30);

7. SCHEDULING (requires pg_cron):
   SELECT setup_automated_testing_schedules();
   
8. CONFIGURATION:
   SELECT * FROM get_monitoring_configuration();
   UPDATE monitoring_config SET config_value = 'new_value' WHERE config_key = 'key_name';

ALERT RULE CUSTOMIZATION:
- Add custom rules to alert_rules table
- Configure notification channels via external integration
- Adjust thresholds based on business requirements

INTEGRATION WITH EXTERNAL SYSTEMS:
- Export data via functions for dashboard tools
- Configure webhooks for alert notifications
- Use JSONB fields for structured data exchange
*/

RAISE NOTICE '';
RAISE NOTICE '=== AUTOMATED TESTING & MONITORING FRAMEWORK READY ===';
RAISE NOTICE 'Run: SELECT initialize_monitoring_system(); to complete setup';
RAISE NOTICE 'See function comments for detailed usage instructions';
RAISE NOTICE '';