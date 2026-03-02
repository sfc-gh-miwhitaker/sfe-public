"""
OpenAI Data Engineering Explorer
Streamlit in Snowflake app - AI-first data engineering with Cortex.
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="OpenAI + Cortex AI Data Engineering", layout="wide")
st.title("AI-First Data Engineering: OpenAI + Snowflake Cortex")
st.caption("Transform complex API responses with native AI classification, sentiment, and summarization")

approach = st.sidebar.radio(
    "Select Approach",
    [
        "Cortex Enrichment",
        "Schema-on-Read (Views)",
        "Medallion (Dynamic Tables)",
        "Raw Data Explorer",
    ],
)

# ---------------------------------------------------------------------------
# Cortex Enrichment (Primary)
# ---------------------------------------------------------------------------
if approach == "Cortex Enrichment":
    st.header("Cortex AI Enrichment Pipeline")
    st.success("Native AI analysis - no external API calls needed!")
    st.markdown(
        "Snowflake Cortex classifies, scores sentiment, summarizes, and scans for PII -- "
        "all within Snowflake, no external API calls."
    )

    tab_enrich, tab_batch_qa, tab_pii, tab_dash = st.tabs(
        ["Enriched Completions", "Batch QA", "PII Scan", "Dashboard"]
    )

    with tab_enrich:
        try:
            df = session.sql("SELECT * FROM DT_ENRICHED_COMPLETIONS").to_pandas()
            st.dataframe(df, use_container_width=True)
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Responses", len(df))
            with col2:
                if "SENTIMENT_SCORE" in df.columns:
                    st.metric("Avg Sentiment", f"{df['SENTIMENT_SCORE'].mean():.2f}")
            with col3:
                if "TOPIC_CLASSIFICATION" in df.columns:
                    st.metric("Topics Found", df["TOPIC_CLASSIFICATION"].nunique())
        except Exception as e:
            st.error(f"DT_ENRICHED_COMPLETIONS not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_batch_qa:
        try:
            df = session.sql("SELECT * FROM DT_BATCH_ENRICHED").to_pandas()
            st.dataframe(df, use_container_width=True)
            if "CLASSIFICATION_AGREEMENT" in df.columns:
                agree = df["CLASSIFICATION_AGREEMENT"].value_counts()
                st.subheader("OpenAI vs Cortex Classification Agreement")
                st.bar_chart(agree)
        except Exception as e:
            st.error(f"DT_BATCH_ENRICHED not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_pii:
        try:
            df = session.sql("SELECT * FROM DT_PII_SCAN").to_pandas()
            st.dataframe(df, use_container_width=True)
        except Exception as e:
            st.error(f"DT_PII_SCAN not ready. Dynamic table may still be initializing. Error: {e}")

    with tab_dash:
        try:
            df = session.sql("SELECT * FROM V_ENRICHMENT_DASHBOARD").to_pandas()
            st.dataframe(df, use_container_width=True)

            if not df.empty and "TOPIC_CLASSIFICATION" in df.columns:
                st.subheader("Responses by Topic")
                st.bar_chart(df.set_index("TOPIC_CLASSIFICATION")["RESPONSE_COUNT"])

                st.subheader("Avg Sentiment by Topic")
                st.bar_chart(df.set_index("TOPIC_CLASSIFICATION")["AVG_SENTIMENT"])
        except Exception as e:
            st.error(f"V_ENRICHMENT_DASHBOARD not ready. Error: {e}")


# ---------------------------------------------------------------------------
# Schema-on-Read
# ---------------------------------------------------------------------------
elif approach == "Schema-on-Read (Views)":
    st.header("Schema-on-Read with FLATTEN + Views")
    st.markdown(
        "Raw VARIANT stays intact. Views use `LATERAL FLATTEN` to extract "
        "and reshape on demand. Zero ETL lag, full schema evolution tolerance."
    )

    tab_comp, tab_tools, tab_struct, tab_batch, tab_usage = st.tabs(
        ["Completions", "Tool Calls", "Structured Outputs", "Batch Results", "Token Usage"]
    )

    with tab_comp:
        st.subheader("V_COMPLETIONS")
        df = session.sql("SELECT * FROM V_COMPLETIONS ORDER BY created_at DESC").to_pandas()
        st.dataframe(df, use_container_width=True)

        col1, col2 = st.columns(2)
        with col1:
            st.metric("Total Completions", len(df))
        with col2:
            st.metric("Unique Models", df["MODEL"].nunique() if "MODEL" in df.columns else 0)

        st.subheader("Token Distribution by Finish Reason")
        token_df = session.sql("""
            SELECT finish_reason,
                   COUNT(*) AS responses,
                   SUM(total_tokens) AS total_tokens,
                   ROUND(AVG(total_tokens), 0) AS avg_tokens
            FROM V_COMPLETIONS
            GROUP BY finish_reason
            ORDER BY total_tokens DESC
        """).to_pandas()
        if not token_df.empty:
            st.bar_chart(token_df.set_index("FINISH_REASON")["TOTAL_TOKENS"])

    with tab_tools:
        st.subheader("V_TOOL_CALLS")
        df = session.sql("SELECT * FROM V_TOOL_CALLS ORDER BY created_at DESC").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Function Call Frequency")
        freq_df = session.sql("""
            SELECT function_name, COUNT(*) AS call_count
            FROM V_TOOL_CALLS
            GROUP BY function_name
            ORDER BY call_count DESC
        """).to_pandas()
        if not freq_df.empty:
            st.bar_chart(freq_df.set_index("FUNCTION_NAME")["CALL_COUNT"])

    with tab_struct:
        st.subheader("V_STRUCTURED_OUTPUTS")
        st.markdown("Completions where `content` is valid JSON -- parsed for traversal.")
        df = session.sql("SELECT * FROM V_STRUCTURED_OUTPUTS").to_pandas()
        st.dataframe(df, use_container_width=True)

    with tab_batch:
        st.subheader("V_BATCH_RESULTS")
        df = session.sql("SELECT * FROM V_BATCH_RESULTS ORDER BY batch_request_id").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Batch Outcome Distribution")
        outcome_df = session.sql("""
            SELECT outcome, COUNT(*) AS cnt
            FROM V_BATCH_RESULTS
            GROUP BY outcome
        """).to_pandas()
        if not outcome_df.empty:
            st.bar_chart(outcome_df.set_index("OUTCOME")["CNT"])

    with tab_usage:
        st.subheader("V_TOKEN_USAGE")
        df = session.sql("SELECT * FROM V_TOKEN_USAGE ORDER BY bucket_start").to_pandas()
        st.dataframe(df, use_container_width=True)

        st.subheader("Daily Token Consumption")
        daily_df = session.sql("""
            SELECT bucket_start::DATE AS day,
                   SUM(input_tokens) AS input_tok,
                   SUM(output_tokens) AS output_tok
            FROM V_TOKEN_USAGE
            GROUP BY day
            ORDER BY day
        """).to_pandas()
        if not daily_df.empty:
            st.line_chart(daily_df.set_index("DAY"))


# ---------------------------------------------------------------------------
# Medallion Architecture
# ---------------------------------------------------------------------------
elif approach == "Medallion (Dynamic Tables)":
    st.header("Medallion Architecture with Dynamic Tables")
    st.markdown(
        "Declarative pipeline: Bronze (raw) to Silver (typed) to Gold (aggregated). "
        "Snowflake handles incremental refresh automatically via `TARGET_LAG`."
    )

    tab_silver, tab_gold = st.tabs(["Silver Layer", "Gold Layer"])

    with tab_silver:
        silver_obj = st.selectbox(
            "Silver Table",
            ["DT_COMPLETIONS", "DT_TOOL_CALLS", "DT_BATCH_OUTCOMES", "DT_USAGE_FLAT"],
        )
        df = session.sql(f"SELECT * FROM {silver_obj} LIMIT 200").to_pandas()
        st.dataframe(df, use_container_width=True)
        st.metric("Row Count", len(df))

    with tab_gold:
        gold_obj = st.selectbox(
            "Gold Table",
            ["DT_DAILY_TOKEN_SUMMARY", "DT_TOOL_CALL_ANALYTICS", "DT_BATCH_SUMMARY"],
        )
        df = session.sql(f"SELECT * FROM {gold_obj}").to_pandas()
        st.dataframe(df, use_container_width=True)

        if gold_obj == "DT_DAILY_TOKEN_SUMMARY" and not df.empty:
            st.subheader("Estimated Daily Cost by Model")
            cost_df = session.sql("""
                SELECT bucket_date,
                       model,
                       SUM(est_total_cost_usd) AS daily_cost
                FROM DT_DAILY_TOKEN_SUMMARY
                GROUP BY bucket_date, model
                ORDER BY bucket_date
            """).to_pandas()
            if not cost_df.empty:
                st.line_chart(
                    cost_df.pivot(
                        index="BUCKET_DATE", columns="MODEL", values="DAILY_COST"
                    )
                )

        elif gold_obj == "DT_TOOL_CALL_ANALYTICS" and not df.empty:
            st.subheader("Tool Invocation Count")
            st.bar_chart(df.set_index("FUNCTION_NAME")["INVOCATION_COUNT"])

        elif gold_obj == "DT_BATCH_SUMMARY" and not df.empty:
            st.subheader("Batch Outcome Breakdown")
            st.bar_chart(df.set_index("OUTCOME")["RECORD_COUNT"])


# ---------------------------------------------------------------------------
# Raw Data Explorer
# ---------------------------------------------------------------------------
else:
    st.header("Raw Data Explorer")
    st.markdown("Explore the raw VARIANT payloads before any transformation.")

    raw_table = st.selectbox(
        "Raw Table",
        ["RAW_CHAT_COMPLETIONS", "RAW_BATCH_OUTPUTS", "RAW_USAGE_BUCKETS"],
    )

    df = session.sql(f"SELECT * FROM {raw_table} LIMIT 50").to_pandas()
    st.dataframe(df, use_container_width=True)

    st.subheader("Single Record Deep Dive")
    if not df.empty:
        row_idx = st.slider("Record Index", 0, len(df) - 1, 0)
        st.json(df.iloc[row_idx]["RAW"])
