# Security Policy

## Supported Versions

We provide security updates for the following versions of pg_stat_insights:

| Version | PostgreSQL Versions | Supported          |
|---------|---------------------|:------------------:|
| 1.0.x   | 13, 14, 15, 16, 17, 18 | :white_check_mark: |

## Reporting a Vulnerability

We take the security of pg_stat_insights seriously. If you discover a security vulnerability, please follow these steps:

### 1. **Do Not** Open a Public Issue

Please do not create a public GitHub issue for security vulnerabilities.

### 2. Report Privately

Send a detailed report to: **security@pgelephant.org**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### 3. Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity (critical: days, high: weeks, medium/low: next release)

### 4. Disclosure Process

1. We will confirm receipt of your report
2. We will investigate and validate the issue
3. We will develop and test a fix
4. We will coordinate disclosure timing with you
5. We will release a security update
6. We will publicly acknowledge your contribution (unless you prefer to remain anonymous)

## Security Best Practices

### Production Deployments

1. **Access Control**
   - Limit who can access `pg_stat_insights` views
   - Use PostgreSQL role-based access control
   - Queries may contain sensitive data (WHERE clauses, values)

2. **Query Text Sanitization**
   - pg_stat_insights normalizes queries (replaces literals with `$1`, `$2`, etc.)
   - However, table/column names are preserved
   - Consider creating restricted views for sensitive environments

3. **Performance Impact**
   - Monitor overhead in production (typically <1%)
   - Adjust `pg_stat_insights.max` to limit memory usage
   - Use `track = 'top'` in production to reduce overhead

4. **Data Retention**
   - Statistics persist across restarts (if `pg_stat_insights.save = on`)
   - Reset statistics periodically to prevent unbounded growth
   - Consider scheduled resets for compliance requirements

### Example: Restricted Access View

```sql
-- Create a view that hides query text for regular users
CREATE VIEW pg_stat_insights_safe AS
SELECT 
    queryid,
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_insights;

-- Grant access to monitoring role
GRANT SELECT ON pg_stat_insights_safe TO monitoring_role;
```

### Example: Scheduled Reset

```sql
-- Reset statistics monthly (run via cron)
SELECT pg_stat_insights_reset();
```

## Known Security Considerations

### Query Text Exposure

- **Issue**: Query text is visible to anyone with SELECT access
- **Mitigation**: Use GRANT/REVOKE to limit access, create restricted views
- **Severity**: Low (similar to pg_stat_statements)

### Memory Usage

- **Issue**: Unbounded query tracking could exhaust memory
- **Mitigation**: Set `pg_stat_insights.max` appropriately for your workload
- **Severity**: Low (same as pg_stat_statements)

### Performance Impact

- **Issue**: Tracking overhead could impact performance
- **Mitigation**: Use `track = 'top'` and disable planning tracking in production
- **Severity**: Very Low (<1% overhead typical)

## Security Updates

Security updates will be released as:
- Patch versions (e.g., 1.0.1, 1.0.2) for security fixes
- Announced via GitHub Security Advisories
- Notified to all users who watch the repository

## Responsible Disclosure

We follow responsible disclosure practices:
- 90-day disclosure timeline for vulnerabilities
- Coordinated disclosure with security researchers
- Public acknowledgment of researchers (if desired)

## Contact

For security concerns: **security@pgelephant.org**

For general questions: **team@pgelephant.org**

---

**Last Updated**: October 27, 2024

