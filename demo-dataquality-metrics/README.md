![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Data Quality Metrics & Reporting Demo

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-01
> This demo uses Snowflake features current as of March 2026.
> After expiration, this repository will be archived and made private.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Author:** SE Community
**Purpose:** Reference implementation for automated data quality monitoring and reporting using Snowflake native features.
**Last Updated:** 2026-03-02 | **Expires:** 2026-05-01 | **Status:** ACTIVE

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

---

## Reference Implementation Notice

This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

---

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-dataquality-metrics
cd sfe-public/demo-dataquality-metrics && cortex
```

## First Time Here?

**Deploy:**
1. Copy `deploy_all.sql` → Paste in Snowsight → Click Run All
2. **Wait 10 minutes** for `TRIGGER_ON_CHANGES` schedule to activate

**Run the Demo:**
3. Insert new data to trigger DMFs: `tools/insert_sample_data.sql`
4. Run `tools/DEMO_SCRIPT.sql` section by section
5. View results: Catalog → Table → **Data Quality** tab

**Cleanup:**
6. Run `sql/99_cleanup/teardown_all.sql` to remove all objects

> **Why wait 10 minutes?** The `TRIGGER_ON_CHANGES` schedule (event-driven DMFs) takes ~10 min to activate. After that, any INSERT triggers DMFs immediately.

## The Demo Story

> "Raw data has quality issues. Snowflake automatically detects bad records, filters them for analytics, and provides a dashboard to monitor quality over time."

| Part | What You Show | Key Query/Action |
|------|---------------|------------------|
| 1. The Problem | Raw data has NULLs and out-of-range values | `SELECT COUNT(*) FROM RAW... WHERE metric_value IS NULL` |
| 2. The Solution | DMFs automatically detect issues on data change | `SHOW PARAMETERS LIKE 'DATA_METRIC_SCHEDULE'` |
| 3. The Outcome | "Golden" views filter bad records | Compare `RAW` count vs `V_` view count |
| 4. Monitoring | **Native Snowsight Data Quality UI** | Catalog → Table → Data Quality tab |
| 5. Live Demo | Insert bad data, watch metrics update | `INSERT` → Refresh Data Quality tab |

## Native Snowsight Visualization

**No Streamlit required!** Snowsight has built-in Data Quality monitoring:

1. **Catalog → Database Explorer** → Select any table
2. Click the **Data Quality** tab
3. See: Data profiling, DMF results, trends, drill-down to failing records

The Streamlit dashboard (`DATA_QUALITY_DASHBOARD`) provides an alternative custom view.

## Automation Helpers (Optional)

```bash
tools/00_master.sh deploy   # Print deployment steps
tools/00_master.sh status   # Check object status
tools/00_master.sh cleanup  # Print cleanup steps
```

## What This Demo Shows

- **Data Metric Functions (DMFs)** - Native Snowflake quality rules with event-driven scheduling
- **Streams and Tasks** - Incremental CDC pattern for quality metric computation
- **Streamlit Dashboard** - Native visualization deployed from Git repository
- **Golden Dataset Views** - Cleaned views filtering invalid records
- **TRANSIENT Tables** - Cost-optimized storage for demo/regenerable data
- Clean, project-scoped naming inside `SNOWFLAKE_EXAMPLE`

## Key Patterns Demonstrated

| Pattern | Implementation |
|---------|----------------|
| Data Quality | Custom DMFs with `TRIGGER_ON_CHANGES` (event-driven) |
| Incremental Processing | Streams + Tasks for CDC |
| Streamlit Deployment | Modern `FROM` syntax with Git integration |
| Cost Optimization | TRANSIENT tables (no Fail-safe overhead) |
| Golden Dataset | Views with data quality filtering |

## What Gets Created

**Database & Schema:**
- Database: `SNOWFLAKE_EXAMPLE`
- Project schema: `SNOWFLAKE_EXAMPLE.DATA_QUALITY`

**Tables (TRANSIENT):**
- `RAW_ATHLETE_PERFORMANCE` - Raw performance metrics
- `RAW_FAN_ENGAGEMENT` - Raw engagement events
- `STG_DATA_QUALITY_METRICS` - Quality metric results

**Data Metric Functions:**
- `DMF_METRIC_VALUE_VALID_PCT` - Validates metric values (0-100 range)
- `DMF_SESSION_DURATION_VALID_PCT` - Validates session duration (0-14400 range)

**Streams:**
- `RAW_ATHLETE_PERFORMANCE_STREAM`
- `RAW_FAN_ENGAGEMENT_STREAM`

**Views (with data quality filtering):**
- `V_ATHLETE_PERFORMANCE` - Cleaned athlete data (valid metrics only)
- `V_FAN_ENGAGEMENT` - Cleaned engagement data (valid sessions only)
- `V_DATA_QUALITY_METRICS` - Quality metrics reporting
- `V_QUALITY_SCORE_TREND` - Aggregated quality trends

**Task:**
- `refresh_data_quality_metrics_task` - 5-minute incremental refresh

**Streamlit App:**
- `DATA_QUALITY_DASHBOARD` - Interactive quality monitoring

**Infrastructure:**
- Warehouse: `SFE_DATA_QUALITY_WH` (XSMALL, auto-suspend 60s)
- Git repository: `SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO`

## Architecture Diagrams

- `diagrams/data-model.md` - Entity relationships
- `diagrams/data-flow.md` - Data pipeline flow
- `diagrams/network-flow.md` - Network boundaries
- `diagrams/auth-flow.md` - Authentication sequence

## Estimated Demo Costs

**Edition Tier:** Enterprise (Streams, Tasks, Streamlit, DMFs)

**Assumptions:**
- Warehouse: XSMALL (1 credit/hour)
- Demo usage: 1 hour/day
- Data volume: under 1 GB

**Estimated Costs:**
- Compute: ~30 credits/month
- Storage: negligible (TRANSIENT tables reduce overhead)
- Serverless: none required

## Repository Structure

```
├── deploy_all.sql              # Single-copy Snowsight deployment
├── sql/
│   ├── 01_setup/               # Database and schema creation
│   ├── 02_data/                # Tables and sample data (TRANSIENT)
│   ├── 03_transformations/     # Streams, DMFs, views, tasks
│   ├── 04_streamlit/           # Dashboard deployment
│   └── 99_cleanup/             # Teardown script
├── streamlit/                  # Streamlit application code
├── docs/                       # Step-by-step guides
├── diagrams/                   # Architecture diagrams (Mermaid)
├── tools/                      # Master script and helpers
└── .github/workflows/          # Demo expiration automation
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| DMFs not triggering | `TRIGGER_ON_CHANGES` schedule takes ~10 min to activate after deployment. Wait, then INSERT new data. |
| Task not running | Check `SHOW TASKS LIKE 'refresh_data_quality%'` and ensure the task is RESUMED. |
| Streamlit app not visible | Navigate to Snowsight > Streamlit. Verify the Git repository stage is accessible. |
| Data Quality tab empty in Catalog | DMFs must have run at least once. Insert sample data and wait for the schedule. |

## Cleanup

Run `sql/99_cleanup/teardown_all.sql` in Snowsight to remove all demo objects.

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## Support

For questions or updates after expiration, contact your Snowflake Solutions Engineer for the latest version of this demo.
