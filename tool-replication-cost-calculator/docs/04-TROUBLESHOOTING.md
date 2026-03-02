# Troubleshooting - Streamlit DR Replication Cost Calculator

## Pricing Issues

### Pricing table empty
- Verify deployment completed: `SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT;` (should be 48 rows)
- If empty, re-run the INSERT statements from `deploy_all.sql` starting at "SECTION 5: Seed Pricing Data"

### Need to update pricing rates
- Use the admin interface: Navigate to Streamlit app → "Admin: Manage Pricing"
- Must be SYSADMIN or ACCOUNTADMIN role
- See `docs/05-ADMIN.md` for detailed instructions

## Privilege Issues

### Insufficient Privileges Error
**Symptom:** `SQL access control error: Insufficient privileges to operate on...`

**Cause:** Missing grants on required objects

**Solutions:**

1. **For deployment (ACCOUNTADMIN required):**
   ```sql
   USE ROLE ACCOUNTADMIN;
   -- Re-run deploy_all.sql
   ```

2. **For regular usage (any user):**
   ```sql
   -- Objects are granted to PUBLIC, any role can access
   USE ROLE PUBLIC;
   SELECT
     SERVICE_TYPE,
     CLOUD,
     REGION,
     UNIT,
     RATE,
     CURRENCY
   FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT
   LIMIT 10;
   ```

3. **Grant ACCOUNT_USAGE access (if DB_METADATA view errors):**
   ```sql
   USE ROLE ACCOUNTADMIN;
   -- Prefer Snowflake database roles over broad IMPORTED PRIVILEGES.
   GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;
   ```

4. **Check specific object grants:**
   ```sql
   SHOW GRANTS TO ROLE PUBLIC;
   SHOW GRANTS ON SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC;
   ```

### Task Execution Failures
**This application no longer uses scheduled tasks.**

If you see references to `PRICING_REFRESH_TASK`, this is from an older version. The simplified version uses pre-loaded pricing rates that admins can update via the Streamlit interface.

## Streamlit App Issues

### Streamlit app cannot load pricing
- Ensure `PRICING_CURRENT` has rows: `SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT;`
- Check last update timestamp: `SELECT MAX(UPDATED_AT) FROM PRICING_CURRENT;`
- Verify Streamlit app was created:
  ```sql
  SHOW STREAMLITS IN SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC;
  ```
- Check app is loading from correct Git path:
  ```sql
  -- App should use: @SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO/branches/main/streamlit
  DESC STREAMLIT REPLICATION_CALCULATOR;
  ```
- Confirm PUBLIC has access:
  ```sql
  SHOW GRANTS ON STREAMLIT REPLICATION_CALCULATOR;
  ```

### Database list empty
**Symptom:** No databases appear in multiselect dropdown

**Cause:** Missing access to `SNOWFLAKE.ACCOUNT_USAGE`

**Solutions:**
1. Ensure SYSADMIN has the required SNOWFLAKE database role:
   ```sql
   USE ROLE ACCOUNTADMIN;
   GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;
   ```

2. Verify warehouse is running:
   ```sql
   ALTER WAREHOUSE SFE_REPLICATION_CALC_WH RESUME;
   SHOW WAREHOUSES LIKE 'SFE_REPLICATION_CALC_WH';
   ```

3. Test DB_METADATA view manually:
   ```sql
   -- Use any role (PUBLIC has access)
   SELECT
     DATABASE_NAME,
     SIZE_TB,
     AS_OF
   FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.DB_METADATA
   LIMIT 5;
   ```

### Data Staleness Warning
**Symptom:** Database sizes show old dates in `AS_OF` column

**Cause:** `TABLE_STORAGE_METRICS` updates with latency (up to a few hours)

**Solution:**
- This is normal; storage metrics have some latency
- The `AS_OF` column shows query execution time; storage metrics may lag by up to 3 hours
- For current estimates, use known database sizes

## Deployment Issues

### Expiration failure
- If `deploy_all.sql` aborts due to expiration (after 2026-04-10), extend or clone with a new expiration date per project policy.
- Update `SET DEMO_EXPIRES = '2026-04-10';` at top of script

### API Integration Already Exists
**Symptom:** `SQL compilation error: Object 'SFE_GIT_API_INTEGRATION' already exists`

**Solution:**
- This is expected and safe (idempotent)
- The script uses `CREATE OR REPLACE` for most objects
- Continue execution

### Role/Warehouse Name Conflicts
**Symptom:** Objects with `SFE_` prefix already exist from other demos

**Solution:**
- This is expected per demo standards
- `SFE_GIT_API_INTEGRATION` is shared across all demos
- Project-specific objects are in dedicated schema `REPLICATION_CALC`

## Performance Issues

### Slow Pricing Updates (Admin Panel)
**Symptom:** Saving pricing changes takes a long time

**Cause:** Large number of pricing entries or warehouse suspended

**Solutions:**
1. Ensure warehouse is running:
   ```sql
   ALTER WAREHOUSE SFE_REPLICATION_CALC_WH RESUME;
   ```
2. Consider increasing warehouse size for bulk updates:
   ```sql
   ALTER WAREHOUSE SFE_REPLICATION_CALC_WH SET WAREHOUSE_SIZE = SMALL;
   ```

### Streamlit App Slow to Load
**Solutions:**
1. Ensure warehouse is auto-resume enabled
2. Check database count (large account with 1000+ databases may be slow)
3. Use filtering in SQL if needed:
   ```sql
   -- Modify DB_METADATA view to filter system databases
   WHERE DATABASE_NAME NOT LIKE 'SNOWFLAKE%'
   ```

## Getting Additional Help

If issues persist:
1. Check Snowflake query history for detailed error messages
2. Verify all prerequisites in `docs/01-SETUP.md`
3. Review admin documentation in `docs/05-ADMIN.md` for pricing management
4. Consult Snowflake documentation for RBAC and account usage
