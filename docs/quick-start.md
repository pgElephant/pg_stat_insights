# Quick Start Guide

Get started with pg_stat_insights in **5 minutes** and start monitoring your PostgreSQL query performance.

---

## Prerequisites

- PostgreSQL 14, 15, 16, or 17 installed
- Superuser access to PostgreSQL
- Extension installed (see [Installation Guide](installation.md))

---

## Step 1: Enable Extension (2 minutes)

### Configure PostgreSQL

```sql
-- Connect as superuser
psql -U postgres

-- Enable pg_stat_insights in shared preload libraries
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- Exit psql
\q
```

### Restart PostgreSQL

```bash
# Ubuntu/Debian
sudo systemctl restart postgresql

# RHEL/Rocky/AlmaLinux
sudo systemctl restart postgresql-17

# macOS (Homebrew)
brew services restart postgresql@17
```

!!! success "[OK] Checkpoint 1"
    PostgreSQL should now restart successfully. If not, check logs:
    ```bash
    sudo journalctl -u postgresql -n 50  # Linux
    tail -f /opt/homebrew/var/log/postgresql@17.log  # macOS
    ```

---

## Step 2: Create Extension (30 seconds)

```sql
-- Connect to your database
psql -U postgres -d your_database

-- Create extension
CREATE EXTENSION pg_stat_insights;
```

**Output:**
```
CREATE EXTENSION
```

!!! success "[OK] Checkpoint 2"
    Extension created successfully!

---

## Step 3: Generate Some Activity (1 minute)

Let's create sample queries to track:

```sql
-- Create a test table
CREATE TABLE performance_test (
  id serial PRIMARY KEY,
  name text,
  value numeric,
  created_at timestamp DEFAULT now()
);

-- Insert data
INSERT INTO performance_test (name, value)
SELECT 
  'item_' || i,
  random() * 1000
FROM generate_series(1, 10000) i;

-- Run some queries
SELECT COUNT(*) FROM performance_test;
SELECT AVG(value) FROM performance_test;
SELECT * FROM performance_test WHERE value > 500 ORDER BY value DESC LIMIT 100;
SELECT name, value FROM performance_test WHERE name LIKE 'item_1%';

-- Wait a moment for stats to be collected
SELECT pg_sleep(0.5);
```

!!! success "[OK] Checkpoint 3"
    Sample queries executed. Statistics are being collected!

---

## Step 4: View Your Performance Data (1 minute)

### Find Slowest Queries

```sql
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

**Sample Output:**
```
                    query                    | calls | total_exec_time | mean_exec_time | rows
