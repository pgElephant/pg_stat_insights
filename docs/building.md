# Building from Source

Complete guide for building pg_stat_insights from source code on all supported platforms.

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **gcc** or **clang** | 7.0+ | C compiler |
| **make** | 3.81+ | Build system |
| **PostgreSQL** | 14-17 | Development headers |
| **git** | 2.0+ | Source control |

### PostgreSQL Development Package

=== "Ubuntu/Debian"

    ```bash
    sudo apt-get install -y postgresql-server-dev-17
    ```

=== "RHEL/Rocky/AlmaLinux"

    ```bash
    sudo dnf install -y postgresql17-devel
    ```

=== "macOS"

    ```bash
    brew install postgresql@17
    ```

---

## Quick Build

### Standard Build

```bash
# Clone repository
git clone https://github.com/pgelephant/pg_stat_insights.git
cd pg_stat_insights

# Build
make

# Install
sudo make install

# Run tests
make installcheck
```

### Custom PostgreSQL Location

```bash
# Set PG_CONFIG
export PG_CONFIG=/usr/pgsql-17/bin/pg_config

# Build and install
make PG_CONFIG=$PG_CONFIG
sudo make install PG_CONFIG=$PG_CONFIG

# Run tests
make installcheck PG_CONFIG=$PG_CONFIG
```

---

## Detailed Build Steps

### 1. Clone Repository

```bash
# HTTPS
git clone https://github.com/pgelephant/pg_stat_insights.git

# SSH (if you have access)
git clone git@github.com:pgelephant/pg_stat_insights.git

# Enter directory
cd pg_stat_insights
```

### 2. Verify Build Environment

```bash
# Check PostgreSQL version
pg_config --version

# Check pg_config location
which pg_config

# Verify PostgreSQL is installed
psql --version

# Check compiler
gcc --version  # or clang --version
```

### 3. Build Extension

```bash
# Clean previous builds
make clean

# Build
make

# Expected output:
# gcc -Wall -Wmissing-prototypes ... -c -o pg_stat_insights.o pg_stat_insights.c
# gcc ... -bundle -o pg_stat_insights.dylib pg_stat_insights.o
```

### 4. Install Extension

```bash
# Install (requires sudo on Linux)
sudo make install

# macOS (no sudo needed if using Homebrew)
make install

# Verify installation
ls -la $(pg_config --sharedir)/extension/pg_stat_insights*
ls -la $(pg_config --pkglibdir)/pg_stat_insights.*
```

### 5. Run Tests

```bash
# Run all 22 regression tests
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

## Build Targets

### Available Make Targets

| Target | Description |
|--------|-------------|
| `make` | Build extension (.so/.dylib file) |
| `make install` | Install extension files |
| `make installcheck` | Run regression tests |
| `make clean` | Remove build artifacts |
| `make uninstall` | Remove installed files |

### Full Clean Build

```bash
# Complete clean build with tests
make clean
make
sudo make install
make installcheck
```

---

## Platform-Specific Builds

### Ubuntu 22.04/24.04

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  git \
  postgresql-17 \
  postgresql-server-dev-17

# Build
cd pg_stat_insights
make
sudo make install

# Configure PostgreSQL
sudo -u postgres psql -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';"
sudo systemctl restart postgresql

# Create extension
sudo -u postgres psql -d postgres -c "CREATE EXTENSION pg_stat_insights;"
```

### Rocky Linux 9

```bash
# Install dependencies
sudo dnf install -y epel-release
sudo dnf install -y \
  https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf install -y \
  gcc make git \
  postgresql17-server \
  postgresql17-devel

# Initialize and start PostgreSQL
sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
sudo systemctl enable --now postgresql-17

# Build
cd pg_stat_insights
export PG_CONFIG=/usr/pgsql-17/bin/pg_config
make PG_CONFIG=$PG_CONFIG
sudo make install PG_CONFIG=$PG_CONFIG

# Configure
sudo -u postgres psql -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';"
sudo systemctl restart postgresql-17

# Create extension
sudo -u postgres psql -d postgres -c "CREATE EXTENSION pg_stat_insights;"
```

### macOS (Homebrew)

