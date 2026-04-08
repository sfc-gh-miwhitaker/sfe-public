"""
AP Invoice Pipeline — Streamlit Dashboard
Three-panel interface: Pipeline Status, Review Queue, Analytics Chat.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
"""

from snowflake.snowpark.context import get_active_session
import streamlit as st

st.set_page_config(
    page_title="AP Invoice Pipeline",
    page_icon="📄",
    layout="wide",
    initial_sidebar_state="expanded",
)

session = get_active_session()

SCHEMA = "SNOWFLAKE_EXAMPLE.AP_INVOICE"
SEMANTIC_VIEW = "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE"


# ── Sidebar ──────────────────────────────────────────────────────────
st.sidebar.title("AP Invoice Pipeline")
st.sidebar.caption("Pair-programmed by SE Community + Cortex Code")
panel = st.sidebar.radio(
    "Navigate",
    ["Pipeline Status", "Review Queue", "Analytics Chat"],
    index=0,
)

properties = session.sql(
    f"SELECT DISTINCT PROPERTY FROM {SCHEMA}.INVOICE_HEADER ORDER BY PROPERTY"
).collect()
property_options = ["All Properties"] + [r["PROPERTY"] for r in properties]
selected_property = st.sidebar.selectbox("Property Filter", property_options)

st.sidebar.markdown("---")
st.sidebar.markdown(
    "**Validation threshold:** 0.75  \n"
    "Invoices scoring below this are routed to the Review Queue."
)
st.sidebar.markdown(
    "![Expires](https://img.shields.io/badge/Expires-2026--05--08-orange)"
)


def property_filter(col="PROPERTY"):
    if selected_property == "All Properties":
        return ""
    return f" AND {col} = '{selected_property}'"


# ── Panel 1: Pipeline Status ────────────────────────────────────────
if panel == "Pipeline Status":
    st.title("📊 Pipeline Status")

    metrics = session.sql(f"""
        SELECT
            COUNT(*)                                         AS total_invoices,
            COUNT_IF(STATUS = 'PROCESSED')                   AS processed,
            COUNT_IF(STATUS = 'REVIEW')                      AS in_review,
            COUNT_IF(STATUS = 'PENDING')                     AS pending,
            ROUND(AVG(VALIDATION_SCORE), 2)                  AS avg_score,
            SUM(CASE WHEN STATUS = 'PROCESSED' THEN TOTAL_AMOUNT ELSE 0 END) AS processed_spend,
            SUM(CASE WHEN STATUS = 'REVIEW' THEN TOTAL_AMOUNT ELSE 0 END)    AS review_spend,
            ROUND(AVG(CASE WHEN APPROVED_TS IS NOT NULL
                THEN DATEDIFF('second', EXTRACTION_TS, APPROVED_TS) END), 0) AS avg_proc_sec
        FROM {SCHEMA}.INVOICE_HEADER
        WHERE 1=1 {property_filter()}
    """).collect()[0]

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Invoices", f"{metrics['TOTAL_INVOICES']}")
    col2.metric(
        "Auto-Approved",
        f"{metrics['PROCESSED']}",
        delta=f"{round(metrics['PROCESSED'] / max(metrics['TOTAL_INVOICES'], 1) * 100, 1)}%",
    )
    col3.metric("In Review", f"{metrics['IN_REVIEW']}")
    col4.metric("Avg Validation Score", f"{metrics['AVG_SCORE']}")

    col5, col6, col7 = st.columns(3)
    col5.metric("Processed Spend", f"${metrics['PROCESSED_SPEND']:,.2f}")
    col6.metric("Pending Review Spend", f"${metrics['REVIEW_SPEND']:,.2f}")
    avg_sec = metrics["AVG_PROC_SEC"] or 0
    col7.metric("Avg Processing Time", f"{avg_sec}s")

    # ROI callout
    st.markdown("---")
    st.subheader("ROI: Manual vs. Automated")
    manual_minutes_per_invoice = 12
    auto_seconds = avg_sec if avg_sec > 0 else 5
    total = metrics["TOTAL_INVOICES"]
    roi_col1, roi_col2, roi_col3 = st.columns(3)
    roi_col1.metric(
        "Manual Processing (est.)",
        f"{total * manual_minutes_per_invoice} min",
        help="Industry average: ~12 minutes per invoice for manual data entry",
    )
    roi_col2.metric(
        "Automated Processing",
        f"{round(total * auto_seconds / 60, 1)} min",
    )
    savings = max(
        round((1 - (auto_seconds / 60) / manual_minutes_per_invoice) * 100, 1), 0
    )
    roi_col3.metric("Time Savings", f"{savings}%")

    # Spend by property
    st.markdown("---")
    st.subheader("Spend by Property")
    spend_by_prop = session.sql(f"""
        SELECT
            PROPERTY,
            COUNT(*)          AS invoice_count,
            SUM(TOTAL_AMOUNT) AS total_spend
        FROM {SCHEMA}.INVOICE_HEADER
        WHERE STATUS = 'PROCESSED' {property_filter()}
        GROUP BY PROPERTY
        ORDER BY total_spend DESC
    """).to_pandas()
    st.bar_chart(spend_by_prop.set_index("PROPERTY")["TOTAL_SPEND"])

    # Top vendors
    st.subheader("Top Vendors by Spend")
    top_vendors = session.sql(f"""
        SELECT
            COALESCE(v.VENDOR_NAME, h.VENDOR_NAME_RAW) AS vendor,
            COUNT(DISTINCT h.INVOICE_ID)               AS invoices,
            SUM(h.TOTAL_AMOUNT)                        AS total_spend
        FROM {SCHEMA}.INVOICE_HEADER h
        LEFT JOIN {SCHEMA}.VENDOR_MASTER v
            ON h.VENDOR_ID_RESOLVED = v.VENDOR_ID
        WHERE h.STATUS = 'PROCESSED' {property_filter('h.PROPERTY')}
        GROUP BY vendor
        ORDER BY total_spend DESC
        LIMIT 10
    """).to_pandas()
    st.dataframe(top_vendors, use_container_width=True, hide_index=True)


