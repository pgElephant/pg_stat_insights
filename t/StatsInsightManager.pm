package StatsInsightManager;

# Copyright (c) 2024-2025, pgElephant, Inc.
# Test helper module for pg_stat_insights

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw(
    setup_test_instance
    cleanup_test_instance
    run_query
    run_test
    get_setting
    reset_stats
    test_view_exists
    test_view_has_data
    get_view_count
    get_metric_value
    execute_times
    verify_column_exists
    print_test_summary
    get_test_summary
    restart_postgres
    execute_query
    execute_query_allow_error
    get_scalar
    get_port
    test_pass
    test_cmp
    $TEST_PORT
    $TEST_PGDATA
    $PG_BIN
    $TESTS_PASSED
    $TESTS_FAILED
    $TOTAL_TESTS
);

our $TEST_PORT = 5580;
our $TEST_PGDATA = "/tmp/pg_stat_insights_test_$$";
our $PG_BIN;

# Test counters
our $TESTS_PASSED = 0;
our $TESTS_FAILED = 0;
our $TOTAL_TESTS = 0;

sub setup_test_instance {
    my %opts = @_;
    my $config = $opts{config} // {};
    
    # Find PostgreSQL binaries
    $PG_BIN = $ENV{PG_BIN} // '/usr/local/pgsql.18/bin';
    $ENV{PATH} = "$PG_BIN:$ENV{PATH}";
    
    # Cleanup any existing instance
    system("pkill -9 postgres 2>/dev/null") if -d $TEST_PGDATA;
    system("rm -rf $TEST_PGDATA 2>/dev/null");
    sleep 1;
    
    # Initialize cluster
    system("$PG_BIN/initdb -D $TEST_PGDATA > /dev/null 2>&1") == 0
        or die "Failed to initialize test cluster\n";
    
    # Create configuration
    open my $conf, '>>', "$TEST_PGDATA/postgresql.conf"
        or die "Cannot open postgresql.conf: $!\n";
    
    print $conf "port = $TEST_PORT\n";
    print $conf "shared_preload_libraries = 'pg_stat_insights'\n";
    
    # Add custom configuration
    foreach my $key (keys %$config) {
        print $conf "$key = $config->{$key}\n";
    }
    
    close $conf;
    
    # Start PostgreSQL
    system("$PG_BIN/pg_ctl -D $TEST_PGDATA -l $TEST_PGDATA/logfile start > /dev/null 2>&1") == 0
        or die "Failed to start PostgreSQL\n";
    
    sleep 2;
    
    # Create extension
    system("$PG_BIN/psql -p $TEST_PORT -d postgres -c 'CREATE EXTENSION pg_stat_insights;' > /dev/null 2>&1") == 0
        or die "Failed to create extension\n";
    
    return 1;
}

sub cleanup_test_instance {
    system("$PG_BIN/pg_ctl -D $TEST_PGDATA stop -m immediate > /dev/null 2>&1");
    system("rm -rf $TEST_PGDATA 2>/dev/null");
    return 1;
}

sub run_query {
    my ($query, $silent) = @_;
    $silent //= 0;
    
    my $redirect = $silent ? '> /dev/null 2>&1' : '';
    my $result = `$PG_BIN/psql -p $TEST_PORT -d postgres -t -c "$query" $redirect`;
    chomp $result;
    $result =~ s/^\s+|\s+$//g;  # Trim whitespace
    return $result;
}

sub reset_stats {
    return run_query("SELECT pg_stat_insights_reset();", 1);
}

sub get_setting {
    my ($param) = @_;
    return run_query("SHOW $param;");
}

sub get_view_count {
    my ($view) = @_;
    return run_query("SELECT count(*) FROM $view;");
}

sub test_view_exists {
    my ($view_name) = @_;
    my $result = run_query("SELECT count(*) FROM pg_views WHERE viewname = '$view_name';");
    return $result eq '1';
}

sub test_view_has_data {
    my ($view_name, $filter) = @_;
    $filter //= '';
    my $where = $filter ? "WHERE $filter" : '';
    my $result = run_query("SELECT count(*) > 0 FROM $view_name $where;");
    return $result eq 't';
}

sub get_metric_value {
    my ($metric, $filter) = @_;
    $filter //= "query LIKE '%test%'";
    return run_query("SELECT $metric FROM pg_stat_insights WHERE $filter LIMIT 1;");
}

sub execute_times {
    my ($query, $times) = @_;
    for (my $i = 0; $i < $times; $i++) {
        run_query($query, 1);
    }
    return 1;
}

