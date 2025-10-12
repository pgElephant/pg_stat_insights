#-------------------------------------------------------------------------
#
# Makefile
#      Build configuration for pg_stat_insights
# Copyright (c) 2024-2025, pgElephant, Inc.
# Copyright (c) 2008-2025, PostgreSQL Global Development Group
#
# IDENTIFICATION
#	  contrib/pg_stat_insights/Makefile
#
#-------------------------------------------------------------------------

MODULE_big = pg_stat_insights
OBJS = \
	$(WIN32RES) \
	pg_stat_insights.o

EXTENSION = pg_stat_insights
DATA = pg_stat_insights--1.0.sql
PGFILEDESC = "pg_stat_insights - enhanced execution statistics of SQL statements"

LDFLAGS_SL += $(filter -lm, $(LIBS))

REGRESS_OPTS = --temp-config $(top_srcdir)/contrib/pg_stat_insights/pg_stat_insights.conf
REGRESS = select dml cursors utility level_tracking planning \
	user_activity wal entry_timestamp privileges extended \
	parallel cleanup oldextversions squashing

NO_INSTALLCHECK = 1
TAP_TESTS = 1

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
