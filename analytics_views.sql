-- Rently Lending Platform Analytics Views
-- Comprehensive SQL views for operational dashboards, advanced analytics, and business intelligence
-- PostgreSQL DDL optimized for high-performance reporting
-- Version: 1.0

-- ============================================================================
-- OPERATIONAL DASHBOARDS - LOAN PORTFOLIO OVERVIEW
-- ============================================================================

-- Loan Portfolio Overview - Core metrics by category, status, and currency
CREATE OR REPLACE VIEW v_loan_portfolio_overview AS
SELECT 
    le.name as legal_entity_name,
    le.country_code,
    p.category as product_category,
    p.business_unit,
    l.currency_code,
    l.status as loan_status,
    COUNT(l.id) as loan_count,
    SUM(l.principal_amount) as total_principal,
    AVG(l.principal_amount) as avg_loan_amount,
    AVG(l.interest_rate) as avg_interest_rate,
    AVG(l.rc_fee_rate) as avg_rc_fee_rate,
    MIN(l.start_date) as earliest_start_date,
    MAX(l.end_date) as latest_end_date,
    COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
    COUNT(CASE WHEN l.status = 'closed' THEN 1 END) as closed_loans,
    COUNT(CASE WHEN l.status = 'written_off' THEN 1 END) as written_off_loans,
    SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as active_principal,
    SUM(CASE WHEN l.status = 'written_off' THEN l.principal_amount ELSE 0 END) as written_off_principal
FROM loan l
JOIN product p ON l.product_id = p.id
JOIN legal_entity le ON l.legal_entity_id = le.id
GROUP BY le.name, le.country_code, p.category, p.business_unit, l.currency_code, l.status
ORDER BY le.name, p.category, l.currency_code, l.status;

COMMENT ON VIEW v_loan_portfolio_overview IS 'Comprehensive loan portfolio metrics by entity, product category, and status';

-- Current Loan Status Summary with Risk Levels
CREATE OR REPLACE VIEW v_current_loan_status_summary AS
SELECT 
    l.id as loan_id,
    l.loan_number,
    l.currency_code,
    l.principal_amount,
    l.status as loan_status,
    p.category as product_category,
    p.business_unit,
    -- Current risk level
    COALESCE(risk_status.status_value, 'normal') as current_risk_level,
    risk_status.effective_from as risk_level_since,
    -- Current collections stage
    COALESCE(collections_status.status_value, 'current') as current_collections_stage,
    collections_status.effective_from as collections_stage_since,
    -- Legal action status
    COALESCE(legal_status.status_value, 'none') as current_legal_action,
    legal_status.effective_from as legal_action_since,
    -- Borrower information
    party.display_name as borrower_name,
    party.email as borrower_email
FROM loan l
JOIN product p ON l.product_id = p.id
JOIN party ON l.borrower_party_id = party.id
LEFT JOIN current_loan_status risk_status ON l.id = risk_status.loan_id AND risk_status.status_type = 'risk_level'
LEFT JOIN current_loan_status collections_status ON l.id = collections_status.loan_id AND collections_status.status_type = 'collections_stage'
LEFT JOIN current_loan_status legal_status ON l.id = legal_status.loan_id AND legal_status.status_type = 'legal_action'
ORDER BY l.created_at DESC;

COMMENT ON VIEW v_current_loan_status_summary IS 'Current operational status summary for all loans with risk, collections, and legal action status';

-- Default Rate Analysis by Product Category
CREATE OR REPLACE VIEW v_default_rate_analysis AS
WITH loan_metrics AS (
    SELECT 
        p.category as product_category,
        p.business_unit,
        l.currency_code,
        l.id as loan_id,
        l.principal_amount,
        l.status,
        -- Current risk level from status history
        COALESCE(cls_risk.status_value, 'normal') as risk_level,
        -- Days past due calculation (simplified - would need actual DPD calculation)
        CASE 
            WHEN cls_risk.status_value IN ('default_level_1', 'default_level_2') THEN 1
            ELSE 0
        END as is_default,
        CASE 
            WHEN l.status = 'written_off' THEN 1
            ELSE 0
        END as is_written_off
    FROM loan l
    JOIN product p ON l.product_id = p.id
    LEFT JOIN current_loan_status cls_risk ON l.id = cls_risk.loan_id AND cls_risk.status_type = 'risk_level'
)
SELECT 
    product_category,
    business_unit,
    currency_code,
    COUNT(*) as total_loans,
    SUM(principal_amount) as total_principal,
    
    -- Default metrics
    SUM(is_default) as default_loans,
    SUM(CASE WHEN is_default = 1 THEN principal_amount ELSE 0 END) as default_principal,
    ROUND(100.0 * SUM(is_default) / NULLIF(COUNT(*), 0), 2) as default_rate_count_pct,
    ROUND(100.0 * SUM(CASE WHEN is_default = 1 THEN principal_amount ELSE 0 END) / NULLIF(SUM(principal_amount), 0), 2) as default_rate_amount_pct,
    
    -- Write-off metrics
    SUM(is_written_off) as written_off_loans,
    SUM(CASE WHEN is_written_off = 1 THEN principal_amount ELSE 0 END) as written_off_principal,
    ROUND(100.0 * SUM(is_written_off) / NULLIF(COUNT(*), 0), 2) as write_off_rate_count_pct,
    ROUND(100.0 * SUM(CASE WHEN is_written_off = 1 THEN principal_amount ELSE 0 END) / NULLIF(SUM(principal_amount), 0), 2) as write_off_rate_amount_pct
    
FROM loan_metrics
GROUP BY product_category, business_unit, currency_code
ORDER BY product_category, business_unit, currency_code;

COMMENT ON VIEW v_default_rate_analysis IS 'Default and write-off rate analysis by product category and business unit';

-- ============================================================================
-- CASH FLOW MANAGEMENT VIEWS
-- ============================================================================

-- Weekly Cash Flow Projections
CREATE OR REPLACE VIEW v_weekly_cash_flow_projections AS
WITH payment_schedule AS (
    SELECT 
        al.due_date,
        al.currency_code,
        DATE_TRUNC('week', al.due_date) as week_start,
        SUM(al.amount_principal + al.amount_rc_fee + al.amount_penalty + al.amount_other) as scheduled_amount,
        COUNT(DISTINCT ap.loan_id) as loans_with_payments
    FROM amortisation_line al
    JOIN amortisation_plan ap ON al.plan_id = ap.id
    WHERE ap.status = 'active'
        AND al.due_date >= CURRENT_DATE
        AND al.due_date <= CURRENT_DATE + INTERVAL '12 weeks'
    GROUP BY DATE_TRUNC('week', al.due_date), al.currency_code, al.due_date
),
actual_payments AS (
    SELECT 
        DATE_TRUNC('week', p.received_at::date) as week_start,
        p.currency_code,
        SUM(p.amount) as actual_amount,
        COUNT(*) as payment_count
    FROM payment p
    WHERE p.status = 'completed'
        AND p.direction = 'inbound'
        AND p.received_at >= CURRENT_DATE - INTERVAL '12 weeks'
        AND p.received_at < CURRENT_DATE
    GROUP BY DATE_TRUNC('week', p.received_at::date), p.currency_code
)
SELECT 
    ps.week_start,
    ps.currency_code,
    ps.scheduled_amount,
    ps.loans_with_payments,
    COALESCE(ap.actual_amount, 0) as historical_actual_amount,
    COALESCE(ap.payment_count, 0) as historical_payment_count,
    -- Calculate collection efficiency for similar periods
    CASE 
        WHEN ps.scheduled_amount > 0 AND ap.actual_amount IS NOT NULL 
        THEN ROUND(100.0 * ap.actual_amount / ps.scheduled_amount, 2)
        ELSE NULL
    END as historical_collection_efficiency_pct
FROM payment_schedule ps
LEFT JOIN actual_payments ap ON ps.week_start = ap.week_start + INTERVAL '12 weeks' AND ps.currency_code = ap.currency_code
ORDER BY ps.currency_code, ps.week_start;

