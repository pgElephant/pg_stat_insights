# Grafana & Prometheus Integration for Index Monitoring

This guide provides pre-configured Grafana dashboards and Prometheus queries for monitoring PostgreSQL indexes using pg_stat_insights index monitoring views.

---

## Prometheus Queries for Index Monitoring

### 1. Total Index Count

```yaml
# postgres_exporter query
- name: pg_stat_insights_indexes_total
  query: |
    SELECT total_indexes FROM pg_stat_insights_index_summary
  metrics:
    - total_indexes:
        usage: "GAUGE"
        description: "Total number of indexes in the database"
```

### 2. Total Index Size

```yaml
- name: pg_stat_insights_index_size_total_mb
  query: |
    SELECT total_index_size_mb FROM pg_stat_insights_index_summary
  metrics:
    - total_index_size_mb:
        usage: "GAUGE"
        description: "Total size of all indexes in MB"
```

### 3. Active vs Unused Indexes

```yaml
- name: pg_stat_insights_index_usage
  query: |
    SELECT 
      active_indexes,
      unused_indexes,
      never_used_indexes
    FROM pg_stat_insights_index_summary
  metrics:
    - active_indexes:
        usage: "GAUGE"
        description: "Number of actively used indexes"
    - unused_indexes:
        usage: "GAUGE"
        description: "Number of unused indexes"
    - never_used_indexes:
        usage: "GAUGE"
        description: "Number of indexes never used"
```

### 4. Index Bloat Metrics

```yaml
- name: pg_stat_insights_index_bloat
  query: |
    SELECT 
      COUNT(*) FILTER (WHERE bloat_severity = 'HIGH') as high_bloat_count,
      COUNT(*) FILTER (WHERE bloat_severity = 'MEDIUM') as medium_bloat_count,
      SUM(estimated_bloat_size_mb) as total_bloat_mb
    FROM pg_stat_insights_index_bloat
  metrics:
    - high_bloat_count:
        usage: "GAUGE"
        description: "Number of indexes with high bloat"
    - medium_bloat_count:
        usage: "GAUGE"
        description: "Number of indexes with medium bloat"
    - total_bloat_mb:
        usage: "GAUGE"
        description: "Total estimated bloat size in MB"
```

### 5. Index Cache Hit Ratio

```yaml
- name: pg_stat_insights_index_cache_hit_ratio
  query: |
    SELECT 
      schemaname,
      tablename,
      indexname,
      idx_cache_hit_ratio
    FROM pg_stat_insights_indexes
    WHERE idx_cache_hit_ratio IS NOT NULL
  metrics:
    - idx_cache_hit_ratio:
        usage: "GAUGE"
        description: "Index cache hit ratio per index"
        labels: [schemaname, tablename, indexname]
```

### 6. Index Scan Statistics

```yaml
- name: pg_stat_insights_index_scans
  query: |
    SELECT 
      schemaname,
      tablename,
      indexname,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch
    FROM pg_stat_insights_indexes
  metrics:
    - idx_scan:
        usage: "COUNTER"
        description: "Number of index scans"
        labels: [schemaname, tablename, indexname]
    - idx_tup_read:
        usage: "COUNTER"
        description: "Number of index tuples read"
        labels: [schemaname, tablename, indexname]
    - idx_tup_fetch:
        usage: "COUNTER"
        description: "Number of index tuples fetched"
        labels: [schemaname, tablename, indexname]
```

### 7. Index Efficiency Metrics

```yaml
- name: pg_stat_insights_index_efficiency
  query: |
    SELECT 
      schemaname,
      tablename,
      indexname,
      index_scan_ratio,
      CASE 
        WHEN efficiency_rating = 'EXCELLENT' THEN 4
        WHEN efficiency_rating = 'GOOD' THEN 3
        WHEN efficiency_rating = 'FAIR' THEN 2
        WHEN efficiency_rating = 'POOR' THEN 1
        ELSE 0
      END as efficiency_score
    FROM pg_stat_insights_index_efficiency
  metrics:
    - index_scan_ratio:
        usage: "GAUGE"
        description: "Ratio of index scans to total scans"
        labels: [schemaname, tablename, indexname]
    - efficiency_score:
        usage: "GAUGE"
        description: "Index efficiency score (0-4)"
        labels: [schemaname, tablename, indexname]
```

