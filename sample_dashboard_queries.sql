-- Rently Lending Platform - Sample Dashboard Queries & Reports
-- Demonstrating key analytics capabilities and dashboard data retrieval
-- Version: 1.0
-- Date: December 2024

-- ============================================================================
-- EXECUTIVE DASHBOARD QUERIES
-- ============================================================================

-- Query 1: Executive Summary - Key Portfolio Metrics
-- Purpose: High-level KPIs for C-suite dashboard
-- Refresh: Real-time
-- Expected execution time: <2 seconds

SELECT 
    'Portfolio Overview' as metric_category,
    COUNT(CASE WHEN loan_status = 'active' THEN 1 END) as active_loans,
    ROUND(SUM(CASE WHEN loan_status = 'active' THEN active_principal ELSE 0 END), 2) as total_active_portfolio,
    ROUND(AVG(CASE WHEN loan_status = 'active' THEN avg_loan_amount END), 2) as average_loan_size,
    ROUND(SUM(written_off_principal), 2) as total_written_off,
    ROUND(100.0 * SUM(written_off_principal) / NULLIF(SUM(active_principal + written_off_principal), 0), 2) as portfolio_loss_rate_pct,
    COUNT(DISTINCT legal_entity_name) as operating_entities,
    COUNT(DISTINCT currency_code) as currencies_active
FROM v_loan_portfolio_overview
WHERE loan_count > 0;

-- Query 2: Monthly Origination Trends (Last 12 Months)
-- Purpose: Track business growth and origination performance
SELECT 
    DATE_TRUNC('month', l.start_date) as origination_month,
    COUNT(l.id) as loans_originated,
    SUM(l.principal_amount) as total_origination_amount,
    AVG(l.principal_amount) as avg_loan_amount,
    COUNT(DISTINCT l.borrower_party_id) as unique_borrowers,
    -- Product mix
    COUNT(CASE WHEN p.category = 'rently_care_d2c' THEN 1 END) as rently_care_d2c,
    COUNT(CASE WHEN p.category = 'rently_care_collaborative' THEN 1 END) as rently_care_collaborative,
    COUNT(CASE WHEN p.category = 'b2b_sme' THEN 1 END) as b2b_sme,
    COUNT(CASE WHEN p.category = 'rnpl_uae' THEN 1 END) as rnpl_uae
FROM loan l
JOIN product p ON l.product_id = p.id
WHERE l.start_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', l.start_date)
ORDER BY origination_month DESC;

-- Query 3: Real-time Risk Dashboard Summary
-- Purpose: Current portfolio health and risk indicators
WITH current_status AS (
    SELECT 
        COUNT(*) as total_active_loans,
        SUM(principal_amount) as total_exposure,
        COUNT(CASE WHEN current_risk_level IN ('default_level_1', 'default_level_2') THEN 1 END) as loans_in_default,
        SUM(CASE WHEN current_risk_level IN ('default_level_1', 'default_level_2') THEN principal_amount ELSE 0 END) as amount_in_default,
        COUNT(CASE WHEN current_collections_stage = 'legal_action' THEN 1 END) as loans_in_legal_action,
        COUNT(CASE WHEN current_collections_stage = 'write_off' THEN 1 END) as loans_written_off
    FROM v_current_loan_status_summary 
    WHERE loan_status = 'active'
)
SELECT 
    total_active_loans,
    ROUND(total_exposure, 2) as total_exposure,
    loans_in_default,
    ROUND(amount_in_default, 2) as amount_in_default,
    ROUND(100.0 * loans_in_default / NULLIF(total_active_loans, 0), 2) as default_rate_count_pct,
    ROUND(100.0 * amount_in_default / NULLIF(total_exposure, 0), 2) as default_rate_amount_pct,
    loans_in_legal_action,
    loans_written_off,
    -- Risk categories
    CASE 
        WHEN 100.0 * amount_in_default / NULLIF(total_exposure, 0) > 10 THEN 'HIGH RISK'
        WHEN 100.0 * amount_in_default / NULLIF(total_exposure, 0) > 5 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END as overall_risk_level
FROM current_status;

-- ============================================================================
-- OPERATIONAL DASHBOARD QUERIES
-- ============================================================================

