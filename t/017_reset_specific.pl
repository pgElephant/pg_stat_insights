#!/usr/bin/perl
#
# Test pg_stat_insights_reset(userid, dbid, queryid) - Specific query reset
#

use strict;
use warnings;
use Test::More;
use lib 't';
use StatsInsightManager;

# Test plan
plan tests => 15;

# Setup test instance
my $test_dir = setup_test_instance();
my $port = get_port();

# Create extension
execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

# Reset stats
execute_query($port, "SELECT pg_stat_insights_reset();");
test_pass("Statistics reset");

# Generate test queries with known queryids
execute_query($port, "SELECT 1 as query1;");
execute_query($port, "SELECT 2 as query2;");
execute_query($port, "SELECT 3 as query3;");
execute_query($port, "SELECT count(*) FROM pg_database;");
execute_query($port, "SELECT count(*) FROM pg_namespace;");

# Verify queries tracked
my $initial_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($initial_count, '>', 0, "Queries tracked after execution (got: $initial_count)");

# Get specific query details
my $result = execute_query($port, "SELECT userid, dbid, queryid FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 as query1' LIMIT 1;");
test_pass("Retrieved query details for specific reset");

# Extract values
my ($userid, $dbid, $queryid) = split(/\|/, $result);
$userid =~ s/^\s+|\s+$//g if $userid;
$dbid =~ s/^\s+|\s+$//g if $dbid;
$queryid =~ s/^\s+|\s+$//g if $queryid;

test_cmp($userid, '>', 0, "userid retrieved: $userid");
test_cmp($dbid, '>', 0, "dbid retrieved: $dbid");
test_cmp($queryid, 'ne', '', "queryid retrieved: $queryid");

# Reset specific query
my $reset_result = execute_query($port, "SELECT pg_stat_insights_reset($userid, $dbid, $queryid);");
test_pass("Specific query reset executed");

# Verify that specific query is gone but others remain
my $after_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($after_count, '<', $initial_count, "Query count decreased (before: $initial_count, after: $after_count)");

# Verify the specific query is no longer present
my $specific_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE queryid = $queryid;");
test_cmp($specific_count, '==', 0, "Specific query removed (count: $specific_count)");

# Verify other queries still exist
my $other_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'SELECT \$1 as query%';");
test_cmp($other_count, '>', 0, "Other similar queries still present (count: $other_count)");

# Test reset with invalid values
my $invalid_result = execute_query($port, "SELECT pg_stat_insights_reset(0, 0, 0);");
test_pass("Reset with invalid queryid handles gracefully");

# Test reset non-existent query (should not error)
my $nonexist_result = execute_query($port, "SELECT pg_stat_insights_reset(10, 16384, 999999999);");
test_pass("Reset non-existent query handles gracefully");

# Verify function signature
my $func_check = get_scalar($port, "SELECT count(*) FROM pg_proc WHERE proname = 'pg_stat_insights_reset' AND pronargs = 3;");
test_cmp($func_check, '==', 1, "Reset function with 3 args exists");

# Test that reset all still works
execute_query($port, "SELECT pg_stat_insights_reset();");
my $final_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($final_count, '<=', 1, "Reset all still works (count: $final_count)");

# Cleanup
cleanup_test_instance($test_dir);

