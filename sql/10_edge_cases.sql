-- ============================================================================
-- Test 10: Edge Cases and Error Handling
-- Tests boundary conditions and error scenarios
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Test with NULL values
CREATE TEMP TABLE null_test (id int, value text);
INSERT INTO null_test VALUES (NULL, NULL);
INSERT INTO null_test VALUES (1, NULL);
INSERT INTO null_test VALUES (NULL, 'test');
SELECT * FROM null_test WHERE id IS NULL;
SELECT * FROM null_test WHERE value IS NOT NULL;

-- Test with empty result sets
SELECT * FROM null_test WHERE id = 999999;
SELECT * FROM null_test WHERE value = 'nonexistent';

-- Test with very long query text
SELECT id FROM null_test WHERE id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20);

-- Test with special characters in strings
SELECT * FROM null_test WHERE value LIKE '%''test''%';
SELECT * FROM null_test WHERE value = E'test\nwith\nnewlines';

-- Wait for stats
SELECT pg_sleep(0.1);

-- Verify no crashes occurred
SELECT COUNT(*) >= 0 AS stats_exist FROM pg_stat_insights;

-- Test reset with invalid parameters
SELECT pg_stat_insights_reset(0::oid, 0::oid, 0::bigint);

-- Test that views handle empty data gracefully
SELECT COUNT(*) >= 0 AS top_time_ok FROM pg_stat_insights_top_by_time;
SELECT COUNT(*) >= 0 AS top_calls_ok FROM pg_stat_insights_top_by_calls;
SELECT COUNT(*) >= 0 AS top_io_ok FROM pg_stat_insights_top_by_io;
SELECT COUNT(*) >= 0 AS cache_misses_ok FROM pg_stat_insights_top_cache_misses;
SELECT COUNT(*) >= 0 AS slow_queries_ok FROM pg_stat_insights_slow_queries;
SELECT COUNT(*) >= 0 AS histogram_ok FROM pg_stat_insights_histogram_summary;
SELECT COUNT(*) >= 0 AS bucket_ok FROM pg_stat_insights_by_bucket;

-- Test division by zero protection in cache hit ratio
SELECT 
  COUNT(*) FILTER (WHERE cache_hit_ratio IS NOT NULL) >= 0 AS cache_ratio_handled
FROM pg_stat_insights_top_cache_misses;

-- Test with zero calls (should not exist but edge case)
SELECT COUNT(*) AS zero_call_queries FROM pg_stat_insights WHERE calls = 0;

-- Test with very large values
CREATE TEMP TABLE large_test AS
SELECT i, 'large_data_' || repeat('x', 100) AS large_text
FROM generate_series(1, 10) i;

SELECT COUNT(*) FROM large_test;
SELECT SUM(i) FROM large_test;

-- Test with negative values (should be handled gracefully)
SELECT id, value FROM null_test WHERE id < 0;

-- Test with empty strings
INSERT INTO null_test VALUES (999, '');
SELECT * FROM null_test WHERE value = '';
SELECT * FROM null_test WHERE value != '';

-- Test with special SQL keywords as values
INSERT INTO null_test VALUES (998, 'SELECT');
INSERT INTO null_test VALUES (997, 'WHERE');
SELECT * FROM null_test WHERE value IN ('SELECT', 'WHERE', 'INSERT');

-- Wait for stats
SELECT pg_sleep(0.1);

-- Verify edge cases are handled
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%large_test%') > 0 AS large_queries_tracked,
  COUNT(*) FILTER (WHERE query LIKE '%null_test%') > 0 AS null_queries_tracked
FROM pg_stat_insights;