COMMENT ON VIEW v_weekly_cash_flow_projections IS 'Weekly cash flow projections with historical collection efficiency comparison';

-- Monthly Cash Flow Analysis with Currency Exposure
CREATE OR REPLACE VIEW v_monthly_cash_flow_analysis AS
WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', al.due_date) as month_start,
        al.currency_code,
        SUM(al.amount_principal + al.amount_rc_fee + al.amount_penalty + al.amount_other) as scheduled_inflow,
        COUNT(DISTINCT ap.loan_id) as active_loans
    FROM amortisation_line al
    JOIN amortisation_plan ap ON al.plan_id = ap.id
    WHERE ap.status = 'active'
        AND al.due_date >= DATE_TRUNC('month', CURRENT_DATE)
        AND al.due_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', al.due_date), al.currency_code
),
disbursement_projections AS (
    SELECT 
        DATE_TRUNC('month', l.start_date) as month_start,
        l.currency_code,
        SUM(l.principal_amount) as projected_disbursements,
        COUNT(*) as new_loans
    FROM loan l
    WHERE l.status = 'active'
        AND l.start_date >= DATE_TRUNC('month', CURRENT_DATE)
        AND l.start_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', l.start_date), l.currency_code
)
SELECT 
    COALESCE(mm.month_start, dp.month_start) as month_start,
    COALESCE(mm.currency_code, dp.currency_code) as currency_code,
    COALESCE(mm.scheduled_inflow, 0) as scheduled_inflow,
    COALESCE(mm.active_loans, 0) as loans_with_payments,
    COALESCE(dp.projected_disbursements, 0) as projected_disbursements,
    COALESCE(dp.new_loans, 0) as new_loans,
    COALESCE(mm.scheduled_inflow, 0) - COALESCE(dp.projected_disbursements, 0) as net_cash_flow
FROM monthly_metrics mm
FULL OUTER JOIN disbursement_projections dp ON mm.month_start = dp.month_start AND mm.currency_code = dp.currency_code
ORDER BY currency_code, month_start;

COMMENT ON VIEW v_monthly_cash_flow_analysis IS 'Monthly cash flow analysis with inflow/outflow projections and currency exposure';

-- Payment Timing Patterns Analysis
CREATE OR REPLACE VIEW v_payment_timing_analysis AS
WITH payment_timing AS (
    SELECT 
        pa.loan_id,
        p.currency_code,
        p.received_at::date as payment_date,
        al.due_date,
        p.received_at::date - al.due_date as days_variance,
        CASE 
            WHEN p.received_at::date < al.due_date THEN 'early'
            WHEN p.received_at::date = al.due_date THEN 'on_time'
            WHEN p.received_at::date <= al.due_date + INTERVAL '7 days' THEN 'late_1_week'
            WHEN p.received_at::date <= al.due_date + INTERVAL '30 days' THEN 'late_1_month'
            ELSE 'late_over_month'
        END as payment_timing_category,
        p.amount as payment_amount,
        pa.allocated_amount
    FROM payment p
    JOIN payment_allocation pa ON p.id = pa.payment_id
    LEFT JOIN amortisation_line al ON pa.line_id = al.id
    WHERE p.status = 'completed'
        AND p.direction = 'inbound'
        AND p.received_at >= CURRENT_DATE - INTERVAL '12 months'
)
SELECT 
    currency_code,
    payment_timing_category,
    COUNT(*) as payment_count,
    SUM(allocated_amount) as total_amount,
    AVG(days_variance) as avg_days_variance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_variance) as median_days_variance,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY currency_code), 2) as percentage_of_payments
FROM payment_timing
WHERE payment_timing_category IS NOT NULL
GROUP BY currency_code, payment_timing_category
ORDER BY currency_code, 
    CASE payment_timing_category 
        WHEN 'early' THEN 1
        WHEN 'on_time' THEN 2
        WHEN 'late_1_week' THEN 3
        WHEN 'late_1_month' THEN 4
        WHEN 'late_over_month' THEN 5
    END;

COMMENT ON VIEW v_payment_timing_analysis IS 'Analysis of payment timing patterns - early, on-time, and late payment categorization';

-- ============================================================================
-- COLLECTIONS PERFORMANCE VIEWS
-- ============================================================================

-- Collections Performance Dashboard
CREATE OR REPLACE VIEW v_collections_performance AS
WITH collections_metrics AS (
    SELECT 
        ce.loan_id,
        l.currency_code,
        l.principal_amount,
        p.category as product_category,
        MIN(CASE WHEN ce.event_type = 'first_overdue' THEN ce.event_at END) as first_overdue_date,
        MAX(ce.dpd_snapshot) as max_dpd,
        COUNT(CASE WHEN ce.event_type = 'reminder_sent' THEN 1 END) as reminder_count,
        COUNT(CASE WHEN ce.event_type IN ('call_attempt', 'call_successful') THEN 1 END) as call_attempts,
        COUNT(CASE WHEN ce.event_type = 'call_successful' THEN 1 END) as successful_calls,
        MAX(CASE WHEN ce.event_type = 'payment_arrangement' THEN ce.event_at END) as last_payment_arrangement,
        COUNT(CASE WHEN ce.event_type IN ('legal_notice', 'lawyer_letter', 'court_filing') THEN 1 END) as legal_actions,
        MAX(CASE WHEN ce.event_type = 'settlement_accepted' THEN ce.event_at END) as settlement_date,
        -- Current stage
        COALESCE(cls.status_value, 'current') as current_collections_stage
    FROM collections_event ce
    JOIN loan l ON ce.loan_id = l.id
    JOIN product p ON l.product_id = p.id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'collections_stage'
    GROUP BY ce.loan_id, l.currency_code, l.principal_amount, p.category, cls.status_value
),
recovery_metrics AS (
    SELECT 
        pa.loan_id,
        SUM(pa.allocated_amount) as total_recovered,
        COUNT(DISTINCT p.id) as recovery_payments,
        MAX(p.received_at) as last_recovery_date
    FROM payment_allocation pa
    JOIN payment p ON pa.payment_id = p.id
    JOIN collections_event ce ON pa.loan_id = ce.loan_id
    WHERE p.status = 'completed' 
        AND p.direction = 'inbound'
        AND p.received_at > (SELECT MIN(event_at) FROM collections_event ce2 WHERE ce2.loan_id = pa.loan_id AND ce2.event_type = 'first_overdue')
    GROUP BY pa.loan_id
)
SELECT 
    cm.product_category,
    cm.currency_code,
    cm.current_collections_stage,
    COUNT(*) as loans_in_stage,
    SUM(cm.principal_amount) as principal_at_risk,
    AVG(cm.max_dpd) as avg_max_dpd,
    AVG(cm.reminder_count) as avg_reminders_sent,
    AVG(cm.call_attempts) as avg_call_attempts,
    ROUND(100.0 * AVG(CASE WHEN cm.successful_calls > 0 AND cm.call_attempts > 0 THEN cm.successful_calls::float / cm.call_attempts ELSE 0 END), 2) as call_success_rate_pct,
    COUNT(CASE WHEN cm.legal_actions > 0 THEN 1 END) as loans_with_legal_action,
    SUM(COALESCE(rm.total_recovered, 0)) as total_recovered_amount,
    ROUND(100.0 * SUM(COALESCE(rm.total_recovered, 0)) / NULLIF(SUM(cm.principal_amount), 0), 2) as recovery_rate_pct,
    AVG(CASE WHEN cm.first_overdue_date IS NOT NULL AND rm.last_recovery_date IS NOT NULL 
        THEN EXTRACT(days FROM rm.last_recovery_date - cm.first_overdue_date) END) as avg_recovery_days
FROM collections_metrics cm
LEFT JOIN recovery_metrics rm ON cm.loan_id = rm.loan_id
GROUP BY cm.product_category, cm.currency_code, cm.current_collections_stage
ORDER BY cm.product_category, cm.currency_code, cm.current_collections_stage;

COMMENT ON VIEW v_collections_performance IS 'Comprehensive collections performance metrics by stage, category, and recovery rates';

