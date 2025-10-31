# Testing Guide

pg_stat_insights includes a comprehensive test suite with 22 regression tests covering all major PostgreSQL features.

## Test Suite Overview

The test suite validates:
- [OK] **22 test cases** covering all functionality
- [OK] **PostgreSQL 14-17 compatibility**
- [OK] **Deterministic results** with ORDER BY and fixed timestamps
- [OK] **All 52 metrics** tracked and validated
- [OK] **All 11 views** functionality verified

## Running Tests

### Prerequisites

```bash
# Ensure PostgreSQL is installed and running
pg_config --version

# Set PG_CONFIG if needed
export PG_CONFIG=/path/to/pg_config
```

### Run Full Test Suite

```bash
cd pg_stat_insights
make installcheck
```

### Run Specific Tests

```bash
# Run a single test
make installcheck REGRESS=01_extension_basics

# Run multiple tests
make installcheck REGRESS="01_extension_basics 02_basic_queries"
```

## Test Categories

### Core Functionality (Tests 1-13)

| Test | Description | Focus Area |
|------|-------------|------------|
| **01_extension_basics** | Extension installation and basic setup | Installation, functions, views |
| **02_basic_queries** | Basic query tracking | SELECT, INSERT, UPDATE, DELETE |
| **03_views_and_aggregates** | View functionality and aggregations | Helper views, filtering, ordering |
| **04_statistics_accuracy** | Statistical accuracy validation | min/max/mean/stddev relationships |
| **05_io_and_cache** | I/O and cache statistics | Block reads, cache hits, timing |
| **06_wal_tracking** | WAL generation monitoring | WAL records, FPI, bytes |
| **07_reset_functionality** | Statistics reset functions | Global and query-specific reset |
| **08_parallel_queries** | Parallel query execution | Worker launch/execution stats |
| **09_jit_tracking** | JIT compilation statistics | JIT functions, timing |
| **10_edge_cases** | Edge cases and error handling | NULL values, empty results, special chars |
| **11_comprehensive_metrics** | All 52 metrics validation | Full metric coverage |
| **12_permissions** | Permission and security | User roles, access control |
| **13_cleanup** | Extension cleanup | DROP EXTENSION |

### Advanced Features (Tests 14-22)

| Test | Description | Features Tested |
|------|-------------|-----------------|
| **14_prepared_statements** | Prepared statement tracking | PREPARE, EXECUTE, DEALLOCATE, plan caching |
| **15_complex_joins** | Complex join operations | INNER, LEFT, RIGHT, FULL, self-joins, subqueries |
| **16_json_operations** | JSON/JSONB functionality | Field access, containment, path queries, aggregation |
| **17_array_operations** | Array operations | Containment, overlap, unnest, ANY/ALL operators |
| **18_partitioning** | Partitioned tables | Partition pruning, cross-partition queries |
| **19_triggers_functions** | Triggers and PL/pgSQL | Trigger execution, stored functions, audit logging |
| **20_window_functions** | Advanced window functions | ROW_NUMBER, RANK, LAG, LEAD, window frames |
| **21_transaction_handling** | Transaction management | COMMIT, ROLLBACK, savepoints, isolation |
| **22_query_normalization** | Query parameterization | Literal normalization, queryid consistency |

## Test Results

All tests must pass for a successful build:

```
# Example output
ok 1         - 01_extension_basics                        27 ms
ok 2         - 02_basic_queries                          120 ms
ok 3         - 03_views_and_aggregates                   123 ms
...
ok 22        - 22_query_normalization                    235 ms
1..22
# All 22 tests passed.
```

## Debugging Test Failures

### View Test Diffs

```bash
# Show differences between expected and actual output
cat regression.diffs
```

### View Test Output

```bash
# Show complete test output
cat regression.out
```

### View Individual Test Results

```bash
# Expected output
cat expected/01_extension_basics.out

# Actual output
cat results/01_extension_basics.out

# Compare
diff expected/01_extension_basics.out results/01_extension_basics.out
```

## Test Environment

### Configuration

Tests use `pg_stat_insights.conf` with recommended settings:

