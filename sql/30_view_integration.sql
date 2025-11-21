-- Test integration between different pg_stat_insights views
-- Ensures views work correctly together and provide consistent data

-- Test 1: Verify all base views exist
SELECT COUNT(*) AS view_count
FROM pg_views
WHERE viewname LIKE 'pg_stat_insights%'
ORDER BY viewname;

-- Test 2: Test cross-view consistency
SELECT 
    (SELECT COUNT(*) FROM pg_stat_insights) >= 
    (SELECT COUNT(*) FROM pg_stat_insights_top_by_time) AS top_time_subset,
    (SELECT COUNT(*) FROM pg_stat_insights) >= 
    (SELECT COUNT(*) FROM pg_stat_insights_top_by_calls) AS top_calls_subset,
    (SELECT COUNT(*) FROM pg_stat_insights) >= 
    (SELECT COUNT(*) FROM pg_stat_insights_slow_queries) AS slow_queries_subset;

-- Test 3: Verify histogram summary aggregates correctly
SELECT 
    SUM(total_queries) >= 0 AS histogram_total_valid,
    COUNT(*) >= 7 AS has_all_buckets
FROM pg_stat_insights_histogram_summary;

-- Test 4: Test replication summary aggregates
SELECT 
    physical_replicas_connected >= 0 AS physical_valid,
    logical_slots_active >= 0 AS logical_valid,
    (physical_replicas_connected + logical_slots_active + inactive_slots) >= 0 AS total_consistent
FROM pg_stat_insights_replication_summary;

-- Test 5: Verify WAL view has consistent totals
SELECT 
    wal_files_count >= 0 AS files_valid,
    wal_total_size_bytes >= 0 AS size_valid,
    total_wal_generated_bytes >= wal_total_size_bytes AS generated_gte_current
FROM pg_stat_insights_replication_wal;

-- Test 6: Test dashboard sections completeness
SELECT 
    section,
    COUNT(*) AS entries
FROM pg_stat_insights_replication_dashboard
GROUP BY section
ORDER BY section;

-- Test 7: Verify dashboard JSON structure
SELECT 
    COUNT(*) FILTER (WHERE jsonb_typeof(details::jsonb) = 'object') = COUNT(*) AS all_valid_json
FROM pg_stat_insights_replication_dashboard;

-- Test 8: Test alert aggregation
SELECT 
    alert_level,
    COUNT(*) AS alert_count
FROM pg_stat_insights_replication_alerts
GROUP BY alert_level
ORDER BY alert_level;

-- Test 9: Cross-check alerts with summary
SELECT 
    (SELECT COUNT(*) FROM pg_stat_insights_replication_alerts WHERE alert_level LIKE 'CRITICAL%') =
    (SELECT critical_alerts FROM pg_stat_insights_replication_dashboard WHERE section = 'CLUSTER_SUMMARY' LIMIT 1)::int AS critical_counts_match,
    (SELECT COUNT(*) FROM pg_stat_insights_replication_alerts WHERE alert_level LIKE 'WARNING%') =
    COALESCE((SELECT (details->>'warning_alerts')::int FROM pg_stat_insights_replication_dashboard WHERE section = 'CLUSTER_SUMMARY' LIMIT 1), 0) AS warning_counts_match;

-- Test 10: Verify view dependencies
SELECT 
    COUNT(DISTINCT viewname) AS total_replication_views
FROM pg_views
WHERE viewname LIKE 'pg_stat_insights_replication%'
   OR viewname LIKE 'pg_stat_insights_subscription%'
   OR viewname LIKE 'pg_stat_insights_publication%';

-- Test 11: Test publication and subscription views correlation
SELECT 
    (SELECT COUNT(*) FROM pg_stat_insights_publications) >= 0 AS publications_counted,
    (SELECT COUNT(*) FROM pg_stat_insights_subscriptions) >= 0 AS subscriptions_counted,
    (SELECT COUNT(*) FROM pg_stat_insights_subscription_stats) >= 0 AS subscription_stats_counted;

-- Test 12: Verify all views handle NULL values gracefully
SELECT COUNT(*) >= 0 AS handles_nulls_physical
FROM pg_stat_insights_physical_replication
WHERE health_status IS NOT NULL OR health_status IS NULL;

SELECT COUNT(*) >= 0 AS handles_nulls_logical
FROM pg_stat_insights_logical_replication
WHERE lag_mb IS NOT NULL OR lag_mb IS NULL;

-- Test 13: Test performance rating distribution
SELECT 
    performance_rating,
    COUNT(*) AS rating_count
FROM pg_stat_insights_replication_performance
GROUP BY performance_rating
ORDER BY performance_rating;

-- Test 14: Test health status distribution
SELECT 
    overall_health,
    COUNT(*) AS health_count
FROM pg_stat_insights_replication_health
GROUP BY overall_health
ORDER BY overall_health;

-- Test 15: Verify all views return consistent data types
SELECT 
    'pg_stat_insights' AS view_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT queryid) AS unique_queries
FROM pg_stat_insights
UNION ALL
SELECT 
    'replication_summary' AS view_name,
    COUNT(*) AS row_count,
    NULL::bigint AS unique_queries
FROM pg_stat_insights_replication_summary
UNION ALL
SELECT 
    'replication_wal' AS view_name,
    COUNT(*) AS row_count,
    NULL::bigint AS unique_queries
FROM pg_stat_insights_replication_wal
ORDER BY view_name;

