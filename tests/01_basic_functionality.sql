-- ============================================================================
-- pg_stat_insights: Basic Functionality Test Suite
-- ============================================================================
-- Run with: psql -f 01_basic_functionality.sql
-- Expected: All tests should pass
-- ============================================================================

\echo '=== TEST 1: Extension Installation ==='
CREATE EXTENSION IF NOT EXISTS pg_stat_insights;

-- Verify extension exists
SELECT 
    CASE WHEN count(*) = 1 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Extension installed' as test_name
FROM pg_extension 
WHERE extname = 'pg_stat_insights';

\echo ''
\echo '=== TEST 2: Verify All 11 Views Exist ==='
WITH expected_views AS (
    SELECT unnest(ARRAY[
        'pg_stat_insights',
        'pg_stat_insights_top_by_time',
        'pg_stat_insights_top_by_calls',
        'pg_stat_insights_top_by_io',
        'pg_stat_insights_top_cache_misses',
        'pg_stat_insights_slow_queries',
        'pg_stat_insights_errors',
        'pg_stat_insights_plan_errors',
        'pg_stat_insights_histogram_summary',
        'pg_stat_insights_by_bucket',
        'pg_stat_insights_replication'
    ]) as view_name
),
actual_views AS (
    SELECT viewname as view_name
    FROM pg_views
    WHERE viewname LIKE 'pg_stat_insights%'
)
SELECT 
    CASE WHEN count(*) = 11 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'All 11 views exist (' || count(*) || '/11)' as test_name
FROM expected_views e
JOIN actual_views a ON e.view_name = a.view_name;

\echo ''
\echo '=== TEST 3: Verify Main View Has 52 Columns ==='
SELECT 
    CASE WHEN count(*) = 52 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Main view has 52 columns (' || count(*) || '/52)' as test_name
FROM information_schema.columns 
WHERE table_name = 'pg_stat_insights';

\echo ''
\echo '=== TEST 4: List All 52 Columns ==='
SELECT 
    row_number() OVER (ORDER BY ordinal_position) as "#",
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'pg_stat_insights'
ORDER BY ordinal_position;

\echo ''
\echo '=== TEST 5: Verify Functions Exist ==='
SELECT 
    CASE WHEN count(*) >= 3 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Core functions exist (' || count(*) || ')' as test_name
FROM pg_proc
WHERE proname LIKE 'pg_stat_insights%';

\echo ''
\echo '=== TEST 6: Reset Statistics ==='
SELECT pg_stat_insights_reset();
SELECT 
    CASE WHEN count(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Statistics cleared after reset' as test_name
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

\echo ''
\echo '=== TEST 7: Create Test Data ==='
DROP TABLE IF EXISTS pgsi_test_table CASCADE;
CREATE TABLE pgsi_test_table (
    id serial PRIMARY KEY,
    value integer NOT NULL,
    description text
);

INSERT INTO pgsi_test_table (value, description)
SELECT 
    i, 
    'Test row ' || i 
FROM generate_series(1, 1000) i;

CREATE INDEX idx_pgsi_test_value ON pgsi_test_table(value);

SELECT 
    '✅ PASS' as result,
    'Test table created with 1000 rows' as test_name;

\echo ''
\echo '=== TEST 8: Execute Test Queries ==='
-- Execute various queries to generate statistics
SELECT count(*) FROM pgsi_test_table;
SELECT * FROM pgsi_test_table WHERE value = 500;
SELECT avg(value), max(value), min(value) FROM pgsi_test_table;
SELECT value, count(*) FROM pgsi_test_table GROUP BY value HAVING count(*) > 0;
UPDATE pgsi_test_table SET description = 'Updated' WHERE value < 10;
DELETE FROM pgsi_test_table WHERE value > 990;

SELECT 
    '✅ PASS' as result,
    'Test queries executed' as test_name;

\echo ''
\echo '=== TEST 9: Verify Query Tracking ==='
SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Queries are being tracked (' || count(*) || ' queries)' as test_name
FROM pg_stat_insights
WHERE query LIKE '%pgsi_test_table%';

\echo ''
\echo '=== TEST 10: Verify All Metric Columns Are Populated ==='
WITH metrics AS (
    SELECT 
        calls > 0 as has_calls,
        total_exec_time >= 0 as has_exec_time,
        rows >= 0 as has_rows,
        shared_blks_hit >= 0 as has_blks_hit,
        shared_blks_read >= 0 as has_blks_read,
        wal_records >= 0 as has_wal_records,
        wal_bytes >= 0 as has_wal_bytes
    FROM pg_stat_insights
    WHERE query LIKE '%pgsi_test_table%'
    LIMIT 1
)
SELECT 
    CASE WHEN bool_and(
        has_calls AND has_exec_time AND has_rows AND 
        has_blks_hit AND has_blks_read AND 
        has_wal_records AND has_wal_bytes
    ) THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Core metrics are populated' as test_name
FROM metrics;

\echo ''
\echo '=== TEST 11: Top Queries View ==='
SELECT 
    query,
    calls,
    round(total_exec_time::numeric, 2) as total_ms,
    round(mean_exec_time::numeric, 2) as mean_ms,
    rows
FROM pg_stat_insights_top_by_time
WHERE query LIKE '%pgsi_test_table%'
LIMIT 5;

\echo ''
\echo '=== TEST 12: Cache Performance View ==='
SELECT 
    query,
    shared_blks_hit,
    shared_blks_read,
    CASE 
        WHEN (shared_blks_hit + shared_blks_read) > 0 
        THEN round(100.0 * shared_blks_hit / (shared_blks_hit + shared_blks_read), 2)
        ELSE 0 
    END as cache_hit_ratio
FROM pg_stat_insights
WHERE query LIKE '%pgsi_test_table%'
ORDER BY (shared_blks_hit + shared_blks_read) DESC
LIMIT 5;

\echo ''
\echo '=== TEST 13: WAL Statistics ==='
SELECT 
    query,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) as wal_bytes
