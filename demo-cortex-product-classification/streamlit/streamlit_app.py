"""
Glaze & Classify — Classification Comparison Dashboard

Side-by-side comparison of four product classification approaches:
1. Traditional SQL (CASE/LIKE/regex)
2. Cortex AI_COMPLETE — Simple
3. Cortex AI_COMPLETE — Robust Pipeline
4. SPCS Custom Vision Model
"""

from decimal import Decimal
from snowflake.snowpark.context import get_active_session
import pandas as pd
import streamlit as st


def _fix_decimals(df: pd.DataFrame) -> pd.DataFrame:
    """Convert Decimal columns to float so Arrow serialization works in SiS."""
    for col in df.columns:
        if df[col].dtype == object and df[col].apply(lambda x: isinstance(x, Decimal)).any():
            df[col] = df[col].astype(float)
    return df

st.set_page_config(
    page_title="Glaze & Classify",
    page_icon="🍩",
    layout="wide"
)

session = get_active_session()


@st.cache_data(ttl=300)
def load_accuracy_summary():
    return _fix_decimals(session.sql("""
        SELECT
            market_code,
            language_code,
            total_products,
            trad_accuracy_pct,
            simple_accuracy_pct,
            robust_accuracy_pct,
            vision_accuracy_pct,
            avg_robust_confidence
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.ACCURACY_SUMMARY
        ORDER BY market_code
    """).to_pandas())


@st.cache_data(ttl=300)
def load_overall_accuracy():
    return _fix_decimals(session.sql("""
        SELECT
            COUNT(*)                                                AS total_products,
            ROUND(AVG(trad_category_correct) * 100, 1)             AS trad_pct,
            ROUND(AVG(simple_category_correct) * 100, 1)           AS simple_pct,
            ROUND(AVG(robust_category_correct) * 100, 1)           AS robust_pct,
            ROUND(AVG(vision_category_correct) * 100, 1)           AS vision_pct,
            ROUND(AVG(trad_full_correct) * 100, 1)                 AS trad_full_pct,
            ROUND(AVG(simple_full_correct) * 100, 1)               AS simple_full_pct,
            ROUND(AVG(robust_full_correct) * 100, 1)               AS robust_full_pct,
            ROUND(AVG(vision_full_correct) * 100, 1)               AS vision_full_pct
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
    """).to_pandas())


@st.cache_data(ttl=300)
def load_comparison_detail():
    return _fix_decimals(session.sql("""
        SELECT
            product_id,
            product_name,
            market_code,
            language_code,
            gold_category,
            gold_subcategory,
            trad_category,
            trad_category_correct,
            simple_category,
            simple_category_correct,
            robust_category,
            robust_confidence,
            robust_category_correct,
            vision_category,
            vision_category_correct,
            is_image_only
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
        ORDER BY product_id
    """).to_pandas())


@st.cache_data(ttl=300)
def load_misclassified():
    return _fix_decimals(session.sql("""
        SELECT
            product_name,
            market_code,
            gold_category,
            trad_category,
            simple_category,
            robust_category,
            robust_confidence
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
        WHERE trad_category_correct = 0
        ORDER BY market_code, product_name
    """).to_pandas())


# -- Header --
st.title("🍩 Glaze & Classify")
st.markdown("**Product classification showdown:** four approaches to classifying an international bakery catalog")
st.divider()

# -- Overall Accuracy KPIs --
st.subheader("Overall Accuracy (Category Level)")

overall = load_overall_accuracy()
if not overall.empty:
    row = overall.iloc[0]
    cols = st.columns(5)
    cols[0].metric("Products", f"{int(row['TOTAL_PRODUCTS']):,}")
    cols[1].metric("Traditional SQL", f"{row['TRAD_PCT']}%")
    cols[2].metric("Cortex Simple", f"{row['SIMPLE_PCT']}%")
    cols[3].metric("Cortex Robust", f"{row['ROBUST_PCT']}%")
    cols[4].metric("SPCS Vision", f"{row['VISION_PCT']}%" if row['VISION_PCT'] else "N/A")

    st.caption("Full match (category + subcategory)")
    cols2 = st.columns(5)
    cols2[0].empty()
    cols2[1].metric("Trad Full", f"{row['TRAD_FULL_PCT']}%", label_visibility="visible")
    cols2[2].metric("Simple Full", f"{row['SIMPLE_FULL_PCT']}%", label_visibility="visible")
    cols2[3].metric("Robust Full", f"{row['ROBUST_FULL_PCT']}%", label_visibility="visible")
    cols2[4].metric("Vision Full", f"{row['VISION_FULL_PCT']}%" if row['VISION_FULL_PCT'] else "N/A", label_visibility="visible")

st.divider()

# -- Accuracy by Market --
st.subheader("Accuracy by Market & Language")

