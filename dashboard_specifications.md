# Rently Lending Platform - Dashboard Specifications
## Analytics & Business Intelligence Dashboard Requirements

**Version:** 1.0  
**Date:** December 2024  
**Document Owner:** Data & Analytics Team  

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Dashboard Architecture](#dashboard-architecture)
3. [Operational Dashboards](#operational-dashboards)
4. [Advanced Analytics Dashboards](#advanced-analytics-dashboards)
5. [Executive & Strategic Dashboards](#executive--strategic-dashboards)
6. [Technical Specifications](#technical-specifications)
7. [Performance Requirements](#performance-requirements)
8. [Security & Access Control](#security--access-control)

---

## Executive Summary

This document defines the comprehensive dashboard specifications for the Rently Lending Platform analytics and business intelligence system. The dashboards are designed to support data-driven decision making across all levels of the organization, from operational staff to executive leadership.

### Key Dashboard Categories
- **Operational Dashboards**: Real-time monitoring and day-to-day operations
- **Advanced Analytics**: Risk management, predictive insights, and performance analysis
- **Executive Dashboards**: Strategic overview and key performance indicators
- **Compliance Dashboards**: Regulatory reporting and risk monitoring

---

## Dashboard Architecture

### Data Architecture Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Source Data   │────│   Analytics      │────│   Dashboard     │
│   (PostgreSQL)  │    │   Views Layer    │    │   Layer         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
    ┌────▼────┐              ┌───▼────┐              ┌───▼────┐
    │  Loans  │              │ Real   │              │  Web   │
    │Payments │              │ Time   │              │ Mobile │
    │Parties  │              │ Views  │              │  API   │
    │Collections              │ Cached │              │        │
    │ etc.    │              │ Views  │              │        │
    └─────────┘              └────────┘              └────────┘
```

### Dashboard Refresh Strategy
- **Tier 1 (Real-time)**: Sub-minute refresh for operational dashboards
- **Tier 2 (Near real-time)**: 5-15 minute refresh for management dashboards  
- **Tier 3 (Batch)**: Daily/hourly refresh for analytical and compliance reports

---

## Operational Dashboards

### 1. Loan Portfolio Overview Dashboard

**Purpose**: Real-time monitoring of loan portfolio health and composition  
**Users**: Portfolio Managers, Risk Officers, Operations Team  
**Refresh**: Real-time (Tier 1)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Portfolio Size** | Total Active Loans | Count of loans with status = 'active' | - | v_loan_portfolio_overview |
| | Active Portfolio Value | Sum of principal_amount for active loans | - | v_loan_portfolio_overview |
| | Average Loan Size | Active portfolio value / active loan count | Varies by product | v_loan_portfolio_overview |
| **Portfolio Mix** | Product Category Distribution | % breakdown by product category | Balanced growth | v_loan_portfolio_overview |
| | Business Unit Split | Residential vs Commercial % | 70/30 target | v_loan_portfolio_overview |
| | Currency Exposure | Portfolio value by currency | Monitor concentration | v_loan_portfolio_overview |
| **Quality Metrics** | Default Rate (Count) | % of loans in default status | <5% target | v_default_rate_analysis |
| | Default Rate (Amount) | % of portfolio value in default | <3% target | v_default_rate_analysis |
| | Write-off Rate | % of loans written off | <2% target | v_default_rate_analysis |

#### Visualizations
- **Portfolio Composition Pie Chart**: Product categories and business units
- **Trend Line**: Portfolio growth over 12 months
- **Heat Map**: Default rates by product category and currency
- **Bar Chart**: Top 10 borrowers by exposure
- **Gauge Charts**: Key ratios vs targets (default rate, write-off rate)

#### Drill-Down Capabilities
- Portfolio → Product Category → Individual Loans
- Geographic distribution → Country → Legal Entity
- Default analysis → Risk level → Collections stage

### 2. Cash Flow Management Dashboard

**Purpose**: Monitor and forecast cash flows, payment collections, and liquidity  
**Users**: Treasury, Finance, Cash Management  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Collections** | Expected Collections (30d) | Scheduled payments next 30 days | - | v_weekly_cash_flow_projections |
| | Actual Collections MTD | Payments received month-to-date | 90% of expected | v_monthly_cash_flow_analysis |
| | Collection Efficiency | Actual vs expected collections % | >85% | v_weekly_cash_flow_projections |
| **Projections** | Weekly Cash Flow | 12-week forward projection | Positive trend | v_weekly_cash_flow_projections |
| | Monthly Net Flow | Inflows minus disbursements | Positive | v_monthly_cash_flow_analysis |
| **Timing Analysis** | On-time Payment Rate | % payments received on/before due date | >80% | v_payment_timing_analysis |
| | Average Days Late | Mean lateness for late payments | <15 days | v_payment_timing_analysis |
| **Currency Risk** | FX Exposure | Non-functional currency exposure % | <30% per currency | v_currency_risk_analysis |

#### Visualizations
- **Waterfall Chart**: Monthly cash flow breakdown (inflows, outflows, net)
- **Time Series**: 12-week rolling cash flow projections
- **Stacked Bar**: Payment timing distribution (early, on-time, late categories)
- **Currency Risk Matrix**: Exposure vs volatility by currency pair
- **Collection Efficiency Trend**: Historical vs projected performance

### 3. Collections Performance Dashboard

**Purpose**: Monitor collections activities, recovery rates, and operational efficiency  
**Users**: Collections Team, Recovery Specialists, Operations Managers  
**Refresh**: Real-time (Tier 1)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Performance** | Recovery Rate | % of defaulted amount recovered | >60% | v_collections_performance |
| | Average Resolution Days | Days from first overdue to resolution | <90 days | v_collections_resolution_analysis |
| | Call Success Rate | Successful calls / total call attempts | >40% | v_collections_performance |
| **Workflow** | Reminders Sent | Count of reminders by stage | - | v_collections_performance |
| | Legal Actions | Loans escalated to legal action | <10% of defaults | v_collections_performance |
| | Cases by Stage | Distribution across collections stages | Monitor flow | v_collections_performance |
| **Efficiency** | Cost per Recovery | Collections cost / amount recovered | Minimize | External data |
| | Agent Productivity | Cases resolved per agent per month | Benchmark | External data |

#### Visualizations
- **Collections Funnel**: Flow from first overdue to resolution
- **Recovery Rate by DPD Bucket**: 30/60/90+ day buckets
- **Agent Performance Scorecard**: Individual and team metrics
- **Resolution Timeline**: Average days by collections stage
- **Legal Action Tracker**: Cases in legal proceedings

### 4. Payment Health Metrics Dashboard

**Purpose**: Monitor current payment status and early warning indicators  
**Users**: Risk Management, Portfolio Managers, Collections  
**Refresh**: Real-time (Tier 1)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Current Status** | Current DPD Distribution | Loans by days past due buckets | Monitor shifts | v_dpd_analysis |
| | Risk Category Mix | Normal/Watch/Substandard/Doubtful/Loss | <5% in Substandard+ | v_dpd_analysis |
| **Early Warning** | 1-7 DPD Count | Loans recently becoming overdue | Trending down | v_payment_health_summary |
| | 8-30 DPD Progression | Movement from early to extended overdue | <50% progression | v_payment_health_summary |
| **Portfolio Health** | Performing Rate | % of portfolio current | >90% | v_payment_health_summary |
| | At-Risk Amount | Value in 31+ DPD categories | <10% of portfolio | v_payment_health_summary |

#### Visualizations
- **DPD Aging Bar Chart**: Portfolio distribution across DPD buckets
- **Risk Heat Map**: Product category vs risk level
- **Trend Analysis**: DPD migration patterns over time
- **Early Warning Alerts**: New entries to watch list
- **Portfolio Health Score**: Composite health indicator

---

## Advanced Analytics Dashboards

### 5. Risk Analytics Dashboard

**Purpose**: Comprehensive risk assessment and concentration analysis  
**Users**: Chief Risk Officer, Risk Analysts, Senior Management  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Concentration** | Product Concentration | Largest product category % | <50% | v_portfolio_concentration_analysis |
| | Borrower Concentration | Top 10 borrowers % of portfolio | <20% | v_portfolio_concentration_analysis |
| | Geographic Concentration | Largest country % of portfolio | <60% | v_portfolio_concentration_analysis |
| **Currency Risk** | FX Risk Level | High/Medium/Low risk classification | Monitor High | v_currency_risk_analysis |
| | Hedging Coverage | % of FX exposure hedged | >80% for high risk | v_currency_risk_analysis |
| **Counterparty** | High Risk Borrowers | Count in High/Very High risk | Minimize | v_counterparty_risk_assessment |
| | Average Risk Score | Portfolio-weighted risk score | Improve trend | v_counterparty_risk_assessment |

#### Visualizations
- **Risk Heatmap**: Multi-dimensional risk view (geography, product, currency)
- **Concentration Radar Chart**: Multiple concentration metrics
- **Counterparty Risk Matrix**: Risk vs exposure scatter plot
- **Currency Risk Dashboard**: FX exposure and hedging status
- **Risk Trend Analysis**: Historical risk metrics evolution

### 6. Performance Metrics Dashboard

**Purpose**: Business performance, origination trends, and portfolio quality analysis  
**Users**: Business Development, Product Managers, Senior Management  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Origination** | Application Volume | Monthly application count | Growth target | v_origination_performance |
| | Approval Rate | Approved applications / total applications | 60-80% range | v_origination_performance |
| | Conversion Rate | Loans disbursed / approvals | >90% | v_origination_performance |
| | Time to Disburse | Days from approval to disbursement | <7 days | External data |
| **Quality** | Vintage Performance | Default rates by origination month | Improving trend | v_portfolio_quality_metrics |
| | Early Default Rate | Defaults within first 6 months | <2% | v_portfolio_quality_metrics |
| **Business Growth** | Monthly Origination | New loan volume by month | Growth targets | v_origination_performance |
| | Market Share | % of target market (by product) | Competitive intel | External data |

#### Visualizations
- **Origination Funnel**: Application → Approval → Disbursement
- **Vintage Analysis**: Cohort performance by origination period
- **Product Performance Matrix**: Volume vs quality by product
- **Growth Trend Dashboard**: Key business metrics trending
- **Competitive Analysis**: Market position indicators

### 7. Predictive Analytics Foundation Dashboard

**Purpose**: Machine learning model performance and predictive insights  
**Users**: Data Scientists, Risk Analysts, Senior Management  
**Refresh**: Daily (Tier 3)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Model Performance** | Default Prediction Accuracy | ML model precision/recall | >80% precision | v_ml_features_default_prediction |
| | Model Drift Score | Performance degradation over time | <10% drift | Model monitoring |
| **Feature Importance** | Top Risk Factors | Most predictive features | Monitor stability | v_ml_features_default_prediction |
| **Predictions** | High Risk Loan Count | Loans predicted to default | Early intervention | Model outputs |
| | Expected Loss | Predicted losses next 12 months | Budget planning | Model outputs |

#### Visualizations
- **Model Performance Charts**: ROC curves, precision-recall, confusion matrix
- **Feature Importance Ranking**: Top predictive variables
- **Prediction Distribution**: Risk score distribution of active loans
- **Model Drift Monitoring**: Performance metrics over time
- **Business Impact**: Model-driven decisions and outcomes

---

## Executive & Strategic Dashboards

### 8. Executive Summary Dashboard

**Purpose**: High-level KPIs and strategic metrics for executive decision-making  
**Users**: C-Suite, Board of Directors, Senior Leadership  
**Refresh**: Real-time (Tier 1)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Business Size** | Total Portfolio Value | Sum of all active loan principal | Growth targets | v_executive_summary_dashboard |
| | Active Loan Count | Total number of active loans | - | v_executive_summary_dashboard |
| | Monthly Origination | New loans originated this month | Budget targets | v_executive_summary_dashboard |
| **Financial Health** | Default Rate | % of portfolio in default | <5% | v_executive_summary_dashboard |
| | Collection Efficiency | Collections vs expected | >85% | v_executive_summary_dashboard |
| | Loss Rate | Cumulative losses / total originated | <2% annual | v_executive_summary_dashboard |
| **Growth** | Month-over-Month Growth | Portfolio growth rate | Target % | v_executive_summary_dashboard |
| | New Market Penetration | Loans in new geographies/products | Strategic goals | External data |

#### Visualizations
- **Executive KPI Cards**: Large, prominent key metrics
- **Portfolio Growth Chart**: Historical and projected growth
- **P&L Impact Summary**: Revenue, costs, and net impact
- **Risk Summary Gauge**: Overall portfolio health score
- **Regional Performance**: Geographic breakdown of key metrics

### 9. Business Intelligence Dashboard

**Purpose**: Strategic insights and business intelligence for planning and strategy  
**Users**: Strategy Team, Product Managers, Business Development  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Market Analysis** | Product Performance | Revenue/profit by product line | ROI targets | Multiple sources |
| | Customer Segments** | Performance by customer type | Segment strategy | v_counterparty_risk_assessment |
| **Operational Excellence** | Process Efficiency | Straight-through processing % | >80% | External data |
| | Customer Satisfaction | NPS or satisfaction score | >8/10 | External surveys |
| **Strategic KPIs** | Market Share | % of addressable market | Growth targets | Market research |
| | Customer Lifetime Value | Average CLV by segment | Maximize | Calculated metrics |

#### Visualizations
- **Strategic Dashboard**: Key business metrics and trends
- **Product Performance Matrix**: Volume vs profitability
- **Customer Journey Analytics**: From application to payoff
- **Competitive Benchmarking**: Market position indicators
- **Scenario Analysis**: "What-if" planning tools

---

## Compliance & Regulatory Dashboards

### 10. Regulatory Compliance Dashboard

**Purpose**: Monitor regulatory ratios and compliance requirements  
**Users**: Compliance Team, Risk Management, Auditors  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Regulatory Ratios** | NPL Ratio | Non-performing loans / total portfolio | <5% (regulatory) | v_regulatory_compliance_report |
| | Provisioning Ratio | Required provisions / outstanding | Regulatory requirement | v_regulatory_compliance_report |
| | Capital Adequacy | Capital / risk-weighted assets | >12% (example) | External data |
| **Classifications** | Loan Classifications | Distribution across risk categories | Monitor shifts | v_regulatory_compliance_report |
| | Legal Action Rate | % of portfolio in legal proceedings | Minimize | v_regulatory_compliance_report |
| **Reporting** | Regulatory Submissions | Timely submission status | 100% on-time | External tracking |

#### Visualizations
- **Regulatory Ratio Dashboard**: Key ratios vs limits
- **Loan Classification Pie Chart**: Risk category distribution
- **Compliance Status Traffic Light**: Green/Amber/Red indicators  
- **Regulatory Trend Analysis**: Historical ratio performance
- **Exception Reports**: Items requiring attention

### 11. Multi-Currency Consolidated Dashboard

**Purpose**: Consolidated view across currencies with FX impact analysis  
**Users**: Finance, Treasury, Senior Management  
**Refresh**: Daily (Tier 2)

#### Key Metrics & KPIs

| Metric Category | KPI Name | Definition | Target/Benchmark | Data Source |
|---|---|---|---|---|
| **Currency Exposure** | Total Exposure by Currency | Portfolio value in each currency | Monitor concentration | v_consolidated_multi_currency_report |
| | FX Risk Assessment | Risk level by currency pair | Manage high risk | v_consolidated_multi_currency_report |
| **Consolidated View** | Functional Currency Total | All exposures in functional currency | - | v_consolidated_multi_currency_report |
| | FX Impact on P&L | Currency gains/losses | Minimize volatility | v_consolidated_multi_currency_report |
| **Hedging** | Hedge Effectiveness | % of FX risk hedged | >80% for material | External data |

#### Visualizations
- **Currency Exposure Breakdown**: Portfolio by currency
- **FX Risk Heat Map**: Risk level by currency pair
- **Consolidated P&L Impact**: FX gains/losses by currency
- **Hedging Coverage**: Exposure vs hedged amounts
- **FX Rate Trend**: Historical rates and volatility

---

## Technical Specifications

### Dashboard Technology Stack

#### Frontend Technologies
- **Visualization Library**: D3.js, Chart.js, or similar
- **Dashboard Framework**: React, Vue.js, or Angular
- **UI Components**: Responsive design with mobile support
- **Real-time Updates**: WebSocket or Server-Sent Events

#### Backend Infrastructure  
- **Database**: PostgreSQL with analytics views
- **API Layer**: REST APIs with GraphQL consideration
- **Caching**: Redis for frequently accessed data
- **Message Queue**: For real-time data pipeline

#### Data Pipeline
- **ETL/ELT**: Scheduled refresh of materialized views
- **Real-time Stream**: For Tier 1 dashboard updates  
- **Data Validation**: Automated data quality checks
- **Error Handling**: Graceful degradation and alerts

### Dashboard Performance Requirements

| Dashboard Tier | Refresh Frequency | Load Time Target | Concurrent Users | Data Latency |
|---|---|---|---|---|
| **Tier 1** (Operational) | <1 minute | <3 seconds | 50+ | Real-time |
| **Tier 2** (Management) | 5-15 minutes | <5 seconds | 25+ | Near real-time |
| **Tier 3** (Analytical) | Daily/Hourly | <10 seconds | 10+ | Acceptable lag |

### Data Volume Considerations
- **Expected Queries/Hour**: 10,000+ across all dashboards
- **Concurrent Dashboard Users**: 100+ peak
- **Data Retention**: 5+ years for trending analysis
- **Export Capabilities**: PDF, Excel, CSV for all dashboards

---

## Security & Access Control

### User Roles & Permissions

| Role | Dashboard Access | Data Scope | Export Rights |
|---|---|---|---|
| **Executive** | All dashboards | All entities | Full export |
| **Risk Manager** | Risk, Compliance, Portfolio | All entities | Full export |
| **Portfolio Manager** | Portfolio, Collections, Performance | Assigned portfolios | Limited export |
| **Collections Agent** | Collections, Payment Health | Assigned accounts | No export |
| **Analyst** | All analytical dashboards | All entities | Full export |
| **Auditor** | Compliance, Risk | All entities | Full export |
| **Treasury** | Cash Flow, Currency Risk | All entities | Full export |

### Security Requirements
- **Authentication**: Multi-factor authentication required
- **Authorization**: Role-based access control (RBAC)  
- **Data Encryption**: In transit and at rest
- **Audit Logging**: All dashboard access and exports logged
- **Session Management**: Automatic timeout and re-authentication
- **Data Masking**: Sensitive fields masked based on user role

### Compliance Considerations
- **GDPR/PDPA**: Personal data protection and right to be forgotten
- **Financial Regulations**: Appropriate data retention and reporting
- **Internal Audit**: Dashboard access and usage tracking
- **Data Lineage**: Traceability from source to dashboard

---

## Implementation Roadmap

### Phase 1: Core Operational Dashboards (Weeks 1-4)
- Loan Portfolio Overview Dashboard
- Cash Flow Management Dashboard  
- Collections Performance Dashboard
- Payment Health Metrics Dashboard

### Phase 2: Advanced Analytics (Weeks 5-8)
- Risk Analytics Dashboard
- Performance Metrics Dashboard
- Regulatory Compliance Dashboard

### Phase 3: Executive & Strategic (Weeks 9-12)
- Executive Summary Dashboard
- Business Intelligence Dashboard
- Multi-Currency Consolidated Dashboard

### Phase 4: Predictive & Advanced Features (Weeks 13-16)
- Predictive Analytics Foundation Dashboard
- Advanced drill-down capabilities
- Mobile responsiveness
- Export and scheduling features

---

## Success Metrics

### User Adoption Targets
- **Dashboard Usage**: >80% of target users accessing weekly
- **Session Duration**: >5 minutes average session time
- **Feature Utilization**: >60% of features used regularly

### Technical Performance  
- **Uptime**: >99.5% dashboard availability
- **Load Time**: <3 seconds for Tier 1 dashboards
- **Error Rate**: <1% failed requests

### Business Impact
- **Decision Speed**: 50% faster management decisions
- **Risk Detection**: Earlier identification of portfolio issues
- **Operational Efficiency**: 25% reduction in manual reporting

---

## Appendices

### Appendix A: Data Dictionary
*[Detailed field definitions for all metrics]*

### Appendix B: Calculation Methodologies  
*[Formulas and business rules for KPI calculations]*

### Appendix C: Mock-ups and Wireframes
*[Visual design specifications for each dashboard]*

### Appendix D: API Documentation
*[Technical API specifications for dashboard data]*

---

**Document Control**
- **Version**: 1.0
- **Last Updated**: December 2024
- **Next Review**: March 2025
- **Owner**: Data & Analytics Team
- **Approver**: Chief Technology Officer