-- ============================================================================
-- pg_stat_insights: Performance Benchmark Test
-- ============================================================================
-- Tests overhead and performance impact of pg_stat_insights
-- Run with: psql -f 02_performance_benchmark.sql
-- ============================================================================

\echo '=== PERFORMANCE BENCHMARK ==='
\echo ''

-- Create benchmark table
DROP TABLE IF EXISTS benchmark_table CASCADE;
CREATE TABLE benchmark_table (
    id serial PRIMARY KEY,
    val1 integer,
    val2 integer,
    txt text
);

INSERT INTO benchmark_table (val1, val2, txt)
SELECT 
    random() * 1000,
    random() * 1000,
    md5(random()::text)
FROM generate_series(1, 10000);

CREATE INDEX idx_benchmark_val1 ON benchmark_table(val1);
CREATE INDEX idx_benchmark_val2 ON benchmark_table(val2);

\echo 'Test table created with 10,000 rows'
\echo ''

-- Reset statistics for clean measurement
SELECT pg_stat_insights_reset();

\echo '=== BENCHMARK 1: Simple SELECT ==='
\echo 'Running 1000 simple SELECT queries...'
\timing on
DO $$
BEGIN
    FOR i IN 1..1000 LOOP
        PERFORM count(*) FROM benchmark_table WHERE val1 = i % 1000;
    END LOOP;
END $$;
\timing off

SELECT 
    count(*) as queries_tracked,
    round(avg(total_exec_time)::numeric, 3) as avg_total_ms,
    round(avg(mean_exec_time)::numeric, 3) as avg_mean_ms,
    sum(calls) as total_calls
FROM pg_stat_insights
WHERE query LIKE '%benchmark_table%';

\echo ''
\echo '=== BENCHMARK 2: Complex JOIN ==='
\timing on
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        PERFORM count(*) 
        FROM benchmark_table b1
        JOIN benchmark_table b2 ON b1.val1 = b2.val2
        WHERE b1.id < 1000;
    END LOOP;
END $$;
\timing off

SELECT 
    query,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    round(stddev_exec_time::numeric, 2) as stddev_ms,
    rows
FROM pg_stat_insights
WHERE query LIKE '%JOIN benchmark_table%'
LIMIT 1;

\echo ''
\echo '=== BENCHMARK 3: Aggregation ==='
\timing on
DO $$
BEGIN
    FOR i IN 1..500 LOOP
        PERFORM 
            val1,
            count(*),
            avg(val2),
            max(val2),
            min(val2)
        FROM benchmark_table
        WHERE val1 < 500
        GROUP BY val1;
    END LOOP;
END $$;
\timing off

SELECT 
    query,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_insights
WHERE query LIKE '%GROUP BY val1%'
LIMIT 1;

\echo ''
\echo '=== BENCHMARK 4: Write Operations ==='
\timing on
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO benchmark_table (val1, val2, txt)
        VALUES (i, i * 2, 'test' || i);
    END LOOP;
END $$;
\timing off

SELECT 
    query,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) as wal_size
FROM pg_stat_insights
WHERE query LIKE '%INSERT INTO benchmark_table%'
LIMIT 1;

\echo ''
\echo '=== BENCHMARK 5: UPDATE Operations ==='
\timing on
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        UPDATE benchmark_table 
        SET val2 = val2 + 1 
        WHERE val1 = i % 100;
    END LOOP;
END $$;
\timing off

SELECT 
    query,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    rows as rows_affected,
    wal_records,
    pg_size_pretty(wal_bytes::bigint) as wal_size
FROM pg_stat_insights
WHERE query LIKE '%UPDATE benchmark_table%'
LIMIT 1;

\echo ''
\echo '=== OVERHEAD ANALYSIS ==='
SELECT 
    '--- Per-Query Overhead Analysis ---' as section;

WITH overhead AS (
    SELECT 
        count(*) as total_queries,
        sum(calls) as total_calls,
        round(avg(mean_exec_time)::numeric, 3) as avg_query_time_ms,
        round((avg(mean_exec_time) * 0.002)::numeric, 3) as estimated_overhead_ms,
        round((avg(mean_exec_time) * 0.002 / avg(mean_exec_time) * 100)::numeric, 2) as overhead_percent
    FROM pg_stat_insights
    WHERE query LIKE '%benchmark_table%'
)
SELECT 
    total_queries,
    total_calls,
    avg_query_time_ms,
    estimated_overhead_ms,
    overhead_percent || '%' as overhead_pct,
    CASE 
        WHEN overhead_percent < 1.0 THEN '✅ Excellent (<1%)'
        WHEN overhead_percent < 2.0 THEN '✅ Good (<2%)'
        WHEN overhead_percent < 5.0 THEN '⚠️  Acceptable (<5%)'
        ELSE '❌ High (>5%)'
    END as performance_rating
FROM overhead;

\echo ''
\echo '=== CACHE HIT RATIO ==='
SELECT 
    round(100.0 * sum(shared_blks_hit) / 
        NULLIF(sum(shared_blks_hit + shared_blks_read), 0), 2) as cache_hit_ratio_pct,
    sum(shared_blks_hit) as total_cache_hits,
    sum(shared_blks_read) as total_disk_reads,
    CASE 
        WHEN sum(shared_blks_hit) * 1.0 / NULLIF(sum(shared_blks_hit + shared_blks_read), 0) > 0.99 
        THEN '✅ Excellent (>99%)'
        WHEN sum(shared_blks_hit) * 1.0 / NULLIF(sum(shared_blks_hit + shared_blks_read), 0) > 0.95 
        THEN '✅ Good (>95%)'
        WHEN sum(shared_blks_hit) * 1.0 / NULLIF(sum(shared_blks_hit + shared_blks_read), 0) > 0.90 
        THEN '⚠️  Acceptable (>90%)'
        ELSE '❌ Poor (<90%)'
    END as cache_performance
FROM pg_stat_insights
WHERE query LIKE '%benchmark_table%';

\echo ''
\echo '=== TOP 5 SLOWEST QUERIES ==='
SELECT 
    substring(query, 1, 60) || '...' as query_preview,
    calls,
    round(total_exec_time::numeric, 2) as total_ms,
    round(mean_exec_time::numeric, 2) as mean_ms,
    round(max_exec_time::numeric, 2) as max_ms,
    rows
FROM pg_stat_insights_top_by_time
WHERE query LIKE '%benchmark_table%'
LIMIT 5;

\echo ''
\echo '=== STATISTICS COLLECTION OVERHEAD ==='
SELECT 
    pg_size_pretty(pg_total_relation_size('benchmark_table')) as table_size,
    (SELECT count(*) FROM pg_stat_insights) as tracked_queries,
    (SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%benchmark_table%') as benchmark_queries;

\echo ''
\echo '=== CLEANUP ==='
DROP TABLE IF EXISTS benchmark_table CASCADE;

\echo ''
\echo '============================================================================'
\echo 'Performance Benchmark Complete'
\echo '============================================================================'
\echo 'Key Metrics to Check:'
\echo '  - Overhead should be < 2% for most queries'
\echo '  - Cache hit ratio should be > 95% for good performance'
\echo '  - Mean execution time should be consistent with expected performance'
\echo '============================================================================'