```bash
# Install dependencies
brew install postgresql@17 git

# Add to PATH
echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Start PostgreSQL
brew services start postgresql@17

# Build
cd pg_stat_insights
export PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
make PG_CONFIG=$PG_CONFIG
make install PG_CONFIG=$PG_CONFIG

# Configure
psql postgres -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_insights';"
brew services restart postgresql@17

# Create extension
psql postgres -c "CREATE EXTENSION pg_stat_insights;"
```

---

## Build Options

### Compiler Flags

```bash
# Debug build
make CFLAGS="-g -O0"

# Optimized build
make CFLAGS="-O3"

# With warnings as errors
make CFLAGS="-Werror"
```

### Custom Install Location

```bash
# Install to custom directory
make install DESTDIR=/custom/path

# Verify
ls -la /custom/path/$(pg_config --sharedir)/extension/
```

---

## Multi-Version Build

### Build for Multiple PostgreSQL Versions

```bash
# Script to build for all versions
for VERSION in 14 15 16 17; do
  echo "Building for PostgreSQL $VERSION"
  
  # Set PG_CONFIG
  export PG_CONFIG=/usr/lib/postgresql/$VERSION/bin/pg_config
  
  # Clean and build
  make clean
  make PG_CONFIG=$PG_CONFIG
  
  # Install
  sudo make install PG_CONFIG=$PG_CONFIG
  
  # Test
  make installcheck PG_CONFIG=$PG_CONFIG
  
  echo "PostgreSQL $VERSION: Complete"
done
```

---

## Build Troubleshooting

### Compiler Errors

**Error: "fatal error: 'postgres.h' file not found"**

**Cause**: PostgreSQL development headers not installed

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-server-dev-17

# RHEL/Rocky
sudo dnf install postgresql17-devel

# macOS
brew install postgresql@17
```

---

**Error: "fatal error: 'nodes/queryjumble.h' file not found"**

**Cause**: Building for PostgreSQL 14 but code expects PG 15+ include path

**Solution:**

This is automatically handled in code:
```c
#if PG_VERSION_NUM >= 150000
#include "nodes/queryjumble.h"  // PostgreSQL 15+
#else
#include "utils/queryjumble.h"  // PostgreSQL 14
#endif
```

Verify PG_CONFIG:
```bash
pg_config --version
```

---

### Linker Errors

**Error: "undefined reference to `function_name`"**

**Cause**: Missing PostgreSQL library

**Solution:**
```bash
# Verify PostgreSQL installation
pg_config --libdir
pg_config --pkglibdir

# Rebuild
make clean
make
```

---

### Permission Errors

**Error: "Permission denied" during install**

**Solution:**
```bash
# Use sudo on Linux
sudo make install

# Check file permissions
ls -la $(pg_config --sharedir)/extension/

# Fix if needed
sudo chown -R root:root $(pg_config --sharedir)/extension/
```

---

## Development Build

### Build for Development

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/pg_stat_insights.git
cd pg_stat_insights

# Create feature branch
git checkout -b feature/my-feature

# Build with debugging
make clean
make CFLAGS="-g -O0 -DDEBUG"

# Install
sudo make install

# Test your changes
make installcheck

# Check for issues
cat regression.diffs  # If tests fail
```

### Incremental Build

```bash
# After making changes to pg_stat_insights.c
make  # Rebuilds only changed files

# Force complete rebuild
make clean && make
```

---

## Packaging

### Build DEB Package

```bash
# Install packaging tools
sudo apt-get install -y debhelper devscripts

# Build package
cd pg_stat_insights
dpkg-buildpackage -b -uc -us

# Package created in parent directory
ls -la ../postgresql-17-pg-stat-insights_*.deb
```

### Build RPM Package

```bash
# Install packaging tools
sudo dnf install -y rpm-build rpmdevtools

# Setup RPM build environment
rpmdev-setuptree

# Build package
cd pg_stat_insights
make PG_CONFIG=/usr/pgsql-17/bin/pg_config

# Create RPM spec and build
rpmbuild -bb packaging/rpm/pg_stat_insights.spec

# Package created in ~/rpmbuild/RPMS/
ls -la ~/rpmbuild/RPMS/x86_64/
```

---

## Continuous Integration

### Local CI Testing

Simulate GitHub Actions build locally:

