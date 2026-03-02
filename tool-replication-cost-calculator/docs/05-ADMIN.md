# Admin: Pricing Management

## Accessing Admin Panel

Only **SYSADMIN** and **ACCOUNTADMIN** roles can update pricing rates.

1. **Navigate to the Streamlit app**: Snowsight → Streamlit → `REPLICATION_CALCULATOR`
2. **Use sidebar navigation**: Click "Admin: Manage Pricing"
3. **Verify your role**: The admin panel shows your current role

## Managing Pricing Rates

### View Current Pricing
The admin panel displays all pricing rates in an editable table with columns:
- **SERVICE_TYPE**: Type of service (DATA_TRANSFER, REPLICATION_COMPUTE, STORAGE_TB_MONTH, SERVERLESS_MAINT)
- **CLOUD**: Cloud provider (AWS, AZURE, GCP)
- **REGION**: Region name (e.g., us-east-1, eastus2, us-central1)
- **UNIT**: Billing unit (TB, TB_MONTH)
- **RATE**: Cost in credits
- **CURRENCY**: Always CREDITS

### Edit Pricing Rates

1. **Click on any cell** to edit the value
2. **Add new rows** using the "+" button at the bottom of the table
3. **Delete rows** by selecting them and using the delete button
4. **Click "Save Changes"** to persist your updates to the database

**Important:** Changes are applied immediately upon saving and will affect all users' cost calculations.

### Reset to Defaults

If you need to restore baseline pricing:

1. Run the INSERT statements from `deploy_all.sql` in a SQL worksheet (SECTION 5: Seed Pricing Data)

## Pricing Data Structure

Each pricing entry must include:
- **SERVICE_TYPE**: One of:
  - `DATA_TRANSFER`: Network transfer costs between regions
  - `REPLICATION_COMPUTE`: Compute costs for replication operations
  - `STORAGE_TB_MONTH`: Monthly storage costs per TB
  - `SERVERLESS_MAINT`: Monthly maintenance costs for serverless features

- **CLOUD**: Cloud provider code (AWS, AZURE, GCP)
- **REGION**: Region identifier (use format from CURRENT_REGION())
- **RATE**: Positive number representing credits per unit

## Best Practices

1. **Document changes**: Keep a record of pricing updates and their source
2. **Verify rates**: Cross-reference with Snowflake's official pricing documentation
3. **Test calculations**: After updating, run a sample calculation to verify results
4. **Backup current rates**: Export the current pricing table before major updates:
   ```sql
   CREATE TABLE PRICING_BACKUP AS
   SELECT
     SERVICE_TYPE,
     CLOUD,
     REGION,
     UNIT,
     RATE,
     CURRENCY,
     UPDATED_AT,
     UPDATED_BY
   FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT;
   ```

## Troubleshooting

### "You must use SYSADMIN or ACCOUNTADMIN role"
- Switch to SYSADMIN or ACCOUNTADMIN role in Snowsight
- Refresh the app to re-detect your role

### "Failed to update pricing"
- Verify you have INSERT/UPDATE/DELETE privileges on PRICING_CURRENT table
- Check that all required columns are populated
- Ensure RATE values are positive numbers

### Changes Not Reflecting
- Pricing changes are immediate - try refreshing the calculator page
- Verify the save operation completed successfully
