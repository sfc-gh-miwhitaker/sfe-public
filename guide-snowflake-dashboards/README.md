![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--01--02-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Roll Out Snowflake Dashboards as an Administrator

Snowflake Dashboards are SQL-backed, multi-tile dashboards that analysts build in Snowsight Workspaces, often by asking Cortex Code, and then share as dashboard artifacts that business users open in Snowflake CoWork or Snowsight. This guide covers the administrator's side: the three independent controls that decide who can share, how caller's-rights execution shapes data access and cost, the lifecycle gaps to plan around, and what to do with dashboards from the retired Legacy Dashboards experience.

**Audience:** Snowflake account administrators enabling Dashboards for analysts and viewers.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-03 | **Last verified:** 2026-11-03 | **Expires:** 2027-01-02 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

Dashboards are an [Open Preview feature available to all accounts](https://docs.snowflake.com/en/user-guide/snowflake-dashboards). Out of the box, any user can share a dashboard they own. Decide whether that is what you want before analysts start publishing.

1. **Inspect the defaults.** Run the [inventory queries](#check-your-current-settings). Expect sharing on and all five `MANAGE ACCESS ON ... ARTIFACTS` privileges granted to `PUBLIC`.
2. **Decide who may share.** Either keep sharing open, or [restrict it to a publisher role](#restrict-sharing-to-a-publisher-role). Decide for every artifact type, not only dashboards.
3. **Prepare viewer access.** Viewers need a warehouse and `SELECT` on what tiles query. Point analysts at [governed views and semantic views](#design-data-access-for-viewers).
4. **Put guardrails on compute.** Every viewer runs their own queries. Give dashboards a [dedicated, bounded warehouse](#plan-for-per-viewer-compute).
5. **Set lifecycle rules.** Transfer artifact ownership to team roles and author in shared or Git-backed workspaces. See [lifecycle gaps](#lifecycle-and-governance-gaps).

Prefer plain language? Read [ELI5.md](ELI5.md).

## What an administrator needs to know

| Concept | What it means for you |
|---------|-----------------------|
| `.dash` file | The editable source, stored in a Snowsight workspace. Authoring and peer review happen here; no special privilege is needed to create one. |
| Dashboard artifact | A read-only, published copy of a `.dash` file. It is a [securable object](https://docs.snowflake.com/en/user-guide/snowflake-artifacts) with `OWNERSHIP`, `READ`, and `WRITE` privileges. Viewers open the artifact, never the file. |
| Caller's rights | Every tile query, filter dropdown, and CoWork follow-up runs with the **viewer's** privileges and warehouse compute. A viewer without access to the source tables sees no data. |
| Owner | Defaults to the creator's personal role. |
| Viewing surfaces | The share link opens in CoWork, where viewers can ask follow-up questions on tiles. The same artifact appears in Snowsight under **Projects > Artifacts**. Viewers cannot edit tiles in either. |

Compared with the retired Legacy Dashboards, the security model has flipped:

| | Legacy Dashboards | Dashboards |
|---|---|---|
| Query identity | Shared session context; filter values computed under the owner | Each viewer's own privileges |
| Access control | User-based sharing | Role-based (RBAC) artifact grants |
| Cache | Shared across users with the role | Per viewer; no cross-viewer cache |
| Filters | Account-global, `:filter_name` | Per dashboard, `{{ filter('name') }}` |

## The three sharing controls

Sharing a dashboard passes three independent gates, and the viewer's own data privileges then decide what they see.

| Gate | Scope | Default | Who changes it |
|------|-------|---------|----------------|
| `ENABLE_SNOWFLAKE_INTELLIGENCE_ARTIFACT_SHARING` account parameter (also **CoWork settings > Data controls > Sharing artifacts and chats**) | Whole account, all artifact types | `TRUE` | `ACCOUNTADMIN` |
| `MANAGE ACCESS ON <TYPE> ARTIFACTS ON ACCOUNT` | One artifact type: `CHART`, `DASHBOARD`, `FILE`, `REPORT`, `THREAD` | Granted to `PUBLIC` ([BCR-2462](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-manage-access-dashboard-artifacts), rolling out from late September 2026) | A role that can grant account privileges |
| `READ` / `WRITE` on the individual artifact | One artifact | Owner only | The owner, through the **Share** dialog |

Behavior worth knowing before you change anything:

- **Turning the account parameter off blocks access, not grants.** Non-owners lose access even with existing grants, and nobody can share. Existing grants come back to life if you turn it on again. It is not a substitute for revoking.
- **`MANAGE ACCESS` does not override the account parameter**, and it does not grant access to any artifact or to source data.
- **Revoking `MANAGE ACCESS` from `PUBLIC` does not remove existing artifact grants.** Dashboards already shared stay shared.
- **Restricting only dashboards leaves other doors open.** Report, File, and Thread artifacts are static snapshots. Their recipients read the saved content **without** needing access to the source data. Chart and Dashboard artifacts rerun queries as the viewer. If your concern is data leaving its governed audience, the snapshot types are the higher risk.

### Check your current settings

Run as `ACCOUNTADMIN`:

```sql
SHOW PARAMETERS LIKE 'ENABLE_SNOWFLAKE_INTELLIGENCE_ARTIFACT_SHARING' IN ACCOUNT;

SHOW GRANTS ON ACCOUNT;
SELECT "privilege", "grantee_name"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "privilege" ILIKE 'MANAGE ACCESS ON % ARTIFACTS'
ORDER BY "privilege", "grantee_name";
```

If the second query returns no rows, BCR-2462 has not reached your account yet. Sharing then follows the account parameter alone.

### Restrict sharing to a publisher role

This keeps authoring open while limiting who can publish dashboards to an audience. Grant to the new role **before** revoking from `PUBLIC`, so no one who should share is locked out mid-change.

```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS DASHBOARD_PUBLISHER
  COMMENT = 'Roles allowed to share dashboard artifacts';
GRANT ROLE DASHBOARD_PUBLISHER TO ROLE SYSADMIN;

GRANT MANAGE ACCESS ON DASHBOARD ARTIFACTS ON ACCOUNT TO ROLE DASHBOARD_PUBLISHER;
REVOKE MANAGE ACCESS ON DASHBOARD ARTIFACTS ON ACCOUNT FROM ROLE PUBLIC;
```

Grant `DASHBOARD_PUBLISHER` to the analysts' functional roles. Repeat the pair of statements for `REPORT`, `FILE`, `THREAD`, and `CHART` with whichever roles should share those types.

If sharing is currently turned **off** for the account, revoke from `PUBLIC` first and only then set the parameter to `TRUE`. Otherwise every user regains the ability to share the moment you turn it on.

To undo the restriction:

```sql
GRANT MANAGE ACCESS ON DASHBOARD ARTIFACTS ON ACCOUNT TO ROLE PUBLIC;
```

## Design data access for viewers

Because each viewer queries as themselves, a dashboard is only as useful as the viewer's grants:

- **Warehouse.** The viewer's role needs `USAGE` on a warehouse. A missing warehouse is the most common reason a shared dashboard shows nothing.
- **Source objects.** The viewer needs `SELECT` on every table or view that tile SQL references. Sharing the artifact grants none of this.
- **Prefer governed objects.** Ask analysts to build tiles on curated views or semantic views that viewer roles already read. Row access and masking policies then apply automatically, per viewer.
- **Expect different numbers for different people.** Two viewers with different row access see different totals and even different filter dropdown values. That is the design, but tell business users before they compare screenshots.
- **Chart actions need a common source.** Click-to-filter interactions only work between tiles that query the same table or view. One more reason to steer authors toward shared semantic views.

## Plan for per-viewer compute

There is no cross-viewer cache. Each viewer's tile queries run on their warehouse; only queries for the open tab run, and a viewer may get their own earlier snapshot of a tile instead of a rerun. A widely shared dashboard can therefore drive more compute than a Legacy Dashboard did.

Give viewer roles a dedicated, bounded warehouse rather than a shared ETL one:

```sql
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS DASHBOARD_VIEWER_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'Compute for dashboard viewers';

GRANT USAGE ON WAREHOUSE DASHBOARD_VIEWER_WH TO ROLE <viewer_role>;
```

Replace `<viewer_role>` with each business role. Then attach a resource monitor or budget to the warehouse so its spend is visible and capped. If many viewers open the same dashboard at once, a multi-cluster setting fits better than a larger size.

## Lifecycle and governance gaps

Plan around these preview behaviors:

- **Ownership sits with a person by default.** Transfer each production artifact to a team role in its **Share** dialog; existing grants stay active. SQL transfer (`GRANT OWNERSHIP ON ARTIFACT`) is documented as upcoming, not available.
- **No SQL inventory yet.** `SHOW ARTIFACTS`, `DESCRIBE ARTIFACT`, and `SYSTEM$SHOW_ARTIFACT_GRANTS` are documented but not yet available, and artifact grants do not appear in `SHOW GRANTS`. Until they arrive, the owner's **Share** dialog is the only place to see who has access.
- **Deletion is permanent.** Dropping an artifact requires `OWNERSHIP`, and `UNDROP` cannot restore it, even for administrators.
- **Source file moves break linkage.** Renaming or deleting a `.dash` file leaves the artifact pointing at a stale path. Moving it to another folder or workspace can detach it, so the next publish creates a new artifact with a new link. Agree on a stable location before publishing.
- **Review before publish.** Keep production `.dash` files in a shared or Git-backed workspace so changes are reviewed before someone with `WRITE` publishes them.

## Legacy Dashboards and BI migration

The full Legacy Dashboards experience has been [removed from Snowsight](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2260). The Dashboards list remains, with download, Streamlit conversion, an admin usage view, and an **Upgrade to v2** action that converts a Legacy Dashboard into a `.dash` file in the user's personal workspace.

What changes on upgrade:

- Tiles, SQL, chart configuration, filters, and layout carry over; a few tiles may land as Markdown with the original query for manual repair.
- Account-global filters become per-dashboard filters, and `:filter_name` becomes `{{ filter('name') }}`.
- Users the Legacy Dashboard was shared with get access to the upgraded dashboard.
- **Viewers now see only what their own roles allow.** If a Legacy Dashboard relied on its owner's role, some viewers will see less or nothing. Grant them access to the data, not a broader role.

Use the admin usage view, filtered to runs in the last 30 days, to choose which dashboards are worth upgrading.

For Tableau (`.twb`, `.twbx`) and Power BI (`.pbix`, `.pbit`) dashboards, analysts can give the exported file to Cortex Code in Workspaces, which rebuilds the tiles. This only works when the data is already in Snowflake. Check every migrated tile against the source before sharing.

## Preview limitations

- Shared artifacts are view-only; editing happens in Workspaces.
- Dashboard artifacts are created and updated from Workspaces. Cortex Code can author `.dash` files but cannot publish dashboard artifacts.
- Per-viewer compute with no shared cache.
- Chart actions require tiles on the same table or view; geospatial chart types are not supported.

## Related Guides

- [Snowflake Dashboards](https://docs.snowflake.com/en/user-guide/snowflake-dashboards)
- [Snowflake Artifacts](https://docs.snowflake.com/en/user-guide/snowflake-artifacts)
- [Create and share a dashboard or HTML report](https://docs.snowflake.com/en/user-guide/snowflake-artifacts-create-share)

## External References

- [BCR-2462: MANAGE ACCESS privileges on artifacts granted to PUBLIC](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-manage-access-dashboard-artifacts)
- [BCR-2260: Deprecation of Legacy Worksheets and Dashboards](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2260)
- [GRANT privileges to a role](https://docs.snowflake.com/en/sql-reference/sql/grant-privilege)
- [REVOKE privileges from a role](https://docs.snowflake.com/en/sql-reference/sql/revoke-privilege)
- [Working with resource monitors](https://docs.snowflake.com/en/user-guide/resource-monitors)
- [Overview of Snowflake CoCo](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
