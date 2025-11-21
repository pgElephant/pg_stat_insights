/*-------------------------------------------------------------------------
 *
 * pg_stat_insights--2.0.sql
 *      Enhanced execution statistics of SQL statements
 * Copyright (c) 2024-2025, pgElephant, Inc.
 * Copyright (c) 2008-2025, PostgreSQL Global Development Group
 *
 *-------------------------------------------------------------------------
 */

\echo Use "CREATE EXTENSION pg_stat_insights" to load this file. \quit

-- Reset all statistics
CREATE FUNCTION pg_stat_insights_reset()
RETURNS void
AS 'MODULE_PATHNAME', 'pg_stat_insights_reset'
LANGUAGE C PARALLEL SAFE;

-- Reset specific query statistics
CREATE FUNCTION pg_stat_insights_reset(IN userid oid, IN dbid oid, IN queryid bigint)
RETURNS void
AS 'MODULE_PATHNAME', 'pg_stat_insights_reset_1_7'
LANGUAGE C PARALLEL SAFE;

-- Main statistics function (matches pg_stat_statements v1.12 output)
CREATE FUNCTION pg_stat_insights(IN showtext boolean,
    OUT userid oid,
    OUT dbid oid,
    OUT toplevel bool,
    OUT queryid bigint,
    OUT query text,
    OUT plans bigint,
    OUT total_plan_time float8,
    OUT min_plan_time float8,
    OUT max_plan_time float8,
    OUT mean_plan_time float8,
    OUT stddev_plan_time float8,
    OUT calls bigint,
    OUT total_exec_time float8,
    OUT min_exec_time float8,
    OUT max_exec_time float8,
    OUT mean_exec_time float8,
    OUT stddev_exec_time float8,
    OUT rows bigint,
    OUT shared_blks_hit bigint,
    OUT shared_blks_read bigint,
    OUT shared_blks_dirtied bigint,
    OUT shared_blks_written bigint,
    OUT local_blks_hit bigint,
    OUT local_blks_read bigint,
    OUT local_blks_dirtied bigint,
    OUT local_blks_written bigint,
    OUT temp_blks_read bigint,
    OUT temp_blks_written bigint,
    OUT shared_blk_read_time float8,
    OUT shared_blk_write_time float8,
    OUT local_blk_read_time float8,
    OUT local_blk_write_time float8,
    OUT temp_blk_read_time float8,
    OUT temp_blk_write_time float8,
    OUT wal_records bigint,
    OUT wal_fpi bigint,
    OUT wal_bytes numeric,
    OUT wal_buffers_full bigint,
    OUT jit_functions bigint,
    OUT jit_generation_time float8,
    OUT jit_inlining_count bigint,
    OUT jit_inlining_time float8,
    OUT jit_optimization_count bigint,
    OUT jit_optimization_time float8,
    OUT jit_emission_count bigint,
    OUT jit_emission_time float8,
    OUT jit_deform_count bigint,
    OUT jit_deform_time float8,
    OUT parallel_workers_to_launch bigint,
    OUT parallel_workers_launched bigint,
    OUT stats_since timestamp with time zone,
    OUT minmax_stats_since timestamp with time zone
)
RETURNS SETOF record
AS 'MODULE_PATHNAME', 'pg_stat_insights_1_12'
LANGUAGE C STRICT VOLATILE PARALLEL SAFE;

-- Replication stats function
CREATE FUNCTION pg_stat_insights_replication_stats()
RETURNS TABLE (
    pid int4,
    usename text,
    application_name text,
    client_addr text,
    repl_state text,
    sync_state text,
    sent_lsn text,
    write_lag_bytes int8,
    flush_lag_bytes int8,
    replay_lag_bytes int8,
    write_lag_seconds float8,
    flush_lag_seconds float8,
    replay_lag_seconds float8
)
LANGUAGE SQL
AS $$
  SELECT 
    pid,
    usename::text,
    application_name,
    client_addr::text,
    state::text AS repl_state,
    sync_state::text,
    sent_lsn::text,
    pg_wal_lsn_diff(sent_lsn, write_lsn) AS write_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, flush_lsn) AS flush_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
    EXTRACT(EPOCH FROM write_lag)::float8 AS write_lag_seconds,
    EXTRACT(EPOCH FROM flush_lag)::float8 AS flush_lag_seconds,
    EXTRACT(EPOCH FROM replay_lag)::float8 AS replay_lag_seconds
  FROM pg_stat_replication;
$$;

-- ============================================================================
-- Main Views
-- ============================================================================

CREATE VIEW pg_stat_insights AS
  SELECT * FROM pg_stat_insights(true);