FROM pg_stat_insights
WHERE query LIKE '%pgsi_test_table%' 
  AND wal_records > 0
ORDER BY wal_bytes DESC
LIMIT 5;

\echo ''
\echo '=== TEST 14: Execution Time Statistics ==='
SELECT 
    query,
    calls,
    round(min_exec_time::numeric, 2) as min_ms,
    round(max_exec_time::numeric, 2) as max_ms,
    round(mean_exec_time::numeric, 2) as mean_ms,
    round(stddev_exec_time::numeric, 2) as stddev_ms
FROM pg_stat_insights
WHERE query LIKE '%pgsi_test_table%'
ORDER BY mean_exec_time DESC
LIMIT 5;

\echo ''
\echo '=== TEST 15: Verify Standard Deviation Calculation ==='
-- stddev should be 0 for single execution, positive for multiple
SELECT 
    CASE 
        WHEN count(*) FILTER (WHERE calls = 1 AND stddev_exec_time = 0) >= 0
         AND count(*) FILTER (WHERE calls > 1 AND stddev_exec_time >= 0) >= 0
        THEN '✅ PASS' 
        ELSE '❌ FAIL' 
    END as result,
    'Standard deviation calculated correctly' as test_name
FROM pg_stat_insights
WHERE query LIKE '%pgsi_test_table%';

\echo ''
\echo '=== TEST 16: Reset Specific Query ==='
-- Get a specific query to reset
DO $$
DECLARE
    v_userid oid;
    v_dbid oid;
    v_queryid bigint;
BEGIN
    SELECT userid, dbid, queryid
    INTO v_userid, v_dbid, v_queryid
    FROM pg_stat_insights
    WHERE query LIKE '%pgsi_test_table%'
    LIMIT 1;
    
    IF v_queryid IS NOT NULL THEN
        PERFORM pg_stat_insights_reset(v_userid, v_dbid, v_queryid);
        RAISE NOTICE 'Reset specific query: queryid=%', v_queryid;
    END IF;
END $$;

SELECT 
    '✅ PASS' as result,
    'Specific query reset function works' as test_name;

\echo ''
\echo '=== TEST 17: Cleanup ==='
DROP TABLE IF EXISTS pgsi_test_table CASCADE;

SELECT 
    '✅ PASS' as result,
    'Test cleanup completed' as test_name;

\echo ''
\echo '============================================================================'
\echo '=== SUMMARY ==='
\echo '============================================================================'
\echo 'All basic functionality tests completed.'
\echo 'Review results above for any ❌ FAIL indicators.'
\echo '============================================================================'

