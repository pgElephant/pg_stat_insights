# pg_stat_insights - PostgreSQL Performance Monitoring Extension

> **Advanced PostgreSQL query performance monitoring, SQL optimization, and database analytics extension**
> 
> Monitor slow queries • Track cache efficiency • Analyze WAL generation • Optimize database performance • Real-time metrics • Grafana dashboards

## Language Support / 多言語対応 / 多语言支持

**[English](#overview)** (current) | **[简体中文](docs/zh_CN/README.md)** | **[繁體中文](docs/zh_TW/README.md)** | **[日本語](docs/ja_JP/README.md)**

<div align="center">

**Track 52 Metrics Across 11 Views - Monitor PostgreSQL Query Performance in Real-Time**

*Production-ready extension for PostgreSQL 16, 17, 18 - Drop-in replacement for pg_stat_statements with enhanced analytics*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20|%2017%20|%2018-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Tests](https://img.shields.io/badge/tests-22%2F22%20passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-52_columns-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/docs-github.io-blue.svg)](https://pgelephant.github.io/pg_stat_insights/)

![52 Columns and 20 Views](https://img.shields.io/badge/52_Columns-20_Views-success?style=for-the-badge)

</div>

---

## Overview

**PostgreSQL Query Performance Monitoring Made Simple**

`pg_stat_insights` is an advanced PostgreSQL extension for **database performance monitoring**, **query optimization**, and **SQL analytics**. Track and analyze **52 comprehensive metrics** across **20 pre-built views** to identify slow queries, optimize cache performance, monitor replication health, detect bottlenecks, and debug replication issues in real-time.

**Perfect for:**
- Database Administrators monitoring PostgreSQL performance
- DevOps teams tracking query performance and resource usage
- Developers optimizing SQL queries and database operations
- SREs implementing database monitoring and alerting

**Key Features:**
- **52 metric columns** - Execution time, cache hits, WAL generation, JIT stats, buffer I/O
- **20 pre-built views** - Instant access to top slow queries, cache misses, I/O intensive operations, comprehensive replication monitoring with bottleneck detection and health diagnostics
- **11 parameters** - Fine-tune tracking, histograms, and statistics collection
- **Drop-in replacement** for pg_stat_statements with enhanced metrics
- **PostgreSQL 16-18** - Full compatibility with PostgreSQL 16, 17, and 18
- **22 regression tests** - Comprehensive test coverage for all features
- **Response time tracking** - Categorize queries by execution time (less than 1ms to greater than 10s)
- **Cache analysis** - Identify buffer cache inefficiencies and optimization opportunities
- **WAL monitoring** - Track write-ahead log generation per query
- **Advanced features** - JSON/JSONB, arrays, partitioning, triggers, window functions
- **Time-series data** - Historical performance trending and bucket analysis
- **Prometheus/Grafana ready** - Pre-built dashboards and alert rules included
- **CI/CD ready** - GitHub Actions workflows for multi-version testing

---

## Quick Start - Install in 3 Steps

**Monitor PostgreSQL query performance in under 5 minutes:**

```sql
-- Step 1: Enable extension in PostgreSQL configuration
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- Restart PostgreSQL server required

-- Step 2: Create the extension in your database
CREATE EXTENSION pg_stat_insights;

-- Step 3: View your slowest queries instantly
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_insights_top_by_time 
LIMIT 10;
```

**Result:** Instant visibility into query performance, execution times, cache efficiency, and resource usage across your PostgreSQL database.

---

## Documentation

**Complete documentation available at:**

### [pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)

**Quick Links:**

- [Getting Started](https://pgelephant.github.io/pg_stat_insights/getting-started/) - Installation and setup
- [Configuration](https://pgelephant.github.io/pg_stat_insights/configuration/) - All 11 parameters
- [Views Reference](https://pgelephant.github.io/pg_stat_insights/views/) - All 20 views
- [Metrics Guide](https://pgelephant.github.io/pg_stat_insights/metrics/) - All 52 columns
- [Usage Examples](https://pgelephant.github.io/pg_stat_insights/usage/) - 50+ SQL queries
- [Prometheus & Grafana](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/) - Monitoring integration
- [Troubleshooting](https://pgelephant.github.io/pg_stat_insights/troubleshooting/) - Common issues

---

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

**Detailed instructions:** [Installation Guide](https://pgelephant.github.io/pg_stat_insights/install/)

---

## Views

All 20 pre-built views:

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
| `pg_stat_insights_replication` | Basic replication monitoring |
| `pg_stat_insights_physical_replication` | Physical replication with enhanced metrics and health status |
| `pg_stat_insights_logical_replication` | Logical replication slots with lag tracking |
| `pg_stat_insights_replication_slots` | All replication slots (physical + logical) with health status |
| `pg_stat_insights_replication_summary` | Overall replication activity summary |
| `pg_stat_insights_replication_alerts` | Critical alerts for lag, WAL loss, and inactive slots |
| `pg_stat_insights_replication_wal` | WAL statistics and retention analysis |
| `pg_stat_insights_replication_bottlenecks` | Identify network, I/O, or replay bottlenecks |
| `pg_stat_insights_replication_conflicts` | Logical replication conflict detection |
| `pg_stat_insights_replication_health` | Comprehensive health check with recommendations |
| `pg_stat_insights_replication_performance` | Performance trends and throughput analysis |
| `pg_stat_insights_replication_timeline` | Historical timeline and lag trends |

**Complete reference:** [Views Documentation](https://pgelephant.github.io/pg_stat_insights/views/)

---

## Why Choose pg_stat_insights?

**Solve Common PostgreSQL Performance Problems:**

- **Find slow queries** - Identify queries consuming excessive execution time and resources
- **Optimize cache usage** - Detect buffer cache misses and improve shared_buffers efficiency
- **Reduce WAL overhead** - Monitor write-ahead log generation per query type
- **Track query patterns** - Analyze execution frequency, response times, and resource consumption
- **Monitor in real-time** - Integrate with Grafana for live dashboards and alerting
- **PostgreSQL best practices** - Built following PostgreSQL coding standards and conventions

## Comparison with Other Extensions

| Feature | pg_stat_statements | pg_stat_monitor | **pg_stat_insights** |
|---------|:------------------:|:---------------:|:--------------------:|
| **Metric Columns** | 44 | 58 | **52** |
| **Pre-built Views** | 2 | 5 | **11** |
| **Configuration Options** | 5 | 12 | **11** |
| **Cache Analysis** | Basic | Basic | **Enhanced with ratios** |
| **Response Time Categories** | No | No | **Yes (<1ms to >10s)** |
| **Time-Series Tracking** | No | No | **Yes (bucket-based)** |
| **TAP Test Coverage** | Standard | Limited | **150 tests, 100% coverage** |
| **Documentation** | Basic | Medium | **30+ pages on GitHub Pages** |
| **Prometheus Integration** | Manual | Manual | **Pre-built queries & dashboards** |

**See detailed comparison:** [Feature Comparison](https://pgelephant.github.io/pg_stat_insights/comparison/)

---

## PostgreSQL Performance Testing

**Comprehensive TAP Test Suite for Quality Assurance:**
- **16 test files** covering all extension functionality
- **150 test cases** with 100% code coverage
- Tests all 52 metric columns, 20 views (including 12 replication diagnostic views), 11 parameters
- Custom StatsInsightManager.pm framework
- No external Perl dependencies required
- Compatible with PostgreSQL 18 testing infrastructure

**Run PostgreSQL extension tests:**
```bash
./run_all_tests.sh
```

**Continuous Integration:** GitHub Actions workflow for automated PostgreSQL testing on every commit

**Learn more:** [Testing Guide](https://pgelephant.github.io/pg_stat_insights/testing/)

---

## Database Monitoring with Prometheus & Grafana

**Real-Time PostgreSQL Metrics Visualization:**

Turn pg_stat_insights data into actionable dashboards and alerts for PostgreSQL database monitoring:

- **Prometheus integration** - 5 pre-configured queries for postgres_exporter
- **Grafana dashboards** - 8 ready-to-use panels for query performance visualization
- **Alert rules** - 11 production-ready alerts for database health monitoring
- **Query rate tracking** - Monitor queries per second (QPS) and throughput
- **Cache performance** - Real-time buffer cache hit ratio monitoring
- **Response time SLA** - Track P95/P99 query latency for service level objectives
- **WAL generation alerts** - Monitor write-ahead log growth and disk usage

**Complete Prometheus/Grafana guide:** [Monitoring Integration](https://pgelephant.github.io/pg_stat_insights/prometheus-grafana/)

---

## License

MIT License - Copyright (c) 2024-2025, pgElephant, Inc.

See [LICENSE](LICENSE) for details.

---

## Links

- [Complete Documentation](https://pgelephant.github.io/pg_stat_insights/)
- [Interactive Demo](https://www.pgelephant.com/pg-stat-insights) - Try pg_stat_insights online
- [Blog Article](https://www.pgelephant.com/blog/pg-stat-insights) - Comprehensive guide and best practices
- [GitHub Repository](https://github.com/pgelephant/pg_stat_insights)
- [Report Issues](https://github.com/pgelephant/pg_stat_insights/issues)
- [Discussions](https://github.com/pgelephant/pg_stat_insights/discussions)

---

<div align="center">

**Built by [pgElephant, Inc.](https://pgelephant.com)**

*Making PostgreSQL monitoring better, one metric at a time*

</div>
