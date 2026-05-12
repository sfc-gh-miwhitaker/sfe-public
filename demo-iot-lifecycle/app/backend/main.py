import os
import json
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import snowflake.connector

app = FastAPI()

def get_connection():
    return snowflake.connector.connect(
        connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME", "default"),
        database="SNOWFLAKE_EXAMPLE",
        schema="IOT_LIFECYCLE",
        warehouse="SFE_IOT_LIFECYCLE_WH",
    )

@app.get("/api/telemetry")
def get_telemetry():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT VEHICLE_ID,
               EXTRACT(EPOCH FROM TIMESTAMP)::INTEGER AS TIMESTAMP,
               LATITUDE, LONGITUDE, SPEED_MPH, ENGINE_STATUS
        FROM GPS_TELEMETRY
        ORDER BY VEHICLE_ID, TIMESTAMP
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "vehicle_id": r[0],
            "timestamp": r[1],
            "latitude": r[2],
            "longitude": r[3],
            "speed_mph": float(r[4]),
            "engine_status": r[5],
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

app.mount("/", StaticFiles(directory="/app/static", html=True), name="static")
