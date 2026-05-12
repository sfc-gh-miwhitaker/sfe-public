import streamlit as st
import pydeck as pdk
import pandas as pd
import time
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

    customers_df = session.sql("""
        SELECT CUSTOMER_ID, CUSTOMER_NAME, INDUSTRY, CITY,
               LATITUDE, LONGITUDE, MONTHLY_VALUE
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS
    """).to_pandas()

    telemetry_df = session.sql("""
        SELECT VEHICLE_ID, TIMESTAMP, LATITUDE, LONGITUDE, SPEED_MPH, ENGINE_STATUS
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GPS_TELEMETRY
        ORDER BY TIMESTAMP
    """).to_pandas()

    telemetry_df["TIMESTAMP"] = pd.to_datetime(telemetry_df["TIMESTAMP"])
    all_timestamps = sorted(telemetry_df["TIMESTAMP"].unique())

    st.sidebar.markdown("### Playback Controls")
    auto_play = st.sidebar.button("Play Route Animation", type="primary")
    speed = st.sidebar.slider("Playback speed (seconds per frame)", 0.5, 3.0, 1.0, 0.5)

    time_idx = st.sidebar.slider(
        "Timeline",
        min_value=0,
        max_value=len(all_timestamps) - 1,
        value=len(all_timestamps) - 1,
        format=f"Step %d of {len(all_timestamps)}",
        key="time_slider",
    )

    current_time = all_timestamps[time_idx]
    st.sidebar.caption(f"Showing positions at: **{pd.Timestamp(current_time).strftime('%H:%M')}**")

    def get_positions_at_time(ts):
        mask = telemetry_df["TIMESTAMP"] <= ts
        latest = telemetry_df[mask].groupby("VEHICLE_ID").tail(1).copy()
        colors = []
        statuses = []
        for _, row in latest.iterrows():
            if row["ENGINE_STATUS"] == "IDLE" and row["SPEED_MPH"] == 0:
                colors.append([255, 200, 0, 220])
                statuses.append("AT_STOP")
            elif row["SPEED_MPH"] > 0:
                colors.append([0, 200, 80, 220])
                statuses.append("IN_TRANSIT")
            else:
                colors.append([200, 60, 60, 220])
                statuses.append("PARKED")
        latest["COLOR"] = colors
        latest["STATUS"] = statuses
        return latest

    def get_trails_at_time(ts):
        mask = telemetry_df["TIMESTAMP"] <= ts
        trails = []
        for vid in telemetry_df["VEHICLE_ID"].unique():
            vdata = telemetry_df[mask & (telemetry_df["VEHICLE_ID"] == vid)].sort_values("TIMESTAMP")
            if len(vdata) > 1:
                path_coords = [[row["LONGITUDE"], row["LATITUDE"]] for _, row in vdata.iterrows()]
                trails.append({"path": path_coords, "name": vid})
        return trails

    def render_map(positions_df, trails):
        vehicle_layer = pdk.Layer(
            "ScatterplotLayer",
            data=positions_df,
            get_position=["LONGITUDE", "LATITUDE"],
            get_fill_color="COLOR",
            get_radius=350,
            pickable=True,
            auto_highlight=True,
        )
        customer_layer = pdk.Layer(
            "ScatterplotLayer",
            data=customers_df,
            get_position=["LONGITUDE", "LATITUDE"],
            get_fill_color=[65, 105, 225, 140],
            get_radius=180,
            pickable=True,
        )
        depot_layer = pdk.Layer(
            "ScatterplotLayer",
            data=[{"LATITUDE": DEPOT_LAT, "LONGITUDE": DEPOT_LNG, "name": "Atlanta Central Depot"}],
            get_position=["LONGITUDE", "LATITUDE"],
            get_fill_color=[220, 20, 60, 220],
            get_radius=500,
            pickable=True,
        )
        path_layer = pdk.Layer(
            "PathLayer",
            data=trails,
            get_path="path",
            get_color=[100, 100, 255, 100],
            width_min_pixels=2,
        )
        view_state = pdk.ViewState(latitude=33.82, longitude=-84.38, zoom=10, pitch=0)
        return pdk.Deck(
            layers=[path_layer, customer_layer, depot_layer, vehicle_layer],
            initial_view_state=view_state,
            tooltip={"text": "{VEHICLE_ID}\nSpeed: {SPEED_MPH} mph\nStatus: {STATUS}"},
        )

    positions = get_positions_at_time(current_time)
    trails = get_trails_at_time(current_time)

    col_k1, col_k2, col_k3, col_k4 = st.columns(4)
    in_transit = len(positions[positions["STATUS"] == "IN_TRANSIT"])
    at_stop = len(positions[positions["STATUS"] == "AT_STOP"])
    parked = len(positions[positions["STATUS"] == "PARKED"])
    avg_speed = positions["SPEED_MPH"].mean()
    col_k1.metric("Vehicles Tracked", len(positions))
    col_k2.metric("In Transit", in_transit)
    col_k3.metric("At Customer Stop", at_stop)
    col_k4.metric("Avg Speed (mph)", f"{avg_speed:.1f}" if pd.notna(avg_speed) else "0.0")

    map_placeholder = st.empty()

    if auto_play:
        for i in range(len(all_timestamps)):
            ts = all_timestamps[i]
            pos = get_positions_at_time(ts)
            trl = get_trails_at_time(ts)
            deck = render_map(pos, trl)
            map_placeholder.pydeck_chart(deck, use_container_width=True)
            time.sleep(speed)
    else:
        deck = render_map(positions, trails)
        map_placeholder.pydeck_chart(deck, use_container_width=True)

    col_legend1, col_legend2, col_legend3, col_legend4 = st.columns(4)
    col_legend1.markdown(":green_circle: **In Transit**")
    col_legend2.markdown(":yellow_circle: **At Customer Stop**")
    col_legend3.markdown(":red_circle: **Depot / Parked**")
    col_legend4.markdown(":blue_circle: **Customer Locations**")

    with st.expander("GPS Telemetry Log"):
        display_df = telemetry_df[telemetry_df["TIMESTAMP"] <= current_time].sort_values("TIMESTAMP", ascending=False).head(20)
        display_df["TIME"] = display_df["TIMESTAMP"].dt.strftime("%H:%M")
        st.dataframe(
            display_df[["VEHICLE_ID", "TIME", "LATITUDE", "LONGITUDE", "SPEED_MPH", "ENGINE_STATUS"]],
            use_container_width=True,
            hide_index=True,
        )

# ─────────────────────────────────────────────────────────────
# TAB 2: IoT Dashboard
# ─────────────────────────────────────────────────────────────
with tab_iot:
    st.header("Garment Lifecycle -- RFID Tracking")

    lifecycle_df = session.sql("""
        SELECT STATUS AS GARMENT_STATUS, COUNT(*) AS CNT
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS
        GROUP BY STATUS
        ORDER BY CNT DESC
    """).to_pandas()

    events_summary = session.sql("""
        SELECT EVENT_TYPE, COUNT(*) AS EVENT_COUNT
        FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_EVENTS
        GROUP BY EVENT_TYPE
        ORDER BY EVENT_COUNT DESC
    """).to_pandas()

    col_g1, col_g2, col_g3 = st.columns(3)
    total_garments = int(session.sql("SELECT COUNT(*) AS C FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS").to_pandas()["C"][0])
    lost_garments = int(session.sql("SELECT COUNT(*) AS C FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS WHERE STATUS = 'LOST'").to_pandas()["C"][0])
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
