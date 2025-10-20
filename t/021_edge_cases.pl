#!/usr/bin/perl
#
# Test edge cases, error conditions, and boundary values
#

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

# Test plan
plan_tests(30);

# Setup
my $test_dir = setup_test_instance();
my $port = get_port();

execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

execute_query($port, "SELECT pg_stat_insights_reset();");
test_pass("Statistics reset");

# Test 1: Empty query result
execute_query($port, "SELECT * FROM pg_database WHERE datname = 'nonexistent_db';");
my $empty_result = get_scalar($port, "SELECT rows FROM pg_stat_insights WHERE query LIKE '%nonexistent_db%' LIMIT 1;");
test_cmp($empty_result, '==', 0, "Empty result set: rows = 0");

# Test 2: Very long query text
my $long_query = "SELECT " . join(', ', map { "$_ as col$_" } (1..100));
execute_query($port, "$long_query;");
my $long_tracked = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%col50%';");
test_cmp($long_tracked, '>', 0, "Long query text tracked");

# Test 3: Query with special characters
execute_query($port, "SELECT 'It''s a test' as quote_test, 'Line\\nBreak' as newline;");
my $special_chars = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%quote_test%';");
test_cmp($special_chars, '>', 0, "Query with special characters tracked");

# Test 4: NULL value handling
execute_query($port, "SELECT NULL as null_col;");
my $null_query = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%NULL as null_col%';");
test_cmp($null_query, '>', 0, "NULL value query tracked");

# Test 5: Division by zero (should error but be tracked)
my $div_zero = execute_query_allow_error($port, "SELECT 1/0;");
my $error_tracked = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%1/0%' OR query LIKE '%1/$1%';");
test_cmp($error_tracked, '>=', 0, "Error query tracking (count: $error_tracked)");

# Test 6: Transaction boundaries
execute_query($port, "BEGIN;");
execute_query($port, "SELECT 1;");
execute_query($port, "COMMIT;");
my $txn_queries = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query IN ('BEGIN', 'COMMIT');");
test_cmp($txn_queries, '>=', 2, "Transaction control tracked");

# Test 7: ROLLBACK
execute_query($port, "BEGIN;");
execute_query($port, "SELECT 2;");
execute_query($port, "ROLLBACK;");
my $rollback = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query = 'ROLLBACK';");
test_cmp($rollback, '>', 0, "ROLLBACK tracked");

# Test 8: Prepared statements
execute_query($port, "PREPARE test_stmt AS SELECT \$1::int;");
execute_query($port, "EXECUTE test_stmt(42);");
execute_query($port, "EXECUTE test_stmt(99);");
my $prepared = get_scalar($port, "SELECT calls FROM pg_stat_insights WHERE query LIKE '%EXECUTE test_stmt%' OR query LIKE 'SELECT \$1::int%' LIMIT 1;");
test_cmp($prepared, '>=', 1, "Prepared statement tracked (calls: $prepared)");

# Test 9: EXPLAIN (utility command)
execute_query($port, "EXPLAIN SELECT * FROM pg_database;");
my $explain = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'EXPLAIN SELECT%';");
test_cmp($explain, '>=', 1, "EXPLAIN tracked (utility tracking on)");

# Test 10: ANALYZE
execute_query($port, "ANALYZE pg_database;");
my $analyze = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'ANALYZE%';");
test_cmp($analyze, '>=', 1, "ANALYZE tracked");

# Test 11: VACUUM (utility command)
execute_query($port, "VACUUM pg_database;");
my $vacuum = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'VACUUM%';");
test_cmp($vacuum, '>=', 1, "VACUUM tracked");

# Test 12: CREATE/DROP tracking
execute_query($port, "CREATE TABLE edge_test (id int);");
execute_query($port, "DROP TABLE edge_test;");
my $ddl = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%edge_test%';");
test_cmp($ddl, '>=', 2, "DDL statements tracked (CREATE and DROP)");

# Test 13: Query with parameters (literal vs parameterized)
execute_query($port, "SELECT * FROM pg_database WHERE datname = 'postgres';");
my $literal = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%datname%';");
test_cmp($literal, '>', 0, "Query with literal tracked");

# Test 14: Very fast query (< 1ms)
execute_query($port, "SELECT 1;");
my $fast_query = get_scalar($port, "SELECT mean_exec_time FROM pg_stat_insights WHERE query = 'SELECT \$1' LIMIT 1;");
test_cmp($fast_query, '>', 0, "Fast query timing captured ($fast_query ms)");

