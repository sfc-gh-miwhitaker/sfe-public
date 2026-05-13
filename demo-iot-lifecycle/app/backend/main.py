import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import snowflake.connector

app = FastAPI()


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
