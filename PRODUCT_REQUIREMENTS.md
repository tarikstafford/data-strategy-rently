# Product Requirements Document - Rently Lending Platform

## 1. Executive Summary

### 1.1 Product Overview
The Rently Lending Platform is a comprehensive loan management system designed to support multiple lending products across different business segments. The platform manages the complete loan lifecycle from application to repayment, with specialized features for rental-related financing and multi-currency operations.

### 1.2 Business Objectives
- **Primary Goal**: Automate and streamline lending operations across all Rently business units
- **Secondary Goals**: 
  - Improve risk management and collections efficiency
  - Support multi-currency operations for international expansion
  - Provide comprehensive reporting and analytics capabilities
  - Ensure regulatory compliance across all jurisdictions

## 2. Business Requirements

### 2.1 Core Business Functions

#### BR-001: Multi-Product Lending Support
**Requirement**: The system must support multiple loan product categories with distinct characteristics and business rules.
- **Products Supported**:
  - Rently Care D2C (Direct-to-Consumer) loans
  - Rently Care Collaborative loans
  - B2B SME (Small & Medium Enterprise) loans  
  - RNPL UAE (Buy Now Pay Later) loans
- **Priority**: High
- **Status**: Required for MVP

#### BR-002: Complete Loan Lifecycle Management
**Requirement**: The system must manage loans from application through final payment or write-off.
- **Lifecycle Stages**: Application → Underwriting → Approval → Disbursement → Servicing → Collections → Closure
- **Priority**: High
- **Status**: Required for MVP

#### BR-003: Multi-Currency Operations
**Requirement**: Support for loans and payments in multiple currencies with real-time FX rate management.
- **Currencies**: USD, AED, EUR, GBP (extensible)
- **FX Rate Sources**: External rate providers with daily updates
- **Priority**: High
- **Status**: Required for MVP

#### BR-004: Payment Processing & Allocation
**Requirement**: Automated payment processing with intelligent allocation to loan components.
- **Allocation Priority**: Penalties → Fees → Principal → Other charges
- **Payment Methods**: Bank transfers, credit cards, digital wallets
- **Priority**: High
- **Status**: Required for MVP

### 2.2 Compliance & Security Requirements

#### BR-005: Regulatory Compliance
**Requirement**: The system must support compliance with financial regulations in all operating jurisdictions.
- **Compliance Areas**: KYC/AML, data protection (GDPR/PDPA), lending regulations
- **Audit Trail**: Complete transaction and decision audit logging
- **Priority**: High
- **Status**: Required for MVP

#### BR-006: Data Security & Privacy
**Requirement**: Implement robust security measures for sensitive financial and personal data.
- **Security Measures**: Role-based access control, data encryption, secure API communication
- **Privacy**: Data anonymization capabilities, right-to-erasure workflows
- **Priority**: High
- **Status**: Required for MVP

### 2.3 Integration Requirements

#### BR-007: External System Integration
**Requirement**: Integrate with external systems for enhanced functionality.
- **Payment Providers**: Multiple payment gateway support
- **KYC Services**: Third-party identity verification
- **Document Storage**: Cloud-based document management
- **Priority**: Medium
- **Status**: Phase 2

## 3. Functional Requirements

### 3.1 User Management & Authentication

#### FR-001: Party Management
**Requirement**: Comprehensive party (customer) management system supporting multiple party types.

**User Story**: As a loan officer, I want to manage customer information for borrowers, guarantors, brokers, and landlords so that I can maintain complete customer relationships.

**Acceptance Criteria**:
- Create, update, and view party records with KYC information
- Support multiple party types: borrower, guarantor, broker, landlord
- Link multiple parties to a single loan with defined roles
- Maintain contact information with communication preferences
- Track KYC status and documentation compliance

**Business Rules**:
- All borrowers must complete KYC before loan approval
- Guarantors must provide legal guarantee documentation
- Contact information must be validated before loan disbursement

