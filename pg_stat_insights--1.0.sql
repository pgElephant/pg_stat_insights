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

-- Reset function
CREATE FUNCTION pg_stat_insights_reset()
RETURNS void
AS 'MODULE_PATHNAME', 'pg_stat_statements_reset'
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
AS 'MODULE_PATHNAME', 'pg_stat_statements_1_12'
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
