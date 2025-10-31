-- ============================================================================
-- Test 7: Reset Functionality
-- Tests both global and selective reset functions
-- ============================================================================

-- Reset all statistics
SELECT pg_stat_insights_reset();

-- Generate some statistics
CREATE TEMP TABLE reset_test (id int, value text);
INSERT INTO reset_test VALUES (1, 'test');
SELECT * FROM reset_test;
SELECT COUNT(*) FROM reset_test;

-- Wait for stats
SELECT pg_sleep(0.1);

-- Verify we have statistics
SELECT COUNT(*) > 0 AS has_stats_before_reset FROM pg_stat_insights;

-- Get a specific queryid for selective reset test
SELECT queryid, userid, dbid 
FROM pg_stat_insights 
WHERE query LIKE '%reset_test%' 
LIMIT 1 
\gset

-- Test global reset
SELECT pg_stat_insights_reset();

-- Verify all stats are cleared
SELECT COUNT(*) AS stats_after_global_reset FROM pg_stat_insights;

-- Generate new statistics
INSERT INTO reset_test VALUES (2, 'test2');
SELECT * FROM reset_test WHERE id = 2;

-- Wait for new stats
SELECT pg_sleep(0.1);

-- Verify we have new statistics
SELECT COUNT(*) > 0 AS has_stats_after_generation FROM pg_stat_insights;

-- Test selective reset (reset specific query)
-- This should work without error even if queryid doesn't exist
SELECT pg_stat_insights_reset(10::oid, 12345::oid, 999999999::bigint);

-- Verify stats still exist (we reset a non-existent query)
SELECT COUNT(*) > 0 AS stats_still_exist FROM pg_stat_insights;