-- Query 4: Collections Performance Dashboard
-- Purpose: Daily collections team performance monitoring
SELECT 
    product_category,
    current_collections_stage,
    loans_in_stage,
    ROUND(principal_at_risk, 2) as principal_at_risk,
    ROUND(avg_max_dpd, 1) as avg_days_past_due,
    ROUND(call_success_rate_pct, 2) as call_success_rate_pct,
    loans_with_legal_action,
    ROUND(total_recovered_amount, 2) as total_recovered_amount,
    ROUND(recovery_rate_pct, 2) as recovery_rate_pct,
    ROUND(avg_recovery_days, 1) as avg_recovery_days,
    -- Performance rating
    CASE 
        WHEN recovery_rate_pct > 70 THEN 'Excellent'
        WHEN recovery_rate_pct > 50 THEN 'Good' 
        WHEN recovery_rate_pct > 30 THEN 'Fair'
        ELSE 'Needs Improvement'
    END as performance_rating
FROM v_collections_performance 
ORDER BY principal_at_risk DESC;

-- Query 5: Cash Flow Projections (Next 8 Weeks)
-- Purpose: Treasury and cash management planning
SELECT 
    week_start,
    currency_code,
    ROUND(scheduled_amount, 2) as expected_collections,
    loans_with_payments,
    ROUND(historical_actual_amount, 2) as historical_actual_amount,
    ROUND(historical_collection_efficiency_pct, 2) as historical_efficiency_pct,
    -- Projected collections based on efficiency
    ROUND(scheduled_amount * COALESCE(historical_collection_efficiency_pct, 85) / 100, 2) as projected_collections,
    -- Week over week growth
    LAG(scheduled_amount) OVER (PARTITION BY currency_code ORDER BY week_start) as previous_week_scheduled,
    ROUND(100.0 * (scheduled_amount - LAG(scheduled_amount) OVER (PARTITION BY currency_code ORDER BY week_start)) / 
          NULLIF(LAG(scheduled_amount) OVER (PARTITION BY currency_code ORDER BY week_start), 0), 2) as week_over_week_growth_pct
FROM v_weekly_cash_flow_projections 
ORDER BY currency_code, week_start;

-- Query 6: DPD Analysis - Current Portfolio Health
-- Purpose: Risk management and early warning system
SELECT 
    dpd_bucket,
    risk_category,
    product_category,
    currency_code,
    loan_count,
    ROUND(total_principal, 2) as total_principal,
    ROUND(pct_of_portfolio_by_count, 2) as pct_of_portfolio_by_count,
    ROUND(pct_of_portfolio_by_amount, 2) as pct_of_portfolio_by_amount,
    -- Risk indicators
    CASE 
        WHEN dpd_bucket IN ('180+ DPD') THEN 'IMMEDIATE ACTION'
        WHEN dpd_bucket IN ('91-180 DPD', '61-90 DPD') THEN 'HIGH PRIORITY'
        WHEN dpd_bucket IN ('31-60 DPD') THEN 'MONITOR CLOSELY'
        WHEN dpd_bucket IN ('8-30 DPD') THEN 'EARLY WARNING'
        ELSE 'NORMAL'
    END as action_required
FROM v_payment_health_summary
WHERE loan_count > 0
ORDER BY 
    CASE dpd_bucket
        WHEN '180+ DPD' THEN 1
        WHEN '91-180 DPD' THEN 2
        WHEN '61-90 DPD' THEN 3
        WHEN '31-60 DPD' THEN 4
        WHEN '8-30 DPD' THEN 5
        WHEN '1-7 DPD' THEN 6
        WHEN 'Current' THEN 7
    END,
    product_category, currency_code;

-- ============================================================================
-- RISK ANALYTICS QUERIES
-- ============================================================================

-- Query 7: Portfolio Concentration Risk Analysis
-- Purpose: Identify concentration risks across multiple dimensions
WITH concentration_summary AS (
    SELECT 
        concentration_type,
        currency_code,
        COUNT(*) as concentration_buckets,
        MAX(portfolio_concentration_pct) as max_concentration_pct,
        COUNT(CASE WHEN concentration_risk_level = 'High Risk' THEN 1 END) as high_risk_concentrations,
        COUNT(CASE WHEN concentration_risk_level = 'Medium Risk' THEN 1 END) as medium_risk_concentrations
    FROM v_portfolio_concentration_analysis
    GROUP BY concentration_type, currency_code
)
SELECT 
    concentration_type,
    currency_code,
    concentration_buckets,
    max_concentration_pct,
    high_risk_concentrations,
    medium_risk_concentrations,
    -- Risk assessment
    CASE 
        WHEN max_concentration_pct > 50 OR high_risk_concentrations > 0 THEN 'HIGH RISK'
        WHEN max_concentration_pct > 25 OR medium_risk_concentrations > 1 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END as overall_concentration_risk
FROM concentration_summary
ORDER BY concentration_type, max_concentration_pct DESC;

