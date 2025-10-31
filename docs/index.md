# pg_stat_insights

> **Advanced PostgreSQL query performance monitoring, SQL optimization, and database analytics extension**

**Track 52 Metrics Across 11 Views - Monitor PostgreSQL Query Performance in Real-Time**

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%20|%2015%20|%2016%20|%2017-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/pgelephant/pg_stat_insights/blob/main/LICENSE)
[![Tests](https://img.shields.io/badge/tests-22%2F22%20passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-52_columns-brightgreen.svg)]()

---

## Overview

`pg_stat_insights` is an advanced PostgreSQL extension for **database performance monitoring**, **query optimization**, and **SQL analytics**. Track and analyze **52 comprehensive metrics** across **11 pre-built views** to identify slow queries, optimize cache performance, and monitor database health in real-time.

**Perfect for:**

- Database Administrators monitoring PostgreSQL performance
- DevOps teams tracking query performance and resource usage
- Developers optimizing SQL queries and database operations
- SREs implementing database monitoring and alerting

## Key Features

- **52 metric columns** - Execution time, cache hits, WAL generation, JIT stats, buffer I/O
- **11 pre-built views** - Instant access to top slow queries, cache misses, I/O intensive operations
- **11 parameters** - Fine-tune tracking, histograms, and statistics collection
- **Drop-in replacement** for pg_stat_statements with enhanced metrics
- **PostgreSQL 16-18** - Full compatibility with PostgreSQL 16, 17, and 18
- **22 regression tests** - Comprehensive test coverage for all features
- **Response time tracking** - Categorize queries by execution time (<1ms to >10s)
- **Cache analysis** - Identify buffer cache inefficiencies and optimization opportunities
- **WAL monitoring** - Track write-ahead log generation per query
- **Advanced features** - JSON/JSONB, arrays, partitioning, triggers, window functions
- **Time-series data** - Historical performance trending and bucket analysis
- **Prometheus/Grafana ready** - Pre-built dashboards and alert rules included
- **CI/CD ready** - GitHub Actions workflows for multi-version testing

## Quick Start

### Installation

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

### Quick Examples

**Find slow queries:**

```sql
SELECT 
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_insights_slow_queries
ORDER BY mean_exec_time DESC;
```

**Check cache efficiency:**

```sql
SELECT 
    query,
    cache_hit_ratio,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_insights_top_cache_misses
WHERE cache_hit_ratio < 0.9;
```

**Monitor WAL generation:**

```sql
SELECT 
    query,
    wal_records,
    wal_bytes,
    calls
FROM pg_stat_insights
WHERE wal_bytes > 1000000
ORDER BY wal_bytes DESC;
```

## Documentation

- **[Installation Guide](installation.md)** - Complete installation instructions
- **[Quick Start](quick-start.md)** - Get started in 5 minutes
- **[Configuration](configuration.md)** - All 11 parameters explained
- **[Views Reference](views.md)** - All 11 views documented
- **[Metrics Guide](metrics.md)** - All 52 columns detailed
- **[Usage Examples](usage.md)** - 50+ SQL queries
- **[Testing Guide](testing.md)** - 22 regression tests
- **[CI/CD Workflows](ci-cd.md)** - GitHub Actions setup
- **[Troubleshooting](troubleshooting.md)** - Common issues

## Why Choose pg_stat_insights?

**Solve Common PostgreSQL Performance Problems:**

- **Find slow queries** - Identify queries consuming excessive execution time and resources
- **Optimize cache usage** - Detect queries with poor buffer cache hit ratios
- **Track WAL generation** - Monitor write-ahead log generation per query pattern
- **Monitor JIT compilation** - Analyze Just-In-Time compilation impact on performance
- **Analyze I/O patterns** - Identify queries causing excessive disk I/O
- **Detect planning issues** - Track planning time vs execution time ratios
- **Monitor parallel queries** - Analyze parallel worker efficiency
- **Track query trends** - Historical performance analysis with time-series buckets

## What's New

### Version 1.1 (Unreleased)

- **Enhanced test suite**: 22 comprehensive regression tests (was 13)
- **PostgreSQL 16-18 support**: Full compatibility across versions
- **New test coverage**: Prepared statements, complex joins, JSON/JSONB, arrays, partitioning, triggers, window functions, transactions
- **GitHub Actions**: Build matrix and documentation deployment workflows
- **Deterministic tests**: ORDER BY clauses and fixed timestamps
- **CI/CD ready**: Automated testing across all supported versions

See [CHANGELOG](https://github.com/pgelephant/pg_stat_insights/blob/main/CHANGELOG.md) for complete history.

## Community

- **GitHub**: [github.com/pgelephant/pg_stat_insights](https://github.com/pgelephant/pg_stat_insights)
- **Issues**: [Report bugs or request features](https://github.com/pgelephant/pg_stat_insights/issues)
- **Discussions**: [Ask questions](https://github.com/pgelephant/pg_stat_insights/discussions)
- **Contributing**: [Contribution guide](contributing.md)

## License

pg_stat_insights is released under the [MIT License](https://github.com/pgelephant/pg_stat_insights/blob/main/LICENSE).

## Credits

Built with ❤️ by the [pgElephant team](https://github.com/pgelephant).

Based on PostgreSQL's pg_stat_statements with significant enhancements.

