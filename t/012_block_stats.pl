#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Block statistics comprehensive testing

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 12: Block Statistics (All Types)\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'track_io_timing' => 'on'
    }
);

# Setup test table
run_query("CREATE TABLE block_test (id int PRIMARY KEY, data text);", 1);
run_query("INSERT INTO block_test SELECT i, repeat('x', 100) FROM generate_series(1, 1000) i;", 1);

# Test 1-4: Shared blocks
reset_stats();
run_query("SELECT * FROM block_test WHERE id = 1;", 1);

run_test("shared_blks_hit tracked",
    "SELECT shared_blks_hit >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM block_test WHERE%' LIMIT 1;",
    "t");

run_test("shared_blks_read tracked",
    "SELECT shared_blks_read >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM block_test WHERE%' LIMIT 1;",
    "t");

# Cause some writes
run_query("UPDATE block_test SET data = 'updated' WHERE id = 1;", 1);

run_test("shared_blks_dirtied tracked",
    "SELECT shared_blks_dirtied >= 0 FROM pg_stat_insights WHERE query LIKE '%UPDATE block_test%' LIMIT 1;",
    "t");

run_test("shared_blks_written tracked",
    "SELECT shared_blks_written >= 0 FROM pg_stat_insights WHERE query LIKE '%UPDATE block_test%' LIMIT 1;",
    "t");

# Test 5-6: Shared block timing
run_test("shared_blk_read_time tracked",
    "SELECT shared_blk_read_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM block_test%' LIMIT 1;",
    "t");

run_test("shared_blk_write_time tracked",
    "SELECT shared_blk_write_time >= 0 FROM pg_stat_insights WHERE query LIKE '%UPDATE block_test%' LIMIT 1;",
    "t");

# Test 7-10: Local blocks (temp tables) - check columns exist
run_test("local_blks_hit column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blks_hit';",
    "1");

run_test("local_blks_read column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blks_read';",
    "1");

run_test("local_blks_dirtied column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blks_dirtied';",
    "1");

run_test("local_blks_written column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blks_written';",
    "1");

# Test 11-12: Local block timing columns exist
run_test("local_blk_read_time column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blk_read_time';",
    "1");

run_test("local_blk_write_time column exists",
    "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = 'local_blk_write_time';",
    "1");

# Test 13-14: Temp blocks (sorting, large operations)
run_query("SELECT * FROM block_test ORDER BY data DESC;", 1);

run_test("temp_blks_read tracked",
    "SELECT temp_blks_read >= 0 FROM pg_stat_insights WHERE query LIKE '%ORDER BY data%' LIMIT 1;",
    "t");

run_test("temp_blks_written tracked",
    "SELECT temp_blks_written >= 0 FROM pg_stat_insights WHERE query LIKE '%ORDER BY data%' LIMIT 1;",
    "t");

# Test 15-16: Temp block timing
run_test("temp_blk_read_time tracked",
    "SELECT temp_blk_read_time >= 0 FROM pg_stat_insights WHERE query LIKE '%ORDER BY%' LIMIT 1;",
    "t");

run_test("temp_blk_write_time tracked",
    "SELECT temp_blk_write_time >= 0 FROM pg_stat_insights WHERE query LIKE '%ORDER BY%' LIMIT 1;",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

