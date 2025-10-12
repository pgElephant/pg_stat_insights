#!/bin/bash

# Master test runner for pg_stat_insights
# Runs all TAP tests using StatsInsightManager

set -e
export PATH=/usr/local/pgsql.18/bin:$PATH
export PG_BIN=/usr/local/pgsql.18/bin

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                             ║"
echo "║     pg_stat_insights - Complete TAP Test Suite            ║"
echo "║                                                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

# Cleanup any existing test instances
pkill -9 postgres 2>/dev/null || true
rm -rf /tmp/pg_stat_insights_test_* 2>/dev/null || true
sleep 2

# Run all tests
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0

for test_file in t/0*.pl; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    echo
    echo "════════════════════════════════════════════════════════════"
    echo "Running: $(basename $test_file)"
    echo "════════════════════════════════════════════════════════════"
    
    if perl $test_file; then
        PASSED_FILES=$((PASSED_FILES + 1))
    else
        FAILED_FILES=$((FAILED_FILES + 1))
        echo "❌ $(basename $test_file) FAILED"
    fi
    
    # Cleanup between tests
    pkill -9 postgres 2>/dev/null || true
    rm -rf /tmp/pg_stat_insights_test_* 2>/dev/null || true
    sleep 1
done

echo
echo "════════════════════════════════════════════════════════════"
echo "FINAL TEST SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo
echo "Test Files: $TOTAL_FILES"
echo "Passed: $PASSED_FILES ✅"
echo "Failed: $FAILED_FILES"
echo

if [ $FAILED_FILES -eq 0 ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                             ║"
    echo "║       ✅ ALL TAP TEST FILES PASSED! ✅                     ║"
    echo "║                                                             ║"
    echo "║   Files: $TOTAL_FILES/$TOTAL_FILES                                               ║"
    echo "║   Using: StatsInsightManager.pm                            ║"
    echo "║   Status: Production Ready                                 ║"
    echo "║                                                             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                             ║"
    echo "║  ❌ SOME TEST FILES FAILED ❌                              ║"
    echo "║                                                             ║"
    echo "║   Passed: $PASSED_FILES/$TOTAL_FILES                                              ║"
    echo "║   Failed: $FAILED_FILES                                                 ║"
    echo "║                                                             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    exit 1
fi
