#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Timestamp tracking comprehensive testing

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 14: Timestamp Columns\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup and execute queries
run_query("CREATE TABLE timestamp_test (x int);", 1);
run_query("INSERT INTO timestamp_test VALUES (1), (2), (3);", 1);
reset_stats();
run_query("SELECT * FROM timestamp_test;", 1);
sleep 1;
run_query("SELECT * FROM timestamp_test;", 1);

# Test 1: stats_since exists and is timestamp
run_test("stats_since is timestamp",
    "SELECT stats_since IS NOT NULL FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;",
    "t");

# Test 2: minmax_stats_since exists and is timestamp
run_test("minmax_stats_since is timestamp",
    "SELECT minmax_stats_since IS NOT NULL FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;",
    "t");

# Test 3: stats_since is in past
run_test("stats_since is in past",
    "SELECT stats_since < now() FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;",
    "t");

# Test 4: minmax_stats_since is in past
run_test("minmax_stats_since is in past",
    "SELECT minmax_stats_since < now() FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;",
    "t");

# Test 5: stats_since <= minmax_stats_since
run_test("Timestamp ordering",
    "SELECT stats_since <= minmax_stats_since FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;",
    "t");

# Test 6: Timestamps update on new queries
my $ts1 = run_query("SELECT minmax_stats_since::text FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;");
sleep 2;
run_query("SELECT * FROM timestamp_test;", 1);
my $ts2 = run_query("SELECT minmax_stats_since::text FROM pg_stat_insights WHERE query LIKE '%FROM timestamp_test%' LIMIT 1;");

run_test("minmax_stats_since updates",
    "SELECT '$ts2' >= '$ts1';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

