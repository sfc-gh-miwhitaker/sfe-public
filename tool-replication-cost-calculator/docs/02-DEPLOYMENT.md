# Deployment - Streamlit DR Replication Cost Calculator (Business Critical)

## One-Script Deployment (Snowsight)

**Total deployment time: ~5 minutes**

### Steps

1. **Open Snowsight**: Navigate to Worksheets
2. **Copy the script**: Open `deploy_all.sql` from the repository root
3. **Paste into Snowsight**: Create a new worksheet and paste the entire script
4. **Run All**: Click "Run All" button (or press Cmd/Ctrl + Enter repeatedly)

### What the Script Does

The `deploy_all.sql` script automatically:

#### Phase 1: Git Integration (ACCOUNTADMIN)
- Checks expiration date (expires 2026-04-10)
- Creates `SFE_GIT_API_INTEGRATION`
- Creates `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema
- Creates Git repository clone: `SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO`
- Fetches latest code from GitHub

#### Phase 2: Object Creation (SYSADMIN)
- Switches to SYSADMIN role
- Creates warehouse: `SFE_REPLICATION_CALC_WH`
- Creates schema: `SNOWFLAKE_EXAMPLE.REPLICATION_CALC`
- Creates Streamlit app: `REPLICATION_CALCULATOR` (created from Git repository clone)
- Creates table: `PRICING_CURRENT`
- Creates view: `DB_METADATA`
- Seeds pricing data (48 baseline rates for AWS/Azure/GCP)

#### Phase 3: Access Grants (SYSADMIN)
- Grants USAGE on warehouse to PUBLIC
- Grants SELECT on tables/views to PUBLIC
- Grants USAGE on Streamlit app to PUBLIC
- Grants `SNOWFLAKE.USAGE_VIEWER` database role to SYSADMIN (for ACCOUNT_USAGE access used by `DB_METADATA`)

### Verify Deployment

After "Run All" completes, you should see:

```
48 pricing rates loaded
```

**Note:** Database sizes are sourced from `SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS` (latency can be up to a few hours). The script grants SYSADMIN the `SNOWFLAKE.USAGE_VIEWER` database role so the `DB_METADATA` view can query `ACCOUNT_USAGE`.

Pricing rates are pre-loaded baseline values. Administrators can update them via the Streamlit app's "Admin: Manage Pricing" page.

### Next Steps

1. Navigate to Snowsight → Streamlit → `REPLICATION_CALCULATOR`
2. See `docs/03-USAGE.md` for how to use the calculator and admin features

## Updating Pricing (Optional)

Administrators (SYSADMIN or ACCOUNTADMIN) can update pricing rates through the Streamlit app:

1. Navigate to Snowsight → Streamlit → `REPLICATION_CALCULATOR`
2. Use sidebar to switch to "Admin: Manage Pricing"
3. Edit rates in the data editor
4. Click "Save Changes"

## Troubleshooting

If deployment fails, see `docs/04-TROUBLESHOOTING.md`.

## Cleanup

To remove all demo objects:

```sql
-- Copy and run sql/99_cleanup/99_drop_replication_calc.sql
```

This removes:
- Schema `SNOWFLAKE_EXAMPLE.REPLICATION_CALC` (CASCADE)
- Warehouse `SFE_REPLICATION_CALC_WH`
- Streamlit app `REPLICATION_CALCULATOR`
- Git repository clone `SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO`

**Preserved (shared infrastructure):**
- `SFE_GIT_API_INTEGRATION` (may be used by other demos)
- `SNOWFLAKE_EXAMPLE` database
- `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema
