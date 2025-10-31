-- ============================================================================
-- Test 18: Partitioned Tables
-- Tests tracking of queries on partitioned tables
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create partitioned table
SELECT setseed(0.5);
CREATE TEMP TABLE partition_test (
  id serial,
  region text NOT NULL,
  order_date date NOT NULL,
  amount numeric(10,2),
  status text DEFAULT 'pending'
) PARTITION BY RANGE (order_date);

-- Create partitions
CREATE TEMP TABLE partition_test_2024_q1 PARTITION OF partition_test
  FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TEMP TABLE partition_test_2024_q2 PARTITION OF partition_test
  FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
CREATE TEMP TABLE partition_test_2024_q3 PARTITION OF partition_test
  FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');
CREATE TEMP TABLE partition_test_2024_q4 PARTITION OF partition_test
  FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- Insert deterministic data across partitions
INSERT INTO partition_test (region, order_date, amount, status)
SELECT 
  CASE (i % 4) WHEN 0 THEN 'us' WHEN 1 THEN 'eu' WHEN 2 THEN 'asia' ELSE 'other' END,
  '2024-01-01'::date + ((i % 365) || ' days')::interval,
  (i * 10.5)::numeric(10,2),
  CASE (i % 3) WHEN 0 THEN 'pending' WHEN 1 THEN 'shipped' ELSE 'delivered' END
FROM generate_series(1, 500) i;

-- Create indexes on partitions
CREATE INDEX idx_partition_region ON partition_test(region);
CREATE INDEX idx_partition_date ON partition_test(order_date);
CREATE INDEX idx_partition_status ON partition_test(status);

-- Test queries targeting specific partitions (partition pruning)
SELECT COUNT(*) FROM partition_test WHERE order_date >= '2024-01-01' AND order_date < '2024-04-01';
SELECT COUNT(*) FROM partition_test WHERE order_date >= '2024-04-01' AND order_date < '2024-07-01';
SELECT COUNT(*) FROM partition_test WHERE order_date >= '2024-07-01' AND order_date < '2024-10-01';
SELECT COUNT(*) FROM partition_test WHERE order_date >= '2024-10-01' AND order_date < '2025-01-01';

-- Test cross-partition queries
SELECT 
  region,
  COUNT(*) AS order_count,
  SUM(amount) AS total_amount,
  AVG(amount) AS avg_amount
FROM partition_test
WHERE order_date >= '2024-01-01' AND order_date < '2024-12-31'
GROUP BY region
ORDER BY region;

-- Test queries with partition pruning and filters
SELECT id, region, order_date, amount
FROM partition_test
WHERE region = 'us' AND order_date >= '2024-06-01' AND order_date < '2024-09-01'
ORDER BY order_date
LIMIT 30;

-- Test queries spanning multiple partitions
SELECT 
  DATE_TRUNC('month', order_date) AS month,
  COUNT(*) AS orders,
  SUM(amount) AS total
FROM partition_test
WHERE order_date >= '2024-01-01' AND order_date < '2024-12-31'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;

-- Test UPDATE on partitioned table
UPDATE partition_test
SET status = 'processed'
WHERE region = 'us' AND order_date >= '2024-01-01' AND order_date < '2024-04-01';

UPDATE partition_test
SET amount = amount * 1.1
WHERE status = 'pending' AND order_date >= '2024-07-01';

-- Test DELETE on partitioned table
DELETE FROM partition_test
WHERE status = 'delivered' AND order_date < '2024-06-01';

-- Test INSERT into partitioned table (should route to correct partition)
INSERT INTO partition_test (region, order_date, amount, status)
VALUES 
  ('us', '2024-02-15', 500.00, 'pending'),
  ('eu', '2024-05-20', 750.00, 'shipped'),
  ('asia', '2024-08-10', 900.00, 'delivered'),
  ('other', '2024-11-25', 1100.00, 'pending');

-- Test JOIN with partitioned table
CREATE TEMP TABLE region_info (
  region text PRIMARY KEY,
  region_name text,
  currency text
);

INSERT INTO region_info VALUES
  ('us', 'United States', 'USD'),
  ('eu', 'Europe', 'EUR'),
  ('asia', 'Asia', 'JPY'),
  ('other', 'Other', 'USD');

SELECT 
  r.region_name,
  COUNT(p.id) AS order_count,
  SUM(p.amount) AS total_amount
FROM partition_test p
JOIN region_info r ON p.region = r.region
WHERE p.order_date >= '2024-01-01' AND p.order_date < '2024-12-31'
GROUP BY r.region_name
ORDER BY total_amount DESC;

-- Test subquery with partitioned table
SELECT 
  region,
  (SELECT COUNT(*) FROM partition_test p2 
   WHERE p2.region = p1.region 
   AND p2.order_date >= '2024-07-01') AS q3_q4_count
FROM (SELECT DISTINCT region FROM partition_test) p1
ORDER BY region;

-- Test window functions on partitioned table
SELECT 
  id,
  region,
  order_date,
  amount,
  SUM(amount) OVER (PARTITION BY region ORDER BY order_date) AS running_total
FROM partition_test
WHERE order_date >= '2024-01-01' AND order_date < '2024-04-01'
ORDER BY region, order_date
LIMIT 50;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify partitioned table queries are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%partition_test%') AS partition_queries,
  COUNT(*) FILTER (WHERE query LIKE '%PARTITION%') AS partition_keyword_queries,
  COUNT(*) FILTER (WHERE query LIKE '%order_date%') AS date_filter_queries
FROM pg_stat_insights
WHERE query LIKE '%partition_test%';

-- Verify partition query metrics
SELECT 
  calls >= 1 AS has_executions,
  rows >= 0 AS returned_rows,
  total_exec_time > 0 AS has_execution_time,
  shared_blks_hit >= 0 AS has_cache_usage
FROM pg_stat_insights
WHERE query LIKE '%partition_test%' AND calls > 0
LIMIT 1;

