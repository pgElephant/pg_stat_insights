# Views Reference

Complete reference for all 11 pg_stat_insights views with examples and use cases.

---

## Overview

pg_stat_insights provides **11 pre-built views** for instant query performance analysis:

| View | Purpose | Typical Use Case |
|------|---------|------------------|
| `pg_stat_insights` | Main statistics view | All-purpose monitoring |
| `pg_stat_insights_top_by_time` | Slowest queries by total time | Find time-consuming queries |
| `pg_stat_insights_top_by_calls` | Most frequently called | Find hot path queries |
| `pg_stat_insights_top_by_io` | Highest I/O consumers | Identify disk-intensive operations |
| `pg_stat_insights_top_cache_misses` | Poor cache performers | Optimize buffer cache usage |
| `pg_stat_insights_slow_queries` | Queries with mean time >100ms | Find consistently slow queries |
| `pg_stat_insights_errors` | Queries with errors | Troubleshooting |
| `pg_stat_insights_plan_errors` | Plan estimation issues | Query optimization |
| `pg_stat_insights_histogram_summary` | Response time distribution | Performance analysis |
| `pg_stat_insights_by_bucket` | Time-series aggregation | Trend analysis |
| `pg_stat_insights_replication` | Replication monitoring | Replication lag tracking |

---

## Main Views

### `pg_stat_insights`

**The primary statistics view with all 52 metrics**

```sql
SELECT * FROM pg_stat_insights LIMIT 10;
```

**Columns** (52 total):

| Category | Columns |
|----------|---------|
| **Identity** | userid, dbid, toplevel, queryid, query |
| **Planning** | plans, total_plan_time, min_plan_time, max_plan_time, mean_plan_time, stddev_plan_time |
| **Execution** | calls, total_exec_time, min_exec_time, max_exec_time, mean_exec_time, stddev_exec_time, rows |
| **Buffer I/O** | shared_blks_hit, shared_blks_read, shared_blks_dirtied, shared_blks_written |
| **Local I/O** | local_blks_hit, local_blks_read, local_blks_dirtied, local_blks_written |
| **Temp I/O** | temp_blks_read, temp_blks_written |
| **I/O Timing** | shared_blk_read_time, shared_blk_write_time, local_blk_read_time, local_blk_write_time, temp_blk_read_time, temp_blk_write_time |
| **WAL** | wal_records, wal_fpi, wal_bytes, wal_buffers_full |
| **JIT** | jit_functions, jit_generation_time, jit_inlining_count, jit_inlining_time, jit_optimization_count, jit_optimization_time, jit_emission_count, jit_emission_time, jit_deform_count, jit_deform_time |
| **Parallel** | parallel_workers_to_launch, parallel_workers_launched |
| **Timestamps** | stats_since, minmax_stats_since |

**Example:**

```sql
-- Comprehensive query analysis
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    pg_size_pretty(wal_bytes::bigint) AS wal_generated,
    parallel_workers_launched,
    rows
FROM pg_stat_insights
WHERE calls > 10
ORDER BY total_exec_time DESC
LIMIT 20;
```

---

## Performance Analysis Views

### `pg_stat_insights_top_by_time`

**Top 100 queries by total execution time**

Identifies queries consuming the most cumulative time.

```sql
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;
```

**Use Cases:**

- [TARGET] **Optimization priority** - Focus on queries consuming most time
- [DATA] **Capacity planning** - Identify resource-intensive operations
- [FIND] **Performance regression** - Detect newly slow queries

**Example Analysis:**

```sql
-- Find queries contributing to 80% of total time
WITH total_time AS (
    SELECT SUM(total_exec_time) AS total FROM pg_stat_insights
),
ranked AS (
    SELECT 
        query,
        total_exec_time,
        SUM(total_exec_time) OVER (ORDER BY total_exec_time DESC) AS running_total,
        ROW_NUMBER() OVER (ORDER BY total_exec_time DESC) AS rank
    FROM pg_stat_insights
)
SELECT 
    rank,
    LEFT(query, 100) AS query_preview,
    ROUND(total_exec_time::numeric, 2) AS time_ms,
    ROUND((running_total / (SELECT total FROM total_time) * 100)::numeric, 1) AS cumulative_pct
FROM ranked
WHERE running_total <= (SELECT total FROM total_time) * 0.8
ORDER BY rank;
```

---

### `pg_stat_insights_top_by_calls`

**Top 100 queries by call count**

