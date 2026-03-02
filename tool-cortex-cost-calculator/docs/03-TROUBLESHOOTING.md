# Troubleshooting Guide: Cortex Cost Tracking Pipeline

Common issues and their solutions for deployment, extraction, and calculation.

## Table of Contents
- [Deployment Issues](#deployment-issues)
- [Permission Errors](#permission-errors)
- [Data Quality Issues](#data-quality-issues)
- [Calculator Issues](#calculator-issues)
- [Performance Issues](#performance-issues)

---

## Deployment Issues

### Issue: "Database already exists" Error

**Symptoms:**
```
SQL compilation error: Database 'SNOWFLAKE_EXAMPLE' already exists.
```

**Cause:** Database exists from previous deployment or other use.

**Solution:**
```sql
-- The deployment script uses CREATE OR REPLACE for views
-- and IF NOT EXISTS for database/schema, so this shouldn't happen.
-- If it does, manually use the existing database:

USE DATABASE SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS CORTEX_USAGE;

-- Then continue with view creation
```

**Prevention:** Script already handles this - ensure you're using latest version.

---

### Issue: Views Not Created

**Symptoms:**
- SHOW VIEWS returns fewer than 22 views
- Some views missing

**Diagnosis:**
```sql
-- Check which views exist
SHOW VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Check for errors in recent queries
SELECT
    query_text,
    error_code,
    error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE user_name = CURRENT_USER()
    AND start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    AND error_code IS NOT NULL
ORDER BY start_time DESC;
```

**Solution:**
1. Review error messages
2. Verify ACCOUNT_USAGE access
3. Re-run deployment script (idempotent)
4. Check warehouse has sufficient resources

---

### Issue: Script Execution Timeout

**Symptoms:**
- Script stops mid-execution
- Not all views created
- Timeout error message

**Solution:**
```sql
-- Increase statement timeout
ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 3600;

-- Use larger warehouse
USE WAREHOUSE <LARGE_WAREHOUSE>;

-- Re-run deployment
@sql/01_deployment/deploy_cortex_monitoring.sql
```

---

## Permission Errors

### Issue: "Object does not exist" - ACCOUNT_USAGE

**Symptoms:**
```
SQL compilation error:
Object 'SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY' does not exist
or not authorized.
```

**Cause:** No access to ACCOUNT_USAGE views.

**Solution:**
```sql
-- Must be run as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Grant to your role
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;

-- Verify
USE ROLE <YOUR_ROLE>;
SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY LIMIT 1;
```

**Alternative:** Run entire deployment as ACCOUNTADMIN.

---

### Issue: "Insufficient Privileges to Operate on Database"

**Symptoms:**
```
Insufficient privileges to operate on database 'SNOWFLAKE_EXAMPLE'
```

**Cause:** Role lacks CREATE DATABASE privilege.

**Solution:**
```sql
-- As ACCOUNTADMIN or role with privilege
GRANT CREATE DATABASE ON ACCOUNT TO ROLE <YOUR_ROLE>;

-- Or create database first as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
GRANT OWNERSHIP ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <YOUR_ROLE>;
```

---

### Issue: Users Can't Query Views

**Symptoms:**
- Deployment successful
- Other users get permission errors querying views

**Solution:**
```sql
-- As ACCOUNTADMIN or database owner
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <USER_ROLE>;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE TO ROLE <USER_ROLE>;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE
TO ROLE <USER_ROLE>;
```

---

## Data Quality Issues

### Issue: Empty Results / No Data

**Symptoms:**
- Views created successfully
- Queries return 0 rows

**Diagnosis:**
```sql
-- Check if ANY Cortex usage exists
SELECT
    service_type,
    usage_date,
    SUM(credits_used) as credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY service_type, usage_date
ORDER BY usage_date DESC;

-- Check specific service histories
SELECT COUNT(*) as analyst_records
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY;

SELECT COUNT(*) as functions_records
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY;
```

**Solutions:**

1. **No Cortex Usage Yet**
   - Expected if Cortex hasn't been used
   - Minimum 7-14 days of usage recommended
   - Test with sample Cortex queries

2. **Data Latency**
   - ACCOUNT_USAGE has 45 min - 3 hour delay
   - Wait and re-query
   - Use more recent date range

3. **Lookback Period Too Short**
   ```sql
   -- Increase lookback in extraction query
   SET lookback_days = 90;  -- Default is 90, can adjust
   ```

---

### Issue: Partial Data / Missing Services

**Symptoms:**
- Some services show data
- Others return empty

**Diagnosis:**
```sql
-- Check which services have data
SELECT
    'Analyst' as service,
    COUNT(*) as records,
    MIN(start_time) as earliest,
    MAX(start_time) as latest
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY

UNION ALL

SELECT
    'Search',
    COUNT(*),
    MIN(usage_date),
    MAX(usage_date)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY

UNION ALL

SELECT
    'Functions',
    COUNT(*),
    MIN(start_time),
    MAX(start_time)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY

UNION ALL

SELECT
    'Document AI',
    COUNT(*),
    MIN(start_time),
    MAX(start_time)
FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY;
```

**Solution:** This is expected if only certain services are used. Not an error.

---

### Issue: Inconsistent User Counts

**Symptoms:**
- Daily unique users = 0 for some services
- User counts seem low

**Cause:** Some ACCOUNT_USAGE views don't include user-level detail.

**Expected Behavior:**
- User tracking: Analyst, Functions (query-level), Document AI
- No user tracking: Search (service-level aggregates only)

**Solution:**
```sql
-- Verify which views have user info
SELECT
    'Has user_name' as check_type,
    COUNT(*) as records
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE user_name IS NOT NULL

UNION ALL

SELECT
    'Search (no users)',
    COUNT(*)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY;
```

This is a data limitation, not a bug. Update projections accordingly.

---

### Issue: Credits Don't Match Expected Costs

**Symptoms:**
- Credit totals seem too high/low
- Costs don't align with Snowflake bills

**Investigation:**
```sql
-- Compare monitoring view totals to metering
SELECT
    'Monitoring Views' as source,
    SUM(total_credits) as credits
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())

UNION ALL

SELECT
    'METERING_DAILY_HISTORY',
    SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -30, CURRENT_DATE());
```

**Possible Causes:**
1. Different date ranges
2. Data latency (metering more delayed)
3. Rounding differences
4. Credit price assumptions incorrect

**Solution:**
- Use actual credit price from Snowflake contract
- Validate against actual billing data
- Document projections as estimates with variance

---

## Calculator Issues

### Issue: Import Errors When Running Streamlit

**Symptoms:**
```
ModuleNotFoundError: No module named 'streamlit'
ModuleNotFoundError: No module named 'plotly'
```

**Solution:**
```bash
cd streamlit/cortex_cost_calculator

# Install requirements
pip install -r requirements.txt

# If pip conflicts, use virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Run app
streamlit run app.py
```

---

### Issue: "Missing Required Columns" Error

**Symptoms:**
- Data uploaded to calculator
- Error: "Missing required columns: DATE, SERVICE_TYPE, TOTAL_CREDITS"

**Cause:** Data format doesn't match expected schema.

**Solution:**

1. **Verify Source Query**
   - Ensure using `extract_metrics_for_calculator.sql`
   - Don't modify column names in export

2. **Check CSV Format**
   ```csv
   DATE,SERVICE_TYPE,TOTAL_CREDITS,...
   2025-10-15,Cortex Functions,150.5,...
   ```

3. **Case Sensitivity**
   - Column names must be UPPERCASE
   - If lowercase, calculator will try to convert

4. **Manual Column Rename**
   ```python
   # In data_parser.py, already handles this
   df.columns = df.columns.str.upper()
   ```

---

### Issue: Date Parsing Errors

**Symptoms:**
```
Error parsing DATE column: [date value] does not match format
```

**Solution:**

1. **Verify Date Format in Export**
   ```sql
   -- In extraction query, ensure proper format
   SELECT
       TO_CHAR(date, 'YYYY-MM-DD') as date,  -- Force format
       ...
   ```

2. **Adjust Parser** (if needed)
   ```python
   # In data_parser.py
   df['DATE'] = pd.to_datetime(df['DATE'], format='%Y-%m-%d')
   ```

---

### Issue: Snowflake Connection Fails in Calculator

**Symptoms:**
- "Connect to Snowflake" option fails
- Authentication errors

**Solutions:**

1. **Check Credentials**
   - Verify account identifier format: `<account>.<region>`
   - Username is case-sensitive
   - Password correct

2. **Network Issues**
   ```python
   # Test connection separately
   from snowflake.connector import connect

   conn = connect(
       account='<account>',
       user='<user>',
       password='<password>'
   )
   print("Connected!")
   conn.close()
   ```

3. **Firewall/VPN**
   - Some networks block Snowflake connections
   - Try from different network
   - Use CSV upload instead

---

### Issue: Charts Not Displaying

**Symptoms:**
- Calculator loads data
- Charts are blank or missing

**Diagnosis:**
```python
# Check Plotly installation
import plotly
print(plotly.__version__)

# Should be >= 5.17.0
```

**Solution:**
```bash
pip install plotly --upgrade
pip install kaleido  # For static image export

# Restart Streamlit
streamlit run app.py
```

---

## Performance Issues

### Issue: View Queries Are Slow

**Symptoms:**
- Queries take minutes to complete
- High credit consumption

**Diagnosis:**
```sql
-- Check query profile
SELECT
    query_id,
    query_text,
    total_elapsed_time,
    bytes_scanned,
    partitions_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%V_CORTEX_%'
    AND start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC;
```

**Solutions:**

1. **Use Larger Warehouse**
   ```sql
   USE WAREHOUSE <LARGE_WH>;
   ```

2. **Reduce Date Range**
   ```sql
   -- Instead of 90 days
   SET lookback_days = 30;
   ```

3. **Add Filters**
   ```sql
   -- Filter by specific service
   SELECT
       usage_date,
       service_type,
       daily_unique_users,
       total_operations,
       total_credits,
       credits_per_user,
       credits_per_operation
   FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
   WHERE service_type = 'Cortex Functions'
       AND usage_date >= DATEADD('day', -7, CURRENT_DATE());
   ```

4. **Materialized Views** (for frequent access)
   ```sql
   -- Create materialized view for better performance
   CREATE MATERIALIZED VIEW V_CORTEX_DAILY_SUMMARY_MAT AS
   SELECT
       usage_date,
       service_type,
       daily_unique_users,
       total_operations,
       total_credits,
       credits_per_user,
       credits_per_operation
   FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY;

   -- Query the materialized version
   SELECT
       usage_date,
       service_type,
       daily_unique_users,
       total_operations,
       total_credits,
       credits_per_user,
       credits_per_operation
   FROM V_CORTEX_DAILY_SUMMARY_MAT;
   ```

---

### Issue: Calculator Slow to Load Data

**Symptoms:**
- Large CSV upload takes long time
- Calculator becomes unresponsive

**Solutions:**

1. **Reduce Data Volume**
   ```sql
   -- Export less data
   SET lookback_days = 30;  -- Instead of 90

   -- Or aggregate before export
   SELECT
       DATE_TRUNC('week', date) as week,
       service_type,
       SUM(total_credits) as weekly_credits,
       AVG(daily_unique_users) as avg_users
   FROM V_CORTEX_COST_EXPORT
   GROUP BY 1, 2
   ```

2. **Use Compression**
   ```bash
   # Compress CSV before upload
   gzip metrics.csv

   # Calculator can read gzipped files
   ```

3. **Optimize Calculator**
   ```bash
   # Run with more memory
   streamlit run app.py --server.maxUploadSize 200
   ```

---

## Advanced Troubleshooting

### Enable Debug Logging

**SQL Queries:**
```sql
-- Enable query logging
ALTER SESSION SET LOG_LEVEL = 'DEBUG';

-- Run problematic query
SELECT
    usage_date,
    service_type,
    daily_unique_users,
    total_operations,
    total_credits,
    credits_per_user,
    credits_per_operation
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY;

-- Check logs
SELECT
    query_id,
    query_text,
    start_time,
    end_time,
    execution_status,
    error_message,
    total_elapsed_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION())
ORDER BY start_time DESC;
```

**Streamlit Calculator:**
```bash
# Run with verbose logging
streamlit run app.py --logger.level=debug
```

### Generate Support Bundle

```sql
-- Export diagnostic information
SELECT
    CURRENT_ACCOUNT() as account,
    CURRENT_REGION() as region,
    CURRENT_ROLE() as role,
    CURRENT_WAREHOUSE() as warehouse,
    CURRENT_VERSION() as version;

-- Check view definitions
SELECT
    table_name,
    view_definition
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'CORTEX_USAGE';

-- Recent query history
SELECT
    query_id,
    query_text,
    execution_status,
    error_message,
    total_elapsed_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%CORTEX%'
    AND start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

---

## Getting Help

### Before Contacting Support

1. Review this troubleshooting guide
2. Check Snowflake documentation
3. Verify permissions and access
4. Test in sandbox/dev environment
5. Gather error messages and query IDs

### Information to Provide

When requesting support, include:

- Snowflake account identifier
- Role being used
- Full error message
- Query ID (from error or query history)
- Screenshots of issue
- Steps to reproduce
- What you've already tried

### Contact

- **Internal:** Snowflake Solutions Engineering team
- **Customers:** Your assigned Solutions Engineer
- **Documentation:** Snowflake docs at docs.snowflake.com

---

## Common Error Reference

| Error Message | Cause | Solution |
|--------------|-------|----------|
| Object does not exist or not authorized | No ACCOUNT_USAGE access | Grant IMPORTED PRIVILEGES |
| Insufficient privileges | Role lacks privileges | Grant required privileges or use ACCOUNTADMIN |
| Statement reached its timeout | Query too slow | Use larger warehouse or reduce date range |
| Missing required columns | Wrong data format | Use provided extraction query |
| ModuleNotFoundError | Python packages not installed | pip install -r requirements.txt |
| Connection refused | Network/firewall issue | Check network, use CSV upload |
| View already exists | Re-running deployment | Expected - views use CREATE OR REPLACE |
| Empty result set | No Cortex usage yet | Wait for usage or extend lookback period |

---

**Last Updated:** October 16, 2025
**Version:** 1.0
