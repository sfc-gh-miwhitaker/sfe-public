# Usage - Streamlit DR Replication Cost Calculator (Business Critical)

## Launch the App

1. **Navigate to Streamlit**: Open Snowsight → Streamlit
2. **Find the app**: Look for `REPLICATION_CALCULATOR`
3. **Click to open**: The app loads automatically
4. **Wait for data load**: The app loads pricing and database metadata (a few seconds)

**Note**: Any Snowflake user can access the app (PUBLIC grants). No special permissions required.

## Using the Calculator

### Step 1: Check Pricing Status
- The app shows when pricing data was last updated
- Pricing rates are managed by administrators via the "Admin: Manage Pricing" page
- Users (with PUBLIC role) can view and use pricing but cannot modify it

### Step 2: Select Database(s)
- Choose one or more databases to replicate
- Sizes come from `ACCOUNT_USAGE.TABLE_STORAGE_METRICS` (latency can be a few hours)
- The app shows data staleness (last updated timestamp)

### Step 3: Choose Destination
- **Source**: Auto-detected from `CURRENT_REGION()`
- **Destination**: Pick target cloud provider and region from dropdown
- The app calculates cross-region and cross-cloud transfer costs

### Step 4: Set Change Parameters
- **Daily Change %**: Estimate how much data changes per day (default: 1%)
- **Refresh Cadence**: How often you'll refresh the replica (default: 1x per day)
- **Volume Calculation**: `transfer_size = database_size × change_rate × cadence`

### Step 5: Review Cost Breakdown

The calculator shows itemized costs:

| Cost Component | Description |
|----------------|-------------|
| **Data Transfer** | Network transfer from source → destination region |
| **Replication Compute** | Snowflake REPLICATION service credits |
| **Storage (Secondary)** | Storage cost in destination region |
| **Serverless (if any)** | MVs, search optimization costs |

**Daily and Monthly totals** are shown for budgeting.

### Step 6: Export Results
- Click **Download CSV** to export the cost breakdown
- CSV includes all assumptions and parameters for record-keeping

## Assumptions
- Business Critical pricing/features.
- Rates are baseline values that should be updated by administrators to reflect current pricing.
- Storage uses destination region pricing; data transfer uses source region pricing; replication compute uses Business Critical REPLICATION rate.

## Notes
- Pricing defaults are seeded by `deploy_all.sql`.
- If you need to reset pricing to defaults, re-run the seed INSERT statements in `deploy_all.sql` (SECTION 5).
