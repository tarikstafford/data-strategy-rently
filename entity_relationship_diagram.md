# Entity Relationship Diagram - Rently Lending Platform

```mermaid
erDiagram
    LEGAL_ENTITY {
        uuid id PK
        text name
        text registration_no
        char country_code
        char functional_ccy
    }
    
    PRODUCT {
        uuid id PK
        text code UK
        text name
        text description
    }
    
    PARTY {
        uuid id PK
        text kind
        text display_name
        text email
        text phone
        text external_ref
        text kyc_identifier
    }
    
    PARTY_ROLE {
        uuid id PK
        uuid party_id FK
        uuid loan_id FK
        text role
    }
    
    PAYMENT_INSTRUMENT {
        uuid id PK
        uuid party_id FK
        text instrument_type
        char currency_code
        text bank_name
        text account_name
        text account_number
        text provider_ref
        boolean is_default
    }
    
    APPLICATION {
        uuid id PK
        text application_number UK
        uuid product_id FK
        uuid legal_entity_id FK
        uuid applicant_party_id FK
        numeric requested_amount
        char requested_currency
        int tenor_months
        text status
    }
    
    DECISION {
        uuid id PK
        uuid application_id FK
        text outcome
        numeric approved_amount
        char approved_currency
        text decided_by
    }
    
    LOAN {
        uuid id PK
        text loan_number UK
        uuid application_id FK
        uuid product_id FK
        uuid legal_entity_id FK
        uuid borrower_party_id FK
        char currency_code
        numeric principal_amount
        numeric rc_fee_rate
        numeric interest_rate
        date start_date
        date end_date
        uuid parent_loan_id FK
        text property_contract_id
        text status
    }
    
    AMORTISATION_PLAN {
        uuid id PK
        uuid loan_id FK
        int version
        text status
        text reason
        date effective_from
        date effective_through
    }
    
    AMORTISATION_LINE {
        uuid id PK
        uuid plan_id FK
        int seq_no
        date due_date
        char currency_code
        numeric amount_principal
        numeric amount_rc_fee
        numeric amount_penalty
        numeric amount_other
    }
    
    PAYMENT {
        uuid id PK
        uuid legal_entity_id FK
        char currency_code
        numeric amount
        text direction
        text provider
        text external_reference
        uuid payer_party_id FK
        uuid payee_party_id FK
        uuid instrument_id FK
        timestamp received_at
        text status
    }
    
    DISBURSEMENT {
        uuid id PK
        uuid loan_id FK
        uuid legal_entity_id FK
        uuid instrument_id FK
        char currency_code
        numeric amount
        timestamp disbursed_at
        text status
    }
    
    PAYMENT_ALLOCATION {
        uuid id PK
        uuid payment_id FK
        uuid loan_id FK
        uuid plan_id FK
        uuid line_id FK
        text component
        numeric allocated_amount
    }
    
    LEDGER_ACCOUNT {
        uuid id PK
        uuid legal_entity_id FK
        text code
        text name
        text type
    }
    
    LEDGER_ENTRY {
        uuid id PK
        uuid legal_entity_id FK
        uuid account_id FK
        uuid loan_id FK
        uuid payment_id FK
        uuid disbursement_id FK
        char currency_code
        numeric amount
        text side
    }
    
    SECURITY_INTEREST {
        uuid id PK
        uuid loan_id FK
        text type
        uuid party_id FK
        text description
        numeric value_amount
        char value_ccy
    }
    
    COLLECTIONS_EVENT {
        uuid id PK
        uuid loan_id FK
        text event_type
        timestamp event_at
        uuid actor_party_id FK
        int dpd_snapshot
        numeric amount_involved
        char currency_code
    }
    
    DOCUMENT {
        uuid id PK
        text title
        text kind
        text storage_url
        timestamp uploaded_at
    }
    
    DOCUMENT_LINK {
        uuid id PK
        uuid document_id FK
        text entity_type
        uuid entity_id
        text role
    }
    
    FX_RATE {
        uuid id PK
        date as_of_date
        char from_ccy
        char to_ccy
        numeric rate
        text source
    }

    %% Relationships
    PARTY ||--o{ PARTY_ROLE : has
    LOAN ||--o{ PARTY_ROLE : involves
    
    PARTY ||--o{ PAYMENT_INSTRUMENT : owns
    
    PRODUCT ||--o{ APPLICATION : for
    LEGAL_ENTITY ||--o{ APPLICATION : processes
    PARTY ||--|| APPLICATION : applies
    
    APPLICATION ||--o| DECISION : receives
    
    APPLICATION ||--o| LOAN : becomes
    PRODUCT ||--o{ LOAN : type
    LEGAL_ENTITY ||--o{ LOAN : lends
    PARTY ||--o{ LOAN : borrows
    LOAN ||--o{ LOAN : refinances
    
    LOAN ||--o{ AMORTISATION_PLAN : has
    AMORTISATION_PLAN ||--o{ AMORTISATION_LINE : contains
    
    LEGAL_ENTITY ||--o{ PAYMENT : processes
    PARTY ||--o{ PAYMENT : pays
    PARTY ||--o{ PAYMENT : receives
    PAYMENT_INSTRUMENT ||--o{ PAYMENT : uses
    
    LOAN ||--o{ DISBURSEMENT : receives
    LEGAL_ENTITY ||--o{ DISBURSEMENT : makes
    PAYMENT_INSTRUMENT ||--o{ DISBURSEMENT : via
    
    PAYMENT ||--o{ PAYMENT_ALLOCATION : allocated
    LOAN ||--o{ PAYMENT_ALLOCATION : toward
    AMORTISATION_PLAN ||--o{ PAYMENT_ALLOCATION : against
    AMORTISATION_LINE ||--o{ PAYMENT_ALLOCATION : specifically
    
    LEGAL_ENTITY ||--o{ LEDGER_ACCOUNT : maintains
    LEDGER_ACCOUNT ||--o{ LEDGER_ENTRY : records
    LEGAL_ENTITY ||--o{ LEDGER_ENTRY : books
    LOAN ||--o{ LEDGER_ENTRY : affects
    PAYMENT ||--o{ LEDGER_ENTRY : creates
    DISBURSEMENT ||--o{ LEDGER_ENTRY : generates
    
    LOAN ||--o{ SECURITY_INTEREST : secured_by
    PARTY ||--o{ SECURITY_INTEREST : provides
    
    LOAN ||--o{ COLLECTIONS_EVENT : has
    PARTY ||--o{ COLLECTIONS_EVENT : acts_in
    
    DOCUMENT ||--o{ DOCUMENT_LINK : linked_via
```

## Key Relationships Summary

### Core Business Flow
1. **Party** applies for **Product** via **Application**
2. **Application** receives **Decision** 
3. Approved **Application** becomes **Loan**
4. **Loan** has **Amortisation Plan** with **Lines**
5. **Payments** are allocated against **Amortisation Lines**
6. All transactions create **Ledger Entries**

### Supporting Structures
- **Payment Instruments** facilitate payments and disbursements
- **Security Interests** provide collateral backing
- **Collections Events** track recovery activities
- **Documents** can be linked to any entity
- **FX Rates** support multi-currency operations