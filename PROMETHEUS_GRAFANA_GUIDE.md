# pg_stat_insights with Prometheus & Grafana

Complete guide to visualizing pg_stat_insights metrics in Grafana using Prometheus.

## Architecture

```
PostgreSQL + pg_stat_insights
        ↓
postgres_exporter (custom queries)
        ↓
Prometheus (scraping)
        ↓
Grafana (visualization)
```

## Step 1: Install postgres_exporter

### Using Docker

```bash
docker run -d \
  --name postgres_exporter \
  --net=host \
  -e DATA_SOURCE_NAME="postgresql://monitoring_user:password@localhost:5432/your_db?sslmode=disable" \
  -v $(pwd)/pg_stat_insights_queries.yml:/queries.yml \
  -p 9187:9187 \
  prometheuscommunity/postgres-exporter \
  --extend.query-path=/queries.yml
```

### Using Binary

```bash
# Download
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v0.15.0/postgres_exporter-0.15.0.linux-amd64.tar.gz
tar xvfz postgres_exporter-0.15.0.linux-amd64.tar.gz
cd postgres_exporter-0.15.0.linux-amd64

# Configure
export DATA_SOURCE_NAME="postgresql://monitoring_user:password@localhost:5432/your_db?sslmode=disable"

# Run with custom queries
./postgres_exporter --extend.query-path=pg_stat_insights_queries.yml
```

## Step 2: Create Monitoring User in PostgreSQL

```sql
-- Create monitoring user
CREATE USER monitoring_user WITH PASSWORD 'secure_password';

-- Grant permissions
GRANT CONNECT ON DATABASE your_database TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;
GRANT pg_monitor TO monitoring_user;  -- PostgreSQL 10+

-- For pg_stat_insights specifically
GRANT SELECT ON pg_stat_insights TO monitoring_user;
GRANT SELECT ON pg_stat_insights_top_by_time TO monitoring_user;
GRANT SELECT ON pg_stat_insights_top_by_calls TO monitoring_user;
GRANT SELECT ON pg_stat_insights_top_by_io TO monitoring_user;
GRANT SELECT ON pg_stat_insights_histogram_summary TO monitoring_user;
GRANT SELECT ON pg_stat_insights_by_bucket TO monitoring_user;
```

## Step 3: Configure Custom Queries

Create `pg_stat_insights_queries.yml`:

