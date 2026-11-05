![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--01--04-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Automatically Find, Tag, and Mask PII in Snowflake

A first-week guide for a new Snowflake administrator: use only native platform features to find personal data in your tables, label every sensitive column with Snowflake's classification tags and your own sensitivity tag, and mask those columns automatically, including in tables that do not exist yet. Every step shows the Trust Center click path and the equivalent SQL side by side.

**Audience:** Snowflake administrators and data governance owners who are new to the platform.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-05 | **Last verified:** 2026-11-05 | **Expires:** 2027-01-04 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

1. Open Snowsight, create a SQL worksheet, paste [`sql/walkthrough.sql`](sql/walkthrough.sql), and select **Run All**. It takes about two minutes and needs no edits.
2. Read the last two result grids. The first lists the tags Snowflake set on each column. The second is the same table queried as an analyst, with every tagged column masked.
3. Open **Governance & security » Trust Center » Data Security** to see the same results in the UI.
4. When you are done, run [`sql/teardown.sql`](sql/teardown.sql).

The walkthrough uses 200 rows of invented customers (example.com emails, 555 phone numbers). It never touches your real data.

Prefer plain language? Read [ELI5.md](ELI5.md).

## How it fits together

```text
Classification profile ──set on──> database or schema
        │                                  │
        │                    Snowflake samples each table on a schedule
        ▼                                  ▼
  rules: auto_tag, tag map,      column found to hold NAME, EMAIL, ...
  custom classifiers, exclusions           │
                                           ▼
             SNOWFLAKE.CORE.SEMANTIC_CATEGORY = 'EMAIL'   (system tag)
             SNOWFLAKE.CORE.PRIVACY_CATEGORY  = 'IDENTIFIER'
             YOUR_DB.SCH.PII_SENSITIVITY      = 'CONFIDENTIAL' (your tag, via tag map)
                                           │
                                           ▼
             masking policy attached to YOUR tag masks the column at query time
```

Three ideas carry the whole guide:

- **Semantic category** is the type of data (NAME, EMAIL, PHONE_NUMBER, STREET_ADDRESS, NATIONAL_IDENTIFIER, and [about 50 more](https://docs.snowflake.com/en/user-guide/classify-native)). **Privacy category** is how identifying it is: IDENTIFIER, QUASI_IDENTIFIER, or SENSITIVE.
- A **classification profile** is the rule book. Setting it on a database or schema is the "on" switch.
- **Tag-based masking** is what turns detection into protection. You attach a masking policy to a tag once; every column that later receives the tag is masked with no further work.

## Before You Start

- **Edition.** Sensitive data classification requires Enterprise Edition or higher.
- **Cost.** Classification runs on serverless compute and is billed as `SENSITIVE_DATA_CLASSIFICATION`. Views cost more to classify than tables and are excluded by default. See [Cost](#cost).
- **Do not run day to day as ACCOUNTADMIN.** Create one governance role and grant it exactly what classification needs. The walkthrough does this for you:

| Need | Grant |
| --- | --- |
| Create profiles and custom classifiers | `GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE <role>` |
| Create a profile in a schema you do not own | `GRANT CREATE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE ON SCHEMA <schema> TO ROLE <role>` |
| Turn classification on for a database or schema | `EXECUTE AUTO CLASSIFICATION` on the account, database, or schema (owners have it by default) |
| Set system and mapped tags on columns | `GRANT APPLY TAG ON ACCOUNT TO ROLE <role>` |
| Attach masking policies to tags | `GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE <role>` |
| Use the Trust Center for setup and review | `GRANT APPLICATION ROLE SNOWFLAKE.TRUST_CENTER_ADMIN TO ROLE <role>` (`TRUST_CENTER_VIEWER` to review only) |
| Query `DATA_CLASSIFICATION_LATEST` and `TAG_REFERENCES` | `GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE <role>` |

- **Keep governance objects in their own schema.** Tags, masking policies, classifiers, and profiles belong together in a schema the governance role owns, separate from the data being classified.

## Step 1: Test one table first

Before you automate anything, see what Snowflake finds in a table you know.

| Trust Center | SQL |
| --- | --- |
| Not available as a one-table test in the UI. Use SQL for this step, or skip to Step 2 and review results there. | `CALL SYSTEM$CLASSIFY('my_db.my_schema.customers', NULL);` |

With `NULL` as the second argument, `SYSTEM$CLASSIFY` returns its findings and applies no tags. For each column the JSON result shows:

- `semantic_category` and `privacy_category`: what Snowflake thinks the column is.
- `confidence`: HIGH, MEDIUM, or LOW.
- `details`: country-specific subcategories, such as `US_STREET_ADDRESS`.
- `alternates`: other categories it considered.

Columns with no recommendation are not sensitive as far as Snowflake can tell. Classification samples up to 10,000 rows, so a column that is mostly empty may not be detected.

## Step 2: Create a classification profile

| Trust Center | SQL |
| --- | --- |
| **Trust Center » Data Security**. The first user sees **Get started**: pick databases, choose whether to auto-apply tags, select **Enable**. For full control use **Settings » Create New** (Steps 3 to 5 below are pages in that same wizard). | `CREATE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE governance_db.sch.pii_profile({'auto_tag': true, 'classify_views': false});` |

The settings that matter on day one:

| Key | What it does | Recommendation |
| --- | --- | --- |
| `auto_tag` | `true` sets the tags automatically. `false` only recommends them; you then accept or change each one in **Trust Center » Dashboard » Objects that need review**. | Start with `false` on a production database you do not know yet, switch to `true` once results look right. |
| Scheduling | **Autopilot** (Open Preview) is the default: Snowflake decides when new tables are classified and reclassifies on a 30-day cadence. Setting `minimum_object_age_for_classification_days` or `maximum_classification_validity_days` switches to `'scheduling_mode': 'CUSTOM'`. | Keep Autopilot unless you have a reason to control timing. |
| `classify_views` | Also classify views. | Leave `false` at first; views cost more. |
| `snowflake_semantic_categories` | Classify only the listed categories, optionally limited by country (`'country_codes': ['US']`). | Use when you need, for example, only GDPR-relevant categories. |
| `ai_mode` | Open Preview. Uses an LLM to find additional categories. Adds token charges on top of classification compute. | Try it on a test schema before enabling broadly. |

Check what you created with `SELECT governance_db.sch.pii_profile!DESCRIBE();`.

## Step 3: Map findings to your own sensitivity tag

Snowflake's system tags say *what* the data is. Your company probably has its own vocabulary for *how sensitive* it is. A **tag map** sets your tag automatically whenever a semantic category is found.

| Trust Center | SQL |
| --- | --- |
| In the profile wizard, on the tag page: under **Tag to apply** choose your tag and value (for example `PII_SENSITIVITY = CONFIDENTIAL`), under **Detected semantic categories** choose the categories that should get it. | Create the tag, then call `SET_TAG_MAP` (below). |

```sql
CREATE TAG governance_db.sch.pii_sensitivity
    ALLOWED_VALUES 'HIGHLY_CONFIDENTIAL', 'CONFIDENTIAL';

CALL governance_db.sch.pii_profile!SET_TAG_MAP({
  'column_tag_map': [
    { 'tag_name': 'governance_db.sch.pii_sensitivity',
      'tag_value': 'HIGHLY_CONFIDENTIAL',
      'semantic_categories': ['NAME', 'NATIONAL_IDENTIFIER'] },
    { 'tag_name': 'governance_db.sch.pii_sensitivity',
      'tag_value': 'CONFIDENTIAL',
      'semantic_categories': ['EMAIL', 'PHONE_NUMBER', 'STREET_ADDRESS'] }
  ]});
```

- **Order matters.** If a column matches more than one entry, the first entry wins. Put your most restrictive value first.
- **Shortcut:** an entry with only `tag_name` copies the semantic category value into your tag for every classified column.
- **Manual tags win and raise an error.** If someone already set your tag on a column by hand, classification does not overwrite it and logs a `MANUALLY_APPLIED_VALUE_PRESENT` tagging error instead. See [Troubleshooting](#troubleshooting).

## Step 4: Teach Snowflake an identifier it does not know

Native categories cover common personal data. Internal identifiers (employee numbers, member IDs, account codes) need a **custom classifier**: a regular expression plus the categories to assign when it matches.

| Trust Center | SQL |
| --- | --- |
| Create the classifier with SQL, then select it on the custom categories page of the profile wizard. | `CREATE` the classifier, `ADD_REGEX`, then `SET_CUSTOM_CLASSIFIERS` on the profile (below). |

```sql
-- 1. Prove the pattern against real values first.
SELECT COUNT(*) FROM my_db.my_schema.customers
WHERE employee_id REGEXP '^EMP-[0-9]{6}$';

-- 2. Create the classifier in your governance schema.
USE SCHEMA governance_db.sch;
CREATE SNOWFLAKE.DATA_PRIVACY.CUSTOM_CLASSIFIER employee_ids();

CALL employee_ids!ADD_REGEX(
    SEMANTIC_CATEGORY => 'EMPLOYEE_ID',
    PRIVACY_CATEGORY  => 'IDENTIFIER',
    VALUE_REGEX       => '^EMP-[0-9]{6}$',
    COL_NAME_REGEX    => '.*EMP.*ID.*',   -- optional
    THRESHOLD         => 0.8);            -- share of values that must match

-- 3. Add it to the profile, and to the tag map if it should get your tag.
CALL pii_profile!SET_CUSTOM_CLASSIFIERS({'employee_ids': employee_ids!LIST()});
```

Regex matching for classification is case-insensitive. `employee_ids!LIST()` shows what a classifier contains. An invalid regex, missing category, or out-of-range threshold makes classification fail for the table, so test the pattern first.

## Step 5: Test the profile, then turn it on

Run the profile against one table before attaching it. When the profile has `auto_tag: true`, this call **does set the tags**, so use a table where that is acceptable.

```sql
CALL SYSTEM$CLASSIFY('my_db.my_schema.customers', 'governance_db.sch.pii_profile');
```

Each column's `tags` array shows `"tag_applied": true` and the exact tags and values. When the result looks right, turn on automatic classification:

| Trust Center | SQL |
| --- | --- |
| Selecting databases on the first page of the profile wizard and choosing **Enable** turns it on. To add databases later: **Settings**, find the profile, **» Edit**, select them. | `ALTER DATABASE my_db SET CLASSIFICATION_PROFILE = 'governance_db.sch.pii_profile';` |

- A profile can also be set on a **schema**. A schema-level profile overrides the database-level one; the Trust Center then shows the database as *partially monitored*. The walkthrough uses a schema so it does not classify other objects in the shared database.
- Scheduled classification starts about **one hour** after you set the profile.
- List what is being monitored: `SELECT SYSTEM$SHOW_SENSITIVE_DATA_MONITORED_ENTITIES('DATABASE');` (or `'SCHEMA'`).
- Turn it off: `ALTER DATABASE my_db UNSET CLASSIFICATION_PROFILE;`

## Step 6: Mask everything that gets tagged

Attach a masking policy to **your** tag, once. Every column that classification tags from now on is masked automatically.

| Trust Center | SQL |
| --- | --- |
| The Dashboard's **Sensitive data masking status** tile shows which sensitive tables are fully, partially, or not masked. Create and attach the policy with SQL. | Create the policy, then `ALTER TAG ... SET MASKING POLICY` (below). |

```sql
CREATE MASKING POLICY governance_db.sch.mask_pii_string
  AS (val STRING) RETURNS STRING ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_CLASSIFICATION_ADMIN') THEN val
       ELSE '***MASKED***' END;

ALTER TAG governance_db.sch.pii_sensitivity
  SET MASKING POLICY governance_db.sch.mask_pii_string;
```

- A tag can hold **one masking policy per data type**. A string policy does not mask a NUMBER or DATE column that receives the same tag; add a policy for each data type you expect.
- Decide who sees real values by role, not by user. `IS_ROLE_IN_SESSION` honors role hierarchy and secondary roles.
- If a column ends up with more than one masking policy through its tags (for example, two mapped tags that each carry a STRING policy), queries on it fail and classification of that table fails with `mapped to multiple masking policies`. A policy set directly on a column takes precedence over a tag-based one, so that combination does not conflict.
- You cannot attach a masking policy to the `SNOWFLAKE.CORE` system tags. That is why Step 3 maps findings onto a tag you own.

## Step 7: Review the results

| Trust Center | SQL |
| --- | --- |
| **Data Security » Dashboard**: objects by compliance category (PII, GDPR, HIPAA, PCI, and others), objects by semantic category, databases monitored, classification status, masking status, and errors. **Sensitive objects** lists every classified table; select one to see its columns and tags. | One table: `CALL SYSTEM$GET_CLASSIFICATION_RESULT('my_db.my_schema.customers');` |

Account-wide queries:

```sql
-- Latest result per table, including errors (can lag up to three hours).
SELECT database_name, schema_name, table_name, status, last_classified_on, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_CLASSIFICATION_LATEST
ORDER BY last_classified_on DESC;

-- Every column carrying a semantic category tag.
SELECT object_database, object_schema, object_name, column_name, tag_value
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE tag_database = 'SNOWFLAKE' AND tag_name = 'SEMANTIC_CATEGORY'
ORDER BY object_database, object_schema, object_name, column_name;
```

`ACCOUNT_USAGE` views lag. For a result that is current right now, use `SYSTEM$GET_CLASSIFICATION_RESULT` or the `INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS` table function, as the walkthrough does. `DATA_CLASSIFICATION_HISTORY` keeps every classification event for 365 days if you need to show how results changed.

The Trust Center can also generate a **Sensitive Data Entitlement report** (who *can* read sensitive tables) and a **Sensitive Data Access report** (who *did*), under **Settings » Reporting**. Both need `SNOWFLAKE.DATA_SECURITY_ADMIN`.

## Operate it

### Exclude data you do not want classified

Two steps: tag the object, then tell the profile to honor the tag.

```sql
ALTER TABLE my_db.my_schema.raw_logs
  SET TAG SNOWFLAKE.CORE.SKIP_SENSITIVE_DATA_CLASSIFICATION = 'TRUE';

CALL governance_db.sch.pii_profile!SET_ENABLE_TAG_BASED_SENSITIVE_DATA_EXCLUSION(TRUE);
```

The tag works on a schema, table, or column. In the Trust Center, the setting is **Exclude SKIP_SENSITIVE_DATA_CLASSIFICATION tagged objects** on the profile's classification criteria page. Without `APPLY TAG ON ACCOUNT`, a role can set the skip tag only on objects it owns.

### Change a profile

Use the profile's methods (`SET_TAG_MAP`, `SET_CUSTOM_CLASSIFIERS`, `SET_AI_MODE`, `ENABLE_AUTO_SCHEDULING_MODE`) to change an attached profile in place. `CREATE OR REPLACE` on a profile that is still set on a database or schema fails with error `398036 ... attached to one or more entities`; unset it first, replace it, then set it again.

### Cost

```sql
SELECT usage_date, credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'SENSITIVE_DATA_CLASSIFICATION'
ORDER BY usage_date DESC;
```

In Snowsight: **Admin » Cost management » Consumption**, Service Type **Sensitive Data Classification**. Rates are in the [Snowflake Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf). Keep costs predictable by leaving views excluded, skipping staging and log schemas that hold copies of data already classified elsewhere, and enabling AI mode only where standard classification misses things.

### Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| No results an hour after setting the profile | Scheduled runs start about one hour after the profile is set; `DATA_CLASSIFICATION_LATEST` can lag a further three hours. Check `SYSTEM$GET_CLASSIFICATION_RESULT` for the table. |
| Table never classified | If you cannot `SELECT` from it, classification cannot either. Check **Dashboard » Classification errors** or `DATA_CLASSIFICATION_LATEST.ERROR_MESSAGE`. |
| `NO_TAGGING_PRIVILEGE` | The role that set the profile lacks `APPLY TAG`. Grant it. |
| `MANUALLY_APPLIED_VALUE_PRESENT` | A value of the same tag was set on the column by hand. Keep it, or unset it and reclassify. |
| `TAG_NOT_ACCESSIBLE_OR_AUTHORIZED` | The tag in the tag map does not exist or the classifying role cannot see it. Create it or grant usage on its database and schema. |
| `mapped to multiple masking policies` | Tags on the column carry more than one masking policy for its data type. Unset the policy from one of the tags. |
| `invalid custom classifier configuration` (event table) | Fix the regex, category, or threshold in the custom classifier. |

Detailed errors are written to your account's event table under `scope:name = 'snow.automatic_sensitive_data_classification'`; filter `RECORD_ATTRIBUTES:"event_type"` on `CLASSIFICATION_ERROR` or `TAGGING_ERROR`. After three consecutive failures, Snowflake retries a table at most once every 22 hours.

## Common misconceptions

| Belief | Reality |
| --- | --- |
| "Classification masks my data." | It only tags. Masking happens because you attached a masking policy to the tag (Step 6). |
| "I have to classify each new table." | Once a profile is set on the database or schema, new and changed tables are classified on the profile's schedule. |
| "Testing with SYSTEM$CLASSIFY is read-only." | Only with `NULL` as the second argument. With a profile that has `auto_tag: true`, it applies tags. |
| "The compliance tiles prove I'm GDPR or HIPAA compliant." | They map native semantic categories to regulations as a starting point. Deciding what applies to your data is your responsibility. |
| "Classification reads every row." | It samples up to 10,000 rows per table. |

## Related Guides

- [Introduction to sensitive data classification](https://docs.snowflake.com/en/user-guide/classify-intro)
- [Tutorial: Automatically classify and tag sensitive data](https://docs.snowflake.com/en/user-guide/tutorials/sensitive-data-auto-classification)
- [Tag-based masking policies](https://docs.snowflake.com/en/user-guide/tag-based-masking-policies)

## External References

- [Use SQL to set up sensitive data classification](https://docs.snowflake.com/en/user-guide/classify-auto)
- [Use the Trust Center to set up sensitive data classification](https://docs.snowflake.com/en/user-guide/classify-ui-trust-center)
- [Native semantic categories](https://docs.snowflake.com/en/user-guide/classify-native)
- [Using custom classifiers](https://docs.snowflake.com/en/user-guide/classify-custom-using)
- [Excluding data from sensitive data classification](https://docs.snowflake.com/en/user-guide/classify-auto-exclude)
- [View and track classification results](https://docs.snowflake.com/en/user-guide/classify-results)
- [Troubleshooting sensitive data classification](https://docs.snowflake.com/en/user-guide/classify-troubleshooting)
- [CREATE CLASSIFICATION_PROFILE](https://docs.snowflake.com/en/sql-reference/classes/classification_profile/commands/create-classification-profile)
- [SYSTEM$CLASSIFY](https://docs.snowflake.com/en/sql-reference/stored-procedures/system_classify)
