#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Reset functionality tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 5: Reset Functionality\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test data
run_query("CREATE TABLE reset_test (x int);", 1);
run_query("INSERT INTO reset_test VALUES (1), (2), (3);", 1);
run_query("SELECT * FROM reset_test;", 1);

# Test 1: Data exists before reset
run_test("Data exists before reset",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';",
    "t");

# Test 2: Global reset clears all
reset_stats();

run_test("Reset clears all data",
    "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';",
    "0");

# Test 3: Tracking after reset
run_query("SELECT * FROM reset_test;", 1);

run_test("Tracking works after reset",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM reset_test%';",
    "t");

# Test 4: Multiple resets
reset_stats();
reset_stats();
reset_stats();

run_test("Multiple resets work",
    "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';",
    "0");

# Test 5-9: Views work after reset
run_query("SELECT * FROM reset_test;", 1);

my @views = qw(
    pg_stat_insights_top_by_time
    pg_stat_insights_top_by_calls
    pg_stat_insights_top_by_io
    pg_stat_insights_histogram_summary
    pg_stat_insights_by_bucket
);

foreach my $view (@views) {
    run_test("View $view works after reset",
        "SELECT count(*) >= 0 FROM $view;",
        "t");
}

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
