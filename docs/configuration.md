# Configuration Reference

Complete reference for all 11 pg_stat_insights configuration parameters.

---

## Overview

pg_stat_insights provides **11 configuration parameters** to fine-tune performance monitoring, tracking behavior, and resource usage.

### Quick Reference

| Parameter | Default | Restart Required | Description |
|-----------|---------|------------------|-------------|
| `pg_stat_insights.max_queries` | 5000 | [OK] Yes | Maximum queries tracked |
| `pg_stat_insights.track_utility` | on | [NO] No | Track utility commands |
| `pg_stat_insights.track_planning` | off | [NO] No | Track planning statistics |
| `pg_stat_insights.track_wal` | on | [NO] No | Track WAL generation |
| `pg_stat_insights.track_jit` | on | [NO] No | Track JIT compilation |
| `pg_stat_insights.track_replication` | on | [NO] No | Track replication stats |
| `pg_stat_insights.track_io_timing` | off | [NO] No | Track I/O timing |
| `pg_stat_insights.track_parallel_queries` | on | [NO] No | Track parallel workers |
| `pg_stat_insights.track_minmax_time` | on | [NO] No | Track min/max times |
| `pg_stat_insights.track_level` | top | [NO] No | Tracking level (top/all) |
| `pg_stat_insights.histogram_buckets` | 10 | [NO] No | Histogram bucket count |

---

## Parameter Details

### `pg_stat_insights.max_queries`

**Maximum number of distinct queries tracked**

```sql
-- View current setting
SHOW pg_stat_insights.max_queries;

-- Change setting (restart required)
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;

-- Restart PostgreSQL
-- sudo systemctl restart postgresql
```

**Details:**

- **Type**: Integer
- **Range**: 100 - 1000000
- **Default**: 5000
- **Restart**: [OK] Required
- **Memory Impact**: ~100 bytes per query

**Recommendations:**

| Database Size | Recommended Value | Memory Usage |
|---------------|-------------------|--------------|
| Small (<10 GB) | 1,000 - 5,000 | 10-50 MB |
| Medium (10-100 GB) | 5,000 - 10,000 | 50-100 MB |
| Large (100GB-1TB) | 10,000 - 20,000 | 100-200 MB |
| Very Large (>1TB) | 20,000 - 50,000 | 200-500 MB |

**When to Adjust:**

- ⬆️ **Increase** if you see `(query texts file full)` in query text
- ⬇️ **Decrease** if running low on shared memory
- [DATA] **Monitor** using: `SELECT COUNT(*) FROM pg_stat_insights;`

---

### `pg_stat_insights.track_utility`

**Track utility commands (CREATE, ALTER, DROP, etc.)**

```sql
-- Enable utility tracking
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Low (~1% CPU)

**Tracks:**

- [OK] `CREATE TABLE`, `CREATE INDEX`
- [OK] `ALTER TABLE`, `ALTER INDEX`
- [OK] `DROP TABLE`, `DROP INDEX`
- [OK] `VACUUM`, `ANALYZE`
- [OK] `GRANT`, `REVOKE`
- [NO] Simple `SELECT`, `INSERT`, `UPDATE`, `DELETE` (always tracked)

**Use Cases:**

- Monitor DDL operations
- Track VACUUM/ANALYZE performance
- Audit schema changes
- Identify expensive index creation

**Example:**

```sql
-- View tracked utility commands
SELECT 
    query,
    calls,
    total_exec_time
FROM pg_stat_insights
WHERE query LIKE 'CREATE %' 
   OR query LIKE 'ALTER %'
   OR query LIKE 'VACUUM %'
ORDER BY total_exec_time DESC;
```

---

### `pg_stat_insights.track_planning`

**Track query planning time and statistics**

```sql
-- Enable planning tracking
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: off
- **Restart**: [NO] Not required
- **Overhead**: Medium (~5% CPU)

**Metrics Enabled:**

