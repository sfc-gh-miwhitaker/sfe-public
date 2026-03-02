# Getting Started: Cortex Cost Calculator

**Professional cost tracking and forecasting for Snowflake Cortex workloads**

**Time to Deploy:** 15 minutes
**Value:** Accurate cost projections, budget planning, multi-scenario analysis

---

## What You'll Build

Deploy this toolkit and you'll have:

- **Real-time tracking** - 22 views (monitoring + attribution + forecast outputs)
- **Historical snapshots** - Automated daily captures with trend analysis
- **Cost projections** - Forecasting (manual projections + optional ML forecast)
- **Interactive calculator** - Streamlit app deployed from Git
- **Query-level analysis** - Identify expensive individual queries
- **Export-ready estimates** - For proposals and finance teams

---

## Two Ways to Use This Tool

### For Solution Engineers (Two-Account Workflow)

```
Customer Account -> Deploy Monitoring -> Wait 7-14 days -> Extract CSV
        |
        v
Your Account -> Deploy Calculator -> Upload CSV -> Generate Estimates -> Sales Team
```

**Time Investment:**
- One-time setup in your account: 10 minutes
- Per-customer analysis: 5-10 minutes

**Benefits:**
- One calculator handles unlimited customers
- Professional, repeatable cost estimates
- No data leaves customer's Snowflake account
- Export-ready for proposals

### For Customers (Self-Service)

```
Your Account -> Deploy Monitoring + Calculator -> Real-time Analysis -> Budget Planning
```

**Time Investment:**
- Initial setup: 15 minutes
- Ongoing analysis: Instant

**Benefits:**
- Ongoing cost visibility
- Track actual vs projected
- Department cost allocation
- Finance team self-service

---

## Prerequisites

Before starting, ensure you have:

- Snowflake account with Cortex usage (ideally 7-14 days of history)
- `ACCOUNTADMIN` role OR role with `IMPORTED PRIVILEGES` on `SNOWFLAKE` database
- Active warehouse for running queries
- Access to Snowsight (Snowflake web UI)

### Quick Access Test

Run this query to verify you have the required permissions:

```sql
SELECT COUNT(*)
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -7, CURRENT_DATE());
```

**Expected:** A number (even if 0) - not an error message

**If error:** Grant privileges first:
```sql
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;
```

---

## Quick Deployment (Recommended)

**Option A: Deploy Everything in One Step (~2 minutes)**

Copy/paste [`deploy_all.sql`](../deploy_all.sql) into Snowsight -> Click "Run All"

This deploys:
- API Integration for GitHub access
- Git Repository with project code
- 22 views (monitoring + attribution + forecast outputs)
- Snapshot table + serverless task
- Streamlit calculator app

**Skip to Step 3 below after deployment completes.**

---

## Step-by-Step Deployment (Alternative)

**Option B: Deploy Monitoring First, Then Calculator (~3-5 minutes)**

### Step 1: Deploy Monitoring Views (~1 minute)

This creates 21 read-only views that track Cortex service usage and expose rollups for the calculator.

### 1.1 Access Snowflake

