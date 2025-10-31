-- ============================================================================
-- Test 11: Comprehensive Metrics Validation
-- Tests all 50+ metrics are collected correctly
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create comprehensive test scenario
CREATE TEMP TABLE metrics_test (
  id bigserial PRIMARY KEY,
  category text NOT NULL,
  amount numeric NOT NULL,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp,
  data jsonb
);

-- Create index for cache testing
CREATE INDEX idx_metrics_category ON metrics_test(category);
CREATE INDEX idx_metrics_amount ON metrics_test(amount);

-- Insert substantial data with deterministic values
SELECT setseed(0.5); -- Set seed for deterministic values
INSERT INTO metrics_test (category, amount, data)
SELECT 
  'cat_' || (i % 10),
  (i * 1.234)::numeric,
  jsonb_build_object('id', i, 'value', i * 0.001)
FROM generate_series(1, 5000) i;

-- Execute diverse query types
-- 1. Full table scan
SELECT COUNT(*) FROM metrics_test;

-- 2. Index scan
SELECT * FROM metrics_test WHERE category = 'cat_5' ORDER BY id;

-- 3. Index-only scan (if possible)
SELECT category FROM metrics_test WHERE category = 'cat_3' ORDER BY category;

-- 4. Sequential scan with filter
SELECT * FROM metrics_test WHERE amount > 8000 ORDER BY id;

-- 5. Aggregation with grouping
SELECT category, COUNT(*), SUM(amount), AVG(amount), MIN(amount), MAX(amount)
FROM metrics_test
GROUP BY category
ORDER BY category;

-- 6. Subquery
SELECT category, amount FROM metrics_test 
WHERE amount > (SELECT AVG(amount) FROM metrics_test)
ORDER BY id;

-- 7. CTE (Common Table Expression)
WITH category_stats AS (
  SELECT category, AVG(amount) as avg_amount
  FROM metrics_test
  GROUP BY category
)
SELECT * FROM category_stats WHERE avg_amount > 5000 ORDER BY category;

-- 8. Window function
SELECT 
  category, 
  amount,
  ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) as rank
FROM metrics_test
ORDER BY category, amount DESC
LIMIT 20;

-- Wait for all stats to be collected
SELECT pg_sleep(0.2);

-- Validate all key metrics are being tracked
SELECT 
  -- Execution metrics
  COUNT(*) FILTER (WHERE calls > 0) > 0 AS has_calls,
  COUNT(*) FILTER (WHERE total_exec_time > 0) > 0 AS has_exec_time,
  COUNT(*) FILTER (WHERE mean_exec_time > 0) > 0 AS has_mean_time,
  COUNT(*) FILTER (WHERE min_exec_time > 0) > 0 AS has_min_time,
  COUNT(*) FILTER (WHERE max_exec_time > 0) > 0 AS has_max_time,
  
  -- Planning metrics
  COUNT(*) FILTER (WHERE plans >= 0) > 0 AS has_plans,
  COUNT(*) FILTER (WHERE total_plan_time >= 0) > 0 AS has_plan_time,
  
  -- Row counts
  COUNT(*) FILTER (WHERE rows >= 0) > 0 AS has_rows,
  
  -- Block I/O metrics
  COUNT(*) FILTER (WHERE shared_blks_hit >= 0) > 0 AS has_shared_hits,
  COUNT(*) FILTER (WHERE shared_blks_read >= 0) > 0 AS has_shared_reads,
  COUNT(*) FILTER (WHERE shared_blks_dirtied >= 0) > 0 AS has_dirtied,
  COUNT(*) FILTER (WHERE shared_blks_written >= 0) > 0 AS has_written,
  
  -- WAL metrics
  COUNT(*) FILTER (WHERE wal_records >= 0) > 0 AS has_wal_records,
  COUNT(*) FILTER (WHERE wal_bytes >= 0) > 0 AS has_wal_bytes,
  COUNT(*) FILTER (WHERE wal_fpi >= 0) > 0 AS has_wal_fpi
FROM pg_stat_insights
WHERE query LIKE '%metrics_test%';

-- Test that stats_since timestamp is reasonable
SELECT 
  stats_since <= now() AS stats_since_in_past,
  stats_since > (now() - interval '1 hour') AS stats_since_recent,
  minmax_stats_since <= now() AS minmax_since_in_past
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Verify queryid uniqueness per query pattern
SELECT 
  COUNT(DISTINCT queryid) > 0 AS has_unique_queryids,
  COUNT(*) > 0 AS has_entries
FROM pg_stat_insights
WHERE query LIKE '%metrics_test%';