```bash
# Test Ubuntu build
docker run --rm -v $(pwd):/build -w /build ubuntu:22.04 bash -c "
  apt-get update && \
  apt-get install -y build-essential postgresql-17 postgresql-server-dev-17 && \
  make clean && make && make installcheck
"

# Test Rocky build
docker run --rm -v $(pwd):/build -w /build rockylinux:9 bash -c "
  dnf install -y epel-release && \
  dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
  dnf -qy module disable postgresql && \
  dnf install -y gcc make postgresql17-devel && \
  cd /build && make clean && make PG_CONFIG=/usr/pgsql-17/bin/pg_config
"
```

---

## Build Verification

### Verify Build Success

```bash
# Check compiled file
file pg_stat_insights.dylib  # macOS
file pg_stat_insights.so     # Linux

# Expected output:
# pg_stat_insights.dylib: Mach-O 64-bit dynamically linked shared library arm64
# pg_stat_insights.so: ELF 64-bit LSB shared object, x86-64

# Check symbols
nm pg_stat_insights.dylib | grep pg_stat_insights_reset
nm pg_stat_insights.so | grep pg_stat_insights_reset

# Install verification
ls -la $(pg_config --sharedir)/extension/pg_stat_insights.control
ls -la $(pg_config --sharedir)/extension/pg_stat_insights--1.0.sql
ls -la $(pg_config --pkglibdir)/pg_stat_insights.*
```

### Test Installation

```bash
# Create test database
createdb test_pg_stat_insights

# Test extension creation
psql test_pg_stat_insights <<EOF
CREATE EXTENSION pg_stat_insights;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_insights';
SELECT COUNT(*) FROM pg_stat_insights;
DROP EXTENSION pg_stat_insights;
EOF

# Cleanup
dropdb test_pg_stat_insights
```

---

## Advanced Build Options

### Cross-Compilation

```bash
# Example: Build for different architecture
make CC=aarch64-linux-gnu-gcc PG_CONFIG=/path/to/target/pg_config
```

### Static Analysis

```bash
# Run static analysis
make clean
scan-build make

# Check for issues
# scan-build will report potential bugs
```

### Code Coverage

```bash
# Build with coverage
make CFLAGS="-fprofile-arcs -ftest-coverage"

# Run tests
make installcheck

# Generate coverage report
gcov pg_stat_insights.c

# View coverage
cat pg_stat_insights.c.gcov
```

---

## Build Performance

### Parallel Build

```bash
# Use multiple cores
make -j$(nproc)  # Linux
make -j$(sysctl -n hw.ncpu)  # macOS
```

### Build Times

Typical build times:

| System | Build Time | Test Time |
|--------|------------|-----------|
| **Modern CPU (8 cores)** | 5-10 sec | 4-5 sec |
| **Older CPU (2 cores)** | 20-30 sec | 10-15 sec |
| **CI Environment** | 15-30 sec | 8-12 sec |

---

## Makefile Reference

### Important Makefile Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PG_CONFIG` | Path to pg_config | `/usr/lib/postgresql/17/bin/pg_config` |
| `MODULE_big` | Extension module name | `pg_stat_insights` |
| `OBJS` | Object files to build | `pg_stat_insights.o` |
| `EXTENSION` | Extension name | `pg_stat_insights` |
| `DATA` | SQL installation script | `pg_stat_insights--1.0.sql` |
| `REGRESS` | Regression test list | `01_extension_basics 02_basic_queries ...` |

### PGXS Integration

pg_stat_insights uses PostgreSQL Extension Building Infrastructure (PGXS):

```makefile
PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
```

This provides:
- Standard build targets
- PostgreSQL integration
- Cross-platform support
- Automatic dependency handling

---

## Debugging

### Debug Build

```bash
# Build with debug symbols
make clean
make CFLAGS="-g -O0 -DDEBUG"

# Debug with gdb
sudo gdb --args postgres -D /path/to/data

# In gdb:
(gdb) break pg_stat_insights_ExecutorEnd
(gdb) run
(gdb) continue
```

### Enable Debug Logging

Add to `postgresql.conf`:
```ini
log_min_messages = DEBUG1
log_error_verbosity = verbose
```

