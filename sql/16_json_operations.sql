-- ============================================================================
-- Test 16: JSON and JSONB Operations
-- Tests tracking of JSON/JSONB queries and operations
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test table with JSON/JSONB columns
SELECT setseed(0.5);
CREATE TEMP TABLE json_test (
  id serial PRIMARY KEY,
  data jsonb,
  metadata json,
  config jsonb,
  tags jsonb DEFAULT '[]'::jsonb,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Insert deterministic JSON data
INSERT INTO json_test (data, metadata, config, tags)
SELECT 
  jsonb_build_object(
    'id', i,
    'name', 'item_' || i,
    'value', i * 1.5,
    'category', CASE (i % 5) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' WHEN 3 THEN 'D' ELSE 'E' END,
    'nested', jsonb_build_object('level', i % 10, 'active', (i % 2 = 0))
  ),
  ('{"source":"test","version":' || (i % 10) || '}')::json,
  jsonb_build_object('setting_' || (i % 20), i * 0.5, 'enabled', (i % 3 = 0)),
  jsonb_build_array('tag' || (i % 10), 'category' || (i % 5))
FROM generate_series(1, 500) i;

-- Create GIN indexes for JSONB
CREATE INDEX idx_json_data ON json_test USING GIN (data);
CREATE INDEX idx_json_config ON json_test USING GIN (config);
CREATE INDEX idx_json_tags ON json_test USING GIN (tags);

-- Test JSONB field access
SELECT id, data->>'name' AS name, data->>'category' AS category
FROM json_test
WHERE (data->>'category') = 'A'
ORDER BY id
LIMIT 20;

-- Test JSONB field extraction as numeric
SELECT id, (data->>'value')::numeric AS value
FROM json_test
WHERE (data->>'value')::numeric > 250
ORDER BY value DESC
LIMIT 25;

-- Test JSONB nested access
SELECT id, data->'nested'->>'level' AS nested_level
FROM json_test
WHERE (data->'nested'->>'level')::int > 5
ORDER BY id
LIMIT 30;

-- Test JSONB containment (@>)
SELECT id, data
FROM json_test
WHERE data @> '{"category": "B"}'
ORDER BY id
LIMIT 20;

-- Test JSONB containment with nested
SELECT id, data
FROM json_test
WHERE data @> '{"nested": {"active": true}}'
ORDER BY id
LIMIT 15;

-- Test JSONB key exists (?)
SELECT id, data
FROM json_test
WHERE data ? 'category' AND data ? 'nested'
ORDER BY id
LIMIT 25;

-- Test JSONB any key exists (?|)
SELECT id, data
FROM json_test
WHERE data ?| ARRAY['category', 'value']
ORDER BY id
LIMIT 20;

-- Test JSONB all keys exist (?&)
SELECT id, data
FROM json_test
WHERE data ?& ARRAY['id', 'name', 'category']
ORDER BY id
LIMIT 30;

-- Test JSONB path queries (jsonb_path_query)
SELECT 
  id,
  jsonb_path_query(data, '$.nested.level') AS level_path
FROM json_test
WHERE data @> '{"nested": {"level": 7}}'
ORDER BY id
LIMIT 20;

-- Test JSON aggregation
SELECT 
  data->>'category' AS category,
  COUNT(*) AS count,
  AVG((data->>'value')::numeric) AS avg_value,
  jsonb_agg(data->'id') AS id_array
FROM json_test
GROUP BY data->>'category'
ORDER BY category
LIMIT 10;

-- Test JSONB set operations
SELECT 
  id,
  data || '{"extra": "field"}'::jsonb AS merged_data
FROM json_test
WHERE id <= 10
ORDER BY id;

-- Test JSONB array operations
SELECT 
  id,
  jsonb_array_length(tags) AS tag_count,
  tags->0 AS first_tag
FROM json_test
WHERE jsonb_array_length(tags) > 1
ORDER BY id
LIMIT 25;

-- Test JSONB text search in arrays
SELECT id, tags
FROM json_test
WHERE tags @> '"tag5"'::jsonb
ORDER BY id
LIMIT 20;

-- Test JSON type casting
SELECT 
  id,
  metadata::jsonb AS metadata_jsonb,
  config::json AS config_json
FROM json_test
WHERE id <= 15
ORDER BY id;

-- Test jsonb_build_object
SELECT 
  id,
  jsonb_build_object(
    'original_id', id,
    'computed_value', (data->>'value')::numeric * 2,
    'is_active', (data->'nested'->>'active')::boolean
  ) AS computed_json
FROM json_test
WHERE (data->'nested'->>'active')::boolean = true
ORDER BY id
LIMIT 30;

-- Test jsonb_each (expand object to key-value pairs)
SELECT 
  id,
  key,
  value
FROM json_test,
LATERAL jsonb_each(data)
WHERE id <= 5
ORDER BY id, key;

-- Test jsonb_each_text
SELECT 
  id,
  key,
  value
FROM json_test,
LATERAL jsonb_each_text(data)
WHERE id <= 5
ORDER BY id, key;

-- Test jsonb_object_keys
SELECT 
  id,
  jsonb_object_keys(data) AS key_name
FROM json_test
WHERE id <= 3
ORDER BY id, key_name;

-- Test jsonb_pretty
SELECT 
  id,
  jsonb_pretty(data) AS pretty_data
FROM json_test
WHERE id <= 5
ORDER BY id;

-- Test JSON functions on arrays
SELECT 
  id,
  jsonb_array_elements(tags) AS tag_element
FROM json_test
WHERE jsonb_array_length(tags) > 0
ORDER BY id, tag_element
LIMIT 40;

-- Test jsonb_set (add/modify keys)
SELECT 
  id,
  jsonb_set(data, '{new_key}', '"new_value"'::jsonb) AS modified_data
FROM json_test
WHERE id <= 10
ORDER BY id;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify JSON operations are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%json%' OR query LIKE '%JSON%') AS json_queries,
  COUNT(*) FILTER (WHERE query LIKE '%@>%' OR query LIKE '%?%') AS containment_queries,
  COUNT(*) FILTER (WHERE query LIKE '%jsonb_path%' OR query LIKE '%jsonb_each%') AS function_queries
FROM pg_stat_insights
WHERE query LIKE '%json_test%';

-- Verify JSON query metrics
SELECT 
  calls >= 1 AS has_executions,
  rows > 0 AS returned_rows,
  total_exec_time > 0 AS has_execution_time,
  shared_blks_hit >= 0 AS has_cache_usage
FROM pg_stat_insights
WHERE query LIKE '%json_test%' AND calls > 0
LIMIT 1;

