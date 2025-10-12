#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Cache statistics tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 6: Cache Statistics\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test table
run_query("CREATE TABLE cache_test (id int PRIMARY KEY, data text);", 1);
run_query("INSERT INTO cache_test SELECT i, 'data' || i FROM generate_series(1, 1000) i;", 1);

# Test 1: Initial query causes buffer access
reset_stats();
run_query("SELECT * FROM cache_test WHERE id = 1;", 1);

run_test("Buffer access tracked",
    "SELECT (shared_blks_hit + shared_blks_read) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM cache_test WHERE%';",
    "t");

# Test 2: Subsequent queries have cache hits
execute_times("SELECT * FROM cache_test WHERE id = 1;", 5);

run_test("Cache hits tracked",
    "SELECT shared_blks_hit > 0 FROM pg_stat_insights WHERE query LIKE '%FROM cache_test WHERE%';",
    "t");

# Test 3: top_cache_misses view accessible
run_test("top_cache_misses view accessible",
    "SELECT count(*) >= 0 FROM pg_stat_insights_top_cache_misses;",
    "t");

# Test 4: cache_hit_ratio calculated
run_test("cache_hit_ratio in valid range",
    "SELECT count(*) > 0 FROM pg_stat_insights_histogram_summary WHERE cache_hit_ratio >= 0 AND cache_hit_ratio <= 1;",
    "t");

# Test 5: Local buffer stats accessible
run_query("CREATE TEMP TABLE temp_cache (x int);", 1);
run_query("INSERT INTO temp_cache VALUES (1), (2), (3);", 1);
run_query("SELECT * FROM temp_cache;", 1);

run_test("Local buffer columns exist",
    "SELECT count(*) = 4 FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name LIKE 'local_blks_%';",
    "t");

# Test 6: Shared blocks tracked for regular tables
run_test("Shared blocks tracked",
    "SELECT (shared_blks_hit + shared_blks_read) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM cache_test%' LIMIT 1;",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
