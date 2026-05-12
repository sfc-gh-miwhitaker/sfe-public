# Deployment Guide

## Prerequisites

- Snowflake account with ACCOUNTADMIN role (for API integration)
- SYSADMIN role for all other objects
- GitHub accessible from your Snowflake account

## Steps

1. Open Snowsight
2. Create a new SQL worksheet
3. Paste the entire contents of `deploy_all.sql`
4. Click **Run All**
5. Monitor output -- deployment takes ~30 seconds

## Troubleshooting

- **API Integration error**: Ensure you have ACCOUNTADMIN role
- **Git fetch fails**: Verify GitHub is accessible from your network
- **Streamlit not loading**: Wait 30 seconds after deployment, then refresh
- **pydeck map blank**: Accept External Offerings Terms in Streamlit settings
