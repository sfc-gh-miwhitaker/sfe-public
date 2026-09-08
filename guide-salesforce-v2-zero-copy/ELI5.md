# Salesforce and Snowflake Zero Copy, in Plain Language

> Simplified from: `guide-salesforce-v2-zero-copy/README.md`

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Salesforce and Snowflake can read selected data from each other without copying it, but each direction needs its own setup.

## The Story

Imagine Salesforce and Snowflake are two libraries. Each library wants visitors
from the other library to read selected books without shipping duplicate shelves.

For Salesforce data read in Snowflake, Salesforce creates a reading list. Snowflake
creates a secure library card called a zero-copy connector.

For Snowflake data read in Salesforce, Salesforce creates a federation connection.
That is a separate door, even though Salesforce calls the whole arrangement bidirectional.

Openflow is different. It works like a delivery truck that copies Salesforce
records into Snowflake tables.

## The Cast

- **Data 360:** Salesforce's library and data-modeling system.
- **Data Share:** the approved list of Salesforce objects Snowflake can read.
- **Snowflake V2 target:** the Salesforce destination paired with Snowflake's Enrollment ID.
- **Zero-copy connector:** Snowflake's secure link to Salesforce Data Shares.
- **Catalog-linked database:** the Snowflake database containing views over shared Salesforce data.
- **Query Federation:** Salesforce asks Snowflake to run a query against Snowflake data.
- **File Federation:** Salesforce reads supported external files without using Snowflake warehouse compute.
- **Openflow:** a managed pipeline that copies Salesforce records into Snowflake tables.
- **Salesforce MCP:** agent tools for Salesforce, not a data-sharing pipeline.

## What Changed

- V2 replaces the old Salesforce-to-Snowflake sharing setup for new designs.
- V2 uses an Enrollment ID, a Snowflake V2 target, and a Snowflake zero-copy connector.
- Salesforce now lists its Snowflake connector as generally available and bidirectional.
- The two directions still require different configuration steps.
- Openflow remains useful when a native copy in Snowflake is required.

## What to Watch Out For

- One Snowflake setup page still says "pilot," so confirm V2 appears in the Salesforce org.
- Not every externally backed Salesforce object can be shared onward.
- Prove V2 works before removing a legacy target.
- Zero copy still depends on the source system and still uses compute somewhere.
- File Federation is labeled Beta in Salesforce's current overview.
- Public V2 docs do not yet define every Streams or Dynamic Tables behavior.
- Dropped zero-copy connectors and catalog-linked databases cannot be restored with `UNDROP`.

## The One Thing to Remember

Bidirectional zero copy means two connected doors, not one magical two-way pipe.

> For the full technical details, see the source document.
