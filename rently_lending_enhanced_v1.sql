-- Rently Lending Platform Enhanced Database Schema v1.0
-- PostgreSQL DDL with comprehensive enhancements for operational excellence
-- Based on comprehensive data strategy requirements

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE BUSINESS ENTITIES
-- ============================================================================

-- Legal Entity Management
CREATE TABLE legal_entity (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    registration_no TEXT,
    country_code CHAR(2) NOT NULL,
    functional_ccy CHAR(3) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT legal_entity_country_code_check CHECK (LENGTH(country_code) = 2),
    CONSTRAINT legal_entity_functional_ccy_check CHECK (LENGTH(functional_ccy) = 3)
);

COMMENT ON TABLE legal_entity IS 'Legal entities operating the lending platform';
COMMENT ON COLUMN legal_entity.functional_ccy IS 'ISO 4217 functional currency code';

-- Enhanced Product Catalog with Business Categorization
CREATE TABLE product (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    -- Enhanced product categorization
    category TEXT NOT NULL,
    subcategory TEXT,
    business_unit TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT product_category_check CHECK (
        category IN ('rently_care_d2c', 'rently_care_collaborative', 'b2b_sme', 'rnpl_uae')
    ),
    CONSTRAINT product_business_unit_check CHECK (
        business_unit IN ('residential', 'commercial')
    )
);

COMMENT ON TABLE product IS 'Loan product definitions with enhanced categorization';
COMMENT ON COLUMN product.category IS 'Primary business category: rently_care_d2c, rently_care_collaborative, b2b_sme, rnpl_uae';
COMMENT ON COLUMN product.business_unit IS 'Business unit classification: residential, commercial';

