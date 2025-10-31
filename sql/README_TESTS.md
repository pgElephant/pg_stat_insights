# pg_stat_insights Test Suite

PostgreSQL-style regression tests for the pg_stat_insights extension.

## Test Files Overview

### Core Functionality Tests

1. **01_extension_basics.sql**
   - Extension creation and versioning
   - Object existence verification (functions, views)
   - Basic function signatures
   - View accessibility

2. **02_basic_queries.sql**
   - Query tracking verification
   - Statistics collection confirmation
   - Basic SELECT, INSERT operations
   - Execution time tracking

3. **03_views_and_aggregates.sql**
   - All 11 helper views
   - View ordering and filtering
   - Cache hit ratio calculations
   - Histogram and bucket views

4. **04_statistics_accuracy.sql**
   - Call count accuracy
   - Min/max/mean relationships
   - Standard deviation calculations
   - Row count tracking
   - Total time consistency

5. **05_io_and_cache.sql**
   - Block-level I/O tracking
   - Cache hit/miss statistics
   - Shared/local/temp block tracking
   - Block timing statistics
   - Cache hit ratio validation

6. **06_wal_tracking.sql**
   - WAL records counting
   - WAL bytes tracking
   - Full Page Images (FPI) tracking
   - WAL buffer statistics
   - INSERT/UPDATE/DELETE WAL generation

7. **07_reset_functionality.sql**
   - Global reset (all statistics)
   - Selective reset (specific query)
   - Statistics persistence after reset
   - Reset validation

8. **08_parallel_queries.sql**
   - Parallel worker statistics
   - Workers planned vs launched
   - Toplevel query tracking
   - Parallel query execution

9. **09_jit_tracking.sql**
   - JIT compilation statistics
   - JIT timing metrics (generation, inlining, optimization, emission)
   - JIT deform tracking
   - JIT usage correlation

10. **10_edge_cases.sql**
    - NULL value handling
    - Empty result sets
    - Special characters in queries
    - Long query text
    - Division by zero protection
    - Invalid reset parameters

11. **11_comprehensive_metrics.sql**
    - All 50+ metrics validation
    - Complex query patterns (CTE, window functions, subqueries)
    - Index scans and sequential scans
    - Timestamp tracking (stats_since, minmax_stats_since)
    - QueryID uniqueness

12. **12_permissions.sql**
    - PUBLIC SELECT permissions on all views
    - Function EXECUTE permissions
    - Security and access control
    - Non-superuser accessibility

13. **13_cleanup.sql**
    - Final reset validation
    - Extension drop cascade
    - Cleanup verification

## Running the Tests

### Full test suite:
```bash
make installcheck
```

### Individual test:
```bash
make installcheck REGRESS=01_extension_basics
```

### Multiple specific tests:
```bash
make installcheck REGRESS="01_extension_basics 02_basic_queries"
```

### Clean up test results:
```bash
make clean
```

## Test Coverage

The test suite covers:
- ✅ Extension installation and versioning
- ✅ All 11 views (main + 10 helper views)
- ✅ Both reset functions (global + selective)
- ✅ 50+ metrics across all categories:
  - Execution statistics (time, calls, rows)
  - Planning statistics
  - Block I/O (shared, local, temp)
  - Cache performance
  - WAL generation (records, bytes, FPI)
  - JIT compilation (10 metrics)
  - Parallel workers
  - Timestamps
- ✅ Edge cases and error handling
- ✅ Permissions and security
- ✅ Data accuracy and consistency
- ✅ View ordering and filtering logic
- ✅ NULL handling
- ✅ Division by zero protection
- ✅ Extension cleanup

## Expected Results

All tests should pass with output matching the expected/ files.

## Notes

- Tests use `?` in expected output where exact values vary (timestamps, random data, etc.)
- Tests include `pg_sleep()` calls to ensure statistics are collected
- Some tests depend on PostgreSQL version (JIT requires PG 11+, certain metrics require specific versions)
- Tests are designed to be deterministic where possible

