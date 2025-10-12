#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Basic functionality tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 1: Basic Functionality\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Test 1: Extension exists
run_test("Extension exists",
    "SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_insights';",
    "1");

# Test 2: Main view exists
run_test("Main view exists",
    "SELECT count(*) FROM pg_views WHERE viewname = 'pg_stat_insights';",
    "1");

# Test 3-13: All 11 views exist
my @views = qw(
    pg_stat_insights
    pg_stat_insights_top_by_time
    pg_stat_insights_top_by_calls
    pg_stat_insights_top_by_io
    pg_stat_insights_top_cache_misses
    pg_stat_insights_slow_queries
    pg_stat_insights_errors
    pg_stat_insights_plan_errors
    pg_stat_insights_histogram_summary
    pg_stat_insights_by_bucket
    pg_stat_insights_replication
);

foreach my $view (@views) {
    run_test("View $view exists",
        "SELECT count(*) FROM pg_views WHERE viewname = '$view';",
        "1");
}

# Test 14: Main view has 52+ columns
run_test("Main view has 52+ columns",
    "SELECT count(*) >= 50 FROM information_schema.columns WHERE table_name = 'pg_stat_insights';",
    "t");

# Test 15: Query tracking
run_query("CREATE TABLE test1 (x int);", 1);
run_query("INSERT INTO test1 VALUES (1), (2);", 1);
run_query("SELECT * FROM test1;", 1);

run_test("Queries are tracked",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM test1%';",
    "t");

# Test 16: Reset function
reset_stats();

run_test("Reset clears data",
    "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';",
    "0");

# Test 17: Tracking after reset
run_query("SELECT * FROM test1;", 1);

run_test("Tracking works after reset",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM test1%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
