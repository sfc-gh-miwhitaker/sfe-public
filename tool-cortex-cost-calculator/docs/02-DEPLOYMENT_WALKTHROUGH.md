# Deployment Walkthrough: Cortex Cost Calculator

**A step-by-step guide for deploying and using the Cortex Cost Calculator**

*This document serves as a script for video walkthroughs or live demonstrations.*

---

## Overview

**What we'll cover:**
1. Deploy monitoring views (5 minutes)
2. Verify data collection (2 minutes)
3. Deploy Streamlit calculator (3 minutes)
4. Analyze usage and generate projections (5 minutes)
5. Export credit estimates (2 minutes)

**Total time:** 15-20 minutes
**Note:** Monitoring should run for 7-14 days to collect meaningful usage data

**Audience:** Solution Engineers and customers deploying for the first time

---

## Pre-Flight Checklist

Before starting, verify:

- Access to Snowflake account (Snowsight or SnowSQL)
- `ACCOUNTADMIN` role or role with `IMPORTED PRIVILEGES` on `SNOWFLAKE` database
- Active warehouse
- This repository downloaded or cloned

---

## Part 1: Deploy Monitoring Views (5 minutes)

### Step 1.1: Access Snowflake

**Snowsight UI:**
1. Navigate to [https://app.snowflake.com](https://app.snowflake.com)
2. Log in with your credentials
3. Select **Worksheets** from left navigation

**What to say:**
> "Let's start by logging into Snowflake. We'll use Snowsight, Snowflake's web interface, for this deployment. Navigate to the Worksheets section where we can run SQL queries."

### Step 1.2: Verify Prerequisites

Create a new worksheet and run:

```sql
-- Verify ACCOUNT_USAGE access
SELECT COUNT(*)
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -7, CURRENT_DATE());
```

**Expected result:** A number (even if 0) - not an error

**If error occurs:**
```sql
-- Grant privileges (requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <YOUR_ROLE>;
```

**What to say:**
> "First, let's verify we have access to Snowflake's ACCOUNT_USAGE views. These views contain the billing and usage data we need for cost analysis. If you get a permissions error, we'll need to grant IMPORTED PRIVILEGES on the SNOWFLAKE database."

### Step 1.3: Deploy Monitoring Views

1. Open `sql/01_deployment/deploy_cortex_monitoring.sql` in a text editor
2. Copy the entire file contents
3. Paste into a new Snowflake worksheet
4. Click **"Run All"** or press `Ctrl+A` then `Ctrl+Enter`

**Watch for:**
- Database creation confirmation
- Schema creation confirmation
- 21 view creation statements completing (monitoring + attribution + forecast outputs)
- Validation queries at the end

**What to say:**
> "Now we'll deploy the monitoring infrastructure. This script creates a database called SNOWFLAKE_EXAMPLE, a schema called CORTEX_USAGE, and 22 views (monitoring + attribution + forecast outputs). The script is idempotent, meaning it's safe to run multiple times."

> "The deployment creates read-only views that query Snowflake's ACCOUNT_USAGE. There's no data copying, no tables created, just views. This is completely non-disruptive to your production workloads."

### Step 1.4: Verify Deployment

At the end of the script, check validation output:

```sql
-- You should see output like this:
OK: Database and schema created
OK: View V_CORTEX_ANALYST_DETAIL: X rows
OK: View V_CORTEX_SEARCH_DETAIL: Y rows
...
```

**If views show 0 rows:**
- This is normal if Cortex hasn't been used yet
- Data latency: Wait 3 hours after Cortex usage
- Check lookback period (default: 90 days)

**What to say:**
> "The validation section shows us whether each view was created successfully and how many rows of data are available. If you see zero rows, that's okay - it just means you haven't used Cortex services in the last 90 days, or there's a data latency delay."

---

## Part 2: Verify Data Collection (2 minutes)

### Step 2.1: Check Available Data

Query the summary view:

```sql
SELECT
    service_type,
    MIN(usage_date) AS first_date,
    MAX(usage_date) AS last_date,
    SUM(total_credits) AS total_credits,
    COUNT(DISTINCT usage_date) AS days_active
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
GROUP BY service_type
ORDER BY total_credits DESC;
```

**What to say:**
> "Let's check what data we have available. This query shows us which Cortex services have been used, the date range of available data, and how many credits have been consumed."

### Step 2.2: Review Sample Data

```sql
SELECT
    date,
    service_type,
    daily_unique_users,
    total_operations,
    total_credits,
    credits_per_user,
    credits_per_operation
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
ORDER BY date DESC, total_credits DESC
LIMIT 20;
```

**What to say:**
> "Here's a sample of the raw data we'll be analyzing. Each row represents one day's usage for one service. The calculator will aggregate and visualize this data to help us understand trends and forecast future costs."

---

## Part 3: Deploy Streamlit Calculator (3 minutes)

### Step 3.1: Navigate to Streamlit

In Snowsight:
1. Click **"Projects"** in left navigation
2. Select **"Streamlit"**
3. Click **"Apps"**
4. Click **"+ Streamlit App"** button

**What to say:**
> "Now let's deploy the cost calculator. Snowflake's Streamlit in Snowflake lets us run interactive Python applications directly in Snowflake without any external hosting."

### Step 3.2: Configure App

Fill in the form:

| Field | Value | Notes |
|-------|-------|-------|
| **App name** | `CORTEX_COST_CALCULATOR` | Or your preferred name |
| **App location** | `SNOWFLAKE_EXAMPLE.CORTEX_USAGE` | Where views are deployed |
| **Warehouse** | Select a warehouse | SMALL is sufficient |

**What to say:**
> "Give the app a name - I'm using CORTEX_COST_CALCULATOR. For the location, we'll use the same schema where we deployed the monitoring views. This allows the app to query the views directly. For the warehouse, SMALL is perfectly fine - this app doesn't require much compute."

### Step 3.3: Add Application Code

1. **Open** `streamlit/cortex_cost_calculator/streamlit_app.py`
2. **Copy** entire file contents
3. **Paste** into Snowflake code editor (replacing default code)

**What to say:**
> "Now we copy the calculator code. This is a full-featured Python application that provides interactive charts, multiple projection scenarios, and export capabilities. Just copy the entire file and paste it into the editor."

### Step 3.4: Add Package Dependencies

1. Click **"Packages"** tab in the editor
2. Open `streamlit/cortex_cost_calculator/environment.yml`
3. Copy the `dependencies` section
4. Paste into Snowflake packages section

**What to say:**
> "Streamlit in Snowflake pre-installs most common packages, but we'll specify our exact requirements. This includes plotly for visualizations and pandas for data manipulation."

### Step 3.5: Create and Launch

1. Click **"Create"** button (bottom right)
2. Wait for app to initialize (15-30 seconds)
3. App will automatically launch when ready

**What to say:**
> "Click Create and Snowflake will build and launch the application. This takes about 30 seconds. Once it's ready, you'll see the calculator interface."

---

## Part 4: Analyze Usage & Generate Projections (5 minutes)

### Step 4.1: Configure Data Source

In the calculator sidebar:

1. **Data Source:** Select **"Query Views (Same Account)"**
2. **Lookback Period:** Leave at 30 days (or adjust as needed)
3. **Credit Cost:** Verify $3.00 or adjust to your contract rate

**What to say:**
> "The calculator has two modes. Since we deployed everything in the same account, we'll use 'Query Views' which connects directly to our monitoring views. If you were a Solutions Engineer analyzing customer data, you'd use 'Upload CSV' instead."

> "The credit cost defaults to $3.00, but this varies by your Snowflake contract. Make sure to update this to your actual credit price for accurate cost projections."

### Step 4.2: Review Historical Analysis (Tab 1)

Click **"Historical Analysis"** tab

**Key metrics to highlight:**
- Total credits consumed
- Total cost
- Date range covered
- Service breakdown

**Charts available:**
- Credits consumed over time
- Cost by service type
- Daily usage patterns

**What to say:**
> "The Historical Analysis tab gives us a complete picture of past usage. At the top we see summary statistics - total credits, total cost, and the date range. The charts below show trends over time and which services are consuming the most credits."

> "In this example, we can see that Cortex Functions is our primary credit consumer, followed by Cortex Analyst. This breakdown helps us understand where our AI spend is coming from."

### Step 4.3: Generate Cost Projections (Tab 2)

Click **"Cost Projections"** tab

**Configuration:**
1. **Projection Period:** Select 12 months
2. **Growth Scenario:** Start with "Moderate" (25% monthly growth)
3. Review projection chart and metrics

**Scenarios available:**
- Conservative (10% monthly growth)
- Moderate (25% monthly growth)
- Aggressive (50% monthly growth)
- Rapid (100% monthly growth)
- Custom (define your own)

**What to say:**
> "Now for the forward-looking analysis. We can project costs over 3, 6, 12, or 24 months using different growth scenarios. Each scenario represents a different assumption about how your AI usage will grow."

> "The Moderate scenario assumes 25% compound monthly growth - this is typical for teams actively expanding their AI capabilities. The chart shows our monthly cost projection with a confidence band. Notice how the costs grow exponentially - this is compound growth in action."

### Step 4.4: Review Summary Report

Click **"Summary Report"** tab

**What's included:**
- Service-by-service credit breakdown
- Daily average usage
- Monthly projections
- Cost estimates

**What to say:**
> "The Summary Report pulls everything together into a clean format perfect for proposals and budget documents. You get a breakdown by service, showing current daily average credits and projected monthly costs."

---

## Part 5: Export Credit Estimates (2 minutes)

### Step 5.1: Download Credit Summary

In the Summary Report tab:
1. Locate **"Download Credit Estimate (CSV)"** button
2. Click to download
3. Open in Excel or Google Sheets

**File contains:**
- Service type
- Daily average credits
- Monthly estimated credits
- Monthly estimated cost
- Notes on methodology

**What to say:**
> "To share these estimates with your sales team or finance department, just click the Download button. You'll get a CSV file with all the key numbers, formatted and ready to incorporate into proposals or budget spreadsheets."

### Step 5.2: Share with Stakeholders

**Best practices for sharing:**

1. **Include variance ranges**
   - "Projected $15K-$18K/month" not "$16.5K/month"
   - Acknowledge uncertainty

2. **Document assumptions**
   - Growth rate used
   - Credit pricing source
   - Historical period analyzed

3. **Provide multiple scenarios**
   - Share conservative and moderate at minimum
   - Let stakeholders choose their planning scenario

4. **Set expectations**
   - These are estimates, not guarantees
   - Will update as actuals come in
   - Monitor monthly and adjust

**What to say:**
> "When sharing these estimates, always present them as ranges rather than precise numbers. Include your assumptions about growth rates and credit pricing. I recommend sharing at least two scenarios - conservative for budgeting and moderate for planning."

---

## Part 6: Solution Engineer Workflow (Bonus)

*This section is specifically for SEs analyzing customer accounts*

### SE Step 1: Extract Customer Data

In the **customer's** Snowflake account:

```sql
-- Run extraction query
@sql/02_utilities/export_metrics.sql
```

1. Click **"Download"** -> Save as CSV
2. Name: `customer_name_cortex_usage_YYYYMMDD.csv`

### SE Step 2: Analyze in Your Account

In **your** Snowflake account:

1. Open your CORTEX_COST_CALCULATOR
2. Select **"Upload Customer CSV"**
3. Drag and drop the CSV file
4. Calculator automatically parses and analyzes

### SE Step 3: Generate Customer Estimate

1. Review data quality in Historical Analysis
2. Generate projections with appropriate growth scenario
3. Export credit summary
4. Share with sales/pricing team

**What to say:**
> "As a Solutions Engineer, you don't want to deploy the calculator in every customer account. Instead, you deploy the monitoring views in the customer account, let them collect data for 7-14 days, then extract the data as a CSV."

> "Back in your own account, you have one calculator that can analyze any customer's data. Just upload the CSV, and within minutes you have professional cost projections ready for your sales team."

---

## Part 7: Cleanup (Optional)

### When to Clean Up

- After scoping exercise is complete (SE workflow)
- When migrating to a permanent solution
- During account decommissioning

### How to Clean Up

```sql
-- Run cleanup script
@sql/99_cleanup/cleanup_cortex_monitoring.sql
```

**Options:**
1. Drop views only (keeps schema for history)
2. Drop schema (removes all monitoring objects)
3. Drop database (complete removal)

**What to say:**
> "When you're done with the monitoring, cleanup is simple. The cleanup script provides three options depending on whether you want to remove just the views, the entire schema, or the whole database. Everything is commented out by default for safety - just uncomment the option you want."

---

## Key Takeaways

### What We Accomplished

1. **Deployed monitoring** - 22 views (monitoring + attribution + forecast outputs)
2. **Deployed calculator** - Interactive cost analysis tool
3. **Analyzed usage** - Historical trends and patterns
4. **Generated projections** - Growth-rate projections and forecast (when available)
5. **Exported estimates** - Ready for proposals and budgets

### Time Investment

- **Initial setup:** 10-15 minutes (one-time)
- **Per-customer analysis:** 5-10 minutes (repeatable)
- **Total value:** Hours saved vs manual analysis

### Business Value

- **Accurate estimates** - Based on real usage data
- **Multiple scenarios** - Present options to stakeholders
- **Professional output** - Export-ready credit summaries
- **Non-disruptive** - Zero impact on production
- **Repeatable** - Use across unlimited customers

---

## Next Steps

### For Solution Engineers

1. Deploy calculator in your account (one-time setup)
2. Use across customer engagements
3. Build library of customer estimates
4. Track projection accuracy over time

### For Customers

1. Deploy in production account
2. Grant access to finance/engineering teams
3. Review monthly as usage grows
4. Update forecasts quarterly

### For Everyone

1. Check `help/TROUBLESHOOTING.md` if issues arise
2. Explore custom scenarios for your specific use case
3. Integrate exports into your planning tools
4. Provide feedback for improvements

---

## Additional Resources

### Documentation
- **README.md** - Complete user guide
- **docs/01-GETTING_STARTED.md** - Quick setup guide
- **docs/03-TROUBLESHOOTING.md** - Issue resolution
- **Snowflake Docs** - [Cortex](https://docs.snowflake.com/en/user-guide/snowflake-cortex)

### Support
- Solution Engineers: Internal SE team
- Customers: Your assigned SE
- Documentation: [docs.snowflake.com](https://docs.snowflake.com)

---

## Video Script Notes

*For creating video walkthroughs*

### Video 1: Quick Start (5 minutes)
- Deploy monitoring
- Deploy calculator
- First look at data
- Target: First-time users wanting immediate value

### Video 2: Deep Dive (15 minutes)
- This walkthrough in full
- All features demonstrated
- SE workflow explained
- Target: Full training for SE team

### Video 3: Customer Use Case (10 minutes)
- Self-service deployment
- Ongoing monitoring
- Budget planning
- Target: Customer champions

### Video 4: Advanced Features (10 minutes)
- Custom scenarios
- Direct view queries
- Integration with BI tools
- Extending the solution
- Target: Power users

---

**Last Updated:** October 16, 2025
**Version:** 1.0
**Author:** Snowflake Solutions Engineering

---

*"From deployment to projection in 15 minutes."*