-- Collections Resolution Time Analysis
CREATE OR REPLACE VIEW v_collections_resolution_analysis AS
WITH collections_timeline AS (
    SELECT 
        ce.loan_id,
        l.currency_code,
        l.principal_amount,
        p.category as product_category,
        MIN(ce.event_at) as collections_start,
        MAX(CASE WHEN ce.resolution_status = 'resolved' THEN ce.event_at END) as resolution_date,
        MAX(ce.dpd_snapshot) as max_dpd_reached,
        STRING_AGG(DISTINCT ce.event_type, ', ' ORDER BY ce.event_type) as actions_taken,
        COUNT(DISTINCT ce.event_type) as unique_action_types,
        MAX(CASE WHEN ce.resolution_status = 'resolved' THEN ce.resolution_status END) as final_resolution_status
    FROM collections_event ce
    JOIN loan l ON ce.loan_id = l.id
    JOIN product p ON l.product_id = p.id
    GROUP BY ce.loan_id, l.currency_code, l.principal_amount, p.category
    HAVING COUNT(*) > 0
)
SELECT 
    product_category,
    currency_code,
    CASE 
        WHEN max_dpd_reached <= 30 THEN '1-30 DPD'
        WHEN max_dpd_reached <= 60 THEN '31-60 DPD'
        WHEN max_dpd_reached <= 90 THEN '61-90 DPD'
        ELSE '90+ DPD'
    END as dpd_bucket,
    COUNT(*) as total_collections_cases,
    COUNT(CASE WHEN resolution_date IS NOT NULL THEN 1 END) as resolved_cases,
    ROUND(100.0 * COUNT(CASE WHEN resolution_date IS NOT NULL THEN 1 END) / COUNT(*), 2) as resolution_rate_pct,
    AVG(CASE WHEN resolution_date IS NOT NULL 
        THEN EXTRACT(days FROM resolution_date - collections_start) END) as avg_resolution_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 
        CASE WHEN resolution_date IS NOT NULL 
        THEN EXTRACT(days FROM resolution_date - collections_start) END) as median_resolution_days,
    AVG(unique_action_types) as avg_actions_per_case,
    SUM(principal_amount) as total_principal_in_collections,
    SUM(CASE WHEN resolution_date IS NOT NULL THEN principal_amount ELSE 0 END) as resolved_principal
FROM collections_timeline
GROUP BY product_category, currency_code, 
    CASE 
        WHEN max_dpd_reached <= 30 THEN '1-30 DPD'
        WHEN max_dpd_reached <= 60 THEN '31-60 DPD'
        WHEN max_dpd_reached <= 90 THEN '61-90 DPD'
        ELSE '90+ DPD'
    END
ORDER BY product_category, currency_code, min(max_dpd_reached);

COMMENT ON VIEW v_collections_resolution_analysis IS 'Collections resolution time analysis by DPD buckets and product category';

-- ============================================================================
-- PAYMENT HEALTH METRICS
-- ============================================================================

-- Days Past Due (DPD) Analysis View
CREATE OR REPLACE VIEW v_dpd_analysis AS
WITH current_dpd AS (
    SELECT 
        l.id as loan_id,
        l.loan_number,
        l.currency_code,
        l.principal_amount,
        p.category as product_category,
        p.business_unit,
        party.display_name as borrower_name,
        -- Calculate current DPD based on last collections event
        COALESCE(MAX(ce.dpd_snapshot), 0) as current_dpd,
        MAX(ce.event_at) as last_collections_event,
        -- Current status
        COALESCE(cls_risk.status_value, 'current') as risk_status,
        COALESCE(cls_collections.status_value, 'current') as collections_status
    FROM loan l
    JOIN product p ON l.product_id = p.id
    JOIN party ON l.borrower_party_id = party.id
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    LEFT JOIN current_loan_status cls_risk ON l.id = cls_risk.loan_id AND cls_risk.status_type = 'risk_level'
    LEFT JOIN current_loan_status cls_collections ON l.id = cls_collections.loan_id AND cls_collections.status_type = 'collections_stage'
    WHERE l.status = 'active'
    GROUP BY l.id, l.loan_number, l.currency_code, l.principal_amount, 
             p.category, p.business_unit, party.display_name, cls_risk.status_value, cls_collections.status_value
)
SELECT 
    loan_id,
    loan_number,
    currency_code,
    principal_amount,
    product_category,
    business_unit,
    borrower_name,
    current_dpd,
    CASE 
        WHEN current_dpd = 0 THEN 'Current'
        WHEN current_dpd <= 7 THEN '1-7 DPD'
        WHEN current_dpd <= 30 THEN '8-30 DPD'
        WHEN current_dpd <= 60 THEN '31-60 DPD'
        WHEN current_dpd <= 90 THEN '61-90 DPD'
        WHEN current_dpd <= 180 THEN '91-180 DPD'
        ELSE '180+ DPD'
    END as dpd_bucket,
    risk_status,
    collections_status,
    last_collections_event,
    -- Risk categorization
    CASE 
        WHEN current_dpd = 0 THEN 'Normal'
        WHEN current_dpd <= 30 THEN 'Watch'
        WHEN current_dpd <= 90 THEN 'Substandard'
        WHEN current_dpd <= 180 THEN 'Doubtful'
        ELSE 'Loss'
    END as risk_category
FROM current_dpd
ORDER BY current_dpd DESC, principal_amount DESC;

COMMENT ON VIEW v_dpd_analysis IS 'Current Days Past Due analysis with risk categorization for all active loans';

-- Payment Health Summary by Product and DPD Buckets
CREATE OR REPLACE VIEW v_payment_health_summary AS
WITH dpd_summary AS (
    SELECT 
        product_category,
        business_unit,
        currency_code,
        dpd_bucket,
        risk_category,
        COUNT(*) as loan_count,
        SUM(principal_amount) as total_principal,
        AVG(current_dpd) as avg_dpd_in_bucket
    FROM v_dpd_analysis
    GROUP BY product_category, business_unit, currency_code, dpd_bucket, risk_category
)
SELECT 
    product_category,
    business_unit,
    currency_code,
    dpd_bucket,
    risk_category,
    loan_count,
    total_principal,
    ROUND(avg_dpd_in_bucket, 1) as avg_dpd_in_bucket,
    ROUND(100.0 * loan_count / SUM(loan_count) OVER (PARTITION BY product_category, business_unit, currency_code), 2) as pct_of_portfolio_by_count,
    ROUND(100.0 * total_principal / SUM(total_principal) OVER (PARTITION BY product_category, business_unit, currency_code), 2) as pct_of_portfolio_by_amount
FROM dpd_summary
ORDER BY product_category, business_unit, currency_code, 
    CASE dpd_bucket
        WHEN 'Current' THEN 1
        WHEN '1-7 DPD' THEN 2
        WHEN '8-30 DPD' THEN 3
        WHEN '31-60 DPD' THEN 4
        WHEN '61-90 DPD' THEN 5
        WHEN '91-180 DPD' THEN 6
        WHEN '180+ DPD' THEN 7
    END;

COMMENT ON VIEW v_payment_health_summary IS 'Payment health summary showing portfolio distribution across DPD buckets and risk categories';

-- ============================================================================
-- ADVANCED ANALYTICS - RISK ANALYTICS
-- ============================================================================

