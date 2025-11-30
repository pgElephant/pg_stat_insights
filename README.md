# pg_stat_insights

PostgreSQL extension for query performance monitoring.

## Language Support

[English](#overview) | [简体中文](docs/zh_CN/README.md) | [繁體中文](docs/zh_TW/README.md) | [日本語](docs/ja_JP/README.md)

## Overview

pg_stat_insights tracks query performance in PostgreSQL. It records 52 metrics across 42 views. It monitors query execution, cache efficiency, WAL generation, replication health, and index usage.

Works with PostgreSQL 16, 17, and 18.

## Features

- 52 metric columns: execution time, cache hits, WAL generation, JIT stats, buffer I/O
- 42 views: slow queries, cache misses, I/O operations, replication monitoring, index monitoring
- 11 configuration parameters
- Replaces pg_stat_statements with additional metrics
- Response time tracking: categories from less than 1ms to greater than 10s
- Replication monitoring: 17 views for physical and logical replication
- Index monitoring: 11 views for index usage, bloat, efficiency, and maintenance
- Cache analysis: buffer cache efficiency metrics
- WAL monitoring: write-ahead log generation per query
- Time-series data: historical performance trends by time bucket

## Quick Start

Install in 3 steps:

```sql
-- Step 1: Enable extension in PostgreSQL configuration
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- Restart PostgreSQL server required

-- Step 2: Create the extension in your database
CREATE EXTENSION pg_stat_insights;

-- Step 3: View your slowest queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

## Documentation

Complete documentation: [pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)

Quick links:
- [Getting Started](https://pgelephant.github.io/pg_stat_insights/getting-started/)
- [Configuration](https://pgelephant.github.io/pg_stat_insights/configuration/)
- [Views Reference](https://pgelephant.github.io/pg_stat_insights/views/)
- [Metrics Guide](https://pgelephant.github.io/pg_stat_insights/metrics/)
- [Usage Examples](https://pgelephant.github.io/pg_stat_insights/usage/)
- [Prometheus & Grafana](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)
- [Troubleshooting](https://pgelephant.github.io/pg_stat_insights/troubleshooting/)

## Installation

```bash
# Build and install
cd pg_stat_insights
make
sudo make install

# Configure
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /etc/postgresql/*/main/postgresql.conf

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create extension
psql -d your_database -c "CREATE EXTENSION pg_stat_insights;"
```

Detailed instructions: [Installation Guide](https://pgelephant.github.io/pg_stat_insights/install/)

## Views

42 views organized by category:

### Query Performance Views (10 views)

| View | Purpose |
|------|---------|
| `pg_stat_insights` | Main statistics view (52 columns) |
| `pg_stat_insights_top_by_time` | Slowest queries by total time |
| `pg_stat_insights_top_by_calls` | Most frequently called queries |
| `pg_stat_insights_top_by_io` | Highest I/O consumers |
| `pg_stat_insights_top_cache_misses` | Poor cache performers |
| `pg_stat_insights_slow_queries` | Queries with mean time > 100ms |
| `pg_stat_insights_errors` | Queries with errors |
| `pg_stat_insights_plan_errors` | Plan estimation issues |
| `pg_stat_insights_histogram_summary` | Response time distribution |
| `pg_stat_insights_by_bucket` | Time-series aggregation |

### Replication Monitoring Views (17 views)

| View | Purpose |
|------|---------|
| `pg_stat_insights_replication` | Basic replication monitoring |
| `pg_stat_insights_physical_replication` | Physical replication with health status |
| `pg_stat_insights_logical_replication` | Logical replication slots with lag tracking |
| `pg_stat_insights_replication_slots` | All replication slots with health status |
| `pg_stat_insights_replication_summary` | Overall replication activity summary |
| `pg_stat_insights_replication_alerts` | Critical alerts for lag, WAL loss, and inactive slots |
| `pg_stat_insights_replication_wal` | WAL statistics and retention analysis |
| `pg_stat_insights_replication_bottlenecks` | Network, I/O, or replay bottlenecks |
| `pg_stat_insights_replication_conflicts` | Logical replication conflict detection |
| `pg_stat_insights_replication_health` | Health check with recommendations |
| `pg_stat_insights_replication_performance` | Performance trends and throughput analysis |
| `pg_stat_insights_replication_timeline` | Historical timeline and lag trends |
| `pg_stat_insights_subscriptions` | Logical replication subscriptions (subscriber side) |
| `pg_stat_insights_subscription_stats` | Per-table subscription sync status |
| `pg_stat_insights_publications` | Logical replication publications (publisher side) |
| `pg_stat_insights_replication_origins` | Replication origin tracking |
| `pg_stat_insights_replication_dashboard` | Single comprehensive JSON dashboard |

### Index Monitoring Views (11 views)

| View | Purpose |
|------|---------|
| `pg_stat_insights_indexes` | Index statistics with usage metrics |
| `pg_stat_insights_index_usage` | Index scan frequency and utilization |
| `pg_stat_insights_index_bloat` | Index bloat detection and size estimation |
| `pg_stat_insights_index_efficiency` | Index efficiency metrics and cache performance |
| `pg_stat_insights_index_maintenance` | Maintenance recommendations and statistics |
| `pg_stat_insights_missing_indexes` | Potential missing indexes based on sequential scans |
| `pg_stat_insights_index_summary` | Overall index health summary |
| `pg_stat_insights_index_alerts` | Critical alerts for unused, bloated, or missing indexes |
| `pg_stat_insights_index_dashboard` | Single comprehensive index monitoring dashboard |
| `pg_stat_insights_index_size_trends` | Historical index size growth trends |
| `pg_stat_insights_index_lock_contention` | Index lock contention statistics |

### Time-Series Bucket Views (4 views)

| View | Purpose |
|------|---------|
| `pg_stat_insights_by_bucket` | Query performance by time bucket |
| `pg_stat_insights_index_by_bucket` | Index usage statistics by hour bucket |
| `pg_stat_insights_index_size_by_bucket` | Index size trends by day bucket |
| `pg_stat_insights_replication_by_bucket` | Replication statistics by hour bucket |
| `pg_stat_insights_replication_lag_by_bucket` | Replication lag trends by hour bucket |

Bucket views track performance trends over time. Hourly buckets group index usage and replication statistics. Daily buckets group index size growth. They identify growing, shrinking, stable, or volatile patterns. Lag analysis monitors replication lag trends with severity classification.

Complete reference: [Views Documentation](https://pgelephant.github.io/pg_stat_insights/views/)

## Use Cases

- Find slow queries: identify queries consuming excessive execution time
- Optimize cache usage: detect buffer cache misses
- Reduce WAL overhead: monitor write-ahead log generation per query
- Track query patterns: analyze execution frequency and resource consumption
- Monitor replication: physical and logical replication monitoring with bottleneck detection
- Troubleshoot lag: identify network, I/O, or replay bottlenecks
- Optimize indexes: identify unused indexes, detect bloat, find missing indexes
- Monitor index health: track index usage, size trends, lock contention
- Monitor in real-time: integrate with Grafana for dashboards and alerting

## Comparison with Other Extensions

| Feature | pg_stat_statements | pg_stat_monitor | pg_stat_insights |
|---------|:------------------:|:---------------:|:----------------:|
| Metric Columns | 44 | 58 | 52 |
| Pre-built Views | 2 | 5 | 42 |
| Configuration Options | 5 | 12 | 11 |
| Cache Analysis | Basic | Basic | Enhanced with ratios |
| Response Time Categories | No | No | Yes |
| Time-Series Tracking | No | No | Yes |
| Replication Monitoring | No | No | 17 views |
| Index Monitoring | No | No | 11 views |
| Bottleneck Detection | No | No | Network/I/O/Replay analysis |
| Logical Replication | No | No | Subscriptions/Publications |
| Index Bloat Detection | No | No | Yes |
| Missing Index Detection | No | No | Yes |
| Documentation | Basic | Medium | 30+ pages |
| Prometheus Integration | Manual | Manual | Pre-built queries and dashboards |

## Replication Monitoring

Physical and logical replication monitoring:

### Physical Replication (8 views)
- Health monitoring: replica status with HEALTHY/WARNING/CRITICAL classifications
- Bottleneck detection: identify network, disk I/O, or replay bottlenecks
- Performance rating: Excellent to Critical based on lag thresholds
- WAL tracking: monitor WAL retention and disk usage
- Alerts: threshold-based alerting for lag and issues

### Logical Replication (7 views)
- Subscription tracking: monitor subscriber health and sync status
- Publication management: track publisher configuration and active subscribers
- Per-table sync: monitor table-level replication progress
- Conflict detection: identify and troubleshoot replication conflicts
- WAL safety: track WAL segment availability and retention

### Unified Dashboard (1 view)
- JSON dashboard: single view with all replication metrics
- Grafana/Prometheus ready: structured output for monitoring systems
- Complete status: physical replicas, logical slots, alerts in one query

Learn more: [Replication Monitoring Guide](https://pgelephant.github.io/pg_stat_insights/views/)

## Index Monitoring

Index analytics and optimization:

### Index Usage and Efficiency (4 views)
- Usage tracking: monitor index scan frequency and utilization
- Efficiency metrics: cache hit ratios, scan types, performance indicators
- Size trends: historical index size growth tracking
- Lock contention: identify indexes with high lock contention

### Index Health and Maintenance (4 views)
- Bloat detection: identify bloated indexes with size estimation
- Maintenance recommendations: REINDEX and VACUUM suggestions
- Health summary: overall index statistics and status
- Alerts: critical alerts for unused, bloated, or missing indexes

### Index Optimization (3 views)
- Missing indexes: identify potential missing indexes based on sequential scans
- Comprehensive dashboard: single view with all index metrics
- Detailed statistics: complete index information with correlation and partial index usage

Features:
- Bloat estimation: calculate estimated bloat size and percentage
- Usage patterns: track index scans, index-only scans, sequential scans
- Maintenance tracking: monitor last VACUUM and ANALYZE operations
- Size monitoring: track index size growth over time
- Lock analysis: identify indexes with high lock contention

Learn more: [Index Monitoring Guide](https://pgelephant.github.io/pg_stat_insights/views/)

## Prometheus and Grafana Integration

PostgreSQL metrics visualization:

- Prometheus integration: 5 pre-configured queries for postgres_exporter
- Grafana dashboards: 8 panels for query performance visualization
- Alert rules: 11 alerts for database health monitoring
- Query rate tracking: monitor queries per second (QPS) and throughput
- Cache performance: buffer cache hit ratio monitoring
- Response time SLA: track P95/P99 query latency
- WAL generation alerts: monitor write-ahead log growth and disk usage
- Replication monitoring: dashboards for replication health and lag
- Index monitoring: panels for index usage, bloat, and efficiency

Complete Prometheus/Grafana guide: [Monitoring Integration](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)

## Version History

### Version 3.0 (Current)
- Index Monitoring: 11 views for index analytics
- Index bloat detection: automatic bloat estimation and alerts
- Missing index detection: identify potential missing indexes
- Index size trends: historical size growth tracking
- Index lock contention: lock statistics and analysis
- Index efficiency metrics: cache performance and scan type analysis
- Index maintenance recommendations: REINDEX and VACUUM suggestions

### Version 2.0
- Replication Monitoring: 16 views for physical and logical replication
- Physical replication: health monitoring, bottleneck detection, performance rating
- Logical replication: subscription tracking, publication management, conflict detection
- Replication alerts: threshold-based alerting
- Replication dashboard: single comprehensive JSON view

### Version 1.0
- Query Performance: 10 views for query analysis
- 52 metric columns: execution statistics
- Response time tracking: time-based categorization
- Cache analysis: buffer cache efficiency metrics
- WAL monitoring: write-ahead log generation tracking

See: [Release Notes](RELEASE_NOTES_2.0.md) for detailed changelog

## License

MIT License. Copyright (c) 2024-2025, pgElephant, Inc.

See [LICENSE](LICENSE) for details.

## Links

- [Complete Documentation](https://pgelephant.github.io/pg_stat_insights/)
- [Interactive Demo](https://www.pgelephant.com/pg-stat-insights)
- [Blog Article](https://www.pgelephant.com/blog/pg-stat-insights)
- [GitHub Repository](https://github.com/pgelephant/pg_stat_insights)
- [Report Issues](https://github.com/pgelephant/pg_stat_insights/issues)
- [Discussions](https://github.com/pgelephant/pg_stat_insights/discussions)
