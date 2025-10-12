#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Planning statistics comprehensive testing

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 13: Planning Statistics (All Metrics)\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'pg_stat_insights.track_planning' => 'on'
    }
);

# Setup test table
run_query("CREATE TABLE plan_test (id int PRIMARY KEY, val int, data text);", 1);
run_query("INSERT INTO plan_test SELECT i, i*10, 'data' || i FROM generate_series(1, 1000) i;", 1);
run_query("CREATE INDEX idx_val ON plan_test(val);", 1);
run_query("ANALYZE plan_test;", 1);

# Execute queries to generate planning stats
reset_stats();
for (my $i = 0; $i < 10; $i++) {
    run_query("SELECT * FROM plan_test WHERE val = 100;", 1);
}

# Test 1: plans counter
run_test("plans counter tracked",
    "SELECT plans > 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 2: total_plan_time
run_test("total_plan_time tracked",
    "SELECT total_plan_time > 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 3: min_plan_time
run_test("min_plan_time tracked",
    "SELECT min_plan_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 4: max_plan_time
run_test("max_plan_time tracked",
    "SELECT max_plan_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 5: mean_plan_time
run_test("mean_plan_time tracked",
    "SELECT mean_plan_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 6: stddev_plan_time
run_test("stddev_plan_time tracked",
    "SELECT stddev_plan_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 7: Planning stats relationships
run_test("Planning stats consistent",
    "SELECT mean_plan_time >= min_plan_time AND mean_plan_time <= max_plan_time FROM pg_stat_insights WHERE plans > 1 LIMIT 1;",
    "t");

# Test 8: Plans match calls
run_test("Plans counted correctly",
    "SELECT plans = calls FROM pg_stat_insights WHERE query LIKE '%FROM plan_test WHERE val%' LIMIT 1;",
    "t");

# Test 9: Total plan time = plans * mean
run_test("Total plan time calculation",
    "SELECT ABS(total_plan_time - (plans * mean_plan_time)) < 0.1 FROM pg_stat_insights WHERE plans > 1 LIMIT 1;",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

