/*-------------------------------------------------------------------------
 *
 * pg_stat_insights--1.0.sql
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
      WHEN lag_bytes > 100000000 THEN 'HIGH_LAG'
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
