# Deployment Guide - Rently Lending Platform

This guide provides comprehensive procedures for deploying the Rently lending platform data strategy enhancements to production environments. It covers environment setup, database migrations, testing procedures, and troubleshooting for a financial technology platform requiring high reliability and zero data loss.

## Table of Contents
1. [Deployment Overview](#deployment-overview)
2. [Environment Setup](#environment-setup)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Database Migration Procedures](#database-migration-procedures)
5. [Testing and Validation](#testing-and-validation)
6. [Monitoring and Alerting](#monitoring-and-alerting)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Deployment Verification](#post-deployment-verification)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Emergency Procedures](#emergency-procedures)

## Deployment Overview

### Deployment Philosophy
The Rently lending platform follows a **zero-downtime**, **zero-data-loss** deployment strategy specifically designed for financial services requirements. All deployments prioritize data integrity and regulatory compliance over speed.

### Key Principles
- **Data Integrity First**: No deployment proceeds without comprehensive data validation
- **Incremental Changes**: Large changes are broken into smaller, testable increments
- **Comprehensive Testing**: Each change is tested in staging environment first
- **Automated Rollback**: Every deployment includes automated rollback procedures
- **Continuous Monitoring**: Real-time monitoring during and after deployment

### Deployment Types

#### Standard Deployment (Scheduled Maintenance)
- **Duration**: 2-4 hours maintenance window
- **Frequency**: Bi-weekly on weekends
- **Scope**: Feature releases, schema enhancements, performance improvements
- **Approval**: Business and technical stakeholders

#### Hotfix Deployment (Emergency)
- **Duration**: <1 hour targeted deployment
- **Frequency**: As needed for critical issues
- **Scope**: Critical bug fixes, security patches
- **Approval**: Technical lead and on-call manager

#### Infrastructure Deployment
- **Duration**: Varies by scope
- **Frequency**: Monthly or as needed
- **Scope**: Server upgrades, configuration changes
- **Approval**: Infrastructure team and security team

## Environment Setup

### Environment Hierarchy

#### Development Environment
- **Purpose**: Individual developer testing and feature development
- **Data**: Anonymized test data, synthetic datasets
- **Access**: All developers, full access
- **Backup**: Not required (recreatable)

#### Staging Environment
- **Purpose**: Integration testing, UAT, performance testing
- **Data**: Production-like data (anonymized)
- **Access**: Development team, QA team, business users
- **Backup**: Daily automated backups
- **Configuration**: Mirrors production as closely as possible

#### Production Environment
- **Purpose**: Live customer-facing system
- **Data**: Real customer and financial data
- **Access**: Restricted to authorized personnel only
- **Backup**: Multiple daily backups, point-in-time recovery
- **Monitoring**: 24/7 monitoring and alerting

### Infrastructure Requirements

#### Database Server Specifications
```yaml
Production Database Server:
  CPU: 16-32 cores (Intel Xeon or AMD EPYC)
  Memory: 64-128 GB RAM (ECC recommended)
  Storage: 
    Primary: 2TB+ NVMe SSD (50,000+ IOPS)
    Backup: 10TB+ for historical data retention
  Network: 10 Gbps interface with redundancy
  OS: Ubuntu 22.04 LTS or RHEL 8+

PostgreSQL Configuration:
  Version: PostgreSQL 14+ (latest stable)
  Extensions:
    - uuid-ossp (UUID generation)
    - pg_stat_statements (performance monitoring)
    - pg_cron (automated scheduling)
  
Connection Pooling:
  Tool: PgBouncer 1.17+
  Max Connections: 500 clients, 25 pool size
  Pool Mode: Transaction level
```

#### Network and Security
```yaml
Network Configuration:
  VPC: Dedicated VPC for database tier
  Subnets: Private subnets only (no direct internet access)
  Security Groups: Strict port 5432 access from application tier only
  Load Balancer: Application Load Balancer for connection distribution

Security Configuration:
  Encryption: 
    - TLS 1.3 for all connections
    - Encryption at rest for all data
  Authentication: 
    - Certificate-based authentication
    - MFA for administrative access
  Audit Logging: All database operations logged
  Backup Encryption: All backups encrypted at rest
```

### Environment Configuration

#### Database Connection Configuration
```bash
# Production database connection
export PGHOST="rently-prod-db.internal"
export PGPORT="5432"
export PGDATABASE="rently_lending"
export PGUSER="rently_app"
export PGPASSWORD="$(aws secretsmanager get-secret-value --secret-id rently/db/password --query SecretString --output text)"
export PGSSLMODE="require"
export PGSSLCERT="/etc/ssl/certs/rently-db.crt"
export PGSSLKEY="/etc/ssl/private/rently-db.key"
export PGSSLROOTCERT="/etc/ssl/certs/ca-certificates.crt"

# Connection pooling configuration
export PGBOUNCER_HOST="rently-pgbouncer.internal"
export PGBOUNCER_PORT="6432"
```

#### Application Configuration
```yaml
# Application configuration for database access
database:
  primary:
    host: "${PGBOUNCER_HOST}"
    port: "${PGBOUNCER_PORT}"
    database: "${PGDATABASE}"
    username: "${PGUSER}"
    password: "${PGPASSWORD}"
    ssl_mode: "require"
    pool_size: 20
    timeout: 30
    
  analytics_replica:
    host: "rently-analytics-replica.internal"
    port: "5432"
    database: "${PGDATABASE}"
    username: "rently_analytics"
    password: "${ANALYTICS_PASSWORD}"
    ssl_mode: "require"
    pool_size: 10
    timeout: 60
```

## Pre-Deployment Checklist

### Business Readiness
- [ ] **Stakeholder Approval**: All required approvals obtained
- [ ] **Change Management**: Change request approved and scheduled
- [ ] **User Communication**: Users notified of maintenance window
- [ ] **Business Validation**: Business acceptance criteria reviewed
- [ ] **Rollback Authorization**: Rollback decision makers identified

### Technical Readiness
- [ ] **Code Review**: All code changes peer-reviewed and approved
- [ ] **Testing Complete**: All automated and manual tests passed
- [ ] **Documentation Updated**: Deployment and rollback procedures documented
- [ ] **Monitoring Setup**: Monitoring and alerting configured
- [ ] **Resource Availability**: All deployment team members available

### Infrastructure Readiness
- [ ] **Environment Health**: All systems operating normally
- [ ] **Capacity Planning**: Sufficient resources for deployment
- [ ] **Network Connectivity**: All network paths tested and verified
- [ ] **Security Clearance**: Security team approval for changes
- [ ] **Backup Verification**: Recent backups validated and accessible

### Data Readiness
- [ ] **Backup Completed**: Full database backup completed and verified
- [ ] **Data Validation**: Current data passes all integrity checks
- [ ] **Migration Scripts**: All migration scripts tested in staging
- [ ] **Rollback Scripts**: Rollback procedures tested and ready
- [ ] **Performance Baseline**: Performance metrics captured for comparison

### Deployment Artifacts
- [ ] **SQL Scripts**: All migration and validation scripts prepared
- [ ] **Configuration Files**: Environment-specific configurations ready
- [ ] **Monitoring Scripts**: Health check and monitoring scripts prepared
- [ ] **Documentation**: Deployment runbook and troubleshooting guides
- [ ] **Communication Plans**: Internal and external communication prepared

## Database Migration Procedures

### Migration Strategy
The database migration follows a **forward-only** strategy with comprehensive rollback procedures. All migrations are transactional where possible and include extensive validation.

### Pre-Migration Setup

#### Step 1: Environment Preparation
```bash
# Create deployment directory structure
sudo mkdir -p /opt/rently-deployment/{scripts,logs,backups,config}
cd /opt/rently-deployment

# Copy deployment artifacts
cp /path/to/migration-scripts/* ./scripts/
cp /path/to/config-files/* ./config/

# Set appropriate permissions
sudo chmod 750 ./scripts/*.sql
sudo chmod 640 ./config/*
sudo chown -R postgres:postgres /opt/rently-deployment
```

#### Step 2: Backup Procedures
```bash
#!/bin/bash
# backup_database.sh - Comprehensive backup procedure

BACKUP_DIR="/opt/rently-deployment/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="rently_lending"

echo "Starting full database backup at $(date)"

# Create full database backup
pg_dump \
  --host="${PGHOST}" \
  --port="${PGPORT}" \
  --username="${PGUSER}" \
  --dbname="${DB_NAME}" \
  --verbose \
  --format=custom \
  --compress=9 \
  --no-owner \
  --no-privileges \
  --file="${BACKUP_DIR}/rently_lending_${TIMESTAMP}.backup"

# Verify backup integrity
echo "Verifying backup integrity..."
pg_restore --list "${BACKUP_DIR}/rently_lending_${TIMESTAMP}.backup" > /dev/null

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: rently_lending_${TIMESTAMP}.backup"
    
    # Create checksum for integrity verification
    sha256sum "${BACKUP_DIR}/rently_lending_${TIMESTAMP}.backup" > "${BACKUP_DIR}/rently_lending_${TIMESTAMP}.backup.sha256"
    
    # Log backup details
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/rently_lending_${TIMESTAMP}.backup" | cut -f1)
    echo "$(date): Backup completed - Size: ${BACKUP_SIZE}" >> "${BACKUP_DIR}/backup_log.txt"
else
    echo "ERROR: Backup verification failed"
    exit 1
fi
```

#### Step 3: Pre-Migration Validation
```sql
-- pre_migration_validation.sql
-- Comprehensive pre-migration health checks

-- 1. Database connectivity and basic health
SELECT 'Database Connection Test' as check_name, 
       CASE WHEN version() IS NOT NULL THEN 'PASS' ELSE 'FAIL' END as status;

-- 2. Check for active connections that might block migration
SELECT 'Active Connections Check' as check_name,
       CASE WHEN COUNT(*) < 50 THEN 'PASS' 
            ELSE 'WARNING - ' || COUNT(*)::text || ' active connections' END as status
FROM pg_stat_activity 
WHERE state = 'active' AND application_name != 'psql';

-- 3. Validate current schema version
SELECT 'Schema Version Check' as check_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_version')
            THEN 'PASS - Version: ' || (SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1)
            ELSE 'FAIL - Schema version table not found' END as status;

-- 4. Check database size and available space
SELECT 'Database Size Check' as check_name,
       pg_size_pretty(pg_database_size('rently_lending')) as current_size,
       'PASS' as status;

-- 5. Validate data integrity before migration
SELECT 'Data Integrity Check' as check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' 
            ELSE 'FAIL - ' || COUNT(*)::text || ' integrity violations' END as status
FROM (
    -- Check for orphaned payment allocations
    SELECT pa.id FROM payment_allocation pa 
    LEFT JOIN payment p ON pa.payment_id = p.id 
    WHERE p.id IS NULL
    
    UNION ALL
    
    -- Check for invalid loan statuses
    SELECT l.id FROM loan l 
    WHERE l.status NOT IN ('active', 'closed', 'written_off', 'pending')
    
    UNION ALL
    
    -- Check for payment allocation imbalances
    SELECT p.id FROM payment p
    JOIN payment_allocation pa ON p.id = pa.payment_id
    WHERE p.status = 'completed' 
    GROUP BY p.id, p.amount
    HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
) integrity_issues;

-- 6. Check for long-running transactions
SELECT 'Long Running Transactions' as check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'WARNING - ' || COUNT(*)::text || ' long-running transactions' END as status
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < NOW() - INTERVAL '5 minutes'
  AND application_name != 'psql';

-- Log validation results
INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
VALUES (
    'DEPLOY_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'),
    'PRE_MIGRATION_VALIDATION',
    'COMPLETED',
    'Pre-migration validation checks completed',
    NOW()
);
```

### Migration Execution

#### Step 4: Schema Migration
```sql
-- migration_v1_to_v2.sql
-- Enhanced schema migration with comprehensive error handling

DO $$
DECLARE
    migration_start_time TIMESTAMP;
    step_start_time TIMESTAMP;
    rows_affected INTEGER;
    migration_id TEXT;
BEGIN
    migration_start_time := clock_timestamp();
    migration_id := 'MIGRATION_V1_TO_V2_' || TO_CHAR(migration_start_time, 'YYYYMMDD_HH24MISS');
    
    RAISE NOTICE 'Starting migration % at %', migration_id, migration_start_time;
    
    -- Log migration start
    INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
    VALUES (migration_id, 'MIGRATION_START', 'IN_PROGRESS', 'Migration started', migration_start_time);
    
    -- Step 1: Create new tables
    step_start_time := clock_timestamp();
    RAISE NOTICE 'Step 1: Creating new tables...';
    
    -- Enhanced collections event tracking
    CREATE TABLE IF NOT EXISTS collections_event (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        loan_id UUID NOT NULL REFERENCES loan(id),
        event_type VARCHAR(50) NOT NULL,
        event_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        dpd_snapshot INTEGER,
        event_details JSONB,
        resolution_status VARCHAR(20),
        created_by UUID,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    
    -- Loan status history for audit trail
    CREATE TABLE IF NOT EXISTS loan_status_history (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        loan_id UUID NOT NULL REFERENCES loan(id),
        status_type VARCHAR(50) NOT NULL,
        status_value VARCHAR(100) NOT NULL,
        effective_from TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        effective_through TIMESTAMP WITH TIME ZONE,
        reason TEXT,
        created_by UUID,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    
    RAISE NOTICE 'Step 1 completed in %', clock_timestamp() - step_start_time;
    
    -- Step 2: Create indexes for performance
    step_start_time := clock_timestamp();
    RAISE NOTICE 'Step 2: Creating indexes...';
    
    -- Collections event indexes
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_loan_id 
        ON collections_event(loan_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_type_date 
        ON collections_event(event_type, event_at DESC);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collections_event_dpd 
        ON collections_event(dpd_snapshot) WHERE dpd_snapshot > 0;
    
    -- Status history indexes
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_loan_id 
        ON loan_status_history(loan_id);
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loan_status_history_current 
        ON loan_status_history(loan_id, status_type, effective_from DESC) 
        WHERE effective_through IS NULL;
    
    RAISE NOTICE 'Step 2 completed in %', clock_timestamp() - step_start_time;
    
    -- Step 3: Create enhanced views
    step_start_time := clock_timestamp();
    RAISE NOTICE 'Step 3: Creating enhanced analytical views...';
    
    -- Current loan status view (materialized for performance)
    CREATE MATERIALIZED VIEW IF NOT EXISTS mv_current_loan_status AS
    SELECT 
        l.id as loan_id,
        l.loan_number,
        l.status as loan_status,
        l.principal_amount,
        p.category as product_category,
        party.display_name as borrower_name,
        COALESCE(cls_risk.status_value, 'normal') as current_risk_level,
        COALESCE(MAX(ce.dpd_snapshot), 0) as current_dpd,
        CASE 
            WHEN COALESCE(MAX(ce.dpd_snapshot), 0) = 0 THEN 'Current'
            WHEN COALESCE(MAX(ce.dpd_snapshot), 0) <= 30 THEN '1-30 DPD'
            WHEN COALESCE(MAX(ce.dpd_snapshot), 0) <= 60 THEN '31-60 DPD'
            WHEN COALESCE(MAX(ce.dpd_snapshot), 0) <= 90 THEN '61-90 DPD'
            ELSE '90+ DPD'
        END as dpd_bucket,
        NOW() as last_updated
    FROM loan l
    JOIN product p ON l.product_id = p.id
    JOIN party ON l.borrower_party_id = party.id
    LEFT JOIN loan_status_history cls_risk ON l.id = cls_risk.loan_id 
        AND cls_risk.status_type = 'risk_level'
        AND cls_risk.effective_through IS NULL
    LEFT JOIN collections_event ce ON l.id = ce.loan_id
    WHERE l.status = 'active'
    GROUP BY l.id, l.loan_number, l.status, l.principal_amount, 
             p.category, party.display_name, cls_risk.status_value;
    
    -- Create indexes on materialized view
    CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_current_loan_status_loan_id 
        ON mv_current_loan_status(loan_id);
    CREATE INDEX IF NOT EXISTS idx_mv_current_loan_status_dpd_bucket 
        ON mv_current_loan_status(dpd_bucket);
    CREATE INDEX IF NOT EXISTS idx_mv_current_loan_status_risk 
        ON mv_current_loan_status(current_risk_level);
    
    RAISE NOTICE 'Step 3 completed in %', clock_timestamp() - step_start_time;
    
    -- Step 4: Create automated refresh function
    step_start_time := clock_timestamp();
    RAISE NOTICE 'Step 4: Creating automation functions...';
    
    CREATE OR REPLACE FUNCTION refresh_materialized_views()
    RETURNS void AS $func$
    BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_loan_status;
        
        INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
        VALUES (
            'AUTO_REFRESH',
            'MATERIALIZED_VIEW_REFRESH', 
            'COMPLETED',
            'Materialized views refreshed successfully',
            NOW()
        );
    EXCEPTION
        WHEN OTHERS THEN
            INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
            VALUES (
                'AUTO_REFRESH',
                'MATERIALIZED_VIEW_REFRESH', 
                'FAILED',
                'Error: ' || SQLERRM,
                NOW()
            );
            RAISE;
    END;
    $func$ LANGUAGE plpgsql;
    
    RAISE NOTICE 'Step 4 completed in %', clock_timestamp() - step_start_time;
    
    -- Step 5: Update schema version
    INSERT INTO schema_version (version, description, applied_at)
    VALUES ('v2.0.0', 'Enhanced collections and status tracking', NOW());
    
    -- Log successful completion
    INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
    VALUES (
        migration_id, 
        'MIGRATION_COMPLETE', 
        'SUCCESS', 
        'Migration completed successfully in ' || (clock_timestamp() - migration_start_time)::text,
        clock_timestamp()
    );
    
    RAISE NOTICE 'Migration % completed successfully in %', 
        migration_id, clock_timestamp() - migration_start_time;
        
EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
        VALUES (
            migration_id, 
            'MIGRATION_ERROR', 
            'FAILED', 
            'Migration failed: ' || SQLERRM,
            clock_timestamp()
        );
        
        RAISE NOTICE 'Migration % failed: %', migration_id, SQLERRM;
        RAISE;
END $$;
```

#### Step 5: Data Migration and Validation
```sql
-- data_migration_validation.sql
-- Migrate existing data and validate integrity

DO $$
DECLARE
    validation_errors INTEGER := 0;
    migration_id TEXT;
BEGIN
    migration_id := 'DATA_MIGRATION_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    
    RAISE NOTICE 'Starting data migration validation...';
    
    -- Populate loan status history for existing loans
    INSERT INTO loan_status_history (loan_id, status_type, status_value, effective_from, created_at)
    SELECT 
        id,
        'loan_status',
        status,
        COALESCE(created_at, start_date),
        NOW()
    FROM loan
    WHERE id NOT IN (
        SELECT DISTINCT loan_id 
        FROM loan_status_history 
        WHERE status_type = 'loan_status'
    );
    
    RAISE NOTICE 'Populated loan status history for % loans', 
        (SELECT COUNT(*) FROM loan_status_history WHERE status_type = 'loan_status');
    
    -- Validate payment allocation consistency
    WITH payment_validation AS (
        SELECT 
            p.id,
            p.amount,
            COALESCE(SUM(pa.allocated_amount), 0) as total_allocated
        FROM payment p
        LEFT JOIN payment_allocation pa ON p.id = pa.payment_id
        WHERE p.status = 'completed'
        GROUP BY p.id, p.amount
    )
    SELECT COUNT(*) INTO validation_errors
    FROM payment_validation
    WHERE ABS(amount - total_allocated) > 0.01;
    
    IF validation_errors > 0 THEN
        RAISE EXCEPTION 'Data validation failed: % payment allocation errors found', validation_errors;
    END IF;
    
    -- Refresh materialized views with new data
    PERFORM refresh_materialized_views();
    
    -- Log successful data migration
    INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
    VALUES (
        migration_id,
        'DATA_MIGRATION',
        'SUCCESS',
        'Data migration and validation completed successfully',
        NOW()
    );
    
    RAISE NOTICE 'Data migration completed successfully';
    
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
        VALUES (
            migration_id,
            'DATA_MIGRATION',
            'FAILED',
            'Data migration failed: ' || SQLERRM,
            NOW()
        );
        RAISE;
END $$;
```

## Testing and Validation

### Post-Migration Testing Suite

#### Functional Testing
```sql
-- functional_tests.sql
-- Comprehensive functional testing after migration

-- Test 1: Verify new table creation and constraints
SELECT 'Table Creation Test' as test_name,
       CASE WHEN COUNT(*) = 2 THEN 'PASS' 
            ELSE 'FAIL - Expected 2 new tables, found ' || COUNT(*)::text END as result
FROM information_schema.tables
WHERE table_name IN ('collections_event', 'loan_status_history')
  AND table_schema = 'public';

-- Test 2: Verify index creation
SELECT 'Index Creation Test' as test_name,
       CASE WHEN COUNT(*) >= 6 THEN 'PASS'
            ELSE 'FAIL - Missing indexes' END as result
FROM pg_indexes
WHERE tablename IN ('collections_event', 'loan_status_history', 'mv_current_loan_status');

-- Test 3: Verify materialized view functionality
SELECT 'Materialized View Test' as test_name,
       CASE WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL - No data in materialized view' END as result
FROM mv_current_loan_status;

-- Test 4: Verify data integrity after migration
WITH integrity_check AS (
    SELECT COUNT(*) as violation_count
    FROM (
        -- Check for orphaned records
        SELECT 1 FROM collections_event ce
        LEFT JOIN loan l ON ce.loan_id = l.id
        WHERE l.id IS NULL
        
        UNION ALL
        
        SELECT 1 FROM loan_status_history lsh
        LEFT JOIN loan l ON lsh.loan_id = l.id
        WHERE l.id IS NULL
    ) violations
)
SELECT 'Data Integrity Test' as test_name,
       CASE WHEN violation_count = 0 THEN 'PASS'
            ELSE 'FAIL - ' || violation_count::text || ' integrity violations' END as result
FROM integrity_check;

-- Test 5: Performance test for new views
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM mv_current_loan_status 
WHERE dpd_bucket = '1-30 DPD' 
LIMIT 100;
```

#### Performance Testing
```bash
#!/bin/bash
# performance_tests.sh
# Automated performance testing after migration

echo "Running performance tests..."

# Test 1: Query response time for key views
psql -d rently_lending -c "
\timing on
SELECT COUNT(*) FROM v_loan_portfolio_overview;
SELECT COUNT(*) FROM v_collections_performance;
SELECT COUNT(*) FROM mv_current_loan_status;
\timing off
" 2>&1 | grep "Time:" > performance_results.log

# Test 2: Concurrent connection handling
for i in {1..10}; do
    psql -d rently_lending -c "SELECT COUNT(*) FROM loan;" &
done
wait

echo "Performance tests completed. Results in performance_results.log"
```

#### Data Quality Testing
```sql
-- data_quality_tests.sql
-- Comprehensive data quality validation

-- Test Suite: Data Quality Validation
SELECT 'Starting Data Quality Tests' as message, NOW() as test_time;

-- Test 1: Completeness Check
WITH completeness_check AS (
    SELECT 
        'loan' as table_name,
        COUNT(*) as total_records,
        COUNT(CASE WHEN loan_number IS NULL THEN 1 END) as missing_loan_number,
        COUNT(CASE WHEN borrower_party_id IS NULL THEN 1 END) as missing_borrower,
        COUNT(CASE WHEN principal_amount IS NULL THEN 1 END) as missing_principal
    FROM loan
    
    UNION ALL
    
    SELECT 
        'payment' as table_name,
        COUNT(*) as total_records,
        COUNT(CASE WHEN amount IS NULL THEN 1 END) as missing_amount,
        COUNT(CASE WHEN currency_code IS NULL THEN 1 END) as missing_currency,
        COUNT(CASE WHEN received_at IS NULL THEN 1 END) as missing_received_date
    FROM payment
)
SELECT 
    table_name,
    total_records,
    CASE WHEN missing_loan_number + missing_borrower + missing_principal + 
              missing_amount + missing_currency + missing_received_date = 0 
         THEN 'PASS' 
         ELSE 'FAIL - Missing critical data' END as completeness_result
FROM completeness_check;

-- Test 2: Referential Integrity
WITH referential_check AS (
    SELECT 'payment_allocation_to_payment' as relationship,
           COUNT(*) as violations
    FROM payment_allocation pa
    LEFT JOIN payment p ON pa.payment_id = p.id
    WHERE p.id IS NULL
    
    UNION ALL
    
    SELECT 'payment_allocation_to_loan' as relationship,
           COUNT(*) as violations
    FROM payment_allocation pa
    LEFT JOIN loan l ON pa.loan_id = l.id
    WHERE l.id IS NULL
    
    UNION ALL
    
    SELECT 'loan_to_product' as relationship,
           COUNT(*) as violations
    FROM loan l
    LEFT JOIN product p ON l.product_id = p.id
    WHERE p.id IS NULL
)
SELECT 
    relationship,
    violations,
    CASE WHEN violations = 0 THEN 'PASS' 
         ELSE 'FAIL' END as integrity_result
FROM referential_check;

-- Test 3: Business Rule Validation
WITH business_rules_check AS (
    -- Check payment allocation totals
    SELECT 
        'payment_allocation_balance' as rule_name,
        COUNT(*) as violations
    FROM payment p
    JOIN payment_allocation pa ON p.id = pa.payment_id
    WHERE p.status = 'completed'
    GROUP BY p.id, p.amount
    HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
    
    UNION ALL
    
    -- Check loan date ranges
    SELECT 
        'loan_date_validity' as rule_name,
        COUNT(*) as violations
    FROM loan
    WHERE end_date <= start_date
    
    UNION ALL
    
    -- Check interest rate ranges
    SELECT 
        'interest_rate_validity' as rule_name,
        COUNT(*) as violations
    FROM loan
    WHERE interest_rate < 0 OR interest_rate > 1.0  -- 0% to 100%
)
SELECT 
    rule_name,
    COALESCE(SUM(violations), 0) as total_violations,
    CASE WHEN COALESCE(SUM(violations), 0) = 0 THEN 'PASS' 
         ELSE 'FAIL' END as business_rule_result
FROM business_rules_check
GROUP BY rule_name;

-- Log test completion
INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
VALUES (
    'DATA_QUALITY_TEST_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'),
    'DATA_QUALITY_TESTING',
    'COMPLETED',
    'Data quality tests completed',
    NOW()
);
```

## Monitoring and Alerting

### Real-Time Monitoring Setup

#### Database Health Monitoring
```sql
-- monitoring_setup.sql
-- Comprehensive monitoring and alerting setup

-- Create monitoring views
CREATE OR REPLACE VIEW v_system_health AS
SELECT 
    'Database Performance' as category,
    pg_database_size('rently_lending') as db_size_bytes,
    pg_size_pretty(pg_database_size('rently_lending')) as db_size_formatted,
    
    -- Connection metrics
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle') as idle_connections,
    
    -- Query performance (last 24 hours)
    (SELECT ROUND(AVG(mean_exec_time), 2) 
     FROM pg_stat_statements 
     WHERE calls > 10) as avg_query_time_ms,
    
    -- Cache performance
    ROUND(100.0 * SUM(blks_hit) / NULLIF(SUM(blks_hit + blks_read), 0), 2) as cache_hit_ratio_pct,
    
    -- Materialized view freshness
    (SELECT EXTRACT(minutes FROM NOW() - MAX(last_updated)) 
     FROM mv_current_loan_status) as oldest_mv_age_minutes
     
FROM pg_stat_database 
WHERE datname = 'rently_lending';

-- Create alerting function
CREATE OR REPLACE FUNCTION check_system_alerts()
RETURNS TABLE (
    alert_type TEXT,
    alert_level TEXT,
    alert_message TEXT,
    metric_value NUMERIC,
    threshold_value NUMERIC,
    alert_time TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    WITH system_metrics AS (SELECT * FROM v_system_health),
    alerts AS (
        -- Connection pool alerts
        SELECT 
            'Connection Pool'::TEXT as alert_type,
            CASE WHEN active_connections > 80 THEN 'CRITICAL'
                 WHEN active_connections > 60 THEN 'WARNING'
                 ELSE 'OK' END as alert_level,
            'Active connections: ' || active_connections::TEXT as alert_message,
            active_connections as metric_value,
            80 as threshold_value,
            NOW() as alert_time
        FROM system_metrics
        WHERE active_connections > 60
        
        UNION ALL
        
        -- Cache performance alerts
        SELECT 
            'Cache Performance'::TEXT as alert_type,
            CASE WHEN cache_hit_ratio_pct < 85 THEN 'CRITICAL'
                 WHEN cache_hit_ratio_pct < 95 THEN 'WARNING'
                 ELSE 'OK' END as alert_level,
            'Cache hit ratio: ' || cache_hit_ratio_pct::TEXT || '%' as alert_message,
            cache_hit_ratio_pct as metric_value,
            95 as threshold_value,
            NOW() as alert_time
        FROM system_metrics
        WHERE cache_hit_ratio_pct < 95
        
        UNION ALL
        
        -- Materialized view freshness alerts
        SELECT 
            'Materialized Views'::TEXT as alert_type,
            CASE WHEN oldest_mv_age_minutes > 10 THEN 'CRITICAL'
                 WHEN oldest_mv_age_minutes > 5 THEN 'WARNING'
                 ELSE 'OK' END as alert_level,
            'Oldest MV age: ' || oldest_mv_age_minutes::TEXT || ' minutes' as alert_message,
            oldest_mv_age_minutes as metric_value,
            5 as threshold_value,
            NOW() as alert_time
        FROM system_metrics
        WHERE oldest_mv_age_minutes > 5
        
        UNION ALL
        
        -- Query performance alerts
        SELECT 
            'Query Performance'::TEXT as alert_type,
            CASE WHEN avg_query_time_ms > 5000 THEN 'CRITICAL'
                 WHEN avg_query_time_ms > 3000 THEN 'WARNING'
                 ELSE 'OK' END as alert_level,
            'Average query time: ' || avg_query_time_ms::TEXT || 'ms' as alert_message,
            avg_query_time_ms as metric_value,
            3000 as threshold_value,
            NOW() as alert_time
        FROM system_metrics
        WHERE avg_query_time_ms > 3000
    )
    SELECT * FROM alerts;
END;
$$ LANGUAGE plpgsql;
```

#### Automated Monitoring Scripts
```bash
#!/bin/bash
# monitoring_daemon.sh
# Continuous monitoring with alerting

ALERT_THRESHOLD_FILE="/opt/rently-deployment/config/alert_thresholds.conf"
ALERT_LOG="/opt/rently-deployment/logs/alerts.log"
NOTIFICATION_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Function to send alerts
send_alert() {
    local alert_level="$1"
    local alert_message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "$timestamp [$alert_level] $alert_message" >> "$ALERT_LOG"
    
    # Send notification for WARNING or CRITICAL alerts
    if [[ "$alert_level" == "WARNING" || "$alert_level" == "CRITICAL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Rently DB Alert [$alert_level]: $alert_message\"}" \
            "$NOTIFICATION_WEBHOOK" 2>/dev/null
    fi
}

# Main monitoring loop
while true; do
    echo "$(date): Running system health checks..."
    
    # Check database connectivity
    if ! pg_isready -h "$PGHOST" -p "$PGPORT" -d "$PGDATABASE" >/dev/null 2>&1; then
        send_alert "CRITICAL" "Database connection failed"
        sleep 30
        continue
    fi
    
    # Run automated alert checks
    psql -d rently_lending -t -c "
        SELECT alert_level || '|' || alert_message 
        FROM check_system_alerts() 
        WHERE alert_level IN ('WARNING', 'CRITICAL');
    " | while IFS='|' read -r level message; do
        [[ -n "$level" && -n "$message" ]] && send_alert "$level" "$message"
    done
    
    # Check disk space
    DISK_USAGE=$(df -h /var/lib/postgresql | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -gt 85 ]]; then
        send_alert "WARNING" "Disk usage at ${DISK_USAGE}%"
    elif [[ $DISK_USAGE -gt 95 ]]; then
        send_alert "CRITICAL" "Disk usage at ${DISK_USAGE}%"
    fi
    
    # Sleep for 5 minutes between checks
    sleep 300
done
```

#### Performance Monitoring Dashboard
```sql
-- Create performance monitoring dashboard
CREATE OR REPLACE VIEW v_performance_dashboard AS
WITH query_stats AS (
    SELECT 
        LEFT(query, 50) || '...' as query_preview,
        calls,
        ROUND(mean_exec_time, 2) as avg_time_ms,
        ROUND(total_exec_time, 2) as total_time_ms,
        ROUND((100.0 * total_exec_time / SUM(total_exec_time) OVER()), 2) as time_percentage
    FROM pg_stat_statements
    WHERE calls > 10
    ORDER BY total_exec_time DESC
    LIMIT 10
),
connection_stats AS (
    SELECT 
        state,
        COUNT(*) as connection_count,
        AVG(EXTRACT(seconds FROM NOW() - state_change)) as avg_duration_seconds
    FROM pg_stat_activity
    WHERE application_name != 'psql'
    GROUP BY state
),
table_stats AS (
    SELECT 
        schemaname||'.'||tablename as table_name,
        n_tup_ins as inserts,
        n_tup_upd as updates,
        n_tup_del as deletes,
        seq_scan as sequential_scans,
        idx_scan as index_scans,
        ROUND(100.0 * idx_scan / NULLIF(seq_scan + idx_scan, 0), 2) as index_usage_pct
    FROM pg_stat_user_tables
    ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC
    LIMIT 10
)
SELECT 
    'Top Queries by Total Time' as section,
    array_agg(
        query_preview || ' (' || calls || ' calls, ' || avg_time_ms || 'ms avg)'
    ) as details
FROM query_stats

UNION ALL

SELECT 
    'Connection Status' as section,
    array_agg(
        state || ': ' || connection_count || ' connections'
    ) as details
FROM connection_stats

UNION ALL

SELECT 
    'Table Activity' as section,
    array_agg(
        table_name || ' (' || (inserts + updates + deletes) || ' modifications, ' || 
        COALESCE(index_usage_pct::text, '0') || '% index usage)'
    ) as details
FROM table_stats;
```

## Rollback Procedures

### Emergency Rollback Strategy

#### Automated Rollback Script
```bash
#!/bin/bash
# emergency_rollback.sh
# Comprehensive rollback procedures

set -euo pipefail

ROLLBACK_ID="ROLLBACK_$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/opt/rently-deployment/backups"
LOG_FILE="/opt/rently-deployment/logs/rollback_${ROLLBACK_ID}.log"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Function to check database connectivity
check_db_connectivity() {
    if ! pg_isready -h "$PGHOST" -p "$PGPORT" -d "$PGDATABASE" >/dev/null 2>&1; then
        log_message "ERROR: Cannot connect to database"
        exit 1
    fi
    log_message "Database connectivity confirmed"
}

# Function to find latest backup
find_latest_backup() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/rently_lending_*.backup 2>/dev/null | head -n1)
    if [[ -z "$latest_backup" ]]; then
        log_message "ERROR: No backup files found in $BACKUP_DIR"
        exit 1
    fi
    echo "$latest_backup"
}

# Function to validate backup integrity
validate_backup() {
    local backup_file="$1"
    log_message "Validating backup file: $backup_file"
    
    if [[ -f "$backup_file.sha256" ]]; then
        if sha256sum -c "$backup_file.sha256" >/dev/null 2>&1; then
            log_message "Backup integrity verified"
        else
            log_message "ERROR: Backup integrity check failed"
            exit 1
        fi
    else
        log_message "WARNING: No checksum file found, skipping integrity check"
    fi
    
    # Verify backup can be listed
    if pg_restore --list "$backup_file" >/dev/null 2>&1; then
        log_message "Backup file structure is valid"
    else
        log_message "ERROR: Backup file is corrupted"
        exit 1
    fi
}

# Function to create pre-rollback snapshot
create_pre_rollback_snapshot() {
    log_message "Creating pre-rollback database snapshot..."
    local snapshot_file="$BACKUP_DIR/pre_rollback_snapshot_${ROLLBACK_ID}.backup"
    
    pg_dump \
        --host="$PGHOST" \
        --port="$PGPORT" \
        --username="$PGUSER" \
        --dbname="$PGDATABASE" \
        --format=custom \
        --compress=9 \
        --file="$snapshot_file"
    
    if [[ $? -eq 0 ]]; then
        log_message "Pre-rollback snapshot created: $snapshot_file"
    else
        log_message "ERROR: Failed to create pre-rollback snapshot"
        exit 1
    fi
}

# Function to execute rollback
execute_rollback() {
    local backup_file="$1"
    local rollback_db="rently_lending_rollback"
    
    log_message "Starting rollback from backup: $backup_file"
    
    # Create temporary database for rollback
    log_message "Creating rollback database: $rollback_db"
    createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$rollback_db"
    
    # Restore backup to temporary database
    log_message "Restoring backup to temporary database..."
    pg_restore \
        --host="$PGHOST" \
        --port="$PGPORT" \
        --username="$PGUSER" \
        --dbname="$rollback_db" \
        --clean \
        --if-exists \
        --verbose \
        "$backup_file" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log_message "Backup restoration completed successfully"
    else
        log_message "ERROR: Backup restoration failed"
        dropdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$rollback_db" 2>/dev/null || true
        exit 1
    fi
    
    # Validate restored database
    log_message "Validating restored database..."
    local restored_count=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$rollback_db" -t -c "SELECT COUNT(*) FROM loan;")
    
    if [[ $restored_count =~ ^[0-9]+$ && $restored_count -gt 0 ]]; then
        log_message "Database validation passed: $restored_count loans found"
    else
        log_message "ERROR: Database validation failed"
        dropdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$rollback_db" 2>/dev/null || true
        exit 1
    fi
    
    # Switch databases (rename operations)
    log_message "Switching databases..."
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c "
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE datname = 'rently_lending' AND pid != pg_backend_pid();
        
        ALTER DATABASE rently_lending RENAME TO rently_lending_failed_${ROLLBACK_ID};
        ALTER DATABASE $rollback_db RENAME TO rently_lending;
    " 2>&1 | tee -a "$LOG_FILE"
    
    log_message "Database rollback completed successfully"
}

# Function to verify rollback success
verify_rollback() {
    log_message "Verifying rollback success..."
    
    # Test basic connectivity and functionality
    local test_result=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -c "
        SELECT 'ROLLBACK_SUCCESS:' || COUNT(*) 
        FROM loan 
        WHERE created_at < NOW() - INTERVAL '1 hour';
    ")
    
    if [[ $test_result == *"ROLLBACK_SUCCESS:"* ]]; then
        log_message "Rollback verification passed"
        
        # Log rollback in deployment log
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
            INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
            VALUES (
                '$ROLLBACK_ID',
                'EMERGENCY_ROLLBACK',
                'SUCCESS',
                'Emergency rollback completed successfully',
                NOW()
            );
        " 2>&1 | tee -a "$LOG_FILE"
        
    else
        log_message "ERROR: Rollback verification failed"
        exit 1
    fi
}

# Main rollback execution
main() {
    log_message "Starting emergency rollback procedure: $ROLLBACK_ID"
    
    # Pre-flight checks
    check_db_connectivity
    
    # Find and validate backup
    BACKUP_FILE=$(find_latest_backup)
    validate_backup "$BACKUP_FILE"
    
    # Create snapshot before rollback
    create_pre_rollback_snapshot
    
    # Execute rollback
    execute_rollback "$BACKUP_FILE"
    
    # Verify success
    verify_rollback
    
    log_message "Emergency rollback completed successfully: $ROLLBACK_ID"
    echo "Rollback completed. Check log file: $LOG_FILE"
}

# Execute main function
main "$@"
```

### Schema-Only Rollback
```sql
-- schema_rollback.sql
-- Rollback schema changes without full data restoration

DO $$
DECLARE
    rollback_id TEXT;
BEGIN
    rollback_id := 'SCHEMA_ROLLBACK_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    
    RAISE NOTICE 'Starting schema rollback: %', rollback_id;
    
    -- Log rollback start
    INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
    VALUES (rollback_id, 'SCHEMA_ROLLBACK_START', 'IN_PROGRESS', 'Schema rollback started', NOW());
    
    -- Drop new materialized views
    DROP MATERIALIZED VIEW IF EXISTS mv_current_loan_status CASCADE;
    
    -- Drop new tables (only if they're safe to drop)
    -- Note: Only drop if no critical data exists
    
    -- Check if new tables have data
    IF (SELECT COUNT(*) FROM collections_event) = 0 THEN
        DROP TABLE IF EXISTS collections_event CASCADE;
        RAISE NOTICE 'Dropped collections_event table (empty)';
    ELSE
        RAISE NOTICE 'WARNING: collections_event table has data, not dropping';
    END IF;
    
    IF (SELECT COUNT(*) FROM loan_status_history) = 0 THEN
        DROP TABLE IF EXISTS loan_status_history CASCADE;
        RAISE NOTICE 'Dropped loan_status_history table (empty)';
    ELSE
        RAISE NOTICE 'WARNING: loan_status_history table has data, not dropping';
    END IF;
    
    -- Drop new functions
    DROP FUNCTION IF EXISTS refresh_materialized_views() CASCADE;
    DROP FUNCTION IF EXISTS check_system_alerts() CASCADE;
    
    -- Revert schema version
    DELETE FROM schema_version WHERE version = 'v2.0.0';
    
    -- Log successful completion
    INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
    VALUES (rollback_id, 'SCHEMA_ROLLBACK_COMPLETE', 'SUCCESS', 'Schema rollback completed', NOW());
    
    RAISE NOTICE 'Schema rollback completed: %', rollback_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
        VALUES (rollback_id, 'SCHEMA_ROLLBACK_ERROR', 'FAILED', 'Schema rollback failed: ' || SQLERRM, NOW());
        
        RAISE NOTICE 'Schema rollback failed: %', SQLERRM;
        RAISE;
END $$;
```

## Post-Deployment Verification

### Comprehensive System Verification
```bash
#!/bin/bash
# post_deployment_verification.sh
# Complete system verification after deployment

VERIFICATION_ID="VERIFY_$(date +%Y%m%d_%H%M%S)"
RESULTS_FILE="/opt/rently-deployment/logs/verification_${VERIFICATION_ID}.log"

# Function to run verification tests
run_verification_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    echo "Running: $test_name" | tee -a "$RESULTS_FILE"
    
    local result=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && "$result" =~ $expected_pattern ]]; then
        echo "✓ PASS: $test_name" | tee -a "$RESULTS_FILE"
        return 0
    else
        echo "✗ FAIL: $test_name - $result" | tee -a "$RESULTS_FILE"
        return 1
    fi
}

echo "Starting post-deployment verification: $VERIFICATION_ID" | tee "$RESULTS_FILE"

# Test 1: Database Connectivity
run_verification_test "Database Connectivity" \
    "pg_isready -h $PGHOST -p $PGPORT -d $PGDATABASE" \
    "accepting connections"

# Test 2: Schema Version
run_verification_test "Schema Version Check" \
    "psql -d rently_lending -t -c \"SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;\"" \
    "v2.0.0"

# Test 3: New Tables Exist
run_verification_test "New Tables Check" \
    "psql -d rently_lending -t -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('collections_event', 'loan_status_history');\"" \
    "2"

# Test 4: Materialized Views
run_verification_test "Materialized Views Check" \
    "psql -d rently_lending -t -c \"SELECT COUNT(*) FROM mv_current_loan_status;\"" \
    "[0-9]+"

# Test 5: Data Integrity
run_verification_test "Data Integrity Check" \
    "psql -d rently_lending -t -c \"SELECT COUNT(*) FROM (SELECT 1 FROM payment p JOIN payment_allocation pa ON p.id = pa.payment_id WHERE p.status = 'completed' GROUP BY p.id, p.amount HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01) violations;\"" \
    "0"

# Test 6: Performance Test
run_verification_test "Performance Test" \
    "timeout 10s psql -d rently_lending -c \"SELECT COUNT(*) FROM v_loan_portfolio_overview;\" > /dev/null 2>&1 && echo 'Performance OK'" \
    "Performance OK"

# Test 7: Monitoring Functions
run_verification_test "Monitoring Functions Check" \
    "psql -d rently_lending -t -c \"SELECT 'OK' FROM check_system_alerts() LIMIT 1;\"" \
    "OK"

echo "Post-deployment verification completed: $VERIFICATION_ID" | tee -a "$RESULTS_FILE"
echo "Results saved to: $RESULTS_FILE"
```

### Application Integration Testing
```bash
#!/bin/bash
# application_integration_tests.sh
# Test application connectivity after deployment

echo "Running application integration tests..."

# Test API endpoints (example)
API_BASE_URL="https://api.rently.internal"
API_TOKEN="your-api-token"

# Test 1: Health Check Endpoint
echo "Testing API health check..."
response=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL/health")
if [[ "$response" -eq 200 ]]; then
    echo "✓ API health check passed"
else
    echo "✗ API health check failed: HTTP $response"
fi

# Test 2: Database-dependent endpoint
echo "Testing database-dependent endpoint..."
response=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
    "$API_BASE_URL/api/v1/loans/count" | jq -r '.count')
if [[ "$response" =~ ^[0-9]+$ ]]; then
    echo "✓ Database connectivity through API confirmed: $response loans"
else
    echo "✗ Database connectivity through API failed"
fi

# Test 3: New functionality endpoint
echo "Testing new collections endpoint..."
response=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
    "$API_BASE_URL/api/v1/collections/summary" | jq -r '.status')
if [[ "$response" == "success" ]]; then
    echo "✓ New collections endpoint working"
else
    echo "✗ New collections endpoint failed"
fi

echo "Application integration tests completed"
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Migration Timeout
**Symptoms**: Migration scripts timeout during execution
**Causes**: Large dataset, insufficient resources, blocking locks
**Solutions**:
```bash
# Check for blocking processes
psql -d rently_lending -c "
SELECT 
    pid, 
    usename, 
    application_name, 
    state, 
    query_start,
    LEFT(query, 50) as query_preview
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY query_start;
"

# Terminate blocking processes (if safe)
psql -d rently_lending -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle in transaction' 
  AND query_start < NOW() - INTERVAL '30 minutes';
"

# Increase statement timeout for migration
psql -d rently_lending -c "SET statement_timeout = '60min';"
```

#### Issue 2: Index Creation Failure
**Symptoms**: Index creation fails or takes excessive time
**Causes**: Large tables, concurrent operations, insufficient space
**Solutions**:
```sql
-- Check index creation progress
SELECT 
    p.pid,
    p.datname,
    p.usename,
    p.application_name,
    p.state,
    p.query_start,
    EXTRACT(seconds FROM now() - p.query_start) as duration_seconds,
    LEFT(p.query, 100) as query_preview
FROM pg_stat_activity p
WHERE p.query LIKE '%CREATE INDEX%'
   OR p.query LIKE '%REINDEX%';

-- Create indexes with specific settings
SET maintenance_work_mem = '2GB';
SET max_parallel_maintenance_workers = 4;
CREATE INDEX CONCURRENTLY idx_name ON table_name (column_name);
```

#### Issue 3: Materialized View Refresh Failures
**Symptoms**: Materialized view refresh fails or produces errors
**Causes**: Data inconsistencies, concurrent modifications, resource constraints
**Solutions**:
```sql
-- Check materialized view status
SELECT 
    schemaname,
    matviewname,
    ispopulated,
    pg_size_pretty(pg_total_relation_size(matviewname::regclass)) as size
FROM pg_matviews;

-- Refresh with specific approach
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_loan_status;

-- If concurrent refresh fails, use standard refresh
REFRESH MATERIALIZED VIEW mv_current_loan_status;

-- Check for underlying data issues
SELECT * FROM mv_current_loan_status LIMIT 10;
```

#### Issue 4: Performance Degradation
**Symptoms**: Queries slower after deployment
**Causes**: Missing indexes, outdated statistics, configuration issues
**Solutions**:
```sql
-- Update table statistics
ANALYZE loan, payment, payment_allocation, collections_event;

-- Check query plans
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM v_loan_portfolio_overview LIMIT 100;

-- Check for missing indexes
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    ROUND(100.0 * seq_scan / NULLIF(seq_scan + idx_scan, 0), 2) as seq_scan_pct
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan
ORDER BY seq_scan DESC;
```

#### Issue 5: Connection Pool Exhaustion
**Symptoms**: Applications cannot connect to database
**Causes**: Connection pool misconfiguration, connection leaks
**Solutions**:
```bash
# Check PgBouncer status
psql -h $PGBOUNCER_HOST -p $PGBOUNCER_PORT -d pgbouncer -c "SHOW POOLS;"
psql -h $PGBOUNCER_HOST -p $PGBOUNCER_PORT -d pgbouncer -c "SHOW CLIENTS;"

# Restart PgBouncer if needed
sudo systemctl restart pgbouncer

# Check for connection leaks in application
psql -d rently_lending -c "
SELECT 
    application_name,
    state,
    COUNT(*) as connection_count
FROM pg_stat_activity
WHERE application_name != 'psql'
GROUP BY application_name, state
ORDER BY connection_count DESC;
"
```

### Emergency Response Procedures

#### Procedure 1: Complete System Failure
```bash
#!/bin/bash
# emergency_recovery.sh
# Complete system recovery procedure

echo "EMERGENCY: Starting complete system recovery"

# 1. Check system resources
df -h
free -m
top -bn1 | head -20

# 2. Check database process
if ! pgrep -x postgres >/dev/null; then
    echo "PostgreSQL is not running - attempting start"
    sudo systemctl start postgresql
    sleep 10
fi

# 3. Test basic connectivity
if pg_isready -h "$PGHOST" -p "$PGPORT" -d "$PGDATABASE"; then
    echo "Database is responding"
else
    echo "Database is not responding - initiating emergency rollback"
    /opt/rently-deployment/scripts/emergency_rollback.sh
fi

# 4. Check data integrity
psql -d rently_lending -c "
SELECT 'loan_count:' || COUNT(*) FROM loan;
SELECT 'payment_count:' || COUNT(*) FROM payment;
"

echo "Emergency recovery procedure completed"
```

#### Procedure 2: Data Corruption Detection
```sql
-- emergency_data_validation.sql
-- Quick data corruption detection

DO $$
DECLARE
    corruption_found BOOLEAN := FALSE;
    error_count INTEGER;
BEGIN
    RAISE NOTICE 'Starting emergency data validation...';
    
    -- Check 1: Orphaned payment allocations
    SELECT COUNT(*) INTO error_count
    FROM payment_allocation pa
    LEFT JOIN payment p ON pa.payment_id = p.id
    WHERE p.id IS NULL;
    
    IF error_count > 0 THEN
        RAISE WARNING 'Found % orphaned payment allocations', error_count;
        corruption_found := TRUE;
    END IF;
    
    -- Check 2: Payment allocation imbalances
    SELECT COUNT(*) INTO error_count
    FROM (
        SELECT p.id
        FROM payment p
        JOIN payment_allocation pa ON p.id = pa.payment_id
        WHERE p.status = 'completed'
        GROUP BY p.id, p.amount
        HAVING ABS(p.amount - SUM(pa.allocated_amount)) > 0.01
    ) imbalances;
    
    IF error_count > 0 THEN
        RAISE WARNING 'Found % payment allocation imbalances', error_count;
        corruption_found := TRUE;
    END IF;
    
    -- Check 3: Invalid loan statuses
    SELECT COUNT(*) INTO error_count
    FROM loan
    WHERE status NOT IN ('active', 'closed', 'written_off', 'pending');
    
    IF error_count > 0 THEN
        RAISE WARNING 'Found % invalid loan statuses', error_count;
        corruption_found := TRUE;
    END IF;
    
    IF corruption_found THEN
        -- Log critical error
        INSERT INTO deployment_log (deployment_id, stage, status, details, created_at)
        VALUES (
            'EMERGENCY_VALIDATION_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'),
            'DATA_CORRUPTION_CHECK',
            'CRITICAL_ERRORS_FOUND',
            'Data corruption detected - manual intervention required',
            NOW()
        );
        
        RAISE EXCEPTION 'CRITICAL: Data corruption detected - initiate emergency procedures';
    ELSE
        RAISE NOTICE 'No data corruption detected';
    END IF;
END $$;
```

## Emergency Procedures

### 24/7 On-Call Response

#### Escalation Matrix
```
Level 1 (0-15 minutes): DevOps Engineer
- Database connectivity issues
- Performance degradation
- Standard error alerts

Level 2 (15-60 minutes): Senior Database Administrator
- Data integrity issues
- Schema corruption
- Migration failures

Level 3 (60+ minutes): Technical Lead + CTO
- Complete system failure
- Data loss scenarios
- Security breaches
```

#### Emergency Contacts
```yaml
Primary On-Call:
  DevOps Engineer: +1-xxx-xxx-xxxx
  Database Administrator: +1-xxx-xxx-xxxx
  
Secondary Escalation:
  Technical Lead: +1-xxx-xxx-xxxx
  CTO: +1-xxx-xxx-xxxx
  
External Support:
  AWS Support: Case Priority HIGH
  PostgreSQL Support: Enterprise Contract
```

#### Critical Response Procedures

##### Procedure 1: Immediate Response Checklist
```bash
# immediate_response.sh
# First response to critical alerts

echo "CRITICAL ALERT RESPONSE INITIATED"

# 1. Acknowledge alert and gather basic info
echo "Timestamp: $(date)"
echo "Responding to: $ALERT_TYPE"
echo "Alert Level: $ALERT_LEVEL"

# 2. Quick system assessment
echo "=== SYSTEM STATUS ==="
pg_isready -h "$PGHOST" -p "$PGPORT" -d "$PGDATABASE" && echo "DB: UP" || echo "DB: DOWN"
curl -s "$API_BASE_URL/health" >/dev/null && echo "API: UP" || echo "API: DOWN"
df -h | grep -E '9[0-9]%|100%' && echo "DISK: CRITICAL" || echo "DISK: OK"

# 3. Check recent deployment log
psql -d rently_lending -c "
SELECT deployment_id, stage, status, details, created_at
FROM deployment_log
ORDER BY created_at DESC
LIMIT 5;
"

# 4. Capture current state
/opt/rently-deployment/scripts/capture_system_state.sh

echo "Immediate response completed - escalating to next level"
```

##### Procedure 2: System State Capture
```bash
#!/bin/bash
# capture_system_state.sh
# Capture comprehensive system state for analysis

STATE_DIR="/opt/rently-deployment/logs/system_state_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$STATE_DIR"

echo "Capturing system state to: $STATE_DIR"

# Database state
psql -d rently_lending -c "\l" > "$STATE_DIR/databases.txt"
psql -d rently_lending -c "\dt" > "$STATE_DIR/tables.txt"
psql -d rently_lending -c "SELECT * FROM pg_stat_activity;" > "$STATE_DIR/active_connections.txt"
psql -d rently_lending -c "SELECT * FROM check_system_alerts();" > "$STATE_DIR/system_alerts.txt"

# System resources
top -bn1 > "$STATE_DIR/system_processes.txt"
df -h > "$STATE_DIR/disk_usage.txt"
free -m > "$STATE_DIR/memory_usage.txt"
netstat -tuln > "$STATE_DIR/network_connections.txt"

# Application logs (last 1000 lines)
tail -1000 /var/log/rently-app/application.log > "$STATE_DIR/application_logs.txt" 2>/dev/null || echo "No app logs found"
tail -1000 /var/log/postgresql/postgresql.log > "$STATE_DIR/postgresql_logs.txt" 2>/dev/null || echo "No PG logs found"

# Recent deployment activity
psql -d rently_lending -c "
SELECT * FROM deployment_log 
WHERE created_at >= NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;
" > "$STATE_DIR/recent_deployments.txt"

echo "System state captured in: $STATE_DIR"
```

### Communication Templates

#### Internal Alert Notification
```
SUBJECT: [CRITICAL] Rently Database Alert - {ALERT_TYPE}

Alert Level: {ALERT_LEVEL}
Timestamp: {TIMESTAMP}
System: Rently Lending Platform Database
Alert Type: {ALERT_TYPE}
Message: {ALERT_MESSAGE}

Initial Response:
- On-call engineer notified
- System state captured
- Investigation in progress

Next Steps:
- Root cause analysis
- Remediation plan development
- Stakeholder notification (if customer impact)

Response Team:
- Primary: {ON_CALL_ENGINEER}
- Secondary: {BACKUP_ENGINEER}
- Escalation: {TECHNICAL_LEAD}

Status Updates: Every 15 minutes until resolved
```

#### Customer Communication Template
```
SUBJECT: Service Advisory - Rently Platform

Dear Rently Users,

We are currently investigating a technical issue that may affect 
platform performance. Our engineering team is actively working 
to resolve this issue.

Current Status:
- Issue identified: {TIMESTAMP}
- Impact: {IMPACT_DESCRIPTION}
- Expected Resolution: {ETA}

We will provide updates every 30 minutes until the issue is 
resolved. Thank you for your patience.

The Rently Engineering Team
```

---

This deployment guide provides comprehensive procedures for safely deploying and maintaining the Rently lending platform data enhancements. The guide emphasizes data integrity, thorough testing, and robust monitoring to ensure the reliability required for financial services operations.

**Key Success Factors:**
- Follow all procedures in sequence
- Never skip validation steps
- Maintain comprehensive logging
- Test rollback procedures before deployment
- Monitor system health continuously

**Document Information:**
- **Version**: 1.0
- **Last Updated**: December 2024
- **Next Review**: March 2025
- **Owner**: DevOps & Database Administration Team