-- ============================================================================
-- Test 2: Basic Query Tracking
-- Tests that queries are tracked and statistics are collected
-- ============================================================================

-- Reset statistics to start fresh
SELECT pg_stat_insights_reset();

-- Execute some test queries
CREATE TEMP TABLE test_table (id int, name text, value numeric);
INSERT INTO test_table VALUES (1, 'test1', 100.5);
INSERT INTO test_table VALUES (2, 'test2', 200.75);
INSERT INTO test_table VALUES (3, 'test3', 300.25);

-- Simple SELECT
SELECT * FROM test_table WHERE id = 1;

-- Aggregation
SELECT COUNT(*), SUM(value), AVG(value) FROM test_table;

-- Join (self-join)
SELECT a.id, a.name, b.value 
FROM test_table a 
JOIN test_table b ON a.id = b.id 
WHERE a.id <= 2;

-- Wait a moment for stats to be collected
SELECT pg_sleep(0.1);

-- Verify that queries are being tracked
SELECT COUNT(*) > 0 AS queries_tracked FROM pg_stat_insights;

-- Check that we have execution statistics
SELECT 
  COUNT(*) FILTER (WHERE calls > 0) AS queries_with_calls,
  COUNT(*) FILTER (WHERE total_exec_time > 0) AS queries_with_time,
  COUNT(*) FILTER (WHERE rows >= 0) AS queries_with_rows
FROM pg_stat_insights;

-- Verify basic statistics are reasonable
SELECT 
  calls >= 1 AS has_calls,
  total_exec_time >= 0 AS has_exec_time,
  mean_exec_time >= 0 AS has_mean_time,
  min_exec_time >= 0 AS has_min_time,
  max_exec_time >= min_exec_time AS max_gte_min
FROM pg_stat_insights
WHERE query LIKE '%test_table%'
LIMIT 1;

