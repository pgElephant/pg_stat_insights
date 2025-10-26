# Contributing to pg_stat_insights

Thank you for your interest in contributing to pg_stat_insights! We welcome contributions from the community.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in [GitHub Issues](https://github.com/pgelephant/pg_stat_insights/issues)
2. If not, create a new issue with:
   - Clear description of the problem or feature
   - PostgreSQL version and OS information
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Relevant log excerpts or error messages

### Submitting Pull Requests

1. **Fork** the repository
2. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our coding standards
4. **Test thoroughly**:
   ```bash
   make clean && make
   sudo make install
   make installcheck  # Run regression tests
   cd t && prove -v   # Run TAP tests
   ```
5. **Commit** with clear messages:
   ```bash
   git commit -m "Add feature: description of feature"
   ```
6. **Push** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Open a Pull Request** with:
   - Clear description of changes
   - Why the change is needed
   - How it was tested
   - Any breaking changes or migration notes

## Coding Standards

### C Code

Follow PostgreSQL C coding conventions:

- **Variables**: Declare at the start of functions
- **Comments**: Use C-style `/* */` comments (not `//`)
- **Braces**: Allman style (opening brace on its own line for functions)
- **Indentation**: Tabs (width 4)
- **Naming**: Snake_case for functions and variables
- **Headers**: Include guards in all `.h` files
- **Warnings**: Code must compile with zero warnings
- **Memory**: Use PostgreSQL memory contexts (palloc/pfree)

Example:
```c
int
my_function(int param1, char *param2)
{
    int result;
    char *buffer;
    
    /* Initialize variables */
    result = 0;
    buffer = palloc(256);
    
    /* Function logic here */
    
    pfree(buffer);
    return result;
}
```

### SQL Code

- Use lowercase for SQL keywords in `.sql` files
- Indent nested queries properly
- Add comments for complex operations
- Test all SQL against all supported PostgreSQL versions

### Documentation

- Update README.md for user-facing changes
- Update relevant docs in GitHub Pages workflow
- Add inline code comments for complex logic
- Update CHANGELOG.md with your changes

## Testing Requirements

### Before Submitting PR

1. **Compile without warnings**:
   ```bash
   make clean && make
   ```

2. **Run regression tests**:
   ```bash
   make installcheck
   ```

3. **Run TAP tests**:
   ```bash
   cd t
   prove -v 001_basic.pl  # Test individual files
   prove -v t/*.pl        # Or all tests
   ```

4. **Test on multiple PostgreSQL versions** (if possible):
   - PostgreSQL 13, 14, 15, 16, 17, 18

### Writing Tests

- Add regression tests to `sql/` and expected output to `expected/`
- Add TAP tests to `t/` for complex scenarios
- Use `StatsInsightManager.pm` for test utilities
- Ensure tests are idempotent and clean up after themselves

## Development Setup

### Prerequisites

- PostgreSQL 13+ with development headers
- GCC or Clang compiler
- Make
- Git
- Perl (for TAP tests)

### Build and Install

```bash
# Clone repository
git clone https://github.com/pgelephant/pg_stat_insights.git
cd pg_stat_insights

# Build
make clean && make

# Install
sudo make install

# Configure PostgreSQL
echo "shared_preload_libraries = 'pg_stat_insights'" >> $PGDATA/postgresql.conf
pg_ctl restart

# Create extension
psql -c "CREATE EXTENSION pg_stat_insights;"
```

### Running Tests Locally

```bash
# Regression tests
make installcheck

# Individual TAP test
cd t
prove -v 001_basic.pl

# All TAP tests
./run_all_tests.sh

# Specific test with verbose output
prove -v 018_all_52_columns_comprehensive.pl
```

## Documentation

### Update Documentation

If your changes affect user-facing functionality:

1. Update `README.md`
2. Update `.github/workflows/deploy-documentation.yml` if adding new features
3. Add examples to the documentation
4. Update `CHANGELOG.md`

### Building Documentation Locally

The documentation is self-contained in the workflow file. To preview changes:

1. Extract doc content from `.github/workflows/deploy-documentation.yml`
2. Save to `docs/*.md` files temporarily
3. Run `mkdocs serve` to preview

## Code Review Process

1. All PRs require maintainer review
2. CI/CD checks must pass (workflows run automatically)
3. At least one approval required
4. No merge conflicts
5. Documentation updated as needed

## Getting Help

- **Questions**: Open a [GitHub Discussion](https://github.com/pgelephant/pg_stat_insights/discussions)
- **Bugs**: Create an [Issue](https://github.com/pgelephant/pg_stat_insights/issues)
- **Email**: team@pgelephant.org

## Code of Conduct

Be respectful, professional, and collaborative. We follow the [PostgreSQL Community Code of Conduct](https://www.postgresql.org/about/policies/coc/).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to pg_stat_insights! 🙏

