import streamlit as st
import pydeck as pdk
import json
from snowflake.snowpark.context import get_active_session

st.set_page_config(layout="wide")

session = get_active_session()

DEPOT_LAT, DEPOT_LNG = 33.7490, -84.3880

tab_map, tab_iot, tab_cfo = st.tabs(["Fleet Map", "IoT Dashboard", "CFO Chat"])

# ─────────────────────────────────────────────────────────────
# TAB 1: Fleet Map
# ─────────────────────────────────────────────────────────────
with tab_map:
    st.header("Fleet Tracker -- Metro Textile Services")

    vehicles_df = session.sql("""
        SELECT VEHICLE_ID, DRIVER_NAME, VEHICLE_TYPE, HOME_DEPOT, VEHICLE_STATUS,
               CURRENT_LAT, CURRENT_LNG, CURRENT_SPEED, ENGINE_STATUS,
               ASSIGNED_ROUTE, MOVEMENT_STATUS, LAST_PING
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.V_FLEET_STATUS
        WHERE CURRENT_LAT IS NOT NULL
    """).to_pandas()

    customers_df = session.sql("""
        SELECT CUSTOMER_ID, CUSTOMER_NAME, INDUSTRY, CITY,
               LATITUDE, LONGITUDE, MONTHLY_VALUE
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS
    """).to_pandas()

    telemetry_df = session.sql("""
        SELECT VEHICLE_ID, TIMESTAMP, LATITUDE, LONGITUDE, SPEED_MPH
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GPS_TELEMETRY
        ORDER BY VEHICLE_ID, TIMESTAMP
    """).to_pandas()

    col_k1, col_k2, col_k3, col_k4 = st.columns(4)
    active_count = len(vehicles_df[vehicles_df["VEHICLE_STATUS"] == "ACTIVE"])
    in_transit = len(vehicles_df[vehicles_df["MOVEMENT_STATUS"] == "IN_TRANSIT"])
    at_stop = len(vehicles_df[vehicles_df["MOVEMENT_STATUS"] == "AT_STOP"])
    avg_speed = vehicles_df["CURRENT_SPEED"].mean()
    col_k1.metric("Vehicles Active", active_count)
    col_k2.metric("In Transit", in_transit)
    col_k3.metric("At Customer Stop", at_stop)
    col_k4.metric("Avg Speed (mph)", f"{avg_speed:.1f}" if avg_speed else "0.0")

    def get_vehicle_color(status):
        if status == "IN_TRANSIT":
            return [0, 200, 80, 200]
        elif status == "AT_STOP":
            return [255, 200, 0, 200]
        return [200, 60, 60, 200]

    vehicles_df["COLOR"] = vehicles_df["MOVEMENT_STATUS"].apply(get_vehicle_color)

    paths = []
    for vid in telemetry_df["VEHICLE_ID"].unique():
        vdata = telemetry_df[telemetry_df["VEHICLE_ID"] == vid].sort_values("TIMESTAMP")
        path_coords = [[row["LONGITUDE"], row["LATITUDE"]] for _, row in vdata.iterrows()]
        if len(path_coords) > 1:
            paths.append({"path": path_coords, "name": vid})

    vehicle_layer = pdk.Layer(
        "ScatterplotLayer",
        data=vehicles_df,
        get_position=["CURRENT_LNG", "CURRENT_LAT"],
        get_fill_color="COLOR",
        get_radius=300,
        pickable=True,
        auto_highlight=True,
    )

    customer_layer = pdk.Layer(
        "ScatterplotLayer",
        data=customers_df,
        get_position=["LONGITUDE", "LATITUDE"],
        get_fill_color=[65, 105, 225, 160],
        get_radius=180,
        pickable=True,
    )

    depot_layer = pdk.Layer(
        "ScatterplotLayer",
        data=[{"lat": DEPOT_LAT, "lng": DEPOT_LNG, "name": "Atlanta Central Depot"}],
        get_position=["lng", "lat"],
        get_fill_color=[220, 20, 60, 220],
        get_radius=500,
        pickable=True,
    )

    path_layer = pdk.Layer(
        "PathLayer",
        data=paths,
        get_path="path",
        get_color=[100, 100, 255, 120],
        width_min_pixels=2,
        pickable=True,
    )

    view_state = pdk.ViewState(
        latitude=33.82,
        longitude=-84.38,
        zoom=10,
        pitch=0,
    )

    deck = pdk.Deck(
        layers=[path_layer, customer_layer, depot_layer, vehicle_layer],
        initial_view_state=view_state,
        tooltip={
            "text": "{DRIVER_NAME}\n{VEHICLE_ID} - {MOVEMENT_STATUS}\nSpeed: {CURRENT_SPEED} mph\nRoute: {ASSIGNED_ROUTE}"
        },
    )

    st.pydeck_chart(deck, use_container_width=True)

    col_legend1, col_legend2, col_legend3, col_legend4 = st.columns(4)
    col_legend1.markdown(":green_circle: **In Transit**")
    col_legend2.markdown(":yellow_circle: **At Customer Stop**")
    col_legend3.markdown(":red_circle: **Depot / Parked**")
    col_legend4.markdown(":blue_circle: **Customer Locations**")

    with st.expander("Vehicle Detail Table"):
        st.dataframe(
            vehicles_df[["VEHICLE_ID", "DRIVER_NAME", "ASSIGNED_ROUTE", "MOVEMENT_STATUS", "CURRENT_SPEED", "LAST_PING"]],
            use_container_width=True,
            hide_index=True,
        )