accuracy_df = load_accuracy_summary()
if not accuracy_df.empty:
    chart_data = accuracy_df[["MARKET_CODE", "TRAD_ACCURACY_PCT", "SIMPLE_ACCURACY_PCT", "ROBUST_ACCURACY_PCT"]].copy()
    chart_data = chart_data.rename(columns={
        "MARKET_CODE": "Market",
        "TRAD_ACCURACY_PCT": "Traditional SQL",
        "SIMPLE_ACCURACY_PCT": "Cortex Simple",
        "ROBUST_ACCURACY_PCT": "Cortex Robust"
    })
    chart_data = chart_data.set_index("Market")
    st.bar_chart(chart_data)

    st.dataframe(
        accuracy_df.rename(columns={
            "MARKET_CODE": "Market",
            "LANGUAGE_CODE": "Language",
            "TOTAL_PRODUCTS": "Products",
            "TRAD_ACCURACY_PCT": "Traditional %",
            "SIMPLE_ACCURACY_PCT": "Simple AI %",
            "ROBUST_ACCURACY_PCT": "Robust AI %",
            "VISION_ACCURACY_PCT": "Vision %",
            "AVG_ROBUST_CONFIDENCE": "Avg Confidence"
        }),
        use_container_width=True,
        hide_index=True
    )

st.divider()

# -- Misclassified by Traditional SQL --
st.subheader("Products Misclassified by Traditional SQL")
st.markdown("These products show where keyword/regex approaches fail — especially non-English items and image-only products.")

misclassified = load_misclassified()
if not misclassified.empty:
    market_filter = st.multiselect(
        "Filter by market",
        options=sorted(misclassified["MARKET_CODE"].unique()),
        default=sorted(misclassified["MARKET_CODE"].unique())
    )
    filtered = misclassified[misclassified["MARKET_CODE"].isin(market_filter)]
    st.dataframe(
        filtered.rename(columns={
            "PRODUCT_NAME": "Product",
            "MARKET_CODE": "Market",
            "GOLD_CATEGORY": "Correct Category",
            "TRAD_CATEGORY": "SQL Predicted",
            "SIMPLE_CATEGORY": "Simple AI",
            "ROBUST_CATEGORY": "Robust AI",
            "ROBUST_CONFIDENCE": "Confidence"
        }),
        use_container_width=True,
        hide_index=True
    )
    st.metric("Total Misclassified (SQL)", len(filtered))

st.divider()

# -- Full Comparison Detail --
st.subheader("Full Classification Detail")

detail = load_comparison_detail()
if not detail.empty:
    col_a, col_b = st.columns(2)
    with col_a:
        selected_market = st.selectbox("Market", ["All"] + sorted(detail["MARKET_CODE"].unique().tolist()))
    with col_b:
        show_only_errors = st.checkbox("Show only misclassifications", value=False)

    view = detail.copy()
    if selected_market != "All":
        view = view[view["MARKET_CODE"] == selected_market]
    if show_only_errors:
        view = view[
            (view["TRAD_CATEGORY_CORRECT"] == 0) |
            (view["SIMPLE_CATEGORY_CORRECT"] == 0) |
            (view["ROBUST_CATEGORY_CORRECT"] == 0)
        ]

    st.dataframe(
        view[["PRODUCT_NAME", "MARKET_CODE", "GOLD_CATEGORY", "TRAD_CATEGORY",
              "SIMPLE_CATEGORY", "ROBUST_CATEGORY", "ROBUST_CONFIDENCE",
              "VISION_CATEGORY", "IS_IMAGE_ONLY"]].rename(columns={
            "PRODUCT_NAME": "Product",
            "MARKET_CODE": "Market",
            "GOLD_CATEGORY": "Correct",
            "TRAD_CATEGORY": "SQL",
            "SIMPLE_CATEGORY": "Simple AI",
            "ROBUST_CATEGORY": "Robust AI",
            "ROBUST_CONFIDENCE": "Confidence",
            "VISION_CATEGORY": "Vision",
            "IS_IMAGE_ONLY": "Image Only"
        }),
        use_container_width=True,
        hide_index=True
    )

st.divider()

# -- Live Classify --
st.subheader("Live Classify")
st.markdown("Enter a product name to see how each approach would classify it in real-time.")

user_input = st.text_input("Product name", placeholder="e.g., チョコレート グレーズド リング")

if user_input:
    with st.spinner("Classifying with Cortex AI..."):
        try:
            result = session.sql(f"""
                SELECT AI_COMPLETE(
                    model => 'llama3.1-70b',
                    prompt => CONCAT(
                        'You are a product classifier for a bakery/donut company. ',
                        'Classify this product into exactly one category and subcategory. ',
                        'Categories: Glazed, Frosted, Filled, Cake, Specialty, Seasonal, Beverages, Merchandise. ',
                        'Respond ONLY with JSON: {{"category": "...", "subcategory": "..."}}\n\n',
                        'Product name: ', '{user_input.replace(chr(39), chr(39)+chr(39))}'
                    )
                ) AS result
            """).to_pandas()

            if not result.empty:
                st.json(result.iloc[0]["RESULT"])
        except Exception as e:
            st.error(f"Classification failed: {e}")

# -- Footer --
st.divider()
st.caption(
    "**Glaze & Classify** | SE Community | "
    "Data: SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY | "
    "Powered by: Cortex AI_COMPLETE, SPCS, Streamlit in Snowflake"
)