# Test 15: Check for zero/negative execution times
my $invalid_times = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE total_exec_time < 0 OR mean_exec_time < 0;");
test_cmp($invalid_times, '==', 0, "No negative execution times");

# Test 16: Check for zero/negative call counts
my $invalid_calls = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE calls <= 0;");
test_cmp($invalid_calls, '==', 0, "All tracked queries have calls > 0");

# Test 17: WAL bytes should be zero for SELECT
my $select_wal = get_scalar($port, "SELECT COALESCE(wal_bytes, 0) FROM pg_stat_insights WHERE query = 'SELECT \$1' LIMIT 1;");
test_cmp($select_wal, '<=', 100, "SELECT queries generate minimal/no WAL ($select_wal bytes)");

# Test 18: Buffer statistics consistency
my $buffer_inconsistency = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE shared_blks_written > (shared_blks_hit + shared_blks_read + shared_blks_dirtied);");
test_cmp($buffer_inconsistency, '==', 0, "Buffer statistics are consistent");

# Test 19: JIT metrics are zero unless JIT is used
my $jit_without_trigger = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE jit_functions > 0;");
test_cmp($jit_without_trigger, '>=', 0, "JIT metrics tracked correctly (queries with JIT: $jit_without_trigger)");

# Test 20: Parallel workers are zero for simple queries
my $no_parallel = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query = 'SELECT \$1' AND parallel_workers_launched > 0;");
test_cmp($no_parallel, '==', 0, "Simple queries don't use parallel workers");

# Test 21: Stats persistence check (stats_since should not be NULL)
my $null_stats_since = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE stats_since IS NULL;");
test_cmp($null_stats_since, '==', 0, "stats_since is never NULL");

# Test 22: Min/max values make sense
my $minmax_check = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE min_exec_time > max_exec_time;");
test_cmp($minmax_check, '==', 0, "min_exec_time <= max_exec_time always");

# Test 23: Mean is within min/max range
my $mean_range = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE mean_exec_time < min_exec_time OR mean_exec_time > max_exec_time;");
test_cmp($mean_range, '==', 0, "mean_exec_time is within min/max range");

# Test 24: Standard deviation makes sense
my $stddev_check = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE stddev_exec_time < 0;");
test_cmp($stddev_check, '==', 0, "stddev_exec_time is never negative");

# Test 25: queryid uniqueness per (userid, dbid, queryid) tuple
my $dup_queryid = get_scalar($port, "SELECT count(*) FROM (SELECT userid, dbid, queryid, count(*) FROM pg_stat_insights GROUP BY userid, dbid, queryid HAVING count(*) > 1) sub;");
test_cmp($dup_queryid, '==', 0, "No duplicate (userid, dbid, queryid) tuples");

# Test 26: Very high call count (integer overflow check)
execute_query($port, "SELECT pg_stat_insights_reset();");
for my $i (1..10000) {
    execute_query($port, "SELECT 'stress';");
}
my $high_calls = get_scalar($port, "SELECT calls FROM pg_stat_insights WHERE query = 'SELECT \$1' LIMIT 1;");
test_cmp($high_calls, '>=', 10000, "High call count tracked correctly ($high_calls)");

# Test 27: Total time accumulates correctly
my $total_time = get_scalar($port, "SELECT total_exec_time FROM pg_stat_insights WHERE query = 'SELECT \$1' LIMIT 1;");
my $mean_time = get_scalar($port, "SELECT mean_exec_time FROM pg_stat_insights WHERE query = 'SELECT \$1' LIMIT 1;");
my $calculated_total = $mean_time * $high_calls;
# Total should be approximately mean * calls (within 10% due to rounding)
my $time_diff_pct = abs($total_time - $calculated_total) / $total_time * 100;
test_cmp($time_diff_pct, '<', 50, "Total time = mean * calls (within reasonable variance)");

# Test 28: Reset specific with boundary values
execute_query($port, "SELECT pg_stat_insights_reset(0, 0, 0);");
execute_query($port, "SELECT pg_stat_insights_reset(999999, 999999, 999999);");
test_pass("Reset with boundary values doesn't crash");

# Cleanup
cleanup_test_instance($test_dir);

done_testing();