-- Query 8: Currency Risk Exposure Report
-- Purpose: FX risk management and hedging decisions
SELECT 
    legal_entity_name,
    entity_functional_currency,
    loan_currency,
    loan_count,
    ROUND(total_exposure_original_ccy, 2) as exposure_original_currency,
    ROUND(total_exposure_functional_ccy, 2) as exposure_functional_currency,
    ROUND(currency_exposure_pct, 2) as currency_exposure_pct,
    fx_risk_level,
    hedging_recommendation,
    -- Calculate potential FX impact (10% currency movement)
    ROUND(total_exposure_functional_ccy * 0.10, 2) as potential_fx_impact_10pct,
    -- Priority for hedging
    CASE 
        WHEN fx_risk_level = 'High FX Risk' AND currency_exposure_pct > 20 THEN 'URGENT'
        WHEN fx_risk_level = 'Medium FX Risk' AND currency_exposure_pct > 15 THEN 'HIGH PRIORITY'
        WHEN fx_risk_level != 'No FX Risk' THEN 'MONITOR'
        ELSE 'NO ACTION'
    END as hedging_priority
FROM v_currency_risk_analysis
WHERE total_exposure_functional_ccy > 0
ORDER BY legal_entity_name, currency_exposure_pct DESC;

-- Query 9: Top Risk Counterparties Report  
-- Purpose: Identify highest risk borrowers for portfolio management
SELECT 
    borrower_name,
    party_type,
    active_loans,
    ROUND(active_exposure, 2) as active_exposure,
    written_off_loans,
    max_dpd_reached,
    ROUND(on_time_payment_rate_pct, 2) as on_time_payment_rate_pct,
    ROUND(avg_days_late, 1) as avg_days_late,
    legal_actions_count,
    risk_rating,
    -- Risk score calculation
    CASE 
        WHEN risk_rating = 'Very High Risk' THEN 10
        WHEN risk_rating = 'High Risk' THEN 8
        WHEN risk_rating = 'Medium Risk' THEN 6
        WHEN risk_rating = 'Low Risk' THEN 4
        ELSE 2
    END as risk_score,
    -- Recommended actions
    CASE 
        WHEN risk_rating IN ('Very High Risk', 'High Risk') AND active_exposure > 50000 THEN 'IMMEDIATE REVIEW'
        WHEN risk_rating = 'High Risk' THEN 'ENHANCED MONITORING'
        WHEN risk_rating = 'Medium Risk' AND on_time_payment_rate_pct < 70 THEN 'WATCH LIST'
        ELSE 'STANDARD MONITORING'
    END as recommended_action
FROM v_counterparty_risk_assessment
WHERE active_exposure > 0
ORDER BY 
    CASE risk_rating 
        WHEN 'Very High Risk' THEN 1
        WHEN 'High Risk' THEN 2
        WHEN 'Medium Risk' THEN 3
        ELSE 4 
    END,
    active_exposure DESC
LIMIT 50;

-- ============================================================================
-- PERFORMANCE ANALYTICS QUERIES
-- ============================================================================

-- Query 10: Origination Performance Analysis
-- Purpose: Business development and product performance tracking
SELECT 
    origination_month,
    product_category,
    legal_entity_name,
    requested_currency,
    total_applications,
    approved_applications,
    loans_created,
    ROUND(avg_requested_amount, 2) as avg_requested_amount,
    ROUND(avg_approved_amount, 2) as avg_approved_amount,
    ROUND(total_disbursed_amount, 2) as total_disbursed_amount,
    ROUND(approval_rate_pct, 2) as approval_rate_pct,
    ROUND(loan_conversion_rate_pct, 2) as conversion_rate_pct,
    ROUND(amount_approval_rate_pct, 2) as amount_approval_rate_pct,
    -- Performance indicators
    CASE 
        WHEN approval_rate_pct > 75 THEN 'High Approval'
        WHEN approval_rate_pct > 50 THEN 'Medium Approval'  
        ELSE 'Low Approval'
    END as approval_performance,
    CASE 
        WHEN loan_conversion_rate_pct > 90 THEN 'Excellent Conversion'
        WHEN loan_conversion_rate_pct > 75 THEN 'Good Conversion'
        ELSE 'Poor Conversion'
    END as conversion_performance,
    -- Month over month growth
    LAG(total_disbursed_amount) OVER (PARTITION BY product_category, legal_entity_name ORDER BY origination_month) as previous_month_disbursed,
    ROUND(100.0 * (total_disbursed_amount - LAG(total_disbursed_amount) OVER (PARTITION BY product_category, legal_entity_name ORDER BY origination_month)) /
          NULLIF(LAG(total_disbursed_amount) OVER (PARTITION BY product_category, legal_entity_name ORDER BY origination_month), 0), 2) as mom_growth_pct
FROM v_origination_performance
WHERE origination_month >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY product_category, legal_entity_name, origination_month DESC;

