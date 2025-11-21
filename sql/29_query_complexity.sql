-- Test complex query patterns and advanced SQL features
-- Ensures pg_stat_insights handles sophisticated queries correctly

-- Test 1: Reset statistics
SELECT pg_stat_insights_reset();

-- Test 2: Create test schema with multiple related tables
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    order_date TIMESTAMP,
    total_amount DECIMAL(10,2)
);

CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    product_name VARCHAR(100),
    quantity INT,
    price DECIMAL(10,2)
);

-- Test 3: Insert relational data
INSERT INTO customers (name, email)
SELECT 
    'Customer_' || i,
    'customer' || i || '@test.com'
FROM generate_series(1, 100) i;

INSERT INTO orders (customer_id, order_date, total_amount)
SELECT 
    (i % 100) + 1,
    '2025-11-01 00:00:00'::TIMESTAMP - (i || ' hours')::INTERVAL,
    (i * 25.50)::DECIMAL(10,2)
FROM generate_series(1, 300) i;

INSERT INTO order_items (order_id, product_name, quantity, price)
SELECT 
    (i % 300) + 1,
    'Product_' || (i % 50),
    (i % 10) + 1,
    ((i % 20) * 5.99)::DECIMAL(10,2)
FROM generate_series(1, 600) i;

-- Test 4: Complex multi-table joins
SELECT c.name, COUNT(o.order_id) AS order_count, SUM(o.total_amount) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
HAVING COUNT(o.order_id) > 0
ORDER BY total_spent DESC
LIMIT 10;

-- Test 5: Nested subqueries with aggregates
SELECT 
    customer_id,
    (SELECT COUNT(*) FROM orders WHERE customer_id = c.customer_id) AS order_count,
    (SELECT SUM(total_amount) FROM orders WHERE customer_id = c.customer_id) AS total_spent
FROM customers c
WHERE customer_id IN (
    SELECT customer_id 
    FROM orders 
    GROUP BY customer_id 
    HAVING COUNT(*) > 2
)
ORDER BY customer_id
LIMIT 10;

-- Test 6: CTEs with window functions
WITH order_stats AS (
    SELECT 
        customer_id,
        order_id,
        total_amount,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_amount DESC) AS rank,
        SUM(total_amount) OVER (PARTITION BY customer_id) AS customer_total
    FROM orders
)
SELECT * FROM order_stats WHERE rank <= 3 ORDER BY customer_id, rank LIMIT 15;

-- Test 7: Recursive CTE
WITH RECURSIVE number_series AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM number_series WHERE n < 20
)
SELECT n, n * n AS square, n * n * n AS cube
FROM number_series
ORDER BY n;

-- Test 8: Complex CASE expressions
SELECT 
    customer_id,
    CASE 
        WHEN total_amount < 100 THEN 'Small'
        WHEN total_amount < 500 THEN 'Medium'
        WHEN total_amount < 1000 THEN 'Large'
        ELSE 'Enterprise'
    END AS order_size,
    COUNT(*) AS count
FROM orders
GROUP BY customer_id, 
    CASE 
        WHEN total_amount < 100 THEN 'Small'
        WHEN total_amount < 500 THEN 'Medium'
        WHEN total_amount < 1000 THEN 'Large'
        ELSE 'Enterprise'
    END
ORDER BY customer_id, order_size
LIMIT 20;

-- Test 9: LATERAL joins
SELECT c.name, recent_orders.order_count, recent_orders.recent_total
FROM customers c
CROSS JOIN LATERAL (
    SELECT 
        COUNT(*) AS order_count,
        SUM(total_amount) AS recent_total
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.order_date > NOW() - INTERVAL '7 days'
) recent_orders
WHERE recent_orders.order_count > 0
ORDER BY recent_orders.recent_total DESC
LIMIT 10;

-- Test 10: DISTINCT ON with complex ordering
SELECT DISTINCT ON (customer_id) 
    customer_id,
    order_id,
    total_amount,
    order_date
FROM orders
ORDER BY customer_id, total_amount DESC, order_date DESC
LIMIT 10;

-- Test 11: Verify complex queries are tracked
SELECT COUNT(*) >= 8 AS tracked_complex_queries
FROM pg_stat_insights
WHERE query LIKE '%customers%' OR query LIKE '%orders%'
  AND query NOT LIKE '%pg_stat_insights%';

-- Test 12: Check for recursive CTE tracking
SELECT COUNT(*) >= 1 AS tracked_recursive_cte
FROM pg_stat_insights
WHERE query LIKE '%RECURSIVE%';

-- Test 13: Verify JOIN tracking
SELECT COUNT(*) >= 2 AS tracked_joins
FROM pg_stat_insights
WHERE query LIKE '%JOIN%'
  AND query NOT LIKE '%pg_stat_insights%';

-- Test 14: Check window function tracking
SELECT COUNT(*) >= 1 AS tracked_window_functions
FROM pg_stat_insights
WHERE query LIKE '%OVER%'
  AND query NOT LIKE '%pg_stat_insights%';

-- Test 15: Verify all tracked queries have valid statistics
SELECT 
    COUNT(*) AS total_queries,
    COUNT(*) FILTER (WHERE calls > 0) AS queries_with_calls,
    COUNT(*) FILTER (WHERE total_exec_time >= 0) AS queries_with_time,
    COUNT(*) FILTER (WHERE mean_exec_time >= 0) AS queries_with_mean
FROM pg_stat_insights
WHERE query NOT LIKE '%pg_stat_insights%';

-- Test 16: Cleanup
DROP TABLE order_items;
DROP TABLE orders;
DROP TABLE customers;

-- Test 17: Final statistics check
SELECT COUNT(*) >= 0 AS stats_available_after_cleanup
FROM pg_stat_insights
WHERE query LIKE '%customers%' OR query LIKE '%orders%';

-- Test 18: Reset
SELECT pg_stat_insights_reset();

