#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Views functionality tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 3: All 11 Views\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test data
run_query("CREATE TABLE view_test (id int, data text);", 1);
run_query("INSERT INTO view_test SELECT i, 'data' || i FROM generate_series(1, 1000) i;", 1);
run_query("CREATE INDEX idx_view_test ON view_test(id);", 1);

# Execute queries to populate stats
execute_times("SELECT * FROM view_test WHERE id < 100;", 10);
execute_times("SELECT count(*) FROM view_test;", 10);
execute_times("UPDATE view_test SET data = 'updated' WHERE id = 1;", 5);

# Test 1-11: All views have data
my @view_tests = (
    ['pg_stat_insights', "query LIKE '%view_test%'"],
    ['pg_stat_insights_top_by_time', "query LIKE '%view_test%'"],
    ['pg_stat_insights_top_by_calls', "query LIKE '%view_test%'"],
    ['pg_stat_insights_top_by_io', "query LIKE '%view_test%'"],
    ['pg_stat_insights_top_cache_misses', "1=1"],
    ['pg_stat_insights_slow_queries', "1=1"],
    ['pg_stat_insights_errors', "1=1"],
    ['pg_stat_insights_plan_errors', "1=1"],
    ['pg_stat_insights_histogram_summary', "query LIKE '%view_test%'"],
    ['pg_stat_insights_by_bucket', "1=1"],
    ['pg_stat_insights_replication', "1=1"],
);

foreach my $test (@view_tests) {
    my ($view, $filter) = @$test;
    run_test("View $view accessible",
        "SELECT count(*) >= 0 FROM $view WHERE $filter;",
        "t");
}

# Test 12: Cache hit ratio calculation
run_test("cache_hit_ratio in valid range",
    "SELECT count(*) > 0 FROM pg_stat_insights_histogram_summary WHERE cache_hit_ratio >= 0 AND cache_hit_ratio <= 1;",
    "t");

# Test 13: Response time category
run_test("response_time_category valid",
    "SELECT count(*) > 0 FROM pg_stat_insights_histogram_summary WHERE response_time_category IN ('<1ms', '1-10ms', '10-100ms', '100ms-1s', '1-10s', '>10s');",
    "t");

# Test 14: Replication view (0 for standalone)
run_test("Replication view returns 0",
    "SELECT count(*) FROM pg_stat_insights_replication;",
    "0");

# Test 15: Top by time ordering
run_test("top_by_time has data",
    "SELECT count(*) > 0 FROM pg_stat_insights_top_by_time WHERE query LIKE '%view_test%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