Identifies most frequently executed queries.

```sql
SELECT * FROM pg_stat_insights_top_by_calls LIMIT 10;
```

**Use Cases:**

- [HOT] **Hot paths** - Identify critical code paths
- [FAST] **Caching opportunities** - Find queries to cache
- [TARGET] **Micro-optimization** - Even small improvements have big impact

**Example:**

```sql
-- Frequent queries with improvement potential
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND((calls * mean_exec_time)::numeric, 2) AS total_time_ms,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio
FROM pg_stat_insights_top_by_calls
WHERE mean_exec_time > 1  -- Room for optimization
ORDER BY (calls * mean_exec_time) DESC
LIMIT 20;
```

---

### `pg_stat_insights_top_by_io`

**Top 100 queries by I/O operations**

Identifies disk-intensive queries.

```sql
SELECT * FROM pg_stat_insights_top_by_io LIMIT 10;
```

**Sorting Logic:**

```sql
ORDER BY (shared_blks_read + local_blks_read + temp_blks_read) DESC
```

**Use Cases:**

- [DISK] **Disk bottlenecks** - Find I/O-bound queries
- [DEPLOY] **Index opportunities** - Reduce sequential scans
- [TREND] **Storage planning** - Identify I/O patterns

**Example:**

```sql
-- I/O-intensive queries with timing
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_read,
    shared_blks_hit,
    shared_blk_read_time,
    ROUND((shared_blk_read_time / NULLIF(shared_blks_read, 0))::numeric, 3) AS ms_per_block,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio
FROM pg_stat_insights_top_by_io
WHERE shared_blks_read > 0
LIMIT 20;
```

---

### `pg_stat_insights_top_cache_misses`

**Queries with poor cache performance**

Includes calculated `cache_hit_ratio` column.

```sql
SELECT * FROM pg_stat_insights_top_cache_misses LIMIT 10;
```

**Cache Hit Ratio Calculation:**

```sql
cache_hit_ratio = shared_blks_hit::numeric / 
                  NULLIF(shared_blks_hit + shared_blks_read, 0)
```

**Use Cases:**

- [DATA] **Cache optimization** - Improve buffer cache efficiency
- [TARGET] **Memory tuning** - Adjust `shared_buffers`
- [FIND] **Index analysis** - Find missing indexes

**Example:**

```sql
-- Queries needing cache optimization
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    shared_blks_hit,
    shared_blks_read,
    pg_size_pretty((shared_blks_read * 8192)::bigint) AS data_read_from_disk
FROM pg_stat_insights_top_cache_misses
WHERE cache_hit_ratio < 0.95 AND calls > 5
ORDER BY (shared_blks_read * calls) DESC
LIMIT 20;
```

---

### `pg_stat_insights_slow_queries`

**Queries with mean execution time > 100ms**

Filters for consistently slow queries.

```sql
SELECT * FROM pg_stat_insights_slow_queries;
```

**Filter Logic:**

```sql
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
```

**Use Cases:**

- [SLOW] **Slow query detection** - Find performance problems
- [TREND] **Optimization candidates** - Prioritize improvements
- [WARNING] **Performance alerts** - Set up monitoring thresholds

**Example:**

```sql
-- Slow queries with full context
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(min_exec_time::numeric, 2) AS min_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio
FROM pg_stat_insights_slow_queries
ORDER BY mean_exec_time DESC
LIMIT 20;
```

---

### `pg_stat_insights_histogram_summary`

**Response time distribution histogram**

Shows query count distribution across time buckets.

```sql
SELECT * FROM pg_stat_insights_histogram_summary
ORDER BY bucket_order;
```

**Columns:**

- `bucket_label` - Time range label (e.g., "< 1ms", "1-10ms")
- `bucket_order` - Ordering number
- `query_count` - Queries in this bucket
- `total_time` - Total execution time for bucket
- `avg_time` - Average execution time

**Use Cases:**

- [DATA] **Performance profile** - Understand query time distribution
- [TARGET] **SLA monitoring** - Track % of queries under threshold
- [TREND] **Trend analysis** - Monitor distribution changes

**Example:**

```sql
-- Response time SLA analysis
SELECT 
    bucket_label,
    query_count,
    ROUND((query_count::numeric / SUM(query_count) OVER () * 100), 1) AS pct_queries,
    ROUND(total_time::numeric, 2) AS total_ms,
    ROUND((total_time / SUM(total_time) OVER () * 100), 1) AS pct_time
FROM pg_stat_insights_histogram_summary
ORDER BY bucket_order;
```

