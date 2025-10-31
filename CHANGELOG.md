# Changelog

All notable changes to pg_stat_insights will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Enhanced Test Suite** - Expanded from 13 to 22 comprehensive regression tests
  - Test 14: Prepared statements and plan caching
  - Test 15: Complex joins (INNER, LEFT, RIGHT, FULL, self-joins, subqueries)
  - Test 16: JSON/JSONB operations (field access, containment, path queries, aggregation)
  - Test 17: Array operations (containment, overlap, functions, ANY/ALL operators)
  - Test 18: Partitioned tables (partition pruning, cross-partition queries)
  - Test 19: Triggers and stored functions (PL/pgSQL functions, audit triggers)
  - Test 20: Advanced window functions (ROW_NUMBER, RANK, LAG, LEAD, aggregates)
  - Test 21: Transaction handling (COMMIT, ROLLBACK, savepoints)
  - Test 22: Query normalization (parameterization with different literals)
- **PostgreSQL 14-17 Compatibility** - Added version detection for queryjumble.h include path
  - PostgreSQL 14-16: uses `utils/queryjumble.h`
  - PostgreSQL 17+: uses `nodes/queryjumble.h`
- **GitHub Actions Workflows**
  - Build matrix workflow for PostgreSQL 14, 15, 16, 17 across Ubuntu, macOS, Rocky Linux
  - Documentation deployment workflow to GitHub Pages
  - DEB package generation (Ubuntu/Debian)
  - RPM package generation (RHEL/Rocky/AlmaLinux)
  - Automated regression testing in CI
- **Test Improvements**
  - Added ORDER BY clauses for deterministic test results
  - Fixed timestamp values in test tables to prevent non-deterministic output
  - Enhanced existing tests with additional edge cases
  - Improved statistical accuracy validation

### Fixed
- Query ordering in regression tests for consistent, deterministic results
- Timestamp-related test failures by using fixed timestamps
- PostgreSQL version compatibility for header file includes
- Test 03, 04, 05, 10, 11: Enhanced with additional test cases and ORDER BY fixes

### Changed
- Updated .gitignore to exclude test_db/ directory and test artifacts
- Improved test coverage from basic functionality to comprehensive feature testing

## [1.0.0] - 2024-10-27

### Added
- Initial release of pg_stat_insights
- Support for PostgreSQL 16, 17, 18 (requires queryjumble.h added in PG 14+)
- 52 comprehensive query performance metrics
- 11 pre-built analytical views for instant insights
- 11 configuration parameters for fine-tuning
- Drop-in replacement for pg_stat_statements with enhanced features
- Response time categorization and histogram buckets
- Cache hit/miss analysis views
- WAL generation monitoring
- JIT compilation statistics tracking
- Planning time statistics (when enabled)
- Parallel query worker metrics
- Time-series tracking with bucket analysis
- User and database level query tracking
- Comprehensive TAP test suite (150 tests across 23 files)
- Custom StatsInsightManager.pm test framework
- RPM package support (RHEL/Rocky/AlmaLinux 9)
- DEB package support (Ubuntu/Debian)
- GitHub Actions workflows for automated builds
- Complete MkDocs documentation with 15+ pages
- Prometheus/Grafana integration examples
- Pre-built monitoring dashboards and alert rules

### Features
- **Performance Analysis**
  - Top queries by execution time
  - Top queries by call frequency
  - Top queries by I/O operations
  - Slow query detection (>100ms)
  - Query execution time variability tracking

- **Cache Analysis**
  - Buffer cache hit/miss tracking
  - Cache inefficiency detection
  - Per-query cache ratio analysis

- **WAL Monitoring**
  - WAL record generation per query
  - WAL byte tracking
  - Full page image counts

- **Advanced Metrics**
  - JIT compilation statistics
  - Planning time tracking
  - Parallel worker metrics
  - Temporary block I/O
  - Error tracking

### Documentation
- Complete installation guide
- Configuration reference for all parameters
- SQL API documentation
- 30+ ready-to-use query examples
- Prometheus/Grafana integration guide
- Comparison with pg_stat_statements and pg_stat_monitor

### Package Management
- Version-specific RPM packages for each PostgreSQL version
- Version-specific DEB packages for each PostgreSQL version
- Automated GitHub Actions workflows
- Package testing in CI/CD pipeline
- SHA256 checksums for all packages

## [Unreleased]

### Planned
- Additional histogram buckets for fine-grained response time analysis
- Query fingerprinting improvements
- Enhanced Grafana dashboard templates
- Additional alert rule examples
- Performance optimization for high-volume workloads

---

For detailed version history and development updates, see the [commit log](https://github.com/pgelephant/pg_stat_insights/commits/main).

