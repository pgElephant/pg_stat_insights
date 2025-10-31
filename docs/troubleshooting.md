# Troubleshooting Guide

Common issues and solutions for pg_stat_insights.

---

## Installation Issues

### Extension Not Found

**Error:**
```
ERROR:  could not open extension control file "/usr/share/postgresql/17/extension/pg_stat_insights.control": No such file or directory
```

**Cause**: Extension not installed or installed in wrong location

**Solution:**
```bash
# Verify pg_config
which pg_config
pg_config --sharedir

# Reinstall with correct PG_CONFIG
cd pg_stat_insights
export PG_CONFIG=/path/to/correct/pg_config
sudo make install

# Verify installation
ls -la $(pg_config --sharedir)/extension/pg_stat_insights*
```

---

### Library Not Found

**Error:**
```
ERROR:  could not load library "/usr/lib/postgresql/17/lib/pg_stat_insights.so": cannot open shared object file
```

**Cause**: Shared library not installed or wrong path

**Solution:**
```bash
# Check library location
ls -la $(pg_config --pkglibdir)/pg_stat_insights*

# Reinstall
cd pg_stat_insights
sudo make install

# Verify
ls -la $(pg_config --pkglibdir)/pg_stat_insights.so
```

---

### Shared Preload Error

**Error:**
```
FATAL:  could not access file "pg_stat_insights": No such file or directory
```

**Cause**: Extension not in `shared_preload_libraries` or not installed

**Solution:**
```sql
-- Check current setting
SHOW shared_preload_libraries;

-- Add pg_stat_insights
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- Restart PostgreSQL (REQUIRED)
-- sudo systemctl restart postgresql
```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- PostgreSQL using excessive CPU
- System slow after enabling pg_stat_insights

**Diagnosis:**
```sql
-- Check tracking settings
SELECT name, setting FROM pg_settings 
WHERE name LIKE 'pg_stat_insights.track_%';
```

**Solution:**
```sql
-- Disable expensive tracking
ALTER SYSTEM SET pg_stat_insights.track_io_timing = off;
ALTER SYSTEM SET pg_stat_insights.track_planning = off;
ALTER SYSTEM SET pg_stat_insights.track_level = 'top';
SELECT pg_reload_conf();

-- Reduce query limit
ALTER SYSTEM SET pg_stat_insights.max_queries = 1000;
-- Restart required
```

---

### Out of Shared Memory

**Error:**
```
ERROR:  out of shared memory
HINT:  You might need to increase max_locks_per_transaction.
```

**Cause**: `max_queries` set too high

**Solution:**
```sql
-- Check current setting
SHOW pg_stat_insights.max_queries;

-- Reduce to reasonable value
ALTER SYSTEM SET pg_stat_insights.max_queries = 5000;

-- Restart PostgreSQL (REQUIRED)
-- sudo systemctl restart postgresql
```

**Memory calculation:**
```
Estimated memory = max_queries * 100 bytes
- 1,000 queries ≈ 10 MB
- 5,000 queries ≈ 50 MB
- 10,000 queries ≈ 100 MB
```

---

### Query Text Truncated

**Symptoms:**
- Query text showing as `(query texts file full)`
- Unable to see full query text

**Cause**: Too many unique queries tracked

**Solution:**
```sql
-- Reset statistics to free space
SELECT pg_stat_insights_reset();

-- Or increase max_queries (restart required)
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;
-- sudo systemctl restart postgresql
```

---

## Data Collection Issues

### No Statistics Collected

**Symptoms:**
- `SELECT COUNT(*) FROM pg_stat_insights` returns 0
- Views are empty

**Diagnosis:**
```sql
-- 1. Check extension is loaded
SELECT * FROM pg_extension WHERE extname = 'pg_stat_insights';

-- 2. Check shared_preload_libraries
SHOW shared_preload_libraries;

-- 3. Run test query
SELECT 1;
SELECT pg_sleep(0.5);

-- 4. Check again
SELECT COUNT(*) FROM pg_stat_insights;
```

**Solution:**
```sql
-- Ensure extension is in shared_preload_libraries
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- Restart PostgreSQL (REQUIRED)
-- sudo systemctl restart postgresql

-- Recreate extension
DROP EXTENSION IF EXISTS pg_stat_insights CASCADE;
CREATE EXTENSION pg_stat_insights;
```

---

