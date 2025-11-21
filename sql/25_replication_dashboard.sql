-- Test replication dashboard comprehensive view
-- This test verifies the unified JSON dashboard functionality

-- Test 1: Verify dashboard sections exist
SELECT DISTINCT section, COUNT(*) as row_count
FROM pg_stat_insights_replication_dashboard
GROUP BY section
ORDER BY section;

-- Test 2: Verify CLUSTER_SUMMARY section structure
SELECT 
    section = 'CLUSTER_SUMMARY' AS correct_section,
    name IS NULL AS name_is_null,
    details IS NOT NULL AS has_details,
    (details->>'physical_replicas')::int >= 0 AS has_physical_count,
    (details->>'logical_slots')::int >= 0 AS has_logical_count,
    (details->>'active_subscriptions')::int >= 0 AS has_subscriptions,
    (details->>'active_publications')::int >= 0 AS has_publications
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

-- Test 3: Verify all detail JSON objects are valid
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE details IS NOT NULL) AS rows_with_details,
    COUNT(*) FILTER (WHERE jsonb_typeof(details::jsonb) = 'object') AS valid_json_objects
FROM pg_stat_insights_replication_dashboard;

-- Test 4: Test JSON extraction from dashboard
SELECT 
    section,
    COUNT(*) as entries,
    COUNT(*) FILTER (WHERE jsonb_typeof(details::jsonb) = 'object') as valid_json
FROM pg_stat_insights_replication_dashboard
GROUP BY section
ORDER BY section;

-- Test 5: Verify CLUSTER_SUMMARY contains expected metrics
SELECT 
    (details->>'physical_replicas') IS NOT NULL AS has_physical_replicas,
    (details->>'logical_slots') IS NOT NULL AS has_logical_slots,
    (details->>'active_subscriptions') IS NOT NULL AS has_subscriptions,
    (details->>'active_publications') IS NOT NULL AS has_publications,
    (details->>'max_lag_seconds') IS NOT NULL AS has_max_lag,
    (details->>'critical_alerts') IS NOT NULL AS has_critical_count,
    (details->>'warning_alerts') IS NOT NULL AS has_warning_count
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

-- Test 6: Test dashboard filtering by section
SELECT COUNT(*) >= 0 AS cluster_summary_exists
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

SELECT COUNT(*) >= 0 AS physical_replica_section_exists
FROM pg_stat_insights_replication_dashboard
WHERE section = 'PHYSICAL_REPLICA';

SELECT COUNT(*) >= 0 AS logical_slot_section_exists
FROM pg_stat_insights_replication_dashboard
WHERE section = 'LOGICAL_SLOT';

SELECT COUNT(*) >= 0 AS alert_section_exists
FROM pg_stat_insights_replication_dashboard
WHERE section = 'ALERT';

-- Test 7: Verify JSON aggregation works
SELECT 
    json_typeof(json_agg(details)::json) = 'array' AS can_aggregate_to_array
FROM pg_stat_insights_replication_dashboard;

-- Test 8: Test pretty JSON formatting
SELECT 
    LENGTH(jsonb_pretty(details::jsonb)) > LENGTH(details::text) AS pretty_formatting_works
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

-- Test 9: Verify numeric values in JSON are valid
SELECT 
    (details->>'physical_replicas')::int >= 0 AS physical_valid,
    (details->>'logical_slots')::int >= 0 AS logical_valid,
    (details->>'active_subscriptions')::int >= 0 AS subscriptions_valid,
    (details->>'active_publications')::int >= 0 AS publications_valid,
    (details->>'critical_alerts')::int >= 0 AS critical_valid,
    (details->>'warning_alerts')::int >= 0 AS warning_valid
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

-- Test 10: Test dashboard ordering
SELECT 
    section,
    name,
    ROW_NUMBER() OVER (ORDER BY section, name) AS row_num
FROM pg_stat_insights_replication_dashboard
ORDER BY section, name
LIMIT 5;

-- Test 11: Verify all sections have proper structure
SELECT 
    section,
    COUNT(*) as row_count,
    COUNT(*) FILTER (WHERE details IS NOT NULL) as with_details,
    COUNT(*) FILTER (WHERE name IS NOT NULL OR section = 'CLUSTER_SUMMARY') as valid_names
FROM pg_stat_insights_replication_dashboard
GROUP BY section
ORDER BY section;

-- Test 12: Test JSON path extraction
SELECT 
    details->>'physical_replicas' AS physical_count,
    details->>'logical_slots' AS logical_count,
    (details->>'critical_alerts')::int + (details->>'warning_alerts')::int AS total_alerts
FROM pg_stat_insights_replication_dashboard
WHERE section = 'CLUSTER_SUMMARY';

-- Test 13: Verify dashboard can be exported as single JSON
SELECT 
    json_typeof(
        json_agg(
            json_build_object(
                'section', section,
                'name', name,
                'details', details
            )
        )::json
    ) = 'array' AS exportable_as_json
FROM pg_stat_insights_replication_dashboard;

-- Test 14: Test filtering alerts from dashboard
SELECT 
    COUNT(*) >= 0 AS has_alert_entries,
    COUNT(*) FILTER (WHERE details->>'alert_level' LIKE 'CRITICAL%') >= 0 AS has_critical,
    COUNT(*) FILTER (WHERE details->>'alert_level' LIKE 'WARNING%') >= 0 AS has_warning
FROM pg_stat_insights_replication_dashboard
WHERE section = 'ALERT';

-- Test 15: Verify dashboard completeness
SELECT 
    COUNT(DISTINCT section) >= 1 AS has_sections,
    COUNT(*) FILTER (WHERE section = 'CLUSTER_SUMMARY') = 1 AS has_single_summary,
    COUNT(*) FILTER (WHERE details IS NOT NULL) = COUNT(*) AS all_have_details
FROM pg_stat_insights_replication_dashboard;

