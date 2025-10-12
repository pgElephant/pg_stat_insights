#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Restart persistence tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 10: Restart Persistence\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'pg_stat_insights.save' => 'on'
    }
);

# Test 1: Create data
run_query("CREATE TABLE restart_test (a int);", 1);
run_query("SELECT a FROM restart_test;", 1);

run_test("Data populated before restart",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM restart_test%';",
    "t");

# Save current query count
my $before_count = run_query("SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';");

# Test 2: Restart with save=on preserves data
print "\n  Restarting PostgreSQL (save=on)...\n";
restart_postgres('fast');

run_test("Data preserved after restart (save=on)",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM restart_test%';",
    "t");

# Test 3: Restart with save=off clears data
print "\n  Changing save=off and restarting...\n";
run_query("ALTER SYSTEM SET pg_stat_insights.save = off;", 1);
restart_postgres('fast');

run_test("Data cleared after restart (save=off)",
    "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat_insights%';",
    "0");

# Test 4: Tracking works after restart
run_query("CREATE TABLE after_restart (z int);", 1);
run_query("SELECT * FROM after_restart;", 1);

run_test("Tracking works after restart",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%FROM after_restart%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
