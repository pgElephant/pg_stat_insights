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


-- Register functions.
CREATE FUNCTION pg_stat_insights_reset()
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C PARALLEL SAFE;

CREATE FUNCTION pg_stat_insights(IN showtext boolean,
    OUT userid oid,
    OUT dbid oid,
    OUT queryid bigint,
    OUT query text,
    OUT calls int8,
    OUT total_time float8,
    OUT min_time float8,
    OUT max_time float8,
    OUT mean_time float8,
    OUT stddev_time float8,
    OUT rows int8,
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
    OUT blk_read_time float8,
    OUT blk_write_time float8,
    OUT query_complexity int4,
    OUT query_length int4,
    OUT param_count int4
)
RETURNS SETOF record
AS 'MODULE_PATHNAME', 'pg_stat_insights_1_14'
LANGUAGE C STRICT VOLATILE PARALLEL SAFE;

-- Register a view on the function for ease of use.
CREATE VIEW pg_stat_insights AS
  SELECT * FROM pg_stat_insights(true);

GRANT SELECT ON pg_stat_insights TO PUBLIC;

-- Don't want this to be available to non-superusers.
REVOKE ALL ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;

-- Register a view on the function for ease of use.
CREATE VIEW pg_stat_insights AS
  SELECT * FROM pg_stat_insights(true);

GRANT SELECT ON pg_stat_insights TO PUBLIC;

-- Don't want this to be available to non-superusers.
REVOKE ALL ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;

    OUT stddev_time float8,    OUT stddev_time float8,

    OUT rows int8,    OUT rows int8,

    OUT shared_blks_hit int8,    OUT shared_blks_hit int8,

    OUT shared_blks_read int8,    OUT shared_blks_read int8,

    OUT shared_blks_dirtied int8,    OUT shared_blks_dirtied int8,

    OUT shared_blks_written int8,    OUT shared_blks_written int8,

    OUT local_blks_hit int8,    OUT local_blks_hit int8,

    OUT local_blks_read int8,    OUT local_blks_read int8,

    OUT local_blks_dirtied int8,    OUT local_blks_dirtied int8,

    OUT local_blks_written int8,    OUT local_blks_written int8,

    OUT temp_blks_read int8,    OUT temp_blks_read int8,

    OUT temp_blks_written int8,    OUT temp_blks_written int8,

    OUT blk_read_time float8,    OUT blk_read_time float8,

    OUT blk_write_time float8,    OUT blk_write_time float8,

    OUT query_complexity int4,    OUT query_complexity int4,

    OUT query_length int4,    OUT query_length int4,

    OUT param_count int4    OUT param_count int4

))

RETURNS SETOF recordRETURNS SETOF record

AS 'MODULE_PATHNAME', 'pg_stat_insights_1_14'AS 'MODULE_PATHNAME', 'pg_stat_insights_1_14'

LANGUAGE C STRICT VOLATILE PARALLEL SAFE;LANGUAGE C STRICT VOLATILE PARALLEL SAFE;



-- Register a view on the function for ease of use.-- Register a view on the function for ease of use.

CREATE VIEW pg_stat_insights ASCREATE VIEW pg_stat_insights AS

  SELECT * FROM pg_stat_insights(true);  SELECT * FROM pg_stat_insights(true);



GRANT SELECT ON pg_stat_insights TO PUBLIC;GRANT SELECT ON pg_stat_insights TO PUBLIC;



-- Don't want this to be available to non-superusers.-- Don't want this to be available to non-superusers.

REVOKE ALL ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;REVOKE ALL ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;