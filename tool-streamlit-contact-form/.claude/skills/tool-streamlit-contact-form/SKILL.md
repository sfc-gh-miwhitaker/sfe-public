---
name: tool-streamlit-contact-form
description: "Simple Streamlit-in-Snowflake contact form. Triggers: contact form, streamlit form, form submissions table, streamlit in snowflake minimal, streamlit inline deployment."
---

# Contact Form (Streamlit in Snowflake)

## Purpose

Minimal Streamlit-in-Snowflake contact form that writes submissions to a Snowflake table. Demonstrates the simplest possible Streamlit deployment pattern using inline code via a Python stored procedure.

## When to Use

- Building a simple form-to-table Streamlit app
- Understanding the inline Streamlit deployment pattern (PUT from stage)
- Adapting for other form-based data collection use cases

## Architecture

```
Streamlit App (inline code via PUT)
  ├── Name, Email, Message fields
  └── Submit button
       │
       ▼
SFE_SUBMISSIONS table
  └── (name, email, message, submitted_at)
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sql` | Schema, table, stage, Streamlit app via Python proc (put_stream) |
| `teardown.sql` | Drops schema |

## Inline Deployment Pattern

The Streamlit code is embedded in a Python stored procedure that writes it to a stage.
The file MUST be staged BEFORE `CREATE STREAMLIT FROM` (which copies files at creation time),
followed by `ADD LIVE VERSION FROM LAST` to activate the app:

```sql
CREATE STAGE @<stage> DIRECTORY = (ENABLE = TRUE);
CREATE PROCEDURE SFE_SETUP_APP() ... AS $$ session.file.put_stream(...) $$;
CALL SFE_SETUP_APP();
ALTER STAGE @<stage> REFRESH;
CREATE STREAMLIT SFE_CONTACT_FORM FROM @<stage> MAIN_FILE = 'streamlit_app.py';
ALTER STREAMLIT SFE_CONTACT_FORM ADD LIVE VERSION FROM LAST;
```

## Extension Playbook: Adding New Form Fields

1. Add the `st.text_input()` or `st.selectbox()` in the inline Streamlit code within `deploy.sql`
2. Add the corresponding column to `SFE_SUBMISSIONS` table
3. Update the INSERT statement in the form submit handler
4. Redeploy by running `deploy.sql`

## Extension Playbook: Migrating to Git-Integrated Deployment

1. Move the inline Streamlit code to `streamlit/app.py`
2. Replace the `put_stream` pattern with:
   ```sql
   CREATE STREAMLIT ... FROM @<git_repo_stage>/.../ MAIN_FILE = 'app.py';
   ```
3. Use `ADD LIVE VERSION FROM LAST` for auto-updates from Git

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM` |
| Warehouse | `SFE_TOOLS_WH` (shared) |
| Table | `SFE_SUBMISSIONS` |
| Streamlit | `SFE_CONTACT_FORM` |

## Gotchas

- `CREATE STREAMLIT FROM` copies files at creation time -- stage the file FIRST, then create the Streamlit object
- `ADD LIVE VERSION FROM LAST` is required after `CREATE STREAMLIT` for the app to be live without manual Snowsight visit
- AUTOINCREMENT defaults to NOORDER since BCR-1483 (2024_01) -- use explicit ORDER if sequential IDs are needed
- Inline deployment via `put_stream` is simpler but harder to version control than Git-integrated
- The shared `SFE_TOOLS_WH` warehouse keeps costs minimal
- `submitted_at` uses `CURRENT_TIMESTAMP()` -- timezone is session-dependent
- Schema CASCADE drop in teardown removes all objects