CREATE VIEW pg_stat_insights_replication AS
  SELECT * FROM pg_stat_insights_replication_stats();

-- ============================================================================
-- Enhanced Replication Views
-- ============================================================================

-- Logical Replication Slots Statistics
CREATE VIEW pg_stat_insights_logical_replication AS
SELECT 
    s.slot_name,
    s.plugin,
    s.slot_type,
    s.database,
    s.active,
    s.active_pid,
    s.xmin::text,
    s.catalog_xmin::text,
    s.restart_lsn::text,
    s.confirmed_flush_lsn::text,
    s.wal_status,
    s.safe_wal_size,
    s.two_phase,
    s.conflicting,
    pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn)::int8 AS lag_bytes,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn)::numeric / 1024 / 1024), 2) AS lag_mb,
    (pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn)::numeric / 
     (SELECT setting::numeric FROM pg_settings WHERE name = 'wal_segment_size'))::int4 AS wal_files_retained
FROM pg_replication_slots s
WHERE s.slot_type = 'logical';

-- All Replication Slots (Physical + Logical) with Health Status
CREATE VIEW pg_stat_insights_replication_slots AS
SELECT 
    slot_name,
    plugin,
    slot_type,
    database,
    temporary,
    active,
    active_pid,
    xmin::text,
    catalog_xmin::text,
    restart_lsn::text,
    confirmed_flush_lsn::text,
    wal_status,
    safe_wal_size,
    two_phase,
    conflicting,
    pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))::int8 AS lag_bytes,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))::numeric / 1024 / 1024), 2) AS lag_mb,
    CASE 
      WHEN restart_lsn IS NOT NULL THEN
        (pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)::numeric / 
         (SELECT setting::numeric FROM pg_settings WHERE name = 'wal_segment_size'))::int4
      ELSE 0
    END AS wal_files_retained,
    CASE
      WHEN NOT active THEN 'INACTIVE'
      WHEN wal_status = 'lost' THEN 'CRITICAL'
      WHEN wal_status = 'unreserved' THEN 'WARNING'
      WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn)) > 100000000 THEN 'HIGH_LAG'
      ELSE 'HEALTHY'
    END AS health_status
FROM pg_replication_slots;

-- Physical Replication with Enhanced Metrics
CREATE VIEW pg_stat_insights_physical_replication AS
SELECT 
    r.pid,
    r.usename::text,
    r.application_name,
    r.client_addr::text,
    r.client_hostname,
    r.client_port,
    r.backend_start,
    EXTRACT(EPOCH FROM (now() - r.backend_start))::int8 AS uptime_seconds,
    r.backend_xmin::text,
    r.state AS repl_state,
    r.sync_state,
    r.sync_priority,
    r.sent_lsn::text,
    r.write_lsn::text,
    r.flush_lsn::text,
    r.replay_lsn::text,
    pg_wal_lsn_diff(r.sent_lsn, r.write_lsn)::int8 AS write_lag_bytes,
    pg_wal_lsn_diff(r.sent_lsn, r.flush_lsn)::int8 AS flush_lag_bytes,
    pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::int8 AS replay_lag_bytes,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.write_lsn)::numeric / 1024 / 1024), 2) AS write_lag_mb,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.flush_lsn)::numeric / 1024 / 1024), 2) AS flush_lag_mb,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 1024 / 1024), 2) AS replay_lag_mb,
    ROUND(EXTRACT(EPOCH FROM r.write_lag)::numeric, 3) AS write_lag_seconds,
    ROUND(EXTRACT(EPOCH FROM r.flush_lag)::numeric, 3) AS flush_lag_seconds,
    ROUND(EXTRACT(EPOCH FROM r.replay_lag)::numeric, 3) AS replay_lag_seconds,
    r.reply_time,
    EXTRACT(EPOCH FROM (now() - r.reply_time))::int8 AS last_msg_age_seconds,
    CASE
      WHEN r.state = 'streaming' AND r.replay_lag IS NOT NULL AND EXTRACT(EPOCH FROM r.replay_lag) < 5 THEN 'HEALTHY'
      WHEN r.state = 'streaming' AND r.replay_lag IS NOT NULL AND EXTRACT(EPOCH FROM r.replay_lag) < 30 THEN 'WARNING'
      WHEN r.state = 'streaming' THEN 'CRITICAL'
      WHEN r.state = 'catchup' THEN 'SYNCING'
      ELSE 'DISCONNECTED'
    END AS health_status
FROM pg_stat_replication r;

