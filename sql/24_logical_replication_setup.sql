-- Test logical replication setup and monitoring
-- This test creates publications and tests publication monitoring views

-- Test 1: Create a test publication for all tables
CREATE PUBLICATION test_pub_all FOR ALL TABLES;

-- Test 2: Verify publication appears in publications view
SELECT 
    publication_name = 'test_pub_all' AS correct_name,
    scope = 'All tables' AS correct_scope,
    operations LIKE '%INSERT%' AS has_insert,
    operations LIKE '%UPDATE%' AS has_update,
    operations LIKE '%DELETE%' AS has_delete
FROM pg_stat_insights_publications
WHERE publication_name = 'test_pub_all';

-- Test 3: Create a test table for selective publication
CREATE TABLE repl_test_table (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Test 4: Insert test data
INSERT INTO repl_test_table (data) VALUES ('test_data_1'), ('test_data_2'), ('test_data_3');

-- Test 5: Create a publication for specific table
CREATE PUBLICATION test_pub_selective FOR TABLE repl_test_table;

-- Test 6: Verify selective publication
SELECT 
    publication_name = 'test_pub_selective' AS correct_name,
    scope = 'Selected tables' AS correct_scope,
    table_count >= 1 AS has_tables
FROM pg_stat_insights_publications
WHERE publication_name = 'test_pub_selective';

-- Test 7: Create publication with limited operations
CREATE PUBLICATION test_pub_limited FOR TABLE repl_test_table 
WITH (publish = 'insert,update');

-- Test 8: Verify limited operations publication
SELECT 
    publication_name = 'test_pub_limited' AS correct_name,
    operations LIKE '%INSERT%' AS has_insert,
    operations LIKE '%UPDATE%' AS has_update,
    operations NOT LIKE '%DELETE%' AS no_delete,
    operations NOT LIKE '%TRUNCATE%' AS no_truncate
FROM pg_stat_insights_publications
WHERE publication_name = 'test_pub_limited';

-- Test 9: Test publication count
SELECT COUNT(*) >= 3 AS has_multiple_publications
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%';

-- Test 10: Test publications with operations filter
SELECT 
    COUNT(*) FILTER (WHERE operations LIKE '%INSERT%') >= 2 AS multiple_with_insert,
    COUNT(*) FILTER (WHERE operations LIKE '%UPDATE%') >= 2 AS multiple_with_update,
    COUNT(*) FILTER (WHERE operations LIKE '%DELETE%') >= 2 AS multiple_with_delete
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%';

-- Test 11: Verify active_subscribers column (should be 0 since no subscriptions)
SELECT 
    COUNT(*) FILTER (WHERE active_subscribers = 0) = COUNT(*) AS no_active_subscribers
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%';

-- Test 12: Test publication monitoring with table changes
ALTER TABLE repl_test_table ADD COLUMN extra_data TEXT;
INSERT INTO repl_test_table (data, extra_data) VALUES ('test_4', 'extra');

-- Verify data exists
SELECT COUNT(*) >= 4 AS has_test_data
FROM repl_test_table;

-- Test 13: Verify publication still exists after table modification
SELECT 
    COUNT(*) >= 2 AS publications_exist_after_alter
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%' 
  AND (publication_name = 'test_pub_selective' OR publication_name = 'test_pub_limited');

-- Test 14: Drop one publication and verify count decreases
DROP PUBLICATION test_pub_limited;

SELECT COUNT(*) = 2 AS correct_count_after_drop
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%';

-- Test 15: Cleanup
DROP PUBLICATION test_pub_all;
DROP PUBLICATION test_pub_selective;
DROP TABLE repl_test_table;

-- Verify cleanup
SELECT COUNT(*) = 0 AS cleanup_successful
FROM pg_stat_insights_publications
WHERE publication_name LIKE 'test_pub%';