**Sample Output:**

```
  bucket_label  | query_count | pct_queries | total_ms | pct_time
----------------+-------------+-------------+----------+----------
 < 1ms          |       1,234 |        82.3 | 456.12   |     15.2
 1-10ms         |         189 |        12.6 | 987.45   |     32.9
 10-100ms       |          52 |         3.5 | 1245.67  |     41.5
 100ms-1s       |          18 |         1.2 | 234.56   |      7.8
 > 1s           |           7 |         0.5 | 78.90    |      2.6
```

---

### `pg_stat_insights_by_bucket`

**Time-series query statistics by time bucket**

Groups queries by time periods for trend analysis.

```sql
SELECT * FROM pg_stat_insights_by_bucket
ORDER BY bucket_start DESC
LIMIT 24;
```

**Columns:**

- `bucket_start` - Bucket start timestamp
- `bucket_end` - Bucket end timestamp
- `query_count` - Distinct queries in bucket
- `total_calls` - Total executions
- `total_time` - Total execution time
- `avg_time` - Average execution time

**Use Cases:**

- [TIME] **Time-series analysis** - Track performance over time
- [FIND] **Pattern detection** - Find daily/hourly patterns
- [SCHEDULE] **Peak load analysis** - Identify busy periods

**Example:**

```sql
-- Hourly performance trends
SELECT 
    DATE_TRUNC('hour', bucket_start) AS hour,
    COUNT(*) AS bucket_count,
    SUM(query_count) AS total_queries,
    SUM(total_calls) AS total_executions,
    ROUND(AVG(avg_time)::numeric, 2) AS avg_response_ms
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', bucket_start)
ORDER BY hour DESC;
```

---

## Specialized Views

### `pg_stat_insights_errors`

**Queries that encountered errors**

!!! info "Note"
    This view may be empty if queries complete successfully. Errors are typically logged but not retained in statistics.

```sql
SELECT * FROM pg_stat_insights_errors;
```

**Use Cases:**

- [BUG] **Error detection** - Find failing queries
- [FIND] **Debugging** - Identify problematic SQL
- [WARNING] **Alert generation** - Monitor for errors

---

### `pg_stat_insights_plan_errors`

**Queries with significant plan estimation errors**

Compares planned rows vs actual rows.

```sql
SELECT * FROM pg_stat_insights_plan_errors;
```

**Use Cases:**

- [DATA] **Statistics accuracy** - Find stale statistics
- [TARGET] **Query tuning** - Identify mis-estimated queries
- [TREND] **Index effectiveness** - Evaluate index usage

**Example:**

```sql
-- Find queries with poor estimates
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    rows AS actual_rows,
    planned_rows,
    ABS(rows - planned_rows) AS estimation_error,
    ROUND((ABS(rows - planned_rows)::numeric / NULLIF(GREATEST(rows, planned_rows), 0) * 100), 1) AS error_pct
FROM pg_stat_insights_plan_errors
WHERE ABS(rows - planned_rows) > 100
ORDER BY ABS(rows - planned_rows) DESC
LIMIT 20;
```

---

### `pg_stat_insights_replication`

**Replication lag and statistics monitoring**

```sql
SELECT * FROM pg_stat_insights_replication;
```

**Columns:**

- `pid` - Replication process ID
- `usename` - Replication user
- `application_name` - Client application
- `client_addr` - Client IP address
- `repl_state` - Replication state (streaming, catchup, etc.)
- `sync_state` - Synchronous state (sync, async, potential)
- `sent_lsn` - Last LSN sent to client
- `write_lag_bytes` - Bytes behind in writing
- `flush_lag_bytes` - Bytes behind in flushing
- `replay_lag_bytes` - Bytes behind in replaying
- `write_lag_seconds` - Time lag in writing
- `flush_lag_seconds` - Time lag in flushing
- `replay_lag_seconds` - Time lag in replaying

**Use Cases:**

- [SYNC] **Replication monitoring** - Track replica lag
- [WARNING] **Lag alerts** - Detect replication delays
- [DATA] **Capacity planning** - Understand replication load

**Example:**