1. Navigate to [https://app.snowflake.com](https://app.snowflake.com)
2. Log in with your credentials
3. Click **Worksheets** in the left navigation
4. Create a new worksheet

### 1.2 Run Deployment Script

1. Open `sql/01_deployment/deploy_cortex_monitoring.sql` from this project
2. Copy the entire file contents
3. Paste into your Snowflake worksheet
4. Click **"Run All"** (or press `Ctrl+Enter` to run all statements)

### 1.3 Verify Deployment

Watch for these success messages:

- Database `SNOWFLAKE_EXAMPLE` created
- Schema `CORTEX_USAGE` created
- 22 views created successfully (monitoring + attribution + forecast outputs)
- Validation queries showing row counts

**What got created:**
```
SNOWFLAKE_EXAMPLE.CORTEX_USAGE
- V_CORTEX_DAILY_SUMMARY           (main rollup view)
- V_CORTEX_COST_EXPORT             (export-ready for calculator / CSV workflow)
- V_USER_SPEND_ATTRIBUTION         (user -> service -> feature -> model attribution, where available)
- V_CORTEX_USAGE_HISTORY           (snapshot-backed history view for faster queries)
- V_USAGE_FORECAST_12M             (forecast output view; may be empty if model unavailable)
```

Note: Views may show 0 rows if:
- No Cortex usage in last 90 days
- Data latency (wait 3 hours after usage)
- This is normal and won't prevent deployment

---

## Step 2: Deploy Calculator (5 minutes)

Deploy the interactive Streamlit calculator in Snowflake.

### 2.1 Create Streamlit App

In Snowsight:

1. Click **"Projects"** in left navigation
2. Click **"Streamlit"**
3. Click **"Apps"**
4. Click **"+ Streamlit App"** button (top right)

### 2.2 Configure App

Fill in the form:

| Field | Value | Notes |
|-------|-------|-------|
| **App name** | `CORTEX_COST_CALCULATOR` | Or your preferred name |
| **App location** | `SNOWFLAKE_EXAMPLE.CORTEX_USAGE` | Must match where views were deployed |
| **Warehouse** | Select your warehouse | SMALL is sufficient |

### 2.3 Add Application Code

1. Open `streamlit/cortex_cost_calculator/streamlit_app.py` from this project
2. Copy the **entire file contents**
3. In Snowflake, paste into the code editor (replacing the default code)

### 2.4 Add Package Dependencies

1. Click the **"Packages"** tab in the Snowflake editor
2. Open `streamlit/cortex_cost_calculator/environment.yml` from this project
3. Copy the dependencies section
4. Add the packages to the Snowflake packages field

### 2.5 Launch the App

1. Click **"Create"** button (bottom right)
2. Wait 30 seconds for the app to initialize
3. The app will automatically launch when ready

**Success!** You now have a fully functional cost calculator.

---

## Step 3: Analyze Your Costs (5 minutes)

Now let's use the calculator to understand your Cortex spending.

### 3.1 Configure Data Source

In the calculator sidebar:

**For same-account deployment (customers):**
- **Data Source:** Select **"Query Views (Same Account)"**
- **Lookback Period:** 30 days (adjust as needed)
- **Credit Cost:** Update to your actual credit price (default: $3.00)

**For SE workflow (analyzing customer data):**
- **Data Source:** Select **"Upload Customer CSV"**
- Upload the CSV file extracted from customer account
- Credit cost will be configured per analysis

### 3.2 Review Historical Analysis

Click the **"Historical Analysis"** tab:

**You'll see:**
- **Summary metrics:** Total credits, total cost, avg daily usage
- **Service breakdown:** Which services consume the most credits
- **Usage trends:** Daily credit consumption over time
- **Service distribution:** Pie chart showing cost allocation

**Use this to:**
- Validate data quality
- Understand current spending patterns
- Identify which services drive costs
- Detect usage anomalies

### 3.3 Generate Cost Projections

Click the **"Cost Projections"** tab:

**Configure projections:**
1. **Projection Period:** Choose 3, 6, 12, or 24 months
2. **Monthly Growth Rate:** Use slider (0-100%)
3. **Pre-defined scenarios:**
   - **Conservative (10%):** Steady adoption, existing use cases
   - **Moderate (25%):** Active expansion, new features
   - **Aggressive (50%):** Rapid rollout, multiple teams
   - **Rapid (100%):** Explosive growth, company-wide adoption

**You'll see:**
- **Month 1 vs Month 12 costs**
- **Total year cost** with variance range
- **Interactive chart** with confidence bands
- **Monthly breakdown table**

### 3.4 Model User Personas (Cost per User Calculator)

Scroll down to the **"Cost per User Calculator"** section:

**Define your user types:**
1. **Add/Edit Personas:**
   - Provide: persona name, user count, and requests per day
   - Use "Add Another Persona" to add more
   - Use "Remove" to delete a persona

2. **Set Baseline Usage:**
   - The calculator uses your historical telemetry (when available) as the baseline for cost-per-request
   - You can optionally toggle to use official published rates for Cortex Analyst

**You'll see:**
- **Total users** across all personas
- **Total monthly cost** breakdown
- **Per-persona costs** with detailed tables
- **Budget capacity** with scaling options

**Use this for:**
- Modeling 10-30 test users with different usage patterns
- Department cost allocation
- Optimizing user mix for budget constraints

### 3.5 Export Estimates

Click the **"Summary Report"** tab:

1. Review **credit breakdown by service**
2. Click **"Download Credit Estimate (CSV)"**
3. Open in Excel for proposals or budget documents

**The CSV includes:**
- Service-by-service breakdown
- Daily and monthly projections
- Cost estimates at current credit price
- Notes on methodology

---

## Troubleshooting

### No Data Showing

**If views return 0 rows:**

1. **Check if Cortex has been used:**
   ```sql
   SELECT
     usage_date,
     service_type,
     credits_used
   FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
   WHERE service_type = 'AI_SERVICES'
   ORDER BY usage_date DESC
   LIMIT 10;
   ```

2. **Wait for data latency:** ACCOUNT_USAGE has 45 min - 3 hour delay

3. **Extend lookback period:** Edit the deployment script to use 180 days instead of 90

### Permission Errors

**Error: "Object does not exist"**

Solution:
```sql
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;
```

### Calculator Won't Load

**Troubleshooting steps:**

1. **Verify warehouse is running**
   - Check warehouse status in Snowsight
   - Resume warehouse if suspended

2. **Check app location matches deployment**
   - App location: `SNOWFLAKE_EXAMPLE.CORTEX_USAGE`
   - Views location: Same path

3. **Refresh browser**
   - Clear cache and reload
   - Try incognito/private window

### Need More Help?

See **`help/TROUBLESHOOTING.md`** for comprehensive issue resolution including:
- Detailed diagnostics
- Permission configurations
- Performance optimization
- Data quality validation

---

## What's Next?

### Use the Calculator Regularly

- **Monthly:** Review actual usage vs projections
- **Quarterly:** Update growth assumptions based on actuals
- **For budgets:** Export estimates for finance team
- **For planning:** Use scenario comparison for capacity planning

### Share with Your Team

Grant access to colleagues:

```sql
-- Grant view access
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <ROLE_NAME>;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE TO ROLE <ROLE_NAME>;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE TO ROLE <ROLE_NAME>;

-- Grant Streamlit app access
GRANT USAGE ON STREAMLIT CORTEX_COST_CALCULATOR TO ROLE <ROLE_NAME>;
```

### Explore Advanced Features

- **Multi-persona modeling:** Model complex org structures
- **Custom scenarios:** Build specific growth projections
- **Budget capacity planning:** Determine user limits within budget
- **Service-level analysis:** Dive deep into per-service costs

### Learn More

- **Complete guide:** See `README.md` for full documentation
- **Detailed walkthrough:** See `help/DEPLOYMENT_WALKTHROUGH.md` for video script
- **Troubleshooting:** See `help/TROUBLESHOOTING.md` for issue resolution
- **Snowflake docs:** [Cortex Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)

---

## Cleanup (When Finished)

To remove all monitoring objects:

```sql
-- Run cleanup script
@sql/99_cleanup/cleanup_cortex_monitoring.sql
```

**Choose one option:**
1. **Drop views only** - Keeps schema for future use
2. **Drop schema** - Removes all monitoring objects
3. **Drop database** - Complete removal

All cleanup is safe and reversible by re-running the deployment script.

---

## Success Stories

### Solution Engineer Workflow
*"Deployed monitoring in 3 customer accounts during POCs. At the end, extracted CSVs and generated professional cost estimates in minutes. Sales team loved the multi-scenario projections."*

### Customer Self-Service
*"Finance team reviews the calculator monthly to track Cortex spend against budget. The service breakdown helps us understand where credits are going."*

### Multi-Persona Modeling
*"We have 5 data scientists, 15 analysts, and 30 business users. The persona calculator showed us that 5 data scientists cost as much as 30 business users combined! Helped us plan training and onboarding by user type."*

---

## Value Proposition

### Before This Tool
- Manual SQL queries per customer
- Hours of Excel calculations
- Inconsistent methodologies
- Basic, single-scenario projections

### After This Tool
- Automated tracking and projections
- 5-10 minutes per analysis
- Professional, repeatable process
- Multi-scenario, multi-persona modeling
- Export-ready estimates

**ROI:** Save 2-4 hours per customer engagement

---

## Key Features

| Feature | Benefit |
|---------|---------|
| **Historical Analysis** | Interactive charts showing usage trends and service breakdown |
| **Cost Projections** | 4 growth scenarios (Conservative to Rapid) plus custom builder |
| **Multi-Persona Modeling** | Model teams with 10-30 different users and usage patterns |
| **Budget Capacity Planning** | Determine how many users you can support within budget |
| **Credit Estimates** | Export-ready CSV for sales teams and finance departments |
| **Real-time Monitoring** | Query views directly or upload customer CSV files |
| **Non-disruptive** | Read-only views, zero impact on production workloads |

---

## Technical Highlights

- **Data Source:** Snowflake `ACCOUNT_USAGE` views (authoritative billing data)
- **Technology:** Streamlit in Snowflake (no external hosting)
- **Security:** Data never leaves your Snowflake account
- **Architecture:** 9 read-only views + interactive calculator
- **Deployment:** Idempotent, safe to re-run
- **Cleanup:** Complete removal in seconds

---

## Questions?

- **Setup issues?** See `help/TROUBLESHOOTING.md`
- **Need details?** See `README.md` for complete documentation
- **Want video walkthrough?** See `help/DEPLOYMENT_WALKTHROUGH.md`
- **Snowflake questions?** Contact your Solutions Engineer

---

**Version:** 1.3
**Last Updated:** October 22, 2025
**Maintained by:** Snowflake Solutions Engineering

---

*"From zero to cost projections in 15 minutes."*
