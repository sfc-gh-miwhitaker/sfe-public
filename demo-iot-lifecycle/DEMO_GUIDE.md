# Demo Guide -- IoT Lifecycle

## Opening (30 seconds)

Open the dashboard URL in your browser. You'll see an Atlanta street map with colored dots -- that's your fleet.

> "This is our operations center. Every vehicle, every garment, every RFID scan -- live from Snowflake."

## Act 1: Fleet in Motion (60 seconds)

Click **Start Simulation** in the top-right corner.

Watch V-001 start moving across the map. Toast notifications pop in the corner as it reaches each stop:
- "V-001 moving -- 26 mph"
- "V-001 arrived at stop"

> "These GPS pings are flowing into Snowflake every 3 seconds. The dashboard polls and updates -- no refresh needed. This is the same pattern that would connect to a real telematics provider."

Hover over any dot to see the vehicle details. Blue dots are customers. The red dot is our central depot.

## Act 2: Garment Lifecycle (60 seconds)

Click the **Garments** tab.

With the simulation still running, watch the Event Feed on the right. Events appear every few seconds:
- CHECK_IN at Receiving Dock
- WASH at Wash Line 2
- DRY at Dryer Bay 1
- FOLD at Finishing Area
- DISPATCH at Loading Dock
- DELIVER at Customer Dock

> "Every garment has an RFID tag. Every touch point scans it. We're watching a scrub set move through the entire laundry lifecycle in real-time."

Point to the inventory table on the left -- color-coded status badges, wash counts, hours since last scan.

> "If something goes missing, we know immediately. Two garments are already flagged LOST."

## Act 3: CFO Intelligence (60 seconds)

Open Snowflake Intelligence (sidebar in Snowsight).

Ask: **"What is our P&L for the last quarter?"**

Then: **"Which customers are most profitable?"**

Then: **"Where are we vs budget this month?"**

> "The CFO doesn't need to write SQL. They don't need to wait for a report. They ask a question and get an answer -- backed by the same data platform running the operations."

## Closing (30 seconds)

Click **Stop Simulation**.

> "What you just saw: real-time fleet tracking, RFID lifecycle management, and AI-powered financial analysis. Three surfaces, one platform. Every INSERT, every scan, every question -- all powered by Snowflake."
