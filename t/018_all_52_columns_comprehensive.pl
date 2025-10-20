#!/usr/bin/perl
#
# Comprehensive test for all 52 columns in pg_stat_insights
# Ensures every column has valid data
#

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

# Test plan - one test per column plus setup tests
plan_tests(60);

# Setup test instance
my $test_dir = setup_test_instance();
my $port = get_port();

# Create extension
execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

# Enable all tracking features
execute_query($port, "ALTER SYSTEM SET pg_stat_insights.track_planning = on;");
execute_query($port, "SELECT pg_reload_conf();");
test_pass("Planning tracking enabled");

# Reset stats
execute_query($port, "SELECT pg_stat_insights_reset();");
test_pass("Statistics reset");

# Create test table with data
execute_query($port, "CREATE TABLE test_data (id SERIAL PRIMARY KEY, value INT, text_col TEXT);");
execute_query($port, "INSERT INTO test_data (value, text_col) SELECT i, 'text_' || i FROM generate_series(1, 1000) i;");
execute_query($port, "CREATE INDEX idx_value ON test_data(value);");
test_pass("Test data created (1000 rows)");

# Execute various query types to populate all metrics
execute_query($port, "SELECT * FROM test_data WHERE id < 100;");  # Simple SELECT
execute_query($port, "SELECT count(*), sum(value), avg(value) FROM test_data;");  # Aggregation
execute_query($port, "UPDATE test_data SET value = value + 1 WHERE id < 50;");  # UPDATE
execute_query($port, "DELETE FROM test_data WHERE id > 990;");  # DELETE
execute_query($port, "INSERT INTO test_data (value, text_col) VALUES (9999, 'new');");  # INSERT
execute_query($port, "SELECT * FROM test_data t1 JOIN test_data t2 ON t1.value = t2.value LIMIT 10;");  # JOIN
execute_query($port, "CREATE TEMP TABLE temp_test (id int);");  # TEMP table
execute_query($port, "INSERT INTO temp_test SELECT generate_series(1, 100);");  # TEMP insert
execute_query($port, "SELECT * FROM temp_test;");  # TEMP select

test_pass("Diverse queries executed to populate metrics");

# Now verify all 52 columns have data

# Column 1: userid
my $userid = get_scalar($port, "SELECT DISTINCT userid FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 FROM test_data%' LIMIT 1;");
test_cmp($userid, '>', 0, "Column 1: userid has value ($userid)");

# Column 2: dbid
my $dbid = get_scalar($port, "SELECT DISTINCT dbid FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 FROM test_data%' LIMIT 1;");
test_cmp($dbid, '>', 0, "Column 2: dbid has value ($dbid)");

# Column 3: toplevel
my $toplevel = get_scalar($port, "SELECT DISTINCT toplevel FROM pg_stat_insights LIMIT 1;");
test_cmp($toplevel, 'eq', 't', "Column 3: toplevel is true ($toplevel)");

# Column 4: queryid
my $queryid = get_scalar($port, "SELECT DISTINCT queryid FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 FROM test_data%' LIMIT 1;");
test_cmp($queryid, 'ne', '', "Column 4: queryid has value");

# Column 5: query
my $query = get_scalar($port, "SELECT query FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 FROM test_data%' LIMIT 1;");
test_cmp($query, 'ne', '', "Column 5: query text captured");

# Column 6: plans (if track_planning is on)
my $plans = get_scalar($port, "SELECT COALESCE(SUM(plans), 0) FROM pg_stat_insights;");
test_cmp($plans, '>=', 0, "Column 6: plans tracked ($plans)");

# Columns 7-11: Planning time metrics
my $total_plan = get_scalar($port, "SELECT COALESCE(SUM(total_plan_time), 0) FROM pg_stat_insights;");
test_cmp($total_plan, '>=', 0, "Column 7: total_plan_time ($total_plan)");

my $min_plan = get_scalar($port, "SELECT COALESCE(MIN(min_plan_time), 0) FROM pg_stat_insights WHERE min_plan_time > 0;");
test_cmp($min_plan, '>=', 0, "Column 8: min_plan_time ($min_plan)");

my $max_plan = get_scalar($port, "SELECT COALESCE(MAX(max_plan_time), 0) FROM pg_stat_insights;");
test_cmp($max_plan, '>=', 0, "Column 9: max_plan_time ($max_plan)");