#### FR-002: Role-Based Access Control
**Requirement**: Secure access control system based on user roles and responsibilities.

**User Story**: As a system administrator, I want to control access to sensitive loan data based on user roles so that data security and privacy are maintained.

**Acceptance Criteria**:
- Define and manage user roles: loan officer, underwriter, collections agent, accountant
- Implement permission-based access to loan data and functions
- Provide audit logging for all access attempts and data modifications
- Support temporary access delegation and approval workflows

### 3.2 Application & Underwriting

#### FR-003: Loan Application Processing
**Requirement**: Digital loan application system with workflow management.

**User Story**: As a borrower, I want to submit a loan application online and track its progress so that I can complete the lending process efficiently.

**Acceptance Criteria**:
- Create loan applications with product selection and terms
- Upload supporting documents with automatic categorization
- Track application status through workflow stages
- Support application amendments and resubmissions
- Automated notifications for status changes

**Business Rules**:
- Applications must include all required documentation before underwriting
- Maximum application validity period: 30 days
- Applications require borrower digital signature or consent

#### FR-004: Underwriting & Decision Management
**Requirement**: Risk assessment and decision management system.

**User Story**: As an underwriter, I want to review loan applications with risk assessment tools so that I can make informed approval decisions.

**Acceptance Criteria**:
- Access complete application data with risk scoring
- Record detailed approval/rejection decisions with reasoning
- Set custom loan terms and conditions for approved applications
- Generate decision notifications and documentation
- Maintain decision audit trail with timestamps

**Business Rules**:
- All decisions must be made by authorized underwriters
- Rejection reasons must be documented for regulatory compliance
- Approved loans must have defined amortization schedules

### 3.3 Loan Management & Servicing

#### FR-005: Loan Creation & Setup
**Requirement**: Automated loan creation from approved applications.

**User Story**: As a loan officer, I want approved applications to automatically create loan records so that I can begin loan servicing immediately.

**Acceptance Criteria**:
- Generate loan records from approved decisions
- Create amortization schedules based on loan terms
- Setup payment instruments and collection preferences
- Establish security interests and guarantees
- Generate loan agreements and documentation

**Business Rules**:
- Loans must have complete amortization schedules before activation
- All security interests must be properly documented
- Loan activation requires borrower acknowledgment

#### FR-006: Payment Processing & Allocation
**Requirement**: Comprehensive payment processing with intelligent allocation.

**User Story**: As a borrower, I want my payments to be automatically allocated to my loan balance so that my account is always up to date.

**Acceptance Criteria**:
- Process payments from multiple sources and methods
- Automatically allocate payments based on predefined priorities
- Handle partial payments and overpayments appropriately
- Support payment reversals and adjustments
- Generate payment confirmations and receipts

**Business Rules**:
- Payment allocation priority: Penalties → RC Fees → Principal → Other charges
- Payments must be allocated within 24 hours of receipt
- All payment transactions must create corresponding ledger entries

#### FR-007: Amortization Management
**Requirement**: Flexible amortization schedule management with modification capabilities.

**User Story**: As a loan officer, I want to modify payment schedules when borrowers face financial difficulties so that I can provide payment relief options.

**Acceptance Criteria**:
- Generate standard amortization schedules at loan creation
- Support payment schedule modifications and restructuring
- Handle payment deferrals and grace periods
- Recalculate loan terms after modifications
- Maintain version history of all schedule changes

**Business Rules**:
- Schedule modifications require management approval
- Modified schedules must maintain loan profitability metrics
- All modifications must be documented with borrower consent

### 3.4 Collections & Recovery

#### FR-008: Collections Management
**Requirement**: Automated collections process with escalation workflows.

**User Story**: As a collections agent, I want to track overdue loans and manage recovery activities so that I can maximize collection rates efficiently.

