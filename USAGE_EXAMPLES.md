# Usage Examples - pg_stat_insights

## Quick Start Queries

### Top Slow Queries

```sql
-- Top 10 slowest queries by total time
SELECT 
    query,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_ms,
    ROUND(exec_time_p95::numeric, 2) AS p95_ms,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio
FROM pg_stat_insights_top_by_time
LIMIT 10;
```

### Cache Analysis

```sql
-- Queries with poor cache performance
SELECT * FROM pg_stat_insights_top_cache_misses LIMIT 20;
```

### Response Time Distribution

```sql
-- View query response time histogram
SELECT 
    query,
    calls,
    resp_calls_under_1ms,
    resp_calls_1_to_10ms,
    resp_calls_10_to_100ms,
    resp_calls_100ms_to_1s,
    resp_calls_over_1s
FROM pg_stat_insights_histogram_summary
WHERE calls > 100;
```

## Performance Analysis

### SLA Monitoring with Percentiles

```sql
SELECT 
    query,
    calls,
    ROUND(exec_time_p50::numeric, 2) AS median_ms,
    ROUND(exec_time_p95::numeric, 2) AS p95_ms,
    ROUND(exec_time_p99::numeric, 2) AS p99_ms,
    CASE 
        WHEN exec_time_p95 < 100 THEN 'Excellent'
        WHEN exec_time_p95 < 500 THEN 'Good'
        WHEN exec_time_p95 < 1000 THEN 'Acceptable'
        ELSE 'Poor'
    END as sla_status
FROM pg_stat_insights
WHERE calls > 50
ORDER BY exec_time_p99 DESC;
```

### Plan Accuracy Issues

```sql
-- Queries where planner estimates are wrong
SELECT * FROM pg_stat_insights_plan_errors
WHERE plan_accuracy_ratio > 10 OR plan_accuracy_ratio < 0.1;
```

### I/O Intensive Queries

```sql
SELECT 
    query,
    calls,
    shared_blks_read + local_blks_read AS total_reads,
    io_histogram_over_1000 AS heavy_io_calls
FROM pg_stat_insights_top_by_io
LIMIT 20;
```

## Error Tracking

### Queries with Errors

```sql
SELECT * FROM pg_stat_insights_errors
WHERE error_count > 0
ORDER BY error_count DESC;
```

### Error Details

```sql
SELECT 
    query,
    error_count,
    last_error_message,
    retry_count
FROM pg_stat_insights
WHERE error_count > 0;
```

## Time-Series Analysis

### Bucket Aggregation

```sql
SELECT 
    bucket_start_time,
    COUNT(*) as query_count,
    SUM(bucket_calls) as total_calls,
    AVG(bucket_total_time) as avg_time
FROM pg_stat_insights_by_bucket
GROUP BY bucket_start_time
ORDER BY bucket_start_time DESC;
```

### Query Trends

```sql
SELECT 
    query,
    first_seen,
    last_executed,
    age(last_executed, first_seen) as query_age,
    calls
FROM pg_stat_insights
WHERE calls > 100
ORDER BY query_age DESC;
```

## Advanced Queries

### Memory Usage Analysis

```sql
SELECT 
    query,
    calls,
    memory_usage_bytes / 1024 / 1024 AS memory_mb,
    shared_mem_bytes / 1024 / 1024 AS shared_mb,
    temp_mem_bytes / 1024 / 1024 AS temp_mb
FROM pg_stat_insights
WHERE memory_usage_bytes > 0
ORDER BY memory_usage_bytes DESC
LIMIT 20;
```

### Network Performance

```sql
SELECT 
    query,
    calls,
    ROUND(network_latency_avg::numeric, 2) AS avg_latency_ms,
    ROUND(network_latency_max::numeric, 2) AS max_latency_ms,
    network_bytes_sent / 1024 AS kb_sent,
    network_bytes_received / 1024 AS kb_received
FROM pg_stat_insights
WHERE network_latency_avg > 0
ORDER BY network_latency_avg DESC;
```

### Plan Structure Analysis

```sql
SELECT 
    query,
    uses_index,
    uses_seq_scan,
    uses_hash_join,
    uses_nested_loop,
    plan_node_count,
    plan_max_depth
FROM pg_stat_insights
WHERE calls > 100 AND uses_seq_scan = true;
```

## Maintenance

### Reset Statistics

```sql
-- Reset all statistics
SELECT pg_stat_insights_reset();

-- Reset specific query statistics
SELECT pg_stat_insights_reset(userid, dbid, queryid);
```

### Check Extension Status

```sql
-- View extension version
SELECT extname, extversion, extrelocatable 
FROM pg_extension 
WHERE extname = 'pg_stat_insights';

-- View configuration
SHOW shared_preload_libraries;
```

## Configuration Examples

### Enable All Features

```sql
-- Production-balanced configuration
ALTER SYSTEM SET pg_stat_insights.max = 10000;
ALTER SYSTEM SET pg_stat_insights.track = 'top';
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
ALTER SYSTEM SET pg_stat_insights.track_histograms = on;
ALTER SYSTEM SET pg_stat_insights.bucket_time = 300;
ALTER SYSTEM SET pg_stat_insights.max_buckets = 12;

SELECT pg_reload_conf();
```

### Development Configuration

```sql
-- Detailed tracking for development
ALTER SYSTEM SET pg_stat_insights.max = 5000;
ALTER SYSTEM SET pg_stat_insights.track = 'all';
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
ALTER SYSTEM SET pg_stat_insights.track_histograms = on;
ALTER SYSTEM SET pg_stat_insights.capture_comments = on;
ALTER SYSTEM SET pg_stat_insights.bucket_time = 60;

SELECT pg_reload_conf();
```

## Integration Examples

### Dashboard Query

```sql
-- Single query for monitoring dashboard
SELECT 
    COUNT(*) as total_queries,
    SUM(calls) as total_executions,
    ROUND(AVG(mean_exec_time)::numeric, 2) as avg_time_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY mean_exec_time)::numeric, 2) as p95_ms,
    ROUND(AVG(cache_hit_ratio)::numeric, 3) as avg_cache_ratio,
    COUNT(*) FILTER (WHERE error_count > 0) as queries_with_errors
FROM pg_stat_insights;
```

### Alerting Query

```sql
-- Identify queries needing attention
SELECT 
    query,
    calls,
    exec_time_p95,
    cache_hit_ratio,
    error_count,
    CASE 
        WHEN exec_time_p95 > 5000 THEN 'CRITICAL: Very slow (>5s)'
        WHEN cache_hit_ratio < 0.5 THEN 'WARNING: Poor cache performance'
        WHEN error_count > 0 THEN 'ERROR: Query failures detected'
        WHEN plan_accuracy_ratio > 100 THEN 'WARNING: Poor plan estimates'
        ELSE 'OK'
    END as alert_level
FROM pg_stat_insights
WHERE calls > 10
    AND (exec_time_p95 > 5000 
         OR cache_hit_ratio < 0.5 
         OR error_count > 0
         OR plan_accuracy_ratio > 100);
```

## See Also

- [Installation Guide](INSTALL.md)
- [Configuration Reference](pg_stat_insights.conf)
- [Complete README](README.md)
- [Contributing Guidelines](CONTRIBUTING.md)
