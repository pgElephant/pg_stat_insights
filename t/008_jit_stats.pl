#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# JIT statistics tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 8: JIT Statistics\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance(
    config => {
        'jit' => 'on',
        'jit_above_cost' => '100'
    }
);

# Test 1-10: JIT columns exist
my @jit_columns = qw(
    jit_functions
    jit_generation_time
    jit_inlining_count
    jit_inlining_time
    jit_optimization_count
    jit_optimization_time
    jit_emission_count
    jit_emission_time
    jit_deform_count
    jit_deform_time
);

foreach my $col (@jit_columns) {
    run_test("Column $col exists",
        "SELECT count(*) FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name = '$col';",
        "1");
}

# Test 11: JIT columns accessible
run_query("CREATE TABLE jit_test (id int, val int);", 1);
run_query("INSERT INTO jit_test SELECT i, i*10 FROM generate_series(1, 1000) i;", 1);
run_query("SELECT sum(val) FROM jit_test WHERE id > 100;", 1);

run_test("JIT functions tracked",
    "SELECT jit_functions >= 0 FROM pg_stat_insights WHERE query LIKE '%sum(val) FROM jit_test%' LIMIT 1;",
    "t");

run_test("JIT generation time tracked",
    "SELECT jit_generation_time >= 0 FROM pg_stat_insights WHERE query LIKE '%sum(val) FROM jit_test%' LIMIT 1;",
    "t");

run_test("All JIT columns accessible",
    "SELECT count(*) = 10 FROM information_schema.columns WHERE table_name = 'pg_stat_insights' AND column_name LIKE 'jit_%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);
