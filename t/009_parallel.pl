#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Parallel query statistics tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 9: Parallel Query Statistics\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'max_parallel_workers_per_gather' => '4',
        'min_parallel_table_scan_size' => "'8kB'"
    }
);

# Test 1-2: Parallel worker columns exist
run_test("Column parallel_workers_to_launch exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'parallel_workers_to_launch';",
    "1");

run_test("Column parallel_workers_launched exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'parallel_workers_launched';",
    "1");

# Test 3: Execute query (may or may not use parallel workers)
run_query("CREATE TABLE parallel_test (id int, val int);", 1);
run_query("INSERT INTO parallel_test SELECT i, i*10 FROM generate_series(1, 10000) i;", 1);
run_query("ANALYZE parallel_test;", 1);

reset_stats();
run_query("SELECT count(*) FROM parallel_test WHERE val > 5000;", 1);

run_test("Parallel stats tracked",
    "SELECT parallel_workers_to_launch >= 0 AND parallel_workers_launched >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM parallel_test%' LIMIT 1;",
    "t");

# Test 4: Query is tracked
run_test("Parallel query tracked",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM parallel_test%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
