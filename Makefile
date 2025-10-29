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
	@if [ -d po ]; then \
		echo "Installing translations..."; \
		$(MAKE) -C po install; \
	else \
		echo "Skipping translations installation (po directory not found)"; \
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