- `plans` - Number of times query was planned
- `total_plan_time` - Total planning time
- `min_plan_time` - Minimum planning time
- `max_plan_time` - Maximum planning time
- `mean_plan_time` - Average planning time
- `stddev_plan_time` - Planning time standard deviation

**Use Cases:**

- Identify queries with expensive planning
- Detect plan instability
- Optimize complex queries
- Monitor prepared statement efficiency

**Example:**

```sql
-- Find queries with expensive planning
SELECT 
    query,
    calls,
    plans,
    ROUND(mean_plan_time::numeric, 2) AS avg_plan_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_exec_ms,
    ROUND((mean_plan_time / NULLIF(mean_exec_time, 0) * 100)::numeric, 1) AS plan_pct_of_exec
FROM pg_stat_insights
WHERE plans > 0
ORDER BY mean_plan_time DESC
LIMIT 20;
```

---

### `pg_stat_insights.track_wal`

**Track Write-Ahead Log generation per query**

```sql
-- Enable WAL tracking
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Low (~1-2% CPU)

**Metrics Enabled:**

- `wal_records` - Number of WAL records generated
- `wal_fpi` - Full Page Images written
- `wal_bytes` - Total WAL bytes generated
- `wal_buffers_full` - Times WAL buffers filled

**Use Cases:**

- Identify write-heavy queries
- Optimize bulk insert/update operations
- Monitor replication lag sources
- Plan WAL archiving capacity

**Example:**

```sql
-- Top WAL generators
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    pg_size_pretty((wal_bytes / NULLIF(calls, 0))::bigint) AS avg_wal_per_call
FROM pg_stat_insights
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 20;
```

---

### `pg_stat_insights.track_jit`

**Track Just-In-Time compilation statistics**

```sql
-- Enable JIT tracking
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Low (~1% CPU)

**Metrics Enabled:**

- `jit_functions` - Functions JIT compiled
- `jit_generation_time` - Time spent generating JIT code
- `jit_inlining_count` - Functions inlined
- `jit_inlining_time` - Time spent inlining
- `jit_optimization_count` - Optimizations performed
- `jit_optimization_time` - Time spent optimizing
- `jit_emission_count` - Code emissions
- `jit_emission_time` - Time spent emitting code
- `jit_deform_count` - Tuple deforming operations
- `jit_deform_time` - Time spent deforming tuples

**Use Cases:**

- Evaluate JIT compilation benefit
- Identify JIT overhead
- Optimize JIT thresholds
- Monitor JIT-intensive queries

**Example:**

```sql
-- Queries benefiting from JIT
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    jit_functions,
    ROUND(jit_generation_time::numeric, 2) AS jit_gen_ms,
    ROUND(mean_exec_time::numeric, 2) AS exec_ms,
    ROUND((jit_generation_time / NULLIF(mean_exec_time, 0) * 100)::numeric, 1) AS jit_overhead_pct
FROM pg_stat_insights
WHERE jit_functions > 0
ORDER BY jit_generation_time DESC
LIMIT 15;
```

---

### `pg_stat_insights.track_io_timing`

**Track I/O operation timing**

```sql
-- Enable I/O timing
ALTER SYSTEM SET pg_stat_insights.track_io_timing = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: off
- **Restart**: [NO] Not required
- **Overhead**: Medium (2-5% CPU, varies by OS)

!!! warning "Performance Impact"
    Enabling I/O timing can impact performance on some systems. Test before enabling in production.

**Metrics Enabled:**

- `shared_blk_read_time` - Time reading shared blocks
- `shared_blk_write_time` - Time writing shared blocks
- `local_blk_read_time` - Time reading local blocks
- `local_blk_write_time` - Time writing local blocks
- `temp_blk_read_time` - Time reading temp blocks
- `temp_blk_write_time` - Time writing temp blocks

**Use Cases:**

- Identify I/O bottlenecks
- Detect slow storage
- Optimize disk-intensive queries
- Monitor temp file usage

**Example:**

```sql
-- Queries with slow I/O
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    shared_blks_read,
    ROUND(shared_blk_read_time::numeric, 2) AS read_time_ms,
    ROUND((shared_blk_read_time / NULLIF(shared_blks_read, 0))::numeric, 3) AS ms_per_block
