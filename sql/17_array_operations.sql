-- ============================================================================
-- Test 17: Array Operations
-- Tests tracking of array queries and operations
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test table with array columns
SELECT setseed(0.5);
CREATE TEMP TABLE array_test (
  id serial PRIMARY KEY,
  int_array int[],
  text_array text[],
  numeric_array numeric[],
  jsonb_array jsonb[],
  multi_dim_array int[][],
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert deterministic array data
INSERT INTO array_test (int_array, text_array, numeric_array, jsonb_array, multi_dim_array)
SELECT 
  ARRAY[1 + i, 2 + i, 3 + i, 4 + i, 5 + i],
  ARRAY['item_' || i, 'value_' || i, 'tag_' || (i % 10)],
  ARRAY[(i * 1.1)::numeric, (i * 2.2)::numeric, (i * 3.3)::numeric],
  ARRAY[
    jsonb_build_object('id', i, 'val', i * 2),
    jsonb_build_object('id', i + 1, 'val', (i + 1) * 2)
  ],
  ARRAY[[i, i+1], [i+2, i+3]]
FROM generate_series(1, 300) i;

-- Create GIN indexes for arrays
CREATE INDEX idx_array_int ON array_test USING GIN (int_array);
CREATE INDEX idx_array_text ON array_test USING GIN (text_array);

-- Test array element access
SELECT id, int_array[1] AS first_element, int_array[array_length(int_array, 1)] AS last_element
FROM array_test
WHERE int_array[1] > 50
ORDER BY id
LIMIT 20;

-- Test array contains (@>)
SELECT id, int_array
FROM array_test
WHERE int_array @> ARRAY[10, 11]
ORDER BY id
LIMIT 15;

-- Test array overlap (&&)
SELECT id, int_array
FROM array_test
WHERE int_array && ARRAY[5, 10, 15, 20]
ORDER BY id
LIMIT 25;

-- Test array length
SELECT id, array_length(int_array, 1) AS arr_length
FROM array_test
WHERE array_length(int_array, 1) > 4
ORDER BY id
LIMIT 30;

-- Test array append (||)
SELECT id, int_array || 999 AS appended_array
FROM array_test
WHERE id <= 10
ORDER BY id;

-- Test array concatenation
SELECT id, int_array || ARRAY[100, 200, 300] AS concatenated
FROM array_test
WHERE id <= 15
ORDER BY id;

-- Test unnest arrays
SELECT id, unnest(int_array) AS array_value
FROM array_test
WHERE id <= 5
ORDER BY id, array_value;

-- Test array_agg aggregation
SELECT 
  id % 10 AS group_id,
  array_agg(int_array[1] ORDER BY int_array[1]) AS aggregated_values
FROM array_test
GROUP BY id % 10
ORDER BY group_id;

-- Test array functions
SELECT 
  id,
  array_dims(int_array) AS dimensions,
  array_lower(int_array, 1) AS lower_bound,
  array_upper(int_array, 1) AS upper_bound
FROM array_test
WHERE id <= 10
ORDER BY id;

-- Test array_remove
SELECT id, array_remove(int_array, 5) AS removed_array
FROM array_test
WHERE 5 = ANY(int_array)
ORDER BY id
LIMIT 20;

-- Test array_replace
SELECT id, array_replace(int_array, 10, 999) AS replaced_array
FROM array_test
WHERE 10 = ANY(int_array)
ORDER BY id
LIMIT 15;

-- Test array_position
SELECT id, array_position(int_array, 50) AS position_of_50
FROM array_test
WHERE 50 = ANY(int_array)
ORDER BY id
LIMIT 10;

-- Test array_positions
SELECT id, array_positions(int_array, 25) AS positions_of_25
FROM array_test
WHERE 25 = ANY(int_array)
ORDER BY id
LIMIT 10;

-- Test ANY and ALL operators
SELECT id, int_array
FROM array_test
WHERE 100 = ANY(int_array)
ORDER BY id
LIMIT 20;

SELECT id, int_array
FROM array_test
WHERE 1000 = ALL(int_array)
ORDER BY id
LIMIT 5;

-- Test text array operations
SELECT id, text_array
FROM array_test
WHERE text_array @> ARRAY['item_50', 'value_50']
ORDER BY id
LIMIT 10;

-- Test numeric array operations
SELECT 
  id,
  numeric_array[1] + numeric_array[2] AS sum_first_two
FROM array_test
WHERE array_length(numeric_array, 1) >= 2
ORDER BY id
LIMIT 25;

-- Test jsonb array operations
SELECT 
  id,
  jsonb_array[1]->>'id' AS first_jsonb_id
FROM array_test
WHERE array_length(jsonb_array, 1) > 0
ORDER BY id
LIMIT 20;

-- Test multidimensional arrays
SELECT 
  id,
  multi_dim_array[1][1] AS first_dim_first,
  multi_dim_array[1][2] AS first_dim_second,
  array_dims(multi_dim_array) AS dims
FROM array_test
WHERE id <= 10
ORDER BY id;

-- Test array slicing
SELECT 
  id,
  int_array[1:3] AS first_three,
  int_array[2:4] AS middle_slice
FROM array_test
WHERE array_length(int_array, 1) >= 4
ORDER BY id
LIMIT 15;

-- Test array_to_string
SELECT 
  id,
  array_to_string(text_array, ' | ') AS joined_text
FROM array_test
WHERE id <= 10
ORDER BY id;

-- Test string_to_array
SELECT 
  id,
  string_to_array(array_to_string(text_array, ','), ',') AS split_text
FROM array_test
WHERE id <= 5
ORDER BY id;

-- Test array comparison operators
SELECT id, int_array
FROM array_test
WHERE int_array < ARRAY[100, 101, 102, 103, 104]
ORDER BY id
LIMIT 20;

SELECT id, int_array
FROM array_test
WHERE int_array > ARRAY[1, 2, 3, 4, 5]
ORDER BY id
LIMIT 15;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify array operations are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%array%' OR query LIKE '%ARRAY%') AS array_queries,
  COUNT(*) FILTER (WHERE query LIKE '%@>%' OR query LIKE '%&&%' OR query LIKE '%ANY%') AS array_operators,
  COUNT(*) FILTER (WHERE query LIKE '%unnest%' OR query LIKE '%array_%') AS array_functions
FROM pg_stat_insights
WHERE query LIKE '%array_test%';

-- Verify array query metrics
SELECT 
  calls >= 1 AS has_executions,
  rows > 0 AS returned_rows,
  total_exec_time > 0 AS has_execution_time
FROM pg_stat_insights
WHERE query LIKE '%array_test%' AND calls > 0
LIMIT 1;

