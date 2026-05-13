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
    ('CHECK_IN', 'Receiving Dock', 'SC-001', 'Soiled pickup from customer'),
    ('WASH',     'Wash Line 2',    'SC-003', 'Standard wash cycle'),
    ('DRY',      'Dryer Bay 1',    'SC-004', '45 min high heat'),
    ('FOLD',     'Finishing Area',  'SC-005', 'QC passed'),
    ('DISPATCH', 'Loading Dock',    'SC-006', 'Loaded on V-001'),
    ('DELIVER',  'Customer Dock',   'SC-007', 'Delivered successfully'),
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
        SELECT CUSTOMER_ID, CUSTOMER_NAME, INDUSTRY, LATITUDE, LONGITUDE
        FROM CUSTOMERS
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
               CUSTOMER_NAME
        FROM V_GARMENT_LIFECYCLE
        ORDER BY GARMENT_ID
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
    counts = {r[0]: int(r[1]) for r in rows}
    return [{"stage": s, "count": counts.get(s, 0)} for s in stage_order]


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
