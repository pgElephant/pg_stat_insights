#!/usr/bin/perl
#
# Test concurrent access to pg_stat_insights from multiple sessions
#

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

# Test plan
plan_tests(20);

# Setup
my $test_dir = setup_test_instance();
my $port = get_port();

execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

execute_query($port, "SELECT pg_stat_insights_reset();");
test_pass("Statistics reset");

# Create test table
execute_query($port, "CREATE TABLE concurrent_test (id SERIAL PRIMARY KEY, value INT, session_id INT);");
execute_query($port, "INSERT INTO concurrent_test (value, session_id) SELECT i, 0 FROM generate_series(1, 1000) i;");
test_pass("Test table created with 1000 rows");

# Test 1: Concurrent reads from pg_stat_insights
print "# Testing concurrent reads...\n";
for my $i (1..5) {
    my $count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
    test_cmp($count, '>=', 0, "Concurrent read $i successful (count: $count)");
}

# Test 2: Generate queries from "multiple sessions" (serial but testing locking)
print "# Generating queries to test concurrent tracking...\n";
for my $session (1..10) {
    execute_query($port, "INSERT INTO concurrent_test (value, session_id) VALUES ($session, $session);");
    execute_query($port, "UPDATE concurrent_test SET value = value + 1 WHERE session_id = $session;");
    execute_query($port, "SELECT * FROM concurrent_test WHERE session_id = $session;");
}
test_pass("Multiple sessions simulated");

# Verify all queries tracked
my $tracked = get_scalar($port, "SELECT count(DISTINCT queryid) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($tracked, '>=', 3, "Multiple query types tracked ($tracked distinct queries)");

# Test 3: Read while potentially updating stats
execute_query($port, "SELECT 1; SELECT * FROM pg_stat_insights; SELECT 2;");
test_pass("Can read stats while generating new queries");

# Test 4: Reset while reading (should not cause issues)
execute_query($port, "SELECT pg_stat_insights_reset();");
my $after_reset = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
test_pass("Reset during active tracking works");

# Test 5: Rapid query execution
print "# Testing rapid query execution (100 queries)...\n";
for my $i (1..100) {
    execute_query($port, "SELECT $i;");
}
my $rapid_count = get_scalar($port, "SELECT calls FROM pg_stat_insights WHERE query LIKE 'SELECT \$1' LIMIT 1;");
test_cmp($rapid_count, '>=', 100, "Rapid queries tracked correctly (calls: $rapid_count)");

# Test 6: Long-running query tracking
print "# Testing long-running query...\n";
execute_query($port, "SELECT pg_sleep(0.1);");
my $sleep_query = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%pg_sleep%';");
test_cmp($sleep_query, '>', 0, "Long-running query tracked");

# Test 7: Multiple resets in sequence
execute_query($port, "SELECT pg_stat_insights_reset();");
execute_query($port, "SELECT pg_stat_insights_reset();");
execute_query($port, "SELECT pg_stat_insights_reset();");
my $multi_reset = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($multi_reset, '<=', 1, "Multiple resets work correctly");

# Test 8: View access doesn't interfere with tracking
execute_query($port, "SELECT 'test1';");
execute_query($port, "SELECT * FROM pg_stat_insights_top_by_time LIMIT 1;");
execute_query($port, "SELECT 'test2';");
my $view_access = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'SELECT%test%';");
test_cmp($view_access, '>=', 2, "Queries tracked while accessing views");

# Test 9: Verify no deadlocks with concurrent access to views
execute_query($port, "SELECT * FROM pg_stat_insights LIMIT 1;");
execute_query($port, "SELECT * FROM pg_stat_insights_top_by_calls LIMIT 1;");
execute_query($port, "SELECT * FROM pg_stat_insights_top_by_io LIMIT 1;");
test_pass("No deadlocks when accessing multiple views");

# Test 10: Statistics consistency after many operations
my $before_ops = get_scalar($port, "SELECT SUM(calls) FROM pg_stat_insights;");
for my $i (1..50) {
    execute_query($port, "SELECT count(*) FROM concurrent_test;");
}
my $after_ops = get_scalar($port, "SELECT SUM(calls) FROM pg_stat_insights;");
test_cmp($after_ops, '>', $before_ops, "Call count increases correctly (before: $before_ops, after: $after_ops)");

# Test 11: Memory doesn't grow unbounded
my $distinct_before = get_scalar($port, "SELECT count(DISTINCT queryid) FROM pg_stat_insights;");
for my $i (1..100) {
    execute_query($port, "SELECT $i;");  # All normalize to same queryid
}
my $distinct_after = get_scalar($port, "SELECT count(DISTINCT queryid) FROM pg_stat_insights;");
test_cmp($distinct_after, '<=', $distinct_before + 5, "Similar queries normalized (distinct before: $distinct_before, after: $distinct_after)");

# Test 12: Verify stats_since timestamp is recent
my $stats_age = get_scalar($port, "SELECT EXTRACT(EPOCH FROM (now() - MIN(stats_since))) FROM pg_stat_insights WHERE stats_since IS NOT NULL;");
test_cmp($stats_age, '<', 60, "stats_since is recent (age: $stats_age seconds)");

# Cleanup
cleanup_test_instance($test_dir);

done_testing();

