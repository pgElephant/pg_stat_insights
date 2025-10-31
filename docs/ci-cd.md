# CI/CD Guide

pg_stat_insights uses GitHub Actions for continuous integration and deployment across multiple PostgreSQL versions and platforms.

## Workflows Overview

### 1. Build Matrix Workflow

**File**: `.github/workflows/build-matrix.yml`

Builds and tests pg_stat_insights across multiple PostgreSQL versions and platforms.

#### Features

- [OK] **Multi-version support**: PostgreSQL 16, 17, 18
- [OK] **Multi-platform**: Ubuntu, macOS, Rocky Linux
- [OK] **Automated testing**: Runs all 22 regression tests
- [OK] **Package generation**: DEB and RPM packages
- [OK] **Release creation**: Optional GitHub release with artifacts

#### Trigger

**Manual only** - Run via GitHub Actions UI:

```yaml
on:
  workflow_dispatch:
    inputs:
      pg_versions:
        description: 'PostgreSQL versions (comma-separated)'
        default: '16,17,18'
      platforms:
        description: 'Platforms (ubuntu,macos,rocky)'
        default: 'ubuntu,macos,rocky'
      create_release:
        description: 'Create GitHub release'
        type: boolean
        default: false
```

#### Build Matrix

| Platform | PostgreSQL 16 | PostgreSQL 17 | PostgreSQL 18 |
|----------|---------------|---------------|---------------|
| **Ubuntu 22.04** | [OK] | [OK] | [OK] |
| **macOS 14** | [OK] | [OK] | [OK] |
| **Rocky Linux 9** | [OK] | [OK] | [OK] |

#### Jobs

1. **Authorize** - Check user permissions
2. **Prepare** - Generate build matrix
3. **Build** - Compile extension for each version/platform
4. **Package DEB** - Create Debian packages
5. **Package RPM** - Create RPM packages
6. **Test Packages** - Install and verify packages
7. **Release** - Create GitHub release (optional)
8. **Summary** - Generate build report

#### Running the Workflow

1. Go to GitHub Actions tab
2. Select "Build Matrix" workflow
3. Click "Run workflow"
4. Configure options:
   - **PostgreSQL versions**: e.g., `14,15,16,17`
   - **Platforms**: e.g., `ubuntu,macos`
   - **Create release**: Check if creating a release
   - **Release tag**: e.g., `v1.0.1`
5. Click "Run workflow"

#### Artifacts

Build artifacts are retained for **30 days**:
- `pg_stat_insights-ubuntu-pg14.tar.gz`
- `pg_stat_insights-ubuntu-pg15.tar.gz`
- `pg_stat_insights-ubuntu-pg16.tar.gz`
- `pg_stat_insights-ubuntu-pg17.tar.gz`
- Similar for macOS and Rocky Linux

Test results are retained for **7 days**:
- `test-results-ubuntu-pg14/`
- `regression.diffs`
- `regression.out`

### 2. Documentation Workflow

**File**: `.github/workflows/docs.yml`

Deploys MkDocs documentation to GitHub Pages.

#### Features

- [OK] **MkDocs Material theme**
- [OK] **Python 3.11**
- [OK] **Dependency caching**
- [OK] **Strict mode** (catches doc errors)
- [OK] **GitHub Pages deployment**

#### Trigger

**Manual only** - Run via GitHub Actions UI:

```yaml
on:
  workflow_dispatch:
```

#### Running the Workflow

1. Go to GitHub Actions tab
2. Select "Deploy Documentation" workflow
3. Click "Run workflow"
4. Click "Run workflow" button

Documentation will be deployed to:
- **URL**: https://pgelephant.github.io/pg_stat_insights/

#### Documentation Structure

```
docs/
├── index.md                 # Homepage
├── getting-started.md       # Installation guide
├── configuration.md         # Configuration parameters
├── views.md                 # View reference
├── metrics.md               # Metric reference
├── usage.md                 # Usage examples
├── testing.md               # Testing guide
├── ci-cd.md                 # This file
├── troubleshooting.md       # Common issues
├── zh_CN/                   # Chinese (Simplified)
├── zh_TW/                   # Chinese (Traditional)
└── ja_JP/                   # Japanese
```

## Package Building

### DEB Packages (Ubuntu/Debian)

Generated for:
- Ubuntu 22.04 (Jammy)
- Ubuntu 24.04 (Noble)
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)

Package naming: `postgresql-<version>-pg-stat-insights_<ver>-<rel>_<arch>.deb`

Example:
```
postgresql-17-pg-stat-insights_1.0.0-1_amd64.deb
```

### RPM Packages (RHEL/Rocky/AlmaLinux)

Generated for:
- Rocky Linux 9
- AlmaLinux 9
- CentOS Stream 9

Package naming: `pg_stat_insights_<pgver>-<ver>-<rel>.<dist>.<arch>.rpm`

Example:
```
pg_stat_insights_17-1.0.0-1.el9.x86_64.rpm
```

## Version Compatibility

### PostgreSQL Version Detection

The code automatically detects PostgreSQL version:

