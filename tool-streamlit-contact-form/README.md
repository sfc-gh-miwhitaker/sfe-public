# Contact Form (Streamlit in Snowflake)

> **Expires:** 2026-01-09 (30 days from creation)

A simple contact form built with Streamlit in Snowflake that collects user information and writes directly to a Snowflake table.

---

## What It Does

- Displays a contact form with name, email, and address fields
- Validates user input (required fields, email format)
- Writes submissions directly to a Snowflake table
- Shows recent submissions in a data table
- Tracks submission count

---

## Snowflake Features Demonstrated

- **Streamlit in Snowflake** - Native Python UI framework
- **Snowpark** - DataFrame operations and SQL execution
- **Session Context** - Using `get_active_session()` for database access

---

## Quick Start

### 1. Run Shared Setup (First Time Only)

```sql
-- Copy shared/sql/00_shared_setup.sql into Snowsight, Run All
```

### 2. Deploy This Tool

```sql
-- Copy deploy.sql into Snowsight, Run All
```

### 3. Use the Tool

1. Navigate to **Projects → Streamlit** in Snowsight
2. Find **SFE_CONTACT_FORM** in the list
3. Click to open the app
4. Fill out the form and click **Submit**
5. See your submission appear in the "Recent Submissions" table

---

## Objects Created

| Object Type | Name | Purpose |
|-------------|------|---------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM` | Tool namespace |
| Table | `SFE_SUBMISSIONS` | Stores form submissions |
| Stage | `SFE_STREAMLIT_STAGE` | Streamlit app files |
| Streamlit | `SFE_CONTACT_FORM` | The contact form app |
| Procedure | `SFE_SETUP_APP` | Uploads Streamlit code |

---

## Sample Data

After submitting the form, your data appears in:

```sql
SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM.SFE_SUBMISSIONS;
```

| submission_id | full_name | email | address | submitted_at |
|---------------|-----------|-------|---------|--------------|
| 1 | Jane Smith | jane@example.com | 123 Main St | 2025-12-10 10:30:00 |

---

## Cleanup

```sql
-- Copy teardown.sql into Snowsight, Run All
```

This removes:
- Schema `SFE_CONTACT_FORM` and all contained objects
- Does NOT remove shared infrastructure (database, warehouse)

---

## Architecture

See `diagrams/` for:
- `data-flow.md` - How form data flows from UI to table

---

## Customization Ideas

1. **Add more fields** - Phone number, company name, etc.
2. **Add validation** - More sophisticated email/phone validation
3. **Add export** - Download submissions as CSV
4. **Add charts** - Submission trends over time

---

*SE Community • Contact Form Tool • Created: 2025-12-10*
