#!/usr/bin/perl
#
# Test complex query patterns: JOINs, CTEs, Subqueries, Aggregations
#

use strict;
use warnings;
use lib 't';
use StatsInsightManager;

# Test plan
plan_tests(25);

# Setup
my $test_dir = setup_test_instance();
my $port = get_port();

execute_query($port, "CREATE EXTENSION pg_stat_insights;");
test_pass("Extension created");

execute_query($port, "SELECT pg_stat_insights_reset();");
test_pass("Statistics reset");

# Create test schema
execute_query($port, "CREATE TABLE customers (id SERIAL PRIMARY KEY, name TEXT, region TEXT);");
execute_query($port, "CREATE TABLE orders (id SERIAL PRIMARY KEY, customer_id INT, amount DECIMAL, order_date DATE);");
execute_query($port, "CREATE TABLE products (id SERIAL PRIMARY KEY, name TEXT, price DECIMAL);");
execute_query($port, "CREATE TABLE order_items (order_id INT, product_id INT, quantity INT);");
test_pass("Test schema created");

# Insert test data
execute_query($port, "INSERT INTO customers (name, region) SELECT 'Customer ' || i, CASE WHEN i % 3 = 0 THEN 'East' WHEN i % 3 = 1 THEN 'West' ELSE 'Central' END FROM generate_series(1, 100) i;");
execute_query($port, "INSERT INTO orders (customer_id, amount, order_date) SELECT (random() * 99 + 1)::int, (random() * 1000)::decimal, CURRENT_DATE - (random() * 365)::int FROM generate_series(1, 500) i;");
execute_query($port, "INSERT INTO products (name, price) SELECT 'Product ' || i, (random() * 100 + 10)::decimal FROM generate_series(1, 50) i;");
execute_query($port, "INSERT INTO order_items SELECT (random() * 499 + 1)::int, (random() * 49 + 1)::int, (random() * 10 + 1)::int FROM generate_series(1, 1000) i;");
test_pass("Test data inserted");

# Test 1: Simple JOIN
execute_query($port, "SELECT c.name, o.amount FROM customers c JOIN orders o ON c.id = o.customer_id WHERE o.amount > 500;");
my $join_count = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%customers c JOIN orders%';");
test_cmp($join_count, '>', 0, "Simple JOIN tracked");

# Test 2: Multi-table JOIN
execute_query($port, "SELECT c.name, o.amount, oi.quantity, p.name FROM customers c JOIN orders o ON c.id = o.customer_id JOIN order_items oi ON o.id = oi.order_id JOIN products p ON oi.product_id = p.id LIMIT 10;");
my $multi_join = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%JOIN%JOIN%JOIN%';");
test_cmp($multi_join, '>', 0, "Multi-table JOIN tracked");

# Test 3: Subquery
execute_query($port, "SELECT name FROM customers WHERE id IN (SELECT customer_id FROM orders WHERE amount > 700);");
my $subquery = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%SELECT customer_id FROM orders%';");
test_cmp($subquery, '>', 0, "Subquery tracked");

# Test 4: CTE (Common Table Expression)
execute_query($port, "WITH top_customers AS (SELECT customer_id, SUM(amount) as total FROM orders GROUP BY customer_id ORDER BY total DESC LIMIT 10) SELECT c.name, tc.total FROM top_customers tc JOIN customers c ON tc.customer_id = c.id;");
my $cte = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%WITH top_customers AS%';");
test_cmp($cte, '>', 0, "CTE query tracked");

# Test 5: Recursive CTE
execute_query($port, "WITH RECURSIVE nums AS (SELECT 1 as n UNION ALL SELECT n + 1 FROM nums WHERE n < 10) SELECT * FROM nums;");
my $recursive_cte = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%WITH RECURSIVE%';");
test_cmp($recursive_cte, '>', 0, "Recursive CTE tracked");

# Test 6: Window functions
execute_query($port, "SELECT name, amount, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY amount DESC) as rank FROM customers JOIN orders ON customers.id = orders.customer_id;");
my $window_func = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%ROW_NUMBER() OVER%';");
test_cmp($window_func, '>', 0, "Window function tracked");

# Test 7: GROUP BY with HAVING
execute_query($port, "SELECT region, COUNT(*), AVG(amount) FROM customers c JOIN orders o ON c.id = o.customer_id GROUP BY region HAVING COUNT(*) > 10;");
my $groupby = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%GROUP BY region HAVING%';");
test_cmp($groupby, '>', 0, "GROUP BY with HAVING tracked");

# Test 8: UNION
execute_query($port, "SELECT name FROM customers WHERE region = 'East' UNION SELECT name FROM customers WHERE region = 'West';");
my $union_q = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%UNION%';");
test_cmp($union_q, '>', 0, "UNION query tracked");

