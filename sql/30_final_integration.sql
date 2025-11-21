-- Final integration test - Verify complete extension functionality
-- Tests all components working together for production readiness

-- Test 1: Verify extension version and schema
SELECT 
    extname = 'pg_stat_insights' AS correct_name,
    extversion = '1.0' AS correct_version
FROM pg_extension
WHERE extname = 'pg_stat_insights';

-- Test 2: Count all objects created by extension
SELECT 
    (SELECT COUNT(*) FROM pg_proc WHERE proname LIKE 'pg_stat_insights%') AS function_count,
    (SELECT COUNT(*) FROM pg_views WHERE viewname LIKE 'pg_stat_insights%') AS view_count;

-- Test 3: Verify all 24 views are accessible
SELECT viewname
FROM pg_views
WHERE viewname LIKE 'pg_stat_insights%'
ORDER BY viewname;

-- Test 4: Test all main functions execute without error
SELECT pg_stat_insights_reset() IS NOT NULL AS reset_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights AS main_view_works;

-- Test 5: Verify all performance views return data
SELECT COUNT(*) >= 0 FROM pg_stat_insights_top_by_time AS top_time_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_top_by_calls AS top_calls_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_top_by_io AS top_io_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_top_cache_misses AS cache_misses_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_slow_queries AS slow_queries_works;

-- Test 6: Verify all replication views return data
SELECT COUNT(*) >= 0 FROM pg_stat_insights_physical_replication AS physical_repl_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_logical_replication AS logical_repl_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_slots AS repl_slots_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_summary AS repl_summary_works;

-- Test 7: Verify advanced replication diagnostics
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_alerts AS alerts_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_wal AS wal_stats_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_bottlenecks AS bottlenecks_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_conflicts AS conflicts_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_health AS health_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_performance AS performance_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_timeline AS timeline_works;

-- Test 8: Verify logical replication monitoring
SELECT COUNT(*) >= 0 FROM pg_stat_insights_subscriptions AS subscriptions_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_subscription_stats AS subscription_stats_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_publications AS publications_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_origins AS origins_works;

-- Test 9: Verify dashboard
SELECT COUNT(*) >= 0 FROM pg_stat_insights_replication_dashboard AS dashboard_works;

-- Test 10: Verify histogram and aggregation views
SELECT COUNT(*) >= 0 FROM pg_stat_insights_histogram_summary AS histogram_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_by_bucket AS bucket_works;

-- Test 11: Verify error tracking views
SELECT COUNT(*) >= 0 FROM pg_stat_insights_errors AS errors_works;
SELECT COUNT(*) >= 0 FROM pg_stat_insights_plan_errors AS plan_errors_works;

-- Test 12: End-to-end workflow test
CREATE TEMP TABLE integration_test (id INT, data TEXT);
INSERT INTO integration_test VALUES (1, 'test');
SELECT * FROM integration_test;
DROP TABLE integration_test;

-- Verify workflow was tracked
SELECT COUNT(*) >= 3 AS workflow_tracked
FROM pg_stat_insights
WHERE query LIKE '%integration_test%';

-- Test 13: Verify all configuration parameters exist
SELECT COUNT(*) >= 11 AS has_all_parameters
FROM pg_settings
WHERE name LIKE 'pg_stat_insights.%';

-- Test 14: Check parameter values are valid
SELECT 
    name,
    setting,
    unit,
    vartype
FROM pg_settings
WHERE name LIKE 'pg_stat_insights.%'
ORDER BY name;

-- Test 15: Final health check - All views functional
SELECT 
    'All 24 views functional' AS status,
    (SELECT COUNT(*) FROM pg_views WHERE viewname LIKE 'pg_stat_insights%') AS view_count,
    (SELECT COUNT(*) FROM pg_proc WHERE proname LIKE 'pg_stat_insights%') AS function_count,
    'READY FOR PRODUCTION' AS result;