-- Query 11: Portfolio Quality by Vintage Analysis
-- Purpose: Track portfolio quality over time by origination cohort
SELECT 
    origination_month,
    product_category,
    currency_code,
    loans_originated,
    ROUND(principal_originated, 2) as principal_originated,
    written_off_loans,
    current_default_loans,
    ROUND(written_off_amount, 2) as written_off_amount,
    ROUND(current_default_amount, 2) as current_default_amount,
    portfolio_age_months,
    ROUND(write_off_rate_count_pct, 2) as write_off_rate_count_pct,
    ROUND(write_off_rate_amount_pct, 2) as write_off_rate_amount_pct,
    ROUND(current_default_rate_count_pct, 2) as current_default_rate_count_pct,
    ROUND(current_default_rate_amount_pct, 2) as current_default_rate_amount_pct,
    -- Quality rating by vintage
    CASE 
        WHEN write_off_rate_amount_pct + current_default_rate_amount_pct < 3 THEN 'Excellent'
        WHEN write_off_rate_amount_pct + current_default_rate_amount_pct < 6 THEN 'Good'
        WHEN write_off_rate_amount_pct + current_default_rate_amount_pct < 10 THEN 'Fair'
        ELSE 'Poor'
    END as vintage_quality,
    -- Maturity adjusted performance (for comparison across vintages)
    CASE 
        WHEN portfolio_age_months >= 24 THEN 'Mature'
        WHEN portfolio_age_months >= 12 THEN 'Maturing' 
        WHEN portfolio_age_months >= 6 THEN 'Young'
        ELSE 'New'
    END as vintage_maturity
FROM v_portfolio_quality_metrics
WHERE loans_originated > 0
ORDER BY origination_month DESC, product_category;

-- ============================================================================
-- PREDICTIVE ANALYTICS QUERIES
-- ============================================================================

-- Query 12: ML Feature Analysis for Default Prediction
-- Purpose: Support machine learning model development and monitoring
SELECT 
    product_category,
    business_unit,
    currency_code,
    borrower_type,
    -- Aggregate features for analysis
    COUNT(*) as total_loans,
    AVG(loan_age_days) as avg_loan_age_days,
    AVG(principal_amount) as avg_principal_amount,
    AVG(interest_rate) as avg_interest_rate,
    AVG(on_time_payment_rate_pct) as avg_on_time_payment_rate,
    AVG(avg_days_late) as avg_days_late,
    AVG(max_dpd_reached) as avg_max_dpd_reached,
    AVG(collections_events_count) as avg_collections_events,
    -- Target variable analysis
    COUNT(CASE WHEN is_bad_loan = 1 THEN 1 END) as bad_loans,
    ROUND(100.0 * COUNT(CASE WHEN is_bad_loan = 1 THEN 1 END) / COUNT(*), 2) as bad_loan_rate_pct,
    -- Risk score distribution
    COUNT(CASE WHEN current_risk_score = 'High' THEN 1 END) as high_risk_loans,
    COUNT(CASE WHEN current_risk_score = 'Medium' THEN 1 END) as medium_risk_loans,
    COUNT(CASE WHEN current_risk_score = 'Low' THEN 1 END) as low_risk_loans,
    COUNT(CASE WHEN current_risk_score = 'Minimal' THEN 1 END) as minimal_risk_loans
FROM v_ml_features_default_prediction
GROUP BY product_category, business_unit, currency_code, borrower_type
HAVING COUNT(*) >= 10  -- Minimum sample size
ORDER BY bad_loan_rate_pct DESC, total_loans DESC;

