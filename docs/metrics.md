# Metrics Guide

Complete reference for all 52 metrics tracked by pg_stat_insights.

---

## Overview

pg_stat_insights tracks **52 comprehensive metrics** across 8 categories:

| Category | Metrics | Description |
|----------|---------|-------------|
| **Identity** | 5 | Query identification and metadata |
| **Planning** | 6 | Query planning statistics |
| **Execution** | 7 | Query execution performance |
| **Buffer I/O** | 12 | Shared and local buffer operations |
| **Temp I/O** | 6 | Temporary file operations |
| **WAL** | 4 | Write-Ahead Log generation |
| **JIT** | 10 | Just-In-Time compilation stats |
| **Parallel** | 2 | Parallel query worker metrics |

**Total: 52 metrics** providing complete query performance visibility

---

## Identity Metrics

### `userid`

**User OID who executed the query**

- **Type**: oid
- **Description**: PostgreSQL user object ID
- **Use**: Filter queries by user, track user activity

```sql
-- Find queries by specific user
SELECT 
    r.rolname AS username,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls
FROM pg_stat_insights s
JOIN pg_roles r ON s.userid = r.oid
GROUP BY r.rolname
ORDER BY total_calls DESC;
```

### `dbid`

**Database OID where query executed**

- **Type**: oid
- **Description**: PostgreSQL database object ID
- **Use**: Filter queries by database

```sql
-- Find queries by database
SELECT 
    d.datname AS database,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls,
    ROUND(SUM(total_exec_time)::numeric, 2) AS total_time_ms
FROM pg_stat_insights s
JOIN pg_database d ON s.dbid = d.oid
GROUP BY d.datname
ORDER BY total_time_ms DESC;
```

### `toplevel`

**Is this a top-level query?**

- **Type**: boolean
- **Values**: `true` (client-issued), `false` (nested/internal)
- **Use**: Filter by query origin

```sql
-- Compare top-level vs nested queries
SELECT 
    toplevel,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls,
    ROUND(AVG(mean_exec_time)::numeric, 2) AS avg_time_ms
FROM pg_stat_insights
GROUP BY toplevel;
```

### `queryid`

**Unique query identifier (hash)**

- **Type**: bigint
- **Description**: Normalized query hash for grouping
- **Use**: Join queries, track specific patterns

```sql
-- Track specific query over time
SELECT 
    queryid,
    query,
    calls,
    total_exec_time,
    stats_since
FROM pg_stat_insights
WHERE queryid = 1234567890;
```

### `query`

**Normalized query text**

- **Type**: text
- **Description**: Query with constants replaced by parameters
- **Use**: Human-readable query identification

```sql
-- Search for queries by pattern
SELECT 
    query,
    calls,
    mean_exec_time
FROM pg_stat_insights
WHERE query LIKE '%my_table%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## Planning Metrics

Requires `pg_stat_insights.track_planning = on`

### `plans`

**Number of times query was planned**

- **Type**: bigint
- **Unit**: count
- **Use**: Detect plan cache efficiency

```sql
-- Find queries that plan frequently
SELECT 
    query,
    plans,
    calls,
    ROUND((plans::numeric / NULLIF(calls, 0)), 2) AS plan_per_call_ratio
FROM pg_stat_insights
WHERE plans > 0
ORDER BY (plans::numeric / NULLIF(calls, 0)) DESC
LIMIT 20;
```

### `total_plan_time`

**Total time spent planning (milliseconds)**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Identify expensive planning

```sql
-- Top queries by planning time
SELECT 
    query,
    plans,
    ROUND(total_plan_time::numeric, 2) AS total_plan_ms,
    ROUND(mean_plan_time::numeric, 2) AS avg_plan_ms
