# Installation Guide

Complete installation guide for pg_stat_insights on all supported platforms and PostgreSQL versions.

---

## Prerequisites

### System Requirements

- **PostgreSQL**: Version 16, 17, or 18
- **Operating System**: Linux (Ubuntu/Debian/RHEL/Rocky), macOS, Windows (WSL)
- **Memory**: Minimum 100MB shared memory for extension
- **Disk**: ~5MB for extension files
- **Permissions**: Superuser access to PostgreSQL

### Verify PostgreSQL Version

```bash
psql --version
# or
pg_config --version
```

---

## Installation Methods

=== "Ubuntu/Debian"

    ### Ubuntu 22.04/24.04 & Debian 11/12

    #### Method 1: Build from Source

    ```bash
    # Install PostgreSQL and development packages
    sudo apt-get update
    sudo apt-get install -y wget gnupg2
    
    # Add PostgreSQL APT repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
      gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
      http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
      sudo tee /etc/apt/sources.list.d/pgdg.list
    
    sudo apt-get update
    sudo apt-get install -y \
      postgresql-17 \
      postgresql-server-dev-17 \
      build-essential
    
    # Clone and build
    git clone https://github.com/pgelephant/pg_stat_insights.git
    cd pg_stat_insights
    
    # Build and install
    make
    sudo make install
    ```

    #### Method 2: DEB Package (Recommended)

    ```bash
    # Download latest release
    wget https://github.com/pgelephant/pg_stat_insights/releases/latest/download/postgresql-17-pg-stat-insights_1.0.0-1_amd64.deb
    
    # Install package
    sudo dpkg -i postgresql-17-pg-stat-insights_1.0.0-1_amd64.deb
    sudo apt-get install -f  # Install dependencies if needed
    ```

=== "RHEL/Rocky/AlmaLinux"

    ### Rocky Linux 9 / AlmaLinux 9 / RHEL 9

    #### Method 1: Build from Source

    ```bash
    # Enable EPEL and PowerTools
    sudo dnf install -y epel-release
    sudo dnf config-manager --set-enabled crb
    
    # Add PostgreSQL repository
    sudo dnf install -y \
      https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    # Disable built-in PostgreSQL module
    sudo dnf -qy module disable postgresql
    
    # Install build dependencies
    sudo dnf install -y \
      gcc \
      make \
      redhat-rpm-config \
      postgresql17-devel
    
    # Clone and build
    git clone https://github.com/pgelephant/pg_stat_insights.git
    cd pg_stat_insights
    
    # Build and install
    make
    sudo make install
    ```

    #### Method 2: RPM Package (Recommended)

    ```bash
    # Download latest release
    wget https://github.com/pgelephant/pg_stat_insights/releases/latest/download/pg_stat_insights_17-1.0.0-1.el9.x86_64.rpm
    
    # Install package
    sudo dnf install -y pg_stat_insights_17-1.0.0-1.el9.x86_64.rpm
    ```

=== "macOS"

    ### macOS (Homebrew)

    ```bash
    # Install PostgreSQL via Homebrew
    brew install postgresql@17
    
    # Clone repository
    git clone https://github.com/pgelephant/pg_stat_insights.git
    cd pg_stat_insights
    
    # Build with Homebrew PostgreSQL
    export PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
    make
    make install
    ```

=== "From Source"

    ### Build from Source (All Platforms)

    ```bash
    # Clone repository
    git clone https://github.com/pgelephant/pg_stat_insights.git
    cd pg_stat_insights
    
    # Set PG_CONFIG (if needed)
    export PG_CONFIG=/path/to/pg_config
    
    # Build
    make clean
    make
    
    # Install
    sudo make install
    
    # Verify installation
    ls -la $(pg_config --sharedir)/extension/pg_stat_insights*
    ```

---

## Configuration

### 1. Enable Shared Preload

pg_stat_insights **must** be loaded via `shared_preload_libraries`.

#### Option A: ALTER SYSTEM (Recommended)

```sql
-- Connect as superuser
psql -U postgres

-- Enable extension
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- Restart PostgreSQL (required)
-- Ubuntu/Debian:
-- sudo systemctl restart postgresql
-- RHEL/Rocky:
-- sudo systemctl restart postgresql-17
-- macOS:
-- brew services restart postgresql@17
```

#### Option B: Edit postgresql.conf

```bash
# Find postgresql.conf
psql -U postgres -c "SHOW config_file;"

# Edit file
sudo nano /etc/postgresql/17/main/postgresql.conf

# Add or modify line:
shared_preload_libraries = 'pg_stat_insights'

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### 2. Restart PostgreSQL

!!! warning "Restart Required"
    Changes to `shared_preload_libraries` require a full PostgreSQL restart.

```bash
# Ubuntu/Debian
sudo systemctl restart postgresql