FROM pg_stat_insights
WHERE shared_blk_read_time > 0
ORDER BY shared_blk_read_time DESC
LIMIT 15;
```

---

### `pg_stat_insights.track_parallel_queries`

**Track parallel query worker statistics**

```sql
-- Enable parallel query tracking
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Low (~1% CPU)

**Metrics Enabled:**

- `parallel_workers_to_launch` - Planned worker count
- `parallel_workers_launched` - Actual workers launched

**Use Cases:**

- Monitor parallel query efficiency
- Detect under-utilized parallelism
- Optimize `max_parallel_workers_per_gather`
- Identify parallelizable queries

**Example:**

```sql
-- Parallel query efficiency
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    parallel_workers_to_launch AS planned_workers,
    parallel_workers_launched AS actual_workers,
    CASE 
        WHEN parallel_workers_to_launch > 0 
        THEN ROUND((parallel_workers_launched::numeric / parallel_workers_to_launch * 100), 1)
        ELSE 0
    END AS worker_utilization_pct
FROM pg_stat_insights
WHERE parallel_workers_to_launch > 0
ORDER BY calls DESC
LIMIT 15;
```

---

### `pg_stat_insights.track_minmax_time`

**Track minimum and maximum execution times**

```sql
-- Enable min/max tracking
ALTER SYSTEM SET pg_stat_insights.track_minmax_time = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Low (<1% CPU)

**Metrics Enabled:**

- `min_exec_time` - Fastest execution
- `max_exec_time` - Slowest execution
- `min_plan_time` - Fastest planning
- `max_plan_time` - Slowest planning
- `minmax_stats_since` - Time when min/max tracking started

**Use Cases:**

- Detect execution time variability
- Identify performance regressions
- Monitor query stability
- Track best/worst case scenarios

**Example:**

```sql
-- Queries with high variability
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    ROUND(min_exec_time::numeric, 2) AS min_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND(stddev_exec_time::numeric, 2) AS stddev_ms,
    ROUND((max_exec_time / NULLIF(min_exec_time, 1) )::numeric, 1) AS variability_ratio
FROM pg_stat_insights
WHERE calls > 10 AND min_exec_time > 0
ORDER BY stddev_exec_time DESC
LIMIT 20;
```

---

### `pg_stat_insights.track_level`

**Set tracking level (top-level only or all nested queries)**

```sql
-- Track only top-level queries
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
SELECT pg_reload_conf();

-- Track all queries including nested
ALTER SYSTEM SET pg_stat_insights.track_level = 'all';
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Enum
- **Values**: `top`, `all`
- **Default**: `top`
- **Restart**: [NO] Not required
- **Overhead**: Low (top) / Medium (all)

**Options:**

| Value | Behavior | Use Case |
|-------|----------|----------|
| `top` | Track only client-issued queries | Production (recommended) |
| `all` | Track all queries including nested/internal | Development, debugging |

**Example:**

```sql
-- View toplevel status
SELECT 
    toplevel,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls
FROM pg_stat_insights
GROUP BY toplevel
ORDER BY toplevel;
```

---

### `pg_stat_insights.track_replication`

**Track replication lag and statistics**

```sql
-- Enable replication tracking
ALTER SYSTEM SET pg_stat_insights.track_replication = on;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Boolean
- **Default**: on
- **Restart**: [NO] Not required
- **Overhead**: Very low

**Views Enabled:**

- `pg_stat_insights_replication` - Replication monitoring view

**Example:**

```sql
-- Monitor replication lag
SELECT 
    application_name,
    client_addr,
    repl_state,
    sync_state,
    write_lag_bytes,
    flush_lag_bytes,
    replay_lag_bytes,
    write_lag_seconds,
    flush_lag_seconds,
    replay_lag_seconds
