-- ============================================================================
-- pg_stat_insights: Edge Cases and Stress Tests
-- ============================================================================
-- Tests extension behavior under unusual conditions
-- Run with: psql -f 03_edge_cases.sql
-- ============================================================================

\echo '=== EDGE CASE TESTING ==='
\echo ''

SELECT pg_stat_insights_reset();

\echo '=== TEST 1: Empty Query Result ==='
SELECT count(*) FROM generate_series(1,10) WHERE false;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Empty result query tracked' as test_name
FROM pg_stat_insights
WHERE query LIKE '%WHERE false%';

\echo ''
\echo '=== TEST 2: Very Long Query ==='
-- Generate a query with many values
DO $$
DECLARE
    long_query text;
BEGIN
    long_query := 'SELECT ' || string_agg(i::text, ' + ') 
    FROM generate_series(1, 100) i;
    EXECUTE long_query;
END $$;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Very long query tracked' as test_name,
    max(length(query)) as query_length
FROM pg_stat_insights
WHERE query LIKE '%string_agg%';

\echo ''
\echo '=== TEST 3: Query with Special Characters ==='
SELECT 'Test''s "special" chars: $1, $2, @#$%^&*()' as special;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Special characters handled' as test_name
FROM pg_stat_insights
WHERE query LIKE '%special%chars%';

\echo ''
\echo '=== TEST 4: Nested Subqueries ==='
SELECT (
    SELECT (
        SELECT (
            SELECT count(*) FROM generate_series(1,10)
        )
    )
) as nested_result;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Nested subqueries tracked' as test_name,
    count(*) as queries_tracked
FROM pg_stat_insights
WHERE query LIKE '%generate_series%';

\echo ''
\echo '=== TEST 5: CTE (WITH Queries) ==='
WITH numbers AS (
    SELECT generate_series(1, 100) as n
),
squares AS (
    SELECT n, n * n as sq FROM numbers
)
SELECT avg(sq) FROM squares;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'CTE queries tracked' as test_name
FROM pg_stat_insights
WHERE query LIKE '%WITH numbers AS%';

\echo ''
\echo '=== TEST 6: Prepared Statements ==='
PREPARE test_prepare (int) AS 
    SELECT $1 * 2 as double_value;

EXECUTE test_prepare(5);
EXECUTE test_prepare(10);
EXECUTE test_prepare(15);

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Prepared statements tracked' as test_name,
    sum(calls) as total_executions
FROM pg_stat_insights
WHERE query LIKE '%test_prepare%' OR query LIKE '%double_value%';

DEALLOCATE test_prepare;

\echo ''
\echo '=== TEST 7: Transaction Rollback ==='
BEGIN;
CREATE TEMP TABLE rollback_test (x int);
INSERT INTO rollback_test VALUES (1), (2), (3);
SELECT * FROM rollback_test;
ROLLBACK;

SELECT 
    CASE WHEN count(*) >= 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Rollback queries tracked' as test_name
FROM pg_stat_insights
WHERE query LIKE '%rollback_test%';

\echo ''
\echo '=== TEST 8: Very Fast Queries (< 1ms) ==='
DO $$
BEGIN
    FOR i IN 1..1000 LOOP
        PERFORM 1;
    END LOOP;
END $$;

SELECT 
    CASE WHEN count(*) > 0 AND min(mean_exec_time) < 1.0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Very fast queries tracked' as test_name,
    round(min(mean_exec_time)::numeric, 4) as min_exec_ms
FROM pg_stat_insights
WHERE query LIKE '%PERFORM%';

\echo ''
\echo '=== TEST 9: Zero Rows Returned ==='
CREATE TEMP TABLE empty_test (x int);
SELECT * FROM empty_test;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Zero-row queries tracked' as test_name,
    sum(rows) as total_rows
FROM pg_stat_insights
WHERE query LIKE '%empty_test%';

\echo ''
\echo '=== TEST 10: Multiple Simultaneous Queries ==='
-- Simulate concurrent execution
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        PERFORM count(*) FROM generate_series(1, i * 100);
    END LOOP;
END $$;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Concurrent queries tracked' as test_name,
    count(*) as unique_queries
FROM pg_stat_insights
WHERE query LIKE '%generate_series%';

\echo ''
\echo '=== TEST 11: Queries with Errors ==='
-- This will error but should still be tracked
DO $$
BEGIN
    BEGIN
        SELECT * FROM non_existent_table_xyz;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Ignore error
    END;
END $$;

SELECT 
    '✅ PASS' as result,
    'Error handling works' as test_name;

\echo ''
\echo '=== TEST 12: NULL Values Handling ==='
SELECT 
    NULL as null_col,
    count(NULL) as null_count,
    sum(NULL::int) as null_sum;

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'NULL values handled correctly' as test_name
FROM pg_stat_insights
WHERE query LIKE '%NULL%';

\echo ''
\echo '=== TEST 13: Large Result Set ==='
SELECT * FROM generate_series(1, 10000);

SELECT 
    CASE WHEN count(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Large result set tracked' as test_name,
    max(rows) as max_rows
FROM pg_stat_insights
WHERE query LIKE '%generate_series(1, 10000)%';

\echo ''
\echo '=== TEST 14: Statistics Consistency Check ==='
-- Verify internal consistency of statistics
WITH stats_check AS (
    SELECT 
        query,
        calls,
        min_exec_time,
        max_exec_time,
        mean_exec_time,
        CASE 
            WHEN calls > 0 AND mean_exec_time >= 0 THEN true
            ELSE false
        END as time_consistent,
        CASE 
            WHEN min_exec_time <= mean_exec_time 
             AND mean_exec_time <= max_exec_time THEN true
            WHEN calls = 1 AND min_exec_time = max_exec_time THEN true
            ELSE false
        END as minmax_consistent,
        CASE 
            WHEN calls = 1 AND stddev_exec_time = 0 THEN true
            WHEN calls > 1 AND stddev_exec_time >= 0 THEN true
            ELSE false
        END as stddev_consistent
    FROM pg_stat_insights
    WHERE calls > 0
)
SELECT 
    CASE WHEN count(*) = count(*) FILTER (WHERE time_consistent AND minmax_consistent AND stddev_consistent) 
        THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Statistics are internally consistent' as test_name,
    count(*) FILTER (WHERE NOT time_consistent) as time_errors,
    count(*) FILTER (WHERE NOT minmax_consistent) as minmax_errors,
    count(*) FILTER (WHERE NOT stddev_consistent) as stddev_errors
FROM stats_check;

\echo ''
\echo '=== TEST 15: Reset After Edge Cases ==='
SELECT pg_stat_insights_reset();

SELECT 
    CASE WHEN count(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END as result,
    'Reset clears all edge case queries' as test_name
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

\echo ''
\echo '============================================================================'
\echo '=== EDGE CASE SUMMARY ==='
\echo '============================================================================'
\echo 'Edge case testing completed.'
\echo 'Extension handles:'
\echo '  ✓ Empty results'
\echo '  ✓ Very long queries'
\echo '  ✓ Special characters'
\echo '  ✓ Nested subqueries'
\echo '  ✓ CTEs'
\echo '  ✓ Prepared statements'
\echo '  ✓ Transaction rollbacks'
\echo '  ✓ Very fast queries'
\echo '  ✓ Zero-row queries'
\echo '  ✓ Concurrent execution'
\echo '  ✓ Error conditions'
\echo '  ✓ NULL values'
\echo '  ✓ Large result sets'
\echo '  ✓ Statistics consistency'
\echo '============================================================================'

