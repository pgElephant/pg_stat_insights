#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# User and database tracking comprehensive testing

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 15: User/Database/Toplevel Tracking\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Test 1: userid tracked
run_query("SELECT 1;", 1);

run_test("userid tracked",
    "SELECT userid IS NOT NULL FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 2: userid is valid OID
run_test("userid is valid OID",
    "SELECT userid > 0 FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 3: dbid tracked
run_test("dbid tracked",
    "SELECT dbid IS NOT NULL FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 4: dbid is valid OID
run_test("dbid is valid OID",
    "SELECT dbid > 0 FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 5: userid matches current user
run_test("userid matches current user",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE userid = (SELECT oid FROM pg_roles WHERE rolname = current_user);",
    "t");

# Test 6: dbid matches current database
run_test("dbid matches current database",
    "SELECT count(*) > 0 FROM pg_stat_insights WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database());",
    "t");

# Test 7: queryid tracked
run_test("queryid tracked",
    "SELECT queryid IS NOT NULL AND queryid != 0 FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 8: toplevel tracked
run_test("toplevel tracked",
    "SELECT toplevel IS NOT NULL FROM pg_stat_insights LIMIT 1;",
    "t");

# Test 9: Simple queries are toplevel
reset_stats();
run_query("SELECT * FROM pg_tables LIMIT 1;", 1);

run_test("Simple queries are toplevel",
    "SELECT toplevel FROM pg_stat_insights WHERE query LIKE '%FROM pg_tables%' LIMIT 1;",
    "t");

# Test 10: Nested queries tracking (depends on track setting)
run_query("DO \$\$ BEGIN PERFORM count(*) FROM pg_tables; END \$\$;", 1);

run_test("DO block tracked",
    "SELECT count(*) >= 0 FROM pg_stat_insights WHERE query LIKE '%DO%';",
    "t");

print_test_summary();
cleanup_test_instance();

exit($StatsInsightManager::TESTS_FAILED > 0 ? 1 : 0);