# RHEL/Rocky/AlmaLinux
sudo systemctl restart postgresql-17

# macOS (Homebrew)
brew services restart postgresql@17

# Manual restart
pg_ctl restart -D /path/to/data
```

### 3. Create Extension

```sql
-- Connect to your database
psql -U postgres -d your_database

-- Create extension
CREATE EXTENSION pg_stat_insights;

-- Verify installation
SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_insights';
```

### 4. Verify Installation

```sql
-- Check extension is loaded
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_insights';

-- Verify functions exist
SELECT proname FROM pg_proc WHERE proname LIKE 'pg_stat_insights%' ORDER BY proname;

-- Verify views exist
SELECT viewname FROM pg_views WHERE viewname LIKE 'pg_stat_insights%' ORDER BY viewname;

-- Test basic query
SELECT COUNT(*) FROM pg_stat_insights;
```

---

## Post-Installation Configuration

### Recommended Settings

For optimal performance monitoring, configure these parameters:

```sql
-- Enable all tracking features
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;
ALTER SYSTEM SET pg_stat_insights.track_utility = on;
ALTER SYSTEM SET pg_stat_insights.track_planning = on;
ALTER SYSTEM SET pg_stat_insights.track_wal = on;
ALTER SYSTEM SET pg_stat_insights.track_jit = on;
ALTER SYSTEM SET pg_stat_insights.track_io_timing = on;
ALTER SYSTEM SET pg_stat_insights.track_parallel_queries = on;
ALTER SYSTEM SET pg_stat_insights.track_minmax_time = on;

-- Reload configuration (no restart needed for these)
SELECT pg_reload_conf();
```

### Memory Configuration

pg_stat_insights uses shared memory. Allocate based on `max_queries`:

| max_queries | Shared Memory | Use Case |
|-------------|---------------|----------|
| 1,000 | ~10 MB | Small database |
| 5,000 | ~50 MB | Medium database |
| 10,000 | ~100 MB | Large database |
| 20,000 | ~200 MB | Very large database |

```sql
-- Check current setting
SHOW pg_stat_insights.max_queries;

-- Adjust if needed
ALTER SYSTEM SET pg_stat_insights.max_queries = 10000;

-- Restart required for max_queries change
```

---

## Upgrading

### From pg_stat_statements

pg_stat_insights is a **drop-in replacement** for pg_stat_statements:

```sql
-- 1. Drop pg_stat_statements
DROP EXTENSION IF EXISTS pg_stat_statements CASCADE;

-- 2. Remove from shared_preload_libraries
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';

-- 3. Restart PostgreSQL
-- sudo systemctl restart postgresql

-- 4. Create pg_stat_insights
CREATE EXTENSION pg_stat_insights;

-- 5. Verify (same views available)
SELECT * FROM pg_stat_insights LIMIT 10;
```

### Upgrading pg_stat_insights

```sql
-- Check current version
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_insights';

-- Upgrade extension
ALTER EXTENSION pg_stat_insights UPDATE TO '1.1';

-- Verify new version
SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_insights';
```

---

## Uninstallation

### Complete Removal

```sql
-- 1. Drop extension from all databases
DROP EXTENSION IF EXISTS pg_stat_insights CASCADE;

-- 2. Remove from postgresql.conf
ALTER SYSTEM SET shared_preload_libraries = '';

-- 3. Restart PostgreSQL
-- sudo systemctl restart postgresql

-- 4. Remove files (optional)
-- sudo rm -f $(pg_config --sharedir)/extension/pg_stat_insights*
-- sudo rm -f $(pg_config --pkglibdir)/pg_stat_insights.*
```

---

## Verification

### Health Check

Run this comprehensive check:

```sql
-- Extension status
SELECT 
  extname,
  extversion,
  extrelocatable
FROM pg_extension 
WHERE extname = 'pg_stat_insights';

-- Function count (should be 3)
SELECT COUNT(*) AS function_count
FROM pg_proc 
WHERE proname LIKE 'pg_stat_insights%';

-- View count (should be 11)
SELECT COUNT(*) AS view_count
FROM pg_views 
WHERE viewname LIKE 'pg_stat_insights%';

-- Test data collection
SELECT pg_sleep(1);
SELECT COUNT(*) AS tracked_queries FROM pg_stat_insights;