-- Replication Summary (Overview of All Replication Activity)
CREATE VIEW pg_stat_insights_replication_summary AS
SELECT 
    (SELECT COUNT(*) FROM pg_stat_replication) AS physical_replicas_connected,
    (SELECT COUNT(*) FROM pg_replication_slots WHERE slot_type = 'physical' AND active) AS physical_slots_active,
    (SELECT COUNT(*) FROM pg_replication_slots WHERE slot_type = 'logical' AND active) AS logical_slots_active,
    (SELECT COUNT(*) FROM pg_replication_slots WHERE NOT active) AS inactive_slots,
    (SELECT COUNT(*) FROM pg_replication_slots WHERE wal_status = 'lost') AS slots_with_lost_wal,
    (SELECT MAX(pg_wal_lsn_diff(sent_lsn, replay_lsn)) FROM pg_stat_replication) AS max_replay_lag_bytes,
    (SELECT ROUND(MAX(EXTRACT(EPOCH FROM replay_lag))::numeric, 2) FROM pg_stat_replication) AS max_replay_lag_seconds,
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM replay_lag))::numeric, 2) FROM pg_stat_replication) AS avg_replay_lag_seconds,
    pg_current_wal_lsn()::text AS current_wal_lsn,
    (SELECT SUM(pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))) 
     FROM pg_replication_slots)::int8 AS total_slot_lag_bytes,
    (SELECT COUNT(*) FROM pg_stat_replication WHERE state = 'streaming') AS streaming_replicas,
    (SELECT COUNT(*) FROM pg_stat_replication WHERE state = 'catchup') AS catchup_replicas,
    (SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state = 'sync') AS sync_replicas,
    (SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state = 'potential') AS potential_sync_replicas;

-- Replication Lag Alerts (Identify problematic replicas and slots)
CREATE VIEW pg_stat_insights_replication_alerts AS
SELECT 
    'PHYSICAL' AS replication_type,
    application_name AS identifier,
    client_addr::text AS source,
    CASE
        WHEN state != 'streaming' THEN 'CRITICAL: Not streaming'
        WHEN EXTRACT(EPOCH FROM replay_lag) > 300 THEN 'CRITICAL: Lag > 5 minutes'
        WHEN EXTRACT(EPOCH FROM replay_lag) > 60 THEN 'WARNING: Lag > 1 minute'
        WHEN EXTRACT(EPOCH FROM replay_lag) > 10 THEN 'INFO: Lag > 10 seconds'
        ELSE 'OK'
    END AS alert_level,
    ROUND(EXTRACT(EPOCH FROM replay_lag)::numeric, 2) AS lag_seconds,
    ROUND((pg_wal_lsn_diff(sent_lsn, replay_lsn)::numeric / 1024 / 1024), 2) AS lag_mb,
    state,
    sync_state,
    EXTRACT(EPOCH FROM (now() - reply_time))::int8 AS last_message_age_seconds
FROM pg_stat_replication
UNION ALL
SELECT 
    'LOGICAL' AS replication_type,
    slot_name AS identifier,
    database AS source,
    CASE
        WHEN NOT active THEN 'WARNING: Inactive'
        WHEN wal_status = 'lost' THEN 'CRITICAL: WAL lost'
        WHEN wal_status = 'unreserved' THEN 'WARNING: WAL unreserved'
        WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) > 1073741824 THEN 'CRITICAL: Lag > 1GB'
        WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) > 104857600 THEN 'WARNING: Lag > 100MB'
        ELSE 'OK'
    END AS alert_level,
    NULL::numeric AS lag_seconds,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)::numeric / 1024 / 1024), 2) AS lag_mb,
    CASE WHEN active THEN 'active' ELSE 'inactive' END AS state,
    plugin AS sync_state,
    NULL::int8 AS last_message_age_seconds
FROM pg_replication_slots
WHERE slot_type = 'logical'
ORDER BY alert_level DESC, lag_mb DESC NULLS LAST;

-- Replication WAL Statistics (Detailed WAL tracking)
CREATE VIEW pg_stat_insights_replication_wal AS
SELECT 
    pg_current_wal_lsn()::text AS current_wal_lsn,
    pg_current_wal_insert_lsn()::text AS current_wal_insert_lsn,
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::int8 AS total_wal_generated_bytes,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::numeric / 1024 / 1024 / 1024), 2) AS total_wal_generated_gb,
    (SELECT COUNT(*) FROM pg_ls_waldir()) AS wal_files_count,
    (SELECT COALESCE(SUM(size), 0) FROM pg_ls_waldir()) AS wal_total_size_bytes,
    ROUND((SELECT COALESCE(SUM(size), 0)::numeric FROM pg_ls_waldir()) / 1024 / 1024, 2) AS wal_total_size_mb,
    (SELECT setting FROM pg_settings WHERE name = 'wal_keep_size') AS wal_keep_size,
    (SELECT setting FROM pg_settings WHERE name = 'max_wal_size') AS max_wal_size,
    (SELECT setting FROM pg_settings WHERE name = 'min_wal_size') AS min_wal_size,
    (SELECT MIN(restart_lsn) FROM pg_replication_slots WHERE restart_lsn IS NOT NULL)::text AS oldest_slot_lsn,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), 
           (SELECT MIN(restart_lsn) FROM pg_replication_slots WHERE restart_lsn IS NOT NULL))::numeric / 1024 / 1024), 2) AS wal_retained_mb;

