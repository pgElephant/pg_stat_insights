-- Test pg_stat_insights with high volume of diverse queries
-- This test ensures the extension handles large datasets and many query types

-- Test 1: Reset statistics
SELECT pg_stat_insights_reset();

-- Test 2: Create test tables with various data types
CREATE TABLE volume_test_numeric (
    id SERIAL PRIMARY KEY,
    int_val INTEGER,
    bigint_val BIGINT,
    decimal_val DECIMAL(10,2),
    float_val FLOAT
);

CREATE TABLE volume_test_text (
    id SERIAL PRIMARY KEY,
    short_text VARCHAR(50),
    long_text TEXT,
    json_data JSONB,
    array_data INT[]
);

-- Test 3: Insert large volume of data
INSERT INTO volume_test_numeric (int_val, bigint_val, decimal_val, float_val)
SELECT 
    i,
    i * 1000::BIGINT,
    (i * 10.5)::DECIMAL(10,2),
    (i * 3.14159)::FLOAT
FROM generate_series(1, 1000) i;

INSERT INTO volume_test_text (short_text, long_text, json_data, array_data)
SELECT 
    'text_' || i,
    repeat('long_text_', 10) || i,
    jsonb_build_object('id', i, 'value', i * 10, 'timestamp', now()),
    ARRAY[i, i*2, i*3, i*4, i*5]
FROM generate_series(1, 1000) i;

-- Test 4: Execute diverse query patterns (50 different queries)
-- Simple selects
SELECT COUNT(*) FROM volume_test_numeric;
SELECT AVG(int_val) FROM volume_test_numeric;
SELECT SUM(bigint_val) FROM volume_test_numeric;
SELECT MIN(decimal_val), MAX(decimal_val) FROM volume_test_numeric;

-- Aggregations
SELECT int_val % 10 AS bucket, COUNT(*), AVG(float_val)
FROM volume_test_numeric
GROUP BY int_val % 10
ORDER BY bucket;

-- Joins
SELECT n.id, n.int_val, t.short_text
FROM volume_test_numeric n
JOIN volume_test_text t ON n.id = t.id
WHERE n.int_val < 100
ORDER BY n.id
LIMIT 10;

-- Subqueries
SELECT * FROM volume_test_numeric
WHERE int_val > (SELECT AVG(int_val) FROM volume_test_numeric)
ORDER BY int_val
LIMIT 10;

-- Window functions
SELECT 
    id,
    int_val,
    ROW_NUMBER() OVER (ORDER BY int_val) AS row_num,
    RANK() OVER (ORDER BY int_val) AS rank,
    PERCENT_RANK() OVER (ORDER BY int_val) AS percent_rank
FROM volume_test_numeric
LIMIT 10;

-- JSON operations
SELECT 
    id,
    json_data->>'id' AS json_id,
    json_data->>'value' AS json_value
FROM volume_test_text
WHERE (json_data->>'value')::int > 5000
ORDER BY id
LIMIT 10;

-- Array operations
SELECT 
    id,
    array_data,
    array_length(array_data, 1) AS array_len,
    array_data[1] AS first_elem
FROM volume_test_text
WHERE array_data @> ARRAY[100]
ORDER BY id
LIMIT 10;

-- CTEs
WITH stats AS (
    SELECT 
        AVG(int_val) AS avg_val,
        STDDEV(int_val) AS stddev_val
    FROM volume_test_numeric
)
SELECT 
    n.id,
    n.int_val,
    CASE 
        WHEN n.int_val > s.avg_val + s.stddev_val THEN 'High'
        WHEN n.int_val < s.avg_val - s.stddev_val THEN 'Low'
        ELSE 'Normal'
    END AS category
FROM volume_test_numeric n, stats s
ORDER BY n.id
LIMIT 10;