# ── Panel 2: Review Queue ───────────────────────────────────────────
elif panel == "Review Queue":
    st.title("🔍 Review Queue")
    st.caption(
        "Invoices below the 0.75 validation threshold. "
        "Every AI decision is labeled — approve, edit, or reject below."
    )

    queue = session.sql(f"""
        SELECT
            QUEUE_ID,
            INVOICE_ID,
            SOURCE_FILE,
            VENDOR_NAME_RAW,
            INVOICE_NUMBER,
            INVOICE_DATE,
            TOTAL_AMOUNT,
            PROPERTY,
            FLAGGED_FIELDS,
            VALIDATION_SCORE,
            RESOLUTION
        FROM {SCHEMA}.V_REVIEW_QUEUE
        WHERE RESOLUTION IS NULL {property_filter()}
        ORDER BY VALIDATION_SCORE ASC
    """).to_pandas()

    if queue.empty:
        st.success("No invoices pending review.")
    else:
        st.warning(f"{len(queue)} invoice(s) need human review")

        for _, row in queue.iterrows():
            with st.expander(
                f"📄 {row['SOURCE_FILE']}  —  Score: {row['VALIDATION_SCORE']}  |  "
                f"Vendor: {row['VENDOR_NAME_RAW'] or 'Unknown'}  |  "
                f"Amount: ${row['TOTAL_AMOUNT']:,.2f}" if row["TOTAL_AMOUNT"] else
                f"📄 {row['SOURCE_FILE']}  —  Score: {row['VALIDATION_SCORE']}  |  "
                f"Vendor: {row['VENDOR_NAME_RAW'] or 'Unknown'}  |  Amount: N/A"
            ):
                detail_col1, detail_col2 = st.columns(2)
                with detail_col1:
                    st.markdown("**Invoice Details**")
                    st.write(f"- **Invoice #:** {row['INVOICE_NUMBER'] or '⚠️ Missing'}")
                    st.write(f"- **Date:** {row['INVOICE_DATE'] or '⚠️ Missing'}")
                    st.write(f"- **Property:** {row['PROPERTY']}")
                    st.write(f"- **PO Ref:** Flagged" if "PO_REFERENCE" in str(row["FLAGGED_FIELDS"]) else "- **PO Ref:** OK")

                with detail_col2:
                    st.markdown("**Flagged Fields** _(AI suggested — needs human confirmation)_")
                    try:
                        import json
                        flags = json.loads(row["FLAGGED_FIELDS"]) if isinstance(row["FLAGGED_FIELDS"], str) else row["FLAGGED_FIELDS"]
                        for flag in flags:
                            st.write(f"⚠️ `{flag}`")
                    except Exception:
                        st.write(f"⚠️ {row['FLAGGED_FIELDS']}")

                # Line items for this invoice
                items = session.sql(f"""
                    SELECT
                        DESCRIPTION,
                        QUANTITY,
                        UNIT_PRICE,
                        LINE_TOTAL,
                        GL_CODE_SUGGESTED       AS ai_suggested_gl,
                        GL_SUGGESTED_DESC       AS gl_description,
                        CLASSIFICATION_STATUS   AS status
                    FROM {SCHEMA}.V_LINE_ITEMS_ENRICHED
                    WHERE INVOICE_ID = {row['INVOICE_ID']}
                """).to_pandas()

                if not items.empty:
                    st.markdown("**Line Items** _(GL codes are AI-suggested)_")
                    st.dataframe(items, use_container_width=True, hide_index=True)

                # Action buttons
                btn_col1, btn_col2, btn_col3 = st.columns(3)
                approve_key = f"approve_{row['QUEUE_ID']}"
                reject_key = f"reject_{row['QUEUE_ID']}"

                if btn_col1.button("✅ Approve", key=approve_key):
                    session.sql(f"""
                        UPDATE {SCHEMA}.REVIEW_QUEUE
                        SET RESOLUTION = 'APPROVED',
                            REVIEWER_ID = CURRENT_USER(),
                            REVIEWED_TS = CURRENT_TIMESTAMP()
                        WHERE QUEUE_ID = {row['QUEUE_ID']}
                    """).collect()
                    session.sql(f"""
                        UPDATE {SCHEMA}.INVOICE_HEADER
                        SET STATUS = 'PROCESSED',
                            APPROVED_BY = CURRENT_USER(),
                            APPROVED_TS = CURRENT_TIMESTAMP()
                        WHERE INVOICE_ID = {row['INVOICE_ID']}
                    """).collect()
                    session.sql(f"""
                        INSERT INTO {SCHEMA}.AUDIT_LOG
                            (INVOICE_ID, ACTION, FIELD_NAME, OLD_VALUE, NEW_VALUE, ACTOR, ACTOR_TYPE)
                        SELECT
                            {row['INVOICE_ID']}, 'HUMAN_APPROVED', 'STATUS', 'REVIEW', 'PROCESSED',
                            CURRENT_USER(), 'HUMAN'
                    """).collect()
                    st.success("Invoice approved and logged to audit trail.")
                    st.rerun()

                if btn_col3.button("❌ Reject", key=reject_key):
                    session.sql(f"""
                        UPDATE {SCHEMA}.REVIEW_QUEUE
                        SET RESOLUTION = 'REJECTED',
                            REVIEWER_ID = CURRENT_USER(),
                            REVIEWED_TS = CURRENT_TIMESTAMP()
                        WHERE QUEUE_ID = {row['QUEUE_ID']}
                    """).collect()
                    session.sql(f"""
                        INSERT INTO {SCHEMA}.AUDIT_LOG
                            (INVOICE_ID, ACTION, FIELD_NAME, OLD_VALUE, NEW_VALUE, ACTOR, ACTOR_TYPE)
                        SELECT
                            {row['INVOICE_ID']}, 'HUMAN_REJECTED', 'STATUS', 'REVIEW', 'REJECTED',
                            CURRENT_USER(), 'HUMAN'
                    """).collect()
                    st.error("Invoice rejected and logged to audit trail.")
                    st.rerun()

    # Audit trail
    st.markdown("---")
    st.subheader("Recent Audit Trail")
    audit = session.sql(f"""
        SELECT
            ACTION_TS,
            INVOICE_ID,
            ACTION,
            FIELD_NAME,
            OLD_VALUE,
            NEW_VALUE,
            ACTOR,
            ACTOR_TYPE
        FROM {SCHEMA}.AUDIT_LOG
        ORDER BY ACTION_TS DESC
        LIMIT 20
    """).to_pandas()
    st.dataframe(audit, use_container_width=True, hide_index=True)


