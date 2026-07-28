# Universal Data Sharing — ELI5

**One sentence:** Snowflake made it so you can share data with anyone, even people who don't use Snowflake, while keeping full control over who sees what.

---

## The Old Problem (in plain English)

Imagine your company uses Snowflake for all its data. You want to share sales numbers with a partner company — but they use Databricks, or Spark, or some other tool. Before 2026, your options were:

1. **Export CSVs** — but then the data is stale the moment you send it, and you lose all control over who sees what.
2. **Create a "reader account"** — Snowflake gave your partner a mini-Snowflake account just to read your data. But someone had to manage it, pay for it, and your partner was forced into an unfamiliar tool.

Neither was great. And the #1 pushback on Snowflake data sharing was always: "But our partners aren't on Snowflake."

---

## What Changed in 2026

### 1. Open Data Sharing — "Use whatever tool you want"

Your partner can now read your Snowflake data using their own tools (Spark, Trino, DuckDB — anything that speaks the Iceberg protocol). You give them a URL and a password (called a PAT). They connect. Done.

**Analogy:** It's like giving someone a link to a Google Doc — they don't need a Google account, they just click the link and read. Except here, your security rules still apply.

### 2. Open Table Format Sharing — "Any cloud, any format"

Your data can live as Iceberg or Delta Lake files in AWS, Azure, or GCP. Snowflake handles copying it to wherever your partner's Snowflake account is, automatically, without you managing pipelines.

**Analogy:** Like Netflix — the movie lives in one place, but it plays on any device without you worrying about format conversion.

### 3. Multi-Party Clean Rooms — "Everyone's equal now"

Previously, data clean rooms had one "provider" (who owns the data) and one "consumer" (who runs analysis). That's it — two parties only, rigid roles.

Now: Any number of companies can join the same clean room. Anyone can bring data. Anyone can run analysis. It's fully flexible.

**Analogy:** The old model was like one person hosting a dinner party. The new model is a potluck — everyone brings something, and the host just coordinates.

### 4. Universal Governance — "Rules follow the data"

Your security rules (who can see what, what gets masked) are now enforced even when non-Snowflake engines read your data. You set the rules once; they apply everywhere.

**Analogy:** Like airport security — no matter which airline you fly, the same security rules apply. You don't need separate security for each airline.

### 5. AI-Powered Sharing — "Ask questions, get answers"

Even non-technical partners can now interact with your shared data by asking questions in plain English. Snowflake automatically creates an AI agent that understands your data's structure and answers questions.

**Analogy:** Instead of giving someone a spreadsheet, you give them an expert assistant who has already read the spreadsheet and can answer any question about it.

---

## The Punchline

Before 2026: "Snowflake sharing only works if everyone's on Snowflake."

After 2026: Snowflake is the governed hub — your partners use whatever tools they already have, your security rules follow the data, and even non-technical people can access insights through AI agents.

---

## Status Check

| What | Ready to use? |
|---|---|
| Open Data Sharing (non-Snowflake partners) | Preview — works but expanding |
| Open Table Format Sharing (Iceberg/Delta) | Yes — fully available |
| Multi-party Clean Rooms | Yes — fully available |
| Security rules on external engines | Spark: yes. Others: coming soon |
| AI agents for shared data | Preview — works today |
