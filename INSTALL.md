# Installation Guide - pg_stat_insights

## Prerequisites

- PostgreSQL 13, 14, 15, 16, 17, or 18
- C compiler (gcc or clang)
- PostgreSQL development headers
- Make

## Quick Installation

### Using PGXS (Recommended)

```bash
cd pg_stat_insights
USE_PGXS=1 make
USE_PGXS=1 sudo make install
```

### With Specific PostgreSQL Version

```bash
# For PostgreSQL 18
export PATH=/usr/local/pgsql.18/bin:$PATH
USE_PGXS=1 PG_CONFIG=/usr/local/pgsql.18/bin/pg_config make
USE_PGXS=1 PG_CONFIG=/usr/local/pgsql.18/bin/pg_config sudo make install
```

## Configuration

### 1. Enable Extension

```sql
-- In postgresql.conf or via ALTER SYSTEM
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
```

### 2. Restart PostgreSQL

```bash
# Linux (systemd)
sudo systemctl restart postgresql

# macOS (Homebrew)
brew services restart postgresql@18

# Manual
pg_ctl restart -D /path/to/data
```

### 3. Create Extension

```sql
CREATE EXTENSION pg_stat_insights;
```

### 4. Verify Installation

```sql
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_insights';
SELECT COUNT(*) FROM pg_stat_insights;
```

## Advanced Configuration

See [Configuration Reference](configuration.md) for all parameters.

### Recommended Production Settings

```sql
-- Core
ALTER SYSTEM SET pg_stat_insights.max = 10000;
ALTER SYSTEM SET pg_stat_insights.track = 'top';
ALTER SYSTEM SET pg_stat_insights.track_planning = on;

-- Features
ALTER SYSTEM SET pg_stat_insights.track_histograms = on;
ALTER SYSTEM SET pg_stat_insights.bucket_time = 300;
ALTER SYSTEM SET pg_stat_insights.max_buckets = 12;

-- Security (keep off)
ALTER SYSTEM SET pg_stat_insights.capture_parameters = off;
ALTER SYSTEM SET pg_stat_insights.capture_plan_text = off;

-- Reload
SELECT pg_reload_conf();
```

## Uninstallation

```sql
DROP EXTENSION pg_stat_insights CASCADE;
```

Then remove from `shared_preload_libraries` and restart PostgreSQL.

