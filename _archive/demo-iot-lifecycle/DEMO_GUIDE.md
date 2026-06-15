# Demo Guide -- IoT Lifecycle: Agentic Operations Engine

## The Narrative

Metro Textile Services has billions of data points flowing through Snowflake: RFID garment scans, GPS telemetry, invoices, customer satisfaction scores. Today this data feeds dashboards that show what happened. This demo pivots to showing **what should happen next** -- Snowflake as an Agentic Operations Engine.

---

## Phase 1: Executive Vision -- The Hook (90 seconds)

### Setup
Open the dashboard URL. You'll see the Atlanta metro map with color-coded customer dots.

### The Reveal

> "This is our operations center. Notice the colors -- red dots are customers with **zombie garments**. Those are items we delivered that haven't come back in over 14 days."

Hover over a red dot (Peachtree General Hospital):
> "120 towels stalled here for over 2 weeks. That's $660 in replacement cost just... sitting there."

Point to the KPI bar showing **Zombie Garments** and **Financial Exposure**:
> "Across our network right now: [zombie count] garments are unaccounted for. That's [$X] in inventory at risk."

### Snowflake Intelligence

Open Snowflake Intelligence. Select **Operations Agent**.

Ask: **"What are the top 3 silent operational leaks right now?"**

> "The agent cross-references RFID lifecycle state, days-at-location, customer satisfaction scores, and replacement costs. It doesn't just show you a number -- it tells you where the bleeding is and how much it costs."

---

## Phase 2: Agentic Lifecycle -- The Core (90 seconds)

### Click the Garments Tab

Point to the **Customer Loop** strip at the top:
> "This is the garment loop: Clean Out, At Customer, Soiled Return. A healthy garment cycles through every 5-7 days. The zombie badge tells us how many have broken the loop."

Point to the **Retention Alerts** panel on the right:
> "These are auto-generated alerts for our route drivers. Each one includes the customer, how many tags are missing, the dollar value we save by recovering them, and a conversational talking point the driver can use."

Read one alert:
> "'Hi -- we noticed 120 towels from your last few deliveries haven't made it back. They're likely in a storage closet. If we recover them today, that's $660 in avoided replacement charges.' This is what agentic operations looks like -- the system tells your people what to do next."

### Ask the Operations Agent

Ask: **"Draft a retention alert for our highest-risk customer"**

> "It generates the alert with financial context, customer-specific details, and even a driver script. No human had to compile this."

Ask: **"Which garments are approaching retirement?"**

> "40 scrubs at Grady Memorial are at 110+ wash cycles out of 120. If they disappear now instead of coming back for replacement, that's $668 unrecoverable."

---

## Phase 3: Real-Time Map -- The Wow Factor (60 seconds)

### Switch Back to Fleet Tab

Click **Start Simulation**. Vehicles begin moving.

> "Now watch the map come alive. Every GPS ping, every 3 seconds, written to Snowflake and reflected here. But the real power is the overlay."

> **Production Note:** In a real deployment, GPS devices would stream telemetry directly to Snowflake via the Snowpipe Streaming REST API -- no intermediate files or message queues. RFID scanners at each plant zone would feed a Python aggregator using the Snowpipe Streaming SDK. Data becomes queryable in ~5 seconds with exactly-once delivery. See the standalone [`guide-snowpipe-streaming-iot`](../guide-snowpipe-streaming-iot/) for the full walk-through.

Point to the risk-banded dots:
- **Red** = zombie cluster (C-001, C-016, C-019)
- **Yellow** = elevated risk (C-008, C-013)
- **Green** = golden customer (C-007, 99.8% return rate)

> "When a driver reaches a red dot, their route app shows the retention alert we saw earlier. They don't just deliver -- they recover."

### Route Efficiency

Ask the Operations Agent: **"Which routes have fuel cost anomalies?"**

> "Route R-006 West Metro Industrial is running 15% above benchmark on fuel. The agent correlates stop inefficiency with mileage data to suggest merging two stops."

---

## Closing (30 seconds)

Click **Stop Simulation**.

> "What you just saw: the data isn't just in Snowflake -- it's working. Zombie detection, retention alerts, route optimization, financial exposure calculations. Every recovered garment saves $16.92. Every alert the driver follows reduces churn and carbon footprint. This isn't a dashboard that tells you what happened yesterday. This is an operations engine that tells your people what to do *right now*."

---

## Built-In Anomalies Cheat Sheet

| Customer | Anomaly | Zombie Count | Exposure |
|----------|---------|:---:|---:|
| C-001 Peachtree General Hospital | 120 towels stalled >14 days | 120 | $660 |
| C-008 Emory University Hospital | 4 items (scrubs + lab coat) stalled 16-18 days | 4 | ~$59 |
| C-013 Grady Memorial Hospital | 40 scrubs at 110-118 wash cycles (near 120 retirement) | 0* | $668* |
| C-016 Dunwoody Hilton | 25 linens stalled (rising loss + CSAT drop) | 25 | ~$238 |
| C-019 Smyrna Collision Center | 18 shop towels stalled (rising loss + disputes) | 18 | ~$63 |
| R-006 West Metro Industrial | +15% fuel variance vs benchmark route | -- | Route cost |
| C-007 Georgia Tech Dining | **Golden customer** -- 99.8% return rate | 0 | $0 |

*C-013's risk is retirement, not zombie -- items are at customer but approaching end-of-life.

---

## Key Talking Points

- "You already have this data in Snowflake. Today it powers dashboards. Tomorrow it powers autonomous operations."
- "This agent doesn't just report what happened -- it tells your drivers what to do next."
- "Every recovered garment saves $16.92 in replacement AND reduces your carbon footprint."
- "Your team already started experimenting with Cortex. This demo extends what they started into production-grade agentic workflows."

---

## Prompt Templates for Live Demo

### Executive Vision
> "Analyze our current RFID data across the Atlanta metro area. Identify the top 3 silent operational leaks -- garments stalled at customer sites beyond our 14-day threshold. Calculate the immediate replacement cost impact."

### Agentic Lifecycle
> "Monitor the garment loop. Identify zombie garments not returned within 3 cycles. For the highest-risk customer, draft a Retention Alert that includes the Customer ID, missing RFID tags, financial save value, and a suggested talking point for the driver."

### Route Optimization
> "Analyze route-level fuel costs and flag any routes where variance exceeds 15% above the benchmark. Suggest stops that could be merged for efficiency."

### Combined Demo Boss Question
> "Give me a full operations status: How many zombie garments total, which customers have the highest financial exposure, any routes eroding profitability, and draft a recovery action plan for our top-risk site."
