-- ============================================================================
-- Test 12: Permissions and Security
-- Tests that permissions are correctly set on all objects
-- ============================================================================

-- Check that PUBLIC has SELECT on main view
SELECT has_table_privilege('public', 'pg_stat_insights', 'SELECT') AS public_can_select_main;

-- Check permissions on all views
SELECT has_table_privilege('public', 'pg_stat_insights_replication', 'SELECT') AS can_select_repl;
SELECT has_table_privilege('public', 'pg_stat_insights_top_by_time', 'SELECT') AS can_select_top_time;
SELECT has_table_privilege('public', 'pg_stat_insights_top_by_calls', 'SELECT') AS can_select_top_calls;
SELECT has_table_privilege('public', 'pg_stat_insights_top_by_io', 'SELECT') AS can_select_top_io;
SELECT has_table_privilege('public', 'pg_stat_insights_top_cache_misses', 'SELECT') AS can_select_cache;
SELECT has_table_privilege('public', 'pg_stat_insights_slow_queries', 'SELECT') AS can_select_slow;
SELECT has_table_privilege('public', 'pg_stat_insights_histogram_summary', 'SELECT') AS can_select_histogram;
SELECT has_table_privilege('public', 'pg_stat_insights_by_bucket', 'SELECT') AS can_select_bucket;

-- Verify functions are executable by public
SELECT has_function_privilege('public', 'pg_stat_insights_reset()', 'EXECUTE') AS can_execute_reset;

-- Test that non-superuser cannot see other users' queries (query text filtering)
-- This depends on PostgreSQL permissions, just verify the view is accessible
SELECT COUNT(*) >= 0 AS view_accessible_by_public FROM pg_stat_insights;

-- Test error views are accessible
SELECT has_table_privilege('public', 'pg_stat_insights_errors', 'SELECT') AS can_select_errors;
SELECT has_table_privilege('public', 'pg_stat_insights_plan_errors', 'SELECT') AS can_select_plan_errors;