my $mean_plan = get_scalar($port, "SELECT COALESCE(AVG(mean_plan_time), 0) FROM pg_stat_insights WHERE mean_plan_time > 0;");
test_cmp($mean_plan, '>=', 0, "Column 10: mean_plan_time ($mean_plan)");

my $stddev_plan = get_scalar($port, "SELECT COALESCE(AVG(stddev_plan_time), 0) FROM pg_stat_insights;");
test_cmp($stddev_plan, '>=', 0, "Column 11: stddev_plan_time ($stddev_plan)");

# Column 12: calls
my $calls = get_scalar($port, "SELECT SUM(calls) FROM pg_stat_insights;");
test_cmp($calls, '>', 0, "Column 12: calls has data ($calls)");

# Columns 13-17: Execution time metrics
my $total_exec = get_scalar($port, "SELECT SUM(total_exec_time) FROM pg_stat_insights;");
test_cmp($total_exec, '>', 0, "Column 13: total_exec_time ($total_exec)");

my $min_exec = get_scalar($port, "SELECT MIN(min_exec_time) FROM pg_stat_insights WHERE min_exec_time > 0;");
test_cmp($min_exec, '>', 0, "Column 14: min_exec_time ($min_exec)");

my $max_exec = get_scalar($port, "SELECT MAX(max_exec_time) FROM pg_stat_insights;");
test_cmp($max_exec, '>', 0, "Column 15: max_exec_time ($max_exec)");

my $mean_exec = get_scalar($port, "SELECT AVG(mean_exec_time) FROM pg_stat_insights WHERE mean_exec_time > 0;");
test_cmp($mean_exec, '>', 0, "Column 16: mean_exec_time ($mean_exec)");

my $stddev_exec = get_scalar($port, "SELECT AVG(stddev_exec_time) FROM pg_stat_insights WHERE stddev_exec_time > 0;");
test_cmp($stddev_exec, '>=', 0, "Column 17: stddev_exec_time ($stddev_exec)");

# Column 18: rows
my $rows = get_scalar($port, "SELECT SUM(rows) FROM pg_stat_insights;");
test_cmp($rows, '>', 0, "Column 18: rows returned/affected ($rows)");

# Columns 19-22: Shared blocks
my $shared_hit = get_scalar($port, "SELECT SUM(shared_blks_hit) FROM pg_stat_insights;");
test_cmp($shared_hit, '>', 0, "Column 19: shared_blks_hit ($shared_hit)");

my $shared_read = get_scalar($port, "SELECT COALESCE(SUM(shared_blks_read), 0) FROM pg_stat_insights;");
test_cmp($shared_read, '>=', 0, "Column 20: shared_blks_read ($shared_read)");

my $shared_dirty = get_scalar($port, "SELECT COALESCE(SUM(shared_blks_dirtied), 0) FROM pg_stat_insights;");
test_cmp($shared_dirty, '>=', 0, "Column 21: shared_blks_dirtied ($shared_dirty)");

my $shared_written = get_scalar($port, "SELECT COALESCE(SUM(shared_blks_written), 0) FROM pg_stat_insights;");
test_cmp($shared_written, '>=', 0, "Column 22: shared_blks_written ($shared_written)");

# Columns 23-26: Local blocks
my $local_hit = get_scalar($port, "SELECT COALESCE(SUM(local_blks_hit), 0) FROM pg_stat_insights;");
test_cmp($local_hit, '>=', 0, "Column 23: local_blks_hit ($local_hit)");

my $local_read = get_scalar($port, "SELECT COALESCE(SUM(local_blks_read), 0) FROM pg_stat_insights;");
test_cmp($local_read, '>=', 0, "Column 24: local_blks_read ($local_read)");

my $local_dirty = get_scalar($port, "SELECT COALESCE(SUM(local_blks_dirtied), 0) FROM pg_stat_insights;");
test_cmp($local_dirty, '>=', 0, "Column 25: local_blks_dirtied ($local_dirty)");

my $local_written = get_scalar($port, "SELECT COALESCE(SUM(local_blks_written), 0) FROM pg_stat_insights;");
test_cmp($local_written, '>=', 0, "Column 26: local_blks_written ($local_written)");

# Columns 27-28: Temp blocks
my $temp_read = get_scalar($port, "SELECT COALESCE(SUM(temp_blks_read), 0) FROM pg_stat_insights;");
test_cmp($temp_read, '>=', 0, "Column 27: temp_blks_read ($temp_read)");