-- Portfolio Concentration Analysis
CREATE OR REPLACE VIEW v_portfolio_concentration_analysis AS
WITH concentration_metrics AS (
    SELECT 
        'product_category' as concentration_type,
        p.category as concentration_value,
        COUNT(l.id) as loan_count,
        SUM(l.principal_amount) as total_exposure,
        AVG(l.principal_amount) as avg_loan_size,
        l.currency_code
    FROM loan l
    JOIN product p ON l.product_id = p.id
    WHERE l.status = 'active'
    GROUP BY p.category, l.currency_code
    
    UNION ALL
    
    SELECT 
        'business_unit' as concentration_type,
        p.business_unit as concentration_value,
        COUNT(l.id) as loan_count,
        SUM(l.principal_amount) as total_exposure,
        AVG(l.principal_amount) as avg_loan_size,
        l.currency_code
    FROM loan l
    JOIN product p ON l.product_id = p.id
    WHERE l.status = 'active'
    GROUP BY p.business_unit, l.currency_code
    
    UNION ALL
    
    SELECT 
        'borrower' as concentration_type,
        party.display_name as concentration_value,
        COUNT(l.id) as loan_count,
        SUM(l.principal_amount) as total_exposure,
        AVG(l.principal_amount) as avg_loan_size,
        l.currency_code
    FROM loan l
    JOIN party ON l.borrower_party_id = party.id
    WHERE l.status = 'active'
    GROUP BY party.display_name, l.currency_code
    
    UNION ALL
    
    SELECT 
        'agent' as concentration_type,
        COALESCE(agent.display_name, 'No Agent') as concentration_value,
        COUNT(l.id) as loan_count,
        SUM(l.principal_amount) as total_exposure,
        AVG(l.principal_amount) as avg_loan_size,
        l.currency_code
    FROM loan l
    LEFT JOIN party agent ON l.agent_party_id = agent.id
    WHERE l.status = 'active'
    GROUP BY COALESCE(agent.display_name, 'No Agent'), l.currency_code
),
portfolio_totals AS (
    SELECT 
        currency_code,
        SUM(total_exposure) as total_portfolio_exposure,
        COUNT(*) as total_concentrations
    FROM concentration_metrics
    WHERE concentration_type = 'product_category'
    GROUP BY currency_code
)
SELECT 
    cm.concentration_type,
    cm.concentration_value,
    cm.currency_code,
    cm.loan_count,
    cm.total_exposure,
    ROUND(cm.avg_loan_size, 2) as avg_loan_size,
    ROUND(100.0 * cm.total_exposure / pt.total_portfolio_exposure, 2) as portfolio_concentration_pct,
    -- Concentration risk rating
    CASE 
        WHEN 100.0 * cm.total_exposure / pt.total_portfolio_exposure > 50 THEN 'High Risk'
        WHEN 100.0 * cm.total_exposure / pt.total_portfolio_exposure > 25 THEN 'Medium Risk'
        WHEN 100.0 * cm.total_exposure / pt.total_portfolio_exposure > 10 THEN 'Low Risk'
        ELSE 'Minimal Risk'
    END as concentration_risk_level
FROM concentration_metrics cm
JOIN portfolio_totals pt ON cm.currency_code = pt.currency_code
WHERE cm.concentration_type IN ('product_category', 'business_unit') 
   OR (cm.concentration_type = 'borrower' AND 100.0 * cm.total_exposure / pt.total_portfolio_exposure > 1)
   OR (cm.concentration_type = 'agent' AND 100.0 * cm.total_exposure / pt.total_portfolio_exposure > 5)
ORDER BY cm.currency_code, cm.concentration_type, cm.total_exposure DESC;

COMMENT ON VIEW v_portfolio_concentration_analysis IS 'Portfolio concentration risk analysis by product, business unit, borrower, and agent';

-- Currency Risk Analysis
CREATE OR REPLACE VIEW v_currency_risk_analysis AS
WITH currency_exposure AS (
    SELECT 
        le.name as legal_entity_name,
        le.functional_ccy as entity_functional_currency,
        l.currency_code as loan_currency,
        COUNT(l.id) as loan_count,
        SUM(l.principal_amount) as total_exposure_original_ccy,
        -- Convert to functional currency (simplified - would use actual FX rates)
        SUM(l.principal_amount * COALESCE(fx.rate, 1)) as total_exposure_functional_ccy
    FROM loan l
    JOIN legal_entity le ON l.legal_entity_id = le.id
    LEFT JOIN fx_rate fx ON l.currency_code = fx.from_ccy 
                        AND le.functional_ccy = fx.to_ccy
                        AND fx.as_of_date = (SELECT MAX(as_of_date) FROM fx_rate fx2 
                                            WHERE fx2.from_ccy = fx.from_ccy 
                                            AND fx2.to_ccy = fx.to_ccy)
    WHERE l.status = 'active'
    GROUP BY le.name, le.functional_ccy, l.currency_code, fx.rate
),
entity_totals AS (
    SELECT 
        legal_entity_name,
        entity_functional_currency,
        SUM(total_exposure_functional_ccy) as total_portfolio_functional_ccy
    FROM currency_exposure
    GROUP BY legal_entity_name, entity_functional_currency
)
SELECT 
    ce.legal_entity_name,
    ce.entity_functional_currency,
    ce.loan_currency,
    ce.loan_count,
    ce.total_exposure_original_ccy,
    ce.total_exposure_functional_ccy,
    ROUND(100.0 * ce.total_exposure_functional_ccy / et.total_portfolio_functional_ccy, 2) as currency_exposure_pct,
    -- Currency risk assessment
    CASE 
        WHEN ce.loan_currency = ce.entity_functional_currency THEN 'No FX Risk'
        WHEN 100.0 * ce.total_exposure_functional_ccy / et.total_portfolio_functional_ccy > 30 THEN 'High FX Risk'
        WHEN 100.0 * ce.total_exposure_functional_ccy / et.total_portfolio_functional_ccy > 15 THEN 'Medium FX Risk'
        ELSE 'Low FX Risk'
    END as fx_risk_level,
    -- Hedging recommendation
    CASE 
        WHEN ce.loan_currency = ce.entity_functional_currency THEN 'No Hedging Required'
        WHEN 100.0 * ce.total_exposure_functional_ccy / et.total_portfolio_functional_ccy > 20 THEN 'Consider Hedging'
        ELSE 'Monitor'
    END as hedging_recommendation
FROM currency_exposure ce
JOIN entity_totals et ON ce.legal_entity_name = et.legal_entity_name 
                     AND ce.entity_functional_currency = et.entity_functional_currency
ORDER BY ce.legal_entity_name, ce.total_exposure_functional_ccy DESC;

COMMENT ON VIEW v_currency_risk_analysis IS 'Currency risk analysis showing FX exposure and hedging recommendations by legal entity';

-- Counterparty Risk Assessment
CREATE OR REPLACE VIEW v_counterparty_risk_assessment AS
WITH borrower_metrics AS (
    SELECT 
        party.id as borrower_id,
        party.display_name as borrower_name,
        party.kind as party_type,
        COUNT(l.id) as total_loans,
        COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
        COUNT(CASE WHEN l.status = 'written_off' THEN 1 END) as written_off_loans,
        SUM(l.principal_amount) as total_exposure,
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as active_exposure,
        AVG(l.interest_rate) as avg_interest_rate,
        MIN(l.start_date) as relationship_start,
        MAX(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN 1 ELSE 0 END) as has_current_default,
        COUNT(CASE WHEN ce.event_type IN ('legal_notice', 'lawyer_letter', 'court_filing') THEN 1 END) as legal_actions_count
    FROM party
    JOIN loan l ON party.id = l.borrower_party_id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'risk_level'
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    GROUP BY party.id, party.display_name, party.kind
),
payment_behavior AS (
    SELECT 
        l.borrower_party_id as borrower_id,
        COUNT(p.id) as total_payments,
        AVG(CASE WHEN p.received_at::date > al.due_date THEN EXTRACT(days FROM p.received_at::date - al.due_date) ELSE 0 END) as avg_days_late,
        COUNT(CASE WHEN p.received_at::date <= al.due_date THEN 1 END) as on_time_payments,
        MAX(ce.dpd_snapshot) as max_dpd_reached
    FROM loan l
    JOIN payment_allocation pa ON l.id = pa.loan_id
    JOIN payment p ON pa.payment_id = p.id
    LEFT JOIN amortisation_line al ON pa.line_id = al.id
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    WHERE p.status = 'completed' AND p.direction = 'inbound'
    GROUP BY l.borrower_party_id
)
SELECT 
    bm.borrower_id,
    bm.borrower_name,
    bm.party_type,
    bm.total_loans,
    bm.active_loans,
    bm.written_off_loans,
    bm.total_exposure,
    bm.active_exposure,
    ROUND(bm.avg_interest_rate * 100, 2) as avg_interest_rate_pct,
    bm.relationship_start,
    EXTRACT(days FROM CURRENT_DATE - bm.relationship_start) as relationship_days,
    bm.has_current_default,
    bm.legal_actions_count,
    COALESCE(pb.total_payments, 0) as total_payments,
    ROUND(COALESCE(pb.avg_days_late, 0), 1) as avg_days_late,
    ROUND(100.0 * COALESCE(pb.on_time_payments, 0) / NULLIF(pb.total_payments, 0), 2) as on_time_payment_rate_pct,
    COALESCE(pb.max_dpd_reached, 0) as max_dpd_reached,
    -- Risk scoring
    CASE 
        WHEN bm.written_off_loans > 0 AND bm.has_current_default = 1 THEN 'Very High Risk'
        WHEN bm.has_current_default = 1 OR pb.max_dpd_reached > 90 THEN 'High Risk'
        WHEN pb.max_dpd_reached > 30 OR 100.0 * COALESCE(pb.on_time_payments, 0) / NULLIF(pb.total_payments, 0) < 80 THEN 'Medium Risk'
        WHEN pb.max_dpd_reached > 0 THEN 'Low Risk'
        ELSE 'Minimal Risk'
    END as risk_rating
