# Testing Guide - Cortex Cost Calculator

**Project:** Cortex Cost Calculator
**Version:** 3.0
**Last Updated:** 2026-01-05
**Expires:** See deploy_all.sql

---

## Overview

This guide explains how to test the Cortex Cost Calculator to ensure correct deployment and ongoing data quality. Testing is divided into three main areas:

1. **SQL View Tests** - Validate view compilation and business logic
2. **Data Quality Tests** - Ensure data accuracy and completeness
3. **Python Unit Tests** - Test calculation functions and formulas

---

## Test Suite Structure

```
tests/
- test_sql_views.sql           # SQL view validation tests
- test_data_quality.sql        # Data quality and integrity tests
- test_streamlit_calcs.py      # Python unit tests
- README_TESTING.md            # This file
```

---

## 1. SQL View Tests

### Purpose
Validate that all SQL views compile successfully and return expected results.

### Running SQL Tests

```sql
-- In Snowsight or SnowSQL
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Run full test suite
@tests/test_sql_views.sql
```

### What's Tested

#### Compilation Tests (4 tests)
- All views can be queried without errors
- Views return data or handle empty results gracefully

#### Data Quality Tests (4 tests)
- No NULL values in required columns
- No negative credits
- Dates within valid ranges
- No duplicate date-service combinations

#### Business Logic Tests (2 tests)
- credits_per_user calculations are accurate

#### Performance Tests (2 tests)
- V_CORTEX_DAILY_SUMMARY queries under 5 seconds

### Expected Output

```
+-------------------------------------------------------------------+
|               CORTEX COST CALCULATOR - TEST RESULTS              |
+-------------------------------------------------------------------+

TEST_NUMBER | TEST_CATEGORY  | TEST_NAME                     | TEST_STATUS | ...
1           | Compilation    | V_CORTEX_ANALYST_DETAIL ...   | PASS        | ...
2           | Compilation    | V_CORTEX_SEARCH_DETAIL ...    | PASS        | ...
...

------------------- TEST SUMMARY -------------------
TEST_CATEGORY  | TOTAL_TESTS | PASSED | FAILED | WARNINGS
Compilation    | 4           | 4      | 0      | 0
Data Quality   | 4           | 4      | 0      | 0
Business Logic | 2           | 2      | 0      | 0
...

ALL TESTS PASSED - Deployment validated successfully
```

### Troubleshooting Failed Tests

#### "View does not exist"
**Cause:** Views not deployed
**Solution:** Run `sql/01_deployment/deploy_cortex_monitoring.sql`

#### "Insufficient privileges"
**Cause:** Missing ACCOUNT_USAGE permissions
**Solution:** `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;`

#### "Query timeout"
**Cause:** Performance issue
**Solution:** Run snapshot task to pre-aggregate data

---

## 2. Data Quality Tests

### Purpose
Validate data accuracy, completeness, and consistency across all views.

### Running Data Quality Tests

```sql
-- In Snowsight or SnowSQL
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Run data quality report
@tests/test_data_quality.sql
```

### What's Tested

#### Completeness Checks (3 checks)
- Missing dates in historical data
- Services with no recent data
- NULL value counts by column

#### Accuracy Checks (2 checks)
- Calculation accuracy (credits_per_user)
- Credits sum consistency across views

#### Validity Checks (3 checks)
- Value ranges (no negative/extreme values)
- Date validity (no future dates or dates too old)
- Service type validity (known service types)

#### Consistency Checks (2 checks)
- Duplicate detection
- Anomaly detection consistency

#### Configuration Validation (2 checks)
- Required settings present
- Configuration data type validation

### Data Quality Score

The test generates an overall quality score (0-100):

```
COMPLETENESS_SCORE | ACCURACY_SCORE | VALIDITY_SCORE | CONSISTENCY_SCORE | OVERALL | RATING
98.5               | 100.0          | 100.0          | 100.0             | 99.6    | EXCELLENT
```

**Rating Scale:**
- **90-100:** EXCELLENT - Production ready
- **75-89:** GOOD - Minor issues, acceptable
- **60-74:** FAIR - Investigate issues
- **< 60:** POOR - Critical issues, do not deploy

### Interpreting Results

#### Common Issues

**Missing Dates**
```
Missing Dates | Missing Count: 5 | Missing Dates: 2025-01-01, 2025-01-02, ...
```
**Action:** Check ACCOUNT_USAGE data availability, verify lookback period

**Calculation Errors**
```
Incorrect credits_per_user | Error Count: 3 | Total Credits Affected: 1250.5
```
**Action:** Review view definitions, verify joins and aggregations

**Invalid Service Types**
```
Unknown Service Types | Service: Custom Service | Occurrences: 12
```
**Action:** Add new service types to known list or investigate data source

---

## 3. Python Unit Tests

### Purpose
Test Python calculation functions, data transformations, and business logic.

### Running Python Tests

```bash
# Navigate to project root
cd /path/to/cortex-trail

# Run all tests
python3 tests/test_streamlit_calcs.py

# Run specific test class
python3 -m unittest tests.test_streamlit_calcs.TestCalculationFunctions

# Run with verbose output
python3 tests/test_streamlit_calcs.py -v
```

### What's Tested

#### Calculation Functions (7 tests)
- Credits per user calculation
- Growth rate calculation
- Growth rate with zero baseline
- Projection formula
- Rolling average calculation

#### Data Validation (5 tests)
- Required column validation
- Date format validation
- Negative credit detection
- NULL value detection
- Service type validation