# ── Panel 3: Analytics Chat ─────────────────────────────────────────
elif panel == "Analytics Chat":
    st.title("💬 Invoice Analytics (Cortex Analyst)")
    st.caption(
        "Ask natural-language questions about your invoice data. "
        "Powered by a semantic view over processed invoices."
    )

    sample_questions = [
        "Total invoice spend by property this month",
        "Invoices pending approval over $10,000",
        "Top 10 vendors by spend YTD",
        "Average processing time for approved invoices",
        "What is the auto-approval rate?",
        "Show me spend by GL category",
        "Which property has the most invoices in review?",
    ]

    st.markdown("**Sample questions:**")
    for q in sample_questions:
        if st.button(q, key=f"sample_{q[:20]}"):
            st.session_state["analyst_question"] = q

    question = st.text_input(
        "Ask a question about your invoices:",
        value=st.session_state.get("analyst_question", ""),
        placeholder="e.g., What is the total spend by property?",
    )

    if question:
        with st.spinner("Querying Cortex Analyst..."):
            try:
                result = session.sql(f"""
                    SELECT * FROM SEMANTIC_VIEW(
                        {SEMANTIC_VIEW}
                        QUESTION => '{question.replace("'", "''")}'
                    )
                """).to_pandas()

                if not result.empty:
                    st.dataframe(result, use_container_width=True, hide_index=True)
                else:
                    st.info("No results returned. Try rephrasing your question.")
            except Exception as e:
                st.error(f"Cortex Analyst error: {e}")
                st.info(
                    "Tip: Try simpler questions like 'total spend by property' "
                    "or 'how many invoices are pending review?'"
                )

    st.markdown("---")
    st.caption(
        "Powered by Snowflake Cortex Analyst with semantic view "
        f"`{SEMANTIC_VIEW}` | "
        "Every query runs against live data — no cached reports."
    )


# ── Footer ───────────────────────────────────────────────────────────
st.sidebar.markdown("---")
st.sidebar.markdown(
    "**Data sources:** SNOWFLAKE_EXAMPLE.AP_INVOICE  \n"
    "**Tech stack:** AI_EXTRACT · AI_CLASSIFY · "
    "Streams · Tasks · Cortex Analyst · Streamlit"
)
