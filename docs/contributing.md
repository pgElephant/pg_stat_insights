# Contributing Guide

Thank you for your interest in contributing to pg_stat_insights! This guide will help you get started.

---

## Ways to Contribute

### [BUG] Bug Reports

Found a bug? Please report it!

1. **Search existing issues**: Check if already reported
2. **Create new issue**: Use bug report template
3. **Include details**:
   - PostgreSQL version
   - Extension version
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages
   - Diagnostic information

**Template:**
```markdown
**PostgreSQL Version:** 17.0
**pg_stat_insights Version:** 1.0.0
**OS:** Ubuntu 22.04

**Description:**
Brief description of the bug

**Steps to Reproduce:**
1. Run query X
2. Check view Y
3. See error Z

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Error Messages:**
```
Paste error messages here
```

**Diagnostic Info:**
```sql
SELECT version();
SELECT * FROM pg_settings WHERE name LIKE 'pg_stat_insights%';
```
```

---

### [NEW] Feature Requests

Have an idea for improvement?

1. **Check roadmap**: See if already planned
2. **Open discussion**: Discuss idea first
3. **Create feature request**: Use template

**Good Feature Requests:**

- Solve real problems
- Include use cases
- Provide examples
- Consider compatibility
- Estimate complexity

---

### [DOCS] Documentation

Improve documentation:

- Fix typos and errors
- Add examples
- Clarify confusing sections
- Translate to other languages
- Add diagrams

**Documentation Files:**
```
docs/
├── index.md              # Homepage
├── installation.md       # Installation guide
├── quick-start.md        # Quick start
├── configuration.md      # Configuration
├── views.md              # Views reference
├── metrics.md            # Metrics reference
├── usage.md              # Usage examples
├── testing.md            # Testing guide
├── ci-cd.md              # CI/CD workflows
├── troubleshooting.md    # This file
└── contributing.md       # This file
```

---

### 🧪 Tests

Add or improve tests:

- New regression tests
- Edge case coverage
- Performance benchmarks
- Platform-specific tests

See [Testing Guide](testing.md) for details.

---

### [CODE] Code Contributions

Contribute code improvements:

- Bug fixes
- New features
- Performance optimizations
- Code refactoring

---

## Development Setup

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  build-essential \
  postgresql-17 \
  postgresql-server-dev-17 \
  git

# macOS
brew install postgresql@17 git

# RHEL/Rocky
sudo dnf install -y \
  gcc make \
  postgresql17-devel \
  git
```

### Clone Repository

```bash
# Fork on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/pg_stat_insights.git
cd pg_stat_insights

# Add upstream remote
git remote add upstream https://github.com/pgelephant/pg_stat_insights.git

# Create feature branch
git checkout -b feature/my-improvement
```

### Build and Test

```bash
# Build
make clean
make

# Install
sudo make install

# Run tests
make installcheck

# Verify all 22 tests pass
# ok 1 - 01_extension_basics
# ...
# ok 22 - 22_query_normalization
# All 22 tests passed.
```

---

## Coding Standards

### C Code Style

Follow PostgreSQL coding conventions:

```c
/* Function header comment */
/*
 * function_name - Brief description
 *
 * Detailed description of what function does,
 * parameters, return values, etc.
 */
static void
function_name(int param1, char *param2)
{
    /* Variable declarations at top */
    int local_var;
    char *result;
    
    /* Code with clear comments */
    local_var = param1 * 2;
    
    /* Use PostgreSQL error reporting */
    if (local_var < 0)
        ereport(ERROR,
                (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                 errmsg("parameter must be positive")));
    
    return;
}
```

**Rules:**

- [OK] Use PostgreSQL memory contexts
- [OK] Follow PostgreSQL naming conventions
- [OK] Add comprehensive comments
- [OK] Use PostgreSQL error handling
- [OK] Include error codes
- [OK] Test edge cases
- [NO] No compiler warnings
- [NO] No memory leaks
- [NO] No unsafe operations

### SQL Code Style

```sql
-- Test file header
-- ============================================================================
-- Test NN: Test Name
-- Brief description of what this test validates
-- ============================================================================

-- Section comments
-- Reset statistics
SELECT pg_stat_insights_reset();

-- Descriptive variable/table names
CREATE TEMP TABLE meaningful_name (
  id serial PRIMARY KEY,
  value numeric,
  created_at timestamp DEFAULT '2025-10-31 12:00:00'::timestamp
);

-- Always use ORDER BY for deterministic results
SELECT * FROM meaningful_name ORDER BY id;

-- Clear assertion names
SELECT 
  condition = expected AS test_passed,
  actual_value
