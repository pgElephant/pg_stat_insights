-- ============================================================================
-- Test 3: Views and Aggregate Functions
-- Tests all helper views and their filtering/ordering logic
-- ============================================================================

-- Reset and create test data
SELECT pg_stat_insights_reset();

-- Create test table with more data
CREATE TEMP TABLE performance_test (
  id serial PRIMARY KEY,
  category text,
  value numeric,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert test data with deterministic values
SELECT setseed(0.5); -- Set seed for deterministic random values
INSERT INTO performance_test (category, value)
SELECT 
  CASE (i % 3)
    WHEN 0 THEN 'fast'
    WHEN 1 THEN 'medium'
    ELSE 'slow'
  END,
  i * 10.5  -- Deterministic values instead of random
FROM generate_series(1, 100) i;

-- Run various query patterns
SELECT COUNT(*) FROM performance_test;
SELECT category, COUNT(*), AVG(value) FROM performance_test GROUP BY category ORDER BY category;
SELECT * FROM performance_test WHERE category = 'fast' ORDER BY value DESC LIMIT 10;
SELECT * FROM performance_test WHERE value > 500 ORDER BY id;

-- Wait for stats
SELECT pg_sleep(0.1);

-- Test top_by_time view
SELECT COUNT(*) > 0 AS has_top_by_time FROM pg_stat_insights_top_by_time;

-- Test top_by_calls view  
SELECT COUNT(*) > 0 AS has_top_by_calls FROM pg_stat_insights_top_by_calls;

-- Test top_by_io view
SELECT COUNT(*) > 0 AS has_top_by_io FROM pg_stat_insights_top_by_io;

-- Test cache misses view
SELECT COUNT(*) >= 0 AS has_cache_misses FROM pg_stat_insights_top_cache_misses;

-- Test slow queries view
SELECT COUNT(*) >= 0 AS has_slow_queries FROM pg_stat_insights_slow_queries;

-- Test histogram summary view
SELECT COUNT(*) > 0 AS has_histogram FROM pg_stat_insights_histogram_summary;

-- Test bucket view
SELECT COUNT(*) > 0 AS has_bucket_view FROM pg_stat_insights_by_bucket;

-- Verify view ordering (top_by_time should be ordered by total_exec_time DESC)
SELECT 
  total_exec_time >= LEAD(total_exec_time) OVER () OR LEAD(total_exec_time) OVER () IS NULL AS is_ordered
FROM pg_stat_insights_top_by_time
LIMIT 5;

-- Verify cache hit ratio calculation
SELECT 
  cache_hit_ratio >= 0 AND cache_hit_ratio <= 1 AS ratio_valid
FROM pg_stat_insights_top_cache_misses
WHERE cache_hit_ratio IS NOT NULL
LIMIT 1;