-- Party Management (Customers, Guarantors, Agents, etc.)
CREATE TABLE party (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kind TEXT NOT NULL,
    display_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    external_ref TEXT,
    kyc_identifier TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT party_kind_check CHECK (
        kind IN ('individual', 'corporate', 'agent', 'broker', 'landlord', 'guarantor')
    ),
    CONSTRAINT party_email_check CHECK (
        email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

COMMENT ON TABLE party IS 'All parties involved in lending operations';
COMMENT ON COLUMN party.kind IS 'Party type: individual, corporate, agent, broker, landlord, guarantor';

-- Party Roles in Loans
CREATE TABLE party_role (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id UUID NOT NULL REFERENCES party(id) ON DELETE RESTRICT,
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_through DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT party_role_check CHECK (
        role IN ('borrower', 'guarantor', 'broker', 'landlord', 'agent')
    ),
    CONSTRAINT party_role_dates_check CHECK (
        effective_through IS NULL OR effective_through > effective_from
    ),
    UNIQUE (party_id, loan_id, role, effective_from)
);

COMMENT ON TABLE party_role IS 'Roles that parties play in specific loans';

-- Payment Instruments (Bank Accounts, Cards, etc.)
CREATE TABLE payment_instrument (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id UUID NOT NULL REFERENCES party(id) ON DELETE CASCADE,
    instrument_type TEXT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    bank_name TEXT,
    account_name TEXT,
    account_number TEXT,
    provider_ref TEXT,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT payment_instrument_type_check CHECK (
        instrument_type IN ('bank_account', 'credit_card', 'debit_card', 'e_wallet')
    ),
    CONSTRAINT payment_instrument_currency_check CHECK (LENGTH(currency_code) = 3)
);

COMMENT ON TABLE payment_instrument IS 'Payment instruments for disbursements and collections';

-- ============================================================================
-- APPLICATION & DECISION WORKFLOW
-- ============================================================================

-- Loan Applications
CREATE TABLE application (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_number TEXT NOT NULL UNIQUE,
    product_id UUID NOT NULL REFERENCES product(id) ON DELETE RESTRICT,
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    applicant_party_id UUID NOT NULL REFERENCES party(id) ON DELETE RESTRICT,
    requested_amount NUMERIC(15,2) NOT NULL,
    requested_currency CHAR(3) NOT NULL,
    tenor_months INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'submitted',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT application_amount_positive CHECK (requested_amount > 0),
    CONSTRAINT application_tenor_positive CHECK (tenor_months > 0),
    CONSTRAINT application_status_check CHECK (
        status IN ('submitted', 'under_review', 'approved', 'rejected', 'withdrawn')
    ),
    CONSTRAINT application_currency_check CHECK (LENGTH(requested_currency) = 3)
);

COMMENT ON TABLE application IS 'Loan applications from customers';

-- Application Decisions
CREATE TABLE decision (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_id UUID NOT NULL REFERENCES application(id) ON DELETE RESTRICT,
    outcome TEXT NOT NULL,
    approved_amount NUMERIC(15,2),
    approved_currency CHAR(3),
    decided_by TEXT NOT NULL,
    decided_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    
    CONSTRAINT decision_outcome_check CHECK (
        outcome IN ('approved', 'rejected', 'conditional')
    ),
    CONSTRAINT decision_approved_amount_check CHECK (
        (outcome = 'approved' AND approved_amount > 0) OR 
        (outcome != 'approved' AND approved_amount IS NULL)
    ),
    CONSTRAINT decision_approved_currency_check CHECK (
        approved_currency IS NULL OR LENGTH(approved_currency) = 3
    )
);

COMMENT ON TABLE decision IS 'Application approval decisions';

-- ============================================================================
-- LOAN MANAGEMENT
-- ============================================================================

-- Enhanced Loans with Rental-Specific Fields
CREATE TABLE loan (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_number TEXT NOT NULL UNIQUE,
    application_id UUID REFERENCES application(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES product(id) ON DELETE RESTRICT,
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    borrower_party_id UUID NOT NULL REFERENCES party(id) ON DELETE RESTRICT,
    currency_code CHAR(3) NOT NULL,
    principal_amount NUMERIC(15,2) NOT NULL,
    rc_fee_rate NUMERIC(5,4) DEFAULT 0.0000,
    interest_rate NUMERIC(5,4) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    parent_loan_id UUID REFERENCES loan(id) ON DELETE RESTRICT,
    property_contract_id TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    -- Rental-specific enhancements
    installment_period TEXT,
    lease_start_date DATE,
    lease_end_date DATE,
    agent_party_id UUID REFERENCES party(id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT loan_amounts_positive CHECK (principal_amount > 0),
    CONSTRAINT loan_dates_check CHECK (end_date > start_date),
    CONSTRAINT loan_lease_dates_check CHECK (
        lease_end_date IS NULL OR lease_start_date IS NULL OR lease_end_date > lease_start_date
    ),
    CONSTRAINT loan_status_check CHECK (
        status IN ('active', 'closed', 'written_off', 'transferred')
    ),
    CONSTRAINT loan_currency_check CHECK (LENGTH(currency_code) = 3),
    CONSTRAINT loan_installment_period_check CHECK (
        installment_period IS NULL OR installment_period ~* '^\d+/\d+$'
    )
);

COMMENT ON TABLE loan IS 'Active loans with rental-specific enhancements';
COMMENT ON COLUMN loan.installment_period IS 'Installment tracking (e.g., 1/12, 2/12)';
COMMENT ON COLUMN loan.agent_party_id IS 'Property agent responsible for the lease';

-- Operational Status Management System
CREATE TABLE loan_status_history (
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

COMMENT ON TABLE loan_status_history IS 'Historical tracking of loan operational status changes';
COMMENT ON COLUMN loan_status_history.status_type IS 'Type: risk_level, collections_stage, legal_action, operational_status';

-- Amortization Planning
CREATE TABLE amortisation_plan (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE CASCADE,
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active',
    reason TEXT,
    effective_from DATE NOT NULL,
    effective_through DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT amortisation_plan_version_positive CHECK (version > 0),
    CONSTRAINT amortisation_plan_status_check CHECK (
        status IN ('active', 'superseded', 'cancelled')
    ),
    CONSTRAINT amortisation_plan_dates_check CHECK (
        effective_through IS NULL OR effective_through > effective_from
    ),
    UNIQUE (loan_id, version)
);

COMMENT ON TABLE amortisation_plan IS 'Versioned amortization schedules for loans';

-- Amortization Schedule Lines
CREATE TABLE amortisation_line (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL REFERENCES amortisation_plan(id) ON DELETE CASCADE,
    seq_no INTEGER NOT NULL,
    due_date DATE NOT NULL,
    currency_code CHAR(3) NOT NULL,
    amount_principal NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    amount_rc_fee NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    amount_penalty NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    amount_other NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    
    CONSTRAINT amortisation_line_seq_positive CHECK (seq_no > 0),
    CONSTRAINT amortisation_line_amounts_non_negative CHECK (
        amount_principal >= 0 AND amount_rc_fee >= 0 AND 
        amount_penalty >= 0 AND amount_other >= 0
    ),
    CONSTRAINT amortisation_line_currency_check CHECK (LENGTH(currency_code) = 3),
    UNIQUE (plan_id, seq_no)
);

COMMENT ON TABLE amortisation_line IS 'Individual payment schedule entries';

-- ============================================================================
-- PAYMENT PROCESSING
-- ============================================================================

-- Payment Transactions
CREATE TABLE payment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    currency_code CHAR(3) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    direction TEXT NOT NULL,
    provider TEXT,
    external_reference TEXT,
    payer_party_id UUID REFERENCES party(id) ON DELETE RESTRICT,
    payee_party_id UUID REFERENCES party(id) ON DELETE RESTRICT,
    instrument_id UUID REFERENCES payment_instrument(id) ON DELETE RESTRICT,
    received_at TIMESTAMP,
    processed_at TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT payment_amount_positive CHECK (amount > 0),
    CONSTRAINT payment_direction_check CHECK (direction IN ('inbound', 'outbound')),
    CONSTRAINT payment_status_check CHECK (
        status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')
    ),
    CONSTRAINT payment_currency_check CHECK (LENGTH(currency_code) = 3)
);

COMMENT ON TABLE payment IS 'All payment transactions (inbound and outbound)';

-- Loan Disbursements
CREATE TABLE disbursement (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE RESTRICT,
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    instrument_id UUID NOT NULL REFERENCES payment_instrument(id) ON DELETE RESTRICT,
    currency_code CHAR(3) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    disbursed_at TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT disbursement_amount_positive CHECK (amount > 0),
    CONSTRAINT disbursement_status_check CHECK (
        status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')
    ),
    CONSTRAINT disbursement_currency_check CHECK (LENGTH(currency_code) = 3)
);

COMMENT ON TABLE disbursement IS 'Loan fund disbursements to borrowers';

-- Payment Allocation to Loans
CREATE TABLE payment_allocation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES payment(id) ON DELETE CASCADE,
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE RESTRICT,
    plan_id UUID REFERENCES amortisation_plan(id) ON DELETE RESTRICT,
    line_id UUID REFERENCES amortisation_line(id) ON DELETE RESTRICT,
    component TEXT NOT NULL,
    allocated_amount NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT payment_allocation_amount_positive CHECK (allocated_amount > 0),
    CONSTRAINT payment_allocation_component_check CHECK (
        component IN ('principal', 'rc_fee', 'penalty', 'other')
    )
);

COMMENT ON TABLE payment_allocation IS 'Allocation of payments to specific loan components';

-- ============================================================================
-- ENHANCED COLLECTIONS MANAGEMENT
-- ============================================================================

-- Enhanced Collections Events
CREATE TABLE collections_event (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor_party_id UUID REFERENCES party(id) ON DELETE RESTRICT,
    dpd_snapshot INTEGER NOT NULL DEFAULT 0,
    amount_involved NUMERIC(15,2),
    currency_code CHAR(3),
    -- Enhanced collections fields
    consecutive_missed_payments INTEGER DEFAULT 0,
    escalation_trigger TEXT,
    resolution_status TEXT,
    next_action_date DATE,
    notes TEXT,
    
    CONSTRAINT collections_event_dpd_non_negative CHECK (dpd_snapshot >= 0),
    CONSTRAINT collections_event_consecutive_non_negative CHECK (consecutive_missed_payments >= 0),
    CONSTRAINT collections_event_amount_positive CHECK (
        amount_involved IS NULL OR amount_involved > 0
    ),
    CONSTRAINT collections_event_type_check CHECK (
        event_type IN (
            'first_overdue', 'reminder_sent', 'call_attempt', 'call_successful',
            'payment_arrangement', 'legal_notice', 'lawyer_letter', 'court_filing',
            'asset_recovery', 'write_off', 'settlement_offer', 'settlement_accepted'
        )
    ),
    CONSTRAINT collections_event_resolution_check CHECK (
        resolution_status IS NULL OR resolution_status IN (
            'pending', 'in_progress', 'resolved', 'escalated', 'closed'
        )
    ),
    CONSTRAINT collections_event_currency_check CHECK (
        currency_code IS NULL OR LENGTH(currency_code) = 3
    )
);

COMMENT ON TABLE collections_event IS 'Enhanced collections workflow tracking with escalation management';

-- ============================================================================
-- ACCOUNTING & LEDGER
-- ============================================================================

-- Chart of Accounts
CREATE TABLE ledger_account (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    parent_account_id UUID REFERENCES ledger_account(id) ON DELETE RESTRICT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ledger_account_type_check CHECK (
        type IN ('asset', 'liability', 'equity', 'revenue', 'expense')
    ),
    UNIQUE (legal_entity_id, code)
);

COMMENT ON TABLE ledger_account IS 'Chart of accounts for double-entry bookkeeping';

-- Double-Entry Ledger Entries
CREATE TABLE ledger_entry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    legal_entity_id UUID NOT NULL REFERENCES legal_entity(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES ledger_account(id) ON DELETE RESTRICT,
    loan_id UUID REFERENCES loan(id) ON DELETE RESTRICT,
    payment_id UUID REFERENCES payment(id) ON DELETE RESTRICT,
    disbursement_id UUID REFERENCES disbursement(id) ON DELETE RESTRICT,
    currency_code CHAR(3) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    side TEXT NOT NULL,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ledger_entry_amount_positive CHECK (amount > 0),
    CONSTRAINT ledger_entry_side_check CHECK (side IN ('debit', 'credit')),
    CONSTRAINT ledger_entry_currency_check CHECK (LENGTH(currency_code) = 3)
);

COMMENT ON TABLE ledger_entry IS 'Double-entry accounting ledger entries';

-- ============================================================================
-- COLLATERAL & SECURITY
-- ============================================================================

-- Security Interests (Collateral)
CREATE TABLE security_interest (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loan(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    party_id UUID REFERENCES party(id) ON DELETE RESTRICT,
    description TEXT,
    value_amount NUMERIC(15,2),
    value_ccy CHAR(3),
    registration_date DATE,
    expiry_date DATE,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT security_interest_type_check CHECK (
        type IN ('property', 'vehicle', 'deposit', 'guarantee', 'other')
    ),
    CONSTRAINT security_interest_value_positive CHECK (
        value_amount IS NULL OR value_amount > 0
    ),
    CONSTRAINT security_interest_dates_check CHECK (
        expiry_date IS NULL OR registration_date IS NULL OR expiry_date > registration_date
    ),
    CONSTRAINT security_interest_status_check CHECK (
        status IN ('active', 'released', 'expired', 'enforced')
    ),
    CONSTRAINT security_interest_currency_check CHECK (
        value_ccy IS NULL OR LENGTH(value_ccy) = 3
    )
);

COMMENT ON TABLE security_interest IS 'Collateral and security interests for loans';

-- ============================================================================
-- DOCUMENT MANAGEMENT
-- ============================================================================

-- Document Repository
CREATE TABLE document (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    kind TEXT NOT NULL,
    storage_url TEXT NOT NULL,
    file_size_bytes BIGINT,
    mime_type TEXT,
    checksum TEXT,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    CONSTRAINT document_kind_check CHECK (
        kind IN (
            'application_form', 'identity_document', 'income_proof', 'lease_agreement',
            'property_valuation', 'legal_notice', 'court_document', 'payment_receipt',
            'contract', 'correspondence', 'other'
        )
    ),
    CONSTRAINT document_file_size_positive CHECK (file_size_bytes IS NULL OR file_size_bytes > 0)
);

COMMENT ON TABLE document IS 'Document repository with metadata tracking';

-- Document Links to Entities
CREATE TABLE document_link (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES document(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    role TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT document_link_entity_type_check CHECK (
        entity_type IN (
            'application', 'loan', 'party', 'payment', 'disbursement',
            'collections_event', 'security_interest'
        )
    ),
    UNIQUE (document_id, entity_type, entity_id)
);

COMMENT ON TABLE document_link IS 'Links documents to various business entities';

-- ============================================================================
-- REFERENCE DATA
-- ============================================================================

-- FX Rates for Multi-Currency Operations
CREATE TABLE fx_rate (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    as_of_date DATE NOT NULL,
    from_ccy CHAR(3) NOT NULL,
    to_ccy CHAR(3) NOT NULL,
    rate NUMERIC(12,6) NOT NULL,
    source TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fx_rate_positive CHECK (rate > 0),
    CONSTRAINT fx_rate_currencies_different CHECK (from_ccy != to_ccy),
    CONSTRAINT fx_rate_from_ccy_check CHECK (LENGTH(from_ccy) = 3),
    CONSTRAINT fx_rate_to_ccy_check CHECK (LENGTH(to_ccy) = 3),
    UNIQUE (as_of_date, from_ccy, to_ccy, source)
);

COMMENT ON TABLE fx_rate IS 'Foreign exchange rates for currency conversion';

-- ============================================================================
-- DISPUTE MANAGEMENT SYSTEM
-- ============================================================================

-- Payment Disputes
CREATE TABLE payment_disputes (
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

COMMENT ON TABLE payment_disputes IS 'Payment discrepancy and dispute management';

-- ============================================================================
-- TRANSFER MANAGEMENT
-- ============================================================================

-- Loan Transfers (Apartment Changes, Refinancing)
CREATE TABLE loan_transfers (
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

COMMENT ON TABLE loan_transfers IS 'Management of loan transfers, apartment changes, and refinancing';

-- ============================================================================
-- PERFORMANCE INDEXES
-- ============================================================================

-- Core entity indexes
CREATE INDEX idx_legal_entity_country ON legal_entity(country_code);
CREATE INDEX idx_product_category_business_unit ON product(category, business_unit);
CREATE INDEX idx_product_active ON product(is_active) WHERE is_active = true;

-- Party and relationship indexes
CREATE INDEX idx_party_kind ON party(kind);
CREATE INDEX idx_party_email ON party(email) WHERE email IS NOT NULL;
CREATE INDEX idx_party_active ON party(is_active) WHERE is_active = true;
CREATE INDEX idx_party_role_loan ON party_role(loan_id);
CREATE INDEX idx_party_role_party ON party_role(party_id);
CREATE INDEX idx_party_role_effective ON party_role(effective_from, effective_through);

-- Payment instrument indexes
CREATE INDEX idx_payment_instrument_party ON payment_instrument(party_id);
CREATE INDEX idx_payment_instrument_default ON payment_instrument(is_default) WHERE is_default = true;
CREATE INDEX idx_payment_instrument_active ON payment_instrument(is_active) WHERE is_active = true;

-- Application workflow indexes
CREATE INDEX idx_application_status ON application(status);
CREATE INDEX idx_application_product ON application(product_id);
CREATE INDEX idx_application_applicant ON application(applicant_party_id);
CREATE INDEX idx_application_created ON application(created_at);
CREATE INDEX idx_decision_application ON decision(application_id);
CREATE INDEX idx_decision_outcome ON decision(outcome);

-- Loan management indexes
CREATE INDEX idx_loan_status ON loan(status);
CREATE INDEX idx_loan_borrower ON loan(borrower_party_id);
CREATE INDEX idx_loan_product ON loan(product_id);
CREATE INDEX idx_loan_dates ON loan(start_date, end_date);
CREATE INDEX idx_loan_agent ON loan(agent_party_id) WHERE agent_party_id IS NOT NULL;
CREATE INDEX idx_loan_parent ON loan(parent_loan_id) WHERE parent_loan_id IS NOT NULL;

-- Status tracking indexes
CREATE INDEX idx_loan_status_history_loan ON loan_status_history(loan_id);
CREATE INDEX idx_loan_status_history_type ON loan_status_history(status_type);
CREATE INDEX idx_loan_status_history_effective ON loan_status_history(effective_from, effective_through);
CREATE INDEX idx_loan_status_history_current ON loan_status_history(loan_id, status_type) 
    WHERE effective_through IS NULL;

-- Amortization indexes
CREATE INDEX idx_amortisation_plan_loan ON amortisation_plan(loan_id);
CREATE INDEX idx_amortisation_plan_status ON amortisation_plan(status);
CREATE INDEX idx_amortisation_plan_effective ON amortisation_plan(effective_from, effective_through);
CREATE INDEX idx_amortisation_line_plan ON amortisation_line(plan_id);
CREATE INDEX idx_amortisation_line_due_date ON amortisation_line(due_date);

-- Payment processing indexes
CREATE INDEX idx_payment_status ON payment(status);
CREATE INDEX idx_payment_received_at ON payment(received_at);
CREATE INDEX idx_payment_payer ON payment(payer_party_id);
CREATE INDEX idx_payment_payee ON payment(payee_party_id);
CREATE INDEX idx_payment_external_ref ON payment(external_reference) WHERE external_reference IS NOT NULL;
CREATE INDEX idx_disbursement_loan ON disbursement(loan_id);
CREATE INDEX idx_disbursement_status ON disbursement(status);
CREATE INDEX idx_payment_allocation_payment ON payment_allocation(payment_id);
CREATE INDEX idx_payment_allocation_loan ON payment_allocation(loan_id);

-- Collections indexes
CREATE INDEX idx_collections_event_loan ON collections_event(loan_id);
CREATE INDEX idx_collections_event_type ON collections_event(event_type);
CREATE INDEX idx_collections_event_date ON collections_event(event_at);
CREATE INDEX idx_collections_event_dpd ON collections_event(dpd_snapshot);
CREATE INDEX idx_collections_event_next_action ON collections_event(next_action_date) 
    WHERE next_action_date IS NOT NULL;

-- Accounting indexes
CREATE INDEX idx_ledger_account_entity ON ledger_account(legal_entity_id);
CREATE INDEX idx_ledger_account_code ON ledger_account(legal_entity_id, code);
CREATE INDEX idx_ledger_account_active ON ledger_account(is_active) WHERE is_active = true;
CREATE INDEX idx_ledger_entry_account ON ledger_entry(account_id);
CREATE INDEX idx_ledger_entry_loan ON ledger_entry(loan_id) WHERE loan_id IS NOT NULL;
CREATE INDEX idx_ledger_entry_payment ON ledger_entry(payment_id) WHERE payment_id IS NOT NULL;
CREATE INDEX idx_ledger_entry_date ON ledger_entry(entry_date);

-- Document indexes
CREATE INDEX idx_document_kind ON document(kind);
CREATE INDEX idx_document_uploaded ON document(uploaded_at);
CREATE INDEX idx_document_expires ON document(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_document_link_entity ON document_link(entity_type, entity_id);
CREATE INDEX idx_document_link_document ON document_link(document_id);

-- Reference data indexes
CREATE INDEX idx_fx_rate_date ON fx_rate(as_of_date);
CREATE INDEX idx_fx_rate_currencies ON fx_rate(from_ccy, to_ccy);

-- Dispute management indexes
CREATE INDEX idx_payment_disputes_status ON payment_disputes(status);
CREATE INDEX idx_payment_disputes_loan ON payment_disputes(loan_id);
CREATE INDEX idx_payment_disputes_assigned ON payment_disputes(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_payment_disputes_priority ON payment_disputes(priority);
CREATE INDEX idx_payment_disputes_created ON payment_disputes(created_at);

-- Transfer management indexes
CREATE INDEX idx_loan_transfers_source ON loan_transfers(source_loan_id);
CREATE INDEX idx_loan_transfers_target ON loan_transfers(target_loan_id) WHERE target_loan_id IS NOT NULL;
CREATE INDEX idx_loan_transfers_status ON loan_transfers(status);
CREATE INDEX idx_loan_transfers_type ON loan_transfers(transfer_type);
CREATE INDEX idx_loan_transfers_date ON loan_transfers(transfer_date);

-- ============================================================================
-- AUDIT TRIGGERS
-- ============================================================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_legal_entity_updated_at BEFORE UPDATE ON legal_entity
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_updated_at BEFORE UPDATE ON product
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_party_updated_at BEFORE UPDATE ON party
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_instrument_updated_at BEFORE UPDATE ON payment_instrument
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_application_updated_at BEFORE UPDATE ON application
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loan_updated_at BEFORE UPDATE ON loan
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Current loan status view
CREATE VIEW current_loan_status AS
SELECT DISTINCT ON (lsh.loan_id, lsh.status_type)
    lsh.loan_id,
    lsh.status_type,
    lsh.status_value,
    lsh.effective_from,
    lsh.reason
FROM loan_status_history lsh
WHERE lsh.effective_through IS NULL
ORDER BY lsh.loan_id, lsh.status_type, lsh.effective_from DESC;

COMMENT ON VIEW current_loan_status IS 'Current status for all loans by status type';

-- Active payment instruments view
CREATE VIEW active_payment_instruments AS
SELECT pi.*
FROM payment_instrument pi
WHERE pi.is_active = true;

COMMENT ON VIEW active_payment_instruments IS 'Currently active payment instruments';

-- Loan portfolio summary view
CREATE VIEW loan_portfolio_summary AS
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

COMMENT ON VIEW loan_portfolio_summary IS 'Portfolio summary by entity, product category, and status';

-- ============================================================================
-- INITIAL REFERENCE DATA
-- ============================================================================

-- Insert common product categories (sample data)
INSERT INTO legal_entity (id, name, registration_no, country_code, functional_ccy) VALUES
(uuid_generate_v4(), 'Rently Technologies Pte Ltd', '202012345A', 'SG', 'SGD'),
(uuid_generate_v4(), 'Rently UAE DMCC', 'DMCC123456', 'AE', 'AED');

-- Sample products
INSERT INTO product (id, code, name, description, category, subcategory, business_unit) VALUES
(uuid_generate_v4(), 'RC_D2C_001', 'Rently Care D2C Standard', 'Standard D2C rental financing', 'rently_care_d2c', 'standard', 'residential'),
(uuid_generate_v4(), 'RC_COLLAB_001', 'Rently Care Collaborative Basic', 'Basic collaborative rental product', 'rently_care_collaborative', 'basic', 'residential'),
(uuid_generate_v4(), 'B2B_SME_001', 'SME Business Rental', 'Small business rental financing', 'b2b_sme', 'standard', 'commercial'),
(uuid_generate_v4(), 'RNPL_UAE_001', 'Rently Now Pay Later UAE', 'UAE rental payment solution', 'rnpl_uae', 'standard', 'residential');

-- ============================================================================
-- GRANTS AND SECURITY
-- ============================================================================

-- Grant appropriate permissions (modify as needed for your security model)
-- These would typically be customized based on your application roles

-- Example: Create application user role
-- CREATE ROLE rently_app_user;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rently_app_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO rently_app_user;

-- ============================================================================
-- SCHEMA VERSION TRACKING
-- ============================================================================

CREATE TABLE schema_version (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

INSERT INTO schema_version (version, description) VALUES
('1.0', 'Enhanced Rently Lending Platform schema with comprehensive data strategy implementation');

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================