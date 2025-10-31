# pg_stat_insights - Executable Test Suite

## Overview

This directory contains **executable SQL test scripts** that can be run directly against a PostgreSQL database with `pg_stat_insights` installed.

## Test Files

| File | Purpose | Tests | Duration |
|------|---------|-------|----------|
| `01_basic_functionality.sql` | Core features | 17 tests | ~30 seconds |
| `02_performance_benchmark.sql` | Performance analysis | 5 benchmarks | ~2 minutes |
| `03_edge_cases.sql` | Edge case handling | 15 tests | ~45 seconds |

## Prerequisites

```bash
# PostgreSQL 16, 17, or 18 required
psql --version

# Install pg_stat_insights
cd /path/to/pg_stat_insights
make
sudo make install

# Configure PostgreSQL
echo "shared_preload_libraries = 'pg_stat_insights'" | \
  sudo tee -a /path/to/postgresql.conf

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Running Tests

### Quick Start

```bash
# Run all tests
psql -U postgres -d test_database -f tests/01_basic_functionality.sql
psql -U postgres -d test_database -f tests/02_performance_benchmark.sql
psql -U postgres -d test_database -f tests/03_edge_cases.sql
```

### Individual Tests

```bash
# Test 1: Basic Functionality (17 tests)
psql -f tests/01_basic_functionality.sql

# Test 2: Performance Benchmark (5 benchmarks)
psql -f tests/02_performance_benchmark.sql

# Test 3: Edge Cases (15 tests)
psql -f tests/03_edge_cases.sql
```

### Save Output

```bash
psql -f tests/01_basic_functionality.sql > test_results.txt 2>&1
```

## Test Details

### Test 1: Basic Functionality (`01_basic_functionality.sql`)

**Tests:**
1. ✅ Extension installation
2. ✅ All 11 views exist
3. ✅ Main view has 52 columns
4. ✅ All 52 columns listed
5. ✅ Core functions exist
6. ✅ Reset statistics
7. ✅ Create test data
8. ✅ Execute test queries
9. ✅ Verify query tracking
10. ✅ Verify metric columns populated
11. ✅ Top queries view
12. ✅ Cache performance view
13. ✅ WAL statistics
14. ✅ Execution time statistics
15. ✅ Standard deviation calculation
16. ✅ Reset specific query
17. ✅ Cleanup

**Expected Output:**
```
✅ PASS | Extension installed
✅ PASS | All 11 views exist (11/11)
✅ PASS | Main view has 52 columns (52/52)
...
```

**Duration:** ~30 seconds

### Test 2: Performance Benchmark (`02_performance_benchmark.sql`)

**Benchmarks:**
1. Simple SELECT (1000 queries)
2. Complex JOIN (100 queries)
3. Aggregation (500 queries)
4. Write operations (100 INSERTs)
5. UPDATE operations (100 UPDATEs)

**Metrics Measured:**
- Per-query execution time
- Overhead percentage
- Cache hit ratio
- WAL generation
- Standard deviation

**Expected Overhead:** <2%

**Duration:** ~2 minutes

### Test 3: Edge Cases (`03_edge_cases.sql`)

**Tests:**
1. ✅ Empty query results
2. ✅ Very long queries
3. ✅ Special characters
4. ✅ Nested subqueries
5. ✅ CTEs (WITH queries)
6. ✅ Prepared statements
7. ✅ Transaction rollback
8. ✅ Very fast queries (<1ms)
9. ✅ Zero rows returned
10. ✅ Concurrent queries
11. ✅ Error handling
12. ✅ NULL values
13. ✅ Large result sets
14. ✅ Statistics consistency
15. ✅ Reset after edge cases

**Duration:** ~45 seconds

## Expected Results

### Success Indicators

All tests should show `✅ PASS`:

```
=== TEST 1: Extension Installation ===
✅ PASS | Extension installed

=== TEST 2: Verify All 11 Views Exist ===
✅ PASS | All 11 views exist (11/11)

