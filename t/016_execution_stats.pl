#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Execution statistics comprehensive testing

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 16: Execution Statistics (Complete)\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test table
run_query("CREATE TABLE exec_test (id int, val int);", 1);
run_query("INSERT INTO exec_test SELECT i, i*10 FROM generate_series(1, 100) i;", 1);

# Execute same query multiple times to get statistics
reset_stats();
for (my $i = 0; $i < 20; $i++) {
    run_query("SELECT * FROM exec_test WHERE id < 50;", 1);
}

# Test 1: calls counter
run_test("calls = 20",
    "SELECT calls FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "20");

# Test 2: total_exec_time
run_test("total_exec_time > 0",
    "SELECT total_exec_time > 0 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 3: min_exec_time
run_test("min_exec_time >= 0",
    "SELECT min_exec_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 4: max_exec_time
run_test("max_exec_time >= min_exec_time",
    "SELECT max_exec_time >= min_exec_time FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 5: mean_exec_time
run_test("mean_exec_time between min and max",
    "SELECT mean_exec_time >= min_exec_time AND mean_exec_time <= max_exec_time FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 6: stddev_exec_time
run_test("stddev_exec_time >= 0",
    "SELECT stddev_exec_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 7: total_exec_time relationship
run_test("total_exec_time ≈ calls * mean_exec_time",
    "SELECT ABS(total_exec_time - (calls * mean_exec_time)) < 1.0 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 8: rows tracked
run_test("rows tracked",
    "SELECT rows > 0 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 9: rows relationship
run_test("rows = calls * rows_per_call",
    "SELECT rows = calls * 49 FROM pg_stat_insights WHERE query LIKE '%FROM exec_test WHERE%';",
    "t");

# Test 10: Execution stats for different query types
run_query("UPDATE exec_test SET val = val + 1 WHERE id = 1;", 1);

run_test("UPDATE tracked",
    "SELECT calls > 0 AND total_exec_time > 0 FROM pg_stat_insights WHERE query LIKE '%UPDATE exec_test%';",
    "t");

# Test 11: DELETE tracking
run_query("DELETE FROM exec_test WHERE id = 99;", 1);

run_test("DELETE tracked",
    "SELECT calls > 0 AND total_exec_time > 0 FROM pg_stat_insights WHERE query LIKE '%DELETE FROM exec_test%';",
    "t");

# Test 12: INSERT tracking
run_query("INSERT INTO exec_test VALUES (999, 9990);", 1);

run_test("INSERT tracked",
    "SELECT calls > 0 AND total_exec_time > 0 FROM pg_stat_insights WHERE query LIKE '%INSERT INTO exec_test VALUES%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

