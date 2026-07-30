# Pattern 4: Snowflake Sentry + Splunk HEC

Instead of shipping raw Snowflake audit logs to Splunk (expensive, high-volume), run your security detections **inside Snowflake** and push only the findings to Splunk's HTTP Event Collector (HEC). Splunk becomes the alert/triage layer; Snowflake does the detection.

This is the lowest-SIEM-ingest-cost pattern. You ingest megabytes of findings instead of gigabytes of raw logs.

---

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE views
        │
        │  SQL detection queries (Tasks or stored procs)
        ▼
Findings stored in Snowflake table
        │
        │  Snowflake Task + External Access Integration
        │  POST to Splunk HEC endpoint
        ▼
Splunk (alerts, dashboards, SOAR playbooks)
```

---

## What is Sentry?

[Sentry](https://snowflake-labs.github.io/Sentry/) is an open-source project from Snowflake's Security Applied Field Engineering (SAFE) team. It provides:

- **Pre-built detection queries** mapped to MITRE ATT&CK (Exfiltration, Persistence, Credential Access, and more)
- **Deployment options:** Streamlit UI wizard, stored procedures, or raw SQL scripts
- **Reference log sources** with MITRE mappings: `snowflake-labs.github.io/Sentry/reference/log-sources.html`

You do not have to use Sentry to implement this pattern — you can write your own detection SQL. Sentry is a head start.

---

## Detection Categories (Sentry + Custom)

| Category | Example Detection | Source View |
|---|---|---|
| **Authentication** | Brute force (N failures, same user, short window) | `LOGIN_HISTORY` |
| **Authentication** | Impossible travel (login from two distant IPs in short time) | `LOGIN_HISTORY` |
| **Privilege escalation** | New `OWNERSHIP` or `ACCOUNTADMIN` grant | `GRANTS_TO_ROLES` |
| **Data exfiltration** | Large `BYTES_SENT_OVER_THE_NETWORK` spike | `DATA_TRANSFER_HISTORY` |
| **Data exfiltration** | COPY INTO external stage by non-standard users | `COPY_HISTORY` |
| **Reconnaissance** | Unusual `INFORMATION_SCHEMA` query patterns | `QUERY_HISTORY` |
| **Credential abuse** | Query execution under unexpected role | `QUERY_HISTORY` |
| **PII exposure** | Access to tagged sensitive columns | `ACCESS_HISTORY` |

---

## Step 1: Deploy Sentry

Option A — Streamlit UI (fastest for eval):
```
git clone https://github.com/Snowflake-Labs/Sentry
```
Follow Sentry's README to deploy the Streamlit app into your Snowflake account. The UI lets you enable/disable individual detections.

Option B — SQL scripts (production):
Run Sentry's stored procedure deploy scripts directly. This creates scheduled tasks that populate a findings table.

Either way, Sentry outputs findings to a table in your account (default: `SENTRY.PUBLIC.DETECTION_RESULTS` or similar — check current Sentry docs for the exact schema).

---

## Step 2: Set Up Splunk HEC

In Splunk:
1. Go to **Settings → Data Inputs → HTTP Event Collector → New Token**
2. Source type: `snowflake:sentry_finding` (custom; helps with Splunk field extraction)
3. Index: select your security index
4. Copy the generated HEC token — this goes into a Snowflake secret

In Splunk, also enable HEC if not already active:
**Settings → Data Inputs → HTTP Event Collector → Global Settings → Enable**

---

## Step 3: Create Snowflake Secret for HEC Token

Store the HEC token in Snowflake Secrets — never hardcode it in task SQL.

```sql
USE ROLE SECURITYADMIN;

CREATE OR REPLACE SECRET SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.SPLUNK_HEC_TOKEN
  TYPE = GENERIC_STRING
  SECRET_STRING = 'Splunk-<your-hec-token-here>'  -- pragma: allowlist secret
  COMMENT = 'Splunk HEC token for Sentry finding push (Expires: 2026-10-30)';
```

---

## Step 4: Create External Access Integration

Snowflake tasks need an External Access Integration to make outbound HTTP calls to Splunk HEC.

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NETWORK RULE SPLUNK_HEC_NETWORK_RULE
  MODE        = EGRESS
  TYPE        = HOST_PORT
  VALUE_LIST  = ('<your-splunk-hec-host>:8088')  -- replace with your HEC endpoint
  COMMENT     = 'Allow Snowflake tasks to reach Splunk HEC (Expires: 2026-10-30)';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SPLUNK_HEC_EAI
  ALLOWED_NETWORK_RULES   = (SPLUNK_HEC_NETWORK_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.SPLUNK_HEC_TOKEN)
  ENABLED                 = TRUE
  COMMENT                 = 'External access for Splunk HEC push (Expires: 2026-10-30)';
```

---

## Step 5: Python Stored Procedure to Push Findings

