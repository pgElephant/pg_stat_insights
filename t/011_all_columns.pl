#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Comprehensive test for ALL 52 columns in pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 11: All 52 Columns Coverage\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'pg_stat_insights.track_planning' => 'on',
        'track_io_timing' => 'on'
    }
);

# Test all 52 columns exist
my @all_columns = qw(
    userid dbid toplevel queryid query
    plans total_plan_time min_plan_time max_plan_time mean_plan_time stddev_plan_time
    calls total_exec_time min_exec_time max_exec_time mean_exec_time stddev_exec_time
    rows
    shared_blks_hit shared_blks_read shared_blks_dirtied shared_blks_written
    local_blks_hit local_blks_read local_blks_dirtied local_blks_written
    temp_blks_read temp_blks_written
    shared_blk_read_time shared_blk_write_time
    local_blk_read_time local_blk_write_time
    temp_blk_read_time temp_blk_write_time
    wal_records wal_fpi wal_bytes wal_buffers_full
    jit_functions jit_generation_time jit_inlining_count jit_inlining_time
    jit_optimization_count jit_optimization_time jit_emission_count jit_emission_time
    jit_deform_count jit_deform_time
    parallel_workers_to_launch parallel_workers_launched
    stats_since minmax_stats_since
);

# Test 1: All 52 columns exist
foreach my $col (@all_columns) {
    run_test("Column $col exists",
        "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = '$col';",
        "1");
}

# Test 53: Total column count
run_test("Total 52 columns",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights';",
    "52");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

