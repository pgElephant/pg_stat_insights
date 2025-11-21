# Version-Specific Expected Output Files

## Overview

PostgreSQL versions format warning messages differently, requiring version-specific expected output files for some tests.

## Files Affected

- `24_logical_replication_setup.out` - Main expected file (for PostgreSQL 17/18)
- `24_logical_replication_setup.out.pg16` - PostgreSQL 16 specific version
- `26_replication_stress_test.out` - Main expected file (for PostgreSQL 17/18)
- `26_replication_stress_test.out.pg16` - PostgreSQL 16 specific version

## Version Differences

### PostgreSQL 16
```
WARNING:  wal_level is insufficient to publish logical changes
HINT:  Set wal_level to "logical" before creating subscriptions.
```

### PostgreSQL 17/18
```
WARNING:  "wal_level" is insufficient to publish logical changes
HINT:  Set "wal_level" to "logical" before creating subscriptions.
```

## Usage

For PostgreSQL 16 testing, copy the `.pg16` files to the main expected files:
```bash
cp expected/24_logical_replication_setup.out.pg16 expected/24_logical_replication_setup.out
cp expected/26_replication_stress_test.out.pg16 expected/26_replication_stress_test.out
```

For PostgreSQL 17/18 testing, the main expected files are already correct.

## Note

The main expected files (without `.pg16` suffix) are configured for PostgreSQL 17/18 format, as these represent the majority of supported versions.