FROM pg_stat_insights
WHERE total_plan_time > 0
ORDER BY total_plan_time DESC
LIMIT 20;
```

### `min_plan_time`, `max_plan_time`, `mean_plan_time`

**Minimum, maximum, and average planning time**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Analyze planning time distribution

```sql
-- Find queries with variable planning time
SELECT 
    query,
    plans,
    ROUND(min_plan_time::numeric, 3) AS min_ms,
    ROUND(mean_plan_time::numeric, 3) AS avg_ms,
    ROUND(max_plan_time::numeric, 3) AS max_ms,
    ROUND((max_plan_time / NULLIF(min_plan_time, 1))::numeric, 1) AS variability
FROM pg_stat_insights
WHERE plans > 5
ORDER BY (max_plan_time / NULLIF(min_plan_time, 1)) DESC
LIMIT 20;
```

### `stddev_plan_time`

**Planning time standard deviation**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Measure planning time consistency

```sql
-- Queries with inconsistent planning
SELECT 
    query,
    plans,
    ROUND(mean_plan_time::numeric, 2) AS avg_ms,
    ROUND(stddev_plan_time::numeric, 2) AS stddev_ms,
    ROUND((stddev_plan_time / NULLIF(mean_plan_time, 0) * 100)::numeric, 1) AS coefficient_of_variation
FROM pg_stat_insights
WHERE plans > 10
ORDER BY stddev_plan_time DESC
LIMIT 20;
```

---

## Execution Metrics

Always tracked.

### `calls`

**Number of times query was executed**

- **Type**: bigint
- **Unit**: count
- **Use**: Identify frequently-run queries

```sql
-- Most frequently executed queries
SELECT 
    query,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND((calls * mean_exec_time)::numeric, 2) AS total_time_ms
FROM pg_stat_insights
ORDER BY calls DESC
LIMIT 20;
```

### `total_exec_time`

**Total execution time (milliseconds)**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Find time-consuming queries

```sql
-- Queries consuming most time
SELECT 
    query,
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND((total_exec_time / SUM(total_exec_time) OVER () * 100)::numeric, 1) AS pct_of_total
FROM pg_stat_insights
ORDER BY total_exec_time DESC
LIMIT 20;
```

### `min_exec_time`, `max_exec_time`, `mean_exec_time`

**Minimum, maximum, and average execution time**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Analyze execution time distribution

```sql
-- Find queries with high variability
SELECT 
    query,
    calls,
    ROUND(min_exec_time::numeric, 2) AS min_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND((max_exec_time - min_exec_time)::numeric, 2) AS range_ms,
    CASE 
        WHEN min_exec_time > 0 THEN ROUND((max_exec_time / min_exec_time)::numeric, 1)
        ELSE NULL
    END AS variability_ratio
FROM pg_stat_insights
WHERE calls > 10
ORDER BY (max_exec_time - min_exec_time) DESC
LIMIT 20;
```

### `stddev_exec_time`

**Execution time standard deviation**

- **Type**: float8
- **Unit**: milliseconds
- **Use**: Measure execution consistency

```sql
-- Queries with unstable performance
SELECT 
    query,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(stddev_exec_time::numeric, 2) AS stddev_ms,
    ROUND((stddev_exec_time / NULLIF(mean_exec_time, 0))::numeric, 3) AS relative_stddev
FROM pg_stat_insights
WHERE calls > 20 AND stddev_exec_time > 0
ORDER BY (stddev_exec_time / NULLIF(mean_exec_time, 0)) DESC
LIMIT 20;
```

### `rows`

**Total rows returned/affected**

- **Type**: bigint
- **Unit**: rows
- **Use**: Analyze query result sizes

```sql
-- Queries returning most rows
SELECT 
    query,
    calls,
    rows,
    ROUND((rows::numeric / NULLIF(calls, 0)), 0) AS avg_rows_per_call,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND((mean_exec_time / NULLIF(rows::numeric / NULLIF(calls, 0), 0))::numeric, 4) AS ms_per_row
