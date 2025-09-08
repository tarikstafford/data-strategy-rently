# User Guide - Rently Lending Platform

## Table of Contents

1. [Getting Started](#getting-started)
2. [Dashboard Overview](#dashboard-overview)
3. [User Roles and Permissions](#user-roles-and-permissions)
4. [Application Management](#application-management)
5. [Loan Management](#loan-management)
6. [Payment Processing](#payment-processing)
7. [Collections Management](#collections-management)
8. [Reporting and Analytics](#reporting-and-analytics)
9. [System Administration](#system-administration)
10. [Troubleshooting](#troubleshooting)
11. [FAQ](#frequently-asked-questions)

---

## Getting Started

### System Access

#### Login Process
1. Navigate to the Rently Lending Platform URL
2. Enter your username and password
3. Complete two-factor authentication if required
4. Click "Login" to access the system

#### First-Time Login
1. Check your email for login credentials
2. Use the temporary password provided
3. You will be prompted to change your password
4. Set up two-factor authentication
5. Complete your profile information

#### Password Requirements
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character
- Cannot reuse last 5 passwords

### System Requirements

#### Supported Browsers
- **Chrome**: Version 90 or later (Recommended)
- **Firefox**: Version 88 or later
- **Safari**: Version 14 or later
- **Edge**: Version 90 or later

#### Hardware Requirements
- **RAM**: Minimum 4GB (8GB recommended)
- **Screen Resolution**: 1024x768 minimum (1920x1080 recommended)
- **Internet Speed**: Minimum 10 Mbps for optimal performance

---

## Dashboard Overview

### Main Dashboard Components

#### Header Navigation
- **Logo**: Returns to main dashboard
- **Search Bar**: Quick search for customers, loans, applications
- **Notifications**: Bell icon showing alerts and tasks
- **User Menu**: Profile settings, logout, help

#### Left Sidebar Menu
- **Dashboard**: Main overview screen
- **Applications**: Loan application management
- **Loans**: Active loan portfolio
- **Customers**: Customer information management
- **Payments**: Payment processing and history
- **Collections**: Collections activities and reporting
- **Reports**: Analytics and reporting section
- **Administration**: System settings (admin only)

#### Dashboard Widgets

##### Key Performance Indicators
- **Total Active Loans**: Current portfolio count
- **Outstanding Balance**: Total portfolio value
- **Payment Collection Rate**: Monthly collection percentage
- **Default Rate**: Current default percentage
- **New Applications**: Today/This week counts

##### Quick Actions
- **New Application**: Start new loan application
- **Process Payment**: Record customer payment
- **Collections Task**: Assign collections activity
- **Generate Report**: Create custom reports

##### Recent Activities
- Latest applications submitted
- Recent payments received
- Collections activities completed
- System alerts and notifications

---

## User Roles and Permissions

### Role Definitions

#### Loan Officer
**Permissions**: 
- Create and manage loan applications
- View customer information
- Process documentation
- Initiate underwriting process
- Handle customer inquiries

**Dashboard Access**:
- Applications (full access)
- Customers (read/write)
- Loans (read only for assigned loans)
- Payments (view only)

#### Underwriter
**Permissions**:
- Review loan applications
- Make approval/rejection decisions
- Set loan terms and conditions
- Access credit reports and risk data
- Generate decision documentation

**Dashboard Access**:
- Applications (review and decision)
- Customers (read only)
- Risk Analytics (full access)
- Reports (credit and risk reports)

#### Collections Agent
**Permissions**:
- View overdue loans
- Record collections activities
- Contact customers
- Update payment promises
- Generate collections reports

**Dashboard Access**:
- Collections (full access)
- Customers (contact information)
- Payments (limited access)
- Loans (overdue loans only)

#### Customer Service Representative
**Permissions**:
- View customer information
- Handle inquiries and complaints
- Process basic account changes
- Generate customer statements
- Escalate complex issues

**Dashboard Access**:
- Customers (full access)
- Loans (view only)
- Payments (view only)
- Basic reports

#### Accountant
**Permissions**:
- View financial transactions
- Generate financial reports
- Process disbursements
- Reconcile accounts
- Access ledger entries

**Dashboard Access**:
- Financial reports (full access)
- Disbursements (full access)
- Payments (full access)
- Ledger entries (view only)

#### System Administrator
**Permissions**:
- Full system access
- User management
- System configuration
- Data backup and recovery
- Security settings

**Dashboard Access**:
- All modules (full access)
- Administration panel
- System logs and monitoring
- User management

---

## Application Management

### Creating New Applications

#### Step 1: Application Initiation
1. Click **"New Application"** from dashboard or Applications menu
2. Select **Product Type**:
   - Rently Care D2C
   - Rently Care Collaborative
   - B2B SME
   - RNPL UAE
3. Enter **Basic Information**:
   - Customer name
   - Contact details
   - Identification number

#### Step 2: Customer Information
1. **Personal Details**:
   - Full name as per ID
   - Date of birth
   - Nationality
   - Marital status
   - Contact information

2. **Employment Information**:
   - Employer name
   - Job title
   - Monthly income
   - Employment duration
   - Bank details

3. **Financial Information**:
   - Monthly expenses
   - Existing debts
   - Assets owned
   - Bank statements

#### Step 3: Loan Details
1. **Loan Parameters**:
   - Requested amount
   - Preferred term
   - Purpose of loan
   - Payment frequency

2. **Security Information** (if applicable):
   - Guarantor details
   - Collateral information
   - Insurance requirements

#### Step 4: Document Upload
1. **Required Documents**:
   - Identity documents
   - Income verification
   - Bank statements
   - Additional product-specific docs

2. **Upload Process**:
   - Drag and drop or browse files
   - Supported formats: PDF, JPG, PNG
   - Maximum file size: 10MB per document
   - Documents auto-categorized by type

### Application Review Process

#### Application Status Tracking
- **Draft**: Application being completed
- **Submitted**: Ready for review
- **Under Review**: Being processed by underwriter
- **Approved**: Loan approved, pending disbursement
- **Rejected**: Application declined
- **Incomplete**: Missing information/documents

#### Review Checklist
1. **KYC Verification**:
   - Identity document verification
   - Address confirmation
   - Employment verification
   - Income validation

2. **Credit Assessment**:
   - Credit bureau check
   - Internal credit scoring
   - Risk category assignment
   - Affordability analysis

3. **Document Verification**:
   - Document authenticity check
   - Completeness verification
   - Compliance requirements
   - Additional documentation needs

#### Decision Recording
1. Navigate to application in "Under Review" status
2. Review all available information
3. Select decision: **Approve** or **Reject**
4. If approved:
   - Set final loan terms
   - Confirm interest rate
   - Set disbursement conditions
5. If rejected:
   - Select rejection reason
   - Add detailed comments
   - Generate rejection letter
6. Save decision and notify relevant parties

---

## Loan Management

### Loan Setup and Activation

#### Post-Approval Setup
1. **Loan Creation**:
   - System auto-generates loan from approved application
   - Assigns unique loan ID
   - Creates customer relationship
   - Sets initial status to "Pending Activation"

2. **Amortization Schedule Generation**:
   - Based on approved terms
   - Payment amount calculation
   - Due date assignment
   - Interest and fee allocation

3. **Document Generation**:
   - Loan agreement
   - Payment schedule
   - Terms and conditions
   - Disclosure statements

4. **Customer Confirmation**:
   - Send loan documents for signature
   - Receive signed agreements
   - Verify payment account setup
   - Activate loan

#### Loan Information Management

##### Basic Loan Details
- **Loan ID**: System-generated unique identifier
- **Product Type**: Loan category
- **Principal Amount**: Original loan amount
- **Interest Rate**: Annual percentage rate
- **Term**: Loan duration in months
- **Payment Amount**: Regular payment amount
- **Next Due Date**: Upcoming payment date

##### Payment Schedule Management
1. **View Schedule**:
   - Navigate to Loans → Select Loan → Payment Schedule
   - View all scheduled payments
   - See payment breakdown (principal, interest, fees)
   - Track payment status

2. **Schedule Modifications**:
   - Payment deferrals
   - Term extensions
   - Rate adjustments
   - Restructuring options

### Loan Servicing Activities

#### Regular Monitoring
1. **Payment Tracking**:
   - Monitor due dates
   - Track payment receipts
   - Identify overdue accounts
   - Calculate days past due

2. **Account Maintenance**:
   - Update customer information
   - Modify payment methods
   - Process account changes
   - Handle customer inquiries

#### Loan Modifications
1. **Payment Deferral**:
   - Navigate to loan account
   - Select "Modify Payment Schedule"
   - Choose deferral period
   - Update payment schedule
   - Generate modification agreement

2. **Term Extension**:
   - Assess customer request
   - Calculate financial impact
   - Get management approval
   - Process modification
   - Update all related records

---

## Payment Processing

### Recording Customer Payments

#### Manual Payment Entry
1. **Navigate to Payments → New Payment**
2. **Enter Payment Details**:
   - Customer/Loan ID
   - Payment amount
   - Payment date
   - Payment method
   - Reference number

3. **Payment Allocation**:
   - System auto-allocates based on hierarchy
   - Manual allocation if needed
   - Review allocation before confirming
   - Process payment

#### Payment Allocation Hierarchy
The system automatically allocates payments in the following order:
1. **Outstanding Penalties** (late fees, legal costs)
2. **RC Fees** (recurring charges)
3. **Accrued Interest**
4. **Principal Balance**
5. **Other Charges**

#### Payment Methods Supported

##### Electronic Payments
- **Bank Transfer**: Direct bank-to-bank transfer
- **Card Payments**: Credit/debit card processing
- **Digital Wallets**: Apple Pay, Google Pay, etc.
- **Online Banking**: Direct bank account debits

##### Traditional Payments
- **Cash Payments**: Through authorized agents
- **Cheque Payments**: Bank cheque processing
- **Money Orders**: Postal/bank money orders

### Payment Verification and Reconciliation

#### Daily Reconciliation Process
1. **Extract Payment Data**:
   - Download bank statements
   - Extract payment gateway reports
   - Compile cash collection reports

2. **Match Payments**:
   - Auto-match by reference numbers
   - Manual matching for exceptions
   - Investigate unmatched items
   - Update payment status

3. **Exception Handling**:
   - Duplicate payments
   - Unidentified payments
   - Payment reversals
   - Amount discrepancies

#### Payment Disputes
1. **Dispute Identification**:
   - Customer complaint
   - System reconciliation mismatch
   - Bank dispute notification

2. **Investigation Process**:
   - Review payment records
   - Check bank statements
   - Contact customer
   - Document findings

3. **Resolution**:
   - Payment adjustment
   - Account correction
   - Customer communication
   - System updates

---

## Collections Management

### Overdue Account Management

#### Automated Collections Workflow
The system automatically triggers collections activities based on days past due (DPD):

**Day 1-7: Soft Collections**
- Automated SMS reminders
- Email payment notices
- System-generated letters

**Day 8-30: Active Collections**
- Customer service calls
- Personalized communications
- Payment plan negotiations

**Day 31-60: Intensive Collections**
- Collections agent assignment
- Field visits (if applicable)
- Formal demand notices

**Day 60+: Legal Collections**
- Legal action consideration
- Asset recovery initiation
- Court case preparation

#### Collections Activity Recording

1. **Contact Attempts**:
   - Date and time of contact
   - Contact method used
   - Person contacted
   - Response received
   - Follow-up action planned

2. **Customer Communications**:
   - Payment promises
   - Dispute information
   - Hardship circumstances
   - Contact preferences

3. **Recovery Actions**:
   - Legal notices sent
   - Asset seizure activities
   - Settlement negotiations
   - Recovery amounts

### Collections Dashboard

#### Overdue Portfolio View
- **Total Overdue Amount**: Sum of all past due balances
- **Accounts by DPD Bucket**: 1-30, 31-60, 60+ days
- **Collection Rate**: Monthly recovery percentage
- **Agent Performance**: Individual agent metrics

#### Task Management
1. **Daily Task List**:
   - Assigned accounts to contact
   - Follow-up actions required
   - Legal deadlines
   - Court appearances

2. **Priority Assignments**:
   - High-value accounts
   - Easy recovery opportunities
   - Legal action required
   - Customer relationship management

### Collections Reporting

#### Performance Metrics
- **Collection Rate**: Percentage of overdue amounts recovered
- **Contact Rate**: Percentage of attempted contacts successful
- **Promise Keeping Rate**: Percentage of promises kept by customers
- **Recovery Time**: Average time from overdue to recovery

#### Portfolio Analysis
- **Vintage Analysis**: Performance by origination period
- **Product Performance**: Collection rates by product type
- **Risk Segmentation**: Recovery rates by risk category
- **Geographic Analysis**: Performance by location

---

## Reporting and Analytics

### Standard Reports

#### Portfolio Reports
1. **Loan Portfolio Summary**:
   - Total active loans by product
   - Outstanding balances
   - Average loan size
   - Portfolio growth trends

2. **Payment Performance**:
   - Collection rates by period
   - Payment timing analysis
   - Default rate trends
   - Recovery performance

3. **Risk Analytics**:
   - Portfolio risk distribution
   - Concentration analysis
   - Early warning indicators
   - Stress test results

#### Financial Reports
1. **Profit & Loss**:
   - Interest income
   - Fee income
   - Operating expenses
   - Net income by product

2. **Balance Sheet**:
   - Loan assets
   - Provisions for losses
   - Equity positions
   - Capital ratios

3. **Cash Flow**:
   - Cash receipts
   - Disbursements
   - Net cash flow
   - Liquidity position

### Custom Report Generation

#### Report Builder
1. **Data Selection**:
   - Choose data sources
   - Select date ranges
   - Apply filters
   - Define groupings

2. **Report Format**:
   - Table format
   - Chart types
   - Summary statistics
   - Export options

3. **Scheduling**:
   - One-time generation
   - Recurring schedules
   - Email distribution
   - Automated delivery

### Dashboard Analytics

#### Key Performance Indicators (KPIs)
- **Loan Origination**: New loans by period
- **Portfolio Quality**: Default and delinquency rates
- **Profitability**: Return on assets, net interest margin
- **Efficiency**: Cost-to-income ratio, processing times

#### Visual Analytics
- **Trend Charts**: Performance over time
- **Comparison Charts**: Product and period comparisons
- **Geographic Maps**: Performance by location
- **Heat Maps**: Risk and performance visualization

---

## System Administration

### User Management

#### Creating New Users
1. **Navigate to Administration → User Management**
2. **Add New User**:
   - Enter user details
   - Assign role and permissions
   - Set initial password
   - Configure access restrictions

3. **Account Setup**:
   - Send credentials to user
   - Verify email address
   - Set up two-factor authentication
   - Assign to appropriate departments

#### Managing User Permissions
1. **Role-Based Permissions**:
   - Assign standard roles
   - Customize permissions
   - Set data access levels
   - Configure approval limits

2. **Access Controls**:
   - IP address restrictions
   - Time-based access
   - Geographic limitations
   - Device restrictions

### System Configuration

#### Product Configuration
1. **Loan Products**:
   - Interest rate ranges
   - Fee structures
   - Eligibility criteria
   - Documentation requirements

2. **Workflow Settings**:
   - Approval workflows
   - Escalation rules
   - Notification settings
   - Automation triggers

#### Integration Settings
1. **Payment Providers**:
   - Gateway configurations
   - API credentials
   - Webhook settings
   - Reconciliation rules

2. **External Services**:
   - KYC service providers
   - Credit bureaus
   - Document storage
   - Communication services

### Data Management

#### Backup and Recovery
1. **Backup Schedule**:
   - Daily automated backups
   - Weekly full backups
   - Monthly archive creation
   - Quarterly disaster recovery tests

2. **Data Retention**:
   - Transaction data: 7 years
   - Customer data: As per regulations
   - System logs: 2 years
   - Audit trails: 10 years

#### Data Security
1. **Encryption**:
   - Data at rest encryption
   - Data in transit encryption
   - Key management
   - Certificate management

2. **Access Monitoring**:
   - User activity logging
   - Data access auditing
   - Failed login monitoring
   - Security incident tracking

---

## Troubleshooting

### Common Issues and Solutions

#### Login Issues

**Problem**: Cannot log into the system
**Solutions**:
1. Verify username and password
2. Check caps lock and keyboard settings
3. Clear browser cache and cookies
4. Try different browser
5. Contact system administrator if problem persists

**Problem**: Two-factor authentication not working
**Solutions**:
1. Verify time on device is correct
2. Ensure authenticator app is synced
3. Try backup authentication codes
4. Contact administrator for reset

#### Application Issues

**Problem**: Application not saving
**Solutions**:
1. Check internet connection
2. Verify all required fields are completed
3. Ensure file uploads are complete
4. Try refreshing the page
5. Clear browser cache

**Problem**: Documents not uploading
**Solutions**:
1. Check file size (max 10MB)
2. Verify file format (PDF, JPG, PNG)
3. Ensure stable internet connection
4. Try different browser
5. Compress large files

#### Payment Issues

**Problem**: Payment not reflecting in system
**Solutions**:
1. Allow 24 hours for processing
2. Check payment reference number
3. Verify bank account details
4. Contact payment provider
5. Submit payment inquiry form

**Problem**: Incorrect payment allocation
**Solutions**:
1. Review payment allocation rules
2. Check for manual allocation needs
3. Contact loan servicing team
4. Submit reallocation request
5. Provide supporting documentation

#### Report Issues

**Problem**: Reports not generating
**Solutions**:
1. Check date range selections
2. Verify data permissions
3. Reduce report scope if too large
4. Try different export format
5. Contact system support

**Problem**: Incorrect data in reports
**Solutions**:
1. Verify report parameters
2. Check data filters applied
3. Confirm time period selection
4. Review data source accuracy
5. Submit data quality inquiry

### Error Messages and Codes

#### System Errors
- **Error 001**: Database connection timeout
- **Error 002**: Insufficient user permissions
- **Error 003**: Invalid data format
- **Error 004**: File upload failed
- **Error 005**: Payment processing error

#### Business Logic Errors
- **Error 101**: Loan eligibility criteria not met
- **Error 102**: Documentation incomplete
- **Error 103**: Payment allocation failed
- **Error 104**: Duplicate customer record
- **Error 105**: Invalid loan modification request

### Getting Help

#### Internal Support
1. **System Administrator**: Technical issues and access problems
2. **Training Team**: User training and process questions
3. **Business Analyst**: Functional requirements and process improvements
4. **IT Help Desk**: Hardware and software support

#### External Support
1. **Vendor Support**: Third-party integration issues
2. **Payment Providers**: Payment processing problems
3. **Compliance Team**: Regulatory and compliance questions
4. **Legal Team**: Legal action and documentation issues

---

## Frequently Asked Questions

### General Questions

**Q: How often is the system updated?**
A: System updates occur monthly with bug fixes and quarterly with new features. Users are notified in advance of scheduled maintenance.

**Q: Can I access the system from mobile devices?**
A: Yes, the system is responsive and works on tablets and smartphones, though full functionality is best experienced on desktop computers.

**Q: How long are user sessions active?**
A: User sessions automatically timeout after 30 minutes of inactivity for security purposes.

### Application Processing

**Q: How long does application processing take?**
A: Processing times vary by product:
- Rently Care D2C: 1-2 business days
- Rently Care Collaborative: 3-5 business days
- B2B SME: 5-10 business days
- RNPL UAE: Real-time to 24 hours

**Q: Can applications be modified after submission?**
A: Yes, applications can be modified until they enter underwriting. Contact your loan officer for assistance.

**Q: What happens if documentation is incomplete?**
A: The system will flag incomplete applications and send notifications to the customer and loan officer.

### Loan Management

**Q: How are payment due dates calculated?**
A: Payment due dates are calculated based on the loan disbursement date and the selected payment frequency.

**Q: Can loan terms be modified after activation?**
A: Yes, loan modifications are possible subject to management approval and regulatory requirements.

**Q: How are late fees calculated?**
A: Late fees are applied according to the product-specific fee structure, typically after a grace period.

### Payment Processing

**Q: How long do payments take to process?**
A: Electronic payments are typically processed within 24 hours. Cash payments may take 2-3 business days.

**Q: Can payments be reversed?**
A: Payment reversals are possible within 48 hours of processing, subject to management approval.

**Q: What happens with overpayments?**
A: Overpayments are credited to the loan balance or can be refunded upon customer request.

### Collections

**Q: When do collections activities begin?**
A: Collections activities begin automatically one day after a payment becomes overdue.

**Q: Can payment arrangements be made?**
A: Yes, payment arrangements can be negotiated with collections agents subject to company policy.

**Q: What legal actions can be taken?**
A: Legal actions may include demand notices, court cases, and asset recovery, depending on jurisdiction and loan terms.

### Reporting

**Q: Can reports be scheduled for automatic delivery?**
A: Yes, most reports can be scheduled for daily, weekly, or monthly delivery via email.

**Q: What export formats are available?**
A: Reports can be exported in PDF, Excel, CSV, and Word formats.

**Q: How current is the data in reports?**
A: Report data is updated in real-time for most metrics, with some analytics updated daily.

### Security and Privacy

**Q: How is customer data protected?**
A: Customer data is protected through encryption, access controls, audit logging, and compliance with data protection regulations.

**Q: Can users see data outside their department?**
A: Access to data is controlled by role-based permissions, ensuring users only see data relevant to their job functions.

**Q: How long is customer data retained?**
A: Customer data is retained according to regulatory requirements, typically 7 years for financial records.

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-08  
**Owner**: Operations Team  
**Reviewers**: Training, IT Support, Business Operations