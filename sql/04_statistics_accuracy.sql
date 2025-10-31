-- ============================================================================
-- Test 4: Statistics Accuracy
-- Tests that collected statistics are accurate and consistent
-- ============================================================================

-- Reset to ensure clean state
SELECT pg_stat_insights_reset();

-- Create test table
CREATE TEMP TABLE stats_test (id int, data text);

-- Insert exactly 50 rows
INSERT INTO stats_test SELECT i, 'data_' || i FROM generate_series(1, 50) i;

-- Execute a query multiple times (exactly 10 times)
DO $$
BEGIN
  FOR i IN 1..10 LOOP
    PERFORM COUNT(*) FROM stats_test;
  END LOOP;
END $$;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify call count
SELECT 
  query LIKE '%COUNT(*) FROM stats_test%' AS is_count_query,
  calls >= 10 AS has_expected_calls,
  calls AS actual_calls
FROM pg_stat_insights
WHERE query LIKE '%COUNT(*) FROM stats_test%'
LIMIT 1;

-- Test min/max/mean relationships
SELECT 
  min_exec_time <= mean_exec_time AS min_le_mean,
  mean_exec_time <= max_exec_time AS mean_le_max,
  min_exec_time <= max_exec_time AS min_le_max,
  min_exec_time > 0 AS min_positive,
  total_exec_time >= mean_exec_time * calls * 0.99 AS total_consistent
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Test standard deviation is non-negative
SELECT 
  stddev_exec_time >= 0 AS stddev_non_negative,
  stddev_plan_time >= 0 AS stddev_plan_non_negative
FROM pg_stat_insights
WHERE calls > 1
LIMIT 1;

-- Test row counts
SELECT 
  rows >= 0 AS rows_non_negative,
  calls > 0 AS has_calls
FROM pg_stat_insights
WHERE query LIKE '%generate_series%'
LIMIT 1;

-- Test statistical relationships with multiple executions
INSERT INTO stats_test SELECT i, 'data_' || i FROM generate_series(51, 100) i;

DO $$
BEGIN
  FOR i IN 1..5 LOOP
    PERFORM COUNT(*) FROM stats_test WHERE data LIKE 'data_5%';
  END LOOP;
END $$;

SELECT pg_sleep(0.1);

-- Verify aggregate statistics are correct
SELECT 
  calls >= 5 AS has_multiple_calls,
  min_exec_time <= mean_exec_time AS min_stats_valid,
  mean_exec_time <= max_exec_time AS max_stats_valid,
  stddev_exec_time >= 0 AS stddev_valid,
  (total_exec_time / NULLIF(calls, 0)) BETWEEN (mean_exec_time * 0.9) AND (mean_exec_time * 1.1) AS avg_consistent
FROM pg_stat_insights
WHERE query LIKE '%COUNT(*) FROM stats_test WHERE data LIKE%'
LIMIT 1;

-- Test cumulative statistics accuracy
SELECT 
  rows >= 0 AS rows_non_negative,
  total_exec_time >= 0 AS total_time_non_negative,
  mean_exec_time >= min_exec_time AS mean_ge_min,
  mean_exec_time <= max_exec_time AS mean_le_max
FROM pg_stat_insights
WHERE calls > 1
ORDER BY calls DESC
LIMIT 1;