### 8. Index Maintenance Alerts

```yaml
- name: pg_stat_insights_index_maintenance_alerts
  query: |
    SELECT 
      COUNT(*) FILTER (WHERE maintenance_type = 'REINDEX') as reindex_needed,
      COUNT(*) FILTER (WHERE maintenance_type = 'VACUUM') as vacuum_needed,
      COUNT(*) FILTER (WHERE priority = 'CRITICAL') as critical_maintenance
    FROM pg_stat_insights_index_maintenance
  metrics:
    - reindex_needed:
        usage: "GAUGE"
        description: "Number of indexes needing REINDEX"
    - vacuum_needed:
        usage: "GAUGE"
        description: "Number of indexes needing VACUUM"
    - critical_maintenance:
        usage: "GAUGE"
        description: "Number of indexes with critical maintenance needs"
```

### 9. Index Alerts Summary

```yaml
- name: pg_stat_insights_index_alerts_summary
  query: |
    SELECT 
      COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_alerts,
      COUNT(*) FILTER (WHERE severity = 'WARNING') as warning_alerts,
      COUNT(*) FILTER (WHERE alert_type = 'BLOAT') as bloat_alerts,
      COUNT(*) FILTER (WHERE alert_type = 'UNUSED') as unused_alerts
    FROM pg_stat_insights_index_alerts
  metrics:
    - critical_alerts:
        usage: "GAUGE"
        description: "Number of critical index alerts"
    - warning_alerts:
        usage: "GAUGE"
        description: "Number of warning index alerts"
    - bloat_alerts:
        usage: "GAUGE"
        description: "Number of bloat-related alerts"
    - unused_alerts:
        usage: "GAUGE"
        description: "Number of unused index alerts"
```

### 10. Index Size by Table

```yaml
- name: pg_stat_insights_index_size_by_table
  query: |
    SELECT 
      schemaname,
      tablename,
      SUM(index_size_mb) as total_index_size_mb,
      COUNT(*) as index_count
    FROM pg_stat_insights_indexes
    GROUP BY schemaname, tablename
  metrics:
    - total_index_size_mb:
        usage: "GAUGE"
        description: "Total index size per table in MB"
        labels: [schemaname, tablename]
    - index_count:
        usage: "GAUGE"
        description: "Number of indexes per table"
        labels: [schemaname, tablename]
```

---

## Grafana Dashboard Panels

### Panel 1: Index Overview

**Query:**
```sql
SELECT 
    total_indexes,
    total_index_size_mb,
    active_indexes,
    unused_indexes,
    bloated_indexes
FROM pg_stat_insights_index_summary;
```

**Visualization:** Stat panels showing key metrics

---

### Panel 2: Index Usage Distribution

**Query:**
```sql
SELECT 
    usage_status,
    COUNT(*) as count
FROM pg_stat_insights_index_usage
GROUP BY usage_status;
```

**Visualization:** Pie chart showing distribution of index usage status

---

### Panel 3: Index Bloat Over Time

**Query:**
```sql
SELECT 
    schemaname || '.' || indexname as index,
    estimated_bloat_size_mb,
    bloat_severity
FROM pg_stat_insights_index_bloat
WHERE bloat_severity IN ('HIGH', 'MEDIUM')
ORDER BY estimated_bloat_size_mb DESC
LIMIT 20;
```

**Visualization:** Bar chart showing top bloated indexes

---

### Panel 4: Index Cache Hit Ratio

**Query:**
```sql
SELECT 
    schemaname || '.' || tablename || '.' || indexname as index,
    idx_cache_hit_ratio * 100 as cache_hit_percent
FROM pg_stat_insights_indexes
WHERE idx_cache_hit_ratio IS NOT NULL
ORDER BY idx_cache_hit_ratio ASC
LIMIT 20;
```

