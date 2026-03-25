# Usage Guide

## Streamlit Dashboard (5 Pages)

Navigate to **Projects > Streamlit > MUSIC_MARKETING_APP** in Snowsight.

### 1. Budget Entry

The "spreadsheet" page. Marketing team members can view and edit budget allocations in a familiar grid interface. Changes save directly to `RAW_MARKETING_BUDGET` in Snowflake.

- Filter by artist using the dropdown
- Edit the **Budget ($)** and **Notes** columns
- Click **Save Changes** to write updates to Snowflake

### 2. Budget vs. Actual

Compare planned budget to actual spend with variance highlighting.

- QTD summary metrics at the top
- Channel-level breakdown table
- Monthly trend chart (budget vs. actual over time)

### 3. Campaign Performance

ROI metrics joining marketing spend to streaming and royalty outcomes.

- KPIs: total campaigns, average ROI, streams per dollar, total invested
- Top 25 campaigns sortable by ROI, streams per dollar, or total spend
- Performance breakdown by campaign type (bar chart)

### 4. Artist Marketing Profile

Per-artist deep dive into marketing investments and downstream impact.

- Select an artist from the dropdown
- Profile summary: genre, territory, tenure, total spend, streams, royalties, ROI
- Campaign history table
- Monthly streams by platform (area chart)

### 5. Anomaly Alerts

Campaigns exceeding budget thresholds or underperforming.

- Critical alerts (>120% of budget) and warnings (>100%)
- Underperforming campaigns (low ROI or low streams per dollar)
- Recent alert log from the hourly monitoring task

## Snowflake Intelligence Agent

Navigate to **AI & ML > Snowflake Intelligence** in Snowsight.

Ask questions like:
- "Which campaigns had the highest ROI last quarter?"
- "How does our social media spend compare to streaming revenue by artist?"
- "Show me budget vs. actual for this quarter by territory"
- "Which marketing channels drive the most streams per dollar spent?"

## Secure Data Sharing

The demo includes two secure views ready for sharing with distribution partners:

- `V_PARTNER_CAMPAIGN_SUMMARY` — Campaign performance without internal cost details
- `V_PARTNER_STREAMING_SUMMARY` — Monthly streaming data by artist and platform