-- Query 13: Early Warning System - High Risk Loans
-- Purpose: Identify loans requiring immediate attention
WITH risk_scoring AS (
    SELECT 
        loan_id,
        product_category,
        borrower_type,
        principal_amount,
        loan_age_days,
        max_dpd_reached,
        on_time_payment_rate_pct,
        avg_days_late,
        collections_events_count,
        current_risk_score,
        is_currently_default,
        -- Calculate composite risk score
        CASE 
            WHEN max_dpd_reached > 90 THEN 40
            WHEN max_dpd_reached > 60 THEN 30
            WHEN max_dpd_reached > 30 THEN 20
            WHEN max_dpd_reached > 0 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN on_time_payment_rate_pct < 50 THEN 30
            WHEN on_time_payment_rate_pct < 70 THEN 20
            WHEN on_time_payment_rate_pct < 85 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN collections_events_count > 10 THEN 20
            WHEN collections_events_count > 5 THEN 15
            WHEN collections_events_count > 0 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN avg_days_late > 20 THEN 10
            WHEN avg_days_late > 10 THEN 5
            ELSE 0
        END as composite_risk_score
    FROM v_ml_features_default_prediction
    WHERE loan_age_days >= 30  -- Only mature loans
)
SELECT 
    loan_id,
    product_category,
    borrower_type,
    ROUND(principal_amount, 2) as principal_amount,
    loan_age_days,
    max_dpd_reached,
    ROUND(on_time_payment_rate_pct, 2) as on_time_payment_rate_pct,
    ROUND(avg_days_late, 1) as avg_days_late,
    collections_events_count,
    current_risk_score,
    composite_risk_score,
    is_currently_default,
    -- Priority classification
    CASE 
        WHEN composite_risk_score >= 80 THEN 'CRITICAL'
        WHEN composite_risk_score >= 60 THEN 'HIGH'
        WHEN composite_risk_score >= 40 THEN 'MEDIUM'
        ELSE 'LOW'
    END as risk_priority,
    -- Recommended action
    CASE 
        WHEN composite_risk_score >= 80 THEN 'IMMEDIATE INTERVENTION'
        WHEN composite_risk_score >= 60 THEN 'ENHANCED COLLECTIONS'
        WHEN composite_risk_score >= 40 THEN 'INCREASED MONITORING'
        ELSE 'STANDARD MONITORING'
    END as recommended_action
FROM risk_scoring
WHERE composite_risk_score >= 40  -- Only medium risk and above
ORDER BY composite_risk_score DESC, principal_amount DESC
LIMIT 100;

-- ============================================================================
-- REGULATORY AND COMPLIANCE QUERIES  
-- ============================================================================

-- Query 14: Regulatory NPL Report
-- Purpose: Non-performing loan regulatory reporting
SELECT 
    legal_entity_name,
    country_code,
    currency_code,
    active_loans,
    ROUND(outstanding_principal, 2) as outstanding_principal,
    performing_loans,
    substandard_loans,
    doubtful_loans,
    loss_loans,
    ROUND(performing_amount, 2) as performing_amount,
    ROUND(substandard_amount, 2) as substandard_amount,
    ROUND(doubtful_amount, 2) as doubtful_amount,
    ROUND(loss_amount, 2) as loss_amount,
    ROUND(required_provisions, 2) as required_provisions,
    ROUND(performing_ratio_pct, 2) as performing_ratio_pct,
    ROUND(npl_ratio_pct, 2) as npl_ratio_pct,
    ROUND(provisioning_ratio_pct, 2) as provisioning_ratio_pct,
    ROUND(charge_off_ratio_pct, 2) as charge_off_ratio_pct,
    npl_compliance_status,
    provisioning_status,
    -- Regulatory classification
    CASE 
        WHEN npl_ratio_pct > 10 THEN 'CRITICAL - REGULATORY REVIEW'
        WHEN npl_ratio_pct > 5 THEN 'HIGH - MANAGEMENT ATTENTION'
        WHEN npl_ratio_pct > 3 THEN 'ELEVATED - MONITOR CLOSELY'
        ELSE 'NORMAL'
    END as regulatory_status,
    CURRENT_DATE as report_date
FROM v_regulatory_compliance_report
ORDER BY legal_entity_name, npl_ratio_pct DESC;

-- Query 15: Multi-Currency Consolidation Report
-- Purpose: Consolidated reporting across all currencies
SELECT 
    legal_entity_name,
    functional_ccy,
    loan_currency,
    active_loans,
    ROUND(outstanding_original_ccy, 2) as outstanding_original_ccy,
    ROUND(outstanding_functional_ccy, 2) as outstanding_functional_ccy,
    ROUND(currency_exposure_pct, 2) as currency_exposure_pct,
    ROUND(fx_rate_to_functional, 6) as current_fx_rate,
    fx_rate_date,
    fx_risk_assessment,
    ROUND(default_rate_by_currency_pct, 2) as default_rate_by_currency_pct,
    -- Summary by entity
    SUM(outstanding_functional_ccy) OVER (PARTITION BY legal_entity_name) as total_entity_portfolio,
    RANK() OVER (PARTITION BY legal_entity_name ORDER BY outstanding_functional_ccy DESC) as currency_rank,
    -- Risk indicators  
    CASE 
        WHEN currency_exposure_pct > 30 AND fx_risk_assessment != 'No FX Risk' THEN 'HIGH CONCENTRATION RISK'
        WHEN currency_exposure_pct > 15 AND fx_risk_assessment = 'High FX Volatility' THEN 'MEDIUM CONCENTRATION RISK'
        ELSE 'ACCEPTABLE'
    END as concentration_risk_level
FROM v_consolidated_multi_currency_report
ORDER BY legal_entity_name, outstanding_functional_ccy DESC;