FROM pg_stat_insights_replication
ORDER BY replay_lag_bytes DESC;
```

---

### `pg_stat_insights.histogram_buckets`

**Number of response time histogram buckets**

```sql
-- Set histogram buckets
ALTER SYSTEM SET pg_stat_insights.histogram_buckets = 10;
SELECT pg_reload_conf();
```

**Details:**

- **Type**: Integer
- **Range**: 5 - 100
- **Default**: 10
- **Restart**: [NO] Not required
- **Overhead**: Low

**Bucket Distribution:**

Default 10 buckets categorize queries by execution time:

| Bucket | Time Range | Typical Queries |
|--------|------------|-----------------|
| 1 | < 1ms | Simple selects, indexed lookups |
| 2 | 1-10ms | Basic joins, small aggregations |
| 3 | 10-100ms | Complex queries, medium aggregations |
| 4 | 100ms-1s | Large joins, full table scans |
| 5 | 1-10s | Heavy analytics, batch operations |
| 6 | > 10s | Very long-running queries |

**Example:**

```sql
-- View response time distribution
SELECT 
    bucket_label,
    query_count,
    total_time,
    avg_time,
    ROUND((query_count::numeric / SUM(query_count) OVER () * 100), 1) AS pct_queries,
    ROUND((total_time / SUM(total_time) OVER () * 100), 1) AS pct_time
FROM pg_stat_insights_histogram_summary
ORDER BY bucket_order;
```

---

## Configuration Profiles

### Development Profile

Maximal tracking for development and debugging:

```sql
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_replication = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = on;
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = on;
ALTER SYSTEM SET pg_stat_insights.track_minmax_time = on;
ALTER SYSTEM SET pg_stat_insights.track_level = 'all';
ALTER SYSTEM SET pg_stat_insights.histogram_buckets = 20;
SELECT pg_reload_conf();
```

**Overhead**: ~10-15% CPU

### Production Profile (Balanced)

Recommended for production environments:

```sql
ALTER SYSTEM SET pg_stat_insights.max_queries = 5000;
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
ALTER SYSTEM SET pg_stat_insights.track_planning = off;  -- Disable for performance
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_replication = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = off;  -- Disable if overhead too high
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = on;
ALTER SYSTEM SET pg_stat_insights.track_minmax_time = on;
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
ALTER SYSTEM SET pg_stat_insights.histogram_buckets = 10;
SELECT pg_reload_conf();
```

**Overhead**: ~2-5% CPU

### Minimal Profile (Low Overhead)

Minimal tracking for performance-sensitive environments:

```sql
ALTER SYSTEM SET pg_stat_insights.max_queries = 1000;
ALTER SYSTEM SET pg_stat_insights.track_utility = off;
ALTER SYSTEM SET pg_stat_insights.track_planning = off;
ALTER SYSTEM SET pg_stat_insights.track_wal = off;
ALTER SYSTEM SET pg_stat_insights.track_jit = off;
ALTER SYSTEM SET pg_stat_insights.track_replication = off;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = off;
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = off;
ALTER SYSTEM SET pg_stat_insights.track_minmax_time = off;
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
ALTER SYSTEM SET pg_stat_insights.histogram_buckets = 5;
SELECT pg_reload_conf();
```

**Overhead**: <1% CPU

---

## Performance Tuning

### Monitoring Overhead

Check pg_stat_insights overhead:

```sql
-- View extension resource usage
SELECT 
    name,
    setting,
    unit,
    category,
    short_desc
