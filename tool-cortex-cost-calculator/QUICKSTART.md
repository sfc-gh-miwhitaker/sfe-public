# Cortex Cost Calculator - Quickstart

**Detailed walkthrough with screenshots and explanations.**

> Want the fastest path? See [`README.md`](README.md) for 2-step deployment (3-4 minutes). This guide provides extra detail and context.

---

## First Time Here?

**Follow these guides in order:**

1. **Deploy Everything:** Run [`deploy_all.sql`](deploy_all.sql) - Copy/paste into Snowsight -> Click "Run All" (~2 min)
2. **Validate Deployment:** Review validation checks at end of script (~1 min)
3. **Access Calculator:** Snowsight -> Projects -> Streamlit -> CORTEX_COST_CALCULATOR (~1 min)
4. **Explore Features:** Learn calculator features below (~5 min)

**Total time: ~10 minutes** (includes learning)

---

**Alternative: Step-by-step with detailed validation**

1. **Deploy Monitoring:** Run [`sql/01_deployment/deploy_cortex_monitoring.sql`](sql/01_deployment/deploy_cortex_monitoring.sql) (~1 min)
2. **Validate Views:** Run validation queries (see [Step 1 below](#step-1-deploy-monitoring-5-minutes)) (~2 min)
3. **Deploy Calculator:** Follow [Streamlit deployment](#step-2-deploy-streamlit-calculator-5-minutes) (~3 min)
4. **Explore Features:** Learn calculator capabilities (~5 min)

**Total time: ~15 minutes** (includes detailed validation)

---

**Want deeper understanding:** [`docs/01-GETTING_STARTED.md`](docs/01-GETTING_STARTED.md) - Architecture and concepts (~5 min)

---

## What You'll Build

By the end of this quickstart, you'll have:

- 21 monitoring views tracking Cortex services (monitoring + attribution + forecast outputs)
- Automated daily snapshots (serverless task)
- Interactive Streamlit cost calculator
- Historical trend analysis
- Cost projections and forecasting
- Export-ready credit estimates


---

## Prerequisites

Before starting, ensure you have:

- **Snowflake Account** with Cortex usage (ideally 7-14 days of history)
- **Role Access:** ACCOUNTADMIN OR role with IMPORTED PRIVILEGES on SNOWFLAKE database
- **Active Warehouse** for running queries
- **5-10 minutes** of uninterrupted time

---

## Step-by-Step Setup

### Step 1: Deploy Monitoring (5 minutes)

1. **Open Snowsight** and log into your Snowflake account
2. **Select a role** with ACCOUNTADMIN or IMPORTED PRIVILEGES on SNOWFLAKE database
3. **Select a warehouse** (any size, SMALL is fine)
4. **Run deployment script:**

```sql
-- Copy and paste the entire contents of:
-- sql/01_deployment/deploy_cortex_monitoring.sql
```

5. **Verify deployment:**

The script automatically validates. You should see:

```
OK: Database created: SNOWFLAKE_EXAMPLE
OK: Schema created: CORTEX_USAGE
OK: Views created: 22 views
OK: Snapshot table created: CORTEX_USAGE_SNAPSHOTS
OK: Serverless task created: TASK_DAILY_CORTEX_SNAPSHOT
```

6. **Test a view:**

```sql
SELECT
  usage_date,
  service_type,
  daily_unique_users,
  total_operations,
  total_credits
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY
ORDER BY usage_date DESC, total_credits DESC
LIMIT 10;
```

**Expected result:** Rows showing your Cortex usage (empty if no usage yet).

---

### Step 2: Deploy Streamlit Calculator (5 minutes)

#### Method 1: Snowsight UI (Recommended)

1. **Navigate:** Snowsight -> **Projects** -> **Streamlit** -> **+ Streamlit App**
2. **Configure:**
   - **App name:** `CORTEX_COST_CALCULATOR`
   - **Location:** `SNOWFLAKE_EXAMPLE.CORTEX_USAGE` (or your preferred database/schema)
   - **Warehouse:** Select warehouse (SMALL is fine)
3. **Copy code:**
   - Open `streamlit/cortex_cost_calculator/streamlit_app.py`
   - Copy entire file contents
   - Paste into Snowsight code editor
4. **Add packages:**
   - Open `streamlit/cortex_cost_calculator/environment.yml`
   - Copy package dependencies
   - Paste into Snowsight packages section
5. **Click "Create"**

**Time:** 2-3 minutes

#### Method 2: SnowSQL CLI (Advanced)

```bash
# 1. Create stage
snow sql -q "CREATE STAGE IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_USAGE.STREAMLIT_STAGE;"

# 2. Upload files (run in your local terminal)
snow stage put file://streamlit/cortex_cost_calculator/streamlit_app.py @SNOWFLAKE_EXAMPLE.CORTEX_USAGE.STREAMLIT_STAGE
snow stage put file://streamlit/cortex_cost_calculator/environment.yml @SNOWFLAKE_EXAMPLE.CORTEX_USAGE.STREAMLIT_STAGE

# 3. Create Streamlit app
snow sql -q "CREATE STREAMLIT SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_COST_CALCULATOR \
  ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.CORTEX_USAGE.STREAMLIT_STAGE' \
  MAIN_FILE = '/streamlit_app.py' \
  QUERY_WAREHOUSE = 'YOUR_WAREHOUSE_NAME';"
```

**Time:** 3-5 minutes

---

### Step 3: Access & Use Calculator (5 minutes)

1. **Open Streamlit app:**
   - Snowsight -> **Projects** -> **Streamlit** -> **Apps** -> **CORTEX_COST_CALCULATOR**

2. **Select data source:**
   - **Option A:** "Query Views (Same Account)" - For ongoing monitoring
   - **Option B:** "Upload Customer CSV" - For SE workflow (analyze customer data)

3. **Explore features:**
   - **Historical Analysis:** View trends, service breakdown, user activity
   - **Cost Projections:** Generate 3, 6, 12, or 24-month forecasts
   - **Cost per User Calculator:** Estimate per-user costs
   - **Budget Capacity Planning:** Determine user capacity for given budget
   - **Summary Report:** Export credit estimates for proposals

---

## Two Common Workflows

### Workflow 1: Customer Self-Service (Single Account)

**Use Case:** Customer wants ongoing cost monitoring in their own account

```
1. Customer deploys monitoring (Step 1 above)
2. Customer deploys Streamlit app (Step 2 above)
3. Customer accesses app anytime for real-time analysis
4. Automated daily snapshots capture historical trends
```

**Benefits:**
- Real-time visibility into Cortex spend
- Historical trend analysis
- No data export required
- Self-service forecasting

---

### Workflow 2: SE Analyzing Customer Data (Two Accounts)

**Use Case:** Solutions Engineer analyzing customer Cortex usage

**In Customer Account:**
```
1. SE deploys monitoring (Step 1 above)
2. Wait 7-14 days for usage data to accumulate
3. Run export query:
   @sql/02_utilities/export_metrics.sql
4. Download CSV
```

**In SE Account:**
```
5. SE accesses their own Streamlit calculator
6. Select "Upload Customer CSV" as data source
7. Upload customer's CSV file
8. Generate cost analysis and projections
9. Export credit estimate for sales team
```

**Benefits:**
- Analyze multiple customers without storing data
- Generate proposals quickly
- Reusable calculator across customers
- No customer data stored permanently

---

## Verification Checklist

After setup, verify everything works:

- [ ] **Database created:** `SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE'` returns 1 row
- [ ] **Schema created:** `SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE` includes CORTEX_USAGE
- [ ] **Views created:** `SHOW VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE` returns 21 rows
- [ ] **Table created:** `SHOW TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE` includes CORTEX_USAGE_SNAPSHOTS
- [ ] **Task created:** `SHOW TASKS IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE` includes TASK_DAILY_CORTEX_SNAPSHOT
- [ ] **Task running:** Task status is "started" (check with `SHOW TASKS`)
- [ ] **Views return data:** `SELECT usage_date, service_type, total_credits FROM V_CORTEX_DAILY_SUMMARY ORDER BY usage_date DESC LIMIT 1` returns rows
- [ ] **Streamlit accessible:** App loads without errors
- [ ] **Charts render:** Historical analysis displays visualizations

---

## Next Steps

Now that you're set up, explore these capabilities:

1. **Set up alerts** - Configure resource monitors for budget tracking
2. **Grant access** - Share views/app with other users via GRANT statements
3. **Customize** - Modify views to match your organization's needs
4. **Automate** - Schedule exports or integrate with your BI tools
5. **Optimize** - Use query-level cost analysis to find expensive queries

**Full documentation:** See [`docs/01-GETTING_STARTED.md`](docs/01-GETTING_STARTED.md) and [`docs/02-DEPLOYMENT_WALKTHROUGH.md`](docs/02-DEPLOYMENT_WALKTHROUGH.md)

---

## Need Help?

- **Documentation:** [`docs/`](docs/) directory
- **Troubleshooting:** [`docs/03-TROUBLESHOOTING.md`](docs/03-TROUBLESHOOTING.md)
- **Architecture:** [`diagrams/`](diagrams/) directory
- **Snowflake Docs:** [https://docs.snowflake.com](https://docs.snowflake.com)

---

## Cleanup (Optional)

To remove all project objects:

```sql
-- Copy/paste into Snowsight and click "Run All"
-- See: sql/99_cleanup/cleanup_all.sql
```

**What's removed:**
- API Integration: SFE_CORTEX_TRAIL_GIT_API
- Git Repository: SFE_CORTEX_TRAIL_REPO
- Streamlit App: CORTEX_COST_CALCULATOR
- CORTEX_USAGE schema (22 views, 1 table, 1 task)

**What's preserved (protected shared infrastructure):**
- SNOWFLAKE_EXAMPLE database (may contain other demos)
- SNOWFLAKE_EXAMPLE.GIT_REPOS schema (shared across demos)
- Source data in SNOWFLAKE.ACCOUNT_USAGE (unaffected)

**Time:** < 1 minute

**Full cleanup script:** [`sql/99_cleanup/cleanup_all.sql`](sql/99_cleanup/cleanup_all.sql)

---

**Ready? Start with Step 1 above. You'll be analyzing Cortex costs in 15 minutes.**
