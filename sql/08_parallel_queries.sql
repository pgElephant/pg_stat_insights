-- ============================================================================
-- Test 8: Parallel Query Tracking
-- Tests parallel worker statistics
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Enable parallel query (if possible)
SET max_parallel_workers_per_gather = 2;
SET parallel_setup_cost = 0;
SET parallel_tuple_cost = 0;
SET min_parallel_table_scan_size = 0;

-- Create table large enough to trigger parallel scan
SELECT setseed(0.5); -- Set seed for deterministic values
CREATE TEMP TABLE parallel_test AS
SELECT i, md5(i::text), i * 0.456 AS random
FROM generate_series(1, 10000) i;

-- Force parallel scan with aggregation
SELECT COUNT(*), SUM(random), AVG(random)
FROM parallel_test;

-- Wait for stats
SELECT pg_sleep(0.1);

-- Test parallel worker statistics
SELECT 
  parallel_workers_to_launch >= 0 AS workers_to_launch_valid,
  parallel_workers_launched >= 0 AS workers_launched_valid,
  parallel_workers_launched <= parallel_workers_to_launch AS workers_consistent
FROM pg_stat_insights
WHERE query LIKE '%parallel_test%' AND calls > 0
LIMIT 1;

-- Verify parallel stats exist
SELECT 
  COUNT(*) FILTER (WHERE parallel_workers_to_launch > 0) AS queries_planned_parallel,
  COUNT(*) FILTER (WHERE parallel_workers_launched > 0) AS queries_used_parallel
FROM pg_stat_insights
WHERE query LIKE '%parallel_test%';

-- Test that toplevel field is tracked
SELECT 
  COUNT(*) FILTER (WHERE toplevel = true) AS toplevel_queries,
  COUNT(*) FILTER (WHERE toplevel = false) AS non_toplevel_queries
FROM pg_stat_insights
WHERE calls > 0;

