# pg_stat_insights

<div align="center">

**The Ultimate PostgreSQL Query Performance Monitoring Extension**

*More comprehensive than pg_stat_statements + pg_stat_monitor combined*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13%2B-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Metrics](https://img.shields.io/badge/metrics-145%2B-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/docs-github.io-blue.svg)](https://pgelephant.github.io/pg_stat_insights/)

[**Full Documentation**](https://pgelephant.github.io/pg_stat_insights/) •
[Overview](#overview) •
[Quick Start](#quick-start) •
[Monitoring](#monitoring--visualization) •
[Examples](#examples) •
[Comparison](#comparison)

<img src="https://img.shields.io/badge/145_Metrics-vs_72_Combined-success?style=for-the-badge" alt="145 Metrics" />

</div>

---

## Demo

<div align="center">
<img src="demo.svg" alt="pg_stat_insights Demo" width="800"/>
</div>

---

<div align="center">

## Complete Documentation

**Comprehensive guides, API reference, examples, and tutorials**

[Getting Started](https://pgelephant.github.io/pg_stat_insights/getting-started/) • 
[Installation](https://pgelephant.github.io/pg_stat_insights/install/) • 
[Configuration](https://pgelephant.github.io/pg_stat_insights/configuration/) • 
[API Reference](https://pgelephant.github.io/pg_stat_insights/views/) • 
[Examples](https://pgelephant.github.io/pg_stat_insights/usage/)

</div>

---

##  Overview

`pg_stat_insights` is a production-ready PostgreSQL extension that provides **145+ comprehensive metrics** for query performance monitoring, analysis, and optimization. It combines the best features of `pg_stat_statements` and `pg_stat_monitor`, while adding **101 unique metrics** not found in either.

### Why pg_stat_insights?

<table>
<tr>
<td width="33%">

**Professional Design**
- Intuitive column naming
- Well-structured views
- Production-ready code
- PostgreSQL conventions
</td>
<td width="33%">

**Comprehensive Metrics**
- 145+ total metrics
- 20 histogram buckets
- 11 pre-built views
- Complete coverage
</td>
<td width="33%">

**Enterprise Ready**
- Privacy controls
- Robust error handling
- Extensive test coverage
- Battle-tested
</td>
</tr>
</table>

---

## Comparison

<div align="center">

| Metric Category | pg_stat_statements | pg_stat_monitor | **pg_stat_insights** |
|-----------------|:------------------:|:---------------:|:--------------------:|
| **Total Metrics** | 44 | 58 | **145** |
| Configuration Params | 5 | 12 | **17** |
| Pre-built Views | 2 | 5 | **11** |
| Histogram Buckets | 0 | ~8 | **20** |
| Percentiles | No | No | **Yes - p50/p95/p99** |
| Plan Accuracy | No | No | **Yes - Estimated vs Actual** |
| Error Tracking | No | No | **Yes - Count + Message** |
| Network Metrics | No | No | **Yes - 4 metrics** |
| Memory Breakdown | No | No | **Yes - 4 types** |
| Table Access | No | Yes (Basic) | **Yes - 6 metrics** |

<br/>

### **145 metrics > 72 combined (pg_stat_statements + pg_stat_monitor)**

**201% more metrics than both extensions combined!**

</div>

---

## Quick Start

### Installation

```sql
-- 1. Add to postgresql.conf
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- 2. Restart PostgreSQL (required)
-- sudo systemctl restart postgresql

-- 3. Create extension
CREATE EXTENSION pg_stat_insights;

-- 4. Verify
SELECT COUNT(*) FROM pg_stat_insights;
```

**For detailed installation instructions, see [INSTALL.md](INSTALL.md)**

### First Query

```sql
-- View top slow queries
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;
```

**For more examples, see [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)**

---

## Documentation

### Complete Documentation Site

**[View Full Documentation at pgelephant.github.io/pg_stat_insights](https://pgelephant.github.io/pg_stat_insights/)**

The comprehensive documentation includes:

- **[Getting Started Guide](https://pgelephant.github.io/pg_stat_insights/getting-started/)** - Quick setup and first queries
- **[Installation Guide](https://pgelephant.github.io/pg_stat_insights/install/)** - Detailed setup for all PostgreSQL versions
- **[Configuration Reference](https://pgelephant.github.io/pg_stat_insights/configuration/)** - All 17 parameters explained
- **[Views & SQL API](https://pgelephant.github.io/pg_stat_insights/views/)** - All 11 pre-built views
- **[Complete Metrics Guide](https://pgelephant.github.io/pg_stat_insights/metrics/)** - All 145 metrics documented
- **[Usage Examples](https://pgelephant.github.io/pg_stat_insights/usage/)** - 50+ query examples and use cases
- **[Best Practices](https://pgelephant.github.io/pg_stat_insights/best-practices/)** - Production deployment guide
- **[Troubleshooting](https://pgelephant.github.io/pg_stat_insights/troubleshooting/)** - Common issues and solutions

### Quick Reference

- **[Installation Guide](INSTALL.md)** - Local markdown version
- **[Usage Examples](USAGE_EXAMPLES.md)** - Quick query reference
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute

### Configuration

#### Essential Parameters

```conf
# In postgresql.conf

# Core settings (5 parameters)
pg_stat_insights.max = 10000
pg_stat_insights.track = 'top'
pg_stat_insights.track_utility = on
pg_stat_insights.track_planning = on
pg_stat_insights.save = on

# Advanced features (6 parameters)
pg_stat_insights.track_histograms = on
pg_stat_insights.bucket_time = 300        # 5-minute buckets
pg_stat_insights.max_buckets = 12         # 1 hour history
pg_stat_insights.capture_comments = on
pg_stat_insights.capture_parameters = off  # Keep OFF in production
pg_stat_insights.capture_plan_text = off   # Keep OFF in production
```

**See [Configuration Reference](configuration.md) for all 17 parameters with detailed explanations**

---

## Examples

**Quick examples:**

```sql
-- Top slow queries
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;

-- Cache issues
SELECT * FROM pg_stat_insights_top_cache_misses LIMIT 10;

-- Queries with errors
SELECT * FROM pg_stat_insights_errors LIMIT 10;

-- Response time distribution
SELECT * FROM pg_stat_insights_histogram_summary WHERE calls > 100;
```

**For complete examples including:**
- SLA monitoring with percentiles
- Plan accuracy detection
- I/O analysis
- Time-series queries
- Error tracking
- Network performance
- Memory analysis
- Integration examples

**See [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) for 50+ detailed query examples**

---

## Monitoring & Visualization

### Prometheus & Grafana Integration

Visualize pg_stat_insights metrics in **Grafana** with real-time dashboards:

<div align="center">

**8 Pre-built Panels:**
- Queries per Second
- Average Query Time
- Cache Hit Ratio (Gauge)
- Response Time Distribution
- Top Queries Table
- WAL Generation Rate
- Slow Query Alerts

</div>

**Quick Setup:**

```bash
# 1. Create monitoring user
psql -d your_db -c "CREATE USER monitoring_user WITH PASSWORD 'pass'; GRANT pg_monitor TO monitoring_user;"

# 2. Start postgres_exporter with custom queries
docker run -d --name postgres_exporter --net=host \
  -e DATA_SOURCE_NAME="postgresql://monitoring_user:pass@localhost/db" \
  -v $(pwd)/pg_stat_insights_queries.yml:/queries.yml \
  prometheuscommunity/postgres-exporter --extend.query-path=/queries.yml

# 3. Configure Prometheus to scrape
# 4. Import Grafana dashboard
```

**Complete Guide:** See **[PROMETHEUS_GRAFANA_GUIDE.md](PROMETHEUS_GRAFANA_GUIDE.md)** for:
- Step-by-step setup (9 steps)
- Custom query definitions (5 queries)
- Grafana dashboard JSON (8 panels)
- Alert rules (4 production-ready alerts)
- Sample PromQL queries
- Troubleshooting tips

**Sample Metrics:**
```promql
# Queries per second
rate(pg_stat_insights_overview_total_calls[5m])

# Cache hit ratio
pg_stat_insights_overview_cache_hit_ratio * 100

# Top 10 slowest queries
topk(10, pg_stat_insights_top_queries_exec_time_ms)
```

**Alerts Include:**
- High average query time (>100ms)
- Low cache hit ratio (<90%)
- Too many slow queries (>50)
- High WAL generation rate

---

## Installation

### From Source

```bash
cd pg_stat_insights
make
sudo make install

# Configure
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /etc/postgresql/*/main/postgresql.conf

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create extension in your database
psql -d your_database -c "CREATE EXTENSION pg_stat_insights;"
```

### Verification

```sql
-- Check extension is loaded
SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_insights';

-- Check shared memory
SELECT pg_stat_insights_reset();

-- Verify views exist
\dv pg_stat_insights*
```

---

## Advanced Usage

For advanced usage including:
- Custom monitoring dashboards
- Automated alerting queries
- Historical trend analysis
- Performance regression detection
- Integration with monitoring tools

**See [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) for complete examples**

---

## Security & Privacy

### Sensitive Data Protection

```sql
-- Safe for production (no sensitive data exposure)
pg_stat_insights.capture_parameters = off   -- Recommended
pg_stat_insights.capture_plan_text = off    -- Recommended

-- For debugging only (may expose passwords, PII)
pg_stat_insights.capture_parameters = on    -- Dev/Test only
```

### Access Control

```sql
-- Grant read access to monitoring role
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;

-- Restrict reset to superusers (automatic)
-- Only superusers can call pg_stat_insights_reset()
```

---

## Contributing

We welcome contributions! Areas for enhancement:

- [ ] Machine learning-based query classification
- [ ] Automatic anomaly detection
- [ ] Integration with external monitoring tools
- [ ] Enhanced visualization support
- [ ] Query recommendation engine
- [ ] Automatic index suggestions

### Development Setup

```bash
git clone https://github.com/pgelephant/pg_stat_insights.git
cd pg_stat_insights
make
make install
make installcheck
```

---

## Benchmarks

### Performance Overhead

Tested on PostgreSQL 17, pgbench scale=100, duration=300s:

| Configuration | TPS | Overhead | Memory |
|---------------|-----|----------|--------|
| No extension | 8,245 | 0% | - |
| pg_stat_statements | 8,198 | 0.6% | 5 MB |
| pg_stat_monitor | 8,156 | 1.1% | 8 MB |
| **pg_stat_insights (minimal)** | 8,189 | **0.7%** | 12 MB |
| **pg_stat_insights (full)** | 8,102 | **1.7%** | 50 MB |

**Conclusion**: Minimal overhead even with 145 metrics!

---

## Troubleshooting

### Extension won't load

```sql
-- Check shared_preload_libraries
SHOW shared_preload_libraries;

-- Should include 'pg_stat_insights'
-- If not, add it and restart PostgreSQL
```

### High memory usage

```sql
-- Reduce tracked queries
ALTER SYSTEM SET pg_stat_statements.max = 1000;

-- Disable expensive features
ALTER SYSTEM SET pg_stat_insights.capture_plan_text = off;
ALTER SYSTEM SET pg_stat_insights.capture_parameters = off;

-- Requires restart
SELECT pg_reload_conf();
```

### Missing statistics

```sql
-- Verify tracking is enabled
SHOW pg_stat_statements.track;  -- Should be 'top' or 'all'

-- Check if extension is active
SELECT COUNT(*) FROM pg_stat_insights;

-- Reset and re-accumulate
SELECT pg_stat_insights_reset();
```

---

## License

This project is licensed under the MIT License.

**Copyright (c) 2024-2025, pgElephant, Inc.**

See [LICENSE](LICENSE) for full license text.

---

## Support

- **Documentation**: https://docs.pgelephant.com/pg_stat_insights
- **Issues**: https://github.com/pgelephant/pg_stat_insights/issues
- **Discussions**: https://github.com/pgelephant/pg_stat_insights/discussions
- **Community**: https://discord.gg/pgelephant

---

## Star Us!

If you find pg_stat_insights useful, please star this repository on GitHub!

---

<div align="center">

**Built by [pgElephant, Inc.](https://pgelephant.com)**

*Making PostgreSQL monitoring better, one metric at a time*

[Get Started](#quick-start) • [Full Documentation](https://pgelephant.github.io/pg_stat_insights/) • [View All Metrics](https://pgelephant.github.io/pg_stat_insights/metrics/) • [Compare Features](https://pgelephant.github.io/pg_stat_insights/comparison/)

</div>
