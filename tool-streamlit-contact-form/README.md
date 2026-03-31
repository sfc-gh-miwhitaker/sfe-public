![Archived](https://img.shields.io/badge/Status-Archived-lightgrey)

# Contact Form (Streamlit in Snowflake)

**This project is archived.** The pattern it demonstrates (form input + Snowpark table write) is now well-covered by the official Snowflake documentation:

- **[Streamlit in Snowflake overview](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)** -- Getting started, deployment, and best practices
- **[Snowpark Python DataFrames](https://docs.snowflake.com/en/developer-guide/snowpark/python/working-with-dataframes)** -- DataFrame writes including `get_active_session()` patterns

The `deploy.sql` and `teardown.sql` scripts remain in this directory for anyone who already has links to this project. They create a minimal Streamlit app that collects name/email/address and writes to a Snowflake table.

For Streamlit examples with more depth, see:
- [`demo-dataquality-metrics`](../demo-dataquality-metrics/) -- Multi-page Streamlit with DMF dashboard
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Streamlit with ML scoring and vector search
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- Multi-page Streamlit with semantic views and agents
