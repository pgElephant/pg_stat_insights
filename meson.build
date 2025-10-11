#-------------------------------------------------------------------------
#
# meson.build
#      Build configuration for pg_stat_insights
# Copyright (c) 2024-2025, pgElephant, Inc.

# Copyright (c) 2008-2025, PostgreSQL Global Development Group
#
# IDENTIFICATION
#	  contrib/pg_stat_insights/meson.build
#
#-------------------------------------------------------------------------

pg_stat_insights_sources = files(
  'pg_stat_insights.c',
)

if host_system == 'windows'
  pg_stat_insights_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'pg_stat_insights',
    '--FILEDESC', 'pg_stat_insights - enhanced execution statistics of SQL statements',])
endif

pg_stat_insights = shared_module('pg_stat_insights',
  pg_stat_insights_sources,
  kwargs: contrib_mod_args + {
    'dependencies': contrib_mod_args['dependencies'],
  },
)
contrib_targets += pg_stat_insights

install_data(
  'pg_stat_insights.control',
  'pg_stat_insights--1.0.sql',
  kwargs: contrib_data_args,
)

tests += {
  'name': 'pg_stat_insights',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'regress': {
    'sql': [
      'select',
      'dml',
      'cursors',
      'utility',
      'level_tracking',
      'planning',
      'user_activity',
      'wal',
      'entry_timestamp',
      'privileges',
      'extended',
      'parallel',
      'cleanup',
      'oldextversions',
      'squashing',
    ],
    'regress_args': ['--temp-config', files('pg_stat_insights.conf')],
    # Disabled because these tests require
    # "shared_preload_libraries=pg_stat_insights", which typical
    # runningcheck users do not have (e.g. buildfarm clients).
    'runningcheck': false,
  },
  'tap': {
    'tests': [
      't/010_restart.pl',
    ],
  },
}
