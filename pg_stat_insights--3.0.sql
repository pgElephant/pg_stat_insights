/*-------------------------------------------------------------------------
 *
 * pg_stat_insights--3.0.sql
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
    COALESCE(
        (SELECT remote_lsn::text FROM pg_replication_origin_status WHERE local_id = o.roident LIMIT 1),
        'No progress'
    ) AS remote_lsn,
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

-- ============================================================================
-- Index Monitoring Views
-- ============================================================================

-- Index Bloat Estimation
CREATE VIEW pg_stat_insights_index_bloat AS
SELECT 
    i.schemaname,
    i.relname AS tablename,
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
    (CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 2.0 THEN
            ROUND(((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size') - 1.0) * 
                  (pg_relation_size(i.indexrelid) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::numeric / 1024 / 1024, 2)
        ELSE 0
    END) * 1024 * 1024 AS estimated_bloat_size_bytes,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 THEN
            (pg_relation_size(i.indexrelid) / 
             (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::int8
        ELSE NULL
    END AS expected_pages,
    CASE 
        WHEN pg_relation_size(i.indexrelid) > 0 AND i.idx_tup_read > 0 AND
             ((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
              (SELECT setting::int FROM pg_settings WHERE name = 'block_size')) > 2.0 THEN
            (ROUND(((pg_relation_size(i.indexrelid)::numeric / NULLIF(i.idx_tup_read, 0)) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size') - 1.0) * 
                  (pg_relation_size(i.indexrelid) / 
                   (SELECT setting::int FROM pg_settings WHERE name = 'block_size'))::numeric / 1024 / 1024, 2) * 1024 * 1024 / 
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

-- Comprehensive Index Statistics
CREATE VIEW pg_stat_insights_indexes AS
SELECT 
    i.schemaname,
    i.relname AS tablename,
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
    io.idx_blks_read,
    io.idx_blks_hit,
    CASE 
        WHEN (io.idx_blks_read + io.idx_blks_hit) > 0 
        THEN ROUND((io.idx_blks_hit::numeric / (io.idx_blks_read + io.idx_blks_hit))::numeric, 4)
        ELSE NULL
    END AS idx_cache_hit_ratio,
    (SELECT CASE 
        WHEN (t.heap_blks_read + t.heap_blks_hit) > 0 
        THEN ROUND((t.heap_blks_hit::numeric / (t.heap_blks_read + t.heap_blks_hit))::numeric, 4)
        ELSE NULL
    END FROM pg_statio_user_tables t WHERE t.relid = i.relid) AS heap_cache_hit_ratio,
    am.amname AS index_type,
    CASE WHEN idx.indisunique THEN true ELSE false END AS is_unique,
    CASE WHEN idx.indisprimary THEN true ELSE false END AS is_primary,
    CASE WHEN idx.indpred IS NOT NULL THEN true ELSE false END AS is_partial,
    CASE WHEN idx.indexprs IS NOT NULL THEN true ELSE false END AS is_expression,
    COALESCE(c.reloptions, ARRAY[]::text[]) AS index_options,
    pg_get_indexdef(i.indexrelid) AS indexdef,
    NULL::int8 AS index_age_days,
    (SELECT estimated_bloat_ratio FROM pg_stat_insights_index_bloat bloat 
     WHERE bloat.schemaname = i.schemaname AND bloat.tablename = i.relname 
     AND bloat.indexname = i.indexrelname LIMIT 1) AS bloat_ratio,
    (SELECT estimated_bloat_size_mb FROM pg_stat_insights_index_bloat bloat 
     WHERE bloat.schemaname = i.schemaname AND bloat.tablename = i.relname 
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
               AND s.tablename = i.relname 
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
    i.relname AS tablename,
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

-- Index Efficiency Analysis
CREATE VIEW pg_stat_insights_index_efficiency AS
SELECT 
    i.schemaname,
    i.relname AS tablename,
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
    i.relname AS tablename,
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
            'VACUUM ANALYZE ' || quote_ident(i.schemaname) || '.' || quote_ident(i.relname) || ';'
        WHEN t.last_analyze IS NULL THEN
            'ANALYZE ' || quote_ident(i.schemaname) || '.' || quote_ident(i.relname) || ';'
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
    bloat.tablename = i.relname AND 
    bloat.indexname = i.indexrelname;

-- Missing Index Recommendations
CREATE VIEW pg_stat_insights_missing_indexes AS
SELECT 
    t.schemaname,
    t.relname AS tablename,
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
SELECT * FROM (
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
) AS alerts
ORDER BY 
    CASE alerts.severity WHEN 'CRITICAL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    alerts.alert_type;

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
    i.relname AS tablename,
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
    i.relname AS tablename,
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
