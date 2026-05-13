import os
import threading
import time
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import snowflake.connector

app = FastAPI()

ROUTE_WAYPOINTS = [
    (33.7490, -84.3880, 0.0, 'IDLE'),
    (33.7530, -84.3865, 22.0, 'ON'),
    (33.7580, -84.3850, 26.0, 'ON'),
    (33.7640, -84.3845, 30.0, 'ON'),
    (33.7720, -84.3843, 28.0, 'ON'),
    (33.7800, -84.3842, 25.0, 'ON'),
    (33.7860, -84.3843, 18.0, 'ON'),
    (33.7896, -84.3843, 0.0, 'IDLE'),
    (33.7860, -84.3845, 20.0, 'ON'),
    (33.7800, -84.3848, 24.0, 'ON'),
    (33.7750, -84.3850, 26.0, 'ON'),
    (33.7710, -84.3850, 0.0, 'IDLE'),
    (33.7680, -84.3820, 18.0, 'ON'),
    (33.7620, -84.3790, 22.0, 'ON'),
    (33.7556, -84.3818, 0.0, 'IDLE'),
    (33.7530, -84.3840, 16.0, 'ON'),
    (33.7500, -84.3860, 20.0, 'ON'),
    (33.7490, -84.3880, 0.0, 'IDLE'),
]

GARMENT_LIFECYCLE = [
    ('SOILED_RETURN', 'Receiving Dock', 'SC-001', 'Soiled pickup from customer'),
    ('CHECK_IN',      'Receiving Dock', 'SC-001', 'Sorted for wash'),
    ('WASH',          'Wash Line 2',    'SC-003', 'Standard wash cycle'),
    ('DRY',           'Dryer Bay 1',    'SC-004', '45 min high heat'),
    ('FOLD',          'Finishing Area',  'SC-005', 'QC passed'),
    ('DISPATCH',      'Loading Dock',    'SC-006', 'Loaded on V-001'),
    ('CLEAN_OUT',     'Loading Dock',    'SC-006', 'Scanned onto truck'),
    ('DELIVER',       'Customer Dock',   'SC-007', 'Delivered successfully'),
    ('AT_CUSTOMER',   'Customer Site',   'SC-007', 'At customer site'),
]

GARMENT_IDS = [f'G-{i:04d}' for i in range(40)]

simulator_state = {"running": False, "thread": None}


def get_login_token():
    with open('/snowflake/session/token', 'r') as f:
        return f.read()


def get_connection():
    if os.path.exists('/snowflake/session/token'):
        return snowflake.connector.connect(
            host=os.getenv('SNOWFLAKE_HOST'),
            account=os.getenv('SNOWFLAKE_ACCOUNT'),
            token=get_login_token(),
            authenticator='oauth',
            database=os.getenv('SNOWFLAKE_DATABASE'),
            schema=os.getenv('SNOWFLAKE_SCHEMA'),
            warehouse='SFE_IOT_LIFECYCLE_WH',
        )
    return snowflake.connector.connect(
        connection_name=os.getenv('SNOWFLAKE_CONNECTION_NAME', 'default'),
        database='SNOWFLAKE_EXAMPLE',
        schema='IOT_LIFECYCLE',
        warehouse='SFE_IOT_LIFECYCLE_WH',
    )


def run_simulator():
    route_idx = 0
    garment_idx = 0
    lifecycle_idx = 0
    tick = 0

    while simulator_state["running"]:
        try:
            conn = get_connection()
            cur = conn.cursor()

            lat, lng, speed, engine = ROUTE_WAYPOINTS[route_idx % len(ROUTE_WAYPOINTS)]
            cur.execute(
                "INSERT INTO GPS_TELEMETRY (VEHICLE_ID, TIMESTAMP, LATITUDE, LONGITUDE, SPEED_MPH, ENGINE_STATUS) "
                "VALUES (%s, CURRENT_TIMESTAMP(), %s, %s, %s, %s)",
                ('V-001', lat, lng, speed, engine)
            )
            route_idx += 1

            if tick % 3 == 0:
                event_type, location, scanner, notes = GARMENT_LIFECYCLE[lifecycle_idx % len(GARMENT_LIFECYCLE)]
                garment_id = GARMENT_IDS[garment_idx % len(GARMENT_IDS)]
                cur.execute(
                    "INSERT INTO GARMENT_EVENTS (GARMENT_ID, EVENT_TYPE, EVENT_TIMESTAMP, LOCATION, SCANNER_ID, NOTES) "
                    "VALUES (%s, %s, CURRENT_TIMESTAMP(), %s, %s, %s)",
                    (garment_id, event_type, location, scanner, notes)
                )
                lifecycle_idx += 1
                if lifecycle_idx % len(GARMENT_LIFECYCLE) == 0:
                    garment_idx += 1

            cur.close()
            conn.close()
        except Exception as e:
            print(f"Simulator error: {e}")

        tick += 1
        time.sleep(3)


