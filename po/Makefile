# Makefile for pg_stat_insights message translations
# Copyright (C) 2025 pgElephant Team

DOMAIN = pg_stat_insights
GETTEXT_TRIGGERS = ereport errmsg errhint errdetail errcontext

# Available translations
LANGUAGES = zh_CN zh_TW ja_JP

# PostgreSQL installation
PG_CONFIG ?= pg_config
PGSHAREDIR := $(shell $(PG_CONFIG) --sharedir)
LOCALEDIR = $(PGSHAREDIR)/locale

# Tools
MSGFMT = msgfmt
MSGMERGE = msgmerge
XGETTEXT = xgettext

# Flags
MSGFMT_FLAGS = -c -v
MSGMERGE_FLAGS = --update --backup=none
XGETTEXT_FLAGS = --language=C --keyword=_ --keyword=N_ \
                 --keyword=ereport:2 --keyword=errmsg \
                 --keyword=errhint --keyword=errdetail \
                 --keyword=errcontext \
                 --copyright-holder='pgElephant Team' \
                 --package-name=$(DOMAIN) \
                 --package-version='1.0' \
                 --msgid-bugs-address='team@pgelephant.org'

# PO files
PO_FILES = $(addsuffix .po,$(LANGUAGES))
MO_FILES = $(addsuffix .mo,$(LANGUAGES))

.PHONY: all install clean update-pot merge-po

# Default target: build all MO files
all: $(MO_FILES)

# Build MO file from PO file
%.mo: %.po
	@echo "Building $@..."
	$(MSGFMT) $(MSGFMT_FLAGS) -o $@ $<

# Update POT template from source (requires source access)
update-pot:
	@echo "Updating POT template..."
	@if [ -f ../pg_stat_insights.c ]; then \
		$(XGETTEXT) $(XGETTEXT_FLAGS) -o $(DOMAIN).pot ../pg_stat_insights.c; \
		echo "✅ POT template updated"; \
	else \
		echo "❌ Source file not found"; \
		exit 1; \
	fi

# Merge POT updates into PO files
merge-po: $(DOMAIN).pot
	@for po in $(PO_FILES); do \
		echo "Merging $$po..."; \
		$(MSGMERGE) $(MSGMERGE_FLAGS) $$po $(DOMAIN).pot; \
	done

# Install MO files to PostgreSQL locale directory
install: all
	@echo "Installing message catalogs to $(LOCALEDIR)..."
	@for lang in $(LANGUAGES); do \
		dir=$(LOCALEDIR)/$$lang/LC_MESSAGES; \
		mkdir -p $$dir; \
		install -m 644 $$lang.mo $$dir/$(DOMAIN)-1.0.mo; \
		echo "  Installed $$lang.mo -> $$dir/$(DOMAIN)-1.0.mo"; \
	done
	@echo "✅ Installation complete"

# Clean built files
clean:
	rm -f $(MO_FILES)
	rm -f *~

# Validate all PO files
validate:
	@echo "Validating PO files..."
	@for po in $(PO_FILES); do \
		echo -n "  Checking $$po... "; \
		$(MSGFMT) -c -o /dev/null $$po 2>&1; \
		if [ $$? -eq 0 ]; then \
			echo "✅ OK"; \
		else \
			echo "❌ FAILED"; \
			exit 1; \
		fi; \
	done
	@echo "✅ All PO files are valid"

# Show translation statistics
stats:
	@echo "Translation Statistics:"
	@echo "======================="
	@for po in $(PO_FILES); do \
		echo ""; \
		echo "$$po:"; \
		msgfmt --statistics -o /dev/null $$po 2>&1; \
	done

# Help target
help:
	@echo "pg_stat_insights Translation Makefile"
	@echo "====================================="
	@echo ""
	@echo "Targets:"
	@echo "  all         - Build all MO files (default)"
	@echo "  install     - Install MO files to PostgreSQL locale directory"
	@echo "  update-pot  - Update POT template from source"
	@echo "  merge-po    - Merge POT updates into PO files"
	@echo "  validate    - Validate all PO files"
	@echo "  stats       - Show translation statistics"
	@echo "  clean       - Remove built files"
	@echo "  help        - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  PG_CONFIG   - Path to pg_config (default: pg_config)"
	@echo "  LOCALEDIR   - Locale installation directory (auto-detected)"
	@echo ""
	@echo "Examples:"
	@echo "  make                                # Build all translations"
	@echo "  make PG_CONFIG=/usr/pgsql-17/bin/pg_config install"
	@echo "  make validate                       # Check PO files"
	@echo "  make stats                          # Show translation progress"