### Statistics Not Updating

**Symptoms:**
- Old queries still showing
- New queries not appearing

**Cause**: Statistics need time to update

**Solution:**
```sql
-- Wait for statistics to be collected
SELECT pg_sleep(1);

-- Force stats update (run new queries)
SELECT COUNT(*) FROM pg_tables;

-- Check last update time
SELECT 
    MAX(stats_since) AS last_updated,
    NOW() - MAX(stats_since) AS time_since_update
FROM pg_stat_insights;
```

---

## Query Issues

### Query Not Appearing

**Issue**: Specific query not showing in pg_stat_insights

**Possible Causes:**

1. **Query not normalized** - Check with exact text
```sql
SELECT * FROM pg_stat_insights(false)  -- Show raw query text
WHERE query LIKE '%your_query%';
```

2. **Tracking level** - Nested queries not tracked
```sql
SHOW pg_stat_insights.track_level;
-- If 'top', only client queries tracked
-- Set to 'all' to track nested queries
ALTER SYSTEM SET pg_stat_insights.track_level = 'all';
SELECT pg_reload_conf();
```

3. **Query evicted** - Least used queries removed
```sql
-- Increase max_queries
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;
-- Restart required
```

---

### Unexpected Query Text

**Issue**: Query text shows `$1`, `$2` instead of actual values

**Explanation**: This is **normal** - queries are normalized

```sql
-- This query:
SELECT * FROM users WHERE id = 123;

-- Appears as:
SELECT * FROM users WHERE id = $1;

-- Same queryid for all of these:
SELECT * FROM users WHERE id = 123;
SELECT * FROM users WHERE id = 456;
SELECT * FROM users WHERE id = 789;
```

**Get raw query:**
```sql
SELECT * FROM pg_stat_insights(false)  -- Shows actual text (not normalized)
WHERE queryid = your_queryid;
```

---

## Test Failures

### Regression Tests Fail

**Error:**
```
not ok 3 - 03_views_and_aggregates
The differences that caused some tests to fail can be viewed in the file "regression.diffs"
```

**Diagnosis:**
```bash
# View differences
cat regression.diffs

# Check specific test output
diff expected/03_views_and_aggregates.out results/03_views_and_aggregates.out
```

**Common Causes:**

1. **Timestamp differences** - Use fixed timestamps in tests
2. **Non-deterministic order** - Add ORDER BY clauses
3. **Version differences** - PostgreSQL version incompatibility

**Solution:**
```bash
# Update expected output (if test is correct)
cp results/03_views_and_aggregates.out expected/

# Re-run tests
make installcheck
```

---

### Cannot Connect to Test Database

**Error:**
```
could not connect to server: Connection refused
```

**Solution:**
```bash
# Check PostgreSQL is running
pg_ctl status

# Start if needed
sudo systemctl start postgresql

# Check port
psql -p 5432 -c "SELECT version();"

# If using custom port
export PGPORT=5419
make installcheck
```

---

## Performance Problems

### Slow View Queries

**Issue**: Queries against pg_stat_insights views are slow

**Solution:**
```sql
-- 1. Always use LIMIT
SELECT * FROM pg_stat_insights_top_by_time LIMIT 10;  -- Fast
-- SELECT * FROM pg_stat_insights;  -- Slow if many queries

-- 2. Add WHERE clauses
SELECT * FROM pg_stat_insights WHERE queryid = 123456;  -- Fast

-- 3. Select only needed columns
SELECT queryid, query, calls, mean_exec_time FROM pg_stat_insights;  -- Faster than SELECT *
```

---

### Statistics Reset Accidentally

**Issue**: All statistics disappeared

**Cause**: Someone ran `pg_stat_insights_reset()`

**Solution:**

```sql
-- Statistics will rebuild automatically
-- Wait for queries to run and be tracked again

-- Check when stats started collecting
SELECT MIN(stats_since) AS stats_collection_started FROM pg_stat_insights;

-- To prevent accidents, restrict permissions
REVOKE EXECUTE ON FUNCTION pg_stat_insights_reset() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_stat_insights_reset() TO dba_role;
```

---

## Compatibility Issues

### PostgreSQL Version Mismatch

**Error:**
```
ERROR:  incompatible library "/usr/lib/postgresql/17/lib/pg_stat_insights.so": version mismatch
```

**Cause**: Extension compiled for different PostgreSQL version

