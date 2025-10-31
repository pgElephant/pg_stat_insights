-- ============================================================================
-- Test 14: Prepared Statements and Query Plans
-- Tests prepared statement tracking and plan caching
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test table
SELECT setseed(0.5);
CREATE TEMP TABLE prep_test (
  id serial PRIMARY KEY,
  name text NOT NULL,
  value numeric NOT NULL,
  status text DEFAULT 'active',
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert deterministic data
INSERT INTO prep_test (name, value, status)
SELECT 
  'item_' || (i % 100),
  (i * 2.5)::numeric,
  CASE (i % 3) WHEN 0 THEN 'active' WHEN 1 THEN 'inactive' ELSE 'pending' END
FROM generate_series(1, 500) i;

-- Create indexes
CREATE INDEX idx_prep_name ON prep_test(name);
CREATE INDEX idx_prep_status ON prep_test(status);

-- Test prepared statements (using DEALLOCATE to force re-planning)
PREPARE prep_select AS SELECT * FROM prep_test WHERE id = $1;
PREPARE prep_update AS UPDATE prep_test SET value = $2 WHERE id = $1;
PREPARE prep_insert AS INSERT INTO prep_test (name, value) VALUES ($1, $2);
PREPARE prep_delete AS DELETE FROM prep_test WHERE id = $1;

-- Execute prepared statements multiple times
EXECUTE prep_select(1);
EXECUTE prep_select(2);
EXECUTE prep_select(3);
EXECUTE prep_select(10);
EXECUTE prep_select(50);

EXECUTE prep_update(1, 999.99);
EXECUTE prep_update(2, 888.88);
EXECUTE prep_update(3, 777.77);

EXECUTE prep_insert('new_item_1', 100.5);
EXECUTE prep_insert('new_item_2', 200.5);
EXECUTE prep_insert('new_item_3', 300.5);

EXECUTE prep_delete(501);
EXECUTE prep_delete(502);
EXECUTE prep_delete(503);

-- Test PREPARE with different parameter types
PREPARE prep_numeric AS SELECT * FROM prep_test WHERE value BETWEEN $1 AND $2;
PREPARE prep_text AS SELECT * FROM prep_test WHERE name LIKE $1;
PREPARE prep_multi AS SELECT * FROM prep_test WHERE id = $1 AND status = $2;

EXECUTE prep_numeric(100, 500);
EXECUTE prep_numeric(200, 600);
EXECUTE prep_numeric(50, 150);

EXECUTE prep_text('item_%');
EXECUTE prep_text('item_5%');
EXECUTE prep_text('item_10%');

EXECUTE prep_multi(1, 'active');
EXECUTE prep_multi(2, 'inactive');
EXECUTE prep_multi(3, 'pending');

-- Wait for stats to be collected
SELECT pg_sleep(0.2);

-- Verify prepared statements are tracked correctly
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%prep_test%') AS queries_tracked,
  COUNT(*) FILTER (WHERE plans > 1) AS queries_with_multiple_plans,
  COUNT(*) FILTER (WHERE calls >= 2) AS queries_called_multiple_times
FROM pg_stat_insights
WHERE query LIKE '%prep_test%';

-- Verify plan vs execution tracking
SELECT 
  plans >= 1 AS has_plan_count,
  calls >= 1 AS has_exec_count,
  mean_plan_time >= 0 AS plan_time_valid,
  mean_exec_time >= 0 AS exec_time_valid
FROM pg_stat_insights
WHERE query LIKE '%prep_test%' AND plans > 0
LIMIT 1;

-- Test DEALLOCATE - should cause re-planning
DEALLOCATE prep_select;
PREPARE prep_select AS SELECT * FROM prep_test WHERE id = $1;
EXECUTE prep_select(100);
EXECUTE prep_select(200);

-- Wait for stats
SELECT pg_sleep(0.1);

-- Verify that plan count increased after DEALLOCATE
SELECT 
  plans > 1 AS plan_count_increased,
  calls >= 2 AS exec_count_consistent
FROM pg_stat_insights
WHERE query LIKE '%prep_test%' AND query LIKE '%id =%'
LIMIT 1;

-- Test with EXPLAIN (timing may vary, so we just verify it runs)
-- EXPLAIN (ANALYZE, BUFFERS) EXECUTE prep_select(5);  -- Commented out due to non-deterministic timing

-- Cleanup
DEALLOCATE ALL;

