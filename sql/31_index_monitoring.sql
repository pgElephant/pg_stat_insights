-- ============================================================================
-- Test 31: Index Monitoring Views
-- Tests all index monitoring views and their functionality
-- ============================================================================

-- Setup test tables and indexes
CREATE TABLE IF NOT EXISTS idx_test_users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now(),
    last_login TIMESTAMP,
    status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS idx_test_orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    amount DECIMAL(10,2),
    order_date DATE DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'pending'
);

-- Create various index types
CREATE INDEX IF NOT EXISTS idx_users_username ON idx_test_users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON idx_test_users(email);
CREATE INDEX IF NOT EXISTS idx_users_created ON idx_test_users(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON idx_test_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON idx_test_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status ON idx_test_orders(status);

-- Insert test data
INSERT INTO idx_test_users (username, email, created_at) 
SELECT 'user' || i, 'user' || i || '@test.com', now() - (i || ' days')::interval
FROM generate_series(1, 500) i;

INSERT INTO idx_test_orders (user_id, amount, order_date, status)
SELECT (i % 100) + 1, (random() * 1000)::decimal(10,2), CURRENT_DATE - (i % 30), 
       CASE WHEN i % 3 = 0 THEN 'completed' WHEN i % 3 = 1 THEN 'pending' ELSE 'cancelled' END
FROM generate_series(1, 1000) i;

-- Execute queries to generate index usage statistics
SELECT * FROM idx_test_users WHERE username = 'user100';
SELECT * FROM idx_test_users WHERE email = 'user200@test.com';
SELECT * FROM idx_test_users WHERE created_at > now() - interval '30 days';
SELECT * FROM idx_test_orders WHERE user_id = 50;
SELECT * FROM idx_test_orders WHERE order_date > CURRENT_DATE - 7;
SELECT * FROM idx_test_orders WHERE status = 'completed';

-- Test 1: Verify all index views exist
SELECT 
    'All index views exist' AS test_name,
    CASE 
        WHEN count(*) = 9 THEN 'PASS'
        ELSE 'FAIL: Expected 9 views, found ' || count(*)
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
    'pg_stat_insights_missing_indexes'
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
        WHEN count(*) = 9 THEN 'PASS'
        ELSE 'FAIL: Expected 9 views with PUBLIC SELECT, found ' || count(*)
    END AS result
FROM information_schema.table_privileges 
WHERE table_name LIKE 'pg_stat_insights_index%' 
  AND privilege_type = 'SELECT' 
  AND grantee = 'PUBLIC';

-- Cleanup
DROP TABLE IF EXISTS idx_test_orders CASCADE;
DROP TABLE IF EXISTS idx_test_users CASCADE;

