%global pg_version %{?pg_version}%{!?pg_version:17}
%global package_version %{?package_version}%{!?package_version:1.0}
%global pginstdir /usr/pgsql-%{pg_version}

Name:           pg_stat_insights_%{pg_version}
Version:        %{package_version}
Release:        1%{?dist}
Summary:        Advanced PostgreSQL query performance monitoring extension
License:        MIT
URL:            https://github.com/pgelephant/pg_stat_insights
Source0:        pg_stat_insights-%{version}.tar.gz

BuildRequires:  postgresql%{pg_version}-server
BuildRequires:  postgresql%{pg_version}-devel
BuildRequires:  gcc
BuildRequires:  make

Requires:       postgresql%{pg_version}-server

%description
pg_stat_insights is an advanced PostgreSQL extension for database performance
monitoring, query optimization, and SQL analytics. It tracks 52 comprehensive
metrics across 11 pre-built views to identify slow queries, optimize cache
performance, and monitor database health in real-time.

Features:
- 52 metric columns for comprehensive query analysis
- 11 pre-built views for instant insights
- Drop-in replacement for pg_stat_statements with enhanced metrics
- Compatible with PostgreSQL 13, 14, 15, 16, 17, 18
- Response time tracking and cache analysis
- WAL monitoring and time-series data
- Prometheus/Grafana ready with pre-built dashboards

%prep
%setup -q -n pg_stat_insights-%{version}

%build
export PG_CONFIG=%{pginstdir}/bin/pg_config
export PATH=%{pginstdir}/bin:$PATH
make USE_PGXS=1 %{?_smp_mflags}

%install
export PG_CONFIG=%{pginstdir}/bin/pg_config
export PATH=%{pginstdir}/bin:$PATH
make install USE_PGXS=1 DESTDIR=%{buildroot}

%files
%license LICENSE
%doc README.md
%{pginstdir}/lib/pg_stat_insights.so
%{pginstdir}/share/extension/pg_stat_insights--*.sql
%{pginstdir}/share/extension/pg_stat_insights.control
%{pginstdir}/lib/bitcode/pg_stat_insights.index.bc
%{pginstdir}/lib/bitcode/pg_stat_insights/

%changelog
* Sun Oct 27 2024 pgElephant Team <team@pgelephant.org> - 1.0-1
- Initial RPM release
- PostgreSQL 13, 14, 15, 16, 17, 18 support
- 52 metrics across 11 views
- Enhanced performance monitoring capabilities