FROM borrower_metrics bm
LEFT JOIN payment_behavior pb ON bm.borrower_id = pb.borrower_id
WHERE bm.active_exposure > 0 OR bm.written_off_loans > 0
ORDER BY 
    CASE 
        WHEN bm.written_off_loans > 0 AND bm.has_current_default = 1 THEN 1
        WHEN bm.has_current_default = 1 OR pb.max_dpd_reached > 90 THEN 2
        WHEN pb.max_dpd_reached > 30 THEN 3
        WHEN pb.max_dpd_reached > 0 THEN 4
        ELSE 5
    END,
    bm.active_exposure DESC;

COMMENT ON VIEW v_counterparty_risk_assessment IS 'Comprehensive counterparty risk assessment with payment behavior analysis and risk scoring';

-- ============================================================================
-- PERFORMANCE METRICS VIEWS
-- ============================================================================

-- Loan Origination Performance
CREATE OR REPLACE VIEW v_origination_performance AS
WITH monthly_origination AS (
    SELECT 
        DATE_TRUNC('month', a.created_at) as origination_month,
        p.category as product_category,
        p.business_unit,
        le.name as legal_entity_name,
        a.requested_currency,
        -- Application metrics
        COUNT(a.id) as total_applications,
        AVG(a.requested_amount) as avg_requested_amount,
        SUM(a.requested_amount) as total_requested_amount,
        -- Decision metrics
        COUNT(d.id) as decided_applications,
        COUNT(CASE WHEN d.outcome = 'approved' THEN 1 END) as approved_applications,
        COUNT(CASE WHEN d.outcome = 'rejected' THEN 1 END) as rejected_applications,
        -- Approved amounts
        SUM(CASE WHEN d.outcome = 'approved' THEN d.approved_amount ELSE 0 END) as total_approved_amount,
        AVG(CASE WHEN d.outcome = 'approved' THEN d.approved_amount END) as avg_approved_amount,
        -- Loan conversion
        COUNT(l.id) as loans_created,
        SUM(CASE WHEN l.id IS NOT NULL THEN l.principal_amount ELSE 0 END) as total_disbursed_amount
    FROM application a
    JOIN product p ON a.product_id = p.id
    JOIN legal_entity le ON a.legal_entity_id = le.id
    LEFT JOIN decision d ON a.id = d.application_id
    LEFT JOIN loan l ON a.id = l.application_id
    WHERE a.created_at >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '24 months'
    GROUP BY DATE_TRUNC('month', a.created_at), p.category, p.business_unit, le.name, a.requested_currency
)
SELECT 
    origination_month,
    product_category,
    business_unit,
    legal_entity_name,
    requested_currency,
    total_applications,
    decided_applications,
    approved_applications,
    rejected_applications,
    loans_created,
    ROUND(avg_requested_amount, 2) as avg_requested_amount,
    ROUND(avg_approved_amount, 2) as avg_approved_amount,
    total_requested_amount,
    total_approved_amount,
    total_disbursed_amount,
    -- Performance ratios
    ROUND(100.0 * decided_applications / NULLIF(total_applications, 0), 2) as decision_rate_pct,
    ROUND(100.0 * approved_applications / NULLIF(decided_applications, 0), 2) as approval_rate_pct,
    ROUND(100.0 * loans_created / NULLIF(approved_applications, 0), 2) as loan_conversion_rate_pct,
    ROUND(100.0 * total_approved_amount / NULLIF(total_requested_amount, 0), 2) as amount_approval_rate_pct,
    ROUND(100.0 * total_disbursed_amount / NULLIF(total_approved_amount, 0), 2) as disbursement_rate_pct
FROM monthly_origination
ORDER BY legal_entity_name, product_category, origination_month DESC;

COMMENT ON VIEW v_origination_performance IS 'Monthly loan origination performance metrics including application, approval, and disbursement rates';

-- Portfolio Quality Metrics
CREATE OR REPLACE VIEW v_portfolio_quality_metrics AS
WITH portfolio_metrics AS (
    SELECT 
        DATE_TRUNC('month', l.start_date) as origination_month,
        p.category as product_category,
        p.business_unit,
        l.currency_code,
        COUNT(l.id) as loans_originated,
        SUM(l.principal_amount) as principal_originated,
        AVG(l.interest_rate) as avg_interest_rate,
        AVG(l.rc_fee_rate) as avg_rc_fee_rate
    FROM loan l
    JOIN product p ON l.product_id = p.id
    WHERE l.start_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '24 months'
    GROUP BY DATE_TRUNC('month', l.start_date), p.category, p.business_unit, l.currency_code
),
performance_metrics AS (
    SELECT 
        DATE_TRUNC('month', l.start_date) as origination_month,
        p.category as product_category,
        p.business_unit,
        l.currency_code,
        COUNT(CASE WHEN l.status = 'written_off' THEN 1 END) as written_off_loans,
        SUM(CASE WHEN l.status = 'written_off' THEN l.principal_amount ELSE 0 END) as written_off_amount,
        COUNT(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN 1 END) as current_default_loans,
        SUM(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN l.principal_amount ELSE 0 END) as current_default_amount,
        AVG(CASE WHEN ce.dpd_snapshot > 0 THEN ce.dpd_snapshot END) as avg_dpd_for_delinquent
    FROM loan l
    JOIN product p ON l.product_id = p.id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'risk_level'
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    WHERE l.start_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '24 months'
    GROUP BY DATE_TRUNC('month', l.start_date), p.category, p.business_unit, l.currency_code
)
SELECT 
    pm.origination_month,
    pm.product_category,
    pm.business_unit,
    pm.currency_code,
    pm.loans_originated,
    pm.principal_originated,
    ROUND(pm.avg_interest_rate * 100, 2) as avg_interest_rate_pct,
    ROUND(pm.avg_rc_fee_rate * 100, 2) as avg_rc_fee_rate_pct,
    COALESCE(pf.written_off_loans, 0) as written_off_loans,
    COALESCE(pf.written_off_amount, 0) as written_off_amount,
    COALESCE(pf.current_default_loans, 0) as current_default_loans,
    COALESCE(pf.current_default_amount, 0) as current_default_amount,
    ROUND(COALESCE(pf.avg_dpd_for_delinquent, 0), 1) as avg_dpd_for_delinquent,
    -- Quality ratios
    ROUND(100.0 * COALESCE(pf.written_off_loans, 0) / NULLIF(pm.loans_originated, 0), 2) as write_off_rate_count_pct,
    ROUND(100.0 * COALESCE(pf.written_off_amount, 0) / NULLIF(pm.principal_originated, 0), 2) as write_off_rate_amount_pct,
    ROUND(100.0 * COALESCE(pf.current_default_loans, 0) / NULLIF(pm.loans_originated, 0), 2) as current_default_rate_count_pct,
    ROUND(100.0 * COALESCE(pf.current_default_amount, 0) / NULLIF(pm.principal_originated, 0), 2) as current_default_rate_amount_pct,
    -- Portfolio age in months
    EXTRACT(months FROM AGE(CURRENT_DATE, pm.origination_month)) as portfolio_age_months