-- ============================================================================
-- SAMPLE DRILL-DOWN QUERIES
-- ============================================================================

-- Query 16: Drill-down from Portfolio Overview to Individual Loans
-- Purpose: Detailed loan-level analysis for specific portfolio segments
-- Parameters: @product_category, @risk_level, @currency_code

-- Example: Show all high-risk Rently Care D2C loans in SGD
SELECT 
    vd.loan_id,
    vd.loan_number,
    vd.borrower_name,
    vd.product_category,
    vd.currency_code,
    ROUND(vd.principal_amount, 2) as principal_amount,
    vd.current_dpd,
    vd.dpd_bucket,
    vd.risk_category,
    vd.collections_status,
    -- Payment history
    COALESCE(ps.payment_count, 0) as payment_count,
    ROUND(COALESCE(ps.total_allocated, 0), 2) as total_payments_received,
    ps.last_payment_date,
    ROUND(100.0 * COALESCE(ps.total_allocated, 0) / NULLIF(vd.principal_amount, 0), 2) as repayment_progress_pct,
    -- Recent collections activity
    ce.last_collections_event,
    ce.event_type as last_event_type,
    ce.dpd_snapshot as last_dpd,
    -- Action recommendations
    CASE 
        WHEN vd.current_dpd > 90 AND COALESCE(ps.payment_count, 0) = 0 THEN 'LEGAL ACTION REQUIRED'
        WHEN vd.current_dpd > 60 THEN 'INTENSIVE COLLECTIONS'
        WHEN vd.current_dpd > 30 THEN 'ENHANCED MONITORING'
        WHEN vd.current_dpd > 0 THEN 'EARLY COLLECTIONS'
        ELSE 'STANDARD MONITORING'
    END as recommended_action
FROM v_dpd_analysis vd
LEFT JOIN mv_payment_summary_cache ps ON vd.loan_id = ps.loan_id
LEFT JOIN (
    SELECT DISTINCT ON (loan_id) 
        loan_id, event_at as last_collections_event, event_type, dpd_snapshot
    FROM collections_event 
    ORDER BY loan_id, event_at DESC
) ce ON vd.loan_id = ce.loan_id
WHERE vd.product_category = 'rently_care_d2c'  -- @product_category
    AND vd.risk_category IN ('Substandard', 'Doubtful', 'Loss')  -- @risk_level  
    AND vd.currency_code = 'SGD'  -- @currency_code
ORDER BY vd.current_dpd DESC, vd.principal_amount DESC;

-- Query 17: Collections Team Performance Drill-down
-- Purpose: Individual collections agent performance analysis
-- Note: This would require additional agent tracking data

SELECT 
    ce.actor_party_id,
    p.display_name as agent_name,
    COUNT(DISTINCT ce.loan_id) as loans_handled,
    COUNT(*) as total_actions,
    COUNT(CASE WHEN ce.event_type = 'call_successful' THEN 1 END) as successful_calls,
    COUNT(CASE WHEN ce.event_type = 'call_attempt' THEN 1 END) as total_calls,
    COUNT(CASE WHEN ce.resolution_status = 'resolved' THEN 1 END) as cases_resolved,
    AVG(ce.dpd_snapshot) as avg_dpd_handled,
    -- Performance metrics
    ROUND(100.0 * COUNT(CASE WHEN ce.event_type = 'call_successful' THEN 1 END) / 
          NULLIF(COUNT(CASE WHEN ce.event_type = 'call_attempt' THEN 1 END), 0), 2) as call_success_rate_pct,
    ROUND(100.0 * COUNT(CASE WHEN ce.resolution_status = 'resolved' THEN 1 END) / 
          NULLIF(COUNT(DISTINCT ce.loan_id), 0), 2) as resolution_rate_pct,
    -- Recovery analysis (would need payment data linked to collections activities)
    SUM(COALESCE(pa_summary.recovered_amount, 0)) as total_recovered_amount,
    ROUND(SUM(COALESCE(pa_summary.recovered_amount, 0)) / NULLIF(COUNT(DISTINCT ce.loan_id), 0), 2) as avg_recovery_per_loan
FROM collections_event ce
JOIN party p ON ce.actor_party_id = p.id
LEFT JOIN (
    SELECT 
        pa.loan_id,
        SUM(pa.allocated_amount) as recovered_amount
    FROM payment_allocation pa
    JOIN payment pay ON pa.payment_id = pay.id
    WHERE pay.status = 'completed' 
        AND pay.direction = 'inbound'
        AND pay.received_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY pa.loan_id
) pa_summary ON ce.loan_id = pa_summary.loan_id
WHERE ce.event_at >= CURRENT_DATE - INTERVAL '30 days'
    AND ce.actor_party_id IS NOT NULL
    AND p.kind = 'agent'  -- Assuming agents are marked as such
