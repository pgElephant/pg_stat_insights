#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Metrics collection tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 4: Metrics Collection\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'pg_stat_insights.track_planning' => 'on'
    }
);

# Setup test table
run_query("CREATE TABLE metrics_test (id int PRIMARY KEY, val int);", 1);
run_query("INSERT INTO metrics_test SELECT i, i*10 FROM generate_series(1, 100) i;", 1);

# Test 1: Execution time tracked
reset_stats();
run_query("SELECT * FROM metrics_test WHERE id = 1;", 1);

run_test("Execution time tracked",
    "SELECT total_exec_time > 0 FROM pg_stat_insights WHERE query LIKE '%FROM metrics_test WHERE%' LIMIT 1;",
    "t");

# Test 2: Call count tracked
run_test("Call count tracked",
    "SELECT calls > 0 FROM pg_stat_insights WHERE query LIKE '%FROM metrics_test WHERE%' LIMIT 1;",
    "t");

# Test 3: Row statistics
reset_stats();
run_query("SELECT * FROM metrics_test LIMIT 10;", 1);

run_test("Row count tracked",
    "SELECT rows > 0 FROM pg_stat_insights WHERE query LIKE '%FROM metrics_test LIMIT%';",
    "t");

# Test 4: Planning statistics
run_test("Planning count tracked",
    "SELECT plans > 0 FROM pg_stat_insights WHERE query LIKE '%FROM metrics_test%' LIMIT 1;",
    "t");

# Test 5: Buffer statistics
run_test("Buffer stats tracked",
    "SELECT (shared_blks_hit + shared_blks_read) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM metrics_test%' LIMIT 1;",
    "t");

# Test 6: Multiple calls increment
reset_stats();
execute_times("SELECT count(*) FROM metrics_test;", 5);

run_test("Calls increment correctly",
    "SELECT calls FROM pg_stat_insights WHERE query LIKE '%count(*) FROM metrics_test%';",
    "5");

# Test 7: Mean execution time
run_test("Mean time calculated",
    "SELECT mean_exec_time > 0 AND mean_exec_time >= min_exec_time AND mean_exec_time <= max_exec_time FROM pg_stat_insights WHERE calls > 1 LIMIT 1;",
    "t");

# Test 8: Standard deviation
run_test("Standard deviation tracked",
    "SELECT stddev_exec_time >= 0 FROM pg_stat_insights WHERE calls > 1 LIMIT 1;",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