FROM portfolio_metrics pm
LEFT JOIN performance_metrics pf ON pm.origination_month = pf.origination_month 
                                 AND pm.product_category = pf.product_category
                                 AND pm.business_unit = pf.business_unit
                                 AND pm.currency_code = pf.currency_code
ORDER BY pm.product_category, pm.business_unit, pm.currency_code, pm.origination_month DESC;

COMMENT ON VIEW v_portfolio_quality_metrics IS 'Portfolio quality metrics by origination cohort showing write-off and default rates over time';

-- ============================================================================
-- PREDICTIVE ANALYTICS FOUNDATION VIEWS
-- ============================================================================

-- ML Feature Engineering View for Default Prediction
CREATE OR REPLACE VIEW v_ml_features_default_prediction AS
WITH loan_features AS (
    SELECT 
        l.id as loan_id,
        -- Basic loan features
        l.principal_amount,
        l.interest_rate,
        l.rc_fee_rate,
        EXTRACT(days FROM l.end_date - l.start_date) as loan_duration_days,
        EXTRACT(days FROM CURRENT_DATE - l.start_date) as loan_age_days,
        -- Product features
        p.category as product_category,
        p.business_unit,
        -- Borrower features
        party.kind as borrower_type,
        EXTRACT(days FROM CURRENT_DATE - l.start_date) as customer_relationship_days,
        -- Payment history features
        COALESCE(payment_stats.total_payments, 0) as total_payments_made,
        COALESCE(payment_stats.on_time_payments, 0) as on_time_payments,
        COALESCE(payment_stats.avg_days_late, 0) as avg_days_late,
        COALESCE(payment_stats.max_dpd, 0) as max_dpd_reached,
        COALESCE(payment_stats.total_amount_paid, 0) as total_amount_paid,
        -- Collections features
        COALESCE(collections_stats.collections_events, 0) as collections_events_count,
        COALESCE(collections_stats.reminder_count, 0) as reminder_count,
        COALESCE(collections_stats.call_attempts, 0) as call_attempts,
        COALESCE(collections_stats.legal_actions, 0) as legal_actions_count,
        -- Current status
        CASE WHEN cls_risk.status_value IN ('default_level_1', 'default_level_2') THEN 1 ELSE 0 END as is_currently_default,
        CASE WHEN l.status = 'written_off' THEN 1 ELSE 0 END as is_written_off,
        -- Time-based features
        EXTRACT(month FROM l.start_date) as origination_month,
        EXTRACT(dow FROM l.start_date) as origination_day_of_week,
        -- Currency and geography
        l.currency_code,
        le.country_code
    FROM loan l
    JOIN product p ON l.product_id = p.id
    JOIN party ON l.borrower_party_id = party.id
    JOIN legal_entity le ON l.legal_entity_id = le.id
    LEFT JOIN current_loan_status cls_risk ON l.id = cls_risk.loan_id AND cls_risk.status_type = 'risk_level'
    LEFT JOIN (
        SELECT 
            pa.loan_id,
            COUNT(p.id) as total_payments,
            COUNT(CASE WHEN p.received_at::date <= al.due_date THEN 1 END) as on_time_payments,
            AVG(CASE WHEN p.received_at::date > al.due_date 
                THEN EXTRACT(days FROM p.received_at::date - al.due_date) 
                ELSE 0 END) as avg_days_late,
            MAX(ce.dpd_snapshot) as max_dpd,
            SUM(pa.allocated_amount) as total_amount_paid
        FROM payment_allocation pa
        JOIN payment p ON pa.payment_id = p.id
        LEFT JOIN amortisation_line al ON pa.line_id = al.id
        LEFT JOIN collections_event ce ON pa.loan_id = ce.loan_id
        WHERE p.status = 'completed' AND p.direction = 'inbound'
        GROUP BY pa.loan_id
    ) payment_stats ON l.id = payment_stats.loan_id
    LEFT JOIN (
        SELECT 
            loan_id,
            COUNT(*) as collections_events,
            COUNT(CASE WHEN event_type = 'reminder_sent' THEN 1 END) as reminder_count,
            COUNT(CASE WHEN event_type IN ('call_attempt', 'call_successful') THEN 1 END) as call_attempts,
            COUNT(CASE WHEN event_type IN ('legal_notice', 'lawyer_letter', 'court_filing') THEN 1 END) as legal_actions
        FROM collections_event
        GROUP BY loan_id
    ) collections_stats ON l.id = collections_stats.loan_id
)
SELECT 
    loan_id,
    principal_amount,
    interest_rate,
    rc_fee_rate,
    loan_duration_days,
    loan_age_days,
    product_category,
    business_unit,
    borrower_type,
    customer_relationship_days,
    total_payments_made,
    on_time_payments,
    CASE WHEN total_payments_made > 0 THEN ROUND(100.0 * on_time_payments / total_payments_made, 2) ELSE NULL END as on_time_payment_rate_pct,
    avg_days_late,
    max_dpd_reached,
    total_amount_paid,
    CASE WHEN principal_amount > 0 THEN ROUND(100.0 * total_amount_paid / principal_amount, 2) ELSE 0 END as repayment_progress_pct,
    collections_events_count,
    reminder_count,
    call_attempts,
    legal_actions_count,
    origination_month,
    origination_day_of_week,
    currency_code,
    country_code,
    -- Target variables for ML
    is_currently_default,
    is_written_off,
    CASE WHEN is_written_off = 1 OR is_currently_default = 1 THEN 1 ELSE 0 END as is_bad_loan,
    -- Risk score calculation (simple rule-based)
    CASE 
        WHEN max_dpd_reached > 90 OR legal_actions_count > 0 THEN 'High'
        WHEN max_dpd_reached > 30 OR avg_days_late > 10 THEN 'Medium'
        WHEN max_dpd_reached > 0 THEN 'Low'
        ELSE 'Minimal'
    END as current_risk_score
FROM loan_features
WHERE loan_age_days >= 30  -- Only include loans with sufficient history
ORDER BY loan_id;

COMMENT ON VIEW v_ml_features_default_prediction IS 'Feature engineering view for machine learning default prediction models with comprehensive loan and borrower characteristics';

-- ============================================================================
-- BUSINESS INTELLIGENCE - EXECUTIVE DASHBOARD VIEWS
-- ============================================================================

