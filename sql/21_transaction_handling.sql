-- ============================================================================
-- Test 21: Transaction Handling
-- Tests tracking of queries within transactions, rollbacks, and commits
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test table
SELECT setseed(0.5);
CREATE TEMP TABLE transaction_test (
  id serial PRIMARY KEY,
  name text NOT NULL,
  value numeric NOT NULL,
  status text DEFAULT 'active',
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert initial data
INSERT INTO transaction_test (name, value)
SELECT 
  'item_' || i,
  (i * 10.5)::numeric
FROM generate_series(1, 100) i;

-- Test successful transaction (COMMIT)
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('txn_item_1', 100.0);
INSERT INTO transaction_test (name, value) VALUES ('txn_item_2', 200.0);
UPDATE transaction_test SET value = value * 1.1 WHERE id = 1;
SELECT COUNT(*) FROM transaction_test WHERE name LIKE 'txn_%';
COMMIT;

-- Test rolled back transaction
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('rollback_item_1', 300.0);
INSERT INTO transaction_test (name, value) VALUES ('rollback_item_2', 400.0);
UPDATE transaction_test SET value = value * 1.2 WHERE id = 2;
SELECT COUNT(*) FROM transaction_test WHERE name LIKE 'rollback_%';
ROLLBACK;

-- Verify rollback worked
SELECT COUNT(*) AS rollback_count FROM transaction_test WHERE name LIKE 'rollback_%';

-- Test nested savepoints
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('savepoint_item_1', 500.0);
SAVEPOINT sp1;
INSERT INTO transaction_test (name, value) VALUES ('savepoint_item_2', 600.0);
UPDATE transaction_test SET value = value * 1.3 WHERE id = 3;
ROLLBACK TO SAVEPOINT sp1;
INSERT INTO transaction_test (name, value) VALUES ('savepoint_item_3', 700.0);
COMMIT;

-- Test multiple operations in transaction
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('multi_op_1', 800.0);
UPDATE transaction_test SET status = 'updated' WHERE id = 10;
DELETE FROM transaction_test WHERE id = 99;
SELECT * FROM transaction_test WHERE id IN (10, 99, (SELECT MAX(id) FROM transaction_test));
COMMIT;

-- Test read-only transaction
BEGIN READ ONLY;
SELECT COUNT(*) FROM transaction_test;
SELECT AVG(value) FROM transaction_test;
SELECT SUM(value) FROM transaction_test WHERE status = 'active';
COMMIT;

-- Test transaction with multiple SELECTs
BEGIN;
SELECT COUNT(*) FROM transaction_test WHERE value > 500;
SELECT AVG(value) FROM transaction_test WHERE value > 500;
SELECT MAX(value) FROM transaction_test WHERE value > 500;
SELECT MIN(value) FROM transaction_test WHERE value > 500;
COMMIT;

-- Test transaction isolation - multiple concurrent-like operations
BEGIN;
UPDATE transaction_test SET value = value + 10 WHERE id <= 10;
SELECT SUM(value) FROM transaction_test WHERE id <= 10;
UPDATE transaction_test SET value = value - 5 WHERE id <= 10;
SELECT SUM(value) FROM transaction_test WHERE id <= 10;
COMMIT;

-- Test transaction with function calls
CREATE OR REPLACE FUNCTION tx_test_func(val numeric)
RETURNS numeric AS $$
BEGIN
  RETURN val * 1.5;
END;
$$ LANGUAGE plpgsql;

BEGIN;
SELECT tx_test_func(value) FROM transaction_test WHERE id = 5;
UPDATE transaction_test SET value = tx_test_func(value) WHERE id = 5;
SELECT value FROM transaction_test WHERE id = 5;
COMMIT;

-- Test transaction with error handling
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('error_test', 999.0);
-- This should succeed
UPDATE transaction_test SET value = value * 2 WHERE id = (SELECT MAX(id) FROM transaction_test);
-- This might cause issues but we continue
SELECT COUNT(*) FROM transaction_test;
COMMIT;

-- Test large transaction (many operations)
BEGIN;
INSERT INTO transaction_test (name, value)
SELECT 'batch_' || i, (i * 5.5)::numeric
FROM generate_series(1, 50) i;
UPDATE transaction_test SET status = 'batch' WHERE name LIKE 'batch_%';
SELECT COUNT(*) FROM transaction_test WHERE name LIKE 'batch_%';
COMMIT;

-- Test transaction rollback with multiple operations
BEGIN;
INSERT INTO transaction_test (name, value) VALUES ('rb_multi_1', 1000.0);
INSERT INTO transaction_test (name, value) VALUES ('rb_multi_2', 1100.0);
UPDATE transaction_test SET value = 9999.0 WHERE name LIKE 'rb_multi_%';
DELETE FROM transaction_test WHERE name = 'rb_multi_1';
ROLLBACK;

-- Verify rollback worked
SELECT COUNT(*) AS rb_count FROM transaction_test WHERE name LIKE 'rb_multi_%';

-- Test transaction with joins
BEGIN;
CREATE TEMP TABLE txn_temp AS
SELECT id, name, value FROM transaction_test WHERE id <= 10;

SELECT 
  t1.id,
  t1.name,
  t1.value,
  t2.value AS other_value
FROM transaction_test t1
JOIN txn_temp t2 ON t1.id = t2.id
ORDER BY t1.id;

DROP TABLE txn_temp;
COMMIT;

-- Test deferred constraints (if applicable)
ALTER TABLE transaction_test ADD CONSTRAINT check_value_positive CHECK (value > 0);

BEGIN;
-- These should succeed
INSERT INTO transaction_test (name, value) VALUES ('deferred_1', 100.0);
INSERT INTO transaction_test (name, value) VALUES ('deferred_2', 200.0);
COMMIT;

-- Test transaction with subtransactions (DO block)
DO $$
BEGIN
  INSERT INTO transaction_test (name, value) VALUES ('do_block_1', 300.0);
  INSERT INTO transaction_test (name, value) VALUES ('do_block_2', 400.0);
  UPDATE transaction_test SET status = 'do_block' WHERE name LIKE 'do_block_%';
END $$;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify transaction queries are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%transaction_test%') AS transaction_queries,
  COUNT(*) FILTER (WHERE query LIKE '%BEGIN%' OR query LIKE '%COMMIT%' OR query LIKE '%ROLLBACK%') AS transaction_commands,
  COUNT(*) FILTER (WHERE query LIKE '%INSERT%' OR query LIKE '%UPDATE%' OR query LIKE '%DELETE%') AS dml_in_transactions
FROM pg_stat_insights
WHERE query LIKE '%transaction_test%';

-- Verify transaction metrics (note: BEGIN/COMMIT/ROLLBACK are utility commands)
SELECT 
  calls >= 1 AS has_executions,
  total_exec_time >= 0 AS has_execution_time,
  rows >= 0 AS returned_rows
FROM pg_stat_insights
WHERE query LIKE '%transaction_test%' AND calls > 0
LIMIT 1;

-- Verify that rolled-back transactions are tracked (the queries themselves)
SELECT 
  COUNT(*) > 0 AS rolled_back_queries_tracked
FROM pg_stat_insights
WHERE query LIKE '%rollback%' OR query LIKE '%rb_multi%';