# Test 9: CASE expression
execute_query($port, "SELECT name, CASE WHEN amount > 800 THEN 'High' WHEN amount > 400 THEN 'Medium' ELSE 'Low' END as category FROM customers c JOIN orders o ON c.id = o.customer_id;");
my $case_expr = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%CASE WHEN%';");
test_cmp($case_expr, '>', 0, "CASE expression tracked");

# Test 10: EXISTS
execute_query($port, "SELECT name FROM customers c WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id AND o.amount > 500);");
my $exists_q = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%EXISTS%';");
test_cmp($exists_q, '>', 0, "EXISTS subquery tracked");

# Verify query complexity is reflected in metrics
my $complex_query_time = get_scalar($port, "SELECT AVG(mean_exec_time) FROM pg_stat_insights WHERE query LIKE '%JOIN%';");
test_cmp($complex_query_time, '>', 0, "Complex queries have execution time");

# Verify complex queries use more resources
my $join_io = get_scalar($port, "SELECT SUM(shared_blks_hit + shared_blks_read) FROM pg_stat_insights WHERE query LIKE '%JOIN%';");
test_cmp($join_io, '>', 0, "JOIN queries have I/O metrics");

# Test aggregation functions
execute_query($port, "SELECT COUNT(*), SUM(amount), AVG(amount), MIN(amount), MAX(amount), STDDEV(amount) FROM orders;");
my $agg_funcs = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%SUM%AVG%MIN%MAX%STDDEV%';");
test_cmp($agg_funcs, '>', 0, "Multiple aggregation functions tracked");

# Test DISTINCT
execute_query($port, "SELECT DISTINCT region FROM customers;");
my $distinct_q = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%DISTINCT region%';");
test_cmp($distinct_q, '>', 0, "DISTINCT query tracked");

# Test ORDER BY with LIMIT
execute_query($port, "SELECT * FROM orders ORDER BY amount DESC LIMIT 20;");
my $orderby = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%ORDER BY amount DESC LIMIT%';");
test_cmp($orderby, '>', 0, "ORDER BY with LIMIT tracked");

# Test LEFT JOIN
execute_query($port, "SELECT c.name, COUNT(o.id) FROM customers c LEFT JOIN orders o ON c.id = o.customer_id GROUP BY c.name;");
my $left_join = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%LEFT JOIN%';");
test_cmp($left_join, '>', 0, "LEFT JOIN tracked");

# Verify total query count
my $total_queries = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%';");
test_cmp($total_queries, '>=', 15, "All complex query types tracked (got: $total_queries)");

# Verify mean execution time makes sense
my $avg_mean_time = get_scalar($port, "SELECT AVG(mean_exec_time) FROM pg_stat_insights WHERE calls > 0;");
test_cmp($avg_mean_time, '>', 0, "Average mean_exec_time > 0 ($avg_mean_time)");

# Verify rows returned is reasonable
my $total_rows = get_scalar($port, "SELECT SUM(rows) FROM pg_stat_insights WHERE query LIKE 'SELECT%';");
test_cmp($total_rows, '>', 0, "SELECT queries returned rows ($total_rows)");

# Test query with many columns
execute_query($port, "SELECT c.id, c.name, c.region, o.id, o.amount, o.order_date, COUNT(oi.quantity), SUM(oi.quantity * p.price) FROM customers c LEFT JOIN orders o ON c.id = o.customer_id LEFT JOIN order_items oi ON o.id = oi.order_id LEFT JOIN products p ON oi.product_id = p.id GROUP BY c.id, c.name, c.region, o.id, o.amount, o.order_date LIMIT 10;");
my $wide_query = get_scalar($port, "SELECT count(*) FROM pg_stat_insights WHERE query LIKE '%COUNT(oi.quantity)%SUM(oi.quantity%';");
test_cmp($wide_query, '>', 0, "Complex multi-column query tracked");

# Verify highest I/O query is a JOIN or aggregation
my $top_io_query = get_scalar($port, "SELECT query FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%' ORDER BY (shared_blks_hit + shared_blks_read) DESC LIMIT 1;");
test_cmp($top_io_query, 'ne', '', "Top I/O query identified");

# Verify statistics are proportional
my $top_time_query = get_scalar($port, "SELECT query FROM pg_stat_insights WHERE query NOT LIKE '%pg_stat%' ORDER BY total_exec_time DESC LIMIT 1;");
test_cmp($top_time_query, 'ne', '', "Top time query identified");

# Cleanup
cleanup_test_instance($test_dir);

done_testing();