-- Replication Bottleneck Detection
CREATE VIEW pg_stat_insights_replication_bottlenecks AS
SELECT 
    r.application_name,
    r.client_addr::text,
    r.state,
    r.sync_state,
    CASE
        WHEN r.state != 'streaming' THEN 'Not streaming - check network/replica'
        WHEN pg_wal_lsn_diff(r.sent_lsn, r.write_lsn) > pg_wal_lsn_diff(r.write_lsn, r.flush_lsn) 
             AND pg_wal_lsn_diff(r.sent_lsn, r.write_lsn) > pg_wal_lsn_diff(r.flush_lsn, r.replay_lsn)
             THEN 'Network bottleneck - slow write'
        WHEN pg_wal_lsn_diff(r.write_lsn, r.flush_lsn) > pg_wal_lsn_diff(r.sent_lsn, r.write_lsn)
             AND pg_wal_lsn_diff(r.write_lsn, r.flush_lsn) > pg_wal_lsn_diff(r.flush_lsn, r.replay_lsn)
             THEN 'Disk I/O bottleneck - slow flush'
        WHEN pg_wal_lsn_diff(r.flush_lsn, r.replay_lsn) > pg_wal_lsn_diff(r.sent_lsn, r.write_lsn)
             AND pg_wal_lsn_diff(r.flush_lsn, r.replay_lsn) > pg_wal_lsn_diff(r.write_lsn, r.flush_lsn)
             THEN 'Replay bottleneck - slow apply'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 30 THEN 'High lag - investigate replica load'
        ELSE 'No bottleneck detected'
    END AS bottleneck_type,
    pg_wal_lsn_diff(r.sent_lsn, r.write_lsn)::int8 AS write_lag_bytes,
    pg_wal_lsn_diff(r.write_lsn, r.flush_lsn)::int8 AS flush_lag_bytes,
    pg_wal_lsn_diff(r.flush_lsn, r.replay_lsn)::int8 AS replay_lag_bytes,
    ROUND(EXTRACT(EPOCH FROM r.write_lag)::numeric, 3) AS write_lag_sec,
    ROUND(EXTRACT(EPOCH FROM r.flush_lag)::numeric, 3) AS flush_lag_sec,
    ROUND(EXTRACT(EPOCH FROM r.replay_lag)::numeric, 3) AS replay_lag_sec,
    ROUND(EXTRACT(EPOCH FROM (now() - r.reply_time))::numeric, 1) AS last_msg_age_sec,
    r.backend_xmin::text,
    EXTRACT(EPOCH FROM (now() - r.backend_start))::int8 AS connection_age_sec
FROM pg_stat_replication r;

-- Replication Conflict Detection (For logical replication)
CREATE VIEW pg_stat_insights_replication_conflicts AS
SELECT 
    s.slot_name,
    s.database,
    s.plugin,
    s.conflicting,
    s.wal_status,
    CASE 
        WHEN s.conflicting THEN 'CONFLICT: Slot has unresolved conflicts'
        WHEN s.wal_status = 'lost' THEN 'CRITICAL: Required WAL segments lost'
        WHEN s.wal_status = 'unreserved' THEN 'WARNING: WAL not reserved, may be removed'
        WHEN NOT s.active AND s.confirmed_flush_lsn IS NOT NULL 
             AND pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn) > 1073741824
             THEN 'WARNING: Inactive slot with >1GB lag'
        ELSE 'OK'
    END AS conflict_status,
    s.active,
    s.xmin::text,
    s.catalog_xmin::text,
    pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn)::int8 AS lag_bytes,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn)::numeric / 1024 / 1024), 2) AS lag_mb,
    s.safe_wal_size,
    CASE 
        WHEN s.safe_wal_size < 0 THEN 'CRITICAL: Exceeding wal_keep_size'
        WHEN s.safe_wal_size < 104857600 THEN 'WARNING: Less than 100MB safe WAL'
        ELSE 'OK'
    END AS wal_safety_status,
    (pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn)::numeric / 
     (SELECT setting::numeric FROM pg_settings WHERE name = 'wal_segment_size'))::int4 AS wal_files_held