---------------------------------------------+-------+-----------------+----------------+------
 SELECT * FROM performance_test WHERE...    |     1 |          45.234 |         45.234 |  100
 INSERT INTO performance_test (name, val... |     1 |          32.156 |         32.156 |10000
 SELECT AVG(value) FROM performance_test    |     1 |          12.456 |         12.456 |    1
 SELECT COUNT(*) FROM performance_test      |     1 |           8.234 |          8.234 |    1
```

### Check Cache Efficiency

```sql
SELECT 
    query,
    calls,
    cache_hit_ratio,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_insights_top_cache_misses
LIMIT 10;
```

### View Most Called Queries

```sql
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time
FROM pg_stat_insights_top_by_calls 
LIMIT 10;
```

!!! success "[OK] Checkpoint 4"
    You're now monitoring PostgreSQL query performance!

---

## Step 5: Explore Advanced Features (1 minute)

### Analyze I/O Patterns

```sql
SELECT 
    query,
    calls,
    shared_blks_read + local_blks_read + temp_blks_read AS total_blks_read,
    shared_blk_read_time + local_blk_read_time + temp_blk_read_time AS total_read_time
FROM pg_stat_insights_top_by_io
LIMIT 10;
```

### Check WAL Generation

```sql
SELECT 
    query,
    calls,
    wal_records,
    wal_bytes,
    wal_fpi
FROM pg_stat_insights
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 10;
```

### View Response Time Distribution

```sql
SELECT 
    bucket_label,
    query_count,
    total_time,
    avg_time
FROM pg_stat_insights_histogram_summary
ORDER BY bucket_order;
```

**Sample Output:**
```
  bucket_label  | query_count | total_time | avg_time
----------------+-------------+------------+----------
 < 1ms          |         125 |     45.234 |    0.362
 1-10ms         |          45 |    234.123 |    5.203
 10-100ms       |          12 |    456.789 |   38.066
 100ms-1s       |           3 |    890.123 |  296.708
 > 1s           |           1 |   1234.567 | 1234.567
```

---

## Common Use Cases

### Monitor Production Queries

```sql
-- View queries consuming the most time
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_time_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
    ROUND((total_exec_time / SUM(total_exec_time) OVER () * 100)::numeric, 1) AS pct_total_time
FROM pg_stat_insights
WHERE total_exec_time > 0
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Find Optimization Opportunities

```sql
-- Queries with poor cache hit ratio
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    ROUND(cache_hit_ratio::numeric, 3) AS cache_ratio,
    shared_blks_read,
    shared_blks_hit
FROM pg_stat_insights_top_cache_misses
WHERE cache_hit_ratio < 0.9
LIMIT 15;
```

### Identify Heavy Writers

```sql
-- Queries generating most WAL
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) AS wal_size,
    ROUND((wal_bytes / NULLIF(calls, 0))::numeric, 0) AS bytes_per_call
FROM pg_stat_insights
WHERE wal_bytes > 1000000
ORDER BY wal_bytes DESC
LIMIT 15;
```

### Monitor Parallel Query Efficiency

```sql
-- Check parallel worker utilization
SELECT 
    LEFT(query, 80) AS query_preview,
    calls,
    parallel_workers_to_launch,
    parallel_workers_launched,
    ROUND((parallel_workers_launched::numeric / NULLIF(parallel_workers_to_launch, 0) * 100), 1) AS worker_efficiency_pct
FROM pg_stat_insights
WHERE parallel_workers_to_launch > 0
ORDER BY calls DESC
LIMIT 15;
```

---

## Automation & Monitoring

### Schedule Regular Reports

```sql
-- Create a monitoring view
CREATE VIEW daily_performance_report AS
SELECT 
    current_timestamp AS report_time,
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    cache_hit_ratio
FROM pg_stat_insights_top_by_time
LIMIT 50;

-- Query the report
SELECT * FROM daily_performance_report;
```

### Create Alerts

```sql
-- Find queries exceeding thresholds
CREATE OR REPLACE FUNCTION check_slow_queries()
RETURNS TABLE (
    alert_type text,
    query_preview text,
    metric_value numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'SLOW_QUERY' AS alert_type,
        LEFT(query, 100) AS query_preview,
        mean_exec_time AS metric_value
    FROM pg_stat_insights
    WHERE mean_exec_time > 1000  -- > 1 second
    ORDER BY mean_exec_time DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Run alert check
SELECT * FROM check_slow_queries();
```

### Reset Statistics

```sql
-- Reset all statistics
SELECT pg_stat_insights_reset();

-- Reset specific query
SELECT pg_stat_insights_reset(
    (SELECT oid FROM pg_roles WHERE rolname = 'myuser'),
    (SELECT oid FROM pg_database WHERE datname = current_database()),
    1234567890  -- queryid
);
```

---

## What's Next?

Now that you're up and running:

### [DOCS] Learn More

- **[Configuration Guide](configuration.md)** - Understand all 11 parameters
- **[Views Reference](views.md)** - Explore all 11 views in detail
- **[Metrics Guide](metrics.md)** - Learn about all 52 metrics
- **[Usage Examples](usage.md)** - 50+ real-world SQL queries

### [CONFIG] Advanced Topics

- **[Testing Guide](testing.md)** - Run 22 regression tests
- **[CI/CD Workflows](ci-cd.md)** - GitHub Actions integration
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### [DEPLOY] Integrations

- **Prometheus/Grafana** - Export metrics for visualization
- **pgBadger** - Combine with log analysis
- **Monitoring Tools** - Datadog, New Relic, etc.

---

## Quick Reference Card

### Essential Queries

```sql
-- Top 10 slowest queries
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;

-- Most called queries
SELECT * FROM pg_stat_insights_top_by_calls LIMIT 10;

-- Highest I/O queries
SELECT * FROM pg_stat_insights_top_by_io LIMIT 10;

-- Poor cache performers
SELECT * FROM pg_stat_insights_top_cache_misses LIMIT 10;

-- Slow queries (>100ms)
SELECT * FROM pg_stat_insights_slow_queries;

-- Response time distribution
SELECT * FROM pg_stat_insights_histogram_summary;

-- Reset all stats
SELECT pg_stat_insights_reset();
```

### Essential Commands

```bash
# Build from source
make && sudo make install

# Run tests
make installcheck

# Check version
psql -c "SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_insights';"

# View extension info
psql -c "\dx+ pg_stat_insights"
```

---

## Success Checklist

Before moving to production:

- [x] Extension installed and loaded
- [x] PostgreSQL restarted successfully
- [x] Extension created in target database(s)
- [x] Test queries tracked in `pg_stat_insights`
- [x] All 11 views accessible
- [x] Configuration parameters tuned
- [x] Regression tests passed (22/22)
- [x] Monitoring queries saved
- [x] Alert thresholds defined
- [x] Documentation bookmarked

---

**Success! Congratulations!** You've successfully installed and configured pg_stat_insights. Start monitoring your PostgreSQL performance now!

