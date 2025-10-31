# Usage Examples

50+ real-world SQL queries for monitoring and optimizing PostgreSQL performance with pg_stat_insights.

---

## Table of Contents

- [Performance Analysis](#performance-analysis)
- [Cache Optimization](#cache-optimization)
- [I/O Analysis](#io-analysis)
- [WAL Monitoring](#wal-monitoring)
- [Query Tuning](#query-tuning)
- [Trend Analysis](#trend-analysis)
- [Alerting & Monitoring](#alerting-monitoring)
- [Troubleshooting](#troubleshooting)

---

## Performance Analysis

### Find Top 10 Slowest Queries

```sql
SELECT 
    LEFT(query, 120) AS query_preview,
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    rows
FROM pg_stat_insights_top_by_time
LIMIT 10;
```

### Queries Contributing to 80% of Total Time

```sql
WITH total_time AS (
    SELECT SUM(total_exec_time) AS total FROM pg_stat_insights
),
ranked AS (
    SELECT 
        query,
        total_exec_time,
        calls,
        SUM(total_exec_time) OVER (ORDER BY total_exec_time DESC) AS running_total
    FROM pg_stat_insights
)
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(total_exec_time::numeric, 2) AS time_ms,
    ROUND((total_exec_time / (SELECT total FROM total_time) * 100)::numeric, 1) AS pct_of_total,
    ROUND((running_total / (SELECT total FROM total_time) * 100)::numeric, 1) AS cumulative_pct
FROM ranked
WHERE running_total <= (SELECT total FROM total_time) * 0.8
ORDER BY total_exec_time DESC;
```

### Most Frequently Called Queries

```sql
SELECT 
    LEFT(query, 120) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND((calls::numeric / SUM(calls) OVER () * 100), 1) AS pct_of_calls
FROM pg_stat_insights_top_by_calls
LIMIT 20;
```

### Queries with High Execution Time Variability

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(min_exec_time::numeric, 2) AS min_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND(stddev_exec_time::numeric, 2) AS stddev_ms,
    ROUND((max_exec_time / NULLIF(min_exec_time, 1))::numeric, 1) AS variability_ratio
FROM pg_stat_insights
WHERE calls > 10 AND min_exec_time > 0
ORDER BY stddev_exec_time DESC
LIMIT 20;
```

### Average Query Performance by Hour

```sql
SELECT 
    EXTRACT(HOUR FROM bucket_start) AS hour_of_day,
    COUNT(*) AS query_types,
    SUM(total_calls) AS total_executions,
    ROUND(AVG(avg_time)::numeric, 2) AS avg_response_ms,
    MIN(avg_time) AS min_response_ms,
    MAX(avg_time) AS max_response_ms
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '7 days'
GROUP BY EXTRACT(HOUR FROM bucket_start)
ORDER BY hour_of_day;
```

---

## Cache Optimization

### Queries with Poor Cache Hit Ratio

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    shared_blks_hit,
    shared_blks_read,
    pg_size_pretty((shared_blks_read * 8192)::bigint) AS data_from_disk,
    pg_size_pretty(((shared_blks_hit + shared_blks_read) * 8192)::bigint) AS total_data
FROM pg_stat_insights_top_cache_misses
WHERE calls > 5 AND cache_hit_ratio < 0.95
ORDER BY (shared_blks_read * calls) DESC
LIMIT 20;
```

### Estimate Required Buffer Cache

```sql
SELECT 
    pg_size_pretty(SUM((shared_blks_hit + shared_blks_read) * 8192)::bigint) AS total_data_accessed,
    pg_size_pretty(SUM(shared_blks_read * 8192)::bigint) AS data_read_from_disk,
    pg_size_pretty((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')::bigint) AS current_shared_buffers,
    ROUND((SUM(shared_blks_hit)::numeric / NULLIF(SUM(shared_blks_hit + shared_blks_read), 0) * 100), 1) AS overall_cache_hit_pct
FROM pg_stat_insights;
```

### Tables with Most Cache Misses

```sql
-- Extract table names from queries
SELECT 
    substring(query from 'FROM ([a-z_]+)') AS table_name,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls,
    SUM(shared_blks_read) AS total_blocks_read,
    ROUND(AVG(cache_hit_ratio)::numeric, 3) AS avg_cache_ratio
FROM pg_stat_insights
WHERE query LIKE '%FROM %'
GROUP BY substring(query from 'FROM ([a-z_]+)')
HAVING SUM(shared_blks_read) > 1000
ORDER BY SUM(shared_blks_read) DESC
LIMIT 20;
```

---

## I/O Analysis

### Top I/O Consumers

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_read + local_blks_read + temp_blks_read AS total_blks_read,
    pg_size_pretty(((shared_blks_read + local_blks_read + temp_blks_read) * 8192)::bigint) AS total_read,
    ROUND((shared_blk_read_time + local_blk_read_time + temp_blk_read_time)::numeric, 2) AS total_read_time_ms,
    ROUND(((shared_blk_read_time + local_blk_read_time + temp_blk_read_time) / 
           NULLIF(shared_blks_read + local_blks_read + temp_blks_read, 0))::numeric, 3) AS ms_per_block
FROM pg_stat_insights_top_by_io
LIMIT 20;
```

### Queries Using Temp Files

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    temp_blks_written,
    pg_size_pretty((temp_blks_written * 8192)::bigint) AS temp_written,
    ROUND(temp_blk_write_time::numeric, 2) AS write_time_ms,
    ROUND((temp_blk_write_time / NULLIF(temp_blks_written, 0))::numeric, 3) AS ms_per_block
FROM pg_stat_insights
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 20;
```

### I/O Timing Analysis

Requires `track_io_timing = on`

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_read,
    ROUND(shared_blk_read_time::numeric, 2) AS read_time_ms,
    ROUND((shared_blk_read_time / NULLIF(shared_blks_read, 0))::numeric, 3) AS ms_per_block,
    CASE 
        WHEN shared_blk_read_time / NULLIF(shared_blks_read, 0) > 10 THEN '[SLOW] Very Slow Storage'
        WHEN shared_blk_read_time / NULLIF(shared_blks_read, 0) > 1 THEN '[WARNING] Slow Storage'
        WHEN shared_blk_read_time / NULLIF(shared_blks_read, 0) > 0.1 THEN '[OK] Normal (HDD)'
        ELSE '[FAST] Fast (SSD)'
    END AS storage_speed
FROM pg_stat_insights
WHERE shared_blks_read > 100
ORDER BY (shared_blk_read_time / NULLIF(shared_blks_read, 0)) DESC
LIMIT 20;
```

---

## WAL Monitoring

### Top WAL Generators

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    wal_records,
    wal_fpi,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    pg_size_pretty((wal_bytes / NULLIF(calls, 0))::bigint) AS wal_per_call
FROM pg_stat_insights
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 20;
```

### WAL Generation by Query Type

```sql
SELECT 
    CASE 
        WHEN query LIKE 'INSERT%' THEN 'INSERT'
        WHEN query LIKE 'UPDATE%' THEN 'UPDATE'
        WHEN query LIKE 'DELETE%' THEN 'DELETE'
        WHEN query LIKE 'CREATE%' THEN 'CREATE'
        WHEN query LIKE 'ALTER%' THEN 'ALTER'
        ELSE 'OTHER'
    END AS query_type,
    COUNT(*) AS query_count,
    SUM(calls) AS total_calls,
    pg_size_pretty(SUM(wal_bytes)::bigint) AS total_wal,
    pg_size_pretty(AVG(wal_bytes / NULLIF(calls, 0))::bigint) AS avg_wal_per_call
FROM pg_stat_insights
WHERE wal_bytes > 0
GROUP BY query_type
ORDER BY SUM(wal_bytes) DESC;
```

### Estimate Replication Lag Source

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) AS wal_generated,
    wal_buffers_full,
    ROUND((wal_bytes::numeric / SUM(wal_bytes) OVER () * 100), 1) AS pct_of_total_wal
FROM pg_stat_insights
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 20;
```

---

## Query Tuning

### Find Missing Index Opportunities

```sql
-- Queries doing sequential scans with cache misses
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    rows,
    ROUND((rows::numeric / NULLIF(calls, 0)), 0) AS avg_rows_per_call,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    shared_blks_read,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms
FROM pg_stat_insights
WHERE query LIKE '%WHERE %'
  AND shared_blks_read > 100
  AND cache_hit_ratio < 0.95
  AND calls > 10
ORDER BY (shared_blks_read * calls) DESC
LIMIT 20;
```

### Analyze JOIN Performance

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    rows,
    ROUND((rows::numeric / NULLIF(calls, 0)), 0) AS avg_rows,
    shared_blks_read,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio
FROM pg_stat_insights
WHERE query LIKE '%JOIN%'
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Find Queries Benefiting from Parallelization

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    rows,
    shared_blks_read,
    parallel_workers_launched,
    CASE 
        WHEN parallel_workers_launched = 0 AND rows > 10000 THEN '[TARGET] Parallel Candidate'
        WHEN parallel_workers_launched > 0 THEN '[OK] Using Parallel'
        ELSE '[NONE] No Parallel Needed'
    END AS parallel_status
FROM pg_stat_insights
WHERE calls > 5 AND mean_exec_time > 100
ORDER BY (CASE WHEN parallel_workers_launched = 0 THEN rows ELSE 0 END) DESC
LIMIT 20;
```

### Prepared Statement Efficiency

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    plans,
    calls,
    ROUND((plans::numeric / NULLIF(calls, 0)), 3) AS plan_per_call_ratio,
    ROUND(mean_plan_time::numeric, 3) AS avg_plan_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_exec_ms,
    CASE 
        WHEN plans::numeric / NULLIF(calls, 0) < 0.1 THEN '[OK] Efficient Caching'
        WHEN plans::numeric / NULLIF(calls, 0) < 0.5 THEN '[WARNING] Some Replanning'
        ELSE '[CRITICAL] High Replanning'
    END AS caching_status
FROM pg_stat_insights
WHERE plans > 0 AND calls > 10
ORDER BY (plans::numeric / NULLIF(calls, 0)) DESC
LIMIT 20;
```

---

## Cache Optimization

### Table-Level Cache Analysis

```sql
-- Extract table names and analyze cache performance
WITH table_stats AS (
    SELECT 
        regexp_replace(query, '.*FROM\s+([a-z_]+).*', '\1') AS table_name,
        SUM(calls) AS total_calls,
        SUM(shared_blks_hit) AS total_hits,
        SUM(shared_blks_read) AS total_reads,
        SUM(total_exec_time) AS total_time
    FROM pg_stat_insights
    WHERE query ~* 'FROM\s+[a-z_]+'
    GROUP BY regexp_replace(query, '.*FROM\s+([a-z_]+).*', '\1')
)
SELECT 
    table_name,
    total_calls,
    ROUND((total_hits::numeric / NULLIF(total_hits + total_reads, 0))::numeric, 3) AS cache_hit_ratio,
    pg_size_pretty((total_reads * 8192)::bigint) AS disk_reads,
    ROUND(total_time::numeric, 2) AS total_time_ms
FROM table_stats
WHERE total_hits + total_reads > 0
ORDER BY total_reads DESC
LIMIT 20;
```

### Queries Needing More Memory

```sql
-- Queries using temp files (work_mem overflow)
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    temp_blks_written,
    pg_size_pretty((temp_blks_written * 8192)::bigint) AS temp_size,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    pg_size_pretty(((temp_blks_written * 8192 / NULLIF(calls, 0)) * 1.5)::bigint) AS recommended_work_mem
FROM pg_stat_insights
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 20;
```

### Effective Working Set Size

```sql
SELECT 
    pg_size_pretty(SUM(DISTINCT (shared_blks_hit + shared_blks_read) * 8192)::bigint) AS working_set_size,
    pg_size_pretty((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')::bigint) AS current_shared_buffers,
    CASE 
        WHEN SUM(DISTINCT (shared_blks_hit + shared_blks_read) * 8192) > 
             (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')
        THEN '[WARNING] Increase shared_buffers'
        ELSE '[OK] Buffer size adequate'
    END AS recommendation
FROM pg_stat_insights;
```

---

## I/O Analysis

### Disk I/O Hotspots

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_read,
    pg_size_pretty((shared_blks_read * 8192)::bigint) AS data_read,
    ROUND(shared_blk_read_time::numeric, 2) AS read_time_ms,
    ROUND((shared_blk_read_time / NULLIF(calls, 0))::numeric, 2) AS ms_per_call,
    ROUND((shared_blks_read::numeric / NULLIF(calls, 0)), 0) AS blocks_per_call
FROM pg_stat_insights
WHERE shared_blks_read > 0
ORDER BY (shared_blks_read * calls) DESC
LIMIT 20;
```

### Write-Heavy Queries

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_written + local_blks_written + temp_blks_written AS total_writes,
    pg_size_pretty(((shared_blks_written + local_blks_written + temp_blks_written) * 8192)::bigint) AS data_written,
    ROUND((shared_blk_write_time + local_blk_write_time + temp_blk_write_time)::numeric, 2) AS write_time_ms
FROM pg_stat_insights
WHERE (shared_blks_written + local_blks_written + temp_blks_written) > 0
ORDER BY (shared_blks_written + local_blks_written + temp_blks_written) DESC
LIMIT 20;
```

### Dirtied Blocks Analysis

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    shared_blks_dirtied,
    shared_blks_written,
    ROUND((shared_blks_written::numeric / NULLIF(shared_blks_dirtied, 0) * 100), 1) AS write_ratio_pct,
    pg_size_pretty((shared_blks_dirtied * 8192)::bigint) AS dirty_data
FROM pg_stat_insights
WHERE shared_blks_dirtied > 0
ORDER BY shared_blks_dirtied DESC
LIMIT 20;
```

---

## WAL Monitoring

### WAL Generation Rate

```sql
SELECT 
    DATE_TRUNC('hour', stats_since) AS hour,
    COUNT(*) AS query_types,
    pg_size_pretty(SUM(wal_bytes)::bigint) AS total_wal,
    SUM(wal_records) AS total_records,
    SUM(wal_fpi) AS total_fpi,
    pg_size_pretty((SUM(wal_bytes) / EXTRACT(EPOCH FROM (NOW() - MIN(stats_since)))::bigint)) AS wal_per_second
FROM pg_stat_insights
WHERE wal_bytes > 0
GROUP BY DATE_TRUNC('hour', stats_since)
ORDER BY hour DESC
LIMIT 24;
```

### Queries Causing Checkpoint Pressure

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    wal_fpi AS full_page_images,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    ROUND((wal_fpi::numeric / NULLIF(wal_records, 0) * 100), 1) AS fpi_ratio
FROM pg_stat_insights
WHERE wal_fpi > 0
ORDER BY wal_fpi DESC
LIMIT 20;
```

### WAL Buffer Saturation

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    wal_buffers_full,
    ROUND((wal_buffers_full::numeric / NULLIF(calls, 0) * 100), 1) AS buffer_full_pct,
    pg_size_pretty(wal_bytes::bigint) AS wal_size
FROM pg_stat_insights
WHERE wal_buffers_full > 0
ORDER BY wal_buffers_full DESC
LIMIT 20;
```

---

## Query Tuning

### JIT Cost vs Benefit

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    jit_functions,
    ROUND(jit_generation_time::numeric, 2) AS jit_time_ms,
    ROUND(mean_exec_time::numeric, 2) AS exec_time_ms,
    ROUND((jit_generation_time / NULLIF(mean_exec_time, 0) * 100)::numeric, 1) AS jit_overhead_pct,
    CASE 
        WHEN jit_generation_time / NULLIF(mean_exec_time, 0) > 0.1 THEN '[CRITICAL] High JIT Overhead'
        WHEN jit_functions > 0 THEN '[OK] JIT Beneficial'
        ELSE '[NONE] No JIT'
    END AS jit_recommendation
FROM pg_stat_insights
WHERE mean_exec_time > 0
ORDER BY jit_generation_time DESC
LIMIT 20;
```

### Planning vs Execution Time

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    plans,
    ROUND(mean_plan_time::numeric, 2) AS avg_plan_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_exec_ms,
    ROUND((mean_plan_time / NULLIF(mean_exec_time, 0) * 100)::numeric, 1) AS plan_overhead_pct,
    CASE 
        WHEN mean_plan_time > mean_exec_time THEN '[WARNING] Planning Expensive'
        WHEN mean_plan_time > mean_exec_time * 0.1 THEN '[DATA] High Planning Cost'
        ELSE '[OK] Planning Efficient'
    END AS planning_status
FROM pg_stat_insights
WHERE plans > 0 AND mean_exec_time > 0
ORDER BY (mean_plan_time / NULLIF(mean_exec_time, 0)) DESC
LIMIT 20;
```

### Row Efficiency

```sql
-- Time per row processed
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    rows,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND((rows::numeric / NULLIF(calls, 0)), 0) AS rows_per_call,
    ROUND((mean_exec_time / NULLIF(rows::numeric / NULLIF(calls, 0), 0))::numeric, 4) AS ms_per_row
FROM pg_stat_insights
WHERE rows > 0 AND calls > 5
ORDER BY (mean_exec_time / NULLIF(rows::numeric / NULLIF(calls, 0), 0)) DESC
LIMIT 20;
```

---

## Trend Analysis

### Daily Query Performance

```sql
SELECT 
    DATE_TRUNC('day', bucket_start)::date AS day,
    COUNT(DISTINCT queryid) AS unique_queries,
    SUM(total_calls) AS total_executions,
    ROUND(AVG(avg_time)::numeric, 2) AS avg_response_ms,
    ROUND(MAX(avg_time)::numeric, 2) AS max_response_ms
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', bucket_start)::date
ORDER BY day DESC;
```

### Peak Performance Periods

```sql
SELECT 
    EXTRACT(DOW FROM bucket_start) AS day_of_week,
    EXTRACT(HOUR FROM bucket_start) AS hour_of_day,
    COUNT(*) AS sample_count,
    SUM(total_calls) AS total_calls,
    ROUND(AVG(avg_time)::numeric, 2) AS avg_response_ms
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '7 days'
GROUP BY EXTRACT(DOW FROM bucket_start), EXTRACT(HOUR FROM bucket_start)
ORDER BY SUM(total_calls) DESC
LIMIT 20;
```

### Response Time Distribution Over Time

```sql
SELECT 
    DATE_TRUNC('hour', bucket_start) AS hour,
    SUM(CASE WHEN avg_time < 1 THEN query_count ELSE 0 END) AS fast_queries,
    SUM(CASE WHEN avg_time BETWEEN 1 AND 10 THEN query_count ELSE 0 END) AS medium_queries,
    SUM(CASE WHEN avg_time BETWEEN 10 AND 100 THEN query_count ELSE 0 END) AS slow_queries,
    SUM(CASE WHEN avg_time > 100 THEN query_count ELSE 0 END) AS very_slow_queries
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', bucket_start)
ORDER BY hour DESC;
```

---

## Alerting Monitoring

### Create Performance Dashboard

```sql
-- Comprehensive performance dashboard
SELECT 
    'Total Queries' AS metric,
    COUNT(*)::text AS value
FROM pg_stat_insights
UNION ALL
SELECT 
    'Total Executions',
    SUM(calls)::text
FROM pg_stat_insights
UNION ALL
SELECT 
    'Avg Response Time',
    ROUND(AVG(mean_exec_time)::numeric, 2)::text || ' ms'
FROM pg_stat_insights
UNION ALL
SELECT 
    'Cache Hit Ratio',
    ROUND((SUM(shared_blks_hit)::numeric / 
           NULLIF(SUM(shared_blks_hit + shared_blks_read), 0) * 100), 1)::text || '%'
FROM pg_stat_insights
UNION ALL
SELECT 
    'Total WAL Generated',
    pg_size_pretty(SUM(wal_bytes)::bigint)
FROM pg_stat_insights
UNION ALL
SELECT 
    'Slow Queries (>100ms)',
    COUNT(*)::text
FROM pg_stat_insights_slow_queries;
```

### Performance Alerts

```sql
-- Generate performance alerts
SELECT 
    'SLOW_QUERY' AS alert_type,
    'CRITICAL' AS severity,
    LEFT(query, 100) AS detail,
    ROUND(mean_exec_time::numeric, 2)::text || ' ms' AS value
FROM pg_stat_insights
WHERE mean_exec_time > 1000 AND calls > 5
UNION ALL
SELECT 
    'LOW_CACHE_RATIO',
    'WARNING',
    LEFT(query, 100),
    ROUND(cache_hit_ratio::numeric, 3)::text
FROM pg_stat_insights
WHERE cache_hit_ratio < 0.9 AND calls > 10 AND (shared_blks_hit + shared_blks_read) > 100
UNION ALL
SELECT 
    'HIGH_WAL',
    'INFO',
    LEFT(query, 100),
    pg_size_pretty(wal_bytes::bigint)
FROM pg_stat_insights
WHERE wal_bytes > 10000000 AND calls > 5
ORDER BY severity, alert_type;
```

### SLA Monitoring

```sql
-- Monitor 95th percentile response time
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND((mean_exec_time + 2 * stddev_exec_time)::numeric, 2) AS p95_estimate_ms,
    CASE 
        WHEN (mean_exec_time + 2 * stddev_exec_time) > 1000 THEN '[CRITICAL] SLA Violation'
        WHEN (mean_exec_time + 2 * stddev_exec_time) > 500 THEN '[WARNING] SLA Risk'
        ELSE '[OK] SLA Met'
    END AS sla_status
FROM pg_stat_insights
WHERE calls > 10 AND stddev_exec_time > 0
ORDER BY (mean_exec_time + 2 * stddev_exec_time) DESC
LIMIT 20;
```

---

## Troubleshooting

### Find Queries Causing Deadlocks

```sql
-- Look for queries that might cause contention
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    rows,
    wal_bytes
FROM pg_stat_insights
WHERE query ~* '(UPDATE|DELETE).*(JOIN|SELECT)'
   OR query ~* 'FOR UPDATE'
ORDER BY calls DESC
LIMIT 20;
```

### Identify Long-Running Batch Operations

```sql
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    rows,
    pg_size_pretty(wal_bytes::bigint) AS wal_generated
FROM pg_stat_insights
WHERE max_exec_time > 10000  -- > 10 seconds
ORDER BY max_exec_time DESC
LIMIT 20;
```

### Queries with Lock Contention Indicators

```sql
-- High variability + long max time = potential locking issues
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(min_exec_time::numeric, 2) AS min_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms,
    ROUND((max_exec_time / NULLIF(min_exec_time, 1))::numeric, 1) AS variability,
    CASE 
        WHEN max_exec_time / NULLIF(min_exec_time, 1) > 100 THEN '[CRITICAL] High Contention Risk'
        WHEN max_exec_time / NULLIF(min_exec_time, 1) > 10 THEN '[WARNING] Moderate Variability'
        ELSE '[OK] Stable'
    END AS contention_risk
FROM pg_stat_insights
WHERE calls > 10 AND min_exec_time > 0
ORDER BY (max_exec_time / NULLIF(min_exec_time, 1)) DESC
LIMIT 20;
```

---

## Advanced Queries

### Query Performance Score

```sql
-- Composite performance score (lower is better)
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND((
        (mean_exec_time / 100) * 0.4 +  -- Execution time (40%)
        ((1 - cache_hit_ratio) * 100) * 0.3 +  -- Cache misses (30%)
        (wal_bytes / 1000000.0) * 0.2 +  -- WAL generation (20%)
        (temp_blks_written / 100.0) * 0.1  -- Temp usage (10%)
    )::numeric, 2) AS performance_score,
    CASE 
        WHEN (mean_exec_time / 100) * 0.4 + ((1 - cache_hit_ratio) * 100) * 0.3 + 
             (wal_bytes / 1000000.0) * 0.2 + (temp_blks_written / 100.0) * 0.1 > 10 
        THEN '[CRITICAL] Critical'
        WHEN (mean_exec_time / 100) * 0.4 + ((1 - cache_hit_ratio) * 100) * 0.3 + 
             (wal_bytes / 1000000.0) * 0.2 + (temp_blks_written / 100.0) * 0.1 > 5 
        THEN '[WARNING] Warning'
        ELSE '[OK] Good'
    END AS status
FROM pg_stat_insights
WHERE calls > 10
ORDER BY performance_score DESC
LIMIT 20;
```

### Resource Consumption by Query Type

```sql
SELECT 
    CASE 
        WHEN query LIKE 'SELECT%' THEN 'SELECT'
        WHEN query LIKE 'INSERT%' THEN 'INSERT'
        WHEN query LIKE 'UPDATE%' THEN 'UPDATE'
        WHEN query LIKE 'DELETE%' THEN 'DELETE'
        WHEN query LIKE 'CREATE%' THEN 'CREATE'
        WHEN query LIKE 'ALTER%' THEN 'ALTER'
        WHEN query LIKE 'DROP%' THEN 'DROP'
        ELSE 'OTHER'
    END AS query_type,
    COUNT(*) AS query_patterns,
    SUM(calls) AS total_calls,
    ROUND(SUM(total_exec_time)::numeric, 2) AS total_time_ms,
    ROUND(AVG(mean_exec_time)::numeric, 2) AS avg_time_ms,
    SUM(rows) AS total_rows,
    ROUND(AVG(cache_hit_ratio)::numeric, 3) AS avg_cache_ratio,
    pg_size_pretty(SUM(wal_bytes)::bigint) AS total_wal
FROM pg_stat_insights
GROUP BY query_type
ORDER BY SUM(total_exec_time) DESC;
```

### Time-to-First-Row Analysis

```sql
-- Analyze queries that return results incrementally
SELECT 
    LEFT(query, 100) AS query_preview,
    calls,
    rows,
    ROUND(mean_exec_time::numeric, 2) AS total_time_ms,
    ROUND((mean_exec_time / NULLIF(rows::numeric / NULLIF(calls, 0), 0))::numeric, 4) AS ms_per_row,
    CASE 
        WHEN query LIKE '%LIMIT%' THEN '[PAGE] Uses LIMIT'
        WHEN query LIKE '%FETCH%' THEN '[PAGE] Uses CURSOR'
        ELSE '[FULL] Full Result'
    END AS fetch_mode
FROM pg_stat_insights
WHERE rows > 0 AND calls > 5
ORDER BY (mean_exec_time / NULLIF(rows::numeric / NULLIF(calls, 0), 0)) DESC
LIMIT 20;
```

---

## Reporting

### Executive Summary Report

```sql
-- High-level performance summary
WITH stats AS (
    SELECT 
        COUNT(*) AS total_queries,
        SUM(calls) AS total_executions,
        ROUND(SUM(total_exec_time)::numeric, 2) AS total_time_ms,
        ROUND(AVG(mean_exec_time)::numeric, 2) AS avg_response_ms,
        ROUND((SUM(shared_blks_hit)::numeric / 
               NULLIF(SUM(shared_blks_hit + shared_blks_read), 0) * 100), 1) AS cache_hit_pct,
        pg_size_pretty(SUM(wal_bytes)::bigint) AS total_wal,
        COUNT(*) FILTER (WHERE mean_exec_time > 100) AS slow_query_count
    FROM pg_stat_insights
)
SELECT 
    '[DATA] **Performance Summary**' AS section,
    '' AS metric,
    '' AS value
UNION ALL SELECT '', 'Total Query Patterns', total_queries::text FROM stats
UNION ALL SELECT '', 'Total Executions', total_executions::text FROM stats
UNION ALL SELECT '', 'Total Execution Time', total_time_ms::text || ' ms' FROM stats
UNION ALL SELECT '', 'Avg Response Time', avg_response_ms::text || ' ms' FROM stats
UNION ALL SELECT '', 'Cache Hit Ratio', cache_hit_pct::text || '%' FROM stats
UNION ALL SELECT '', 'Total WAL Generated', total_wal FROM stats
UNION ALL SELECT '', 'Slow Queries (>100ms)', slow_query_count::text FROM stats;
```

### Weekly Performance Report

```sql
SELECT 
    'Week of ' || DATE_TRUNC('week', bucket_start)::date AS week,
    COUNT(DISTINCT queryid) AS unique_queries,
    SUM(total_calls) AS executions,
    ROUND(AVG(avg_time)::numeric, 2) AS avg_response_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_time)::numeric, 2) AS p95_response_ms,
    ROUND(MAX(avg_time)::numeric, 2) AS max_response_ms
FROM pg_stat_insights_by_bucket
WHERE bucket_start >= NOW() - INTERVAL '4 weeks'
GROUP BY DATE_TRUNC('week', bucket_start)
ORDER BY week DESC;
```

---

## Next Steps

- **[Views Reference](views.md)** - Explore all 11 views
- **[Configuration](configuration.md)** - Configure parameters
- **[Troubleshooting](troubleshooting.md)** - Solve issues
- **[Testing Guide](testing.md)** - Run regression tests