```yaml
# pg_stat_insights custom queries for postgres_exporter

pg_stat_insights_overview:
  query: |
    SELECT 
      COUNT(*)::float AS total_queries,
      SUM(calls)::float AS total_calls,
      SUM(total_exec_time)::float AS total_exec_time_ms,
      AVG(mean_exec_time)::float AS avg_exec_time_ms,
      SUM(rows)::float AS total_rows,
      SUM(shared_blks_hit)::float AS cache_hits,
      SUM(shared_blks_read)::float AS cache_misses,
      CASE 
        WHEN SUM(shared_blks_hit + shared_blks_read) > 0 
        THEN (SUM(shared_blks_hit)::float / SUM(shared_blks_hit + shared_blks_read))
        ELSE 0 
      END AS cache_hit_ratio
    FROM pg_stat_insights
    WHERE query NOT LIKE '%pg_stat%';
  metrics:
    - total_queries:
        usage: "GAUGE"
        description: "Total number of unique queries tracked"
    - total_calls:
        usage: "COUNTER"
        description: "Total number of query executions"
    - total_exec_time_ms:
        usage: "COUNTER"
        description: "Total execution time in milliseconds"
    - avg_exec_time_ms:
        usage: "GAUGE"
        description: "Average execution time in milliseconds"
    - total_rows:
        usage: "COUNTER"
        description: "Total rows returned"
    - cache_hits:
        usage: "COUNTER"
        description: "Total shared buffer cache hits"
    - cache_misses:
        usage: "COUNTER"
        description: "Total shared buffer cache misses"
    - cache_hit_ratio:
        usage: "GAUGE"
        description: "Cache hit ratio (0-1)"

pg_stat_insights_top_queries:
  query: |
    SELECT 
      md5(query) AS query_hash,
      LEFT(query, 50) AS query_preview,
      calls::float,
      total_exec_time::float AS exec_time_ms,
      mean_exec_time::float AS avg_time_ms,
      stddev_exec_time::float AS stddev_time_ms,
      rows::float,
      (shared_blks_hit + shared_blks_read)::float AS total_blocks,
      CASE 
        WHEN (shared_blks_hit + shared_blks_read) > 0 
        THEN (shared_blks_hit::float / (shared_blks_hit + shared_blks_read))
        ELSE 0 
      END AS cache_ratio
    FROM pg_stat_insights
    WHERE query NOT LIKE '%pg_stat%'
    ORDER BY total_exec_time DESC
    LIMIT 20;
  metrics:
    - query_hash:
        usage: "LABEL"
        description: "MD5 hash of query"
    - query_preview:
        usage: "LABEL"
        description: "First 50 characters of query"
    - calls:
        usage: "COUNTER"
        description: "Number of times executed"
    - exec_time_ms:
        usage: "COUNTER"
        description: "Total execution time"
    - avg_time_ms:
        usage: "GAUGE"
        description: "Average execution time"
    - stddev_time_ms:
        usage: "GAUGE"
        description: "Standard deviation of execution time"
    - rows:
        usage: "COUNTER"
        description: "Total rows returned"
    - total_blocks:
        usage: "COUNTER"
        description: "Total blocks accessed"
    - cache_ratio:
        usage: "GAUGE"
        description: "Cache hit ratio for this query"

pg_stat_insights_response_time_buckets:
  query: |
    SELECT 
      CASE 
        WHEN mean_exec_time < 1 THEN '0_under_1ms'
        WHEN mean_exec_time < 10 THEN '1_1_to_10ms'
        WHEN mean_exec_time < 100 THEN '2_10_to_100ms'
        WHEN mean_exec_time < 1000 THEN '3_100ms_to_1s'
        WHEN mean_exec_time < 10000 THEN '4_1_to_10s'
        ELSE '5_over_10s'
      END AS response_bucket,
      COUNT(*)::float AS query_count,
      SUM(calls)::float AS total_calls
    FROM pg_stat_insights
    WHERE query NOT LIKE '%pg_stat%'
    GROUP BY response_bucket;
  metrics:
    - response_bucket:
        usage: "LABEL"
        description: "Response time bucket"
    - query_count:
        usage: "GAUGE"
        description: "Number of queries in this bucket"
    - total_calls:
        usage: "COUNTER"
        description: "Total calls in this bucket"

pg_stat_insights_wal_stats:
  query: |
    SELECT 
      SUM(wal_records)::float AS total_wal_records,
      SUM(wal_fpi)::float AS total_wal_fpi,
      SUM(wal_bytes)::float AS total_wal_bytes
    FROM pg_stat_insights
    WHERE wal_records > 0;
  metrics:
    - total_wal_records:
        usage: "COUNTER"
        description: "Total WAL records generated"
    - total_wal_fpi:
        usage: "COUNTER"
        description: "Total WAL full page images"
    - total_wal_bytes:
        usage: "COUNTER"
        description: "Total WAL bytes generated"

pg_stat_insights_slow_queries:
  query: |
    SELECT 
      COUNT(*)::float AS slow_query_count,
      AVG(mean_exec_time)::float AS avg_slow_time_ms,
      MAX(max_exec_time)::float AS max_slow_time_ms
    FROM pg_stat_insights
    WHERE mean_exec_time > 100
      AND query NOT LIKE '%pg_stat%';
  metrics:
    - slow_query_count:
        usage: "GAUGE"
        description: "Number of slow queries (>100ms)"
    - avg_slow_time_ms:
        usage: "GAUGE"
        description: "Average time of slow queries"
    - max_slow_time_ms:
        usage: "GAUGE"
        description: "Maximum execution time of slow queries"
```