FROM pg_replication_slots s
WHERE s.slot_type = 'logical';

-- Replication Performance Trends (Lag over time estimation)
CREATE VIEW pg_stat_insights_replication_performance AS
SELECT 
    r.application_name,
    r.client_addr::text,
    r.state,
    r.sync_state,
    r.sent_lsn::text,
    r.replay_lsn::text,
    pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::int8 AS current_lag_bytes,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 1024 / 1024), 2) AS current_lag_mb,
    ROUND(EXTRACT(EPOCH FROM r.replay_lag)::numeric, 2) AS current_lag_seconds,
    EXTRACT(EPOCH FROM (now() - r.backend_start))::int8 AS uptime_seconds,
    CASE 
        WHEN EXTRACT(EPOCH FROM (now() - r.backend_start)) > 0 THEN
            ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 
                   EXTRACT(EPOCH FROM (now() - r.backend_start))), 2)
        ELSE 0
    END AS avg_lag_bytes_per_second,
    CASE
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 0 THEN
            ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 
                   EXTRACT(EPOCH FROM r.replay_lag)), 2)
        ELSE 0
    END AS replay_rate_bytes_per_second,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 
           EXTRACT(EPOCH FROM r.replay_lag))::numeric / 1024 / 1024, 2) AS replay_rate_mb_per_second,
    CASE
        WHEN EXTRACT(EPOCH FROM r.replay_lag) < 1 THEN 'Excellent (<1s)'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) < 5 THEN 'Good (<5s)'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) < 30 THEN 'Fair (<30s)'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) < 300 THEN 'Poor (<5min)'
        ELSE 'Critical (>5min)'
    END AS performance_rating
FROM pg_stat_replication r
WHERE r.replay_lag IS NOT NULL;

-- Replication Slot Health Check (Comprehensive diagnostics)
CREATE VIEW pg_stat_insights_replication_health AS
SELECT 
    slot_name,
    slot_type,
    database,
    plugin,
    active,
    temporary,
    wal_status,
    CASE 
        WHEN wal_status = 'lost' THEN 'CRITICAL'
        WHEN NOT active AND slot_type = 'logical' THEN 'WARNING'
        WHEN conflicting THEN 'WARNING'
        WHEN safe_wal_size < 0 THEN 'CRITICAL'
        WHEN safe_wal_size < 104857600 THEN 'WARNING'
        WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn)) > 1073741824 THEN 'WARNING'
        ELSE 'OK'
    END AS overall_health,
    ARRAY[
        CASE WHEN NOT active THEN 'Slot inactive' ELSE NULL END,
        CASE WHEN wal_status = 'lost' THEN 'WAL segments lost' ELSE NULL END,
        CASE WHEN wal_status = 'unreserved' THEN 'WAL not reserved' ELSE NULL END,
        CASE WHEN conflicting THEN 'Has conflicts' ELSE NULL END,
        CASE WHEN safe_wal_size < 0 THEN 'Exceeding wal_keep_size' ELSE NULL END,
        CASE WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn)) > 1073741824 
             THEN 'Lag exceeds 1GB' ELSE NULL END,
        CASE WHEN temporary THEN 'Temporary slot' ELSE NULL END
    ]::text[] AS issues,
    pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))::int8 AS lag_bytes,
    ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))::numeric / 1024 / 1024), 2) AS lag_mb,
    (pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)::numeric / 
     (SELECT setting::numeric FROM pg_settings WHERE name = 'wal_segment_size'))::int4 AS wal_files_held,
    safe_wal_size,
    ROUND((safe_wal_size::numeric / 1024 / 1024), 2) AS safe_wal_size_mb,
    CASE
        WHEN NOT active THEN 'Activate the subscription or drop the slot'
        WHEN wal_status = 'lost' THEN 'Rebuild subscription - required WAL lost'
        WHEN wal_status = 'unreserved' THEN 'Increase wal_keep_size or max_slot_wal_keep_size'
        WHEN safe_wal_size < 104857600 THEN 'Monitor closely - approaching WAL limit'
        WHEN ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), COALESCE(confirmed_flush_lsn, restart_lsn))::numeric / 1024 / 1024), 2) > 1024 THEN 'Investigate subscriber lag - consider parallel apply'
        ELSE NULL
    END AS recommendation
FROM pg_replication_slots;

