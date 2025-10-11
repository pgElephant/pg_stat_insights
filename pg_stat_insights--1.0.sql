/*-------------------------------------------------------------------------
 *
 * pg_stat_insights--1.0.sql
 *      Enhanced execution statistics of SQL statements
 * Copyright (c) 2024-2025, pgElephant, Inc.
 * Copyright (c) 2008-2025, PostgreSQL Global Development Group
 *
 * IDENTIFICATION
 *	  contrib/pg_stat_insights/pg_stat_insights--1.0.sql
 *
 *-------------------------------------------------------------------------
 */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_stat_insights" to load this file. \quit

-- ============================================================================
-- Core Functions
-- ============================================================================

CREATE FUNCTION pg_stat_insights_reset()
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C PARALLEL SAFE;

CREATE FUNCTION pg_stat_insights(IN showtext boolean,
    -- Core identification
    OUT userid oid,
    OUT dbid oid,
    OUT queryid bigint,
    OUT query text,
    
    -- Execution statistics
    OUT calls int8,
    OUT total_exec_time float8,
    OUT min_exec_time float8,
    OUT max_exec_time float8,
    OUT mean_exec_time float8,
    OUT stddev_exec_time float8,
    
    -- Row statistics
    OUT rows_retrieved int8,
    
    -- Buffer/Cache statistics
    OUT shared_blks_hit int8,
    OUT shared_blks_read int8,
    OUT shared_blks_dirtied int8,
    OUT shared_blks_written int8,
    OUT local_blks_hit int8,
    OUT local_blks_read int8,
    OUT local_blks_dirtied int8,
    OUT local_blks_written int8,
    OUT temp_blks_read int8,
    OUT temp_blks_written int8,
    
    -- I/O timing
    OUT blk_read_time float8,
    OUT blk_write_time float8,
    
    -- Query characteristics
    OUT query_complexity int4,
    OUT query_length int4,
    OUT param_count int4,
    
    -- Plan statistics
    OUT plan_type int4,
    OUT plan_cost float8,
    OUT plan_rows_estimated int8,
    OUT plan_rows_actual int8,
    OUT plan_accuracy_ratio float8,
    
    -- Wait events and locks
    OUT wait_event text,
    OUT lock_count int4,
    
    -- Temporary files
    OUT temp_file_count int8,
    
    -- Cache efficiency
    OUT cache_hit_ratio float8,
    
    -- Error tracking
    OUT error_count int4,
    OUT last_error_message text,
    
    -- Percentile statistics
    OUT exec_time_p50 float8,
    OUT exec_time_p95 float8,
    OUT exec_time_p99 float8,
    
    -- Resource usage
    OUT memory_usage_bytes int8,
    
    -- Session information
    OUT application_name text,
    OUT backend_pid int4,
    OUT transaction_id int8,
    OUT retry_count int4,
    OUT client_ip inet,
    
    -- Query metadata
    OUT relations_accessed text,
    OUT cmd_type int4,
    OUT cmd_type_text text,
    
    -- Histogram (response time distribution)
    OUT resp_calls_under_1ms int8,
    OUT resp_calls_1_to_10ms int8,
    OUT resp_calls_10_to_100ms int8,
    OUT resp_calls_100ms_to_1s int8,
    OUT resp_calls_1_to_10s int8,
    OUT resp_calls_10_to_60s int8,
    OUT resp_calls_1_to_5min int8,
    OUT resp_calls_5_to_10min int8,
    OUT resp_calls_10_to_30min int8,
    OUT resp_calls_over_30min int8,
    
    -- Bucket tracking
    OUT bucket_id int8,
    OUT bucket_start_time timestamptz,
    
    -- Query plan text (if enabled)
    OUT query_plan_text text,
    
    -- Actual parameters (if enabled)
    OUT query_parameters text,
    
    -- SQL comments
    OUT sql_comments text,
    
    -- State tracking
    OUT state_change_count int4,
    OUT first_seen timestamptz,
    OUT last_executed timestamptz
)
RETURNS SETOF record
AS 'MODULE_PATHNAME', 'pg_stat_insights_1_14'
LANGUAGE C STRICT VOLATILE PARALLEL SAFE;

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
AS 'MODULE_PATHNAME', 'pg_stat_insights_replication_stats'
LANGUAGE C STRICT VOLATILE PARALLEL SAFE;

-- ============================================================================
-- Main Views
-- ============================================================================

CREATE VIEW pg_stat_insights AS
  SELECT * FROM pg_stat_insights(true);

CREATE VIEW pg_stat_insights_replication AS
  SELECT * FROM pg_stat_insights_replication_stats();

-- ============================================================================
-- Top Queries Helper Views
-- ============================================================================

-- Top queries by total execution time
CREATE VIEW pg_stat_insights_top_by_time AS
  SELECT 
    queryid,
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows_retrieved,
    cache_hit_ratio,
    application_name
  FROM pg_stat_insights
  ORDER BY total_exec_time DESC
  LIMIT 100;

-- Top queries by call count
CREATE VIEW pg_stat_insights_top_by_calls AS
  SELECT 
    queryid,
    query,
    calls,
    mean_exec_time,
    rows_retrieved,
    cache_hit_ratio
  FROM pg_stat_insights
  ORDER BY calls DESC
  LIMIT 100;

-- Top queries by I/O (buffer reads)
CREATE VIEW pg_stat_insights_top_by_io AS
  SELECT 
    queryid,
    query,
    calls,
    shared_blks_read + local_blks_read AS total_blks_read,
    shared_blks_hit,
    cache_hit_ratio,
    blk_read_time
  FROM pg_stat_insights
  ORDER BY (shared_blks_read + local_blks_read) DESC
  LIMIT 100;

