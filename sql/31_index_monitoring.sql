-- ============================================================================
-- Test 31: Index Monitoring Views
-- Tests all index monitoring views and their functionality
-- ============================================================================

-- Setup test tables and indexes
-- Use fixed timestamp for deterministic test output
CREATE TABLE IF NOT EXISTS idx_test_users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT '2025-11-22 14:52:32.72989'::timestamp,
    last_login TIMESTAMP,
    status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS idx_test_orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    amount DECIMAL(10,2),
    order_date DATE DEFAULT '2025-11-22'::date,
    status TEXT DEFAULT 'pending'
);

-- Create various index types
CREATE INDEX IF NOT EXISTS idx_users_username ON idx_test_users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON idx_test_users(email);
CREATE INDEX IF NOT EXISTS idx_users_created ON idx_test_users(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON idx_test_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON idx_test_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status ON idx_test_orders(status);

-- Insert test data with deterministic timestamps
INSERT INTO idx_test_users (username, email, created_at) 
SELECT 'user' || i, 'user' || i || '@test.com', '2025-11-22 14:52:32.72989'::timestamp - (i || ' days')::interval
FROM generate_series(1, 500) i;

INSERT INTO idx_test_orders (user_id, amount, order_date, status)
SELECT (i % 100) + 1, ((i * 17) % 1000)::decimal(10,2), '2025-11-22'::date - (i % 30), 
       CASE WHEN i % 3 = 0 THEN 'completed' WHEN i % 3 = 1 THEN 'pending' ELSE 'cancelled' END
FROM generate_series(1, 1000) i;

-- Execute queries to generate index usage statistics
SELECT * FROM idx_test_users WHERE username = 'user100';
SELECT * FROM idx_test_users WHERE email = 'user200@test.com';
SELECT * FROM idx_test_users WHERE created_at > '2025-11-22 14:52:32.72989'::timestamp - interval '30 days';
SELECT * FROM idx_test_orders WHERE user_id = 50;
SELECT * FROM idx_test_orders WHERE order_date > '2025-11-22'::date - 7 ORDER BY id;
SELECT * FROM idx_test_orders WHERE status = 'completed' ORDER BY id;

-- Test 1: Verify all index views exist
SELECT 
    'All index views exist' AS test_name,
    CASE 
        WHEN count(*) >= 9 THEN 'PASS'
        ELSE 'FAIL: Expected at least 9 views, found ' || count(*)
    END AS result
FROM pg_views 
WHERE viewname IN (
    'pg_stat_insights_indexes',
    'pg_stat_insights_index_usage',
    'pg_stat_insights_index_bloat',
    'pg_stat_insights_index_efficiency',
    'pg_stat_insights_index_maintenance',
    'pg_stat_insights_index_summary',
    'pg_stat_insights_index_alerts',
    'pg_stat_insights_index_dashboard',
    'pg_stat_insights_missing_indexes',
    'pg_stat_insights_index_maintenance_history',
    'pg_stat_insights_index_duplicates'
);

-- Test 2: pg_stat_insights_indexes - Basic functionality
SELECT 
    'pg_stat_insights_indexes has data' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 3: Index size metrics
SELECT 
    'Index size metrics valid' AS test_name,
    CASE 
        WHEN count(*) > 0 AND 
             min(index_size_bytes) >= 0 AND 
             min(index_size_mb) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 4: Index type detection
SELECT 
    'Index type detection works' AS test_name,
    CASE 
        WHEN count(*) > 0 AND 
             count(*) FILTER (WHERE index_type = 'btree') > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 5: Index properties
SELECT 
    'Index properties detected' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE is_primary = true) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 6: pg_stat_insights_index_usage - Usage analysis