@app.get("/api/simulate/start")
def start_simulation():
    if simulator_state["running"]:
        return {"status": "already_running"}
    simulator_state["running"] = True
    t = threading.Thread(target=run_simulator, daemon=True)
    t.start()
    simulator_state["thread"] = t
    return {"status": "started"}


@app.get("/api/simulate/stop")
def stop_simulation():
    simulator_state["running"] = False
    return {"status": "stopped"}


@app.get("/api/simulate/status")
def simulation_status():
    return {"running": simulator_state["running"]}


@app.get("/api/positions")
def get_positions():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT VEHICLE_ID, LATITUDE, LONGITUDE, SPEED_MPH, ENGINE_STATUS, TIMESTAMP
        FROM GPS_TELEMETRY
        QUALIFY ROW_NUMBER() OVER (PARTITION BY VEHICLE_ID ORDER BY TIMESTAMP DESC) = 1
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "vehicle_id": r[0],
            "latitude": r[1],
            "longitude": r[2],
            "speed_mph": float(r[3]),
            "engine_status": r[4],
            "timestamp": str(r[5]),
        }
        for r in rows
    ]


@app.get("/api/customers")
def get_customers():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT c.CUSTOMER_ID, c.CUSTOMER_NAME, c.INDUSTRY, c.LATITUDE, c.LONGITUDE,
               cr.RISK_BAND, cr.ZOMBIE_COUNT, cr.FINANCIAL_EXPOSURE_USD
        FROM CUSTOMERS c
        LEFT JOIN V_CUSTOMER_RISK cr ON c.CUSTOMER_ID = cr.CUSTOMER_ID
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "customer_id": r[0],
            "customer_name": r[1],
            "industry": r[2],
            "latitude": r[3],
            "longitude": r[4],
            "risk_band": r[5] or 'NORMAL',
            "zombie_count": int(r[6]) if r[6] else 0,
            "financial_exposure_usd": float(r[7]) if r[7] else 0.0,
        }
        for r in rows
    ]


@app.get("/api/vehicles")
def get_vehicles():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT VEHICLE_ID, LICENSE_PLATE, DRIVER_NAME, VEHICLE_TYPE, HOME_DEPOT, STATUS
        FROM FLEET_VEHICLES
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "vehicle_id": r[0],
            "license_plate": r[1],
            "driver_name": r[2],
            "vehicle_type": r[3],
            "home_depot": r[4],
            "status": r[5],
        }
        for r in rows
    ]


@app.get("/api/garments")
def get_garments():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT GARMENT_ID, RFID_TAG, GARMENT_TYPE, SIZE, COLOR,
               CUSTOMER_ID, GARMENT_STATUS, WASH_COUNT,
               LAST_EVENT, LAST_EVENT_TIME, HOURS_SINCE_LAST_EVENT,
               CUSTOMER_NAME, LIFECYCLE_STATE, DAYS_AT_LOCATION,
               REPLACEMENT_COST, USEFUL_LIFE_CYCLES, WASH_CYCLE_PCT_OF_LIFE
        FROM V_GARMENT_LIFECYCLE
        ORDER BY GARMENT_ID
        LIMIT 200
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "garment_id": r[0],
            "rfid_tag": r[1],
            "garment_type": r[2],
            "size": r[3],
            "color": r[4],
            "customer_id": r[5],
            "status": r[6],
            "wash_count": int(r[7]) if r[7] else 0,
            "last_event": r[8],
            "last_event_time": str(r[9]) if r[9] else None,
            "hours_since_last_event": int(r[10]) if r[10] else None,
            "customer_name": r[11],
            "lifecycle_state": r[12],
            "days_at_location": int(r[13]) if r[13] else 0,
            "replacement_cost": float(r[14]) if r[14] else 0.0,
            "useful_life_cycles": int(r[15]) if r[15] else 100,
            "wash_cycle_pct": float(r[16]) if r[16] else 0.0,
        }
        for r in rows
    ]