-- Replication Timeline Analysis
CREATE VIEW pg_stat_insights_replication_timeline AS
SELECT 
    r.application_name,
    r.client_addr::text,
    r.backend_start,
    EXTRACT(EPOCH FROM (now() - r.backend_start))::int8 AS connected_for_seconds,
    ROUND((EXTRACT(EPOCH FROM (now() - r.backend_start))::numeric / 3600), 2) AS connected_for_hours,
    r.sent_lsn::text,
    r.replay_lsn::text,
    pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::int8 AS replay_lag_bytes,
    ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 1024 / 1024), 2) AS replay_lag_mb,
    ROUND(EXTRACT(EPOCH FROM r.replay_lag)::numeric, 2) AS replay_lag_seconds,
    CASE 
        WHEN EXTRACT(EPOCH FROM (now() - r.backend_start)) > 0 AND pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn) > 0 THEN
            ROUND(((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 1024 / 1024) / 
                   (EXTRACT(EPOCH FROM (now() - r.backend_start))::numeric / 3600)), 2)
        ELSE 0
    END AS avg_lag_mb_per_hour,
    CASE
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 0 THEN
            ROUND((pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn)::numeric / 
                   EXTRACT(EPOCH FROM r.replay_lag)::numeric / 1024), 2)
        ELSE 0
    END AS replay_throughput_kb_per_sec,
    r.reply_time,
    EXTRACT(EPOCH FROM (now() - r.reply_time))::int8 AS heartbeat_age_seconds,
    CASE
        WHEN EXTRACT(EPOCH FROM (now() - r.reply_time)) > 60 THEN 'Replica not responding'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 300 THEN 'Severe lag - investigate immediately'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 60 THEN 'Moderate lag - monitor closely'
        WHEN EXTRACT(EPOCH FROM r.replay_lag) > 10 THEN 'Minor lag - acceptable'
        ELSE 'Healthy replication'
    END AS status_message
FROM pg_stat_replication r;

-- Logical Replication Subscriptions (Subscriber side monitoring)
CREATE VIEW pg_stat_insights_subscriptions AS
SELECT 
    s.subname AS subscription_name,
    s.oid::int4 AS subscription_oid,
    d.datname AS database,
    CASE s.subenabled WHEN true THEN 'enabled' ELSE 'disabled' END AS status,
    s.subconninfo AS connection_info,
    s.subslotname AS slot_name,
    s.subsynccommit AS sync_commit,
    s.subpublications AS publications,
    CASE 
        WHEN NOT s.subenabled THEN 'Subscription disabled'
        WHEN s.subslotname IS NULL THEN 'No replication slot'
        ELSE 'Active'
    END AS health_status,
    CASE
        WHEN NOT s.subenabled THEN 'Enable subscription: ALTER SUBSCRIPTION ' || s.subname || ' ENABLE'
        WHEN s.subslotname IS NULL THEN 'Create slot or set slot_name'
        ELSE NULL
    END AS recommendation
FROM pg_subscription s
JOIN pg_database d ON d.oid = s.subdbid;

-- Logical Replication Subscription Statistics
CREATE VIEW pg_stat_insights_subscription_stats AS
SELECT 
    sr.srsubid AS subid,
    s.subname AS subscription_name,
    sr.srrelid AS relid,
    n.nspname || '.' || c.relname AS table_name,
    sr.srsubstate AS sync_state,
    sr.srsublsn::text AS subscription_lsn,
    CASE sr.srsubstate
        WHEN 'i' THEN 'Initialize'
        WHEN 'd' THEN 'Data copy'
        WHEN 's' THEN 'Synchronized'
        WHEN 'r' THEN 'Ready'
        ELSE 'Unknown'
    END AS sync_state_description,
    CASE
        WHEN sr.srsubstate = 's' THEN 'Fully synchronized'
        WHEN sr.srsubstate = 'r' THEN 'Ready for sync'
        WHEN sr.srsubstate = 'd' THEN 'Copying initial data'
        WHEN sr.srsubstate = 'i' THEN 'Initializing'
        ELSE 'Check subscription status'
    END AS status_message
FROM pg_subscription_rel sr
JOIN pg_subscription s ON s.oid = sr.srsubid
JOIN pg_class c ON c.oid = sr.srrelid
JOIN pg_namespace n ON n.oid = c.relnamespace;