-- Executive Summary Dashboard
CREATE OR REPLACE VIEW v_executive_summary_dashboard AS
WITH current_metrics AS (
    SELECT 
        le.name as legal_entity_name,
        le.country_code,
        le.functional_ccy,
        -- Portfolio size
        COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as active_portfolio_value,
        -- Origination this month
        COUNT(CASE WHEN l.start_date >= DATE_TRUNC('month', CURRENT_DATE) THEN 1 END) as loans_originated_mtd,
        SUM(CASE WHEN l.start_date >= DATE_TRUNC('month', CURRENT_DATE) THEN l.principal_amount ELSE 0 END) as amount_originated_mtd,
        -- Default metrics
        COUNT(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN 1 END) as current_default_loans,
        SUM(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN l.principal_amount ELSE 0 END) as current_default_amount,
        -- Collections metrics
        COUNT(CASE WHEN l.status = 'written_off' THEN 1 END) as written_off_loans,
        SUM(CASE WHEN l.status = 'written_off' THEN l.principal_amount ELSE 0 END) as written_off_amount
    FROM legal_entity le
    LEFT JOIN loan l ON le.id = l.legal_entity_id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'risk_level'
    GROUP BY le.name, le.country_code, le.functional_ccy
),
cash_flow_metrics AS (
    SELECT 
        l.legal_entity_id,
        -- Expected collections next 30 days
        SUM(CASE WHEN al.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days' 
            THEN al.amount_principal + al.amount_rc_fee + al.amount_penalty + al.amount_other 
            ELSE 0 END) as expected_collections_30d,
        -- Collections this month
        COALESCE(collections_mtd.amount_collected, 0) as collections_mtd
    FROM loan l
    JOIN amortisation_plan ap ON l.id = ap.loan_id AND ap.status = 'active'
    JOIN amortisation_line al ON ap.id = al.plan_id
    LEFT JOIN (
        SELECT 
            pa.loan_id,
            SUM(pa.allocated_amount) as amount_collected
        FROM payment_allocation pa
        JOIN payment p ON pa.payment_id = p.id
        WHERE p.status = 'completed' 
            AND p.direction = 'inbound'
            AND p.received_at >= DATE_TRUNC('month', CURRENT_DATE)
        GROUP BY pa.loan_id
    ) collections_mtd ON l.id = collections_mtd.loan_id
    WHERE l.status = 'active'
    GROUP BY l.legal_entity_id, collections_mtd.amount_collected
)
SELECT 
    cm.legal_entity_name,
    cm.country_code,
    cm.functional_ccy,
    cm.active_loans,
    cm.active_portfolio_value,
    cm.loans_originated_mtd,
    cm.amount_originated_mtd,
    cfm.collections_mtd,
    cfm.expected_collections_30d,
    cm.current_default_loans,
    cm.current_default_amount,
    cm.written_off_loans,
    cm.written_off_amount,
    -- Key ratios
    ROUND(100.0 * cm.current_default_loans / NULLIF(cm.active_loans, 0), 2) as default_rate_count_pct,
    ROUND(100.0 * cm.current_default_amount / NULLIF(cm.active_portfolio_value, 0), 2) as default_rate_amount_pct,
    ROUND(100.0 * cm.written_off_amount / NULLIF(cm.active_portfolio_value + cm.written_off_amount, 0), 2) as cumulative_loss_rate_pct,
    ROUND(100.0 * cfm.collections_mtd / NULLIF(cfm.expected_collections_30d, 0), 2) as collection_efficiency_mtd_pct,
    -- Growth metrics (simplified - would need historical comparison)
    CASE 
        WHEN cm.amount_originated_mtd > cm.active_portfolio_value * 0.05 THEN 'High Growth'
        WHEN cm.amount_originated_mtd > cm.active_portfolio_value * 0.02 THEN 'Moderate Growth' 
        ELSE 'Stable'
    END as growth_trend
FROM current_metrics cm
LEFT JOIN cash_flow_metrics cfm ON cm.legal_entity_name = (SELECT name FROM legal_entity WHERE id = cfm.legal_entity_id)
ORDER BY cm.legal_entity_name;

COMMENT ON VIEW v_executive_summary_dashboard IS 'Executive dashboard with key portfolio, origination, default, and cash flow metrics by legal entity';

-- ============================================================================
-- COMPLIANCE AND REGULATORY REPORTING VIEWS
-- ============================================================================

-- Regulatory Compliance Report
CREATE OR REPLACE VIEW v_regulatory_compliance_report AS
WITH compliance_metrics AS (
    SELECT 
        le.name as legal_entity_name,
        le.country_code,
        l.currency_code,
        -- Portfolio metrics
        COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as outstanding_principal,
        -- Risk classification
        COUNT(CASE WHEN cls.status_value = 'normal' OR cls.status_value IS NULL THEN 1 END) as performing_loans,
        COUNT(CASE WHEN cls.status_value IN ('default_level_1') THEN 1 END) as substandard_loans,
        COUNT(CASE WHEN cls.status_value IN ('default_level_2') THEN 1 END) as doubtful_loans,
        COUNT(CASE WHEN l.status = 'written_off' THEN 1 END) as loss_loans,
        -- Amounts by classification
        SUM(CASE WHEN cls.status_value = 'normal' OR cls.status_value IS NULL THEN l.principal_amount ELSE 0 END) as performing_amount,
        SUM(CASE WHEN cls.status_value IN ('default_level_1') THEN l.principal_amount ELSE 0 END) as substandard_amount,
        SUM(CASE WHEN cls.status_value IN ('default_level_2') THEN l.principal_amount ELSE 0 END) as doubtful_amount,
        SUM(CASE WHEN l.status = 'written_off' THEN l.principal_amount ELSE 0 END) as loss_amount,
        -- Provisioning (simplified calculation)
        SUM(CASE 
            WHEN cls.status_value IN ('default_level_1') THEN l.principal_amount * 0.20
            WHEN cls.status_value IN ('default_level_2') THEN l.principal_amount * 0.50
            WHEN l.status = 'written_off' THEN l.principal_amount
            ELSE l.principal_amount * 0.01
        END) as required_provisions,
        -- Collections and recoveries
        COUNT(CASE WHEN ce.event_type IN ('legal_notice', 'lawyer_letter', 'court_filing') THEN 1 END) as legal_action_loans,
        SUM(CASE WHEN ce.event_type IN ('legal_notice', 'lawyer_letter', 'court_filing') THEN l.principal_amount ELSE 0 END) as legal_action_amount
    FROM legal_entity le
    LEFT JOIN loan l ON le.id = l.legal_entity_id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'risk_level'
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    GROUP BY le.name, le.country_code, l.currency_code
)
SELECT 
    legal_entity_name,
    country_code,
    currency_code,
    active_loans,
    outstanding_principal,
    performing_loans,
    substandard_loans,
    doubtful_loans,
    loss_loans,
    performing_amount,
    substandard_amount,
    doubtful_amount,
    loss_amount,
    required_provisions,
    legal_action_loans,
    legal_action_amount,
    -- Regulatory ratios
    ROUND(100.0 * performing_amount / NULLIF(outstanding_principal, 0), 2) as performing_ratio_pct,
    ROUND(100.0 * (substandard_amount + doubtful_amount) / NULLIF(outstanding_principal, 0), 2) as npl_ratio_pct,
    ROUND(100.0 * required_provisions / NULLIF(outstanding_principal, 0), 2) as provisioning_ratio_pct,
    ROUND(100.0 * loss_amount / NULLIF(outstanding_principal + loss_amount, 0), 2) as charge_off_ratio_pct,
    -- Compliance flags
    CASE WHEN 100.0 * (substandard_amount + doubtful_amount) / NULLIF(outstanding_principal, 0) > 5 
         THEN 'High NPL - Review Required' 
         ELSE 'Within Limits' END as npl_compliance_status,
    CASE WHEN 100.0 * required_provisions / NULLIF(outstanding_principal, 0) > 10 
         THEN 'High Provisioning Required' 
         ELSE 'Normal' END as provisioning_status
FROM compliance_metrics
WHERE outstanding_principal > 0 OR loss_amount > 0
ORDER BY legal_entity_name, currency_code;

COMMENT ON VIEW v_regulatory_compliance_report IS 'Regulatory compliance reporting with loan classifications, provisioning requirements, and NPL ratios';

