#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Parameter configuration tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 2: Parameter Configuration\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'pg_stat_insights.max' => '5000',
        'pg_stat_insights.track' => "'all'",
        'pg_stat_insights.track_utility' => 'on',
        'pg_stat_insights.track_planning' => 'on',
        'pg_stat_insights.save' => 'on'
    }
);

# Test 1-5: Parameter values
my @params = (
    ['pg_stat_insights.max', '5000'],
    ['pg_stat_insights.track', 'all'],
    ['pg_stat_insights.track_utility', 'on'],
    ['pg_stat_insights.track_planning', 'on'],
    ['pg_stat_insights.save', 'on'],
);

foreach my $param (@params) {
    run_test("Parameter $param->[0] = $param->[1]",
        "SHOW $param->[0];",
        $param->[1]);
}

# Test 6: All 11 parameters exist
run_test("All 11 parameters exist",
    "SELECT count(*) FROM pg_settings WHERE name LIKE 'pg_stat_insights.%';",
    "11");

# Test 7: Utility command tracking
run_query("CREATE TABLE param_test (x int);", 1);

run_test("Utility commands tracked",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE query LIKE '%CREATE TABLE param_test%';",
    "t");

# Test 8: Planning statistics
run_query("INSERT INTO param_test VALUES (1), (2), (3);", 1);
run_query("SELECT * FROM param_test WHERE x = 1;", 1);

run_test("Planning stats tracked",
    "SELECT plans > 0 FROM pg_stat_insights WHERE query LIKE '%FROM param_test WHERE%' LIMIT 1;",
    "t");

# Test 9: Planning time tracked
run_test("Planning time tracked",
    "SELECT total_plan_time >= 0 FROM pg_stat_insights WHERE query LIKE '%FROM param_test WHERE%' LIMIT 1;",
    "t");

# Test 10: Save parameter affects persistence
run_test("Save parameter is on",
    "SHOW pg_stat_insights.save;",
    "on");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