```ini
shared_preload_libraries = 'pg_stat_insights'
pg_stat_insights.max_queries = 10000
pg_stat_insights.track_utility = on
pg_stat_insights.track_planning = on
pg_stat_insights.track_wal = on
pg_stat_insights.track_jit = on
pg_stat_insights.track_replication = on
pg_stat_insights.track_io_timing = on
pg_stat_insights.track_parallel_queries = on
pg_stat_insights.track_minmax_time = on
pg_stat_insights.track_level = 'top'
```

### Database Setup

Tests run in a temporary database:
- Database name: `contrib_regression`
- Automatically created and destroyed
- Isolated from production data

## Writing New Tests

### Test File Structure

```sql
-- ============================================================================
-- Test N: Test Name
-- Description of what this test validates
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test data with deterministic values
SELECT setseed(0.5);  -- For reproducible random values
CREATE TEMP TABLE test_table (
  id serial PRIMARY KEY,
  value numeric,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp  -- Fixed timestamp
);

-- Run test queries (with ORDER BY for deterministic output)
SELECT * FROM test_table ORDER BY id;

-- Validate results
SELECT 
  condition = expected_value AS test_passed
FROM pg_stat_insights
WHERE query LIKE '%test_table%'
ORDER BY queryid;  -- Always order results!
```

### Best Practices

1. **Use ORDER BY** - Ensure deterministic output
2. **Fixed Timestamps** - Avoid `now()` in test data
3. **Deterministic Data** - Use `setseed()` for random values
4. **Clear Test Names** - Descriptive test and assertion names
5. **Wait for Stats** - Use `pg_sleep(0.1)` after queries
6. **Cleanup** - Drop temporary objects when done

### Updating Expected Output

```bash
# Run test to generate new output
make installcheck REGRESS=test_name

# Copy results to expected (if correct)
cp results/test_name.out expected/
```

## Continuous Integration

Tests run automatically in GitHub Actions:
- **PostgreSQL versions**: 14, 15, 16, 17
- **Platforms**: Ubuntu, macOS, Rocky Linux
- **Trigger**: Manual workflow dispatch
- **Artifacts**: Test results retained for 7 days

See [CI/CD Guide](ci-cd.md) for more details.

## Performance Benchmarking

### Test Execution Time

Monitor test performance:

```bash
# Run with timing
make installcheck 2>&1 | grep "ms$"
```

Typical execution times:
- Fast tests: 25-120 ms
- Standard tests: 120-240 ms
- Complex tests: 240-330 ms

### Load Testing

For performance testing under load:

```bash
# Use pgbench with pg_stat_insights
pgbench -i -s 10 testdb
pgbench -T 60 testdb

# View query statistics
SELECT * FROM pg_stat_insights_top_by_time LIMIT 20;
```

## Troubleshooting

### Common Issues

**Test Failure: "could not connect to database"**
```bash
# Ensure PostgreSQL is running
pg_ctl status

# Check port
psql -p 5432 -c "SELECT version();"
```

**Test Failure: "extension does not exist"**
```bash
# Install extension
sudo make install

# Verify installation
psql -c "SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_insights';"
```

**Test Failure: "permission denied"**
```bash
# Set correct permissions
sudo chown -R postgres:postgres /usr/share/postgresql/*/extension/

# Verify
ls -la /usr/share/postgresql/*/extension/pg_stat_insights*
```

**Non-deterministic Output**
- Add ORDER BY to queries
- Use fixed timestamps instead of `now()`
- Use `setseed()` for random data

## Contributing Tests

When contributing new tests:

1. Follow naming convention: `NN_descriptive_name.sql`
2. Add to `Makefile` REGRESS list
3. Generate expected output
4. Test on all supported PostgreSQL versions
5. Document in this file

For detailed contribution guidelines, see [Contributing Guide](contributing.md).

## Resources

- [PostgreSQL Testing Documentation](https://www.postgresql.org/docs/current/regress.html)
- [pg_regress Tool](https://www.postgresql.org/docs/current/regress-run.html)
- [TAP Tests](https://www.postgresql.org/docs/current/regress-tap.html)

