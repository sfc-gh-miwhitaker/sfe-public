![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2027--02--05-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Snowflake Firewall Allowlisting for Network Administrators

A plain-language guide for the network/firewall admin who has been handed a ticket that says "allow Snowflake traffic" and has never touched Snowflake. Covers both directions of traffic, explains why there is no static IP list for inbound connections, and provides the exact queries and automation patterns needed to keep firewall rules current.

**Audience:** Network administrators, firewall engineers, security operations teams — anyone maintaining edge firewall rules who needs to permit Snowflake traffic without a Snowflake background.

```
Pair-programmed by SE Community + Cortex Code
```

**Created:** 2026-08-05 | **Expires:** 2027-02-05 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

You got a ticket. Someone on the data team needs "Snowflake access." Before you reach for a static IP list — stop. Snowflake's architecture means the answer depends on **which direction** the traffic flows.

| Direction | What's happening | How to allowlist | Static IPs? |
|-----------|-----------------|-----------------|-------------|
| **Outbound** (your network → Snowflake) | Users/apps connecting to Snowflake | Allowlist by **DNS hostname** (FQDN) + port | No — IPs are dynamic |
| **Inbound** (Snowflake → your network) | Snowflake calling your APIs/services | Allowlist by **CIDR block** from a Snowflake function | Yes — stable, but they expire |

If you only need one direction, jump to that section. If you need both, read straight through.

---

## Section 1: Outbound — Your Network to Snowflake

### The Problem

Your users (or ETL servers) need to reach Snowflake's service endpoints. Your firewall blocks everything by default. You need to know what to allow.

### Why There Are No Static IPs

Snowflake runs on shared cloud infrastructure (AWS, Azure, GCP). The IP addresses behind Snowflake's hostnames are managed by the cloud provider's load balancers and change without notice. Snowflake does not publish a static IP list for inbound connections — it cannot, because it does not control the underlying cloud IPs.

### What You Allowlist Instead: DNS Hostnames

Snowflake provides a function that returns every hostname and port your account needs. Ask your Snowflake admin to run this:

```sql
-- Returns all hostnames + ports needed for this account
SELECT
    t.VALUE:type::VARCHAR  AS type,
    t.VALUE:host::VARCHAR  AS host,
    t.VALUE:port::INTEGER  AS port
FROM TABLE(FLATTEN(input => PARSE_JSON(SYSTEM$ALLOWLIST()))) AS t
ORDER BY type, host;
```

For accounts using **AWS PrivateLink / Azure Private Link / GCP Private Service Connect**:

```sql
SELECT
    t.VALUE:type::VARCHAR  AS type,
    t.VALUE:host::VARCHAR  AS host,
    t.VALUE:port::INTEGER  AS port
FROM TABLE(FLATTEN(input => PARSE_JSON(SYSTEM$ALLOWLIST_PRIVATELINK()))) AS t
ORDER BY type, host;
```

### What the Output Looks Like (representative sample)

| Type | Example Host | Port | Why |
|------|------|------|-----|
| SNOWFLAKE_DEPLOYMENT | `<acct-locator>.<region>.snowflakecomputing.com` | 443 | Main service endpoint |
| SNOWFLAKE_DEPLOYMENT_REGIONLESS | `<org>-<acct>.snowflakecomputing.com` | 443 | Org-level URL |
| SNOWSIGHT_DEPLOYMENT | `app.snowflake.com` | 443 | Web UI (Snowsight) |
| STAGE | `sfc-*-customer-stage.s3.<region>.amazonaws.com` | 443 | File staging (S3/Blob/GCS) |
| SNOWSQL_REPO | `sfc-repo.snowflakecomputing.com` | 443 | SnowSQL auto-update |
| OCSP_CACHE | `ocsp.snowflakecomputing.com` | **80** | Certificate validation cache |
| OCSP_RESPONDER | `ocsp.r2m01.amazontrust.com` | **80** | Certificate validation |
| CRL_DISTRIBUTION_POINT | `crl.r2m04.amazontrust.com` | **80** | Certificate revocation list |
| DUO_SECURITY | `api-*.duosecurity.com` | 443 | MFA push (if enabled) |
| OUT_OF_BAND_TELEMETRY | (see query output — account-specific telemetry endpoint) | 443 | Driver telemetry |
| SPCS_REGISTRY_REGIONLESS | `<org>-<acct>.registry.snowflakecomputing.com` | 443 | Container image registry |
| SNOWPARK_CONNECT | `<acct-locator>.snowpark.<region>.snowflakecomputing.com` | 443 | Snowpark Connect |
| APP_SERVICE_PUBLIC_WILDCARD | `*.<org>-<acct>.<region>.aws.snowflake.app` | 443 | Snowflake Apps (wildcard) |

> **Note:** Your account may show 20-35 entries depending on which features are enabled. The types above are the most common. Run the query — it is authoritative for your account.

### Firewall Configuration Strategy

**If your firewall supports FQDN-based rules** (Palo Alto, Fortinet, Zscaler, etc.):
1. Create an FQDN object for each hostname from the query above.
2. Allow HTTPS (TCP 443) and HTTP (TCP 80 for OCSP only) outbound to those FQDNs.
3. Re-run `SYSTEM$ALLOWLIST()` quarterly — new types can appear (e.g., when Snowflake Apps are enabled).

**If your firewall only supports IP-based rules** (legacy ACLs):
1. Resolve each hostname to its current IP(s) via DNS.
2. Add those IPs to your outbound allow rule.
3. **Critical:** Schedule automated DNS re-resolution (daily minimum). The IPs **will** change. If you hardcode them, access will break silently.
4. Consider upgrading to an FQDN-capable firewall or using a forward proxy.

### The PrivateLink Escape Hatch

If your security posture cannot tolerate dynamic IPs on the public internet, **AWS PrivateLink / Azure Private Link / GCP Private Service Connect** eliminates the problem entirely:

- Traffic stays on the cloud provider's private backbone.
- You use private IPs from your own VPC/VNet.
- No public internet exposure, no dynamic IPs to track.
- Your Snowflake admin provisions this; once active, `SYSTEM$ALLOWLIST_PRIVATELINK()` returns the private endpoints.

This is the "correct" long-term answer for organizations with strict network perimeters.

---

## Section 2: Inbound — Snowflake to Your Network

### The Problem

Your team has built UDFs, stored procedures, or Snowpark Container Services that call out to your internal APIs. Snowflake needs to reach your endpoint. Your firewall needs to know which source IPs to allow inbound.

### Good News: Stable Egress IPs (GA on AWS)

Snowflake provides **stable egress IP CIDR ranges** that you can add to your firewall's inbound allow rules. These are actual IP ranges that will carry Snowflake's outbound traffic.

Ask your Snowflake admin to run:

```sql
SELECT
    value:"ipv4_prefix"::VARCHAR   AS ip_cidr_range,
    value:"effective"::TIMESTAMP   AS effective_date,
    value:"expires"::TIMESTAMP     AS expiration_date
FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES())));
```

### What the Output Looks Like

| IP CIDR Range | Effective | Expires |
|---------------|-----------|---------|
| 153.45.34.0/24 | 2025-08-01 | 2026-05-06 |
| 153.45.77.0/24 | 2025-08-01 | 2026-05-06 |

### Supported Use Cases

These egress IPs are used when Snowflake calls out via:
- External access from UDFs and stored procedures (External Network Access)
- Snowpark Container Services (SPCS) external access
- Snowflake Openflow on SPCS
- Snowflake Git integration with IP-restricted Git servers

### Deployment Availability

- **AWS Commercial:** GA (Generally Available)
- **Azure / GCP:** Check with your Snowflake account team for current status

### Critical: These IPs Expire

Unlike a static firewall rule you set and forget, Snowflake's egress IP ranges have explicit expiration dates. When a range expires, it stops carrying traffic. New ranges appear in the function output at least **60 days before** becoming effective.

**You must automate the refresh.** Options:

1. **Snowflake Task + External Function:** Schedule a daily task that calls `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()`, compares with the current firewall rules, and pushes updates via your firewall's API.

2. **External script (Python/Bash):** A cron job that queries Snowflake, diffs the results, and updates your firewall via CLI/API (Terraform, AWS CLI, Azure CLI, Palo Alto API, etc.).

3. **IaC integration (Terraform/Ansible):** Define firewall rules as code. A pipeline periodically refreshes the IP list from Snowflake and applies changes idempotently.

### Automation Skeleton (Python)

```python
import snowflake.connector
import json

# Connect to Snowflake (service account with minimal privileges)
conn = snowflake.connector.connect(
    account='<org>-<account>',
    user='SVC_FIREWALL_AUTOMATION',
    private_key_file='/path/to/rsa_key.p8',
    warehouse='UTIL_XS'
)

# Retrieve current egress ranges
cursor = conn.cursor()
cursor.execute("SELECT SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()")
raw = cursor.fetchone()[0]
ranges = json.loads(raw)

# Extract active + upcoming CIDRs
cidrs = [r['ipv4_prefix'] for r in ranges]

# Compare with current firewall rules (your implementation)
# current_rules = get_current_firewall_rules()
# if set(cidrs) != set(current_rules):
#     update_firewall(cidrs)
#     log_change(old=current_rules, new=cidrs)

conn.close()
```

---

## Section 3: Decision Matrix

Use this table to answer "what do I need to do?" based on your scenario:

| Scenario | Action | Static? | Refresh needed? |
|----------|--------|---------|-----------------|
| Users connect to Snowflake from corporate network | Allowlist FQDNs from `SYSTEM$ALLOWLIST()` outbound | No | Quarterly check |
| ETL server connects to Snowflake | Same as above, or use PrivateLink | No | Quarterly check |
| Snowflake UDF calls your REST API | Add CIDRs from `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()` inbound | Yes (temporary) | Automated, before expiry |
| Snowflake loads from your S3 bucket | Use S3 VPC endpoint policy (not IP-based) | N/A | N/A |
| You want zero public internet exposure | Implement PrivateLink end-to-end | Private IPs | One-time setup |

---

## Section 4: FAQ for the Network Admin

**Q: Can you just give me a list of IPs to allow?**
A: For outbound (you → Snowflake): No. The IPs are dynamic and cloud-managed. You must use DNS hostnames or PrivateLink. For inbound (Snowflake → you): Yes, but they expire. Use `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()`.

**Q: What ports do I need open?**
A: TCP 443 (HTTPS) for almost everything. TCP 80 for OCSP certificate validation only. No UDP. No exotic ports.

**Q: What if my firewall doesn't support FQDN rules?**
A: You have three options: (1) resolve DNS daily and update IP rules via automation, (2) use a forward proxy that handles FQDN filtering, or (3) deploy PrivateLink to eliminate the problem.

**Q: How often do the hostnames change?**
A: The hostnames from `SYSTEM$ALLOWLIST()` are stable — they're tied to your account. What changes are the IPs behind them. New hostnames can appear when new Snowflake features are activated (like Snowflake Apps or Client Redirect).

**Q: Do I need to allow `*.snowflakecomputing.com`?**
A: No. Use the specific hostnames from `SYSTEM$ALLOWLIST()`. A wildcard is unnecessarily broad.

**Q: What about SnowCD?**
A: SnowCD is a diagnostic tool that tests connectivity to every endpoint in `SYSTEM$ALLOWLIST()`. If SnowCD passes, your firewall rules are correct. Give this to your Snowflake admin as a validation tool.

**Q: The `SYSTEM$WHITELIST()` function — is that the same thing?**
A: Yes, it's the old name. `SYSTEM$WHITELIST()` is deprecated. Use `SYSTEM$ALLOWLIST()` instead. Same output, modern naming.

**Q: What's the minimal set I need for basic Snowflake access?**
A: At minimum: the `SNOWFLAKE_DEPLOYMENT` host (TCP 443) and the `OCSP_CACHE` host (TCP 80). But the full list from `SYSTEM$ALLOWLIST()` ensures all features work — SnowSQL updates, file staging, Snowsight UI, MFA, etc.

---

## Section 5: Validation

After applying firewall rules, validate with SnowCD (Snowflake Connectivity Diagnostic):

```bash
# Download SnowCD from https://docs.snowflake.com/en/user-guide/snowcd
# Save allowlist output to a file, then test:
snowcd allowlist.json
```

SnowCD tests connectivity to every endpoint and reports pass/fail per host. Hand this tool to your Snowflake admin — they can generate the allowlist JSON and you can validate from the network.

---

## Related Guides

- [SYSTEM$ALLOWLIST Reference](https://docs.snowflake.com/en/sql-reference/functions/system_allowlist) — Full function reference
- [SYSTEM$ALLOWLIST_PRIVATELINK Reference](https://docs.snowflake.com/en/sql-reference/functions/system_allowlist_privatelink) — PrivateLink variant
- [SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES Reference](https://docs.snowflake.com/en/sql-reference/functions/system_get_snowflake_egress_ip_ranges) — Egress IP function
- [Allowing Host Names](https://docs.snowflake.com/en/user-guide/hostname-allowlist) — Per-client breakdown
- [Securing Ingress with Egress IPs](https://docs.snowflake.com/en/user-guide/egress-ip/network-egress) — Automation patterns
- [SnowCD Diagnostic Tool](https://docs.snowflake.com/en/user-guide/snowcd) — Connectivity validation
- [Network Policies](https://docs.snowflake.com/en/user-guide/network-policies) — Snowflake-side IP restrictions (the inverse problem)
- [Private Connectivity Overview](https://docs.snowflake.com/en/user-guide/admin-security-privatelink) — PrivateLink setup

---

## External References

- [Snowflake Community: How to manage Snowflake IP addresses for network security (AWS)](https://community.snowflake.com/s/article/Why-Snowflake-doesn-t-share-static-IP-address-with-customer)
- [Snowflake Community: Why Snowflake doesn't share static IP address range (Azure)](https://community.snowflake.com/s/article/Why-Snowflake-doesn-t-share-static-IP-address-range-with-the-customer-Azure)