-- Test reset function
SELECT pg_stat_insights_reset();
```

### Regression Tests

Run the full test suite to verify installation:

```bash
cd pg_stat_insights
make installcheck

# Expected output:
# ok 1 - 01_extension_basics
# ok 2 - 02_basic_queries
# ...
# ok 22 - 22_query_normalization
# 1..22
# All 22 tests passed.
```

---

## Platform-Specific Notes

### Ubuntu 22.04

```bash
# PostgreSQL 17 default path
PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config
SHAREDIR=/usr/share/postgresql/17
PKGLIBDIR=/usr/lib/postgresql/17/lib
```

### Ubuntu 24.04

```bash
# Same as 22.04
PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config
```

### Rocky Linux 9

```bash
# PostgreSQL 17 default path
PG_CONFIG=/usr/pgsql-17/bin/pg_config
SHAREDIR=/usr/pgsql-17/share
PKGLIBDIR=/usr/pgsql-17/lib
```

### macOS (Homebrew)

```bash
# PostgreSQL 17 default path
PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
SHAREDIR=/opt/homebrew/share/postgresql@17
PKGLIBDIR=/opt/homebrew/lib/postgresql@17
```

---

## Troubleshooting

### Issue: "could not load library"

**Cause**: Extension not in `shared_preload_libraries`

**Solution**:
```sql
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';
-- Restart PostgreSQL
```

### Issue: "extension does not exist"

**Cause**: Extension files not installed

**Solution**:
```bash
# Verify pg_config
which pg_config

# Reinstall
cd pg_stat_insights
sudo make install

# Check files
ls -la $(pg_config --sharedir)/extension/pg_stat_insights*
```

### Issue: "out of shared memory"

**Cause**: Not enough shared memory allocated

**Solution**:
```sql
-- Reduce max_queries
ALTER SYSTEM SET pg_stat_insights.max_queries = 5000;

-- Or increase shared memory
ALTER SYSTEM SET shared_buffers = '256MB';

-- Restart required
```

### Issue: "permission denied"

**Cause**: File permissions incorrect

**Solution**:
```bash
# Fix ownership
sudo chown -R postgres:postgres \
  /usr/share/postgresql/17/extension/pg_stat_insights* \
  /usr/lib/postgresql/17/lib/pg_stat_insights.*

# Verify permissions
ls -la $(pg_config --sharedir)/extension/pg_stat_insights*
```

---

## Next Steps

After installation:

1. **[Configure Parameters](configuration.md)** - Fine-tune tracking settings
2. **[Quick Start Guide](quick-start.md)** - Start monitoring in 5 minutes
3. **[View Reference](views.md)** - Explore all 11 views
4. **[Usage Examples](usage.md)** - Learn from 50+ SQL examples
5. **[Testing Guide](testing.md)** - Run regression tests

---

## Support

Need help with installation?

- **Issues**: [GitHub Issues](https://github.com/pgelephant/pg_stat_insights/issues)
- **Discussions**: [GitHub Discussions](https://github.com/pgelephant/pg_stat_insights/discussions)
- **Documentation**: [Full Docs](https://pgelephant.github.io/pg_stat_insights/)

---

## Quick Reference

### One-Line Installation (Ubuntu)

```bash
# PostgreSQL 17 on Ubuntu
sudo apt-get install -y postgresql-17 postgresql-server-dev-17 build-essential && \
git clone https://github.com/pgelephant/pg_stat_insights.git && \
cd pg_stat_insights && make && sudo make install && \
sudo -u postgres psql -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';" && \
sudo systemctl restart postgresql && \
sudo -u postgres psql -c "CREATE EXTENSION pg_stat_insights;"
```

### One-Line Installation (macOS)

```bash
# PostgreSQL 17 on macOS (Homebrew)
brew install postgresql@17 && \
git clone https://github.com/pgelephant/pg_stat_insights.git && \
cd pg_stat_insights && \
export PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config && \
make && make install && \
psql postgres -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';" && \
brew services restart postgresql@17 && sleep 3 && \
psql postgres -c "CREATE EXTENSION pg_stat_insights;"
```

---

## Version Matrix

| PostgreSQL | Ubuntu 22.04 | Ubuntu 24.04 | Debian 11 | Debian 12 | Rocky 9 | macOS |
|------------|--------------|--------------|-----------|-----------|---------|-------|
| **16** | [OK] | [OK] | [OK] | [OK] | [OK] | [OK] |
| **17** | [OK] | [OK] | [OK] | [OK] | [OK] | [OK] |
| **18** | [OK] | [OK] | [OK] | [OK] | [OK] | [OK] |

All combinations tested in CI/CD pipeline.

