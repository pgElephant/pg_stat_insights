-- ============================================================================
-- Test 15: Complex Joins and Subqueries
-- Tests tracking of complex join operations and nested queries
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create multiple related tables
SELECT setseed(0.5);
CREATE TEMP TABLE customers (
  customer_id serial PRIMARY KEY,
  name text NOT NULL,
  email text,
  region text DEFAULT 'us',
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

CREATE TEMP TABLE orders (
  order_id serial PRIMARY KEY,
  customer_id int REFERENCES customers(customer_id),
  order_date date DEFAULT '2025-10-31',
  total_amount numeric(10,2),
  status text DEFAULT 'pending'
);

CREATE TEMP TABLE order_items (
  item_id serial PRIMARY KEY,
  order_id int REFERENCES orders(order_id),
  product_id int,
  quantity int,
  unit_price numeric(10,2)
);

CREATE TEMP TABLE products (
  product_id serial PRIMARY KEY,
  name text NOT NULL,
  category text,
  price numeric(10,2)
);

-- Insert deterministic data
INSERT INTO customers (name, email, region)
SELECT 
  'customer_' || i,
  'email_' || i || '@example.com',
  CASE (i % 4) WHEN 0 THEN 'us' WHEN 1 THEN 'eu' WHEN 2 THEN 'asia' ELSE 'other' END
FROM generate_series(1, 200) i;

INSERT INTO orders (customer_id, total_amount, status)
SELECT 
  (i % 200) + 1,
  (i * 10.5)::numeric(10,2),
  CASE (i % 3) WHEN 0 THEN 'pending' WHEN 1 THEN 'shipped' ELSE 'delivered' END
FROM generate_series(1, 500) i;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
  (i % 500) + 1,
  (i % 50) + 1,
  (i % 10) + 1,
  ((i % 100) * 1.25)::numeric(10,2)
FROM generate_series(1, 1000) i;

INSERT INTO products (name, category, price)
SELECT 
  'product_' || i,
  CASE (i % 5) WHEN 0 THEN 'electronics' WHEN 1 THEN 'clothing' WHEN 2 THEN 'food' WHEN 3 THEN 'books' ELSE 'other' END,
  (i * 2.75)::numeric(10,2)
FROM generate_series(1, 100) i;

-- Create indexes for join optimization
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Test simple joins
SELECT c.name, o.order_id, o.total_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.region = 'us'
ORDER BY o.total_amount DESC
LIMIT 20;

-- Test multiple joins
SELECT 
  c.name,
  o.order_id,
  o.order_date,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE c.region = 'eu' AND o.status = 'shipped'
ORDER BY o.total_amount DESC
LIMIT 50;

-- Test LEFT JOIN
SELECT 
  c.name,
  COUNT(o.order_id) AS order_count,
  COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
HAVING COUNT(o.order_id) > 2
ORDER BY total_spent DESC
LIMIT 30;

-- Test RIGHT JOIN
SELECT 
  o.order_id,
  c.name,
  o.total_amount
FROM orders o
RIGHT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.region = 'asia'
ORDER BY o.total_amount DESC NULLS LAST
LIMIT 25;

-- Test FULL OUTER JOIN
SELECT 
  c.customer_id,
  o.order_id,
  c.name,
  o.total_amount
FROM customers c
FULL OUTER JOIN orders o ON c.customer_id = o.customer_id
WHERE c.region = 'other' OR o.status = 'delivered'
ORDER BY c.customer_id, o.order_id
LIMIT 40;

-- Test subquery in WHERE clause
SELECT 
  c.name,
  c.region,
  (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS order_count
FROM customers c
WHERE c.customer_id IN (SELECT customer_id FROM orders WHERE total_amount > 500)
ORDER BY order_count DESC
LIMIT 20;

-- Test subquery in SELECT clause
SELECT 
  o.order_id,
  o.total_amount,
  (SELECT name FROM customers WHERE customer_id = o.customer_id) AS customer_name
FROM orders o
WHERE o.status = 'pending'
ORDER BY o.total_amount DESC
LIMIT 30;

-- Test correlated subquery
SELECT 
  c.customer_id,
  c.name,
  (SELECT AVG(total_amount) FROM orders WHERE customer_id = c.customer_id) AS avg_order_amount
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders WHERE customer_id = c.customer_id AND total_amount > 1000)
ORDER BY avg_order_amount DESC
LIMIT 25;

-- Test EXISTS clause
SELECT c.name, c.region
FROM customers c
WHERE EXISTS (
  SELECT 1 FROM orders o 
  WHERE o.customer_id = c.customer_id 
  AND o.total_amount > 750
)
ORDER BY c.name
LIMIT 40;

-- Test NOT EXISTS
SELECT c.name, c.email
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM orders o 
  WHERE o.customer_id = c.customer_id
)
ORDER BY c.name
LIMIT 10;

-- Test IN with subquery
SELECT 
  o.order_id,
  o.total_amount,
  o.status
FROM orders o
WHERE o.customer_id IN (
  SELECT customer_id FROM customers WHERE region = 'us'
)
ORDER BY o.total_amount DESC
LIMIT 35;

-- Test self-join
SELECT 
  c1.name AS customer1,
  c2.name AS customer2,
  COUNT(DISTINCT o1.order_id) AS shared_orders
FROM customers c1
JOIN customers c2 ON c1.region = c2.region AND c1.customer_id < c2.customer_id
JOIN orders o1 ON o1.customer_id = c1.customer_id
JOIN orders o2 ON o2.customer_id = c2.customer_id
WHERE c1.region = 'eu'
GROUP BY c1.name, c2.name
HAVING COUNT(DISTINCT o1.order_id) > 0
ORDER BY shared_orders DESC
LIMIT 15;

-- Test cross join
SELECT 
  c.name,
  p.name AS product_name,
  p.price
FROM customers c
CROSS JOIN products p
WHERE c.region = 'us' AND p.category = 'electronics'
ORDER BY p.price DESC
LIMIT 20;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify complex joins are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%JOIN%') AS join_queries,
  COUNT(*) FILTER (WHERE query LIKE '%EXISTS%' OR query LIKE '%IN (%') AS subquery_queries,
  COUNT(*) FILTER (WHERE query LIKE '%GROUP BY%') AS aggregation_queries
FROM pg_stat_insights
WHERE query LIKE '%customers%' OR query LIKE '%orders%';

-- Verify join performance metrics
SELECT 
  calls >= 1 AS has_executions,
  rows > 0 AS returned_rows,
  total_exec_time > 0 AS has_execution_time,
  shared_blks_hit >= 0 AS has_cache_hits,
  shared_blks_read >= 0 AS has_block_reads
FROM pg_stat_insights
WHERE query LIKE '%JOIN%' AND calls > 0
LIMIT 1;

