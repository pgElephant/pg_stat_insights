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

REGRESS_OPTS = --temp-config pg_stat_insights.conf
REGRESS = 01_extension_basics 02_basic_queries 03_views_and_aggregates \
	04_statistics_accuracy 05_io_and_cache 06_wal_tracking \
	07_reset_functionality 08_parallel_queries 09_jit_tracking \
	10_edge_cases 11_comprehensive_metrics 12_permissions 13_cleanup \
	14_prepared_statements 15_complex_joins 16_json_operations \
	17_array_operations 18_partitioning 19_triggers_functions \
	20_window_functions 21_transaction_handling 22_query_normalization \
	23_replication_monitoring 24_logical_replication_setup 25_replication_dashboard \
	26_replication_stress_test 27_high_volume_queries 28_concurrent_operations \
	29_query_complexity 30_final_integration

TAP_TESTS = 1

# Internationalization support
GETTEXT_LANGUAGES = zh_CN zh_TW ja_JP
GETTEXT_TRIGGERS = ereport errmsg errhint errdetail errcontext

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# OS detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Detect macOS (Darwin)
ifeq ($(UNAME_S),Darwin)
  IS_MACOS := 1
  SHLIB_SUFFIX := .dylib
else
  IS_MACOS := 0
  SHLIB_SUFFIX := .so
endif

# Detect architecture
ifeq ($(UNAME_M),x86_64)
  ARCH := x86_64
else ifeq ($(UNAME_M),arm64)
  ARCH := arm64
else ifeq ($(UNAME_M),aarch64)
  ARCH := aarch64
else
  ARCH := unknown
endif

# Additional targets for internationalization
# Only build translations if po directory exists
.PHONY: translations translations-install translations-clean translations-stats

translations:
	@if [ -d po ]; then \
		echo "Building translations..."; \
		$(MAKE) -C po all; \
	else \
		echo "Skipping translations (po directory not found)"; \
	fi

translations-install:
	@if [ -d po ] && command -v msgfmt >/dev/null 2>&1; then \
		echo "Installing translations..."; \
		$(MAKE) -C po install; \
	else \
		echo "Skipping translations installation (msgfmt not found or po directory missing)"; \
	fi

translations-clean:
	@if [ -d po ]; then \
		echo "Cleaning translations..."; \
		$(MAKE) -C po clean; \
	fi

translations-stats:
	@if [ -d po ]; then \
		echo "Translation statistics..."; \
		$(MAKE) -C po stats; \
	fi

# Enhanced install target (translations are optional)
install: translations-install

# Enhanced clean target (translations are optional)
clean: translations-clean

# Post-install step for macOS: ensure .dylib is available if .so was created
install-macos-check:
	@if [ "$(IS_MACOS)" = "1" ]; then \
		if [ -f "$(DESTDIR)$(pkglibdir)/$(MODULE_big).so" ] && [ ! -f "$(DESTDIR)$(pkglibdir)/$(MODULE_big).dylib" ]; then \
			echo "Creating .dylib symlink for macOS..."; \
			cd "$(DESTDIR)$(pkglibdir)" && ln -sf $(MODULE_big).so $(MODULE_big).dylib; \
		fi; \
	fi