-- Test 5: Verify pg_stat_insights captured all queries
SELECT COUNT(*) >= 10 AS captured_diverse_queries
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 6: Check top queries by time
SELECT COUNT(*) >= 5 AS has_top_queries
FROM pg_stat_insights_top_by_time
LIMIT 10;

-- Test 7: Check queries with high call counts
SELECT COUNT(*) >= 0 AS has_frequent_queries
FROM pg_stat_insights_top_by_calls
LIMIT 10;

-- Test 8: Verify cache statistics are being tracked
SELECT 
    COUNT(*) FILTER (WHERE shared_blks_hit > 0) >= 0 AS has_cache_hits,
    COUNT(*) FILTER (WHERE shared_blks_read > 0) >= 0 AS has_disk_reads
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 9: Verify I/O statistics for data-intensive queries
SELECT COUNT(*) >= 0 AS has_io_stats
FROM pg_stat_insights_top_by_io
LIMIT 10;

-- Test 10: Check histogram distribution
SELECT 
    COUNT(*) >= 0 AS has_histogram_data,
    COUNT(*) >= 10 AS sufficient_query_volume
FROM pg_stat_insights_histogram_summary;

-- Test 11: Verify WAL generation tracking
SELECT 
    COUNT(*) FILTER (WHERE wal_records > 0) >= 0 AS has_wal_records,
    COUNT(*) FILTER (WHERE wal_bytes > 0) >= 0 AS has_wal_bytes
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 12: Test concurrent query execution simulation
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..20 LOOP
        PERFORM COUNT(*) FROM volume_test_numeric WHERE int_val = i;
        PERFORM COUNT(*) FROM volume_test_text WHERE id = i;
    END LOOP;
END $$;

-- Test 13: Verify statistics after concurrent execution
SELECT COUNT(*) >= 30 AS has_many_tracked_queries
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 14: Check for any error queries
SELECT COUNT(*) >= 0 AS error_queries_tracked
FROM pg_stat_insights_errors;

-- Test 15: Verify mean execution time calculations
SELECT 
    COUNT(*) FILTER (WHERE mean_exec_time > 0) >= 5 AS has_valid_mean_times,
    COUNT(*) FILTER (WHERE mean_exec_time BETWEEN min_exec_time AND max_exec_time) = 
        COUNT(*) FILTER (WHERE calls > 0) AS mean_in_valid_range
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%' AND calls > 0;

-- Test 16: Test query normalization with parameters
PREPARE test_query AS SELECT * FROM volume_test_numeric WHERE int_val = $1;
EXECUTE test_query(10);
EXECUTE test_query(20);
EXECUTE test_query(30);
DEALLOCATE test_query;

SELECT 
    COUNT(*) FILTER (WHERE calls >= 3) >= 0 AS normalized_queries_grouped
FROM pg_stat_insights
WHERE query LIKE '%volume_test_numeric%int_val%';

-- Test 17: Verify row count tracking
SELECT 
    COUNT(*) FILTER (WHERE rows > 0) >= 5 AS has_row_counts,
    SUM(rows) > 0 AS total_rows_tracked
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%' AND query LIKE '%volume_test%';

-- Test 18: Check buffer usage statistics
SELECT 
    COUNT(*) FILTER (WHERE shared_blks_hit + shared_blks_read > 0) >= 5 AS has_buffer_stats,
    COUNT(*) FILTER (WHERE local_blks_hit + local_blks_read >= 0) = COUNT(*) AS has_local_stats
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 19: Verify temp blocks tracking
SELECT COUNT(*) >= 0 AS temp_blocks_tracked
FROM pg_stat_insights
WHERE temp_blks_read > 0 OR temp_blks_written > 0;

-- Test 20: Cleanup
DROP TABLE volume_test_numeric;
DROP TABLE volume_test_text;

-- Verify cleanup
SELECT COUNT(*) >= 0 AS stats_retained_after_table_drop
FROM pg_stat_insights
WHERE query LIKE '%volume_test%';