@app.get("/api/garment-pipeline")
def get_garment_pipeline():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        WITH latest_events AS (
            SELECT GARMENT_ID, EVENT_TYPE
            FROM GARMENT_EVENTS
            QUALIFY ROW_NUMBER() OVER (PARTITION BY GARMENT_ID ORDER BY EVENT_TIMESTAMP DESC) = 1
        )
        SELECT
            COALESCE(le.EVENT_TYPE, 'CHECK_IN') AS STAGE,
            COUNT(*) AS CNT
        FROM GARMENTS g
        LEFT JOIN latest_events le ON g.GARMENT_ID = le.GARMENT_ID
        WHERE g.STATUS = 'IN_SERVICE'
        GROUP BY COALESCE(le.EVENT_TYPE, 'CHECK_IN')
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    stage_order = ['CHECK_IN', 'WASH', 'DRY', 'FOLD', 'DISPATCH', 'DELIVER']
    loop_order = ['CLEAN_OUT', 'AT_CUSTOMER', 'SOILED_RETURN']
    counts = {r[0]: int(r[1]) for r in rows}
    return {
        "factory": [{"stage": s, "count": counts.get(s, 0)} for s in stage_order],
        "loop": [{"stage": s, "count": counts.get(s, 0)} for s in loop_order],
    }


@app.get("/api/zombie-summary")
def get_zombie_summary():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT COUNT(*) AS ZOMBIE_COUNT,
               COALESCE(SUM(REPLACEMENT_COST), 0) AS TOTAL_EXPOSURE,
               COALESCE(AVG(DAYS_AT_LOCATION), 0) AS AVG_DAYS_STALLED
        FROM GARMENTS
        WHERE LIFECYCLE_STATE = 'ZOMBIE'
    """)
    row = cur.fetchone()
    cur.close()
    conn.close()
    return {
        "zombie_count": int(row[0]),
        "total_exposure_usd": float(row[1]),
        "avg_days_stalled": float(row[2]),
    }


@app.get("/api/retention-alerts")
def get_retention_alerts():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT ALERT_ID, CUSTOMER_ID, CUSTOMER_NAME, INDUSTRY, ROUTE_NAME,
               DRIVER_NAME, ALERT_DATE, MISSING_TAG_COUNT, FINANCIAL_SAVE_USD,
               DRIVER_TALKING_POINT, ALERT_STATUS, CSAT_SCORE
        FROM V_RETENTION_ALERTS
        WHERE ALERT_STATUS = 'PENDING'
        ORDER BY FINANCIAL_SAVE_USD DESC
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "alert_id": r[0],
            "customer_id": r[1],
            "customer_name": r[2],
            "industry": r[3],
            "route_name": r[4],
            "driver_name": r[5],
            "alert_date": str(r[6]),
            "missing_tag_count": int(r[7]),
            "financial_save_usd": float(r[8]),
            "driver_talking_point": r[9],
            "alert_status": r[10],
            "csat_score": float(r[11]) if r[11] else None,
        }
        for r in rows
    ]


@app.get("/api/garment-events")
def get_garment_events():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT ge.EVENT_ID, ge.GARMENT_ID, g.GARMENT_TYPE, ge.EVENT_TYPE,
               ge.EVENT_TIMESTAMP, ge.LOCATION, ge.SCANNER_ID, ge.NOTES
        FROM GARMENT_EVENTS ge
        JOIN GARMENTS g ON ge.GARMENT_ID = g.GARMENT_ID
        ORDER BY ge.EVENT_TIMESTAMP DESC
        LIMIT 50
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "event_id": r[0],
            "garment_id": r[1],
            "garment_type": r[2],
            "event_type": r[3],
            "timestamp": str(r[4]),
            "location": r[5],
            "scanner_id": r[6],
            "notes": r[7],
        }
        for r in rows
    ]


app.mount("/", StaticFiles(directory="/app/static", html=True), name="static")
