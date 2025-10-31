-- ============================================================================
-- Test 9: JIT Compilation Tracking
-- Tests JIT statistics collection (if JIT is available)
-- ============================================================================

-- Reset statistics
SELECT pg_stat_insights_reset();

-- Enable JIT if available (PostgreSQL 11+)
SET jit = on;
SET jit_above_cost = 0;
SET jit_optimize_above_cost = 0;
SET jit_inline_above_cost = 0;

-- Create table for JIT testing
SELECT setseed(0.5); -- Set seed for deterministic values
CREATE TEMP TABLE jit_test AS
SELECT i, i * 2 AS doubled, i * 3 AS tripled, md5(i::text)
FROM generate_series(1, 10000) i;

-- Run query that might trigger JIT
SELECT 
  SUM(doubled + tripled) AS total,
  AVG(doubled) AS avg_doubled,
  COUNT(DISTINCT md5) AS unique_hashes
FROM jit_test
WHERE doubled > 1000 AND tripled < 20000;

-- Wait for stats
SELECT pg_sleep(0.1);

-- Test JIT statistics are non-negative
SELECT 
  jit_functions >= 0 AS jit_functions_valid,
  jit_generation_time >= 0 AS jit_gen_time_valid,
  jit_inlining_count >= 0 AS jit_inline_count_valid,
  jit_inlining_time >= 0 AS jit_inline_time_valid,
  jit_optimization_count >= 0 AS jit_opt_count_valid,
  jit_optimization_time >= 0 AS jit_opt_time_valid,
  jit_emission_count >= 0 AS jit_emit_count_valid,
  jit_emission_time >= 0 AS jit_emit_time_valid,
  jit_deform_count >= 0 AS jit_deform_count_valid,
  jit_deform_time >= 0 AS jit_deform_time_valid
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Test JIT time relationships (if JIT was used)
SELECT 
  CASE 
    WHEN jit_functions > 0 THEN jit_generation_time > 0
    ELSE jit_generation_time >= 0
  END AS jit_time_correlation
FROM pg_stat_insights
WHERE calls > 0
LIMIT 1;

-- Verify JIT stats are collected for complex queries
SELECT 
  COUNT(*) FILTER (WHERE jit_functions >= 0) AS queries_with_jit_tracking
FROM pg_stat_insights;

