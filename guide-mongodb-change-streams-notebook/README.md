![Guide](https://img.shields.io/badge/Type-Guide-blue) ![No Deploy](https://img.shields.io/badge/Deploy-Notebook-lightgrey) ![Expires](https://img.shields.io/badge/Expires-2027--01--11-orange) ![Status](https://img.shields.io/badge/Status-ACTIVE-green)

# MongoDB Change Streams to Snowflake in One Notebook

A single Snowflake Notebook in Workspaces that moves MongoDB data into Snowflake without Kafka or
Openflow. It snapshots each collection once, then reads MongoDB change streams from a saved resume
token on every scheduled run, keeps a current-state table, generates typed column views, and reports
how far behind it is.

**Audience:** data engineers replacing a Kafka hop whose only job is carrying MongoDB change streams.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-12 | **Expires:** 2027-01-11 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

1. Run the one-time SQL in section 0 of the notebook from a worksheet (needs `CREATE INTEGRATION`).
2. Import [`mongodb_change_streams.ipynb`](mongodb_change_streams.ipynb) into Workspaces and attach
   `MONGODB_CDC_EAI` and the `MONGODB_URI` secret to the notebook service.
3. Edit the two registration cells in section 2 for your collections and columns.
4. Run all cells once, then schedule the notebook from the calendar icon with the same integration
   and secret attached.

## How It Works

| Step | Notebook section | Snowflake objects |
| --- | --- | --- |
| Objects | 1 | `COLLECTIONS`, `CHECKPOINTS`, `RAW_EVENTS`, `DOCUMENTS`, `COLUMN_MAP`, `RUN_LOG`, `RAW_EVENTS_STREAM` |
| Sync | 4 | `pymongo` `watch(resume_after=...)`, appends to `RAW_EVENTS`, saves the token in `CHECKPOINTS` |
| Current state | 5 | `MERGE` from the stream into `DOCUMENTS`, newest `clusterTime` wins |
| Columns | 6 | One view per collection generated from `COLUMN_MAP` |
| Lag | 7 | `SYNC_LAG` view |

## Requirements

- MongoDB replica set or sharded cluster (change streams are not available on a standalone server),
  reachable from Snowflake over the hosts listed in the network rule.
- A role with `CREATE INTEGRATION` for the one-time setup.
- Notebooks in Workspaces on Container Runtime. Scheduled runs use the scheduling user's default role.

## Design Notes

- **At-least-once delivery.** Events are written before the token is saved; replays are absorbed by the
  `MERGE` ordering on `(CLUSTER_TS, CLUSTER_INC)`.
- **Quiet collections keep their position fresh.** An empty poll still saves the stream's latest token.
- **Oplog rollover.** If the saved token is older than the oplog (MongoDB error 286), the collection is
  snapshotted again and documents missing from the new snapshot are marked deleted. Set
  `AUTO_RESNAPSHOT = False` to stop and flag it instead.
- **Cost.** Each run bills compute pool time for the notebook plus warehouse time for its SQL. Keep
  `RUN_SECONDS` short and match the schedule to how fresh the data needs to be.

## Related Guides

- [MongoDB change streams](https://www.mongodb.com/docs/manual/changeStreams/)
- [Using secrets in Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-in-workspaces/notebooks-in-workspaces-using-secrets)
- [Run and schedule Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-in-workspaces/notebooks-in-workspaces-schedule)

## External References

- [External network access overview](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)
- [Resume a change stream](https://www.mongodb.com/docs/manual/changeStreams/#resume-a-change-stream)
- [PyMongo `ChangeStream`](https://pymongo.readthedocs.io/en/stable/api/pymongo/change_stream.html)
