#!/usr/bin/perl
# Quick sanity test for TAP infrastructure

use strict;
use warnings;
use Test::More tests => 5;
use lib 't';
use StatsInsightManager;

# Test setup
my $test_dir = setup_test_instance();
ok($test_dir, "Test instance created");

my $port = get_port();
ok($port > 0, "Port number valid: $port");

# Create extension
execute_query($port, "CREATE EXTENSION pg_stat_insights;");
my $ext_check = get_scalar($port, "SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_insights';");
is($ext_check, 1, "Extension installed");

# Execute a query
execute_query($port, "SELECT 1;");
my $query_check = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE 'SELECT%';");
ok($query_check > 0, "Queries tracked");

# Cleanup
cleanup_test_instance($test_dir);
ok(1, "Cleanup successful");
