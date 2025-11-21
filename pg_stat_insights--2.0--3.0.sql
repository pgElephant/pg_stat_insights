/*-------------------------------------------------------------------------
 *
 * pg_stat_insights--2.0--3.0.sql
 *      Upgrade script from version 2.0 to 3.0
 * Copyright (c) 2024-2025, pgElephant, Inc.
 * Copyright (c) 2008-2025, PostgreSQL Global Development Group
 *
 *-------------------------------------------------------------------------
 */

-- ============================================================================
-- Index Monitoring Views
-- ============================================================================

-- Comprehensive Index Statistics
CREATE VIEW pg_stat_insights_indexes AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    i.indexrelid,
    i.relid AS indrelid,
    pg_relation_size(i.indexrelid) AS index_size_bytes,
    ROUND((pg_relation_size(i.indexrelid)::numeric / 1024 / 1024), 2) AS index_size_mb,
    (pg_relation_size(i.indexrelid) / 
     (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::int8 AS index_pages,
    i.idx_scan,
    i.idx_tup_read,
    i.idx_tup_fetch,
    io.idx_blk_read,
    io.idx_blk_hit,
    io.heap_blk_read,
    io.heap_blk_hit,
    CASE 
        WHEN (io.idx_blk_read + io.idx_blk_hit) > 0 
        THEN ROUND((io.idx_blk_hit::numeric / (io.idx_blk_read + io.idx_blk_hit))::numeric, 4)
        ELSE NULL
    END AS idx_cache_hit_ratio,
    CASE 
        WHEN (io.heap_blk_read + io.heap_blk_hit) > 0 
        THEN ROUND((io.heap_blk_hit::numeric / (io.heap_blk_read + io.heap_blk_hit))::numeric, 4)
        ELSE NULL
    END AS heap_cache_hit_ratio,
    am.amname AS index_type,
    CASE WHEN idx.indisunique THEN true ELSE false END AS is_unique,
    CASE WHEN idx.indisprimary THEN true ELSE false END AS is_primary,
    CASE WHEN idx.indpred IS NOT NULL THEN true ELSE false END AS is_partial,
    CASE WHEN idx.indexprs IS NOT NULL THEN true ELSE false END AS is_expression,
    COALESCE(c.reloptions, ARRAY[]::text[]) AS index_options,
    pg_get_indexdef(i.indexrelid) AS indexdef,
    NULL::int8 AS index_age_days,
    (SELECT estimated_bloat_ratio FROM pg_stat_insights_index_bloat bloat 
     WHERE bloat.schemaname = i.schemaname AND bloat.tablename = i.tablename 
     AND bloat.indexname = i.indexrelname LIMIT 1) AS bloat_ratio,
    (SELECT estimated_bloat_size_mb FROM pg_stat_insights_index_bloat bloat 
     WHERE bloat.schemaname = i.schemaname AND bloat.tablename = i.tablename 
     AND bloat.indexname = i.indexrelname LIMIT 1) AS bloat_size_mb,
    COALESCE((SELECT option_value::int FROM unnest(c.reloptions) AS option_value 
              WHERE option_value LIKE 'fillfactor=%'), 100) AS fillfactor,
    t.last_vacuum,
    t.last_autovacuum,
    NULL::timestamp with time zone AS last_reindex,
    CASE 
        WHEN am.amname = 'brin' THEN
            (SELECT s.correlation 
             FROM pg_stats s
             JOIN pg_attribute a ON a.attrelid = (SELECT relid FROM pg_stat_user_indexes WHERE indexrelid = i.indexrelid)
             JOIN pg_index idx2 ON idx2.indexrelid = i.indexrelid 
             WHERE s.schemaname = i.schemaname 
               AND s.tablename = i.tablename 
               AND a.attnum = idx2.indkey[0]
               AND a.attname = s.attname
             LIMIT 1)
        ELSE NULL
    END AS correlation,
    CASE 
        WHEN idx.indpred IS NOT NULL THEN i.idx_scan
        ELSE NULL
    END AS partial_index_scans,
    CASE 
        WHEN idx.indexprs IS NOT NULL THEN i.idx_scan
        ELSE NULL
    END AS expression_index_scans
FROM pg_stat_user_indexes i
JOIN pg_statio_user_indexes io ON io.indexrelid = i.indexrelid AND io.relid = i.relid
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_index idx ON idx.indexrelid = i.indexrelid
JOIN pg_am am ON am.oid = c.relam
LEFT JOIN pg_stat_user_tables t ON t.relid = i.relid;

-- Index Usage Analysis
CREATE VIEW pg_stat_insights_index_usage AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    i.idx_scan AS total_scans,
    CASE 
        WHEN (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()) IS NOT NULL THEN
            ROUND((i.idx_scan::numeric / 
                   NULLIF(EXTRACT(EPOCH FROM (now() - (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database())))::numeric / 86400, 0)), 2)
        ELSE NULL
    END AS scans_per_day,
    CASE 
        WHEN i.idx_scan > 0 THEN 
            (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database())
        ELSE NULL
    END AS last_scan_time,
    t.seq_scan AS table_seq_scans,
    t.n_tup_ins + t.n_tup_upd + t.n_tup_del AS table_total_updates,
    CASE 
        WHEN (t.seq_scan + i.idx_scan) > 0 
        THEN ROUND((i.idx_scan::numeric / (t.seq_scan + i.idx_scan))::numeric, 4)
        ELSE 0
    END AS index_scan_ratio,
    CASE 
        WHEN i.idx_scan = 0 THEN 'NEVER_USED'
        WHEN i.idx_scan < 10 THEN 'RARE'
        WHEN i.idx_scan < 100 THEN 'OCCASIONAL'
        WHEN i.idx_scan < 1000 THEN 'ACTIVE'
        ELSE 'HEAVY'
    END AS usage_status,
    CASE 
        WHEN i.idx_scan = 0 AND (t.n_tup_ins + t.n_tup_upd + t.n_tup_del) > 1000 THEN 
            'DROP_CANDIDATE: Index never used on active table'
        WHEN i.idx_scan < 10 AND t.seq_scan > i.idx_scan * 100 THEN 
            'REVIEW: Low usage, high sequential scans'
        WHEN i.idx_scan > 0 AND (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) < 0.1 THEN
            'REVIEW: Sequential scans preferred over index'
        ELSE 'KEEP'
    END AS recommendation
FROM pg_stat_user_indexes i
JOIN pg_stat_user_tables t ON t.relid = i.relid;

-- Index Bloat Estimation
CREATE VIEW pg_stat_insights_index_bloat AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    pg_relation_size(i.indexrelid) AS actual_size_bytes,
    ROUND((pg_relation_size(i.indexrelid)::numeric / 1024 / 1024), 2) AS actual_size_mb,
    (pg_relation_size(i.indexrelid) / 
     (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::int8 AS actual_pages,
    CASE 
        WHEN i.idx_tup_read > 0 THEN
            (pg_relation_size(i.indexrelid) / 
             NULLIF(i.idx_tup_read, 0))::int8
        ELSE NULL
    END AS bytes_per_tuple_read,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 THEN
            ROUND(((pg_relation_size(i.indexrelid)::numeric / 
                    NULLIF(i.idx_tup_read, 0)) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::numeric, 2)
        ELSE NULL
    END AS estimated_bloat_ratio,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 2.0 THEN
            ROUND(((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size') - 1.0) * 
                  (pg_relation_size(i.indexrelid) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::numeric / 1024 / 1024, 2)
        ELSE 0
    END AS estimated_bloat_size_mb,
    estimated_bloat_size_mb * 1024 * 1024 AS estimated_bloat_size_bytes,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 THEN
            (pg_relation_size(i.indexrelid) / 
             (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::int8
        ELSE NULL
    END AS expected_pages,
    CASE 
        WHEN estimated_bloat_size_mb > 0 THEN
            (estimated_bloat_size_mb * 1024 * 1024 / 
             (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::int8
        ELSE 0
    END AS wasted_pages,
    COALESCE((SELECT option_value::int FROM unnest(c.reloptions) AS option_value 
              WHERE option_value LIKE 'fillfactor=%'), 100) AS fillfactor,
    NULL::numeric AS avg_leaf_density,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 2.0 THEN 'HIGH'
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 1.5 THEN 'MEDIUM'
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 1.2 THEN 'LOW'
        ELSE 'NONE'
    END AS bloat_severity,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 2.0 THEN true
        ELSE false
    END AS needs_reindex,
    NULL::timestamp with time zone AS last_reindex,
    (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()) AS last_analyzed
FROM pg_stat_user_indexes i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.idx_tup_read > 0;

-- Index Efficiency Analysis
CREATE VIEW pg_stat_insights_index_efficiency AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    i.idx_scan AS index_scans,
    t.seq_scan AS seq_scans,
    CASE 
        WHEN (t.seq_scan + i.idx_scan) > 0 
        THEN ROUND((i.idx_scan::numeric / (t.seq_scan + i.idx_scan))::numeric, 4)
        ELSE 0
    END AS index_scan_ratio,
    CASE 
        WHEN (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) >= 0.8 THEN 'EXCELLENT'
        WHEN (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) >= 0.5 THEN 'GOOD'
        WHEN (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) >= 0.2 THEN 'FAIR'
        WHEN (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) > 0 THEN 'POOR'
        ELSE 'UNUSED'
    END AS efficiency_rating,
    CASE 
        WHEN i.idx_scan = 0 AND t.seq_scan > 1000 THEN 
            'Consider dropping: Index never used, high sequential scan activity'
        WHEN (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) < 0.1 AND t.seq_scan > 100 THEN
            'Review index: Sequential scans preferred, may need index tuning'
        WHEN i.idx_scan > 0 AND (t.seq_scan + i.idx_scan) > 0 AND 
             (i.idx_scan::numeric / (t.seq_scan + i.idx_scan)) >= 0.5 THEN
            'Index performing well'
        ELSE 'Monitor index usage'
    END AS recommendation
FROM pg_stat_user_indexes i
JOIN pg_stat_user_tables t ON t.relid = i.relid;

-- Index Maintenance Recommendations
CREATE VIEW pg_stat_insights_index_maintenance AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    CASE 
        WHEN bloat.needs_reindex = true THEN 'REINDEX'
        WHEN t.last_vacuum IS NULL AND t.last_autovacuum IS NULL AND 
             (t.n_tup_upd + t.n_tup_del) > 10000 THEN 'VACUUM'
        WHEN t.last_analyze IS NULL AND t.n_tup_ins > 1000 THEN 'ANALYZE'
        ELSE 'NONE'
    END AS maintenance_type,
    CASE 
        WHEN bloat.needs_reindex = true THEN 'CRITICAL'
        WHEN bloat.bloat_severity = 'HIGH' THEN 'HIGH'
        WHEN (t.n_tup_upd + t.n_tup_del) > 100000 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS priority,
    CASE 
        WHEN bloat.needs_reindex = true THEN 'Index has significant bloat, REINDEX recommended'
        WHEN bloat.bloat_severity = 'HIGH' THEN 'Index bloat detected, consider REINDEX'
        WHEN t.last_vacuum IS NULL AND t.last_autovacuum IS NULL THEN 
            'Table has not been vacuumed, may affect index performance'
        WHEN t.last_analyze IS NULL THEN 
            'Table statistics outdated, ANALYZE recommended'
        ELSE 'No immediate maintenance needed'
    END AS reason,
    t.last_vacuum,
    t.last_autovacuum,
    t.last_analyze,
    CASE 
        WHEN bloat.needs_reindex = true THEN 
            'REINDEX INDEX ' || quote_ident(i.schemaname) || '.' || quote_ident(i.indexrelname) || ';'
        WHEN t.last_vacuum IS NULL AND t.last_autovacuum IS NULL THEN
            'VACUUM ANALYZE ' || quote_ident(i.schemaname) || '.' || quote_ident(i.tablename) || ';'
        WHEN t.last_analyze IS NULL THEN
            'ANALYZE ' || quote_ident(i.schemaname) || '.' || quote_ident(i.tablename) || ';'
        ELSE NULL
    END AS recommended_action,
    CASE 
        WHEN bloat.needs_reindex = true AND bloat.estimated_bloat_size_mb > 0 THEN
            'Potential size reduction: ' || ROUND(bloat.estimated_bloat_size_mb, 2) || ' MB'
        ELSE 'Maintenance will improve query performance'
    END AS estimated_benefit
FROM pg_stat_user_indexes i
JOIN pg_stat_user_tables t ON t.relid = i.relid
LEFT JOIN pg_stat_insights_index_bloat bloat ON 
    bloat.schemaname = i.schemaname AND 
    bloat.tablename = i.tablename AND 
    bloat.indexname = i.indexrelname;

-- Missing Index Recommendations
CREATE VIEW pg_stat_insights_missing_indexes AS
SELECT 
    t.schemaname,
    t.tablename,
    'column_analysis' AS analysis_type,
    NULL::text AS column_name,
    NULL::text AS column_type,
    'WHERE' AS query_pattern,
    t.seq_scan AS occurrence_count,
    NULL::float8 AS total_exec_time,
    CASE 
        WHEN t.seq_scan > 1000 AND t.seq_tup_read > 10000 THEN 'HIGH'
        WHEN t.seq_scan > 100 AND t.seq_tup_read > 1000 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS estimated_benefit,
    CASE 
        WHEN t.seq_scan > 1000 AND t.seq_tup_read > 10000 THEN
            'Consider adding index on frequently filtered columns'
        ELSE NULL
    END AS recommended_index_def,
    'btree' AS recommended_index_type,
    CASE 
        WHEN COALESCE(idx.total_idx_scan, 0) = 0 AND t.seq_scan > 100 THEN true
        WHEN t.seq_scan > COALESCE(idx.total_idx_scan, 0) * 10 AND t.seq_scan > 100 THEN true
        ELSE false
    END AS high_priority
FROM pg_stat_user_tables t
LEFT JOIN (
    SELECT relid, SUM(idx_scan) AS total_idx_scan
    FROM pg_stat_user_indexes
    GROUP BY relid
) idx ON idx.relid = t.relid
WHERE t.seq_scan > 100
  AND (idx.total_idx_scan IS NULL OR t.seq_scan > idx.total_idx_scan * 5)
ORDER BY t.seq_scan DESC, t.seq_tup_read DESC
LIMIT 50;

-- Index Summary
CREATE VIEW pg_stat_insights_index_summary AS
SELECT 
    (SELECT COUNT(*) FROM pg_stat_user_indexes) AS total_indexes,
    ROUND((SELECT SUM(pg_relation_size(indexrelid))::numeric FROM pg_stat_user_indexes) / 1024 / 1024, 2) AS total_index_size_mb,
    (SELECT COUNT(*) FROM pg_stat_user_indexes WHERE idx_scan > 0) AS active_indexes,
    (SELECT COUNT(*) FROM pg_stat_user_indexes WHERE idx_scan = 0) AS unused_indexes,
    (SELECT COUNT(*) FROM pg_stat_insights_index_bloat WHERE bloat_severity IN ('HIGH', 'MEDIUM')) AS bloated_indexes,
    (SELECT COUNT(*) FROM pg_stat_insights_index_maintenance WHERE maintenance_type = 'REINDEX') AS indexes_needing_reindex,
    (SELECT COUNT(*) FROM pg_stat_insights_index_maintenance WHERE maintenance_type = 'VACUUM') AS indexes_needing_vacuum,
    (SELECT COUNT(*) FROM pg_stat_insights_index_usage WHERE usage_status = 'NEVER_USED') AS never_used_indexes,
    (SELECT COUNT(*) FROM pg_stat_insights_index_usage WHERE recommendation LIKE 'DROP_CANDIDATE%') AS drop_candidate_indexes,
    ROUND((SELECT AVG(idx_cache_hit_ratio) FROM pg_stat_insights_indexes WHERE idx_cache_hit_ratio IS NOT NULL), 4) AS avg_index_cache_hit_ratio,
    (SELECT SUM(idx_scan) FROM pg_stat_user_indexes) AS total_index_scans,
    (SELECT SUM(seq_scan) FROM pg_stat_user_tables) AS total_seq_scans,
    CASE 
        WHEN (SELECT SUM(idx_scan) + SUM(seq_scan) FROM 
              (SELECT SUM(idx_scan) AS idx_scan, 0 AS seq_scan FROM pg_stat_user_indexes
               UNION ALL
               SELECT 0, SUM(seq_scan) FROM pg_stat_user_tables) t) > 0 THEN
            ROUND(((SELECT SUM(idx_scan) FROM pg_stat_user_indexes)::numeric / 
                   NULLIF((SELECT SUM(idx_scan) FROM pg_stat_user_indexes) + 
                          (SELECT SUM(seq_scan) FROM pg_stat_user_tables), 0))::numeric, 4)
        ELSE NULL
    END AS overall_index_usage_ratio,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'btree') AS btree_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'gin') AS gin_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'gist') AS gist_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'brin') AS brin_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'hash') AS hash_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE index_type = 'spgist') AS spgist_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE is_partial = true) AS partial_index_count,
    (SELECT COUNT(*) FROM pg_stat_insights_indexes WHERE is_expression = true) AS expression_index_count,
    (SELECT COUNT(*) FROM pg_stat_insights_missing_indexes) AS total_missing_indexes;

-- Index Alerts
CREATE VIEW pg_stat_insights_index_alerts AS
SELECT 
    'BLOAT' AS alert_type,
    'CRITICAL' AS severity,
    schemaname,
    tablename,
    indexname,
    'Index has significant bloat: ' || ROUND(estimated_bloat_size_mb, 2) || ' MB wasted space' AS alert_message,
    'REINDEX recommended to reclaim space and improve performance' AS impact,
    'REINDEX INDEX ' || quote_ident(schemaname) || '.' || quote_ident(indexname) || ';' AS recommended_action
FROM pg_stat_insights_index_bloat
WHERE bloat_severity = 'HIGH'
UNION ALL
SELECT 
    'UNUSED' AS alert_type,
    'WARNING' AS severity,
    schemaname,
    tablename,
    indexname,
    'Index has never been used (0 scans)' AS alert_message,
    'Index consumes storage and slows down writes without providing benefit' AS impact,
    'Consider dropping: DROP INDEX ' || quote_ident(schemaname) || '.' || quote_ident(indexname) || ';' AS recommended_action
FROM pg_stat_insights_index_usage
WHERE usage_status = 'NEVER_USED'
UNION ALL
SELECT 
    'INEFFICIENT' AS alert_type,
    'WARNING' AS severity,
    schemaname,
    tablename,
    indexname,
    'Index rarely used, sequential scans preferred (ratio: ' || ROUND(index_scan_ratio, 2) || ')' AS alert_message,
    'Index may not be optimal for query patterns' AS impact,
    'Review query patterns and consider index tuning or removal' AS recommended_action
FROM pg_stat_insights_index_efficiency
WHERE efficiency_rating IN ('POOR', 'UNUSED') AND seq_scans > 100
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    alert_type;

-- Index Dashboard
CREATE VIEW pg_stat_insights_index_dashboard AS
SELECT 
    'SUMMARY' AS section,
    NULL::text AS name,
    json_build_object(
        'total_indexes', (SELECT total_indexes FROM pg_stat_insights_index_summary),
        'total_size_mb', (SELECT total_index_size_mb FROM pg_stat_insights_index_summary),
        'active_indexes', (SELECT active_indexes FROM pg_stat_insights_index_summary),
        'unused_indexes', (SELECT unused_indexes FROM pg_stat_insights_index_summary),
        'bloated_indexes', (SELECT bloated_indexes FROM pg_stat_insights_index_summary),
        'critical_alerts', (SELECT COUNT(*) FROM pg_stat_insights_index_alerts WHERE severity = 'CRITICAL'),
        'warning_alerts', (SELECT COUNT(*) FROM pg_stat_insights_index_alerts WHERE severity = 'WARNING')
    ) AS details
UNION ALL
SELECT 
    'BLOAT' AS section,
    schemaname || '.' || indexname AS name,
    json_build_object(
        'tablename', tablename,
        'bloat_severity', bloat_severity,
        'bloat_size_mb', estimated_bloat_size_mb,
        'needs_reindex', needs_reindex
    ) AS details
FROM pg_stat_insights_index_bloat
WHERE bloat_severity IN ('HIGH', 'MEDIUM')
UNION ALL
SELECT 
    'UNUSED' AS section,
    schemaname || '.' || indexname AS name,
    json_build_object(
        'tablename', tablename,
        'usage_status', usage_status,
        'total_scans', total_scans,
        'recommendation', recommendation
    ) AS details
FROM pg_stat_insights_index_usage
WHERE usage_status IN ('NEVER_USED', 'RARE')
UNION ALL
SELECT 
    'ALERT' AS section,
    alert_type || ':' || schemaname || '.' || indexname AS name,
    json_build_object(
        'severity', severity,
        'tablename', tablename,
        'alert_message', alert_message,
        'recommended_action', recommended_action
    ) AS details
FROM pg_stat_insights_index_alerts
ORDER BY section, name;

-- Grant permissions on new index views
GRANT SELECT ON pg_stat_insights_indexes TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_usage TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_bloat TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_efficiency TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_maintenance TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_summary TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_alerts TO PUBLIC;
GRANT SELECT ON pg_stat_insights_index_dashboard TO PUBLIC;

-- ============================================================================
-- C Code Functions for Index Monitoring
-- ============================================================================

-- Capture index size snapshot
CREATE FUNCTION pg_stat_insights_index_size_snapshot()
RETURNS timestamp with time zone
AS 'MODULE_PATHNAME', 'pg_stat_insights_index_size_snapshot'
LANGUAGE C PARALLEL SAFE;

-- Get index size growth trends
CREATE FUNCTION pg_stat_insights_index_size_trends(IN indexrelid oid DEFAULT NULL)
RETURNS TABLE (
    indexrelid oid,
    size_bytes bigint,
    size_mb numeric,
    snapshot_time timestamp with time zone,
    growth_mb_per_day numeric
)
AS 'MODULE_PATHNAME', 'pg_stat_insights_index_size_trends'
LANGUAGE C PARALLEL SAFE;

-- Get index lock contention statistics
CREATE FUNCTION pg_stat_insights_index_lock_contention()
RETURNS TABLE (
    indexrelid oid,
    relid oid,
    lock_waits bigint,
    total_wait_time_ms bigint,
    avg_wait_time_ms numeric,
    last_wait_time timestamp with time zone
)
AS 'MODULE_PATHNAME', 'pg_stat_insights_index_lock_contention'
LANGUAGE C PARALLEL SAFE;

-- Index Size Growth Trends View (using C code)
CREATE VIEW pg_stat_insights_index_size_trends AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    t.indexrelid,
    t.size_bytes AS current_size_bytes,
    t.size_mb AS current_size_mb,
    t.snapshot_time,
    t.growth_mb_per_day,
    CASE 
        WHEN t.growth_mb_per_day > 10 THEN 'GROWING'
        WHEN t.growth_mb_per_day < -1 THEN 'SHRINKING'
        WHEN t.growth_mb_per_day BETWEEN -1 AND 1 THEN 'STABLE'
        ELSE 'VOLATILE'
    END AS growth_trend,
    CASE 
        WHEN t.growth_mb_per_day > 0 THEN
            ROUND((t.size_mb + (t.growth_mb_per_day * 30))::numeric, 2)
        ELSE t.size_mb
    END AS projected_size_mb_30days,
    CASE 
        WHEN t.growth_mb_per_day > 0 THEN
            ROUND((t.size_mb + (t.growth_mb_per_day * 90))::numeric, 2)
        ELSE t.size_mb
    END AS projected_size_mb_90days
FROM pg_stat_insights_index_size_trends() t
JOIN pg_stat_user_indexes i ON i.indexrelid = t.indexrelid
ORDER BY t.snapshot_time DESC, t.growth_mb_per_day DESC NULLS LAST;

GRANT SELECT ON pg_stat_insights_index_size_trends TO PUBLIC;

-- Index Lock Contention View (using C code)
CREATE VIEW pg_stat_insights_index_lock_contention AS
SELECT 
    i.schemaname,
    i.tablename,
    i.indexrelname AS indexname,
    l.indexrelid,
    l.relid,
    l.lock_waits,
    l.total_wait_time_ms,
    l.avg_wait_time_ms,
    l.last_wait_time,
    CASE 
        WHEN l.lock_waits > 1000 THEN 'CRITICAL'
        WHEN l.lock_waits > 100 THEN 'HIGH'
        WHEN l.lock_waits > 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS contention_severity
FROM pg_stat_insights_index_lock_contention() l
JOIN pg_stat_user_indexes i ON i.indexrelid = l.indexrelid
WHERE l.lock_waits > 0
ORDER BY l.lock_waits DESC, l.total_wait_time_ms DESC;

GRANT SELECT ON pg_stat_insights_index_lock_contention TO PUBLIC;
GRANT SELECT ON pg_stat_insights_missing_indexes TO PUBLIC;