GROUP BY ce.actor_party_id, p.display_name
HAVING COUNT(DISTINCT ce.loan_id) >= 5  -- Minimum activity threshold
ORDER BY resolution_rate_pct DESC, total_recovered_amount DESC;

-- ============================================================================
-- AUTOMATED REPORTING QUERIES
-- ============================================================================

-- Query 18: Daily Operations Report
-- Purpose: Automated daily email report for operations team
SELECT 
    CURRENT_DATE as report_date,
    'Daily Operations Summary' as report_title,
    
    -- Portfolio metrics
    (SELECT COUNT(*) FROM loan WHERE status = 'active') as total_active_loans,
    (SELECT ROUND(SUM(principal_amount), 2) FROM loan WHERE status = 'active') as total_active_portfolio,
    
    -- New loans today  
    (SELECT COUNT(*) FROM loan WHERE start_date = CURRENT_DATE) as new_loans_today,
    (SELECT ROUND(COALESCE(SUM(principal_amount), 0), 2) FROM loan WHERE start_date = CURRENT_DATE) as new_loan_amount_today,
    
    -- Payments received today
    (SELECT COUNT(*) FROM payment WHERE received_at::date = CURRENT_DATE AND status = 'completed' AND direction = 'inbound') as payments_received_today,
    (SELECT ROUND(COALESCE(SUM(amount), 0), 2) FROM payment WHERE received_at::date = CURRENT_DATE AND status = 'completed' AND direction = 'inbound') as payment_amount_today,
    
    -- Collections metrics
    (SELECT COUNT(DISTINCT loan_id) FROM collections_event WHERE event_at::date = CURRENT_DATE) as loans_with_collections_activity,
    (SELECT COUNT(*) FROM collections_event WHERE event_at::date = CURRENT_DATE AND event_type = 'call_successful') as successful_calls_today,
    
    -- Risk indicators
    (SELECT COUNT(*) FROM v_dpd_analysis WHERE dpd_bucket IN ('31-60 DPD', '61-90 DPD', '91-180 DPD', '180+ DPD')) as loans_over_30_dpd,
    (SELECT COUNT(*) FROM v_dpd_analysis WHERE dpd_bucket = '1-7 DPD') as new_overdue_loans,
    
    -- Operational flags
    CASE 
        WHEN (SELECT COUNT(*) FROM v_dpd_analysis WHERE dpd_bucket = '1-7 DPD') > 
             (SELECT AVG(daily_count) FROM (
                 SELECT COUNT(*) as daily_count 
                 FROM collections_event 
                 WHERE event_type = 'first_overdue' 
                   AND event_at >= CURRENT_DATE - INTERVAL '7 days' 
                   AND event_at < CURRENT_DATE
                 GROUP BY event_at::date
             ) avg_calc) * 1.5 
        THEN 'HIGH NEW OVERDUE VOLUME - INVESTIGATE'
        ELSE 'NORMAL'
    END as operational_alert;

