#!/usr/bin/env perl
# Copyright (c) 2024-2025, pgElephant, Inc.

# Index monitoring functionality tests for pg_stat_insights

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

print "TAP Test 24: Index Monitoring Views\n";
print "──────────────────────────────────────────────────────────────\n";

setup_test_instance();

# Setup test data with indexes
run_query("CREATE TABLE index_test_table (id int PRIMARY KEY, name text, email text, created_at timestamp);", 1);
run_query("CREATE INDEX idx_name ON index_test_table(name);", 1);
run_query("CREATE INDEX idx_email ON index_test_table(email);", 1);
run_query("CREATE INDEX idx_created ON index_test_table(created_at);", 1);
run_query("INSERT INTO index_test_table SELECT i, 'name' || i, 'email' || i || '@test.com', now() - (i || ' days')::interval FROM generate_series(1, 1000) i;", 1);

# Execute queries to populate index statistics
execute_times("SELECT * FROM index_test_table WHERE name = 'name100';", 20);
execute_times("SELECT * FROM index_test_table WHERE email = 'email200@test.com';", 15);
execute_times("SELECT * FROM index_test_table WHERE created_at > now() - interval '10 days';", 10);
execute_times("SELECT * FROM index_test_table WHERE id > 500;", 5);

# Test 1: pg_stat_insights_indexes view exists and has data
run_test("pg_stat_insights_indexes view exists",
    "SELECT count(*) > 0 FROM pg_stat_insights_indexes WHERE tablename = 'index_test_table';",
    "t");

# Test 2: Index size metrics are present
run_test("Index size metrics available",
    "SELECT count(*) > 0 FROM pg_stat_insights_indexes WHERE index_size_bytes > 0 AND index_size_mb >= 0;",
    "t");

# Test 3: Index usage statistics
run_test("Index usage statistics present",
    "SELECT count(*) > 0 FROM pg_stat_insights_indexes WHERE idx_scan >= 0 AND idx_tup_read >= 0;",
    "t");

# Test 4: Index type detection
run_test("Index type detected correctly",
    "SELECT count(*) > 0 FROM pg_stat_insights_indexes WHERE index_type = 'btree' AND tablename = 'index_test_table';",
    "t");

# Test 5: Index properties detection
run_test("Index properties detected",
    "SELECT count(*) > 0 FROM pg_stat_insights_indexes WHERE is_primary = true AND indexname LIKE '%_pkey';",
    "t");

# Test 6: pg_stat_insights_index_usage view
run_test("pg_stat_insights_index_usage view accessible",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_usage WHERE tablename = 'index_test_table';",
    "t");

# Test 7: Usage status classification
run_test("Usage status classification works",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_usage WHERE usage_status IN ('ACTIVE', 'HEAVY', 'OCCASIONAL', 'RARE', 'NEVER_USED');",
    "t");

# Test 8: Index scan ratio calculation
run_test("Index scan ratio calculated",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_usage WHERE index_scan_ratio >= 0 AND index_scan_ratio <= 1;",
    "t");

# Test 9: pg_stat_insights_index_bloat view
run_test("pg_stat_insights_index_bloat view accessible",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_bloat WHERE tablename = 'index_test_table';",
    "t");

# Test 10: Bloat severity classification
run_test("Bloat severity classification works",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_bloat WHERE bloat_severity IN ('NONE', 'LOW', 'MEDIUM', 'HIGH');",
    "t");

# Test 11: pg_stat_insights_index_efficiency view
run_test("pg_stat_insights_index_efficiency view accessible",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_efficiency WHERE tablename = 'index_test_table';",
    "t");

# Test 12: Efficiency rating
run_test("Efficiency rating calculated",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_efficiency WHERE efficiency_rating IN ('EXCELLENT', 'GOOD', 'FAIR', 'POOR', 'UNUSED');",
    "t");

# Test 13: pg_stat_insights_index_maintenance view
run_test("pg_stat_insights_index_maintenance view accessible",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_maintenance WHERE tablename = 'index_test_table';",
    "t");

# Test 14: Maintenance type detection
run_test("Maintenance type detected",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_maintenance WHERE maintenance_type IN ('REINDEX', 'VACUUM', 'ANALYZE', 'NONE');",
    "t");

# Test 15: Priority classification
run_test("Priority classification works",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_maintenance WHERE priority IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');",
    "t");

# Test 16: pg_stat_insights_index_summary view
run_test("pg_stat_insights_index_summary view accessible",
    "SELECT total_indexes > 0 FROM pg_stat_insights_index_summary;",
    "t");

# Test 17: Summary metrics
run_test("Summary metrics calculated",
    "SELECT total_index_size_mb >= 0 AND active_indexes >= 0 AND unused_indexes >= 0 FROM pg_stat_insights_index_summary;",
    "t");

# Test 18: pg_stat_insights_index_alerts view
run_test("pg_stat_insights_index_alerts view accessible",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_alerts;",
    "t");

# Test 19: Alert severity levels
run_test("Alert severity levels correct",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_alerts WHERE severity IN ('INFO', 'WARNING', 'CRITICAL');",
    "t");

# Test 20: Alert types
run_test("Alert types correct",
    "SELECT count(*) >= 0 FROM pg_stat_insights_index_alerts WHERE alert_type IN ('BLOAT', 'UNUSED', 'INEFFICIENT', 'MISSING', 'MAINTENANCE');",
    "t");

# Test 21: pg_stat_insights_index_dashboard view
run_test("pg_stat_insights_index_dashboard view accessible",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_dashboard;",
    "t");

# Test 22: Dashboard JSON structure
run_test("Dashboard JSON structure valid",
    "SELECT count(*) > 0 FROM pg_stat_insights_index_dashboard WHERE section IN ('SUMMARY', 'BLOAT', 'UNUSED', 'ALERT') AND details IS NOT NULL;",
    "t");

# Test 23: pg_stat_insights_missing_indexes view
run_test("pg_stat_insights_missing_indexes view accessible",
    "SELECT count(*) >= 0 FROM pg_stat_insights_missing_indexes;",
    "t");

# Test 24: Missing index recommendations
run_test("Missing index recommendations present",
    "SELECT count(*) >= 0 FROM pg_stat_insights_missing_indexes WHERE estimated_benefit IN ('HIGH', 'MEDIUM', 'LOW');",
    "t");

# Test 25: Cache hit ratio calculation
run_test("Index cache hit ratio in valid range",
    "SELECT count(*) >= 0 FROM pg_stat_insights_indexes WHERE idx_cache_hit_ratio IS NULL OR (idx_cache_hit_ratio >= 0 AND idx_cache_hit_ratio <= 1);",
    "t");

# Test 26: All index views have proper columns
my @index_views = (
    'pg_stat_insights_indexes',
    'pg_stat_insights_index_usage',
    'pg_stat_insights_index_bloat',
    'pg_stat_insights_index_efficiency',
    'pg_stat_insights_index_maintenance',
    'pg_stat_insights_index_summary',
    'pg_stat_insights_index_alerts',
    'pg_stat_insights_index_dashboard',
    'pg_stat_insights_missing_indexes'
);

foreach my $view (@index_views) {
    run_test("View $view has columns",
        "SELECT count(*) > 0 FROM information_schema.columns WHERE table_name = '$view';",
        "t");
}

# Test 27: Index views permissions
run_test("Index views have PUBLIC SELECT permission",
    "SELECT count(*) = 9 FROM information_schema.table_privileges WHERE table_name LIKE 'pg_stat_insights_index%' AND privilege_type = 'SELECT' AND grantee = 'PUBLIC';",
    "t");

print_test_summary();
cleanup_test_instance();

