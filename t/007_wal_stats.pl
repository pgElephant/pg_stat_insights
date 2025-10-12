#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# WAL statistics tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 7: WAL Statistics\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test table
run_query("CREATE TABLE wal_test (id int, val text);", 1);

# Test 1: INSERT generates WAL
reset_stats();
run_query("INSERT INTO wal_test VALUES (1, 'data1');", 1);

run_test("INSERT generates WAL records",
    "SELECT wal_records > 0 FROM pg_stat_insights WHERE query LIKE '%INSERT INTO wal_test%';",
    "t");

# Test 2: WAL bytes tracked
run_test("WAL bytes tracked",
    "SELECT wal_bytes > 0 FROM pg_stat_insights WHERE query LIKE '%INSERT INTO wal_test%';",
    "t");

# Test 3: UPDATE generates WAL
reset_stats();
run_query("UPDATE wal_test SET val = 'updated' WHERE id = 1;", 1);

run_test("UPDATE generates WAL",
    "SELECT wal_records > 0 FROM pg_stat_insights WHERE query LIKE '%UPDATE wal_test%';",
    "t");

# Test 4: Multiple operations accumulate WAL
reset_stats();
for (my $i = 2; $i <= 10; $i++) {
    run_query("INSERT INTO wal_test VALUES ($i, 'data$i');", 1);
}

run_test("WAL accumulates",
    "SELECT wal_records >= 9 FROM pg_stat_insights WHERE query LIKE '%INSERT INTO wal_test VALUES%';",
    "t");

# Test 5: WAL FPI tracked
run_test("WAL FPI tracked",
    "SELECT wal_fpi >= 0 FROM pg_stat_insights WHERE query LIKE '%INSERT INTO wal_test%';",
    "t");

# Test 6: SELECT generates no WAL
reset_stats();
run_query("SELECT * FROM wal_test;", 1);

run_test("SELECT generates no WAL",
    "SELECT wal_records FROM pg_stat_insights WHERE query LIKE '%FROM wal_test%';",
    "0");

# Test 7: DELETE generates WAL
reset_stats();
run_query("DELETE FROM wal_test WHERE id = 1;", 1);

run_test("DELETE generates WAL",
    "SELECT wal_records > 0 FROM pg_stat_insights WHERE query LIKE '%DELETE FROM wal_test%';",
    "t");

# Test 8: wal_buffers_full tracked
run_test("wal_buffers_full tracked",
    "SELECT wal_buffers_full >= 0 FROM pg_stat_insights LIMIT 1;",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