# ─────────────────────────────────────────────────────────────
# TAB 2: IoT Dashboard
# ─────────────────────────────────────────────────────────────
with tab_iot:
    st.header("Garment Lifecycle -- RFID Tracking")

    lifecycle_df = session.sql("""
        SELECT GARMENT_STATUS, COUNT(*) AS CNT
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS
        GROUP BY GARMENT_STATUS
        ORDER BY CNT DESC
    """).to_pandas()

    events_summary = session.sql("""
        SELECT EVENT_TYPE, COUNT(*) AS EVENT_COUNT
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_EVENTS
        GROUP BY EVENT_TYPE
        ORDER BY EVENT_COUNT DESC
    """).to_pandas()

    col_g1, col_g2, col_g3 = st.columns(3)
    total_garments = session.sql("SELECT COUNT(*) AS C FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS").to_pandas()["C"][0]
    lost_garments = session.sql("SELECT COUNT(*) AS C FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS WHERE STATUS = 'LOST'").to_pandas()["C"][0]
    total_events = session.sql("SELECT COUNT(*) AS C FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_EVENTS").to_pandas()["C"][0]
    col_g1.metric("Total Garments", f"{total_garments:,}")
    col_g2.metric("Lost Garments", lost_garments)
    col_g3.metric("RFID Events Logged", f"{total_events:,}")

    col_chart1, col_chart2 = st.columns(2)
    with col_chart1:
        st.subheader("Garment Status")
        st.bar_chart(lifecycle_df.set_index("GARMENT_STATUS")["CNT"])

    with col_chart2:
        st.subheader("Events by Type")
        st.bar_chart(events_summary.set_index("EVENT_TYPE")["EVENT_COUNT"])

    st.subheader("Loss Rate by Customer")
    loss_df = session.sql("""
        SELECT CUSTOMER_NAME, GARMENT_TYPE, TOTAL_GARMENTS, LOST_COUNT, LOSS_RATE_PCT
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.V_GARMENT_LOSS_RATE
        WHERE LOST_COUNT > 0
        ORDER BY LOSS_RATE_PCT DESC
    """).to_pandas()
    st.dataframe(loss_df, use_container_width=True, hide_index=True)

    st.subheader("Recent Garment Events")
    recent_events = session.sql("""
        SELECT ge.GARMENT_ID, g.GARMENT_TYPE, ge.EVENT_TYPE, ge.EVENT_TIMESTAMP,
               ge.LOCATION, ge.NOTES
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_EVENTS ge
        JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS g ON ge.GARMENT_ID = g.GARMENT_ID
        ORDER BY ge.EVENT_TIMESTAMP DESC
        LIMIT 25
    """).to_pandas()
    st.dataframe(recent_events, use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────────────────────
# TAB 3: CFO Chat
# ─────────────────────────────────────────────────────────────
with tab_cfo:
    st.header("CFO Financial Assistant")
    st.caption("Ask questions about revenue, costs, margins, budget variance, and customer profitability.")

    sample_questions = [
        "What is our monthly P&L summary?",
        "Where are we vs budget this quarter?",
        "Who are our top customers by revenue?",
        "What is our gross margin percentage?",
        "Show me revenue by customer industry",
        "What are garment replacement costs trending?",
    ]

    st.markdown("**Try these questions:**")
    cols = st.columns(3)
    for i, q in enumerate(sample_questions):
        if cols[i % 3].button(q, key=f"sq_{i}"):
            st.session_state["cfo_question"] = q

    if "cfo_messages" not in st.session_state:
        st.session_state["cfo_messages"] = []

    for msg in st.session_state["cfo_messages"]:
        with st.chat_message(msg["role"]):
            if msg.get("is_table"):
                st.dataframe(msg["content"], use_container_width=True, hide_index=True)
            else:
                st.write(msg["content"])

    question = st.chat_input("Ask the CFO Assistant...")
    if "cfo_question" in st.session_state:
        question = st.session_state.pop("cfo_question")

    if question:
        st.session_state["cfo_messages"].append({"role": "user", "content": question})
        with st.chat_message("user"):
            st.write(question)

        with st.chat_message("assistant"):
            with st.spinner("Analyzing..."):
                try:
                    result = session.sql(f"""
                        SELECT * FROM TABLE(
                            SNOWFLAKE.CORTEX.SEMANTIC_VIEW_QUERY(
                                'SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_IOT_FINANCIAL',
                                '{question.replace("'", "''")}'
                            )
                        )
                    """).to_pandas()

                    if len(result) > 0:
                        st.dataframe(result, use_container_width=True, hide_index=True)
                        st.session_state["cfo_messages"].append(
                            {"role": "assistant", "content": result, "is_table": True}
                        )
                    else:
                        st.info("No results found for that question.")
                        st.session_state["cfo_messages"].append(
                            {"role": "assistant", "content": "No results found."}
                        )
                except Exception as e:
                    fallback_msg = f"I couldn't process that question directly. Error: {str(e)[:200]}\n\nTry rephrasing or use the CFO Assistant in Snowflake Intelligence for full agent capabilities."
                    st.warning(fallback_msg)
                    st.session_state["cfo_messages"].append(
                        {"role": "assistant", "content": fallback_msg}
                    )