```sql
USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT;

CREATE OR REPLACE PROCEDURE PUSH_SENTRY_FINDINGS_TO_SPLUNK()
  RETURNS VARCHAR
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'push_findings'
  EXTERNAL_ACCESS_INTEGRATIONS = (SPLUNK_HEC_EAI)
  SECRETS = ('hec_token' = SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.SPLUNK_HEC_TOKEN)
  COMMENT = 'Push Sentry findings to Splunk HEC (Expires: 2026-10-30)'
AS $$
import requests
import _snowflake
import json

def push_findings(session):
    # Retrieve HEC token from Snowflake secret
    hec_token = _snowflake.get_generic_secret_string('hec_token')
    splunk_hec_url = 'https://<your-splunk-hec-host>:8088/services/collector/event'

    headers = {
        'Authorization': hec_token,
        'Content-Type': 'application/json'
    }

    # Fetch unsent findings from Sentry results table
    # Adjust the table name to match your Sentry deployment
    findings_df = session.sql("""
        SELECT
            DETECTION_NAME,
            SEVERITY,
            USER_NAME,
            DETAILS,
            DETECTED_AT,
            FINDING_ID
        FROM SENTRY.PUBLIC.DETECTION_RESULTS
        WHERE PUSHED_TO_SPLUNK = FALSE
          AND DETECTED_AT >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
        ORDER BY DETECTED_AT ASC
        LIMIT 500
    """).to_pandas()

    if findings_df.empty:
        return 'No new findings to push'

    pushed = 0
    failed = 0
    finding_ids = []

    for _, row in findings_df.iterrows():
        event = {
            'time': row['DETECTED_AT'].timestamp() if hasattr(row['DETECTED_AT'], 'timestamp') else None,
            'sourcetype': 'snowflake:sentry_finding',
            'event': {
                'detection_name': row['DETECTION_NAME'],
                'severity': row['SEVERITY'],
                'user_name': row['USER_NAME'],
                'details': row['DETAILS'],
                'finding_id': row['FINDING_ID']
            }
        }

        resp = requests.post(splunk_hec_url, headers=headers, json=event, timeout=10)

        if resp.status_code == 200:
            pushed += 1
            finding_ids.append(str(row['FINDING_ID']))
        else:
            failed += 1

    # Mark pushed findings to avoid re-sending
    if finding_ids:
        ids_list = ', '.join(finding_ids)
        session.sql(f"""
            UPDATE SENTRY.PUBLIC.DETECTION_RESULTS
            SET PUSHED_TO_SPLUNK = TRUE
            WHERE FINDING_ID IN ({ids_list})
        """).collect()

    return f'Pushed: {pushed}, Failed: {failed}'
$$;
```

---

## Step 6: Schedule the Push Task

```sql
CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.PUSH_SENTRY_TO_SPLUNK
  WAREHOUSE = SPLUNK_EXPORT_WH
  SCHEDULE  = '15 MINUTE'
  COMMENT   = 'Push Sentry findings to Splunk HEC every 15 min (Expires: 2026-10-30)'
AS
  CALL SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.PUSH_SENTRY_FINDINGS_TO_SPLUNK();

ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.PUSH_SENTRY_TO_SPLUNK RESUME;
```

---

## Alternative: Trust Center

Snowflake's built-in [Trust Center](https://docs.snowflake.com/en/user-guide/trust-center/overview) provides a managed version of security posture scanning without deploying Sentry. Trust Center runs scanner packages on a schedule and surfaces findings in the Snowflake UI via the `SNOWFLAKE.TRUST_CENTER.FINDINGS` view.

You can feed Trust Center findings into Splunk using the same External Access pattern above — replace the Sentry findings table with:

```sql
SELECT *
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS
WHERE CREATED_AT >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
  AND STATUS = 'OPEN'
```

Trust Center is lower-effort to set up than Sentry (no external repo clone required) but has fewer customization options. Use Trust Center for baseline posture management; Sentry for custom detection logic.

---

## Cost Profile

| Component | Notes |
|---|---|
| Sentry detection tasks | SQL tasks on XSMALL warehouse. Very low credit consumption — detections run fast. |
| Push task | XSMALL, every 15 min. < 0.1 credits/day. |
| Splunk ingest | Minimal — findings only, not raw logs. Typical busy org: < 10 MB/day of findings. |
| Snowflake egress | Negligible — finding payloads are tiny JSON objects. |

---

## What to Watch For

- **Sentry schema changes:** Sentry is an open-source project; table and column names may change between versions. Pin to a specific Sentry commit/release when deploying in production.
- **`PUSHED_TO_SPLUNK` column:** The sample procedure assumes you add this column to Sentry's findings table. If the Sentry schema does not include it, maintain a separate tracking table.
- **HEC token rotation:** When you rotate the Splunk HEC token, update the Snowflake secret immediately. The push task will fail silently if the token is invalid unless you add error alerting.
- **External Access Integration requires ACCOUNTADMIN** to create. Plan for this in change management.

---

[Back to README](README.md) | [Previous: External Stage](pattern-3-external-stage.md)
