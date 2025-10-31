-- ============================================================================
-- Test 5: I/O and Cache Statistics
-- Tests block-level I/O tracking and cache hit ratios
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create a larger table to generate I/O
SELECT setseed(0.5); -- Set seed for deterministic values
CREATE TEMP TABLE io_test AS 
SELECT i, md5(i::text), i * 0.123 AS value
FROM generate_series(1, 1000) i;

-- Force some block reads
SELECT COUNT(*) FROM io_test;
SELECT * FROM io_test WHERE i <= 100 ORDER BY i;
SELECT md5, COUNT(*) FROM io_test GROUP BY md5 ORDER BY md5;

-- Wait for stats
SELECT pg_sleep(0.1);

-- Test that I/O stats are being collected
SELECT 
  COUNT(*) FILTER (WHERE shared_blks_hit > 0 OR shared_blks_read > 0) AS queries_with_io,
  COUNT(*) FILTER (WHERE shared_blks_hit > 0) AS queries_with_cache_hits,
  COUNT(*) FILTER (WHERE shared_blks_read > 0) AS queries_with_reads
FROM pg_stat_insights
WHERE query LIKE '%io_test%';

-- Test cache hit ratio calculations
SELECT 
  shared_blks_hit >= 0 AS hits_non_negative,
  shared_blks_read >= 0 AS reads_non_negative,
  (shared_blks_hit + shared_blks_read) >= 0 AS total_blocks_non_negative,
  CASE 
    WHEN (shared_blks_hit + shared_blks_read) > 0 
    THEN (shared_blks_hit::numeric / (shared_blks_hit + shared_blks_read)) BETWEEN 0 AND 1
    ELSE true
  END AS cache_ratio_valid
FROM pg_stat_insights
WHERE query LIKE '%io_test%'
LIMIT 1;

-- Test temp blocks tracking
SELECT 
  temp_blks_read >= 0 AS temp_read_non_negative,
  temp_blks_written >= 0 AS temp_write_non_negative
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Test block timing stats (if track_io_timing is enabled)
SELECT 
  shared_blk_read_time >= 0 AS read_time_valid,
  shared_blk_write_time >= 0 AS write_time_valid
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Test top_by_io view returns queries ordered by I/O
SELECT COUNT(*) > 0 AS has_io_stats FROM pg_stat_insights_top_by_io;