**Visualization:** Bar chart showing indexes with lowest cache hit ratio

---

### Panel 5: Index Efficiency Rating

**Query:**
```sql
SELECT 
    efficiency_rating,
    COUNT(*) as count
FROM pg_stat_insights_index_efficiency
GROUP BY efficiency_rating;
```

**Visualization:** Bar chart showing efficiency distribution

---

### Panel 6: Index Scan vs Sequential Scan Ratio

**Query:**
```sql
SELECT 
    schemaname || '.' || tablename as table,
    indexname,
    index_scan_ratio * 100 as index_scan_percent,
    (1 - index_scan_ratio) * 100 as seq_scan_percent
FROM pg_stat_insights_index_efficiency
WHERE index_scan_ratio IS NOT NULL
ORDER BY index_scan_ratio ASC
LIMIT 20;
```

**Visualization:** Stacked bar chart comparing index vs sequential scans

---

### Panel 7: Index Maintenance Needs

**Query:**
```sql
SELECT 
    maintenance_type,
    priority,
    COUNT(*) as count
FROM pg_stat_insights_index_maintenance
WHERE maintenance_type != 'NONE'
GROUP BY maintenance_type, priority
ORDER BY 
    CASE priority 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;
```

**Visualization:** Table showing maintenance needs by type and priority

---

### Panel 8: Index Alerts Timeline

**Query:**
```sql
SELECT 
    alert_type,
    severity,
    COUNT(*) as alert_count
FROM pg_stat_insights_index_alerts
GROUP BY alert_type, severity;
```

**Visualization:** Time series showing alert counts over time

---

### Panel 9: Top Indexes by Size

**Query:**
```sql
SELECT 
    schemaname || '.' || tablename || '.' || indexname as index,
    index_size_mb
FROM pg_stat_insights_indexes
ORDER BY index_size_mb DESC
LIMIT 20;
```

**Visualization:** Bar chart showing largest indexes

---

### Panel 10: Index Usage Heatmap

**Query:**
```sql
SELECT 
    schemaname,
    tablename,
    indexname,
    total_scans,
    usage_status
FROM pg_stat_insights_index_usage
ORDER BY total_scans DESC;
```

**Visualization:** Heatmap showing index usage patterns

---

### Panel 11: Missing Index Recommendations

**Query:**
```sql
SELECT 
    schemaname || '.' || tablename as table,
    estimated_benefit,
    high_priority,
    recommended_index_def
FROM pg_stat_insights_missing_indexes
WHERE high_priority = true
ORDER BY 
    CASE estimated_benefit 
        WHEN 'HIGH' THEN 1 
        WHEN 'MEDIUM' THEN 2 
        ELSE 3 
    END;
```

**Visualization:** Table showing missing index recommendations

---

### Panel 12: Index Dashboard JSON

**Query:**
```sql
SELECT 
    section,
    name,
    details
FROM pg_stat_insights_index_dashboard
WHERE section = 'SUMMARY';
```

**Visualization:** JSON viewer for complete dashboard data

---

## Prometheus Alert Rules

### Alert: High Index Bloat

```yaml
groups:
  - name: pg_stat_insights_index_alerts
    interval: 5m
    rules:
      - alert: HighIndexBloat
        expr: |
          SELECT COUNT(*) 
          FROM pg_stat_insights_index_bloat 
          WHERE bloat_severity = 'HIGH'
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "High index bloat detected"
          description: "{{ $value }} indexes have high bloat and need REINDEX"
      
      - alert: UnusedIndexes
        expr: |
          SELECT never_used_indexes 
          FROM pg_stat_insights_index_summary
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Unused indexes detected"
          description: "{{ $value }} indexes have never been used"
      
      - alert: LowIndexCacheHitRatio
        expr: |
          SELECT AVG(idx_cache_hit_ratio) 
          FROM pg_stat_insights_indexes 
          WHERE idx_cache_hit_ratio IS NOT NULL
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Low index cache hit ratio"
          description: "Average index cache hit ratio is {{ $value | humanizePercentage }}"
      
      - alert: CriticalIndexMaintenance
        expr: |
          SELECT critical_maintenance 
          FROM pg_stat_insights_index_maintenance_alerts
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Critical index maintenance needed"
          description: "{{ $value }} indexes require immediate maintenance"
```

