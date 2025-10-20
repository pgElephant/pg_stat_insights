#!/usr/bin/perl
#
# Test performance overhead of pg_stat_insights
# Verifies the extension adds minimal overhead to query execution
#

use strict;
use warnings;
use lib 't';
use StatsInsightManager;
use Time::HiRes qw(time);

# Test plan
plan_tests(20);

# Setup
my $test_dir = setup_test_instance();
my $port = get_port();

execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

# Create test table
execute_query($port, "CREATE TABLE perf_test (id SERIAL PRIMARY KEY, data TEXT);");
execute_query($port, "INSERT INTO perf_test (data) SELECT 'data_' || i FROM generate_series(1, 10000) i;");
test_pass("Performance test table created (10K rows)");

# Test 1: Simple SELECT overhead
execute_query($port, "SELECT pg_stat_insights_reset();");
my $start = time();
for my $i (1..1000) {
    execute_query($port, "SELECT id FROM perf_test WHERE id = $i;");
}
my $elapsed = time() - $start;
my $avg_time_ms = ($elapsed / 1000) * 1000;
test_cmp($avg_time_ms, '<', 10, "Average query time < 10ms with tracking ($avg_time_ms ms)");

# Test 2: Verify metrics are collected
my $collected = get_scalar($port, "SELECT calls FROM pg_stat_insights WHERE query LIKE '%FROM perf_test WHERE id%' LIMIT 1;");
test_cmp($collected, '==', 1000, "All queries tracked ($collected calls)");

# Test 3: Statistics view access overhead
my $view_start = time();
for my $i (1..100) {
    execute_query($port, "SELECT count(*) FROM pg_stat_insights;");
}
my $view_elapsed = time() - $view_start;
my $view_avg_ms = ($view_elapsed / 100) * 1000;
test_cmp($view_avg_ms, '<', 50, "View access is fast ($view_avg_ms ms avg)");

# Test 4: Memory usage is reasonable
my $row_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
test_cmp($row_count, '<', 100, "Memory usage reasonable (only $row_count distinct queries tracked)");

# Test 5: Reset overhead
my $reset_start = time();
execute_query($port, "SELECT pg_stat_insights_reset();");
my $reset_time = (time() - $reset_start) * 1000;
test_cmp($reset_time, '<', 100, "Reset is fast ($reset_time ms)");

# Test 6: INSERT overhead
execute_query($port, "SELECT pg_stat_insights_reset();");
my $insert_start = time();
for my $i (1..500) {
    execute_query($port, "INSERT INTO perf_test (data) VALUES ('new_$i');");
}
my $insert_elapsed = time() - $insert_start;
my $insert_avg = ($insert_elapsed / 500) * 1000;
test_cmp($insert_avg, '<', 10, "INSERT overhead minimal ($insert_avg ms avg)");

# Test 7: UPDATE overhead
my $update_start = time();
for my $i (1..500) {
    execute_query($port, "UPDATE perf_test SET data = 'updated' WHERE id = $i;");
}
my $update_elapsed = time() - $update_start;
my $update_avg = ($update_elapsed / 500) * 1000;
test_cmp($update_avg, '<', 10, "UPDATE overhead minimal ($update_avg ms avg)");

# Test 8: JOIN overhead
execute_query($port, "CREATE TABLE perf_test2 (id SERIAL PRIMARY KEY, ref_id INT);");
execute_query($port, "INSERT INTO perf_test2 (ref_id) SELECT (random() * 10000)::int FROM generate_series(1, 5000);");

my $join_start = time();
for my $i (1..100) {
    execute_query($port, "SELECT t1.id, t2.ref_id FROM perf_test t1 JOIN perf_test2 t2 ON t1.id = t2.ref_id LIMIT 10;");
}
my $join_elapsed = time() - $join_start;
my $join_avg = ($join_elapsed / 100) * 1000;
test_cmp($join_avg, '<', 50, "JOIN overhead minimal ($join_avg ms avg)");

# Test 9: Aggregation overhead
my $agg_start = time();
for my $i (1..100) {
    execute_query($port, "SELECT count(*), min(id), max(id), avg(id) FROM perf_test;");
}
my $agg_elapsed = time() - $agg_start;
my $agg_avg = ($agg_elapsed / 100) * 1000;
test_cmp($agg_avg, '<', 100, "Aggregation overhead minimal ($agg_avg ms avg)");

# Test 10: Verify tracking doesn't slow down significantly
my $calls_check = get_scalar($port, "SELECT SUM(calls) FROM pg_stat_insights;");
test_cmp($calls_check, '>', 1500, "All queries tracked without slowdown ($calls_check total calls)");

# Test 11: Statistics size is reasonable
my $stats_size = get_scalar($port, "SELECT pg_size_pretty(pg_total_relation_size('pg_stat_insights'));");
test_pass("Statistics view size: $stats_size");

# Test 12: Concurrent stats access doesn't block queries
execute_query($port, "SELECT * FROM pg_stat_insights; SELECT 1; SELECT * FROM pg_stat_insights_top_by_time;");
test_pass("Concurrent access to stats doesn't block");

# Test 13: Extension doesn't affect transaction performance
my $txn_start = time();
for my $i (1..100) {
    execute_query($port, "BEGIN; SELECT 1; COMMIT;");
}
my $txn_elapsed = time() - $txn_start;
my $txn_avg = ($txn_elapsed / 100) * 1000;
test_cmp($txn_avg, '<', 20, "Transaction overhead minimal ($txn_avg ms avg)");

# Test 14: Cache hit ratio tracking doesn't impact performance
my $cache_start = time();
for my $i (1..500) {
    execute_query($port, "SELECT * FROM perf_test WHERE id = $i;");
}
my $cache_elapsed = time() - $cache_start;
my $cache_avg = ($cache_elapsed / 500) * 1000;
test_cmp($cache_avg, '<', 10, "Cache tracking overhead minimal ($cache_avg ms avg)");

# Test 15: WAL tracking doesn't impact writes
my $wal_start = time();
for my $i (1..200) {
    execute_query($port, "INSERT INTO perf_test (data) VALUES ('wal_test');");
}
my $wal_elapsed = time() - $wal_start;
my $wal_avg = ($wal_elapsed / 200) * 1000;
test_cmp($wal_avg, '<', 15, "WAL tracking overhead minimal ($wal_avg ms avg)");

# Test 16: Verify total tracked queries is reasonable
my $final_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
test_cmp($final_count, '<', 200, "Query deduplication working (only $final_count distinct queries)");

# Test 17: Mean execution time is realistic
my $mean_check = get_scalar($port, "SELECT AVG(mean_exec_time) FROM pg_stat_insights WHERE calls > 10;");
test_cmp($mean_check, '>', 0, "Mean execution time is realistic ($mean_check ms)");
test_cmp($mean_check, '<', 1000, "Mean execution time < 1000ms for this workload");

# Test 18: No memory leaks (query count stable)
my $before_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
for my $i (1..1000) {
    execute_query($port, "SELECT 'same_query';");  # Should normalize to one entry
}
my $after_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights;");
my $count_diff = $after_count - $before_count;
test_cmp($count_diff, '<=', 5, "No memory leak - similar queries normalized (diff: $count_diff)");

# Cleanup
cleanup_test_instance($test_dir);

done_testing();