**Solution:**
```bash
# Rebuild for correct version
cd pg_stat_insights
make clean

# Set correct PG_CONFIG
export PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config

# Rebuild and install
make
sudo make install

# Restart PostgreSQL
sudo systemctl restart postgresql
```

---

### Header File Not Found

**Error (during build):**
```
fatal error: 'nodes/queryjumble.h' file not found
```

**Cause**: PostgreSQL version mismatch in includes

**Solution:**

This is handled automatically in the code:
```c
#if PG_VERSION_NUM >= 170000
#include "nodes/queryjumble.h"  // PostgreSQL 17+
#else
#include "utils/queryjumble.h"  // PostgreSQL 14-16
#endif
```

If issue persists:
```bash
# Check PostgreSQL version
pg_config --version

# Verify pg_config points to correct version
which pg_config

# Set correct PG_CONFIG
export PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config
```

---

## Monitoring Issues

### Missing Metrics

**Issue**: Some metrics always show 0 or NULL

**Diagnosis:**
```sql
-- Check which tracking features are enabled
SELECT name, setting FROM pg_settings 
WHERE name LIKE 'pg_stat_insights.track_%'
ORDER BY name;
```

**Solution:**
```sql
-- Enable required tracking
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = on;
SELECT pg_reload_conf();

-- Run queries and check again
SELECT pg_sleep(1);
SELECT * FROM pg_stat_insights WHERE wal_bytes > 0;
```

---

### Replication View Empty

**Issue**: `pg_stat_insights_replication` returns no rows

**Causes:**

1. **No replicas connected**
```sql
-- Check for replicas
SELECT * FROM pg_stat_replication;
-- If empty, no replicas are connected
```

2. **Replication tracking disabled**
```sql
SHOW pg_stat_insights.track_replication;
-- Enable if off
ALTER SYSTEM SET pg_stat_insights.track_replication = on;
SELECT pg_reload_conf();
```

---

## Common Errors

### ERROR: function pg_stat_insights() does not exist

**Cause**: Extension not created in current database

**Solution:**
```sql
-- Create extension
CREATE EXTENSION pg_stat_insights;

-- Verify
SELECT extname FROM pg_extension WHERE extname = 'pg_stat_insights';
```

---

### ERROR: permission denied for function pg_stat_insights_reset

**Cause**: Non-superuser trying to reset

**Solution:**
```sql
-- Option 1: Grant permission
GRANT EXECUTE ON FUNCTION pg_stat_insights_reset() TO monitoring_user;

-- Option 2: Use superuser
-- sudo -u postgres psql -c "SELECT pg_stat_insights_reset();"
```

---

### HINT: You might need to increase max_locks_per_transaction

**Cause**: Shared memory exhausted

**Solution:**
```sql
-- Increase max_locks_per_transaction
ALTER SYSTEM SET max_locks_per_transaction = 128;  -- Default: 64

-- Or reduce pg_stat_insights.max_queries
ALTER SYSTEM SET pg_stat_insights.max_queries = 3000;

-- Restart required
-- sudo systemctl restart postgresql
```

---

## Diagnostic Queries

### Health Check

```sql
-- Comprehensive health check
SELECT 
    'Extension Version' AS check_type,
    extversion AS status
FROM pg_extension 
WHERE extname = 'pg_stat_insights'
UNION ALL
SELECT 
    'Shared Preload',
    setting
FROM pg_settings 
WHERE name = 'shared_preload_libraries' AND setting LIKE '%pg_stat_insights%'
UNION ALL
SELECT 
    'Max Queries',
    setting
FROM pg_settings 
WHERE name = 'pg_stat_insights.max_queries'
UNION ALL
SELECT 
    'Queries Tracked',
    COUNT(*)::text
FROM pg_stat_insights
UNION ALL
SELECT 
    'Total Calls',
    SUM(calls)::text
FROM pg_stat_insights;
```

### Performance Diagnostics

```sql
-- Check if pg_stat_insights is causing overhead
SELECT 
    'Total Execution Time' AS metric,
    ROUND(SUM(total_exec_time)::numeric, 2)::text || ' ms' AS value
FROM pg_stat_insights
UNION ALL
SELECT 
    'Avg Query Time',
    ROUND(AVG(mean_exec_time)::numeric, 2)::text || ' ms'
FROM pg_stat_insights
UNION ALL
SELECT 
    'Cache Hit Ratio',
    ROUND((SUM(shared_blks_hit)::numeric / 
           NULLIF(SUM(shared_blks_hit + shared_blks_read), 0) * 100), 1)::text || '%'
FROM pg_stat_insights;
```