**Acceptance Criteria**:
- Monitor payment due dates and identify overdue accounts
- Calculate days past due (DPD) and assign collection buckets
- Log collection activities and borrower communications
- Escalate accounts based on predefined rules
- Track recovery rates and agent performance

**Business Rules**:
- Collections activities begin after 1 day past due
- Escalation rules: 1-30 days (soft), 31-60 days (active), 60+ days (legal)
- All collection activities must be logged with date/time stamps

#### FR-009: Default Management
**Requirement**: Comprehensive default handling with legal action support.

**User Story**: As a collections manager, I want to manage defaulted loans through legal processes so that I can maximize recovery while maintaining compliance.

**Acceptance Criteria**:
- Identify loans for default classification based on DPD
- Initiate legal action workflows with case tracking
- Manage security interest enforcement and asset recovery
- Calculate and track recovery costs and proceeds
- Generate default reporting for management and regulators

**Business Rules**:
- Loans default after 90 days past due (or product-specific rules)
- Legal action requires management approval
- All recovery proceeds must be properly allocated

### 3.5 Financial Management

#### FR-010: Ledger & Accounting Integration
**Requirement**: Complete financial transaction recording with double-entry bookkeeping.

**User Story**: As an accountant, I want all loan transactions to automatically create ledger entries so that financial records are always accurate and complete.

**Acceptance Criteria**:
- Automatically generate ledger entries for all financial transactions
- Support multi-currency accounting with FX translation
- Maintain chart of accounts across multiple legal entities
- Generate standard financial reports and statements
- Support period-end closing and reconciliation processes

**Business Rules**:
- All financial transactions must balance in the general ledger
- FX translation rates must be sourced from approved providers
- Ledger entries cannot be deleted, only reversed with adjustments

#### FR-011: Multi-Currency Support
**Requirement**: Full multi-currency operations with FX rate management.

**User Story**: As a loan officer, I want to process loans and payments in different currencies so that I can serve international customers effectively.

**Acceptance Criteria**:
- Support loans denominated in multiple currencies
- Process payments in currencies different from loan currency
- Maintain daily FX rates from external providers
- Calculate FX gains/losses on currency conversions
- Generate multi-currency reporting and analytics

**Business Rules**:
- FX rates must be updated daily from approved sources
- Currency conversions use rates effective at transaction time
- FX gains/losses must be recorded in appropriate GL accounts

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-001: System Response Time
- **Requirement**: 95% of user interactions must complete within 3 seconds
- **Critical Functions**: Payment processing, loan balance inquiries, dashboard loading
- **Measurement**: Average response time under normal load conditions

#### NFR-002: Transaction Processing Capacity
- **Requirement**: System must handle 10,000 payment transactions per day
- **Peak Load**: Support 500 concurrent users during business hours
- **Scalability**: Architecture must support 10x growth without major redesign

### 4.2 Availability & Reliability

#### NFR-003: System Availability
- **Requirement**: 99.5% uptime during business hours (8 AM - 8 PM local time)
- **Maintenance Windows**: Maximum 4 hours per month for scheduled maintenance
- **Recovery Time**: Maximum 15 minutes for system restoration after failures

#### NFR-004: Data Backup & Recovery
- **Requirement**: Daily automated backups with 30-day retention
- **Recovery Point Objective**: Maximum 1 hour of data loss
- **Recovery Time Objective**: System restoration within 4 hours

### 4.3 Security Requirements

#### NFR-005: Data Encryption
- **Requirement**: All sensitive data encrypted at rest and in transit
- **Standards**: AES-256 for data at rest, TLS 1.3 for data in transit
- **Key Management**: Secure key rotation and management procedures

#### NFR-006: Access Control
- **Requirement**: Role-based access control with principle of least privilege
- **Authentication**: Multi-factor authentication for all system access
- **Session Management**: Automatic session timeout after 30 minutes of inactivity

### 4.4 Compliance Requirements