```sql
-- Monitor replication lag
SELECT 
    application_name,
    client_addr,
    sync_state,
    pg_size_pretty(replay_lag_bytes::bigint) AS replay_lag_size,
    ROUND(replay_lag_seconds::numeric, 2) AS replay_lag_sec,
    CASE 
        WHEN replay_lag_seconds < 1 THEN '[OK] Healthy'
        WHEN replay_lag_seconds < 10 THEN '[WARNING] Warning'
        ELSE '[CRITICAL] Critical'
    END AS status
FROM pg_stat_insights_replication
ORDER BY replay_lag_seconds DESC;
```

---

## View Comparison

### When to Use Each View

```mermaid
graph TD
    A[Start] --> B{What do you need?}
    B -->|Find slowest queries| C[pg_stat_insights_top_by_time]
    B -->|Find most called queries| D[pg_stat_insights_top_by_calls]
    B -->|Find I/O bottlenecks| E[pg_stat_insights_top_by_io]
    B -->|Optimize cache| F[pg_stat_insights_top_cache_misses]
    B -->|Find consistently slow| G[pg_stat_insights_slow_queries]
    B -->|Analyze time distribution| H[pg_stat_insights_histogram_summary]
    B -->|Track trends| I[pg_stat_insights_by_bucket]
    B -->|Monitor replication| J[pg_stat_insights_replication]
    B -->|All metrics| K[pg_stat_insights]
```

### View Performance Characteristics

| View | Rows Returned | Query Speed | Memory Usage |
|------|---------------|-------------|--------------|
| `pg_stat_insights` | All queries (5,000+) | Medium | High |
| `pg_stat_insights_top_by_time` | 100 | Fast | Low |
| `pg_stat_insights_top_by_calls` | 100 | Fast | Low |
| `pg_stat_insights_top_by_io` | 100 | Fast | Low |
| `pg_stat_insights_top_cache_misses` | 100 | Fast | Low |
| `pg_stat_insights_slow_queries` | Filtered | Fast | Low |
| `pg_stat_insights_histogram_summary` | 10-20 | Very Fast | Very Low |
| `pg_stat_insights_by_bucket` | 100-1000 | Medium | Medium |
| `pg_stat_insights_replication` | 1-10 | Very Fast | Very Low |

---

## Advanced Usage

### Combining Views

```sql
-- Slow queries with poor cache performance
SELECT 
    s.query,
    s.mean_exec_time,
    c.cache_hit_ratio,
    s.calls,
    i.shared_blks_read
FROM pg_stat_insights_slow_queries s
JOIN pg_stat_insights_top_cache_misses c USING (queryid)
JOIN pg_stat_insights_top_by_io i USING (queryid)
WHERE c.cache_hit_ratio < 0.9
ORDER BY s.mean_exec_time DESC
LIMIT 15;
```

### Custom Views

```sql
-- Create your own monitoring view
CREATE VIEW my_critical_queries AS
SELECT 
    queryid,
    LEFT(query, 200) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    CASE 
        WHEN mean_exec_time > 1000 THEN '[CRITICAL] Critical'
        WHEN mean_exec_time > 100 THEN '[WARNING] Warning'
        ELSE '[OK] OK'
    END AS status
FROM pg_stat_insights
WHERE calls > 10 AND (
    mean_exec_time > 100 
    OR cache_hit_ratio < 0.9
    OR wal_bytes > 1000000
)
ORDER BY mean_exec_time DESC;

-- Query your custom view
SELECT * FROM my_critical_queries;
```

---

## View Maintenance

### Refresh Statistics

Statistics are continuously updated. To see latest data:

```sql
-- No special refresh needed - data is live
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;
```

### Reset Statistics

```sql
-- Reset all statistics (affects all views)
SELECT pg_stat_insights_reset();

-- Reset specific query
SELECT pg_stat_insights_reset(userid, dbid, queryid);
```

---

## Performance Considerations

### View Query Cost

All views are lightweight and query shared memory directly:

- **Cost**: ~1-10ms per query
- **Impact**: Minimal on production
- **Caching**: Results can be cached by application

### Best Practices

1. **Limit results** - Use `LIMIT` for large result sets
2. **Filter early** - Add WHERE clauses when possible
3. **Cache results** - Cache view results in application
4. **Avoid SELECT *** - Select only needed columns
5. **Use prepared statements** - For repeated view queries

---

## Next Steps

- **[Metrics Guide](metrics.md)** - Learn about all 52 metrics
- **[Usage Examples](usage.md)** - 50+ real-world queries
- **[Quick Start](quick-start.md)** - Start monitoring now