-- Top queries by cache misses
CREATE VIEW pg_stat_insights_top_cache_misses AS
  SELECT 
    queryid,
    query,
    calls,
    shared_blks_read,
    shared_blks_hit,
    cache_hit_ratio,
    (1.0 - cache_hit_ratio) * 100 AS cache_miss_percent
  FROM pg_stat_insights
  WHERE shared_blks_read > 0
  ORDER BY shared_blks_read DESC
  LIMIT 100;

-- Queries with plan estimation errors
CREATE VIEW pg_stat_insights_plan_errors AS
  SELECT 
    queryid,
    query,
    calls,
    plan_rows_estimated,
    plan_rows_actual,
    plan_accuracy_ratio,
    CASE 
      WHEN plan_accuracy_ratio > 2.0 THEN 'severe_overestimate'
      WHEN plan_accuracy_ratio > 1.5 THEN 'moderate_overestimate'
      WHEN plan_accuracy_ratio < 0.5 THEN 'severe_underestimate'
      WHEN plan_accuracy_ratio < 0.7 THEN 'moderate_underestimate'
      ELSE 'acceptable'
    END AS estimation_quality
  FROM pg_stat_insights
  WHERE plan_rows_estimated > 0 AND plan_rows_actual > 0
    AND ABS(plan_accuracy_ratio - 1.0) > 0.3
  ORDER BY ABS(plan_accuracy_ratio - 1.0) DESC
  LIMIT 100;

-- Slow queries (p95 > 100ms)
CREATE VIEW pg_stat_insights_slow_queries AS
  SELECT 
    queryid,
    query,
    calls,
    exec_time_p50,
    exec_time_p95,
    exec_time_p99,
    mean_exec_time,
    wait_event,
    lock_count
  FROM pg_stat_insights
  WHERE exec_time_p95 > 100.0
  ORDER BY exec_time_p95 DESC
  LIMIT 100;

-- Queries with errors
CREATE VIEW pg_stat_insights_errors AS
  SELECT 
    queryid,
    query,
    calls,
    error_count,
    last_error_message,
    retry_count,
    last_executed
  FROM pg_stat_insights
  WHERE error_count > 0
  ORDER BY error_count DESC
  LIMIT 100;

-- Histogram summary view (response time distribution analysis)
CREATE VIEW pg_stat_insights_histogram_summary AS
  SELECT 
    queryid,
    query,
    calls AS total_calls,
    resp_calls_under_1ms,
    resp_calls_1_to_10ms,
    resp_calls_10_to_100ms,
    resp_calls_100ms_to_1s,
    resp_calls_1_to_10s,
    resp_calls_10_to_60s,
    resp_calls_1_to_5min,
    resp_calls_5_to_10min,
    resp_calls_10_to_30min,
    resp_calls_over_30min,
    -- Calculate distribution percentages
    CASE WHEN calls > 0 THEN ROUND((resp_calls_under_1ms * 100.0 / calls)::numeric, 2) ELSE 0 END AS pct_ultra_fast,
    CASE WHEN calls > 0 THEN ROUND(((resp_calls_under_1ms + resp_calls_1_to_10ms) * 100.0 / calls)::numeric, 2) ELSE 0 END AS pct_under_10ms,
    CASE WHEN calls > 0 THEN ROUND(((resp_calls_under_1ms + resp_calls_1_to_10ms + resp_calls_10_to_100ms) * 100.0 / calls)::numeric, 2) ELSE 0 END AS pct_under_100ms,
    CASE WHEN calls > 0 THEN ROUND((resp_calls_over_30min * 100.0 / calls)::numeric, 2) ELSE 0 END AS pct_critical_slow,
    -- Performance classification
    CASE 
      WHEN calls = 0 THEN 'no_data'
      WHEN (resp_calls_under_1ms * 100.0 / calls) > 90 THEN 'excellent'
      WHEN ((resp_calls_under_1ms + resp_calls_1_to_10ms) * 100.0 / calls) > 90 THEN 'good'
      WHEN ((resp_calls_under_1ms + resp_calls_1_to_10ms + resp_calls_10_to_100ms) * 100.0 / calls) > 90 THEN 'acceptable'
      WHEN (resp_calls_over_30min * 100.0 / calls) > 5 THEN 'critical'
      ELSE 'needs_optimization'
    END AS performance_rating
  FROM pg_stat_insights
  WHERE calls > 0;

-- Bucket statistics (if bucket tracking enabled)
CREATE VIEW pg_stat_insights_by_bucket AS
  SELECT 
    bucket_id,
    bucket_start_time,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls,
    SUM(total_exec_time) AS total_time,
    AVG(mean_exec_time) AS avg_exec_time,
    SUM(rows_retrieved) AS total_rows,
    AVG(cache_hit_ratio) AS avg_cache_hit_ratio
  FROM pg_stat_insights
  WHERE bucket_id > 0
  GROUP BY bucket_id, bucket_start_time
  ORDER BY bucket_id DESC;

-- ============================================================================
-- Permissions
-- ============================================================================

GRANT SELECT ON pg_stat_insights TO PUBLIC;
GRANT SELECT ON pg_stat_insights_replication TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_time TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_calls TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_by_io TO PUBLIC;
GRANT SELECT ON pg_stat_insights_top_cache_misses TO PUBLIC;
GRANT SELECT ON pg_stat_insights_plan_errors TO PUBLIC;
GRANT SELECT ON pg_stat_insights_slow_queries TO PUBLIC;
GRANT SELECT ON pg_stat_insights_errors TO PUBLIC;
GRANT SELECT ON pg_stat_insights_histogram_summary TO PUBLIC;
GRANT SELECT ON pg_stat_insights_by_bucket TO PUBLIC;

-- Restrict reset function to superusers only
REVOKE ALL ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;