-- Multi-Currency Consolidated Reporting
CREATE OR REPLACE VIEW v_consolidated_multi_currency_report AS
WITH currency_positions AS (
    SELECT 
        le.name as legal_entity_name,
        le.functional_ccy,
        l.currency_code as loan_currency,
        COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as outstanding_original_ccy,
        -- Convert to functional currency using latest FX rates
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount * COALESCE(fx.rate, 1) ELSE 0 END) as outstanding_functional_ccy,
        -- Default amounts
        SUM(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN l.principal_amount ELSE 0 END) as default_original_ccy,
        SUM(CASE WHEN cls.status_value IN ('default_level_1', 'default_level_2') THEN l.principal_amount * COALESCE(fx.rate, 1) ELSE 0 END) as default_functional_ccy,
        -- Get latest FX rate for reference
        COALESCE(fx.rate, 1) as fx_rate_to_functional,
        fx.as_of_date as fx_rate_date
    FROM legal_entity le
    LEFT JOIN loan l ON le.id = l.legal_entity_id
    LEFT JOIN current_loan_status cls ON l.id = cls.loan_id AND cls.status_type = 'risk_level'
    LEFT JOIN (
        SELECT DISTINCT ON (from_ccy, to_ccy) 
            from_ccy, to_ccy, rate, as_of_date
        FROM fx_rate 
        ORDER BY from_ccy, to_ccy, as_of_date DESC
    ) fx ON l.currency_code = fx.from_ccy AND le.functional_ccy = fx.to_ccy
    GROUP BY le.name, le.functional_ccy, l.currency_code, fx.rate, fx.as_of_date
)
SELECT 
    legal_entity_name,
    functional_ccy,
    -- Summary totals in functional currency
    SUM(outstanding_functional_ccy) as total_portfolio_functional_ccy,
    SUM(default_functional_ccy) as total_default_functional_ccy,
    -- Currency breakdown
    loan_currency,
    active_loans,
    outstanding_original_ccy,
    outstanding_functional_ccy,
    default_original_ccy,
    default_functional_ccy,
    fx_rate_to_functional,
    fx_rate_date,
    -- Currency exposure analysis
    ROUND(100.0 * outstanding_functional_ccy / NULLIF(SUM(outstanding_functional_ccy) OVER (PARTITION BY legal_entity_name), 0), 2) as currency_exposure_pct,
    ROUND(100.0 * default_functional_ccy / NULLIF(outstanding_functional_ccy, 0), 2) as default_rate_by_currency_pct,
    -- FX risk indicators
    CASE 
        WHEN loan_currency = functional_ccy THEN 'No FX Risk'
        WHEN ABS(fx_rate_to_functional - 1) > 0.10 THEN 'High FX Volatility'
        WHEN ABS(fx_rate_to_functional - 1) > 0.05 THEN 'Medium FX Volatility'
        ELSE 'Low FX Volatility'
    END as fx_risk_assessment
FROM currency_positions
WHERE outstanding_original_ccy > 0 OR default_original_ccy > 0
ORDER BY legal_entity_name, outstanding_functional_ccy DESC;

COMMENT ON VIEW v_consolidated_multi_currency_report IS 'Multi-currency consolidated reporting with FX conversion, exposure analysis, and risk assessment';

-- ============================================================================
-- MATERIALIZED VIEWS FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Materialized view for current loan status (refresh daily)
CREATE MATERIALIZED VIEW mv_current_loan_status_cache AS
SELECT * FROM current_loan_status;

CREATE INDEX idx_mv_current_loan_status_loan_id ON mv_current_loan_status_cache(loan_id);
CREATE INDEX idx_mv_current_loan_status_type ON mv_current_loan_status_cache(status_type);

COMMENT ON MATERIALIZED VIEW mv_current_loan_status_cache IS 'Cached materialized view of current loan status for performance optimization';

-- Materialized view for payment allocation summary (refresh nightly)
CREATE MATERIALIZED VIEW mv_payment_summary_cache AS
WITH payment_summary AS (
    SELECT 
        pa.loan_id,
        COUNT(DISTINCT p.id) as payment_count,
        SUM(pa.allocated_amount) as total_allocated,
        MAX(p.received_at) as last_payment_date,
        MIN(p.received_at) as first_payment_date,
        AVG(pa.allocated_amount) as avg_payment_amount
    FROM payment_allocation pa
    JOIN payment p ON pa.payment_id = p.id
    WHERE p.status = 'completed' AND p.direction = 'inbound'
    GROUP BY pa.loan_id
)
SELECT * FROM payment_summary;

CREATE INDEX idx_mv_payment_summary_loan_id ON mv_payment_summary_cache(loan_id);

COMMENT ON MATERIALIZED VIEW mv_payment_summary_cache IS 'Cached payment summary for performance optimization';

-- ============================================================================
-- REFRESH FUNCTIONS FOR MATERIALIZED VIEWS
-- ============================================================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_analytics_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_loan_status_cache;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_payment_summary_cache;
    
    -- Log the refresh
    INSERT INTO schema_version (version, description) VALUES 
    (CURRENT_TIMESTAMP::text, 'Analytics materialized views refreshed');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_analytics_materialized_views() IS 'Refresh all analytics materialized views for performance optimization';

-- ============================================================================
-- VIEW DEPENDENCIES AND METADATA
-- ============================================================================

-- Create view dependency tracking table
CREATE TABLE IF NOT EXISTS view_dependencies (
    view_name TEXT PRIMARY KEY,
    base_tables TEXT[],
    refresh_frequency TEXT,
    performance_tier TEXT,
    business_owner TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert view metadata
INSERT INTO view_dependencies (view_name, base_tables, refresh_frequency, performance_tier, business_owner) VALUES
('v_loan_portfolio_overview', ARRAY['loan', 'product', 'legal_entity'], 'real_time', 'tier_1', 'portfolio_management'),
('v_current_loan_status_summary', ARRAY['loan', 'product', 'party', 'current_loan_status'], 'real_time', 'tier_1', 'risk_management'),
('v_default_rate_analysis', ARRAY['loan', 'product', 'current_loan_status'], 'daily', 'tier_1', 'risk_management'),
('v_weekly_cash_flow_projections', ARRAY['amortisation_line', 'amortisation_plan', 'payment', 'payment_allocation'], 'daily', 'tier_1', 'treasury'),
('v_monthly_cash_flow_analysis', ARRAY['amortisation_line', 'amortisation_plan', 'loan'], 'daily', 'tier_2', 'treasury'),
('v_payment_timing_analysis', ARRAY['payment', 'payment_allocation', 'amortisation_line'], 'daily', 'tier_2', 'operations'),
('v_collections_performance', ARRAY['collections_event', 'loan', 'product', 'current_loan_status', 'payment_allocation'], 'real_time', 'tier_1', 'collections'),
('v_collections_resolution_analysis', ARRAY['collections_event', 'loan', 'product'], 'daily', 'tier_2', 'collections'),
('v_dpd_analysis', ARRAY['loan', 'product', 'party', 'collections_event', 'current_loan_status'], 'real_time', 'tier_1', 'risk_management'),
('v_payment_health_summary', ARRAY['v_dpd_analysis'], 'real_time', 'tier_1', 'risk_management'),
('v_portfolio_concentration_analysis', ARRAY['loan', 'product', 'party'], 'daily', 'tier_1', 'risk_management'),
('v_currency_risk_analysis', ARRAY['loan', 'legal_entity', 'fx_rate'], 'daily', 'tier_1', 'treasury'),
('v_counterparty_risk_assessment', ARRAY['party', 'loan', 'current_loan_status', 'collections_event', 'payment', 'payment_allocation'], 'daily', 'tier_2', 'risk_management'),
('v_origination_performance', ARRAY['application', 'product', 'legal_entity', 'decision', 'loan'], 'daily', 'tier_1', 'business_development'),
('v_portfolio_quality_metrics', ARRAY['loan', 'product', 'current_loan_status', 'collections_event'], 'daily', 'tier_1', 'portfolio_management'),
('v_ml_features_default_prediction', ARRAY['loan', 'product', 'party', 'legal_entity', 'current_loan_status', 'payment_allocation', 'collections_event'], 'daily', 'tier_3', 'data_science'),
('v_executive_summary_dashboard', ARRAY['legal_entity', 'loan', 'current_loan_status', 'amortisation_plan', 'amortisation_line'], 'real_time', 'tier_1', 'executive'),
('v_regulatory_compliance_report', ARRAY['legal_entity', 'loan', 'current_loan_status', 'collections_event'], 'daily', 'tier_1', 'compliance'),
('v_consolidated_multi_currency_report', ARRAY['legal_entity', 'loan', 'current_loan_status', 'fx_rate'], 'daily', 'tier_1', 'finance');

COMMENT ON TABLE view_dependencies IS 'Metadata tracking for analytics views including dependencies, refresh schedules, and ownership';

-- ============================================================================
-- END OF ANALYTICS VIEWS
-- ============================================================================