sub verify_column_exists {
    my ($table, $column) = @_;
    my $result = run_query(
        "SELECT count(*) FROM information_schema.columns 
         WHERE table_name = '$table' AND column_name = '$column';"
    );
    return $result eq '1';
}

sub run_test {
    my ($test_name, $test_query, $expected) = @_;
    
    $TOTAL_TESTS++;
    my $result = run_query($test_query);
    
    if ($result eq $expected) {
        print "  ✅ Test $TOTAL_TESTS: $test_name\n";
        $TESTS_PASSED++;
        return 1;
    } else {
        print "  ❌ Test $TOTAL_TESTS: $test_name (got: '$result', expected: '$expected')\n";
        $TESTS_FAILED++;
        return 0;
    }
}

sub get_test_summary {
    return {
        total => $TOTAL_TESTS,
        passed => $TESTS_PASSED,
        failed => $TESTS_FAILED,
        success => $TESTS_FAILED == 0
    };
}

sub restart_postgres {
    my $mode = shift // 'fast';
    system("$PG_BIN/pg_ctl -D $TEST_PGDATA restart -m $mode > /dev/null 2>&1") == 0
        or die "Failed to restart PostgreSQL\n";
    sleep 3;
    return 1;
}

sub print_test_summary {
    my $summary = get_test_summary();
    
    print "\n";
    print "════════════════════════════════════════════════════════════\n";
    print "TEST RESULTS\n";
    print "════════════════════════════════════════════════════════════\n";
    print "\n";
    print "Total Tests: $summary->{total}\n";
    print "Passed: $summary->{passed} ✅\n";
    print "Failed: $summary->{failed}\n";
    print "\n";
    
    if ($summary->{success}) {
        print "╔════════════════════════════════════════════════════════════╗\n";
        print "║                                                             ║\n";
        printf "║       ✅ ALL TESTS PASSED (%d/%d)! ✅                     ║\n", 
            $summary->{passed}, $summary->{total};
        print "║                                                             ║\n";
        print "╚════════════════════════════════════════════════════════════╝\n";
    } else {
        print "╔════════════════════════════════════════════════════════════╗\n";
        print "║                                                             ║\n";
        printf "║  ❌ SOME TESTS FAILED (%d/%d failed) ❌                    ║\n",
            $summary->{failed}, $summary->{total};
        print "║                                                             ║\n";
        print "╚════════════════════════════════════════════════════════════╝\n";
    }
    
    return $summary->{success};
}

# Execute SQL query
sub execute_query {
    my ($port, $sql) = @_;
    my $result = run_query($port, $sql);
    return $result;
}

# Execute query that may fail
sub execute_query_allow_error {
    my ($port, $sql) = @_;
    my $result = `psql -p $port -t -A -c "$sql" postgres 2>/dev/null`;
    return $result;
}

# Get scalar value from query
sub get_scalar {
    my ($port, $sql) = @_;
    my $result = run_query($port, $sql);
    $result =~ s/^\s+|\s+$//g if defined $result;
    return $result // '';
}

# Get port
sub get_port {
    return $TEST_PORT;
}

# Test pass helper
sub test_pass {
    my ($message) = @_;
    $TOTAL_TESTS++;
    $TESTS_PASSED++;
    print "ok $TOTAL_TESTS - $message\n";
    return 1;
}

# Test comparison helper
sub test_cmp {
    my ($got, $op, $expected, $message) = @_;
    $TOTAL_TESTS++;
    
    my $result = 0;
    if ($op eq '==') {
        $result = ($got == $expected);
    } elsif ($op eq '!=') {
        $result = ($got != $expected);
    } elsif ($op eq '>') {
        $result = ($got > $expected);
    } elsif ($op eq '>=') {
        $result = ($got >= $expected);
    } elsif ($op eq '<') {
        $result = ($got < $expected);
    } elsif ($op eq '<=') {
        $result = ($got <= $expected);
    } elsif ($op eq 'eq') {
        $result = ($got eq $expected);
    } elsif ($op eq 'ne') {
        $result = ($got ne $expected);
    }
    
    if ($result) {
        $TESTS_PASSED++;
        print "ok $TOTAL_TESTS - $message\n";
    } else {
        $TESTS_FAILED++;
        print "not ok $TOTAL_TESTS - $message\n";
        print "#   got: '$got'\n";
        print "#   expected ($op): '$expected'\n";
    }
    
    return $result;
}

1;

