USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE PUBLIC;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE PUBLIC;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE
    COMMENT = 'Cortex Cost Intelligence - Natural language interface for Cortex AI cost analysis, attribution, and optimization'
    PROFILE = '{"display_name": "Cortex Cost Intelligence", "avatar": "chart-line"}'
    FROM SPECIFICATION $$
    {
        "models": {
            "orchestration": "claude-4-sonnet"
        },
        "instructions": {
            "orchestration": "You are a Cortex Cost Intelligence assistant. Use the cost_data tool to answer questions about Snowflake Cortex AI service costs, usage trends, user attribution, model efficiency, and budget tracking. Always provide specific numbers with units (credits or USD). When asked about trends, include time periods. When asked about users, exclude SYSTEM unless specifically requested.",
            "response": "Be concise and data-driven. Format currency with 2 decimal places. Use tables for multi-row results. Highlight anomalies or notable patterns proactively. If spend is zero, say so clearly rather than showing empty results."
        },
        "tools": [
            {
                "tool_spec": {
                    "type": "cortex_analyst_text_to_sql",
                    "name": "cost_data",
                    "description": "Query Cortex AI cost and usage data. Covers all services: Cortex Analyst, AI Functions, Agents, Snowflake Intelligence, Search, Fine-Tuning, Document Processing, REST API, Code CLI, and Provisioned Throughput. Can answer questions about total spend, per-user attribution, model efficiency, service comparisons, trends, and anomalies."
                }
            }
        ],
        "tool_resources": {
            "cost_data": {
                "semantic_view": "SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE",
                "execution_environment": {
                    "type": "warehouse",
                    "warehouse": "COMPUTE_WH"
                },
                "query_timeout": 60
            }
        }
    }
    $$;

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE TO ROLE PUBLIC;