---

## Getting Help

### Collect Diagnostic Information

When reporting issues, include:

```bash
# 1. PostgreSQL version
psql -c "SELECT version();"

# 2. Extension version
psql -c "SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_insights';"

# 3. Configuration
psql -c "SELECT name, setting FROM pg_settings WHERE name LIKE 'pg_stat_insights%';"

# 4. System info
uname -a

# 5. Build info (if building from source)
pg_config --version
gcc --version

# 6. Error logs
sudo journalctl -u postgresql -n 100  # Linux
tail -f /var/log/postgresql/postgresql-17-main.log  # Ubuntu/Debian
```

### Enable Debug Logging

```sql
-- Increase log verbosity
ALTER SYSTEM SET log_min_messages = 'DEBUG1';
ALTER SYSTEM SET log_error_verbosity = 'verbose';
SELECT pg_reload_conf();

-- Check logs for pg_stat_insights messages
-- sudo journalctl -u postgresql -f | grep pg_stat_insights
```

---

## Support Channels

### GitHub Issues

**For bugs and feature requests:**
- URL: https://github.com/pgelephant/pg_stat_insights/issues
- Include diagnostic information above
- Search existing issues first

### GitHub Discussions

**For questions and help:**
- URL: https://github.com/pgelephant/pg_stat_insights/discussions
- Community support
- Best practices sharing

### Documentation

**Complete documentation:**
- URL: https://pgelephant.github.io/pg_stat_insights/
- Installation guides
- Configuration reference
- Usage examples

---

## FAQ

### Can I use pg_stat_insights with pg_stat_statements?

No. pg_stat_insights is a drop-in replacement for pg_stat_statements. Use one or the other, not both.

### Does pg_stat_insights work with connection poolers?

Yes. Works with PgBouncer, pgpool-II, and other poolers. Configure pooler to use transaction or session pooling for accurate statistics.

### How much overhead does pg_stat_insights add?

Typical overhead:
- Minimal config: <1% CPU
- Balanced config: 2-5% CPU
- Full tracking: 5-10% CPU

Overhead depends on:
- `track_io_timing` setting (biggest impact)
- `track_planning` setting
- `max_queries` value
- Query complexity

### Can I track specific users or databases only?

Yes, filter in your queries:

```sql
-- Specific user
SELECT * FROM pg_stat_insights s
JOIN pg_roles r ON s.userid = r.oid
WHERE r.rolname = 'app_user';

-- Specific database
SELECT * FROM pg_stat_insights s
JOIN pg_database d ON s.dbid = d.oid
WHERE d.datname = 'production_db';
```

### How often should I reset statistics?

Depends on use case:
- **Production monitoring**: Weekly or monthly
- **Performance testing**: Before each test
- **Development**: Daily or as needed

```sql
-- Reset weekly via cron
SELECT pg_stat_insights_reset();
```

### Can I export data to external monitoring?

Yes. Query views and export to:
- **Prometheus**: Use postgres_exporter
- **Grafana**: Direct PostgreSQL datasource
- **CSV**: `\copy` command
- **JSON**: `row_to_json()` function

Example:
```sql
\copy (SELECT * FROM pg_stat_insights_top_by_time LIMIT 100) TO '/tmp/stats.csv' CSV HEADER;
```

---

## Best Practices

### [OK] DO

- Start with default settings
- Enable `track_io_timing` only if acceptable overhead
- Reset statistics periodically
- Use LIMIT in production queries
- Filter by database/user when analyzing
- Monitor extension overhead
- Update extension regularly

### [NO] DON'T

- Set `max_queries` too high
- Enable all tracking in high-load environments
- Run `SELECT * FROM pg_stat_insights` without LIMIT
- Forget to restart after changing `max_queries`
- Ignore high CPU usage
- Keep stale statistics indefinitely
- Use in development same as production

---

## Next Steps

- **[Configuration Guide](configuration.md)** - Tune settings
- **[Usage Examples](usage.md)** - More SQL queries
- **[Testing Guide](testing.md)** - Run tests
- **[CI/CD Guide](ci-cd.md)** - Automate testing

