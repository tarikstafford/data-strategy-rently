-- Migration Script: Rently Lending Platform v0 to v1
-- Upgrades existing database schema to enhanced v1 with comprehensive data strategy features
-- Execute this script against an existing v0 database

-- ============================================================================
-- MIGRATION SAFETY CHECKS AND PREPARATION
-- ============================================================================

-- Create migration log table
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status TEXT DEFAULT 'in_progress',
    error_message TEXT,
    rollback_sql TEXT
);

-- Log migration start
INSERT INTO migration_log (migration_name, rollback_sql) 
VALUES ('v0_to_v1_migration', 'See rollback_v1_to_v0.sql for complete rollback procedures');

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- PHASE 1: ENHANCE EXISTING TABLES
-- ============================================================================

-- Enhance legal_entity table
ALTER TABLE legal_entity 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add constraints to legal_entity
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'legal_entity_country_code_check') THEN
        ALTER TABLE legal_entity ADD CONSTRAINT legal_entity_country_code_check 
            CHECK (LENGTH(country_code) = 2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'legal_entity_functional_ccy_check') THEN
        ALTER TABLE legal_entity ADD CONSTRAINT legal_entity_functional_ccy_check 
            CHECK (LENGTH(functional_ccy) = 3);
    END IF;
END $$;

