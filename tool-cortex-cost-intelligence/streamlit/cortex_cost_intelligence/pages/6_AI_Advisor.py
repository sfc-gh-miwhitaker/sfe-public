import streamlit as st
import pandas as pd
import requests
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="AI Advisor", layout="wide")
st.title("AI Advisor")

st.markdown(
    "Ask natural-language questions about your Cortex AI costs. "
    "Powered by the `SV_CORTEX_COST_INTELLIGENCE` semantic view via Cortex Analyst."
)

SEMANTIC_VIEW = "SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE"

if "advisor_messages" not in st.session_state:
    st.session_state.advisor_messages = []

suggestions = [
    "What was our total Cortex spend last month?",
    "Who are the top 5 spenders this month?",
    "Which service is growing fastest week over week?",
    "What is the cheapest model for COMPLETE?",
]

st.sidebar.subheader("Suggested Questions")
for s in suggestions:
    if st.sidebar.button(s, key=f"sug_{s[:20]}"):
        st.session_state.advisor_messages.append({"role": "user", "content": [{"type": "text", "text": s}]})

for msg in st.session_state.advisor_messages:
    role = "assistant" if msg["role"] == "analyst" else msg["role"]
    with st.chat_message(role):
        for item in msg.get("content", []):
            if item["type"] == "text":
                st.markdown(item["text"])
            elif item["type"] == "sql":
                with st.expander("SQL Query", expanded=False):
                    st.code(item["statement"], language="sql")
                try:
                    session = get_active_session()
                    df = session.sql(item["statement"]).to_pandas()
                    st.dataframe(df, use_container_width=True)
                except Exception as e:
                    st.error(f"Query error: {e}")
            elif item["type"] == "suggestions":
                for sug in item.get("suggestions", []):
                    st.info(sug)

if prompt := st.chat_input("Ask about your Cortex costs..."):
    st.session_state.advisor_messages.append({"role": "user", "content": [{"type": "text", "text": prompt}]})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            try:
                session = get_active_session()
                request_body = {
                    "messages": st.session_state.advisor_messages,
                    "semantic_view": SEMANTIC_VIEW,
                }
                resp = requests.post(
                    url=f"https://{session.get_current_account()}.snowflakecomputing.com/api/v2/cortex/analyst/message",
                    json=request_body,
                    headers={
                        "Authorization": f'Snowflake Token="{session.connection.rest.token}"',
                        "Content-Type": "application/json",
                    },
                )
                if resp.status_code < 400:
                    result = resp.json()
                    content = result["message"]["content"]
                    st.session_state.advisor_messages.append({"role": "analyst", "content": content})
                    for item in content:
                        if item["type"] == "text":
                            st.markdown(item["text"])
                        elif item["type"] == "sql":
                            with st.expander("SQL Query", expanded=False):
                                st.code(item["statement"], language="sql")
                            try:
                                df = session.sql(item["statement"]).to_pandas()
                                st.dataframe(df, use_container_width=True)
                            except Exception as e:
                                st.error(f"Query error: {e}")
                        elif item["type"] == "suggestions":
                            for sug in item.get("suggestions", []):
                                st.info(sug)
                else:
                    st.error(f"Cortex Analyst error ({resp.status_code}): {resp.text}")
            except Exception as e:
                st.error(f"Error: {e}")
