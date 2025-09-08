# Business Process Data Flow - Rently Lending Platform

## 1. Loan Application Process

```mermaid
flowchart TD
    START([Start]) --> PARTY_REG[Register Party<br/>KYC & Documentation]
    PARTY_REG --> PI[Setup Payment Instruments]
    PI --> APP_CREATE[Create Application<br/>Product + Amount + Terms]
    APP_CREATE --> DOC_UPLOAD[Upload Supporting Documents]
    DOC_UPLOAD --> UW_REVIEW[Underwriter Review]
    
    UW_REVIEW --> DECISION{Decision}
    DECISION -->|Approved| LOAN_CREATE[Create Loan Record]
    DECISION -->|Rejected| APP_REJECT[Application Rejected]
    
    LOAN_CREATE --> AMORT_PLAN[Generate Amortisation Plan]
    AMORT_PLAN --> SECURITY[Setup Security Interests]
    SECURITY --> DISBURSEMENT[Process Disbursement]
    DISBURSEMENT --> LEDGER_DISB[Record Disbursement<br/>in Ledger]
    
    LEDGER_DISB --> LOAN_ACTIVE[Loan Active]
    APP_REJECT --> END([End])
    LOAN_ACTIVE --> END

    %% Data entities involved
    PARTY_REG -.-> |Creates| P[party, document, document_link]
    PI -.-> |Creates| PMI[payment_instrument]
    APP_CREATE -.-> |Creates| A[application]
    DOC_UPLOAD -.-> |Creates| D[document, document_link]
    UW_REVIEW -.-> |Creates| DEC[decision]
    LOAN_CREATE -.-> |Creates| L[loan, party_role]
    AMORT_PLAN -.-> |Creates| AP[amortisation_plan, amortisation_line]
    SECURITY -.-> |Creates| SI[security_interest]
    DISBURSEMENT -.-> |Creates| DISB[disbursement]
    LEDGER_DISB -.-> |Creates| LE[ledger_entry]
```

## 2. Payment Processing & Allocation

```mermaid
flowchart TD
    PAY_RECEIVED[Payment Received<br/>from Borrower] --> PAY_RECORD[Record Payment<br/>with Status]
    PAY_RECORD --> VALIDATE[Validate Payment<br/>Amount & Currency]
    
    VALIDATE --> GET_PLAN[Get Current<br/>Amortisation Plan]
    GET_PLAN --> ALLOCATE[Allocate Payment<br/>to Plan Lines]
    
    ALLOCATE --> COMPONENTS{Allocation Priority}
    COMPONENTS -->|1st| PENALTY[Penalty Amount]
    COMPONENTS -->|2nd| RC_FEE[RC Fee Amount]
    COMPONENTS -->|3rd| PRINCIPAL[Principal Amount]
    COMPONENTS -->|4th| OTHER[Other Charges]
    
    PENALTY --> LEDGER_P[Record Penalty<br/>Ledger Entry]
    RC_FEE --> LEDGER_F[Record Fee<br/>Ledger Entry]
    PRINCIPAL --> LEDGER_PR[Record Principal<br/>Ledger Entry]
    OTHER --> LEDGER_O[Record Other<br/>Ledger Entry]
    
    LEDGER_P --> CHECK_STATUS
    LEDGER_F --> CHECK_STATUS
    LEDGER_PR --> CHECK_STATUS
    LEDGER_O --> CHECK_STATUS
    
    CHECK_STATUS[Check Loan Status] --> COMPLETE{Loan Paid Off?}
    COMPLETE -->|Yes| CLOSE_LOAN[Close Loan]
    COMPLETE -->|No| CONTINUE[Continue Monitoring]
    
    CLOSE_LOAN --> END([End])
    CONTINUE --> END

    %% Data entities involved
    PAY_RECEIVED -.-> |Creates| PAY[payment]
    ALLOCATE -.-> |Creates| PA[payment_allocation]
    LEDGER_P -.-> |Creates| LEP[ledger_entry]
    LEDGER_F -.-> |Creates| LEF[ledger_entry]
    LEDGER_PR -.-> |Creates| LEPR[ledger_entry]
    LEDGER_O -.-> |Creates| LEO[ledger_entry]
```

## 3. Collections & Recovery Process