Run queries and check logs:
```bash
sudo tail -f /var/log/postgresql/postgresql-17-main.log
```

---

## Build Matrix Testing

### Test All PostgreSQL Versions

```bash
#!/bin/bash
# test-all-versions.sh

VERSIONS=(14 15 16 17)

for VERSION in "${VERSIONS[@]}"; do
  echo "===================="
  echo "Testing PostgreSQL $VERSION"
  echo "===================="
  
  # Set PG_CONFIG based on system
  if [ -f "/usr/lib/postgresql/$VERSION/bin/pg_config" ]; then
    PG_CONFIG="/usr/lib/postgresql/$VERSION/bin/pg_config"
  elif [ -f "/usr/pgsql-$VERSION/bin/pg_config" ]; then
    PG_CONFIG="/usr/pgsql-$VERSION/bin/pg_config"
  elif [ -f "/opt/homebrew/opt/postgresql@$VERSION/bin/pg_config" ]; then
    PG_CONFIG="/opt/homebrew/opt/postgresql@$VERSION/bin/pg_config"
  else
    echo "PostgreSQL $VERSION not found, skipping"
    continue
  fi
  
  # Build
  make clean
  make PG_CONFIG=$PG_CONFIG || { echo "Build failed for PG $VERSION"; exit 1; }
  
  # Install
  sudo make install PG_CONFIG=$PG_CONFIG || { echo "Install failed for PG $VERSION"; exit 1; }
  
  # Test
  make installcheck PG_CONFIG=$PG_CONFIG || { echo "Tests failed for PG $VERSION"; cat regression.diffs; exit 1; }
  
  echo "PostgreSQL $VERSION: [PASS]"
done

echo "All versions tested successfully!"
```

---

## Performance Optimization

### Compiler Optimizations

```bash
# Level 2 optimization (default)
make CFLAGS="-O2"

# Level 3 optimization (maximum)
make CFLAGS="-O3 -march=native"

# Size optimization
make CFLAGS="-Os"
```

### Link-Time Optimization

```bash
# Enable LTO
make CFLAGS="-O3 -flto" LDFLAGS="-flto"
```

---

## Creating Releases

### Version Bumping

1. Update version in files:
```bash
# pg_stat_insights.control
default_version = '1.1.0'

# Makefile
PACKAGE_VERSION = '1.1.0'

# .github/workflows/build-matrix.yml
PACKAGE_VERSION: '1.1.0'
```

2. Update CHANGELOG.md

3. Commit and tag:
```bash
git add -A
git commit -m "chore: bump version to 1.1.0"
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin main --tags
```

---

## Build Artifacts

### Generated Files

**Build artifacts:**
```
pg_stat_insights.o       # Object file
pg_stat_insights.so      # Linux shared library
pg_stat_insights.dylib   # macOS shared library
pg_stat_insights.bc      # LLVM bitcode (if enabled)
```

**Test artifacts:**
```
results/                 # Test output files
regression.diffs         # Test diff file
regression.out           # Test summary
tmp_check/              # Temporary test directory
```

**Installation files:**
```
pg_stat_insights.control            # Extension control file
pg_stat_insights--1.0.sql          # Installation SQL script
```

### Cleanup

```bash
# Remove build artifacts
make clean

# Remove test artifacts
rm -rf results/ regression.diffs regression.out tmp_check/

# Complete cleanup
git clean -fdx  # Warning: removes all untracked files
```

---

## Continuous Integration

### GitHub Actions

pg_stat_insights uses GitHub Actions for automated building and testing.

**Workflow:** `.github/workflows/build-matrix.yml`

**Matrix:**
- PostgreSQL versions: 14, 15, 16, 17
- Platforms: Ubuntu, macOS, Rocky Linux

**Manual trigger:**
```
1. Go to GitHub Actions tab
2. Select "Build Matrix"
3. Click "Run workflow"
4. Configure options
5. Click "Run workflow" button
```

See [CI/CD Guide](ci-cd.md) for complete details.

---

## Next Steps

- **[Testing Guide](testing.md)** - Run regression tests
- **[CI/CD Guide](ci-cd.md)** - Automate builds
- **[Contributing Guide](contributing.md)** - Contribute code
- **[Installation Guide](installation.md)** - Install built extension