-- Enhance product table with business categorization
ALTER TABLE product 
    ADD COLUMN IF NOT EXISTS category TEXT,
    ADD COLUMN IF NOT EXISTS subcategory TEXT,
    ADD COLUMN IF NOT EXISTS business_unit TEXT,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add product constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'product_category_check') THEN
        ALTER TABLE product ADD CONSTRAINT product_category_check 
            CHECK (category IN ('rently_care_d2c', 'rently_care_collaborative', 'b2b_sme', 'rnpl_uae'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'product_business_unit_check') THEN
        ALTER TABLE product ADD CONSTRAINT product_business_unit_check 
            CHECK (business_unit IN ('residential', 'commercial'));
    END IF;
END $$;

-- Update existing products with default values
UPDATE product SET 
    category = 'rently_care_d2c',
    business_unit = 'residential'
WHERE category IS NULL;

-- Make category and business_unit NOT NULL after updating
ALTER TABLE product 
    ALTER COLUMN category SET NOT NULL,
    ALTER COLUMN business_unit SET NOT NULL;

-- Enhance party table
ALTER TABLE party 
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add party constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'party_kind_check') THEN
        ALTER TABLE party ADD CONSTRAINT party_kind_check 
            CHECK (kind IN ('individual', 'corporate', 'agent', 'broker', 'landlord', 'guarantor'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'party_email_check') THEN
        ALTER TABLE party ADD CONSTRAINT party_email_check 
            CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    END IF;
END $$;

-- Update display_name to be NOT NULL where it isn't already
UPDATE party SET display_name = COALESCE(display_name, 'Unknown') WHERE display_name IS NULL;
ALTER TABLE party ALTER COLUMN display_name SET NOT NULL;

-- Enhance party_role table
ALTER TABLE party_role 
    ADD COLUMN IF NOT EXISTS effective_from DATE DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS effective_through DATE,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add party_role constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'party_role_check') THEN
        ALTER TABLE party_role ADD CONSTRAINT party_role_check 
            CHECK (role IN ('borrower', 'guarantor', 'broker', 'landlord', 'agent'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'party_role_dates_check') THEN
        ALTER TABLE party_role ADD CONSTRAINT party_role_dates_check 
            CHECK (effective_through IS NULL OR effective_through > effective_from);
    END IF;
END $$;

-- Enhance payment_instrument table
ALTER TABLE payment_instrument 
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add payment_instrument constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_instrument_type_check') THEN
        ALTER TABLE payment_instrument ADD CONSTRAINT payment_instrument_type_check 
            CHECK (instrument_type IN ('bank_account', 'credit_card', 'debit_card', 'e_wallet'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_instrument_currency_check') THEN
        ALTER TABLE payment_instrument ADD CONSTRAINT payment_instrument_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Enhance application table
ALTER TABLE application 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Update application status with defaults and add constraints
UPDATE application SET status = 'submitted' WHERE status IS NULL;
ALTER TABLE application ALTER COLUMN status SET NOT NULL;
ALTER TABLE application ALTER COLUMN status SET DEFAULT 'submitted';

-- Add application constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'application_amount_positive') THEN
        ALTER TABLE application ADD CONSTRAINT application_amount_positive 
            CHECK (requested_amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'application_tenor_positive') THEN
        ALTER TABLE application ADD CONSTRAINT application_tenor_positive 
            CHECK (tenor_months > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'application_status_check') THEN
        ALTER TABLE application ADD CONSTRAINT application_status_check 
            CHECK (status IN ('submitted', 'under_review', 'approved', 'rejected', 'withdrawn'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'application_currency_check') THEN
        ALTER TABLE application ADD CONSTRAINT application_currency_check 
            CHECK (LENGTH(requested_currency) = 3);
    END IF;
END $$;

-- Enhance decision table
ALTER TABLE decision 
    ADD COLUMN IF NOT EXISTS decided_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS reason TEXT;

-- Add decision constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'decision_outcome_check') THEN
        ALTER TABLE decision ADD CONSTRAINT decision_outcome_check 
            CHECK (outcome IN ('approved', 'rejected', 'conditional'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'decision_approved_amount_check') THEN
        ALTER TABLE decision ADD CONSTRAINT decision_approved_amount_check 
            CHECK ((outcome = 'approved' AND approved_amount > 0) OR 
                   (outcome != 'approved' AND approved_amount IS NULL));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'decision_approved_currency_check') THEN
        ALTER TABLE decision ADD CONSTRAINT decision_approved_currency_check 
            CHECK (approved_currency IS NULL OR LENGTH(approved_currency) = 3);
    END IF;
END $$;

-- Enhance loan table with rental-specific fields
ALTER TABLE loan 
    ADD COLUMN IF NOT EXISTS installment_period TEXT,
    ADD COLUMN IF NOT EXISTS lease_start_date DATE,
    ADD COLUMN IF NOT EXISTS lease_end_date DATE,
    ADD COLUMN IF NOT EXISTS agent_party_id UUID,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add foreign key for agent_party_id
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'loan_agent_party_id_fkey') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_agent_party_id_fkey 
            FOREIGN KEY (agent_party_id) REFERENCES party(id) ON DELETE RESTRICT;
    END IF;
END $$;

-- Update loan status with defaults and add constraints
UPDATE loan SET status = 'active' WHERE status IS NULL;
ALTER TABLE loan ALTER COLUMN status SET NOT NULL;
ALTER TABLE loan ALTER COLUMN status SET DEFAULT 'active';

-- Add loan constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_amounts_positive') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_amounts_positive 
            CHECK (principal_amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_dates_check') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_dates_check 
            CHECK (end_date > start_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_lease_dates_check') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_lease_dates_check 
            CHECK (lease_end_date IS NULL OR lease_start_date IS NULL OR lease_end_date > lease_start_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_status_check') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_status_check 
            CHECK (status IN ('active', 'closed', 'written_off', 'transferred'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_currency_check') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'loan_installment_period_check') THEN
        ALTER TABLE loan ADD CONSTRAINT loan_installment_period_check 
            CHECK (installment_period IS NULL OR installment_period ~* '^\d+/\d+$');
    END IF;
END $$;

-- Enhance amortisation_plan table
ALTER TABLE amortisation_plan 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Update amortisation_plan with defaults and add constraints
UPDATE amortisation_plan SET status = 'active' WHERE status IS NULL;
UPDATE amortisation_plan SET version = 1 WHERE version IS NULL;
ALTER TABLE amortisation_plan ALTER COLUMN status SET NOT NULL;
ALTER TABLE amortisation_plan ALTER COLUMN status SET DEFAULT 'active';
ALTER TABLE amortisation_plan ALTER COLUMN version SET NOT NULL;
ALTER TABLE amortisation_plan ALTER COLUMN version SET DEFAULT 1;

-- Add amortisation_plan constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_plan_version_positive') THEN
        ALTER TABLE amortisation_plan ADD CONSTRAINT amortisation_plan_version_positive 
            CHECK (version > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_plan_status_check') THEN
        ALTER TABLE amortisation_plan ADD CONSTRAINT amortisation_plan_status_check 
            CHECK (status IN ('active', 'superseded', 'cancelled'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_plan_dates_check') THEN
        ALTER TABLE amortisation_plan ADD CONSTRAINT amortisation_plan_dates_check 
            CHECK (effective_through IS NULL OR effective_through > effective_from);
    END IF;
END $$;

-- Add amortisation_line constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_line_seq_positive') THEN
        ALTER TABLE amortisation_line ADD CONSTRAINT amortisation_line_seq_positive 
            CHECK (seq_no > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_line_amounts_non_negative') THEN
        ALTER TABLE amortisation_line ADD CONSTRAINT amortisation_line_amounts_non_negative 
            CHECK (amount_principal >= 0 AND amount_rc_fee >= 0 AND 
                   amount_penalty >= 0 AND amount_other >= 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'amortisation_line_currency_check') THEN
        ALTER TABLE amortisation_line ADD CONSTRAINT amortisation_line_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Update amortisation_line amounts with defaults
UPDATE amortisation_line SET 
    amount_principal = COALESCE(amount_principal, 0),
    amount_rc_fee = COALESCE(amount_rc_fee, 0),
    amount_penalty = COALESCE(amount_penalty, 0),
    amount_other = COALESCE(amount_other, 0);

ALTER TABLE amortisation_line 
    ALTER COLUMN amount_principal SET NOT NULL,
    ALTER COLUMN amount_principal SET DEFAULT 0.00,
    ALTER COLUMN amount_rc_fee SET NOT NULL,
    ALTER COLUMN amount_rc_fee SET DEFAULT 0.00,
    ALTER COLUMN amount_penalty SET NOT NULL,
    ALTER COLUMN amount_penalty SET DEFAULT 0.00,
    ALTER COLUMN amount_other SET NOT NULL,
    ALTER COLUMN amount_other SET DEFAULT 0.00;

-- Enhance payment table
ALTER TABLE payment 
    ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Update payment with defaults and add constraints
UPDATE payment SET status = 'pending' WHERE status IS NULL;
ALTER TABLE payment ALTER COLUMN status SET NOT NULL;
ALTER TABLE payment ALTER COLUMN status SET DEFAULT 'pending';

-- Add payment constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_amount_positive') THEN
        ALTER TABLE payment ADD CONSTRAINT payment_amount_positive 
            CHECK (amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_direction_check') THEN
        ALTER TABLE payment ADD CONSTRAINT payment_direction_check 
            CHECK (direction IN ('inbound', 'outbound'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_status_check') THEN
        ALTER TABLE payment ADD CONSTRAINT payment_status_check 
            CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_currency_check') THEN
        ALTER TABLE payment ADD CONSTRAINT payment_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Enhance disbursement table
ALTER TABLE disbursement 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Update disbursement with defaults and add constraints
UPDATE disbursement SET status = 'pending' WHERE status IS NULL;
ALTER TABLE disbursement ALTER COLUMN status SET NOT NULL;
ALTER TABLE disbursement ALTER COLUMN status SET DEFAULT 'pending';

-- Add disbursement constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'disbursement_amount_positive') THEN
        ALTER TABLE disbursement ADD CONSTRAINT disbursement_amount_positive 
            CHECK (amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'disbursement_status_check') THEN
        ALTER TABLE disbursement ADD CONSTRAINT disbursement_status_check 
            CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'disbursement_currency_check') THEN
        ALTER TABLE disbursement ADD CONSTRAINT disbursement_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Enhance payment_allocation table
ALTER TABLE payment_allocation 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add payment_allocation constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_allocation_amount_positive') THEN
        ALTER TABLE payment_allocation ADD CONSTRAINT payment_allocation_amount_positive 
            CHECK (allocated_amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'payment_allocation_component_check') THEN
        ALTER TABLE payment_allocation ADD CONSTRAINT payment_allocation_component_check 
            CHECK (component IN ('principal', 'rc_fee', 'penalty', 'other'));
    END IF;
END $$;

-- Enhance ledger_account table
ALTER TABLE ledger_account 
    ADD COLUMN IF NOT EXISTS parent_account_id UUID,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add ledger_account foreign key and constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'ledger_account_parent_account_id_fkey') THEN
        ALTER TABLE ledger_account ADD CONSTRAINT ledger_account_parent_account_id_fkey 
            FOREIGN KEY (parent_account_id) REFERENCES ledger_account(id) ON DELETE RESTRICT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'ledger_account_type_check') THEN
        ALTER TABLE ledger_account ADD CONSTRAINT ledger_account_type_check 
            CHECK (type IN ('asset', 'liability', 'equity', 'revenue', 'expense'));
    END IF;
END $$;

-- Make ledger_account fields NOT NULL where appropriate
UPDATE ledger_account SET name = COALESCE(name, 'Unknown Account') WHERE name IS NULL;
ALTER TABLE ledger_account ALTER COLUMN name SET NOT NULL;

-- Enhance ledger_entry table
ALTER TABLE ledger_entry 
    ADD COLUMN IF NOT EXISTS entry_date DATE DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add ledger_entry constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'ledger_entry_amount_positive') THEN
        ALTER TABLE ledger_entry ADD CONSTRAINT ledger_entry_amount_positive 
            CHECK (amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'ledger_entry_side_check') THEN
        ALTER TABLE ledger_entry ADD CONSTRAINT ledger_entry_side_check 
            CHECK (side IN ('debit', 'credit'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'ledger_entry_currency_check') THEN
        ALTER TABLE ledger_entry ADD CONSTRAINT ledger_entry_currency_check 
            CHECK (LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Update ledger_entry with defaults
UPDATE ledger_entry SET entry_date = CURRENT_DATE WHERE entry_date IS NULL;
ALTER TABLE ledger_entry ALTER COLUMN entry_date SET NOT NULL;

-- Enhance security_interest table
ALTER TABLE security_interest 
    ADD COLUMN IF NOT EXISTS registration_date DATE,
    ADD COLUMN IF NOT EXISTS expiry_date DATE,
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add security_interest constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'security_interest_type_check') THEN
        ALTER TABLE security_interest ADD CONSTRAINT security_interest_type_check 
            CHECK (type IN ('property', 'vehicle', 'deposit', 'guarantee', 'other'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'security_interest_value_positive') THEN
        ALTER TABLE security_interest ADD CONSTRAINT security_interest_value_positive 
            CHECK (value_amount IS NULL OR value_amount > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'security_interest_dates_check') THEN
        ALTER TABLE security_interest ADD CONSTRAINT security_interest_dates_check 
            CHECK (expiry_date IS NULL OR registration_date IS NULL OR expiry_date > registration_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'security_interest_status_check') THEN
        ALTER TABLE security_interest ADD CONSTRAINT security_interest_status_check 
            CHECK (status IN ('active', 'released', 'expired', 'enforced'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'security_interest_currency_check') THEN
        ALTER TABLE security_interest ADD CONSTRAINT security_interest_currency_check 
            CHECK (value_ccy IS NULL OR LENGTH(value_ccy) = 3);
    END IF;
END $$;

-- Enhance collections_event table with new fields
ALTER TABLE collections_event 
    ADD COLUMN IF NOT EXISTS consecutive_missed_payments INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS escalation_trigger TEXT,
    ADD COLUMN IF NOT EXISTS resolution_status TEXT,
    ADD COLUMN IF NOT EXISTS next_action_date DATE,
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- Update collections_event with defaults and add constraints
UPDATE collections_event SET dpd_snapshot = COALESCE(dpd_snapshot, 0);
UPDATE collections_event SET event_at = COALESCE(event_at, CURRENT_TIMESTAMP);
UPDATE collections_event SET consecutive_missed_payments = COALESCE(consecutive_missed_payments, 0);

ALTER TABLE collections_event 
    ALTER COLUMN dpd_snapshot SET NOT NULL,
    ALTER COLUMN dpd_snapshot SET DEFAULT 0,
    ALTER COLUMN event_at SET NOT NULL,
    ALTER COLUMN event_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN consecutive_missed_payments SET DEFAULT 0;

-- Add collections_event constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_dpd_non_negative') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_dpd_non_negative 
            CHECK (dpd_snapshot >= 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_consecutive_non_negative') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_consecutive_non_negative 
            CHECK (consecutive_missed_payments >= 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_amount_positive') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_amount_positive 
            CHECK (amount_involved IS NULL OR amount_involved > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_type_check') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_type_check 
            CHECK (event_type IN (
                'first_overdue', 'reminder_sent', 'call_attempt', 'call_successful',
                'payment_arrangement', 'legal_notice', 'lawyer_letter', 'court_filing',
                'asset_recovery', 'write_off', 'settlement_offer', 'settlement_accepted'
            ));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_resolution_check') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_resolution_check 
            CHECK (resolution_status IS NULL OR resolution_status IN (
                'pending', 'in_progress', 'resolved', 'escalated', 'closed'
            ));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'collections_event_currency_check') THEN
        ALTER TABLE collections_event ADD CONSTRAINT collections_event_currency_check 
            CHECK (currency_code IS NULL OR LENGTH(currency_code) = 3);
    END IF;
END $$;

-- Enhance document table
ALTER TABLE document 
    ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS mime_type TEXT,
    ADD COLUMN IF NOT EXISTS checksum TEXT,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP;

-- Update document with defaults and add constraints
UPDATE document SET uploaded_at = COALESCE(uploaded_at, CURRENT_TIMESTAMP);
UPDATE document SET title = COALESCE(title, 'Untitled Document') WHERE title IS NULL;
ALTER TABLE document ALTER COLUMN title SET NOT NULL;
ALTER TABLE document ALTER COLUMN uploaded_at SET DEFAULT CURRENT_TIMESTAMP;

-- Add document constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'document_kind_check') THEN
        ALTER TABLE document ADD CONSTRAINT document_kind_check 
            CHECK (kind IN (
                'application_form', 'identity_document', 'income_proof', 'lease_agreement',
                'property_valuation', 'legal_notice', 'court_document', 'payment_receipt',
                'contract', 'correspondence', 'other'
            ));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'document_file_size_positive') THEN
        ALTER TABLE document ADD CONSTRAINT document_file_size_positive 
            CHECK (file_size_bytes IS NULL OR file_size_bytes > 0);
    END IF;
END $$;

-- Enhance document_link table
ALTER TABLE document_link 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add document_link constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'document_link_entity_type_check') THEN
        ALTER TABLE document_link ADD CONSTRAINT document_link_entity_type_check 
            CHECK (entity_type IN (
                'application', 'loan', 'party', 'payment', 'disbursement',
                'collections_event', 'security_interest'
            ));
    END IF;
END $$;

-- Enhance fx_rate table
ALTER TABLE fx_rate 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add fx_rate constraints
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'fx_rate_positive') THEN
        ALTER TABLE fx_rate ADD CONSTRAINT fx_rate_positive 
            CHECK (rate > 0);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'fx_rate_currencies_different') THEN
        ALTER TABLE fx_rate ADD CONSTRAINT fx_rate_currencies_different 
            CHECK (from_ccy != to_ccy);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'fx_rate_from_ccy_check') THEN
        ALTER TABLE fx_rate ADD CONSTRAINT fx_rate_from_ccy_check 
            CHECK (LENGTH(from_ccy) = 3);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.check_constraints 
                   WHERE constraint_name = 'fx_rate_to_ccy_check') THEN
        ALTER TABLE fx_rate ADD CONSTRAINT fx_rate_to_ccy_check 
            CHECK (LENGTH(to_ccy) = 3);
    END IF;
END $$;

-- Update fx_rate with defaults
UPDATE fx_rate SET source = COALESCE(source, 'manual') WHERE source IS NULL;
ALTER TABLE fx_rate ALTER COLUMN source SET NOT NULL;

-- ============================================================================
-- PHASE 2: CREATE NEW TABLES
-- ============================================================================

-- Operational Status Management System
CREATE TABLE IF NOT EXISTS loan_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE CASCADE,
    status_type TEXT NOT NULL,
    status_value TEXT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_through TIMESTAMP,
    reason TEXT,
    created_by UUID REFERENCES party(id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT loan_status_history_type_check CHECK (
        status_type IN ('risk_level', 'collections_stage', 'legal_action', 'operational_status')
    ),
    CONSTRAINT loan_status_history_dates_check CHECK (
        effective_through IS NULL OR effective_through > effective_from
    )
);

-- Payment Disputes Management
CREATE TABLE IF NOT EXISTS payment_disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID REFERENCES payment(id) ON DELETE RESTRICT,
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE RESTRICT,
    dispute_type TEXT NOT NULL,
    expected_amount NUMERIC(15,2),
    actual_amount NUMERIC(15,2),
    status TEXT NOT NULL DEFAULT 'open',
    reported_by UUID NOT NULL REFERENCES party(id) ON DELETE RESTRICT,
    assigned_to UUID REFERENCES party(id) ON DELETE RESTRICT,
    priority TEXT DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    
    CONSTRAINT payment_disputes_type_check CHECK (
        dispute_type IN ('amount_mismatch', 'timing_issue', 'allocation_error', 'unauthorized_payment', 'duplicate_payment')
    ),
    CONSTRAINT payment_disputes_status_check CHECK (
        status IN ('open', 'investigating', 'resolved', 'closed', 'escalated')
    ),
    CONSTRAINT payment_disputes_priority_check CHECK (
        priority IN ('low', 'medium', 'high', 'critical')
    ),
    CONSTRAINT payment_disputes_amounts_positive CHECK (
        (expected_amount IS NULL OR expected_amount > 0) AND
        (actual_amount IS NULL OR actual_amount > 0)
    )
);

-- Loan Transfer Management
CREATE TABLE IF NOT EXISTS loan_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE RESTRICT,
    target_loan_id UUID REFERENCES loan(id) ON DELETE RESTRICT,
    transfer_type TEXT NOT NULL,
    transfer_amount NUMERIC(15,2) NOT NULL,
    transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    approved_by UUID REFERENCES party(id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    
    CONSTRAINT loan_transfers_type_check CHECK (
        transfer_type IN ('apartment_change', 'lease_renewal', 'refinance', 'consolidation')
    ),
    CONSTRAINT loan_transfers_status_check CHECK (
        status IN ('pending', 'approved', 'processing', 'completed', 'cancelled', 'rejected')
    ),
    CONSTRAINT loan_transfers_amount_positive CHECK (transfer_amount > 0)
);

-- ============================================================================
-- PHASE 3: CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Core entity indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_entity_country ON legal_entity(country_code);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_category_business_unit ON product(category, business_unit);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_active ON product(is_active) WHERE is_active = true;

-- Party and relationship indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_kind ON party(kind);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_email ON party(email) WHERE email IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_active ON party(is_active) WHERE is_active = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_role_loan ON party_role(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_role_party ON party_role(party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_party_role_effective ON party_role(effective_from, effective_through);

-- Payment instrument indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_instrument_party ON payment_instrument(party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_instrument_default ON payment_instrument(is_default) WHERE is_default = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_instrument_active ON payment_instrument(is_active) WHERE is_active = true;

-- Application workflow indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_application_status ON application(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_application_product ON application(product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_application_applicant ON application(applicant_party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_application_created ON application(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_decision_application ON decision(application_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_decision_outcome ON decision(outcome);

-- Loan management indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status ON loan(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_borrower ON loan(borrower_party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_product ON loan(product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_dates ON loan(start_date, end_date);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_agent ON loan(agent_party_id) WHERE agent_party_id IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_parent ON loan(parent_loan_id) WHERE parent_loan_id IS NOT NULL;

-- Status tracking indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_loan ON loan_status_history(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_type ON loan_status_history(status_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_effective ON loan_status_history(effective_from, effective_through);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_current ON loan_status_history(loan_id, status_type) 
    WHERE effective_through IS NULL;

-- Amortization indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_amortisation_plan_loan ON amortisation_plan(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_amortisation_plan_status ON amortisation_plan(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_amortisation_plan_effective ON amortisation_plan(effective_from, effective_through);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_amortisation_line_plan ON amortisation_line(plan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_amortisation_line_due_date ON amortisation_line(due_date);

-- Payment processing indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_status ON payment(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_received_at ON payment(received_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_payer ON payment(payer_party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_payee ON payment(payee_party_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_external_ref ON payment(external_reference) WHERE external_reference IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_disbursement_loan ON disbursement(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_disbursement_status ON disbursement(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_allocation_payment ON payment_allocation(payment_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_allocation_loan ON payment_allocation(loan_id);

-- Collections indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_loan ON collections_event(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_type ON collections_event(event_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_date ON collections_event(event_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_dpd ON collections_event(dpd_snapshot);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_next_action ON collections_event(next_action_date) 
    WHERE next_action_date IS NOT NULL;

-- Accounting indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_account_entity ON ledger_account(legal_entity_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_account_code ON ledger_account(legal_entity_id, code);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_account_active ON ledger_account(is_active) WHERE is_active = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_account ON ledger_entry(account_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_loan ON ledger_entry(loan_id) WHERE loan_id IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_payment ON ledger_entry(payment_id) WHERE payment_id IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_date ON ledger_entry(entry_date);

-- Document indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_kind ON document(kind);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_uploaded ON document(uploaded_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_expires ON document(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_link_entity ON document_link(entity_type, entity_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_link_document ON document_link(document_id);

-- Reference data indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fx_rate_date ON fx_rate(as_of_date);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fx_rate_currencies ON fx_rate(from_ccy, to_ccy);

-- New table indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_disputes_status ON payment_disputes(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_disputes_loan ON payment_disputes(loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_disputes_assigned ON payment_disputes(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_disputes_priority ON payment_disputes(priority);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_disputes_created ON payment_disputes(created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_transfers_source ON loan_transfers(source_loan_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_transfers_target ON loan_transfers(target_loan_id) WHERE target_loan_id IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_transfers_status ON loan_transfers(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_transfers_type ON loan_transfers(transfer_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_transfers_date ON loan_transfers(transfer_date);

-- ============================================================================
-- PHASE 4: CREATE TRIGGERS AND FUNCTIONS
-- ============================================================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for timestamp updates (only if they don't exist)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_legal_entity_updated_at') THEN
        CREATE TRIGGER update_legal_entity_updated_at BEFORE UPDATE ON legal_entity
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_product_updated_at') THEN
        CREATE TRIGGER update_product_updated_at BEFORE UPDATE ON product
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_party_updated_at') THEN
        CREATE TRIGGER update_party_updated_at BEFORE UPDATE ON party
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_payment_instrument_updated_at') THEN
        CREATE TRIGGER update_payment_instrument_updated_at BEFORE UPDATE ON payment_instrument
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_application_updated_at') THEN
        CREATE TRIGGER update_application_updated_at BEFORE UPDATE ON application
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_loan_updated_at') THEN
        CREATE TRIGGER update_loan_updated_at BEFORE UPDATE ON loan
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- ============================================================================
-- PHASE 5: CREATE VIEWS
-- ============================================================================

-- Current loan status view
CREATE OR REPLACE VIEW current_loan_status AS
SELECT DISTINCT ON (lsh.loan_id, lsh.status_type)
    lsh.loan_id,
    lsh.status_type,
    lsh.status_value,
    lsh.effective_from,
    lsh.reason
FROM loan_status_history lsh
WHERE lsh.effective_through IS NULL
ORDER BY lsh.loan_id, lsh.status_type, lsh.effective_from DESC;

-- Active payment instruments view
CREATE OR REPLACE VIEW active_payment_instruments AS
SELECT pi.*
FROM payment_instrument pi
WHERE pi.is_active = true;

-- Loan portfolio summary view
CREATE OR REPLACE VIEW loan_portfolio_summary AS
SELECT 
    l.legal_entity_id,
    p.category,
    p.business_unit,
    l.currency_code,
    l.status,
    COUNT(*) as loan_count,
    SUM(l.principal_amount) as total_principal,
    AVG(l.interest_rate) as avg_interest_rate,
    MIN(l.start_date) as earliest_start,
    MAX(l.end_date) as latest_end
FROM loan l
JOIN product p ON l.product_id = p.id
GROUP BY l.legal_entity_id, p.category, p.business_unit, l.currency_code, l.status;

-- ============================================================================
-- PHASE 6: POPULATE INITIAL DATA
-- ============================================================================

-- Update migration log for initial data population
UPDATE migration_log SET status = 'populating_data' WHERE migration_name = 'v0_to_v1_migration';

-- Create initial loan status history entries for existing loans
INSERT INTO loan_status_history (loan_id, status_type, status_value, effective_from, reason)
SELECT 
    l.id,
    'operational_status',
    l.status,
    l.start_date,
    'Initial status from migration'
FROM loan l
WHERE NOT EXISTS (
    SELECT 1 FROM loan_status_history lsh 
    WHERE lsh.loan_id = l.id AND lsh.status_type = 'operational_status'
);

-- Add unique constraints that might have been missed
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'party_role_unique_active_role') THEN
        ALTER TABLE party_role ADD CONSTRAINT party_role_unique_active_role 
            UNIQUE (party_id, loan_id, role, effective_from);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'amortisation_plan_unique_loan_version') THEN
        ALTER TABLE amortisation_plan ADD CONSTRAINT amortisation_plan_unique_loan_version 
            UNIQUE (loan_id, version);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'amortisation_line_unique_plan_seq') THEN
        ALTER TABLE amortisation_line ADD CONSTRAINT amortisation_line_unique_plan_seq 
            UNIQUE (plan_id, seq_no);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'ledger_account_unique_entity_code') THEN
        ALTER TABLE ledger_account ADD CONSTRAINT ledger_account_unique_entity_code 
            UNIQUE (legal_entity_id, code);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'document_link_unique_document_entity') THEN
        ALTER TABLE document_link ADD CONSTRAINT document_link_unique_document_entity 
            UNIQUE (document_id, entity_type, entity_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'fx_rate_unique_date_currencies_source') THEN
        ALTER TABLE fx_rate ADD CONSTRAINT fx_rate_unique_date_currencies_source 
            UNIQUE (as_of_date, from_ccy, to_ccy, source);
    END IF;
END $$;

-- ============================================================================
-- PHASE 7: CREATE SCHEMA VERSION TRACKING
-- ============================================================================

-- Create schema version table
CREATE TABLE IF NOT EXISTS schema_version (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Insert version information
INSERT INTO schema_version (version, description) VALUES
('1.0', 'Enhanced Rently Lending Platform schema with comprehensive data strategy implementation')
ON CONFLICT (version) DO UPDATE SET 
    applied_at = CURRENT_TIMESTAMP,
    description = EXCLUDED.description;

-- ============================================================================
-- MIGRATION COMPLETION
-- ============================================================================

-- Update migration log completion
UPDATE migration_log 
SET 
    completed_at = CURRENT_TIMESTAMP,
    status = 'completed'
WHERE migration_name = 'v0_to_v1_migration';

-- Final verification query
DO $$ 
DECLARE 
    table_count INTEGER;
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    
    SELECT COUNT(*) INTO index_count 
    FROM pg_indexes 
    WHERE schemaname = 'public';
    
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'Total tables: %', table_count;
    RAISE NOTICE 'Total indexes: %', index_count;
    RAISE NOTICE 'Schema version: 1.0';
END $$;

-- ============================================================================
-- POST-MIGRATION RECOMMENDATIONS
-- ============================================================================

/*
POST-MIGRATION CHECKLIST:

1. Run ANALYZE on all tables to update statistics:
   ANALYZE;

2. Verify all foreign key relationships:
   SELECT COUNT(*) FROM information_schema.referential_constraints;

3. Check constraint violations:
   -- Run specific queries to verify data integrity

4. Update application connection strings if needed

5. Test application functionality with enhanced schema

6. Monitor query performance and add additional indexes if needed

7. Set up regular maintenance:
   - VACUUM and ANALYZE schedules
   - Index maintenance
   - Statistics updates

8. Backup the migrated database:
   pg_dump -h localhost -U username -d database_name > rently_v1_backup.sql

ROLLBACK INSTRUCTIONS:
- If rollback is needed, use the rollback script: rollback_v1_to_v0.sql
- Restore from backup taken before migration
- Contact DBA team for assistance with complex rollback scenarios
*/