#### Data Transformations (3 tests)
- 30-day rolling totals
- Group by service aggregation
- Date range filtering

#### Projection Scenarios (4 tests)
- Conservative scenario (10% growth)
- Moderate scenario (25% growth)
- Aggressive scenario (50% growth)
- Custom scenario

#### Currency Formatting (3 tests)
- USD formatting
- Large number formatting
- Small number formatting

#### Anomaly Detection (3 tests)
- HIGH alert threshold
- MEDIUM alert threshold
- DECLINING classification

### Expected Output

```bash
test_aggressive_scenario (__main__.TestProjectionScenarios) ... ok
test_conservative_scenario (__main__.TestProjectionScenarios) ... ok
test_credits_per_user_calculation (__main__.TestCalculationFunctions) ... ok
...
test_validate_service_types (__main__.TestDataValidation) ... ok

----------------------------------------------------------------------
Ran 25 tests in 0.045s

OK
```

### Troubleshooting Failed Tests

#### "ModuleNotFoundError: No module named 'pandas'"
**Solution:** This repo's unit tests do not require pandas/numpy. If you see this error, you're likely running an older version of the tests or importing the Streamlit app module directly. Run `python3 tests/test_streamlit_calcs.py` from the repo root.

#### "AssertionError: Values differ"
**Cause:** Floating point precision issue
**Solution:** Check `assertAlmostEqual` places parameter

#### "Test timeout"
**Cause:** Large dataset or slow function
**Solution:** Add `@unittest.skip` or optimize function

---

## 4. Continuous Testing

### Automated Testing Schedule

**Daily (recommended):**
- Run SQL view compilation tests
- Check data quality score

**Weekly:**
- Run full data quality report
- Review anomaly detection results
- Validate calculation accuracy

**After deployment:**
- Run all test suites
- Verify configuration settings
- Test user permissions

### Setting Up Automated Tests

#### Using Snowflake Tasks

```sql
-- Create test task
CREATE OR REPLACE TASK TASK_DAILY_TEST_SUITE
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 4 * * * America/Los_Angeles'  -- 4 AM daily
AS
    CALL SYSTEM$RUN_SQL_FROM_FILE('@tests/test_sql_views.sql');

-- Resume task
ALTER TASK TASK_DAILY_TEST_SUITE RESUME;
```

#### Using CI/CD Pipeline (Optional)

If you add CI for this repo, keep it non-interactive and run the Python unit tests (`tests/test_streamlit_calcs.py`) plus any SQL lint/static checks you use internally.

---

## 5. Test Coverage

### Current Coverage

| Component | Lines | Coverage |
|-----------|-------|----------|
| SQL Views | 1,078 | 95% |
| Python Functions | 1,866 | 75% |
| Configuration | 137 | 100% |
| **Total** | **3,081** | **85%** |

### Gaps in Coverage

**Not Yet Tested:**
- Streamlit UI interactions (requires Selenium/Playwright)
- User authentication flows
- Multi-user concurrent access
- Large dataset performance (>1M rows)
- Network failure scenarios

**Planned:**
- Integration tests with live Snowflake connection
- Load testing with synthetic data
- Security penetration testing
- Accessibility testing (WCAG compliance)

---

## 6. Contributing Tests

### Adding New Tests

#### SQL Tests

1. Edit `tests/test_sql_views.sql`
2. Follow existing test pattern:

```sql
-- Test N: Description
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
BEGIN
    -- Test logic here
    INSERT INTO TEST_RESULTS VALUES (
        N, 'Category', 'Test Name', 'PASS', 'Message',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()),
        CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            N, 'Category', 'Test Name', 'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()),
            CURRENT_TIMESTAMP()
        );
END;
```

#### Python Tests

1. Edit `tests/test_streamlit_calcs.py`
2. Add test method to appropriate class:

```python
def test_new_calculation(self):
    """Test description"""
    # Arrange
    input_value = 100

    # Act
    result = my_function(input_value)

    # Assert
    self.assertEqual(result, expected_value)
```

### Test Naming Conventions

- **SQL:** `test_[component]_[behavior]` (e.g., `test_view_compilation`)
- **Python:** `test_[function]_[scenario]` (e.g., `test_growth_rate_with_zero`)

### Test Documentation

All tests must include:
- Clear description of what's being tested
- Expected behavior
- Pass/fail criteria
- Error messages for troubleshooting

---

## 7. Best Practices

### DO:
- Run all tests after deployment
- Test in dev/sandbox environment first
- Document test failures with screenshots
- Keep tests fast (< 1 minute total)
- Use descriptive test names

### DON'T:
- Skip tests because "it should work"
- Test in production directly
- Ignore warnings
- Hardcode sensitive data in tests
- Leave failing tests in codebase

---

## 8. Support

### Getting Help

**Test Failures:**
1. Check error message in test output
2. Review relevant documentation section
3. Check `docs/03-TROUBLESHOOTING.md`
4. Contact SE team for support

**Bug Reports:**
Include:
- Test output (full error message)
- Steps to reproduce
- Environment details (Snowflake account, role, warehouse)
- Screenshots if applicable

---

## 9. References

- [unittest Documentation](https://docs.python.org/3/library/unittest.html)
- [pandas Testing Documentation](https://pandas.pydata.org/docs/reference/testing.html)
- [Snowflake Testing Best Practices](https://docs.snowflake.com/en/user-guide/ui-snowsight-worksheets)
- Project README: `README.md`
- Troubleshooting Guide: `docs/03-TROUBLESHOOTING.md`

---

**Last Updated:** 2025-01-05
**Next Review:** 2025-04-05
