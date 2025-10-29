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

TAP_TESTS = 1

# Internationalization support
GETTEXT_LANGUAGES = zh_CN zh_TW ja_JP
GETTEXT_TRIGGERS = ereport errmsg errhint errdetail errcontext

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Additional targets for internationalization
.PHONY: translations translations-install translations-clean translations-stats

translations:
	@echo "Building translations..."
	@$(MAKE) -C po all

translations-install: translations
	@echo "Installing translations..."
	@$(MAKE) -C po install

translations-clean:
	@echo "Cleaning translations..."
	@$(MAKE) -C po clean

translations-stats:
	@echo "Translation statistics..."
	@$(MAKE) -C po stats

# Enhanced install target
install: translations-install

# Enhanced clean target  
clean: translations-clean