-- Logical Replication Publications (Publisher side monitoring)
CREATE VIEW pg_stat_insights_publications AS
SELECT 
    p.pubname AS publication_name,
    p.oid::int4 AS publication_oid,
    d.datname AS database,
    CASE p.puballtables WHEN true THEN 'All tables' ELSE 'Selected tables' END AS scope,
    CASE p.pubinsert WHEN true THEN 'INSERT' ELSE '' END ||
    CASE WHEN p.pubinsert AND (p.pubupdate OR p.pubdelete OR p.pubtruncate) THEN ', ' ELSE '' END ||
    CASE p.pubupdate WHEN true THEN 'UPDATE' ELSE '' END ||
    CASE WHEN p.pubupdate AND (p.pubdelete OR p.pubtruncate) THEN ', ' ELSE '' END ||
    CASE p.pubdelete WHEN true THEN 'DELETE' ELSE '' END ||
    CASE WHEN p.pubdelete AND p.pubtruncate THEN ', ' ELSE '' END ||
    CASE p.pubtruncate WHEN true THEN 'TRUNCATE' ELSE '' END AS operations,
    CASE p.pubviaroot WHEN true THEN 'Via root' ELSE 'Direct' END AS partition_mode,
    (SELECT COUNT(*) FROM pg_publication_tables pt WHERE pt.pubname = p.pubname) AS table_count,
    (SELECT COUNT(*) FROM pg_replication_slots rs WHERE rs.database = d.datname) AS active_subscribers
FROM pg_publication p
JOIN pg_database d ON d.datname = current_database();

-- Replication Origin Tracking (For cascading and bidirectional replication)
CREATE VIEW pg_stat_insights_replication_origins AS
SELECT 
    o.roident::int4 AS origin_id,
    o.roname AS origin_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_replication_origin_status WHERE local_id = o.roident) THEN true
        ELSE false
    END AS session_active,
    COALESCE(pg_replication_origin_progress(o.roname, false)::text, 'No progress') AS remote_lsn,
    COALESCE(pg_replication_origin_progress(o.roname, true)::text, 'No progress') AS local_lsn,
    CASE 
        WHEN pg_replication_origin_progress(o.roname, false) IS NOT NULL THEN
            pg_wal_lsn_diff(pg_current_wal_lsn(), pg_replication_origin_progress(o.roname, false))::int8
        ELSE 0
    END AS lag_bytes,
    CASE 
        WHEN pg_replication_origin_progress(o.roname, false) IS NOT NULL THEN
            ROUND((pg_wal_lsn_diff(pg_current_wal_lsn(), pg_replication_origin_progress(o.roname, false))::numeric / 1024 / 1024), 2)
        ELSE 0
    END AS lag_mb
FROM pg_replication_origin o;

-- Replication Diagnostics Dashboard (Single comprehensive view)
CREATE VIEW pg_stat_insights_replication_dashboard AS
SELECT 
    'CLUSTER_SUMMARY' AS section,
    NULL::text AS name,
    json_build_object(
        'physical_replicas', (SELECT COUNT(*) FROM pg_stat_replication),
        'logical_slots', (SELECT COUNT(*) FROM pg_replication_slots WHERE slot_type = 'logical'),
        'active_subscriptions', (SELECT COUNT(*) FROM pg_subscription WHERE subenabled),
        'active_publications', (SELECT COUNT(*) FROM pg_publication),
        'max_lag_seconds', (SELECT ROUND(MAX(EXTRACT(EPOCH FROM replay_lag))::numeric, 2) FROM pg_stat_replication),
        'critical_alerts', (SELECT COUNT(*) FROM pg_stat_insights_replication_alerts WHERE alert_level LIKE 'CRITICAL%'),
        'warning_alerts', (SELECT COUNT(*) FROM pg_stat_insights_replication_alerts WHERE alert_level LIKE 'WARNING%')
    ) AS details
UNION ALL
SELECT 
    'PHYSICAL_REPLICA' AS section,
    application_name AS name,
    json_build_object(
        'client_addr', client_addr,
        'state', repl_state,
        'sync_state', sync_state,
        'health_status', health_status,
        'replay_lag_mb', replay_lag_mb,
        'replay_lag_seconds', replay_lag_seconds,
        'uptime_hours', ROUND((uptime_seconds::numeric / 3600), 1)
    ) AS details
FROM pg_stat_insights_physical_replication
UNION ALL
SELECT 
    'LOGICAL_SLOT' AS section,
    slot_name AS name,
    json_build_object(
        'database', database,
        'plugin', plugin,
        'active', active,
        'wal_status', wal_status,
        'lag_mb', lag_mb,
        'wal_files_retained', wal_files_retained
    ) AS details
FROM pg_stat_insights_logical_replication
UNION ALL
SELECT 
    'ALERT' AS section,
    identifier AS name,
    json_build_object(
        'replication_type', replication_type,
        'alert_level', alert_level,
        'lag_mb', lag_mb,
        'state', state
    ) AS details
FROM pg_stat_insights_replication_alerts
WHERE alert_level NOT LIKE 'OK%'
ORDER BY section, name;