FROM pg_settings
WHERE name LIKE 'pg_stat_insights%'
ORDER BY name;
```

### Optimal Settings by Workload

| Workload Type | max_queries | track_planning | track_io_timing | track_level |
|---------------|-------------|----------------|-----------------|-------------|
| **OLTP** (many small queries) | 5,000 | off | off | top |
| **OLAP** (few large queries) | 1,000 | on | on | all |
| **Mixed** (hybrid workload) | 5,000 | off | off | top |
| **Development** | 10,000 | on | on | all |

### Memory Optimization

```sql
-- Check shared memory usage
SELECT 
    pg_size_pretty(
        (SELECT setting::bigint FROM pg_settings WHERE name = 'shared_buffers')::bigint * 
        (SELECT setting::bigint FROM pg_settings WHERE name = 'block_size')::bigint
    ) AS shared_buffers_size;

-- Estimate pg_stat_insights memory
SELECT 
    setting AS max_queries,
    pg_size_pretty((setting::bigint * 100)::bigint) AS estimated_memory
FROM pg_settings
WHERE name = 'pg_stat_insights.max_queries';
```

---

## Best Practices

### [OK] DO

- **Start with defaults** - Use default settings initially
- **Monitor overhead** - Check CPU/memory impact
- **Enable I/O timing carefully** - Test overhead first
- **Use `top` level** - Unless debugging
- **Reload config** - Use `pg_reload_conf()` for dynamic settings
- **Reset periodically** - Clear statistics to avoid stale data

### [NO] DON'T

- **Set max_queries too high** - Wastes shared memory
- **Enable all features** - May cause performance issues
- **Track all levels** - Only if needed for debugging
- **Forget to restart** - When changing `max_queries`
- **Ignore overhead** - Monitor CPU usage
- **Keep stale stats** - Reset old statistics regularly

---

## Configuration Examples

### Example 1: High-Traffic Web Application

```sql
-- Optimized for many concurrent users
ALTER SYSTEM SET pg_stat_insights.max_queries = 5000;
ALTER SYSTEM SET pg_stat_insights.track_utility = off;  -- Focus on queries
ALTER SYSTEM SET pg_stat_insights.track_planning = off;
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = off;  -- Minimize overhead
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
SELECT pg_reload_conf();
```

### Example 2: Data Warehouse

```sql
-- Optimized for complex analytical queries
ALTER SYSTEM SET pg_stat_insights.max_queries = 1000;
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
ALTER SYSTEM SET pg_stat_insights.track_planning = on;  -- Important for complex queries
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = on;  -- Track slow I/O
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = on;  -- Monitor parallelism
ALTER SYSTEM SET pg_stat_insights.track_level = 'all';
ALTER SYSTEM SET pg_stat_insights.histogram_buckets = 20;  -- Fine-grained distribution
SELECT pg_reload_conf();
```

### Example 3: Replication Primary

```sql
-- Optimized for monitoring replication performance
ALTER SYSTEM SET pg_stat_insights.max_queries = 5000;
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
ALTER SYSTEM SET pg_stat_insights.track_wal = on;  -- Critical for replication
ALTER SYSTEM SET pg_stat_insights.track_replication = on;  -- Monitor replicas
ALTER SYSTEM SET pg_stat_insights.track_jit = off;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = off;
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
SELECT pg_reload_conf();
```

---

## Viewing Current Configuration

### All Settings

```sql
SELECT 
    name,
    setting,
    unit,
    boot_val,
    reset_val,
    source,
    sourcefile,
    sourceline
FROM pg_settings
WHERE name LIKE 'pg_stat_insights%'
ORDER BY name;
```

### Settings Requiring Restart

```sql
SELECT 
    name,
    setting,
    pending_restart
FROM pg_settings
WHERE name LIKE 'pg_stat_insights%'
  AND pending_restart = true;
```

---

## Next Steps

- **[Quick Start Guide](quick-start.md)** - Start monitoring now
- **[Views Reference](views.md)** - Explore all 11 views
- **[Metrics Guide](metrics.md)** - Learn about 52 metrics
- **[Usage Examples](usage.md)** - Real-world queries

