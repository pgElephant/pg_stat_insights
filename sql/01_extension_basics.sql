-- ============================================================================
-- Test 1: Extension Basics
-- Tests extension creation, versioning, and basic metadata
-- ============================================================================

-- Create the extension
CREATE EXTENSION pg_stat_insights;

-- Verify extension is installed
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_insights';

-- Check that all main objects exist
SELECT proname FROM pg_proc WHERE proname LIKE 'pg_stat_insights%' ORDER BY proname;

-- Check that all views exist
SELECT viewname FROM pg_views WHERE viewname LIKE 'pg_stat_insights%' ORDER BY viewname;

-- Verify function signatures
\df pg_stat_insights_reset

-- Test basic function calls (should not error)
SELECT pg_stat_insights_reset();

-- Verify main view is accessible
SELECT COUNT(*) >= 0 AS view_accessible FROM pg_stat_insights;