-- ============================================================================
-- Helper Views - Performance Analysis
-- ============================================================================

-- Top queries by total execution time
CREATE VIEW pg_stat_insights_top_by_time AS
  SELECT * FROM pg_stat_insights
  ORDER BY total_exec_time DESC
  LIMIT 100;

-- Top queries by number of calls
CREATE VIEW pg_stat_insights_top_by_calls AS
  SELECT * FROM pg_stat_insights
  ORDER BY calls DESC
  LIMIT 100;

-- Top queries by I/O (blocks read)
CREATE VIEW pg_stat_insights_top_by_io AS
  SELECT * FROM pg_stat_insights
  ORDER BY (shared_blks_read + local_blks_read + temp_blks_read) DESC
  LIMIT 100;

-- Queries with poor cache performance
CREATE VIEW pg_stat_insights_top_cache_misses AS
  SELECT *,
    CASE 
      WHEN (shared_blks_hit + shared_blks_read) > 0 
      THEN (shared_blks_hit::numeric / (shared_blks_hit + shared_blks_read))
      ELSE 0
    END AS cache_hit_ratio
  FROM pg_stat_insights
  WHERE shared_blks_read > 100
  ORDER BY (shared_blks_hit::numeric / NULLIF(shared_blks_hit + shared_blks_read, 0)) ASC
  LIMIT 100;

-- Slow queries (mean exec time > 100ms)
CREATE VIEW pg_stat_insights_slow_queries AS
  SELECT * FROM pg_stat_insights
  WHERE mean_exec_time > 100
  ORDER BY mean_exec_time DESC
  LIMIT 100;

-- Queries with errors (placeholder - actual error tracking requires C code)
CREATE VIEW pg_stat_insights_errors AS
  SELECT * FROM pg_stat_insights
  WHERE calls = 0  -- Placeholder condition
  LIMIT 100;

-- Plan estimation errors (placeholder - requires plan tracking in C code)
CREATE VIEW pg_stat_insights_plan_errors AS
  SELECT * FROM pg_stat_insights
  WHERE calls = 0  -- Placeholder condition
  LIMIT 100;

-- Response time distribution summary
CREATE VIEW pg_stat_insights_histogram_summary AS
  SELECT 
    userid,
    dbid,
    queryid,
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    min_exec_time,
    max_exec_time,
    stddev_exec_time,
    CASE 
      WHEN mean_exec_time < 1 THEN '<1ms'
      WHEN mean_exec_time < 10 THEN '1-10ms'
      WHEN mean_exec_time < 100 THEN '10-100ms'
      WHEN mean_exec_time < 1000 THEN '100ms-1s'
      WHEN mean_exec_time < 10000 THEN '1-10s'
      ELSE '>10s'
    END AS response_time_category,
    CASE 
      WHEN (shared_blks_hit + shared_blks_read) > 0 
      THEN ROUND((shared_blks_hit::numeric / (shared_blks_hit + shared_blks_read))::numeric, 4)
      ELSE 0
    END AS cache_hit_ratio,
    shared_blks_hit + shared_blks_read AS total_blocks,
    wal_records,
    wal_bytes
  FROM pg_stat_insights
  WHERE calls > 0
  ORDER BY calls DESC
  LIMIT 100;

-- Query performance by time bucket (statistics since timestamp)
CREATE VIEW pg_stat_insights_by_bucket AS
  SELECT 
    queryid,
    userid,
    dbid,
    LEFT(query, 100) AS query_preview,
    calls AS total_calls,
    total_exec_time,
    mean_exec_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    wal_records,
    wal_bytes,
    stats_since AS stats_start_time,
    CASE 
      WHEN (shared_blks_hit + shared_blks_read) > 0 
      THEN ROUND((shared_blks_hit::numeric / (shared_blks_hit + shared_blks_read))::numeric, 4)
      ELSE NULL
    END AS cache_hit_ratio
  FROM pg_stat_insights
  WHERE calls > 0
  ORDER BY total_exec_time DESC
  LIMIT 100;

-- Grant permissions
GRANT SELECT ON pg_stat_insights TO PUBLIC;
GRANT SELECT ON pg_stat_insights_replication TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_time TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_calls TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_io TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_cache_misses TO PUBLIC;
GRANT SELECT ON pg_stat_insights_slow_queries TO PUBLIC;
GRANT SELECT ON pg_stat_insights_errors TO PUBLIC;
GRANT SELECT ON pg_stat_insights_plan_errors TO PUBLIC;
GRANT SELECT ON pg_stat_insights_histogram_summary TO PUBLIC;
GRANT SELECT ON pg_stat_insights_by_bucket TO PUBLIC;
