# Contributing to pg_stat_insights

Thank you for your interest in contributing to pg_stat_insights!

## Development Setup

```bash
git clone https://github.com/pgelephant/pg_stat_insights.git
cd pg_stat_insights

# Build
USE_PGXS=1 make

# Test
USE_PGXS=1 make installcheck
```

## Code Style

- Follow PostgreSQL coding conventions
- Use tabs for indentation
- Keep lines under 80 characters where reasonable
- Add comments for complex logic
- Use descriptive variable names

## Adding New Metrics

1. Add field to `Counters` struct in `pg_stat_insights.c`
2. Initialize in entry allocation
3. Update in `pgss_store()` function
4. Add to SQL function output in `pg_stat_insights--1.0.sql`
5. Document in README.md and METRICS_COUNT.md
6. Add tests if applicable

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Update documentation
6. Submit a pull request

## Testing

```bash
# Run all tests
USE_PGXS=1 make installcheck

# Run specific test
psql -f sql/select.sql
```

## License

All contributions will be licensed under the PostgreSQL license.