## Step 4: Configure Prometheus

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'postgres_pg_stat_insights'
    static_configs:
      - targets: ['localhost:9187']
    scrape_interval: 30s
    scrape_timeout: 10s
```

Restart Prometheus:
```bash
systemctl restart prometheus
# or
docker restart prometheus
```

## Step 5: Verify Metrics in Prometheus

1. Open Prometheus UI: http://localhost:9090
2. Go to "Graph"
3. Try these queries:

```promql
# Total queries tracked
pg_stat_insights_overview_total_queries

# Query execution rate (queries per second)
rate(pg_stat_insights_overview_total_calls[5m])

# Average query execution time
pg_stat_insights_overview_avg_exec_time_ms

# Cache hit ratio
pg_stat_insights_overview_cache_hit_ratio

# Top queries by execution time
topk(10, pg_stat_insights_top_queries_exec_time_ms)
```

## Step 6: Create Grafana Dashboard

### Import Pre-built Dashboard

1. Open Grafana: http://localhost:3000
2. Go to "Dashboards" → "Import"
3. Upload the JSON below or paste it

### Dashboard JSON

Create `pg_stat_insights_dashboard.json`:

```json
{
  "dashboard": {
    "title": "pg_stat_insights - PostgreSQL Query Analytics",
    "tags": ["postgresql", "pg_stat_insights"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Total Queries Tracked",
        "type": "stat",
        "targets": [
          {
            "expr": "pg_stat_insights_overview_total_queries",
            "legendFormat": "Queries"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Queries per Second",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(pg_stat_insights_overview_total_calls[5m])",
            "legendFormat": "QPS"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 3,
        "title": "Average Query Time",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_insights_overview_avg_exec_time_ms",
            "legendFormat": "Avg Time (ms)"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      },
      {
        "id": 4,
        "title": "Cache Hit Ratio",
        "type": "gauge",
        "targets": [
          {
            "expr": "pg_stat_insights_overview_cache_hit_ratio * 100",
            "legendFormat": "Hit %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 90, "color": "yellow"},
                {"value": 99, "color": "green"}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 5,
        "title": "Response Time Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "pg_stat_insights_response_time_buckets_query_count",
            "legendFormat": "{{response_bucket}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12}
      },
      {
        "id": 6,
        "title": "Top 10 Queries by Execution Time",
        "type": "table",
        "targets": [
          {
            "expr": "topk(10, pg_stat_insights_top_queries_exec_time_ms)",
            "legendFormat": "",
            "format": "table"
          }
        ],
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 20}
      },
      {
        "id": 7,
        "title": "WAL Generation Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(pg_stat_insights_wal_stats_total_wal_bytes[5m]) / 1024 / 1024",
            "legendFormat": "WAL MB/s"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12}
      },
      {
        "id": 8,
        "title": "Slow Queries (>100ms)",
        "type": "stat",
        "targets": [
          {
            "expr": "pg_stat_insights_slow_queries_slow_query_count",
            "legendFormat": "Slow Queries"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 10, "color": "yellow"},
                {"value": 50, "color": "red"}
              ]
            }
          }
        },
        "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0}
      }
    ],
    "refresh": "30s",
    "time": {"from": "now-1h", "to": "now"}
  }
}
```

## Step 7: Advanced PromQL Queries

### Query Performance

```promql
# P95 query execution time (approximate)
histogram_quantile(0.95, 
  rate(pg_stat_insights_top_queries_exec_time_ms[5m]))

# Queries with high standard deviation (inconsistent performance)
pg_stat_insights_top_queries_stddev_time_ms > 100

# Query execution time increase (compared to 1 hour ago)
(pg_stat_insights_overview_avg_exec_time_ms - 
 pg_stat_insights_overview_avg_exec_time_ms offset 1h) 
 / pg_stat_insights_overview_avg_exec_time_ms offset 1h * 100
```

### Cache Performance

```promql
# Cache miss rate
rate(pg_stat_insights_overview_cache_misses[5m])

