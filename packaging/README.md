# pg_stat_insights Packaging

This directory contains packaging files for building RPM and DEB packages of pg_stat_insights for various PostgreSQL versions.

## Supported Versions

- PostgreSQL 16, 17, 18
- Rocky Linux / AlmaLinux / RHEL 9 (RPM)
- Ubuntu 22.04+ / Debian (DEB)

**Note**: PostgreSQL 16+ is required due to dependency on `nodes/queryjumble.h` (added in PG 14).

## Package Structure

```
packaging/
├── rpm/
│   └── pg_stat_insights.spec     # RPM spec file
└── debian/
    ├── control                    # Package metadata
    ├── rules                      # Build rules
    ├── changelog                  # Changelog
    └── compat                     # Debhelper compatibility level
```

## GitHub Actions Workflow

The packages are built automatically using GitHub Actions workflows:

- `.github/workflows/build-packages.yml` - Main workflow (manual trigger)
- `.github/workflows/reusable-build-rpm.yml` - RPM build workflow
- `.github/workflows/reusable-build-deb.yml` - DEB build workflow

### Manual Trigger

1. Go to: `https://github.com/pgelephant/pg_stat_insights/actions`
2. Select "Build Packages" workflow
3. Click "Run workflow"
4. Configure options:
   - **pg_versions**: Comma-separated list (e.g., `16,17,18`)
   - **create_release**: Check to create GitHub release
   - **release_tag**: Release tag name (e.g., `REL_1_0`, `v1.0.0`)
5. Click "Run workflow"

### Workflow Features

- ✅ Matrix build across all PostgreSQL versions
- ✅ Builds both RPM and DEB packages
- ✅ Automatic package testing
- ✅ Optional GitHub release creation
- ✅ SHA256SUMS generation
- ✅ Artifact retention (30 days)

## Package Naming

### RPM Packages
```
pg_stat_insights_<pg_version>-<version>-<release>.el9.<arch>.rpm
```
Example: `pg_stat_insights_17-1.0.0-1.el9.x86_64.rpm`

### DEB Packages
```
postgresql-<pg_version>-pg-stat-insights_<version>-<release>_<arch>.deb
```
Example: `postgresql-17-pg-stat-insights_1.0.0-1_amd64.deb`

## Building Locally

### Build RPM

```bash
# Install dependencies
sudo dnf install rpm-build rpmdevtools postgresql17-devel

# Create source tarball
VERSION=1.0.0
tar czf ~/rpmbuild/SOURCES/pg_stat_insights-${VERSION}.tar.gz \
  --transform "s,^,pg_stat_insights-${VERSION}/," \
  *.c *.sql *.control Makefile LICENSE README.md

# Build RPM
rpmbuild -ba packaging/rpm/pg_stat_insights.spec \
  --define "pg_version 17" \
  --define "package_version ${VERSION}"
```

### Build DEB

```bash
# Install dependencies
sudo apt install build-essential debhelper postgresql-server-dev-17

# Prepare build directory
VERSION=1.0.0
BUILD_DIR=pg_stat_insights-postgresql-17-${VERSION}
mkdir -p ${BUILD_DIR}
cp -r *.c *.sql *.control Makefile LICENSE README.md ${BUILD_DIR}/
cp -r packaging/debian ${BUILD_DIR}/
cd ${BUILD_DIR}

# Update PostgreSQL version in control file
sed -i "s/@PG_VERSION@/17/g" debian/control

# Build package
dpkg-buildpackage -us -uc -b
```

## Installation

### RPM Installation

```bash
# Install package
sudo dnf install pg_stat_insights_17-1.0.0-1.el9.x86_64.rpm

# Verify installation
rpm -ql pg_stat_insights_17
```

### DEB Installation

```bash
# Install package
sudo apt install ./postgresql-17-pg-stat-insights_1.0.0-1_amd64.deb

# Verify installation
dpkg -L postgresql-17-pg-stat-insights
```

## Post-Installation

After installing the package, configure PostgreSQL:

1. Edit `postgresql.conf`:
   ```ini
   shared_preload_libraries = 'pg_stat_insights'
   ```

2. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

3. Create extension:
   ```sql
   CREATE EXTENSION pg_stat_insights;
   ```

4. Verify:
   ```sql
   SELECT * FROM pg_stat_insights_top_slow_queries LIMIT 10;
   ```

## Package Contents

### Files Installed

- **Library**: `/usr/pgsql-<ver>/lib/pg_stat_insights.so` (RPM) or `/usr/lib/postgresql/<ver>/lib/pg_stat_insights.so` (DEB)
- **SQL**: `/usr/pgsql-<ver>/share/extension/pg_stat_insights--*.sql`
- **Control**: `/usr/pgsql-<ver>/share/extension/pg_stat_insights.control`
- **Bitcode**: `/usr/pgsql-<ver>/lib/bitcode/pg_stat_insights/` (for JIT compilation)

## Troubleshooting

### Build Failures

1. **PostgreSQL version not found**:
   - Ensure PostgreSQL repository is configured
   - Check version availability: `dnf list postgresql*-devel` or `apt-cache search postgresql-server-dev`

2. **Missing build dependencies**:
   - RPM: `sudo dnf install gcc make postgresql<ver>-devel`
   - DEB: `sudo apt install build-essential postgresql-server-dev-<ver>`

3. **Permission errors**:
   - Ensure rpmbuild directories exist: `rpmdev-setuptree`
   - Ensure proper file permissions: `chmod +x packaging/debian/rules`

### Installation Failures

1. **Dependency errors**:
   - Install PostgreSQL server first
   - RPM: `sudo dnf install postgresql<ver>-server`
   - DEB: `sudo apt install postgresql-<ver>`

2. **Shared library not found**:
   - Check library path: `ldconfig -p | grep pg_stat_insights`
   - Verify PostgreSQL version matches package version

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/pgelephant/pg_stat_insights/issues
- Documentation: https://pgelephant.github.io/pg_stat_insights/
- Email: team@pgelephant.org

