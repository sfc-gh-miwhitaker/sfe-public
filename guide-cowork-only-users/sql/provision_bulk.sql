/*==============================================================================
  BULK USER PROVISIONING — guide-cowork-admin-setup
  Edit the INSERT block, then run this entire script in Snowsight
  (Worksheets → Run All).
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-22
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ─── 1. Define your user list ─────────────────────────────────────────────
-- Add one row per user. login_name is the IdP login identifier (usually email).
CREATE OR REPLACE TEMPORARY TABLE users_to_provision (
    login_name    VARCHAR,
    display_name  VARCHAR,
    email         VARCHAR
);

INSERT INTO users_to_provision (login_name, display_name, email) VALUES
    ('alice@yourcompany.com',   'Alice Smith',   'alice@yourcompany.com'),
    ('bob@yourcompany.com',     'Bob Jones',     'bob@yourcompany.com'),
    ('carol@yourcompany.com',   'Carol White',   'carol@yourcompany.com');
    -- Add one row per user

-- ─── 2. Set your warehouse (fill in before running) ───────────────────────
SET warehouse_name = '<your_warehouse>';

-- ─── 3. Provisioning loop ──────────────────────────────────────────────────
-- Uses EXECUTE IMMEDIATE with QUOTE_STRING() to handle email-format login names safely.
-- Idempotent: CREATE USER IF NOT EXISTS and GRANT ROLE skip existing entries.
DECLARE
    v_login     VARCHAR;
    v_display   VARCHAR;
    v_email     VARCHAR;
    v_warehouse VARCHAR DEFAULT $warehouse_name;
    v_count     INTEGER DEFAULT 0;
BEGIN
    FOR row IN (SELECT login_name, display_name, email FROM users_to_provision) DO
        v_login   := row.login_name;
        v_display := row.display_name;
        v_email   := row.email;

        EXECUTE IMMEDIATE
            'CREATE USER IF NOT EXISTS IDENTIFIER(' || QUOTE_STRING(:v_login) || ')
             LOGIN_NAME        = ' || QUOTE_STRING(:v_login)   || '
             DISPLAY_NAME      = ' || QUOTE_STRING(:v_display) || '
             EMAIL             = ' || QUOTE_STRING(:v_email)   || '
             DEFAULT_ROLE      = COWORK_USER
             DEFAULT_WAREHOUSE = IDENTIFIER(' || :v_warehouse || ')
             MUST_CHANGE_PASSWORD = FALSE';

        EXECUTE IMMEDIATE
            'GRANT ROLE COWORK_USER TO USER IDENTIFIER(' || QUOTE_STRING(:v_login) || ')';

        EXECUTE IMMEDIATE
            'ALTER USER IDENTIFIER(' || QUOTE_STRING(:v_login) || ')
             SET ALLOWED_INTERFACES = (SNOWFLAKE_INTELLIGENCE)';

        v_count := v_count + 1;
    END FOR;
    RETURN 'Provisioned ' || :v_count || ' users.';
END;

-- ─── 4. Quick verification ─────────────────────────────────────────────────
SELECT 'Users in provisioning list: ' || COUNT(*) FROM users_to_provision;
