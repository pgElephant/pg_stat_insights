-- ============================================================================
-- Test 22: Query Normalization Edge Cases
-- Tests query normalization and parameterization
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test table
SELECT setseed(0.5);
CREATE TEMP TABLE norm_test (
  id serial PRIMARY KEY,
  name text NOT NULL,
  value numeric NOT NULL,
  status text DEFAULT 'active',
  tags text[],
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert deterministic data
INSERT INTO norm_test (name, value, status, tags)
SELECT 
  'item_' || i,
  (i * 10.5)::numeric,
  CASE (i % 3) WHEN 0 THEN 'active' WHEN 1 THEN 'inactive' ELSE 'pending' END,
  ARRAY['tag' || (i % 10), 'cat' || (i % 5)]
FROM generate_series(1, 300) i;

-- Test queries with different literal values (should normalize to same queryid)
SELECT * FROM norm_test WHERE id = 1;
SELECT * FROM norm_test WHERE id = 2;
SELECT * FROM norm_test WHERE id = 3;
SELECT * FROM norm_test WHERE id = 10;
SELECT * FROM norm_test WHERE id = 50;
SELECT * FROM norm_test WHERE id = 100;

-- Test queries with different string literals
SELECT * FROM norm_test WHERE name = 'item_1';
SELECT * FROM norm_test WHERE name = 'item_2';
SELECT * FROM norm_test WHERE name = 'item_3';
SELECT * FROM norm_test WHERE name = 'item_100';

-- Test queries with different numeric values
SELECT * FROM norm_test WHERE value = 10.5;
SELECT * FROM norm_test WHERE value = 21.0;
SELECT * FROM norm_test WHERE value = 31.5;
SELECT * FROM norm_test WHERE value = 105.0;

-- Test queries with IN clauses
SELECT * FROM norm_test WHERE id IN (1, 2, 3);
SELECT * FROM norm_test WHERE id IN (10, 20, 30);
SELECT * FROM norm_test WHERE id IN (100, 200, 300);

-- Test queries with BETWEEN
SELECT * FROM norm_test WHERE value BETWEEN 10 AND 20;
SELECT * FROM norm_test WHERE value BETWEEN 50 AND 60;
SELECT * FROM norm_test WHERE value BETWEEN 100 AND 200;

-- Test queries with LIKE patterns (should normalize differently)
SELECT * FROM norm_test WHERE name LIKE 'item_1%';
SELECT * FROM norm_test WHERE name LIKE 'item_2%';
SELECT * FROM norm_test WHERE name LIKE 'item_%';

-- Test queries with array operations
SELECT * FROM norm_test WHERE tags @> ARRAY['tag1'];
SELECT * FROM norm_test WHERE tags @> ARRAY['tag2'];
SELECT * FROM norm_test WHERE tags @> ARRAY['tag5'];

-- Test queries with multiple WHERE conditions
SELECT * FROM norm_test WHERE id = 1 AND status = 'active';
SELECT * FROM norm_test WHERE id = 2 AND status = 'inactive';
SELECT * FROM norm_test WHERE id = 3 AND status = 'pending';

-- Test queries with ORDER BY different columns
SELECT * FROM norm_test WHERE value > 100 ORDER BY id LIMIT 10;
SELECT * FROM norm_test WHERE value > 100 ORDER BY name LIMIT 10;
SELECT * FROM norm_test WHERE value > 100 ORDER BY value LIMIT 10;

-- Test queries with different LIMIT values (should normalize to same)
SELECT * FROM norm_test WHERE value > 50 LIMIT 10;
SELECT * FROM norm_test WHERE value > 50 LIMIT 20;
SELECT * FROM norm_test WHERE value > 50 LIMIT 30;

-- Test queries with different OFFSET values
SELECT * FROM norm_test WHERE value > 50 LIMIT 10 OFFSET 0;
SELECT * FROM norm_test WHERE value > 50 LIMIT 10 OFFSET 10;
SELECT * FROM norm_test WHERE value > 50 LIMIT 10 OFFSET 20;

-- Test queries with CASE expressions
SELECT 
  id,
  name,
  CASE WHEN value > 100 THEN 'high' ELSE 'low' END AS category
FROM norm_test
WHERE id = 1;

SELECT 
  id,
  name,
  CASE WHEN value > 200 THEN 'very_high' WHEN value > 100 THEN 'high' ELSE 'low' END AS category
FROM norm_test
WHERE id = 2;

-- Test queries with COALESCE
SELECT id, name, COALESCE(status, 'unknown') AS status_val FROM norm_test WHERE id = 1;
SELECT id, name, COALESCE(status, 'unknown') AS status_val FROM norm_test WHERE id = 2;

-- Test queries with NULLIF
SELECT id, name, NULLIF(status, 'active') AS status_val FROM norm_test WHERE id = 1;
SELECT id, name, NULLIF(status, 'inactive') AS status_val FROM norm_test WHERE id = 2;

-- Test queries with functions
SELECT * FROM norm_test WHERE UPPER(name) = 'ITEM_1';
SELECT * FROM norm_test WHERE UPPER(name) = 'ITEM_2';
SELECT * FROM norm_test WHERE LENGTH(name) = 6;

-- Test queries with date/time functions
SELECT * FROM norm_test WHERE created_at > '2025-10-30'::timestamp;
SELECT * FROM norm_test WHERE created_at > '2025-10-31'::timestamp;
SELECT * FROM norm_test WHERE created_at BETWEEN '2025-10-30'::timestamp AND '2025-11-01'::timestamp;

-- Test queries with aggregate functions (should normalize)
SELECT COUNT(*) FROM norm_test WHERE status = 'active';
SELECT COUNT(*) FROM norm_test WHERE status = 'inactive';
SELECT COUNT(*) FROM norm_test WHERE status = 'pending';

-- Test queries with GROUP BY
SELECT status, COUNT(*) FROM norm_test GROUP BY status;
SELECT status, AVG(value) FROM norm_test GROUP BY status;
SELECT status, SUM(value) FROM norm_test GROUP BY status;

-- Test queries with HAVING
SELECT status, COUNT(*) FROM norm_test GROUP BY status HAVING COUNT(*) > 50;
SELECT status, AVG(value) FROM norm_test GROUP BY status HAVING AVG(value) > 100;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify normalization: queries with same structure but different literals should share queryid
SELECT 
  COUNT(*) AS total_queries,
  COUNT(DISTINCT queryid) AS unique_queryids,
  COUNT(*) - COUNT(DISTINCT queryid) AS normalized_queries
FROM pg_stat_insights
WHERE query LIKE '%norm_test%';

-- Verify that queries with different literal values are normalized
SELECT 
  query LIKE '%WHERE id =%' AS is_normalized_id_query,
  COUNT(*) AS query_count,
  COUNT(DISTINCT queryid) AS unique_ids
FROM pg_stat_insights
WHERE query LIKE '%WHERE id =%' AND query LIKE '%norm_test%'
GROUP BY query LIKE '%WHERE id =%';

-- Verify LIKE queries are normalized separately (pattern differs)
SELECT 
  query LIKE '%LIKE%' AS has_like,
  COUNT(*) AS like_query_count,
  COUNT(DISTINCT queryid) AS unique_like_ids
FROM pg_stat_insights
WHERE query LIKE '%LIKE%' AND query LIKE '%norm_test%'
GROUP BY query LIKE '%LIKE%';