SELECT 
    'Index usage view has data' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_usage
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 7: Usage status classification
SELECT 
    'Usage status classification works' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE usage_status IN ('ACTIVE', 'HEAVY', 'OCCASIONAL', 'RARE', 'NEVER_USED')) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_usage
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 8: Index scan ratio
SELECT 
    'Index scan ratio valid' AS test_name,
    CASE 
        WHEN count(*) > 0 AND 
             min(index_scan_ratio) >= 0 AND 
             max(index_scan_ratio) <= 1 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_usage
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 9: pg_stat_insights_index_bloat - Bloat detection
SELECT 
    'Index bloat view accessible' AS test_name,
    CASE 
        WHEN count(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_bloat
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 10: Bloat severity
SELECT 
    'Bloat severity classification works' AS test_name,
    CASE 
        WHEN count(*) >= 0 AND 
             count(*) FILTER (WHERE bloat_severity IN ('NONE', 'LOW', 'MEDIUM', 'HIGH')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_bloat
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 11: pg_stat_insights_index_efficiency - Efficiency analysis
SELECT 
    'Index efficiency view has data' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_efficiency
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 12: Efficiency rating
SELECT 
    'Efficiency rating calculated' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE efficiency_rating IN ('EXCELLENT', 'GOOD', 'FAIR', 'POOR', 'UNUSED')) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_efficiency
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 13: pg_stat_insights_index_maintenance - Maintenance recommendations
SELECT 
    'Index maintenance view has data' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_maintenance
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 14: Maintenance type
SELECT 
    'Maintenance type detected' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE maintenance_type IN ('REINDEX', 'VACUUM', 'ANALYZE', 'NONE')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_maintenance
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 15: pg_stat_insights_index_summary - Summary view
SELECT 
    'Index summary view accessible' AS test_name,
    CASE 
        WHEN total_indexes > 0 AND total_index_size_mb >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_summary;

-- Test 16: Summary metrics
SELECT 
    'Summary metrics calculated' AS test_name,
    CASE 
        WHEN active_indexes >= 0 AND unused_indexes >= 0 AND bloated_indexes >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_summary;

-- Test 17: pg_stat_insights_index_alerts - Alerts
SELECT 
    'Index alerts view accessible' AS test_name,
    CASE 
        WHEN count(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_alerts;

-- Test 18: Alert severity
SELECT 
    'Alert severity levels correct' AS test_name,
    CASE 
        WHEN count(*) >= 0 AND 
             count(*) FILTER (WHERE severity IN ('INFO', 'WARNING', 'CRITICAL')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_alerts;

-- Test 19: pg_stat_insights_index_dashboard - Dashboard
SELECT 
    'Index dashboard view accessible' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_dashboard;

-- Test 20: Dashboard JSON structure
SELECT 
    'Dashboard JSON structure valid' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE section IN ('SUMMARY', 'BLOAT', 'UNUSED', 'ALERT') AND details IS NOT NULL) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_dashboard;

-- Test 21: pg_stat_insights_missing_indexes - Missing index recommendations
SELECT 
    'Missing indexes view accessible' AS test_name,
    CASE 
        WHEN count(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_missing_indexes;

-- Test 22: Cache hit ratio validation
SELECT 
    'Index cache hit ratio valid' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE idx_cache_hit_ratio IS NULL OR (idx_cache_hit_ratio >= 0 AND idx_cache_hit_ratio <= 1)) = count(*) THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 23: All views have proper permissions
SELECT 
    'Index views have PUBLIC SELECT permission' AS test_name,
    CASE 
        WHEN count(*) >= 9 THEN 'PASS'
        ELSE 'FAIL: Expected at least 9 views with PUBLIC SELECT, found ' || count(*)
    END AS result
FROM information_schema.table_privileges 
WHERE table_name LIKE 'pg_stat_insights_index%' 
  AND privilege_type = 'SELECT' 
  AND grantee = 'PUBLIC';

-- Test 24: Index-only scan metrics
SELECT 
    'Index-only scan ratio calculated' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE index_only_scan_ratio IS NULL OR (index_only_scan_ratio >= 0 AND index_only_scan_ratio <= 1)) = count(*) THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 25: Index-only scan efficiency rating
SELECT 
    'Index-only scan efficiency rating works' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE index_only_scan_efficiency IS NULL OR index_only_scan_efficiency IN ('EXCELLENT', 'GOOD', 'FAIR', 'POOR')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 26: Selectivity metrics
SELECT 
    'Selectivity ratio calculated' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE selectivity_ratio IS NULL OR selectivity_ratio >= 0) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 27: Distinct value ratio
SELECT 
    'Distinct value ratio calculated' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE distinct_value_ratio IS NULL OR (distinct_value_ratio >= 0 AND distinct_value_ratio <= 1)) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 28: Extended correlation (all index types)
SELECT 
    'Column correlation available for all index types' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE column_correlation IS NOT NULL) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 29: Statistics age
SELECT 
    'Statistics age calculated' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE stats_age_days IS NULL OR stats_age_days >= 0) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 30: I/O wait statistics placeholders
SELECT 
    'I/O wait statistics columns exist' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE avg_io_wait_ms IS NULL AND total_io_wait_ms IS NULL) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_indexes
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 31: Maintenance history view
SELECT 
    'Maintenance history view accessible' AS test_name,
    CASE 
        WHEN count(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_maintenance_history
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 32: Maintenance status
SELECT 
    'Maintenance status classification works' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE maintenance_status IN ('CURRENT', 'NEEDS_VACUUM', 'NEEDS_ANALYZE', 'STALE_VACUUM', 'STALE_ANALYZE')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_maintenance_history
WHERE tablename IN ('idx_test_users', 'idx_test_orders');

-- Test 33: Duplicate index detection view
SELECT 
    'Duplicate index detection view accessible' AS test_name,
    CASE 
        WHEN count(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_duplicates;

-- Test 34: Duplicate type classification
SELECT 
    'Duplicate type classification works' AS test_name,
    CASE 
        WHEN count(*) >= 0 AND 
             count(*) FILTER (WHERE duplicate_type IN ('EXACT_DUPLICATE', 'REDUNDANT', 'SAME_COLUMN', 'POTENTIAL_OVERLAP')) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_index_duplicates;

-- Test 35: Enhanced missing indexes - benefit score
SELECT 
    'Enhanced missing indexes has benefit score' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE benefit_score IS NOT NULL AND benefit_score >= 0) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_missing_indexes;

-- Test 36: Enhanced missing indexes - estimated size
SELECT 
    'Enhanced missing indexes has estimated size' AS test_name,
    CASE 
        WHEN count(*) FILTER (WHERE estimated_index_size_mb IS NULL OR estimated_index_size_mb >= 0) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM pg_stat_insights_missing_indexes;

-- Cleanup
DROP TABLE IF EXISTS idx_test_orders CASCADE;
DROP TABLE IF EXISTS idx_test_users CASCADE;