#### NFR-007: Audit Logging
- **Requirement**: Complete audit trail for all system activities
- **Retention**: Minimum 7 years for financial transaction records
- **Integrity**: Tamper-proof logging with cryptographic signatures

#### NFR-008: Data Privacy
- **Requirement**: GDPR/PDPA compliance for personal data processing
- **Features**: Data anonymization, right-to-erasure, consent management
- **Documentation**: Privacy impact assessments for all data processing activities

## 5. User Stories & Acceptance Criteria

### 5.1 Borrower Stories

#### US-001: Loan Application Submission
**As a** borrower  
**I want to** submit a loan application online  
**So that** I can apply for financing quickly and conveniently

**Acceptance Criteria**:
- [ ] I can select from available loan products
- [ ] I can input my personal and financial information
- [ ] I can upload required documents
- [ ] I receive confirmation of application submission
- [ ] I can track my application status

#### US-002: Payment Management
**As a** borrower  
**I want to** make payments and view my loan balance  
**So that** I can manage my loan obligations effectively

**Acceptance Criteria**:
- [ ] I can make payments through multiple methods
- [ ] I can view my current balance and payment history
- [ ] I can see my upcoming payment schedule
- [ ] I receive payment confirmations and receipts
- [ ] I can setup automatic payment options

### 5.2 Staff Stories

#### US-003: Application Processing
**As a** loan officer  
**I want to** process loan applications efficiently  
**So that** I can serve customers quickly and accurately

**Acceptance Criteria**:
- [ ] I can review complete application information
- [ ] I can request additional documentation
- [ ] I can communicate with applicants
- [ ] I can track application progress
- [ ] I can escalate applications to underwriters

#### US-004: Risk Assessment
**As an** underwriter  
**I want to** assess loan applications with comprehensive risk information  
**So that** I can make informed approval decisions

**Acceptance Criteria**:
- [ ] I can access credit history and financial information
- [ ] I can view risk scoring and analysis
- [ ] I can set custom loan terms and conditions
- [ ] I can document decision rationale
- [ ] I can generate approval/rejection notifications

## 6. Business Rules & Validation Logic

### 6.1 Application Rules

#### BR-APP-001: Application Eligibility
- Borrowers must be at least 18 years old
- Borrowers must have valid identification documents
- Applications must include proof of income
- Maximum debt-to-income ratio: 50%

#### BR-APP-002: Documentation Requirements
- Identity documents: Government-issued ID, passport
- Income verification: Bank statements, employment letter, tax returns
- Guarantor requirements: Legal guarantee agreement, ID documents
- Property documents: Lease agreement (for rental loans)

### 6.2 Loan Rules

#### BR-LOAN-001: Loan Limits
- Rently Care D2C: Maximum AED 50,000 per borrower
- Rently Care Collaborative: Maximum AED 100,000 per borrower
- B2B SME: Maximum USD 500,000 per entity
- RNPL UAE: Maximum AED 25,000 per transaction

#### BR-LOAN-002: Interest Rate Rules
- Interest rates based on risk assessment and product type
- Minimum rate: 5% per annum
- Maximum rate: 25% per annum (regulatory compliance)
- Rate adjustments require management approval

### 6.3 Payment Rules

#### BR-PAY-001: Payment Allocation
1. **First Priority**: Penalty amounts and late fees
2. **Second Priority**: RC fees and service charges  
3. **Third Priority**: Principal amount
4. **Fourth Priority**: Other charges and costs

#### BR-PAY-002: Payment Processing
- Payments processed within 24 hours of receipt
- Minimum payment amount: Equivalent to USD 10
- Payment reversals allowed within 48 hours
- Overpayments credited to loan balance or refunded

### 6.4 Collections Rules

#### BR-COL-001: Collections Escalation
- **Days 1-30**: Automated reminders (SMS, email)
- **Days 31-60**: Direct contact by collections agent
- **Days 61-90**: Formal demand notices
- **Days 90+**: Legal action initiation

