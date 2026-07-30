> Simplified from: [Snowflake Logs → Splunk: Integration Guide](README.md)

# ELI5: Getting Snowflake Logs into Splunk

## One-Sentence Version

Snowflake stores its own activity records as database tables — not log files — so there are four different ways to get that information into Splunk, ranging from "just look at it from Splunk" to "run the alarms in Snowflake and only tell Splunk when something is wrong."

---

## The Story

Imagine a library where every book checkout, every staff login, every time someone looked in the catalog — all of it is recorded in the library's own internal database, not in a paper logbook. Your security team uses a different system (Splunk) to watch for suspicious activity. The question is: how do you get the library's records over to the security system?

You have four options. You could give the security system a window into the library's database so it can look things up on demand — that's Federated Search. You could hire a courier to regularly copy records from the library's database and deliver them to the security system — that's DB Connect. You could have the library drop copies of the records into a shared mailbox (cloud storage) that the security system checks periodically — that's the External Stage approach. Or you could have the library's own staff watch for suspicious patterns, and only call the security system when they actually spot something — that's Sentry.

Each option costs different amounts, works with different versions of Splunk, and gives you different levels of detail. The guide walks through all four and helps you pick.

---

## The Cast

| Concept | Plain words |
|---|---|
| **ACCOUNT_USAGE** | The library's internal records database. Every login, every query, every privilege change is in here. Free to query. But it's always 45 minutes to 3 hours behind real time. |
| **Splunk** | The security team's monitoring system. Indexes logs and lets analysts search them. Charges by how much data you send to it. |
| **DB Connect** | A Splunk plugin that reads from external databases via a direct connection. The most common way to pull Snowflake records into Splunk today. |
| **Rising Column** | A bookmark. DB Connect remembers the last record it fetched and only asks for newer ones on the next check. Without it, you'd re-import everything every time. |
| **Federated Search** | Splunk querying Snowflake directly — no copying. The data never leaves Snowflake. Only works on Splunk Cloud running on AWS (as of July 2026). |
| **HEC** | Splunk's "drop-box" — an endpoint you send events to via HTTP. Push something here and it shows up in Splunk. |
| **Sentry** | Snowflake's open-source toolkit of pre-written security alarm queries. You deploy it inside Snowflake; it watches the logs and raises alerts without sending all the raw data out. |
| **PAT** | A password-equivalent for automated systems. Because some tools (like DB Connect) can't use Snowflake's more modern key-based auth, you generate a PAT and use it as a password. |

---

## What Changed

- Splunk Federated Search for Snowflake became generally available in **July 2026** — before that, DB Connect or manual export were the only options for live Snowflake→Splunk integration
- Snowflake now supports Programmatic Access Tokens (PATs) as a clean service-account credential for tools that need username/password auth
- Sentry has grown into a maintained framework with MITRE ATT&CK mappings, making the "detect-in-Snowflake, push-findings-only" architecture easier to implement
- The strategic direction is toward query-in-place (Federated Search) and detect-in-place (Sentry) — less raw log movement, lower SIEM costs

---

## What to Watch Out For

- **Latency is baked in.** All four patterns are limited by ACCOUNT_USAGE's 45-minute to 3-hour lag. If you need to catch a breach in real time (under a minute), none of these patterns achieves that with ACCOUNT_USAGE data.
- **Federated Search is AWS Cloud only right now.** If your team runs Splunk Enterprise on-prem or on Azure/GCP, you cannot use Pattern 1 yet.
- **Sending everything to Splunk gets expensive fast.** ACCESS_HISTORY and QUERY_HISTORY can generate gigabytes per day at a busy org. The guide recommends starting with just LOGIN_HISTORY and only adding more if you have a specific reason.
- **DB Connect has a known timestamp checkpoint bug** with certain Snowflake views. The guide covers the workaround (cast timestamps to TIMESTAMP_NTZ), but it trips up people who follow older tutorials.
- **Sentry is an open-source project** — it's not an official Snowflake product. Table names and schemas can change between versions. If you deploy it in production, pin to a specific version.

---

## The One Thing to Remember

Snowflake's logs are already in a database — start with the cheapest, simplest path for your Splunk edition, not the most complete one, because the most complete one can become the most expensive one very quickly.

---

> For the full technical details, see the [source guide](README.md).
