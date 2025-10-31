-- ============================================================================
-- Test 20: Advanced Window Functions
-- Tests tracking of window functions and analytical queries
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Create test tables
SELECT setseed(0.5);
CREATE TEMP TABLE sales_data (
  sale_id serial PRIMARY KEY,
  region text NOT NULL,
  product_id int NOT NULL,
  sale_date date NOT NULL,
  amount numeric(10,2) NOT NULL,
  quantity int NOT NULL,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

CREATE TEMP TABLE employees (
  emp_id serial PRIMARY KEY,
  name text NOT NULL,
  department text NOT NULL,
  salary numeric(10,2) NOT NULL,
  hire_date date NOT NULL
);

-- Insert deterministic data
INSERT INTO sales_data (region, product_id, sale_date, amount, quantity)
SELECT 
  CASE (i % 4) WHEN 0 THEN 'north' WHEN 1 THEN 'south' WHEN 2 THEN 'east' ELSE 'west' END,
  (i % 20) + 1,
  '2024-01-01'::date + ((i % 365) || ' days')::interval,
  (i * 15.75)::numeric(10,2),
  (i % 10) + 1
FROM generate_series(1, 500) i;

INSERT INTO employees (name, department, salary, hire_date)
SELECT 
  'emp_' || i,
  CASE (i % 5) WHEN 0 THEN 'sales' WHEN 1 THEN 'marketing' WHEN 2 THEN 'engineering' WHEN 3 THEN 'hr' ELSE 'finance' END,
  (50000 + (i * 1000))::numeric(10,2),
  '2020-01-01'::date + ((i % 1000) || ' days')::interval
FROM generate_series(1, 200) i;

-- Test ROW_NUMBER()
SELECT 
  sale_id,
  region,
  amount,
  ROW_NUMBER() OVER (ORDER BY amount DESC) AS rank_by_amount
FROM sales_data
ORDER BY amount DESC
LIMIT 30;

-- Test ROW_NUMBER() with PARTITION BY
SELECT 
  sale_id,
  region,
  amount,
  ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rank_in_region
FROM sales_data
ORDER BY region, amount DESC
LIMIT 50;

-- Test RANK()
SELECT 
  sale_id,
  region,
  amount,
  RANK() OVER (PARTITION BY region ORDER BY amount DESC) AS rank_amount
FROM sales_data
ORDER BY region, amount DESC
LIMIT 40;

-- Test DENSE_RANK()
SELECT 
  sale_id,
  region,
  amount,
  DENSE_RANK() OVER (PARTITION BY region ORDER BY amount DESC) AS dense_rank_amount
FROM sales_data
ORDER BY region, amount DESC
LIMIT 35;

-- Test PERCENT_RANK()
SELECT 
  sale_id,
  region,
  amount,
  PERCENT_RANK() OVER (PARTITION BY region ORDER BY amount) AS percent_rank
FROM sales_data
ORDER BY region, amount
LIMIT 45;

-- Test CUME_DIST()
SELECT 
  sale_id,
  region,
  amount,
  CUME_DIST() OVER (PARTITION BY region ORDER BY amount) AS cumulative_dist
FROM sales_data
ORDER BY region, amount
LIMIT 40;

-- Test LAG()
SELECT 
  sale_id,
  region,
  sale_date,
  amount,
  LAG(amount, 1) OVER (PARTITION BY region ORDER BY sale_date) AS prev_amount,
  amount - LAG(amount, 1) OVER (PARTITION BY region ORDER BY sale_date) AS amount_diff
FROM sales_data
ORDER BY region, sale_date
LIMIT 50;

-- Test LEAD()
SELECT 
  sale_id,
  region,
  sale_date,
  amount,
  LEAD(amount, 1) OVER (PARTITION BY region ORDER BY sale_date) AS next_amount,
  LEAD(amount, 1) OVER (PARTITION BY region ORDER BY sale_date) - amount AS amount_diff
FROM sales_data
ORDER BY region, sale_date
LIMIT 45;

-- Test FIRST_VALUE()
SELECT 
  sale_id,
  region,
  amount,
  FIRST_VALUE(amount) OVER (PARTITION BY region ORDER BY sale_date) AS first_amount_in_region
FROM sales_data
ORDER BY region, sale_date
LIMIT 40;

-- Test LAST_VALUE()
SELECT 
  sale_id,
  region,
  amount,
  LAST_VALUE(amount) OVER (PARTITION BY region ORDER BY sale_date 
    RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_amount_in_region
FROM sales_data
ORDER BY region, sale_date
LIMIT 35;

-- Test SUM() window function
SELECT 
  sale_id,
  region,
  amount,
  SUM(amount) OVER (PARTITION BY region ORDER BY sale_date) AS running_total,
  SUM(amount) OVER (PARTITION BY region) AS region_total
FROM sales_data
ORDER BY region, sale_date
LIMIT 50;

-- Test AVG() window function
SELECT 
  sale_id,
  region,
  amount,
  AVG(amount) OVER (PARTITION BY region) AS avg_region_amount,
  AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7
FROM sales_data
ORDER BY sale_date
LIMIT 40;

-- Test COUNT() window function
SELECT 
  sale_id,
  region,
  COUNT(*) OVER (PARTITION BY region) AS region_count,
  COUNT(*) OVER (ORDER BY sale_date RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW) AS sales_last_7_days
FROM sales_data
ORDER BY sale_date
LIMIT 45;

-- Test MIN/MAX window functions
SELECT 
  sale_id,
  region,
  amount,
  MIN(amount) OVER (PARTITION BY region) AS min_region_amount,
  MAX(amount) OVER (PARTITION BY region) AS max_region_amount
FROM sales_data
ORDER BY region, amount DESC
LIMIT 40;

-- Test multiple window functions
SELECT 
  sale_id,
  region,
  amount,
  ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rank,
  SUM(amount) OVER (PARTITION BY region) AS total,
  AVG(amount) OVER (PARTITION BY region) AS average,
  PERCENT_RANK() OVER (PARTITION BY region ORDER BY amount) AS pct_rank
FROM sales_data
ORDER BY region, amount DESC
LIMIT 50;

-- Test window frames - ROWS
SELECT 
  sale_id,
  amount,
  SUM(amount) OVER (ORDER BY sale_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS sum_3_rows,
  AVG(amount) OVER (ORDER BY sale_id ROWS BETWEEN 4 PRECEDING AND 1 FOLLOWING) AS avg_6_rows
FROM sales_data
ORDER BY sale_id
LIMIT 40;

-- Test window frames - RANGE
SELECT 
  sale_id,
  sale_date,
  amount,
  SUM(amount) OVER (ORDER BY sale_date RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW) AS sum_7_days
FROM sales_data
ORDER BY sale_date
LIMIT 35;

-- Test NTILE()
SELECT 
  sale_id,
  region,
  amount,
  NTILE(4) OVER (PARTITION BY region ORDER BY amount DESC) AS quartile
FROM sales_data
ORDER BY region, amount DESC
LIMIT 45;

-- Test window function with JOIN
SELECT 
  e.emp_id,
  e.name,
  e.department,
  e.salary,
  RANK() OVER (PARTITION BY e.department ORDER BY e.salary DESC) AS dept_salary_rank,
  AVG(e.salary) OVER (PARTITION BY e.department) AS dept_avg_salary
FROM employees e
ORDER BY e.department, e.salary DESC
LIMIT 50;

-- Test nested window functions (in subquery)
SELECT 
  region,
  sale_id,
  amount,
  rank_within_region,
  amount - LAG(amount, 1) OVER (PARTITION BY region ORDER BY sale_id) AS diff_from_prev
FROM (
  SELECT 
    sale_id,
    region,
    amount,
    ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rank_within_region
  FROM sales_data
) ranked
ORDER BY region, sale_id
LIMIT 40;

-- Wait for stats
SELECT pg_sleep(0.2);

-- Verify window function queries are tracked
SELECT 
  COUNT(*) FILTER (WHERE query LIKE '%OVER%' OR query LIKE '%window%') AS window_queries,
  COUNT(*) FILTER (WHERE query LIKE '%ROW_NUMBER%' OR query LIKE '%RANK%' OR query LIKE '%LAG%' OR query LIKE '%LEAD%') AS window_functions,
  COUNT(*) FILTER (WHERE query LIKE '%PARTITION BY%') AS partition_queries
FROM pg_stat_insights
WHERE query LIKE '%sales_data%' OR query LIKE '%employees%';

-- Verify window function metrics
SELECT 
  calls >= 1 AS has_executions,
  rows > 0 AS returned_rows,
  total_exec_time > 0 AS has_execution_time
FROM pg_stat_insights
WHERE query LIKE '%OVER%' OR query LIKE '%window%'
LIMIT 1;