```c
#if PG_VERSION_NUM >= 170000
#include "nodes/queryjumble.h"
#else
#include "utils/queryjumble.h"
#endif
```

### Supported Versions

| PostgreSQL | Status | Notes |
|------------|--------|-------|
| **14** | [OK] Supported | Uses `utils/queryjumble.h` |
| **15** | [OK] Supported | Uses `utils/queryjumble.h` |
| **16** | [OK] Supported | Uses `utils/queryjumble.h` |
| **17** | [OK] Supported | Uses `nodes/queryjumble.h` |

## Environment Setup

### Ubuntu/Debian

```bash
# Install PostgreSQL repository
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
  gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
  http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
  sudo tee /etc/apt/sources.list.d/pgdg.list

# Install build dependencies
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  postgresql-server-dev-17
```

### macOS (Homebrew)

```bash
# Install PostgreSQL
brew install postgresql@17

# Set PG_CONFIG
export PG_CONFIG=/opt/homebrew/opt/postgresql@17/bin/pg_config
```

### Rocky Linux/RHEL

```bash
# Install PostgreSQL repository
sudo dnf install -y epel-release
sudo dnf install -y \
  https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable built-in module
sudo dnf -qy module disable postgresql

# Install build dependencies
sudo dnf install -y \
  gcc \
  make \
  postgresql17-devel
```

## Local Testing

### Test Against Multiple Versions

```bash
# PostgreSQL 16
export PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
make clean && make && make installcheck

# PostgreSQL 17
export PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config
make clean && make && make installcheck
```

### Docker Testing

```bash
# PostgreSQL 17
docker run --rm -v $(pwd):/build -w /build \
  postgres:17 bash -c "\
  apt-get update && \
  apt-get install -y build-essential postgresql-server-dev-17 && \
  make clean && make && make installcheck"
```

## Release Process

### 1. Update Version

Update version in:
- `pg_stat_insights.control` - `default_version`
- `Makefile` - `PACKAGE_VERSION`
- `.github/workflows/build-matrix.yml` - `PACKAGE_VERSION`
- `CHANGELOG.md` - Add new release section

### 2. Update Documentation

```bash
# Update CHANGELOG.md
# Update README.md badges
# Update docs/ if needed
```

### 3. Run Tests Locally

```bash
# Test on all versions
for ver in 14 15 16 17; do
  export PG_CONFIG=/usr/lib/postgresql/$ver/bin/pg_config
  make clean && make && make installcheck || exit 1
done
```

### 4. Commit and Tag

```bash
git add -A
git commit -m "chore: release v1.0.1"
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin main --tags
```

### 5. Run GitHub Workflow

1. Go to GitHub Actions
2. Select "Build Matrix"
3. Run workflow with:
   - `create_release`: true
   - `release_tag`: v1.0.1

### 6. Verify Release

Check:
- [OK] All builds passed
- [OK] All tests passed (22/22)
- [OK] Packages generated
- [OK] Release created with artifacts
- [OK] SHA256SUMS included

## Monitoring

### GitHub Actions Status

Monitor workflow runs:
- https://github.com/pgElephant/pg_stat_insights/actions

### Build Times

Typical workflow duration:
- **Build**: 3-5 minutes per version/platform
- **Package DEB**: 5-10 minutes
- **Package RPM**: 5-10 minutes
- **Total**: 45-60 minutes for full matrix

### Resource Usage

Concurrent jobs:
- Maximum 20 concurrent runners (GitHub Free tier)
- Each job runs independently
- Matrix strategy parallelizes builds

## Troubleshooting

### Build Failures

**Check logs**:
```
1. Go to Actions tab
2. Click on failed run
3. Click on failed job
4. Expand failed step
```

**Common issues**:
- PostgreSQL not started: Check PostgreSQL service status
- Permission denied: Check file permissions
- Test failures: Check `regression.diffs` artifact

### Package Issues

**DEB installation fails**:
```bash
# Check dependencies
apt-cache depends postgresql-17-pg-stat-insights

# Manual install with fixes
sudo dpkg -i package.deb || sudo apt-get install -f -y
```

**RPM installation fails**:
```bash
# Check dependencies
rpm -qpR package.rpm

# Install with dependencies
sudo dnf install -y package.rpm
```

### Documentation Issues

**MkDocs build fails**:
```bash
# Test locally
pip install -r docs-requirements.txt
mkdocs build --strict

# Check for errors in docs
mkdocs serve
```

## Best Practices

1. **Always test locally** before pushing
2. **Run full test suite** on all versions
3. **Update CHANGELOG.md** for every change
4. **Version compatibility** - test new PostgreSQL versions
5. **Document breaking changes** prominently
6. **Keep workflows fast** - optimize build steps
7. **Monitor artifact size** - clean up old artifacts
8. **Use semantic versioning** - MAJOR.MINOR.PATCH

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PostgreSQL Extension Building](https://www.postgresql.org/docs/current/extend-pgxs.html)
- [MkDocs Documentation](https://www.mkdocs.org/)
- [Semantic Versioning](https://semver.org/)