# Cache hit ratio over time
rate(pg_stat_insights_overview_cache_hits[5m]) / 
(rate(pg_stat_insights_overview_cache_hits[5m]) + 
 rate(pg_stat_insights_overview_cache_misses[5m]))
```

### Resource Usage

```promql
# WAL generation rate (MB/s)
rate(pg_stat_insights_wal_stats_total_wal_bytes[5m]) / 1024 / 1024

# Rows processed per second
rate(pg_stat_insights_overview_total_rows[5m])
```

## Step 8: Alerting Rules

Create `pg_stat_insights_alerts.yml`:

```yaml
groups:
  - name: pg_stat_insights_alerts
    interval: 30s
    rules:
      - alert: HighAverageQueryTime
        expr: pg_stat_insights_overview_avg_exec_time_ms > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High average query execution time"
          description: "Average query time is {{ $value }}ms (threshold: 100ms)"

      - alert: LowCacheHitRatio
        expr: pg_stat_insights_overview_cache_hit_ratio < 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low cache hit ratio"
          description: "Cache hit ratio is {{ $value | humanizePercentage }} (threshold: 90%)"

      - alert: TooManySlowQueries
        expr: pg_stat_insights_slow_queries_slow_query_count > 50
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Too many slow queries detected"
          description: "{{ $value }} queries are running slower than 100ms"

      - alert: HighWALGeneration
        expr: rate(pg_stat_insights_wal_stats_total_wal_bytes[5m]) > 100000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High WAL generation rate"
          description: "WAL generation is {{ $value | humanize }}B/s"
```

## Step 9: Grafana Variables

Add these to your dashboard for filtering:

```json
{
  "templating": {
    "list": [
      {
        "name": "database",
        "type": "query",
        "query": "label_values(pg_stat_insights_overview_total_queries, datname)",
        "refresh": 1
      },
      {
        "name": "time_range",
        "type": "interval",
        "options": ["1m", "5m", "15m", "30m", "1h", "6h", "12h", "1d"]
      }
    ]
  }
}
```

## Complete Setup Script

```bash
#!/bin/bash

# Quick setup script for pg_stat_insights monitoring

# 1. Create monitoring user
psql -d your_db << 'SQL'
CREATE USER monitoring_user WITH PASSWORD 'secure_password';
GRANT pg_monitor TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;
SQL

# 2. Start postgres_exporter
docker run -d \
  --name postgres_exporter \
  --net=host \
  -e DATA_SOURCE_NAME="postgresql://monitoring_user:secure_password@localhost:5432/your_db?sslmode=disable" \
  -v $(pwd)/pg_stat_insights_queries.yml:/queries.yml \
  prometheuscommunity/postgres-exporter \
  --extend.query-path=/queries.yml

# 3. Verify exporter is running
curl http://localhost:9187/metrics | grep pg_stat_insights

echo "✓ Setup complete!"
echo "  - postgres_exporter: http://localhost:9187/metrics"
echo "  - Add to Prometheus scrape config"
echo "  - Import Grafana dashboard"
```

## Troubleshooting

### No metrics appearing

```bash
# Check postgres_exporter logs
docker logs postgres_exporter

# Test query manually
psql -U monitoring_user -d your_db -c "SELECT COUNT(*) FROM pg_stat_insights;"

# Verify Prometheus is scraping
curl http://localhost:9090/api/v1/targets
```

### Permission errors

```sql
-- Grant all necessary permissions
GRANT pg_monitor TO monitoring_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO monitoring_user;
```

### High cardinality warning

If you see too many time series, limit the number of tracked queries:

```yaml
# In queries.yml, add LIMIT
query: |
  SELECT ... FROM pg_stat_insights
  ORDER BY total_exec_time DESC
  LIMIT 50;  -- Limit to top 50 queries
```

## Resources

- postgres_exporter: https://github.com/prometheus-community/postgres_exporter
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- pg_stat_insights docs: https://pgelephant.github.io/pg_stat_insights/