=== TEST 3: Verify Main View Has 52 Columns ===
✅ PASS | Main view has 52 columns (52/52)
```

### Performance Expectations

```
Overhead Analysis:
  - Overhead: < 2% ✅
  - Cache hit ratio: > 95% ✅
  - Mean execution time: consistent
```

## Troubleshooting

### Issue: Extension not found

```
ERROR:  extension "pg_stat_insights" is not available
```

**Solution:**
```bash
# Verify extension is installed
ls -l $(pg_config --pkglibdir)/pg_stat_insights.so

# Verify control file exists
ls -l $(pg_config --sharedir)/extension/pg_stat_insights.control

# Reinstall if needed
cd /path/to/pg_stat_insights
make clean
make
sudo make install
```

### Issue: Extension not loading

```
ERROR:  could not access file "$libdir/pg_stat_insights": No such file
```

**Solution:**
```bash
# Add to postgresql.conf
shared_preload_libraries = 'pg_stat_insights'

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Issue: Insufficient privileges

```
ERROR:  permission denied for function pg_stat_insights_reset
```

**Solution:**
```sql
-- Grant necessary privileges
GRANT pg_stat_reset TO your_user;
```

## Interpreting Results

### Test Success

```
✅ PASS | Test name
```
- Test completed successfully
- All assertions passed
- Expected behavior confirmed

### Test Failure

```
❌ FAIL | Test name
```
- Test did not meet expectations
- Check test output for details
- Review extension logs

### Performance Rating

```
✅ Excellent (<1% overhead)
✅ Good (<2% overhead)
⚠️  Acceptable (<5% overhead)
❌ High (>5% overhead)
```

## Advanced Testing

### Custom Workload

```sql
-- Create your own test
BEGIN;

SELECT pg_stat_insights_reset();

-- Your queries here
SELECT ...;

-- Check statistics
SELECT * FROM pg_stat_insights_top_by_time;

ROLLBACK;
```

### Stress Testing

```sql
-- High concurrency simulation
DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        PERFORM count(*) FROM large_table WHERE id = i;
    END LOOP;
END $$;

-- Check overhead
SELECT 
    count(*) as queries,
    avg(mean_exec_time) as avg_time_ms,
    max(mean_exec_time) as max_time_ms
FROM pg_stat_insights;
```

### Long-Running Test

```bash
# Run for 1 hour
while true; do
    psql -f tests/02_performance_benchmark.sql
    sleep 300
done
```

## Automated Testing

### Shell Script

```bash
#!/bin/bash
# run_all_tests.sh

TESTS=(
    "tests/01_basic_functionality.sql"
    "tests/02_performance_benchmark.sql"
    "tests/03_edge_cases.sql"
)

for test in "${TESTS[@]}"; do
    echo "Running $test..."
    psql -f "$test" >> test_results.txt 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ $test passed"
    else
        echo "❌ $test failed"
    fi
done
```

### CI/CD Integration

```yaml
# .gitlab-ci.yml or similar
test:
  script:
    - make install
    - pg_ctl restart
    - psql -f tests/01_basic_functionality.sql
    - psql -f tests/02_performance_benchmark.sql
    - psql -f tests/03_edge_cases.sql
```

## Test Coverage

| Category | Coverage | Tests |
|----------|:--------:|-------|
| Core Functionality | 100% | 17 tests |
| Performance | 100% | 5 benchmarks |
| Edge Cases | 100% | 15 tests |
| Views | 100% | 11 views |
| Metrics | 100% | 52 columns |
| Functions | 100% | 4 functions |

**Total: 37 executable tests**

## Support

For issues or questions:
- GitHub Issues: https://github.com/pgelephant/pg_stat_insights/issues
- Documentation: https://pgelephant.github.io/pg_stat_insights/
- Email: support@pgelephant.com

## License

Copyright (c) 2024-2025, pgElephant, Inc.
MIT License - See LICENSE file for details