```mermaid
flowchart TD
    MONITOR[Daily Payment Monitoring] --> CHECK_DUE[Check Due Dates<br/>vs Payments Received]
    CHECK_DUE --> OVERDUE{Payment Overdue?}
    
    OVERDUE -->|No| CONTINUE_MONITOR[Continue Monitoring]
    OVERDUE -->|Yes| CALC_DPD[Calculate Days<br/>Past Due (DPD)]
    
    CALC_DPD --> DPD_BUCKET{DPD Bucket}
    DPD_BUCKET -->|1-30 days| SOFT_COLLECTIONS[Soft Collections<br/>SMS/Email Reminders]
    DPD_BUCKET -->|31-60 days| CALL_COLLECTIONS[Call Collections<br/>Direct Contact]
    DPD_BUCKET -->|60+ days| HARD_COLLECTIONS[Hard Collections<br/>Legal/Recovery Action]
    
    SOFT_COLLECTIONS --> LOG_SOFT[Log Collections Event<br/>Type: Reminder]
    CALL_COLLECTIONS --> LOG_CALL[Log Collections Event<br/>Type: Contact]
    HARD_COLLECTIONS --> LOG_HARD[Log Collections Event<br/>Type: Legal]
    
    LOG_SOFT --> RESPONSE_SOFT{Borrower Response?}
    LOG_CALL --> RESPONSE_CALL{Payment Promise?}
    LOG_HARD --> LEGAL_ACTION[Initiate Legal<br/>Recovery Process]
    
    RESPONSE_SOFT -->|Payment| PAYMENT_RECEIVED[Payment Received]
    RESPONSE_SOFT -->|No Response| ESCALATE[Escalate Collections]
    
    RESPONSE_CALL -->|Promise Kept| PAYMENT_RECEIVED
    RESPONSE_CALL -->|Promise Broken| ESCALATE
    
    LEGAL_ACTION --> SECURITY_ENFORCE[Enforce Security<br/>Interests]
    SECURITY_ENFORCE --> RECOVER[Partial/Full Recovery]
    
    PAYMENT_RECEIVED --> CONTINUE_MONITOR
    ESCALATE --> DPD_BUCKET
    RECOVER --> FINAL_LEDGER[Final Ledger<br/>Adjustments]
    FINAL_LEDGER --> END([End])
    CONTINUE_MONITOR --> END

    %% Data entities involved
    LOG_SOFT -.-> |Creates| CE1[collections_event]
    LOG_CALL -.-> |Creates| CE2[collections_event]
    LOG_HARD -.-> |Creates| CE3[collections_event]
    SECURITY_ENFORCE -.-> |References| SI[security_interest]
    FINAL_LEDGER -.-> |Creates| LE[ledger_entry]
```

## 4. Multi-Currency Operations

```mermaid
flowchart LR
    subgraph "FX Rate Management"
        RATE_FEED[External Rate Feed] --> UPDATE_FX[Update FX Rates<br/>Daily/Real-time]
        UPDATE_FX --> FX_TABLE[(fx_rate table)]
    end
    
    subgraph "Payment Processing"
        PAY_FOREIGN[Foreign Currency<br/>Payment] --> CONVERT[Convert to<br/>Functional Currency]
        CONVERT --> FX_TABLE
        FX_TABLE --> CALC[Calculate Converted<br/>Amount]
        CALC --> RECORD_BOTH[Record Both<br/>Original & Converted]
    end
    
    subgraph "Reporting"
        FX_TABLE --> REPORT[Multi-Currency<br/>Reports]
        RECORD_BOTH --> REPORT
        REPORT --> CONSOLIDATE[Consolidated<br/>Financial Position]
    end

    %% Data entities involved
    UPDATE_FX -.-> |Creates/Updates| FXR[fx_rate]
    RECORD_BOTH -.-> |Creates| P[payment], LE[ledger_entry]
```

## 5. Document Management Flow

```mermaid
flowchart TD
    DOC_UPLOAD[Document Upload] --> STORE[Store in External<br/>Storage System]
    STORE --> CREATE_RECORD[Create Document Record<br/>with Storage URL]
    CREATE_RECORD --> LINK_ENTITY[Link to Entity<br/>Application/Loan/Party]
    
    LINK_ENTITY --> CATEGORIZE[Categorize Document<br/>by Role/Type]
    CATEGORIZE --> VERSIONING{New Version?}
    
    VERSIONING -->|Yes| UPDATE_LINK[Update Document Link<br/>Keep History]
    VERSIONING -->|No| NEW_LINK[Create New Link]
    
    UPDATE_LINK --> COMPLIANCE[Compliance Check<br/>Required Documents]
    NEW_LINK --> COMPLIANCE
    
    COMPLIANCE --> NOTIFY[Notify Relevant<br/>Stakeholders]
    NOTIFY --> END([End])

    %% Data entities involved
    CREATE_RECORD -.-> |Creates| DOC[document]
    LINK_ENTITY -.-> |Creates| DL[document_link]
```

## Key Data Flow Insights

### 📊 **Transaction Flow**
1. **Application** → **Decision** → **Loan** → **Amortisation Plan** → **Payments** → **Ledger**
2. All financial transactions create corresponding ledger entries
3. Payment allocations follow waterfall priority (Penalty → Fee → Principal → Other)

### 🔄 **State Management**
- Applications: draft → submitted → under_review → approved/rejected
- Loans: active → current → overdue → closed/written_off
- Payments: pending → completed → failed → reversed

### 👥 **Multi-Party Interactions**
- **Party Roles** link parties to loans with specific responsibilities
- **Security Interests** connect guarantors/collateral to loans
- **Payment Instruments** facilitate bi-directional money flow

### 📈 **Collections Lifecycle**
- Automatic DPD calculation triggers collection workflows
- Collections events create audit trail with actor attribution
- Recovery actions reference security interests for enforcement