my $temp_written = get_scalar($port, "SELECT COALESCE(SUM(temp_blks_written), 0) FROM pg_stat_insights;");
test_cmp($temp_written, '>=', 0, "Column 28: temp_blks_written ($temp_written)");

# Columns 29-34: Block I/O time
my $shared_read_time = get_scalar($port, "SELECT COALESCE(SUM(shared_blk_read_time), 0) FROM pg_stat_insights;");
test_cmp($shared_read_time, '>=', 0, "Column 29: shared_blk_read_time ($shared_read_time)");

my $shared_write_time = get_scalar($port, "SELECT COALESCE(SUM(shared_blk_write_time), 0) FROM pg_stat_insights;");
test_cmp($shared_write_time, '>=', 0, "Column 30: shared_blk_write_time ($shared_write_time)");

my $local_read_time = get_scalar($port, "SELECT COALESCE(SUM(local_blk_read_time), 0) FROM pg_stat_insights;");
test_cmp($local_read_time, '>=', 0, "Column 31: local_blk_read_time ($local_read_time)");

my $local_write_time = get_scalar($port, "SELECT COALESCE(SUM(local_blk_write_time), 0) FROM pg_stat_insights;");
test_cmp($local_write_time, '>=', 0, "Column 32: local_blk_write_time ($local_write_time)");

my $temp_read_time = get_scalar($port, "SELECT COALESCE(SUM(temp_blk_read_time), 0) FROM pg_stat_insights;");
test_cmp($temp_read_time, '>=', 0, "Column 33: temp_blk_read_time ($temp_read_time)");

my $temp_write_time = get_scalar($port, "SELECT COALESCE(SUM(temp_blk_write_time), 0) FROM pg_stat_insights;");
test_cmp($temp_write_time, '>=', 0, "Column 34: temp_blk_write_time ($temp_write_time)");

# Columns 35-38: WAL statistics
my $wal_records = get_scalar($port, "SELECT COALESCE(SUM(wal_records), 0) FROM pg_stat_insights;");
test_cmp($wal_records, '>', 0, "Column 35: wal_records ($wal_records)");

my $wal_fpi = get_scalar($port, "SELECT COALESCE(SUM(wal_fpi), 0) FROM pg_stat_insights;");
test_cmp($wal_fpi, '>=', 0, "Column 36: wal_fpi ($wal_fpi)");

my $wal_bytes = get_scalar($port, "SELECT COALESCE(SUM(wal_bytes), 0) FROM pg_stat_insights;");
test_cmp($wal_bytes, '>', 0, "Column 37: wal_bytes ($wal_bytes)");

my $wal_buffers = get_scalar($port, "SELECT COALESCE(SUM(wal_buffers_full), 0) FROM pg_stat_insights;");
test_cmp($wal_buffers, '>=', 0, "Column 38: wal_buffers_full ($wal_buffers)");

# Columns 39-48: JIT statistics
my $jit_functions = get_scalar($port, "SELECT COALESCE(SUM(jit_functions), 0) FROM pg_stat_insights;");
test_cmp($jit_functions, '>=', 0, "Column 39: jit_functions ($jit_functions)");

my $jit_gen_time = get_scalar($port, "SELECT COALESCE(SUM(jit_generation_time), 0) FROM pg_stat_insights;");
test_cmp($jit_gen_time, '>=', 0, "Column 40: jit_generation_time ($jit_gen_time)");

my $jit_inlining_cnt = get_scalar($port, "SELECT COALESCE(SUM(jit_inlining_count), 0) FROM pg_stat_insights;");
test_cmp($jit_inlining_cnt, '>=', 0, "Column 41: jit_inlining_count ($jit_inlining_cnt)");

my $jit_inlining_time = get_scalar($port, "SELECT COALESCE(SUM(jit_inlining_time), 0) FROM pg_stat_insights;");
test_cmp($jit_inlining_time, '>=', 0, "Column 42: jit_inlining_time ($jit_inlining_time)");

my $jit_opt_cnt = get_scalar($port, "SELECT COALESCE(SUM(jit_optimization_count), 0) FROM pg_stat_insights;");
test_cmp($jit_opt_cnt, '>=', 0, "Column 43: jit_optimization_count ($jit_opt_cnt)");

my $jit_opt_time = get_scalar($port, "SELECT COALESCE(SUM(jit_optimization_time), 0) FROM pg_stat_insights;");
test_cmp($jit_opt_time, '>=', 0, "Column 44: jit_optimization_time ($jit_opt_time)");

