-- ============================================================================
-- Test 19: Triggers and Stored Functions
-- Tests tracking of triggers and function executions
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test tables
SELECT setseed(0.5);
CREATE TEMP TABLE trigger_test (
  id serial PRIMARY KEY,
  name text NOT NULL,
  value numeric NOT NULL,
  updated_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp,
  update_count int DEFAULT 0
);

CREATE TEMP TABLE audit_log (
  id serial PRIMARY KEY,
  table_name text,
  operation text,
  record_id int,
  old_value text,
  new_value text,
  changed_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Create stored functions
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_counter()
RETURNS TRIGGER AS $$
BEGIN
  NEW.update_count := OLD.update_count + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log (table_name, operation, record_id, new_value)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(NEW)::text);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log (table_name, operation, record_id, old_value, new_value)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(OLD)::text, row_to_json(NEW)::text);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_log (table_name, operation, record_id, old_value)
    VALUES (TG_TABLE_NAME, TG_OP, OLD.id, row_to_json(OLD)::text);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create function for computed values
CREATE OR REPLACE FUNCTION compute_total(id_val int)
RETURNS numeric AS $$
DECLARE
  total_val numeric;
BEGIN
  SELECT SUM(value) INTO total_val
  FROM trigger_test
  WHERE id <= id_val;
  RETURN COALESCE(total_val, 0);
END;
$$ LANGUAGE plpgsql;

-- Create function with exception handling
CREATE OR REPLACE FUNCTION safe_divide(a numeric, b numeric)
RETURNS numeric AS $$
BEGIN
  IF b = 0 THEN
    RETURN NULL;
  END IF;
  RETURN a / b;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_timestamp_trigger
  BEFORE UPDATE ON trigger_test
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER increment_counter_trigger
  BEFORE UPDATE ON trigger_test
  FOR EACH ROW
  EXECUTE FUNCTION increment_counter();

CREATE TRIGGER audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON trigger_test
  FOR EACH ROW
  EXECUTE FUNCTION audit_trigger_func();

-- Insert initial data
INSERT INTO trigger_test (name, value)
SELECT 
  'item_' || i,
  (i * 10.5)::numeric
FROM generate_series(1, 200) i;

-- Test INSERT with trigger execution
INSERT INTO trigger_test (name, value) VALUES ('new_item_1', 100.0);
INSERT INTO trigger_test (name, value) VALUES ('new_item_2', 200.0);
INSERT INTO trigger_test (name, value) VALUES ('new_item_3', 300.0);

-- Test UPDATE with trigger execution
UPDATE trigger_test SET value = value * 1.1 WHERE id <= 10;
UPDATE trigger_test SET value = value + 50 WHERE id BETWEEN 11 AND 20;
UPDATE trigger_test SET name = 'updated_' || id WHERE id BETWEEN 21 AND 30;

-- Test DELETE with trigger execution
DELETE FROM trigger_test WHERE id > 190;

-- Test function calls
SELECT compute_total(10) AS total_10;
SELECT compute_total(50) AS total_50;
SELECT compute_total(100) AS total_100;

-- Test function calls in SELECT
SELECT id, name, value, compute_total(id) AS running_total
FROM trigger_test
WHERE id <= 20
ORDER BY id;

-- Test function in WHERE clause
SELECT id, name, value
FROM trigger_test
WHERE value > compute_total(5)
ORDER BY id
LIMIT 15;

-- Test safe_divide function
SELECT 
  id,
  value,
  safe_divide(value, 10) AS divided_by_10,
  safe_divide(value, 0) AS divide_by_zero
FROM trigger_test
WHERE id <= 10
ORDER BY id;

-- Test function with multiple parameters
CREATE OR REPLACE FUNCTION multiply_add(a numeric, b numeric, c numeric)
RETURNS numeric AS $$
BEGIN
  RETURN (a * b) + c;
END;
$$ LANGUAGE plpgsql;

SELECT 
  id,
  value,
  multiply_add(value, 2, 100) AS computed
FROM trigger_test
WHERE id <= 10
ORDER BY id;

-- Test function in aggregate
SELECT 
  COUNT(*) AS count_items,
  AVG(compute_total(id)) AS avg_total
FROM trigger_test
WHERE id <= 50;

-- Test recursive function
CREATE OR REPLACE FUNCTION factorial(n int)
RETURNS bigint AS $$
BEGIN
  IF n <= 1 THEN
    RETURN 1;
  ELSE
    RETURN n * factorial(n - 1);
  END IF;
END;
$$ LANGUAGE plpgsql;

SELECT factorial(5) AS fact_5;
SELECT factorial(10) AS fact_10;

-- Test function in JOIN
CREATE TEMP TABLE function_results AS
SELECT id, compute_total(id) AS total_value
FROM trigger_test
WHERE id <= 10;

SELECT 
  t.id,
  t.name,
  t.value,
  f.total_value
FROM trigger_test t
JOIN function_results f ON t.id = f.id
ORDER BY t.id;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify trigger and function executions are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%trigger_test%') AS table_queries,
  COUNT(*) FILTER (WHERE query LIKE '%compute_total%' OR query LIKE '%factorial%' OR query LIKE '%multiply_add%' OR query LIKE '%safe_divide%') AS function_calls,
  COUNT(*) FILTER (WHERE query LIKE '%INSERT%' OR query LIKE '%UPDATE%' OR query LIKE '%DELETE%') AS dml_operations
FROM pg_stat_insights
WHERE query LIKE '%trigger_test%' OR query LIKE '%compute_total%' OR query LIKE '%factorial%';

-- Verify function execution metrics
SELECT 
  calls >= 1 AS has_executions,
  total_exec_time >= 0 AS has_execution_time,
  rows >= 0 AS returned_rows
FROM pg_stat_insights
WHERE query LIKE '%compute_total%' OR query LIKE '%factorial%'
LIMIT 1;

-- Verify audit log was populated by triggers
SELECT 
  COUNT(*) > 0 AS audit_records_created,
  COUNT(*) FILTER (WHERE operation = 'INSERT') AS insert_audits,
  COUNT(*) FILTER (WHERE operation = 'UPDATE') AS update_audits,
  COUNT(*) FILTER (WHERE operation = 'DELETE') AS delete_audits
FROM audit_log;