FROM pg_stat_insights
WHERE rows > 0
ORDER BY rows DESC
LIMIT 20;
```

---

## Buffer I/O Metrics

### Shared Buffers

**Shared buffer operations (PostgreSQL buffer cache)**

| Metric | Description | Unit |
|--------|-------------|------|
| `shared_blks_hit` | Blocks found in cache | blocks (8KB each) |
| `shared_blks_read` | Blocks read from disk | blocks (8KB each) |
| `shared_blks_dirtied` | Blocks modified | blocks |
| `shared_blks_written` | Blocks written to disk | blocks |

**Cache Hit Ratio:**

```sql
SELECT 
    query,
    shared_blks_hit,
    shared_blks_read,
    ROUND((shared_blks_hit::numeric / 
           NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 3) AS cache_hit_ratio,
    pg_size_pretty((shared_blks_read * 8192)::bigint) AS data_from_disk
FROM pg_stat_insights
WHERE (shared_blks_hit + shared_blks_read) > 0
ORDER BY shared_blks_read DESC
LIMIT 20;
```

### Local Buffers

**Local buffer operations (temporary tables)**

| Metric | Description |
|--------|-------------|
| `local_blks_hit` | Local blocks in cache |
| `local_blks_read` | Local blocks from disk |
| `local_blks_dirtied` | Local blocks modified |
| `local_blks_written` | Local blocks written |

### Temp Buffers

**Temporary file operations (work_mem overflow)**

| Metric | Description |
|--------|-------------|
| `temp_blks_read` | Temp blocks read |
| `temp_blks_written` | Temp blocks written |

```sql
-- Find queries using temp files
SELECT 
    query,
    calls,
    temp_blks_read,
    temp_blks_written,
    pg_size_pretty((temp_blks_written * 8192)::bigint) AS temp_written_size
FROM pg_stat_insights
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 20;
```

---

## I/O Timing Metrics

Requires `pg_stat_insights.track_io_timing = on`

### Block Timing

**Time spent on I/O operations (milliseconds)**

| Metric | Description |
|--------|-------------|
| `shared_blk_read_time` | Time reading shared blocks |
| `shared_blk_write_time` | Time writing shared blocks |
| `local_blk_read_time` | Time reading local blocks |
| `local_blk_write_time` | Time writing local blocks |
| `temp_blk_read_time` | Time reading temp blocks |
| `temp_blk_write_time` | Time writing temp blocks |

```sql
-- Find slow I/O operations
SELECT 
    query,
    calls,
    shared_blks_read,
    ROUND(shared_blk_read_time::numeric, 2) AS read_time_ms,
    ROUND((shared_blk_read_time / NULLIF(shared_blks_read, 0))::numeric, 3) AS ms_per_block,
    CASE 
        WHEN shared_blk_read_time / NULLIF(shared_blks_read, 0) > 10 THEN '[SLOW] Very Slow'
        WHEN shared_blk_read_time / NULLIF(shared_blks_read, 0) > 1 THEN '[WARNING] Slow'
        ELSE '[OK] Normal'
    END AS disk_speed
FROM pg_stat_insights
WHERE shared_blks_read > 0
ORDER BY (shared_blk_read_time / NULLIF(shared_blks_read, 0)) DESC
LIMIT 20;
```

---

## WAL Metrics

Requires `pg_stat_insights.track_wal = on`

### `wal_records`

**Number of WAL records generated**

- **Type**: bigint
- **Unit**: count
- **Use**: Track write activity

### `wal_fpi`

**Full Page Images written**

- **Type**: bigint
- **Unit**: count
- **Use**: Monitor checkpoint impact

### `wal_bytes`

**Total WAL bytes generated**

- **Type**: numeric
- **Unit**: bytes
- **Use**: Capacity planning, replication monitoring

### `wal_buffers_full`

**Times WAL buffers were full**

- **Type**: bigint
- **Unit**: count
- **Use**: Detect WAL buffer saturation

```sql
-- Comprehensive WAL analysis
SELECT 
    query,
    calls,
    wal_records,
    wal_fpi,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    wal_buffers_full,
    ROUND((wal_records::numeric / NULLIF(calls, 0)), 2) AS records_per_call,
    pg_size_pretty((wal_bytes / NULLIF(calls, 0))::bigint) AS bytes_per_call
FROM pg_stat_insights
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 20;
```

---

## JIT Metrics

Requires `pg_stat_insights.track_jit = on`

### JIT Compilation

**Just-In-Time compilation statistics**

| Metric | Description | Unit |
|--------|-------------|------|
| `jit_functions` | Functions JIT compiled | count |
| `jit_generation_time` | Code generation time | ms |
| `jit_inlining_count` | Functions inlined | count |
| `jit_inlining_time` | Inlining time | ms |
| `jit_optimization_count` | Optimizations performed | count |
| `jit_optimization_time` | Optimization time | ms |
| `jit_emission_count` | Code emissions | count |
| `jit_emission_time` | Emission time | ms |
| `jit_deform_count` | Tuple deforming ops | count |
| `jit_deform_time` | Deforming time | ms |

```sql
-- Analyze JIT cost vs benefit
SELECT 
    query,
    calls,
    jit_functions,
    ROUND(jit_generation_time::numeric, 2) AS jit_gen_ms,
    ROUND(mean_exec_time::numeric, 2) AS exec_ms,
    ROUND((jit_generation_time / NULLIF(mean_exec_time, 0) * 100)::numeric, 1) AS jit_overhead_pct,
    CASE 
        WHEN (jit_generation_time / NULLIF(mean_exec_time, 0) * 100) > 10 THEN '[WARNING] High Overhead'
        WHEN jit_functions > 0 THEN '[OK] Using JIT'
        ELSE '[NONE] No JIT'
    END AS jit_status
FROM pg_stat_insights
WHERE mean_exec_time > 0
ORDER BY jit_generation_time DESC
LIMIT 20;
```

---

## Parallel Query Metrics

Requires `pg_stat_insights.track_parallel_queries = on`

### `parallel_workers_to_launch`

**Number of parallel workers planned**

- **Type**: bigint
- **Unit**: workers
- **Use**: Evaluate parallelization planning

### `parallel_workers_launched`

**Number of parallel workers actually launched**

- **Type**: bigint
- **Unit**: workers
- **Use**: Monitor parallel execution

```sql
-- Parallel query efficiency
SELECT 
    query,
    calls,
    parallel_workers_to_launch AS planned,
    parallel_workers_launched AS actual,
    ROUND((parallel_workers_launched::numeric / 
           NULLIF(parallel_workers_to_launch, 0) * 100), 1) AS efficiency_pct,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    rows
FROM pg_stat_insights
WHERE parallel_workers_to_launch > 0
ORDER BY calls DESC
LIMIT 20;
```

---

## Timestamp Metrics

### `stats_since`

**When statistics collection started for this query**

- **Type**: timestamp with time zone
- **Use**: Data freshness tracking

### `minmax_stats_since`

**When min/max tracking started**

- **Type**: timestamp with time zone
- **Use**: Min/max data validity period

```sql
-- Check stats freshness
SELECT 
    query,
    calls,
    stats_since,
    NOW() - stats_since AS stats_age,
    minmax_stats_since,
    NOW() - minmax_stats_since AS minmax_age
FROM pg_stat_insights
WHERE stats_since < NOW() - INTERVAL '1 hour'
ORDER BY stats_since
LIMIT 10;
```

---

## Metric Relationships

### Cache Hit Ratio

**Calculated from buffer metrics**

```sql
cache_hit_ratio = shared_blks_hit::numeric / 
                  NULLIF(shared_blks_hit + shared_blks_read, 0)
```

| Ratio | Performance | Action |
|-------|-------------|--------|
| > 0.99 | Excellent [OK] | No action needed |
| 0.95-0.99 | Good [OK] | Monitor |
| 0.90-0.95 | Fair [WARNING] | Consider optimization |
| < 0.90 | Poor [CRITICAL] | Optimize immediately |

### Execution Efficiency

**Time per row returned**

```sql
ms_per_row = mean_exec_time / NULLIF(rows / NULLIF(calls, 0), 0)
```

### I/O Efficiency

**Time per block read**

```sql
ms_per_block = shared_blk_read_time / NULLIF(shared_blks_read, 0)
```

Typical values:
- **SSD**: 0.1-1 ms/block
- **HDD**: 1-10 ms/block
- **Network storage**: 5-50 ms/block

---

## Metric Aggregations

### Sum Metrics

Metrics that can be summed across queries:

- `calls`, `rows`
- `total_plan_time`, `total_exec_time`
- All `*_blks_*` metrics
- All `wal_*` metrics
- All `jit_*_count` metrics

```sql
-- Total across all queries
SELECT 
    COUNT(*) AS total_queries,
    SUM(calls) AS total_calls,
    SUM(rows) AS total_rows,
    ROUND(SUM(total_exec_time)::numeric, 2) AS total_time_ms,
    SUM(shared_blks_read) AS total_blocks_read,
    pg_size_pretty(SUM(wal_bytes)::bigint) AS total_wal
FROM pg_stat_insights;
```

### Average Metrics

Metrics that should be averaged:

- `mean_plan_time`, `mean_exec_time`
- `cache_hit_ratio`
- JIT timing metrics

```sql
-- Average across all queries
SELECT 
    ROUND(AVG(mean_exec_time)::numeric, 2) AS avg_exec_time,
    ROUND(AVG(cache_hit_ratio)::numeric, 3) AS avg_cache_ratio,
    ROUND(AVG(parallel_workers_launched)::numeric, 2) AS avg_workers
FROM pg_stat_insights
WHERE calls > 0;
```

---

## Metric Best Practices

### [OK] Recommended Metrics to Monitor

**Always Monitor:**
- `total_exec_time` - Find expensive queries
- `calls` - Identify hot paths
- `mean_exec_time` - Detect slow queries
- `cache_hit_ratio` - Optimize caching
- `rows` - Understand query impact

**Monitor in Production:**
- `wal_bytes` - Track writes
- `shared_blks_read` - Monitor I/O
- `stddev_exec_time` - Detect variability

**Monitor in Development:**
- `plans` - Plan caching
- JIT metrics - JIT effectiveness
- Parallel metrics - Parallelization efficiency

---

## Metric Thresholds

### Recommended Alert Thresholds

```sql
-- Define monitoring thresholds
CREATE VIEW performance_alerts AS
SELECT 
    queryid,
    LEFT(query, 100) AS query_preview,
    CASE 
        WHEN mean_exec_time > 10000 THEN 'CRITICAL: >10s avg'
        WHEN mean_exec_time > 1000 THEN 'WARNING: >1s avg'
        WHEN mean_exec_time > 100 THEN 'INFO: >100ms avg'
        ELSE 'OK'
    END AS execution_alert,
    CASE 
        WHEN cache_hit_ratio < 0.80 THEN 'CRITICAL: <80% cache'
        WHEN cache_hit_ratio < 0.90 THEN 'WARNING: <90% cache'
        WHEN cache_hit_ratio < 0.95 THEN 'INFO: <95% cache'
        ELSE 'OK'
    END AS cache_alert,
    CASE 
        WHEN wal_bytes > 100000000 THEN 'WARNING: >100MB WAL'
        WHEN wal_bytes > 10000000 THEN 'INFO: >10MB WAL'
        ELSE 'OK'
    END AS wal_alert
FROM pg_stat_insights
WHERE calls > 10;

-- Check for alerts
SELECT * FROM performance_alerts 
WHERE execution_alert != 'OK' 
   OR cache_alert != 'OK' 
   OR wal_alert != 'OK';
```

---

## Next Steps

- **[Views Reference](views.md)** - Explore all 11 views
- **[Configuration](configuration.md)** - Configure tracking
- **[Usage Examples](usage.md)** - Real-world queries
- **[Troubleshooting](troubleshooting.md)** - Common issues