---

## Grafana Dashboard JSON

Complete Grafana dashboard configuration available in `grafana-index-monitoring-dashboard.json`

**Key Features:**
- 12 pre-configured panels
- Auto-refresh every 30 seconds
- Variable support for schema/table filtering
- Alert integration
- Export to PDF/PNG

---

## Integration Steps

### 1. Configure postgres_exporter

Add index monitoring queries to `postgres_exporter` configuration:

```yaml
queries:
  - pg_stat_insights_indexes_total
  - pg_stat_insights_index_size_total_mb
  - pg_stat_insights_index_usage
  - pg_stat_insights_index_bloat
  - pg_stat_insights_index_cache_hit_ratio
  - pg_stat_insights_index_scans
  - pg_stat_insights_index_efficiency
  - pg_stat_insights_index_maintenance_alerts
  - pg_stat_insights_index_alerts_summary
  - pg_stat_insights_index_size_by_table
```

### 2. Import Grafana Dashboard

1. Open Grafana
2. Go to Dashboards → Import
3. Upload `grafana-index-monitoring-dashboard.json`
4. Configure Prometheus data source
5. Set refresh interval

### 3. Configure Alert Rules

1. Add alert rules to Prometheus configuration
2. Configure notification channels in Grafana
3. Set alert thresholds based on your requirements

---

## Example Queries for Custom Dashboards

### Index Growth Over Time

```sql
SELECT 
    schemaname || '.' || indexname as index,
    index_size_mb,
    now() as time
FROM pg_stat_insights_indexes
ORDER BY index_size_mb DESC;
```

### Index Efficiency by Type

```sql
SELECT 
    index_type,
    AVG(CASE 
        WHEN efficiency_rating = 'EXCELLENT' THEN 4
        WHEN efficiency_rating = 'GOOD' THEN 3
        WHEN efficiency_rating = 'FAIR' THEN 2
        WHEN efficiency_rating = 'POOR' THEN 1
        ELSE 0
    END) as avg_efficiency_score
FROM pg_stat_insights_indexes i
JOIN pg_stat_insights_index_efficiency e 
    ON i.schemaname = e.schemaname 
    AND i.tablename = e.tablename 
    AND i.indexname = e.indexname
GROUP BY index_type;
```

### Index Maintenance Cost Analysis

```sql
SELECT 
    maintenance_type,
    COUNT(*) as count,
    SUM(CASE 
        WHEN priority = 'CRITICAL' THEN 1 ELSE 0 
    END) as critical_count
FROM pg_stat_insights_index_maintenance
WHERE maintenance_type != 'NONE'
GROUP BY maintenance_type;
```

---

## Best Practices

1. **Monitor Regularly**: Set up daily/weekly reviews of index metrics
2. **Set Thresholds**: Configure alerts for bloat > 20%, cache hit < 80%
3. **Review Unused Indexes**: Monthly review of never-used indexes
4. **Track Growth**: Monitor index size growth trends
5. **Maintenance Windows**: Schedule REINDEX during low-traffic periods

---

## Troubleshooting

### No Data in Grafana

- Verify postgres_exporter is configured correctly
- Check that pg_stat_insights extension is installed
- Ensure views are accessible (GRANT SELECT)

### High Query Latency

- Index monitoring views query system catalogs
- Consider materialized views for large databases
- Use summary views instead of detailed views for dashboards

### Missing Metrics

- Some metrics require index activity (bloat calculation)
- Ensure indexes have been used to generate statistics
- Check PostgreSQL version compatibility (16/17/18)

---

## Additional Resources

- [PostgreSQL Index Monitoring Best Practices](https://www.postgresql.org/docs/current/indexes.html)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)