-- Query 19: Weekly Executive Summary Report
-- Purpose: Automated weekly report for senior management
WITH weekly_metrics AS (
    SELECT 
        DATE_TRUNC('week', CURRENT_DATE) as week_start,
        DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '6 days' as week_end,
        
        -- Current portfolio
        COUNT(CASE WHEN l.status = 'active' THEN 1 END) as active_loans,
        SUM(CASE WHEN l.status = 'active' THEN l.principal_amount ELSE 0 END) as active_portfolio,
        
        -- This week origination
        COUNT(CASE WHEN l.start_date >= DATE_TRUNC('week', CURRENT_DATE) THEN 1 END) as new_loans_this_week,
        SUM(CASE WHEN l.start_date >= DATE_TRUNC('week', CURRENT_DATE) THEN l.principal_amount ELSE 0 END) as new_loan_amount_this_week,
        
        -- Last week for comparison
        COUNT(CASE WHEN l.start_date >= DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '1 week' 
                   AND l.start_date < DATE_TRUNC('week', CURRENT_DATE) THEN 1 END) as new_loans_last_week,
        SUM(CASE WHEN l.start_date >= DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '1 week' 
                 AND l.start_date < DATE_TRUNC('week', CURRENT_DATE) THEN l.principal_amount ELSE 0 END) as new_loan_amount_last_week
    FROM loan l
    WHERE l.start_date >= CURRENT_DATE - INTERVAL '2 weeks'
),
risk_metrics AS (
    SELECT 
        COUNT(CASE WHEN risk_category IN ('Substandard', 'Doubtful', 'Loss') THEN 1 END) as high_risk_loans,
        SUM(CASE WHEN risk_category IN ('Substandard', 'Doubtful', 'Loss') THEN principal_amount ELSE 0 END) as high_risk_amount,
        COUNT(*) as total_portfolio_loans,
        SUM(principal_amount) as total_portfolio_amount
    FROM v_dpd_analysis
)
SELECT 
    wm.week_start,
    wm.week_end,
    wm.active_loans,
    ROUND(wm.active_portfolio, 2) as active_portfolio,
    wm.new_loans_this_week,
    ROUND(wm.new_loan_amount_this_week, 2) as new_loan_amount_this_week,
    wm.new_loans_last_week,
    ROUND(wm.new_loan_amount_last_week, 2) as new_loan_amount_last_week,
    
    -- Week over week growth
    ROUND(100.0 * (wm.new_loans_this_week - wm.new_loans_last_week) / NULLIF(wm.new_loans_last_week, 0), 2) as loan_count_wow_growth_pct,
    ROUND(100.0 * (wm.new_loan_amount_this_week - wm.new_loan_amount_last_week) / NULLIF(wm.new_loan_amount_last_week, 0), 2) as loan_amount_wow_growth_pct,
    
    -- Risk metrics
    rm.high_risk_loans,
    ROUND(rm.high_risk_amount, 2) as high_risk_amount,
    ROUND(100.0 * rm.high_risk_loans / NULLIF(rm.total_portfolio_loans, 0), 2) as high_risk_rate_count_pct,
    ROUND(100.0 * rm.high_risk_amount / NULLIF(rm.total_portfolio_amount, 0), 2) as high_risk_rate_amount_pct,
    
    -- Performance indicators
    CASE 
        WHEN 100.0 * (wm.new_loan_amount_this_week - wm.new_loan_amount_last_week) / NULLIF(wm.new_loan_amount_last_week, 0) > 10 THEN 'Strong Growth'
        WHEN 100.0 * (wm.new_loan_amount_this_week - wm.new_loan_amount_last_week) / NULLIF(wm.new_loan_amount_last_week, 0) > 0 THEN 'Positive Growth'
        WHEN 100.0 * (wm.new_loan_amount_this_week - wm.new_loan_amount_last_week) / NULLIF(wm.new_loan_amount_last_week, 0) > -10 THEN 'Stable'
        ELSE 'Declining'
    END as growth_trend,
    
    CASE 
        WHEN 100.0 * rm.high_risk_amount / NULLIF(rm.total_portfolio_amount, 0) > 10 THEN 'High Risk Portfolio'
        WHEN 100.0 * rm.high_risk_amount / NULLIF(rm.total_portfolio_amount, 0) > 5 THEN 'Elevated Risk'
        ELSE 'Healthy Portfolio'
    END as risk_assessment
FROM weekly_metrics wm
CROSS JOIN risk_metrics rm;

-- ============================================================================
-- PERFORMANCE MONITORING QUERIES
-- ============================================================================

-- Query 20: View Performance Monitoring
-- Purpose: Monitor performance of analytics views for optimization
SELECT 
    schemaname,
    viewname as view_name,
    'view' as object_type
FROM pg_views 
WHERE schemaname = 'public' 
    AND viewname LIKE 'v_%'
UNION ALL
SELECT 
    schemaname,
    matviewname as view_name,
    'materialized_view' as object_type
FROM pg_matviews 
WHERE schemaname = 'public'
    AND matviewname LIKE 'mv_%'
ORDER BY view_name;

-- Note: Actual query performance monitoring would require additional 
-- pg_stat_statements extension and performance logging setup

-- ============================================================================
-- END OF SAMPLE QUERIES
-- ============================================================================

/* 
USAGE NOTES:

1. Query Performance:
   - All queries are optimized for the defined indexes in the analytics_views.sql
   - Tier 1 queries should execute in <3 seconds
   - Tier 2 queries should execute in <10 seconds

2. Dashboard Integration:
   - Each query includes result formatting for dashboard consumption
   - Results include calculated KPIs and performance indicators
   - Queries support parameterization for drill-down capabilities

3. Refresh Schedules:
   - Real-time queries (1-6): Use direct views, refresh <1 minute
   - Near real-time queries (7-15): Use cached views, refresh 5-15 minutes  
   - Batch queries (16-20): Use materialized views, refresh daily

4. Customization:
   - Replace hardcoded filters with parameters for dynamic dashboards
   - Adjust time ranges based on business requirements
   - Modify thresholds and targets based on business rules

5. Security Considerations:
   - All queries respect row-level security if implemented
   - Sensitive data should be masked based on user roles
   - Query results should be logged for audit purposes
*/