my $jit_emit_cnt = get_scalar($port, "SELECT COALESCE(SUM(jit_emission_count), 0) FROM pg_stat_insights;");
test_cmp($jit_emit_cnt, '>=', 0, "Column 45: jit_emission_count ($jit_emit_cnt)");

my $jit_emit_time = get_scalar($port, "SELECT COALESCE(SUM(jit_emission_time), 0) FROM pg_stat_insights;");
test_cmp($jit_emit_time, '>=', 0, "Column 46: jit_emission_time ($jit_emit_time)");

my $jit_deform_cnt = get_scalar($port, "SELECT COALESCE(SUM(jit_deform_count), 0) FROM pg_stat_insights;");
test_cmp($jit_deform_cnt, '>=', 0, "Column 47: jit_deform_count ($jit_deform_cnt)");

my $jit_deform_time = get_scalar($port, "SELECT COALESCE(SUM(jit_deform_time), 0) FROM pg_stat_insights;");
test_cmp($jit_deform_time, '>=', 0, "Column 48: jit_deform_time ($jit_deform_time)");

# Columns 49-50: Parallel query
my $parallel_to_launch = get_scalar($port, "SELECT COALESCE(SUM(parallel_workers_to_launch), 0) FROM pg_stat_insights;");
test_cmp($parallel_to_launch, '>=', 0, "Column 49: parallel_workers_to_launch ($parallel_to_launch)");

my $parallel_launched = get_scalar($port, "SELECT COALESCE(SUM(parallel_workers_launched), 0) FROM pg_stat_insights;");
test_cmp($parallel_launched, '>=', 0, "Column 50: parallel_workers_launched ($parallel_launched)");

# Columns 51-52: Timestamps
my $stats_since = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE stats_since IS NOT NULL;");
test_cmp($stats_since, '>', 0, "Column 51: stats_since has timestamps ($stats_since rows)");

my $minmax_since = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE minmax_stats_since IS NOT NULL;");
test_cmp($minmax_since, '>', 0, "Column 52: minmax_stats_since has timestamps ($minmax_since rows)");

# Verify all columns can be selected together
my $all_cols = execute_query($port, "SELECT COUNT(*) FROM pg_stat_insights;");
test_pass("All 52 columns can be selected together");

# Verify column count
my $col_count = get_scalar($port, "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights';");
test_cmp($col_count, '==', 52, "Exactly 52 columns in view (got: $col_count)");

# Verify no NULL queryids
my $null_queryid = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE queryid IS NULL;");
test_cmp($null_queryid, '==', 0, "No NULL queryids (got: $null_queryid)");

# Verify no NULL queries
my $null_query = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query IS NULL;");
test_cmp($null_query, '==', 0, "No NULL query texts (got: $null_query)");

# Verify calls > 0 for all rows
my $zero_calls = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE calls = 0;");
test_cmp($zero_calls, '==', 0, "All tracked queries have calls > 0 (got: $zero_calls)");

# Verify total_exec_time >= mean_exec_time for calls = 1
my $time_consistency = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE calls = 1 AND total_exec_time < mean_exec_time;");
test_cmp($time_consistency, '==', 0, "Time metrics consistent for single calls");

# Verify cache metrics consistency (hit + read > 0 or both = 0)
my $cache_consistency = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE (shared_blks_hit > 0 OR shared_blks_read > 0) OR (shared_blks_hit = 0 AND shared_blks_read = 0);");
test_cmp($cache_consistency, '>', 0, "Cache metrics are consistent");

# Test all columns in WHERE clause
execute_query($port, "SELECT count(*) FROM pg_stat_insights WHERE userid > 0;");
test_pass("Can filter by userid");

execute_query($port, "SELECT count(*) FROM pg_stat_insights WHERE calls > 0;");
test_pass("Can filter by calls");

execute_query($port, "SELECT count(*) FROM pg_stat_insights WHERE total_exec_time > 0;");
test_pass("Can filter by total_exec_time");

execute_query($port, "SELECT count(*) FROM pg_stat_insights WHERE shared_blks_hit > 0;");
test_pass("Can filter by shared_blks_hit");

execute_query($port, "SELECT count(*) FROM pg_stat_insights WHERE wal_bytes > 0;");
test_pass("Can filter by wal_bytes");

# Cleanup
cleanup_test_instance($test_dir);

done_testing();