FROM test_table;
```

---

## Pull Request Process

### 1. Create Quality PR

**Before submitting:**

- [OK] All tests pass (`make installcheck`)
- [OK] No compiler warnings
- [OK] Code follows style guide
- [OK] Documentation updated
- [OK] CHANGELOG.md updated
- [OK] Commit messages are clear

**PR Checklist:**

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Performance improvement
- [ ] Refactoring

## Testing
- [ ] All 22 regression tests pass
- [ ] Added new tests for new functionality
- [ ] Tested on PostgreSQL 14, 15, 16, 17
- [ ] No compiler warnings
- [ ] No memory leaks

## Documentation
- [ ] Updated relevant documentation
- [ ] Added usage examples
- [ ] Updated CHANGELOG.md

## Screenshots (if applicable)
Paste screenshots here
```

### 2. Submit PR

```bash
# Commit changes
git add -A
git commit -m "feat: add awesome feature

- Detailed description
- What it does
- Why it's needed

Closes #123"

# Push to your fork
git push origin feature/my-improvement

# Create PR on GitHub
```

### 3. Code Review

- Address review comments
- Update code as needed
- Keep PR focused and small
- Be responsive to feedback

### 4. Merge

Once approved:
- PR will be merged to main
- Included in next release
- You'll be added to contributors!

---

## Testing Requirements

### Unit Tests

All code must have tests:

```sql
-- sql/NN_feature_name.sql
SELECT pg_stat_insights_reset();

-- Test your feature
... test code ...

-- Assertions
SELECT 
  expected_value = actual_value AS test_passed
FROM ...;
```

### Regression Tests

```bash
# Run all tests
make installcheck

# Run specific test
make installcheck REGRESS=14_prepared_statements

# Generate expected output
cp results/14_prepared_statements.out expected/
```

### Cross-Version Testing

Test on all supported versions:

```bash
# PostgreSQL 14
export PG_CONFIG=/usr/lib/postgresql/14/bin/pg_config
make clean && make && make installcheck

# PostgreSQL 15
export PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
make clean && make && make installcheck

# PostgreSQL 16
export PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
make clean && make && make installcheck

# PostgreSQL 17
export PG_CONFIG=/usr/lib/postgresql/17/bin/pg_config
make clean && make && make installcheck
```

---

## Documentation Guidelines

### Writing Style

- **Clear and concise** - Avoid jargon
- **Examples included** - Show, don't just tell
- **Proper formatting** - Use markdown features
- **Code blocks** - Always include language
- **Tables** - For structured data
- **Admonitions** - For notes/warnings/tips

### Markdown Admonitions

```markdown
!!! note "Title"
    Note content here

!!! warning "Important"
    Warning content

!!! tip "Pro Tip"
    Helpful tip

!!! danger "Critical"
    Critical information
```

### Code Examples

```markdown
```sql
-- Always include language
SELECT * FROM table_name;
```
```

---

## Commit Message Format

Follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `chore`: Maintenance

**Examples:**

```bash
# Feature
git commit -m "feat(tracking): add JSON operation tracking

- Add JSON/JSONB operation support
- Track JSON path queries
- Include containment operations

Closes #45"

# Bug fix
git commit -m "fix(cache): correct cache hit ratio calculation

- Fix division by zero in cache_hit_ratio
- Add NULLIF protection
- Update test expectations

Fixes #67"

# Documentation
git commit -m "docs: add troubleshooting guide

- Add common issues section
- Include diagnostic queries
- Add FAQ section"
```

---

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Release Checklist

- [ ] Update version in `pg_stat_insights.control`
- [ ] Update CHANGELOG.md
- [ ] Update README.md badges
- [ ] Run all tests on all versions
- [ ] Update documentation
- [ ] Create git tag
- [ ] Trigger GitHub Actions workflow
- [ ] Verify packages built
- [ ] Create GitHub release
- [ ] Announce release

---

## Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/):

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for community
- Show empathy

Report violations to: conduct@pgelephant.com

---

## Recognition

### Contributors

All contributors are recognized in:

- AUTHORS file
- GitHub contributors page
- Release notes
- Documentation credits

### Hall of Fame

Top contributors may be invited to:

- Become maintainers
- Join steering committee
- Guide project direction

---

## Resources

### Learning Resources

- [PostgreSQL Extension Development](https://www.postgresql.org/docs/current/extend.html)
- [PostgreSQL Coding Conventions](https://www.postgresql.org/docs/current/source.html)
- [Git Best Practices](https://git-scm.com/book/en/v2)
- [Markdown Guide](https://www.markdownguide.org/)

### Tools

- **Code Editor**: VS Code, Vim, Emacs
- **Git Client**: Command line, GitHub Desktop
- **PostgreSQL**: psql, pgAdmin
- **Testing**: pg_regress, TAP tests

---

## Questions?

Need help getting started?

- **Discussions**: https://github.com/pgelephant/pg_stat_insights/discussions
- **Email**: contribute@pgelephant.com
- **Docs**: https://pgelephant.github.io/pg_stat_insights/

**We'd love to have you contribute! Success!**