#### BR-COL-002: Default Classification
- Loans become delinquent after 1 day past due
- Loans classified as default after 90 days past due
- Write-off consideration after 180 days default
- Recovery actions continue post write-off

## 7. Integration Requirements

### 7.1 Payment System Integration

#### INT-PAY-001: Payment Provider APIs
- Support for multiple payment gateways
- Real-time payment status updates
- Webhook handling for payment notifications
- Reconciliation reporting and matching

#### INT-PAY-002: Banking Integration
- Direct bank account verification
- Account balance inquiries
- Direct debit/credit processing
- Statement import and reconciliation

### 7.2 External Service Integration

#### INT-EXT-001: KYC Service Integration
- Identity verification APIs
- Document validation services
- Sanction and PEP screening
- Ongoing monitoring services

#### INT-EXT-002: Credit Bureau Integration
- Credit report retrieval APIs
- Score calculation and monitoring
- Dispute management integration
- Regular credit profile updates

## 8. Reporting Requirements

### 8.1 Operational Reports

#### REP-001: Loan Portfolio Dashboard
- Active loans by product and status
- Payment performance metrics
- Collections pipeline analysis
- Risk concentration reports

#### REP-002: Financial Reports
- Profit & loss by product line
- Balance sheet positions
- Cash flow analysis
- Currency exposure reports

### 8.2 Regulatory Reports

#### REP-003: Compliance Reporting
- Central bank regulatory returns
- Anti-money laundering reports
- Customer due diligence reports
- Audit trail reports

#### REP-004: Risk Management Reports
- Credit risk concentration
- Operational risk incidents
- Liquidity risk monitoring
- Market risk exposure

## 9. Success Criteria

### 9.1 Business Success Metrics
- **Loan Origination**: Process 1,000+ loans per month
- **Collections Efficiency**: Maintain >85% collection rate
- **Processing Time**: Reduce application processing time by 50%
- **Customer Satisfaction**: Achieve >4.0/5.0 customer rating

### 9.2 Technical Success Metrics
- **System Availability**: Achieve 99.5% uptime
- **Performance**: Maintain <3 second response times
- **Data Accuracy**: Achieve >99.9% financial data accuracy
- **Security**: Zero security incidents or data breaches

## 10. Assumptions & Dependencies

### 10.1 Assumptions
- External payment providers will maintain 99.9% uptime
- KYC service providers will provide real-time verification
- Regulatory requirements will remain stable during implementation
- Customer adoption of digital processes will be high

### 10.2 Dependencies
- Integration APIs from payment providers
- Regulatory approval for lending operations
- Legal framework for collections and recovery
- IT infrastructure and cloud services availability

## 11. Risks & Mitigation Strategies

### 11.1 Technical Risks
- **Risk**: System integration failures
- **Mitigation**: Comprehensive testing, fallback procedures, vendor SLAs

- **Risk**: Data security breaches
- **Mitigation**: Multi-layered security, regular audits, incident response plan

### 11.2 Business Risks
- **Risk**: Regulatory changes affecting operations
- **Mitigation**: Regulatory monitoring, compliance team, flexible system design

- **Risk**: Higher than expected default rates
- **Mitigation**: Conservative underwriting, diversified portfolio, strong collections

## 12. Implementation Timeline

### Phase 1: Core Platform (Months 1-6)
- Core loan management functionality
- Basic payment processing
- User management and security
- Essential reporting

### Phase 2: Advanced Features (Months 7-12)
- Collections automation
- Advanced analytics
- External integrations
- Mobile applications

### Phase 3: Optimization (Months 13-18)
- Performance optimization
- Advanced risk management
- Predictive analytics
- International expansion support

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-08  
**Owner**: Product Management  
**Reviewers**: Business Stakeholders, Technical Architecture, Risk Management