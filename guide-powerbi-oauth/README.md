# Connect Power BI to Snowflake Using Your Microsoft Login

![Expires](https://img.shields.io/badge/Expires-2026--08--19-orange)

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-07-20 | **Expires:** 2026-08-19 | **Status:** ACTIVE

Power BI needs to verify who each person is before it shows them Snowflake data. Right now it probably uses a shared password — meaning everyone looks the same to Snowflake. This guide switches it to use your organization's Microsoft login instead, so each person is identified individually.

**Three systems, three jobs:**

| System | What you do | Time |
|---|---|---|
| **Snowflake** | Run two SQL blocks in Snowsight | ~10 min |
| **Microsoft Entra** | Follow one Microsoft tutorial link | ~20 min (may need your Entra admin) |
| **Power BI** | Click through connection settings | ~5 min |

---

## Before you start

**1. Find your Entra Tenant ID**

This is a string of letters and numbers that identifies your Microsoft organization. You'll paste it into one SQL command in Step 1.

Where to find it:
- Go to [portal.azure.com](https://portal.azure.com) → search "Microsoft Entra ID" → Overview page → look for **Tenant ID**
- Or: Power BI Admin portal → Settings → About Power BI

It looks like this: `a828b821-f44f-4698-85b2-3c6749302698`

**2. Snowflake access you need**

You need the `ACCOUNTADMIN` role in Snowflake for Step 1. If you don't have it, ask your Snowflake account admin to either run Step 1 for you or grant you the role temporarily.

**3. Who else might need to be involved**

Step 2 happens entirely in Microsoft Entra. If you don't manage Entra yourself, you'll need to loop in whoever does (often an IT/identity team) for that step. Get them on standby before you start.

---

## Live data or a scheduled copy? Pick one before continuing

Power BI can either query Snowflake live every time someone opens a report, or copy the data on a schedule and serve it from a local cache. Pick your mode now — it affects how you configure Power BI in Steps 3 and 4.

| I want... | Use |
|---|---|
| Data that's always current when the report opens | **DirectQuery** |
| A daily or hourly data refresh is fine | **Import** |
| Each person to only see data they're allowed to see (row-level security in Snowflake) | **DirectQuery** — required |
| Fast report performance, complex calculations | **Import** |
| Very large tables (hundreds of millions of rows) | **DirectQuery** |

**Not sure?** Start with Import. You can switch to DirectQuery later without redoing the login setup in this guide.

> **Row-level security note:** If you need different people to see different rows of data based on who they are (e.g., each manager only sees their own team's numbers), you need DirectQuery. With DirectQuery + the OAuth setup in this guide, Snowflake enforces data access per person automatically.

---

## Step 1: Configure Snowflake

Open Snowsight. You'll run two SQL blocks — stay here until both are done.

### Block A: Tell Snowflake to trust Microsoft logins

This creates a trust agreement: "Snowflake, accept Microsoft's word for who Power BI users are."

```sql
USE ROLE ACCOUNTADMIN;

CREATE SECURITY INTEGRATION powerbi
    TYPE = external_oauth
    ENABLED = true
    EXTERNAL_OAUTH_TYPE = azure
    EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/<YOUR_ENTRA_TENANT_ID>/'
    EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://login.windows.net/common/discovery/keys'
    EXTERNAL_OAUTH_AUDIENCE_LIST = (
        'https://analysis.windows.net/powerbi/connector/Snowflake',
        'https://analysis.windows.net/powerbi/connector/snowflake'
    )
    EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'upn'
    EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'login_name';
```

**The only thing to change:** Replace `<YOUR_ENTRA_TENANT_ID>` with your actual tenant ID from the "Before you start" section.

Example:
```
EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/a828b821-f44f-4698-85b2-3c6749302698/'
```

Don't change anything else — the URLs, the audience list, the token mapping are all fixed values that Microsoft and Snowflake expect.

> **The trailing `/` on the issuer URL is required.** Without it, every login fails with a misleading error.

### Block B: Allow Microsoft Entra to sync users automatically

This sets up SCIM — the automated sync that lets Entra create and manage Snowflake user accounts. When you add someone to the right Entra group, their Snowflake account is created automatically with the right settings. When you remove them, access is revoked.

```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS aad_provisioner;
GRANT CREATE USER ON ACCOUNT TO ROLE aad_provisioner;
GRANT CREATE ROLE ON ACCOUNT TO ROLE aad_provisioner;
GRANT ROLE aad_provisioner TO ROLE accountadmin;

CREATE OR REPLACE SECURITY INTEGRATION aad_provisioning
    TYPE = scim
    SCIM_CLIENT = 'azure'
    RUN_AS_ROLE = 'AAD_PROVISIONER';
```

No substitutions needed — run this exactly as written.

### Are your Power BI users already in Snowflake?

Before moving to Step 2, identify which situation you're in. This affects what happens when Step 2 runs.

---

**Path A — These users don't have Snowflake accounts yet**

SCIM will create their accounts automatically when Step 2 is complete. Nothing else to do here.

→ Continue to Step 2.

---

**Path B — These users already have Snowflake accounts, and their login name is their work email**

They're ready. The OAuth integration will recognize them automatically. Run the query below to confirm which users fall into this category:

```sql
SHOW USERS;
SELECT "name", "login_name", "email"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "login_name" ILIKE '%@%'  -- login_name looks like an email address
ORDER BY "login_name";
```

Any user whose `login_name` matches their work email is already correctly configured.

→ Continue to Step 2. These users will work as-is.

---

**Path C — These users already have Snowflake accounts, but their login name is NOT their work email**

This is the most common surprise. It happens when Snowflake accounts were created with a username like `ALICE_SMITH` instead of an email address. When Power BI sends `alice@contoso.com` as the user's identity, Snowflake can't find a match — and the login fails with a confusing "invalid credentials" error even though the setup looks correct.

First, find out which users are affected:

```sql
SHOW USERS;
SELECT "name", "login_name", "email"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "login_name" NOT ILIKE '%@%'  -- login_name is NOT an email address
ORDER BY "name";
```

Then pick one of these two fixes:

**Fix 1 — Update the login name manually** (best for a small number of users)

```sql
USE ROLE SECURITYADMIN;
ALTER USER ALICE_SMITH SET LOGIN_NAME = 'alice@contoso.com';
```

Repeat for each affected user. Their existing Snowflake permissions and settings are not changed — only the login name used for authentication.

**Fix 2 — Transfer ownership to the SCIM provisioner** (best if you want Entra to manage these users going forward)

```sql
USE ROLE ACCOUNTADMIN;
GRANT OWNERSHIP ON USER ALICE_SMITH TO ROLE AAD_PROVISIONER;
```

After transferring ownership, Entra will update the user's settings at the next SCIM sync, including setting the correct login name based on their Entra profile. Make sure the user's email address in Entra is correct before doing this.

> Note: existing Snowflake users not owned by `AAD_PROVISIONER` cannot be updated by SCIM — that's why ownership transfer is needed.

---

> **The single rule that causes most failures:**
> Every Power BI user needs a Snowflake account where the `LOGIN_NAME` field equals their exact work email address.
>
> If it doesn't match — even by one character, even if everything else is correct — the login fails with a misleading "invalid credentials" error.

---

### Verify the integrations exist

Before moving on, confirm both integrations were created:

```sql
SHOW INTEGRATIONS;
```

You should see `POWERBI` (type: `EXTERNAL_OAUTH`) and `AAD_PROVISIONING` (type: `SCIM`) in the list.

---

## Step 2: Connect Microsoft Entra to Snowflake

This step happens in Microsoft Entra, not Snowflake. Entra will sync users to Snowflake automatically once it's configured.

**What you need from Step 1:** Your Snowflake SCIM endpoint URL. Construct it from your Snowflake account URL:

```
https://<your-snowflake-account>.snowflakecomputing.com/scim/v2/
```

For example: `https://YOUR_ORG-YOUR_ACCOUNT.snowflakecomputing.com/scim/v2/`

You'll paste this into the **Tenant URL** field during the Microsoft setup.

**Follow Microsoft's tutorial:**
[Snowflake Provisioning Tutorial — Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/saas-apps/snowflake-provisioning-tutorial)

The tutorial walks you through creating a new enterprise application in Entra, connecting it to Snowflake, and assigning the groups or users who should get Snowflake access.

**What "done" looks like:** After completing the tutorial and triggering a sync, run `SHOW USERS;` in Snowflake. You should see new users appearing with `LOGIN_NAME` values that are email addresses, owned by `AAD_PROVISIONER`.

> **Important:** Create a new enterprise application for this — don't reuse an existing one. Microsoft's documentation is explicit about this because reusing an app causes unpredictable behavior.

---

## Step 3: Connect Power BI Desktop

1. Open **Power BI Desktop**
2. Click **Get Data** → **Snowflake**
3. Enter your Snowflake account URL (e.g., `YOUR_ORG-YOUR_ACCOUNT.snowflakecomputing.com`)
4. Enter the **Warehouse** name
5. Set **Data Connectivity mode** to the option you chose at the top of this guide
6. Click **OK**
7. When the authentication dialog appears, select **Microsoft Account**
8. Click **Sign in** and use your normal organizational email and password
9. Once signed in, the navigator shows your Snowflake databases

> **If you see a username and password field instead:** Look for a tab or option labeled "Microsoft Account" or "Organizational account" — it may not be the default selection. Do not enter your Snowflake password here.

---

## Step 4: Finish setup in Power BI Service

Publishing the report isn't enough — you need to configure the credentials in Power BI Service, otherwise all report viewers will use the publisher's identity instead of their own.

1. Go to your Power BI workspace in the browser
2. Find your published dataset — in newer Power BI it's called a **Semantic model**
3. Click the three-dot menu → **Settings**
4. Under **Data source credentials**, click **Edit credentials** for the Snowflake entry
5. Set the authentication method to **OAuth2**
6. Check **Report viewers can only access this data source with their own Power BI identities**
7. Click **Sign in** and authenticate with your Microsoft account
8. Save

> **Step 6 is what enables per-person data access.** Without checking that box, every report viewer uses the publisher's Snowflake identity — row-level security won't work, and the audit log will show all activity under one account.

**Do you need a gateway?**

| Your setup | Gateway |
|---|---|
| Power BI Service → Snowflake on a public URL | Not needed — Power BI has a built-in Snowflake driver |
| Power BI Service → Snowflake via Private Link or VPN | Required — install an on-premises data gateway |
| Power BI Desktop → Snowflake | Never needed |

---

## Check that it worked

After the first Power BI connection, run this in Snowsight:

```sql
USE ROLE ACCOUNTADMIN;

SELECT
    event_timestamp,
    user_name,
    first_authentication_factor,
    is_success,
    error_message
FROM TABLE(information_schema.login_history(
    DATEADD('hours', -1, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
))
WHERE first_authentication_factor = 'OAUTH_ACCESS_TOKEN'
ORDER BY event_timestamp DESC;
```

If you see rows with `IS_SUCCESS = YES` and `FIRST_AUTHENTICATION_FACTOR = OAUTH_ACCESS_TOKEN`, OAuth is working.

If the query returns no rows at all, Power BI connected using username and password instead of Microsoft login. Go back to Steps 3 and 4 and make sure "Microsoft Account" and "OAuth2" were selected.

---

## When something goes wrong

### Error table

| Power BI shows | What it means | Fix |
|---|---|---|
| "Invalid OAuth access token" | Tenant ID is wrong, or the issuer URL is missing the trailing `/` | Re-check Step 1 Block A. Verify tenant ID and the trailing slash. |
| "Incorrect username or password" | Snowflake can't find a user whose `LOGIN_NAME` matches the email | See the [existing user paths](#path-c--these-users-already-have-snowflake-accounts-but-their-login-name-is-not-their-work-email) above |
| "User access disabled" | The Snowflake user account is disabled | `ALTER USER <name> SET DISABLED = FALSE` |
| "OAuth Authz Server Integration is not enabled" | The Step 1 Block A integration is missing or disabled | Re-run Block A. Run `SHOW INTEGRATIONS` to check. |
| "No default role has been assigned to the user" | The Snowflake user has no default role set | `ALTER USER <name> SET DEFAULT_ROLE = <role>` |
| "User's configured default role is not granted" | The default role isn't actually granted to the user | `GRANT ROLE <role> TO USER <name>` |
| Warehouse error / report won't load | Warehouse is suspended and won't wake up | `ALTER WAREHOUSE <name> SET AUTO_RESUME = TRUE` |
| "We couldn't authenticate with the credentials provided" | Almost always a `LOGIN_NAME` mismatch | Check the [existing user paths](#path-c--these-users-already-have-snowflake-accounts-but-their-login-name-is-not-their-work-email) above |

### Diagnostic checklist

If something isn't working, run through this list in order:

```
□ SHOW INTEGRATIONS → POWERBI (EXTERNAL_OAUTH, ENABLED) and AAD_PROVISIONING (SCIM) both present
□ DESC SECURITY INTEGRATION powerbi → issuer URL contains your tenant ID, ends with /
□ SHOW USERS → affected user exists, LOGIN_NAME looks like an email address
□ SHOW GRANTS TO USER <name> → their default role appears in the list
□ login_history → FIRST_AUTHENTICATION_FACTOR = OAUTH_ACCESS_TOKEN on successful logins
□ Warehouse → AUTO_RESUME = TRUE
□ Power BI Service → dataset credentials set to OAuth2 with per-viewer identity enabled
```

### Getting more detail on a specific failure

If Power BI shows an error with a long ID string (a UUID), paste it into this query — it returns the real reason Snowflake rejected the login, not the generic message Power BI shows:

```sql
SELECT SYSTEM$GET_LOGIN_FAILURE_DETAILS('<paste-uuid-here>');
```

---

## Special cases

These only apply to specific situations. If none match your setup, you're done.

### External partners or guest users (Microsoft B2B)

If people from other companies access your Power BI workspace as guests, they need a separate integration with one different setting. Create this in addition to the one in Step 1 Block A:

```sql
USE ROLE ACCOUNTADMIN;

CREATE SECURITY INTEGRATION powerbi_b2b
    TYPE = external_oauth
    ENABLED = true
    EXTERNAL_OAUTH_TYPE = azure
    EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/<YOUR_ENTRA_TENANT_ID>/'
    EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://login.windows.net/common/discovery/keys'
    EXTERNAL_OAUTH_AUDIENCE_LIST = (
        'https://analysis.windows.net/powerbi/connector/Snowflake',
        'https://analysis.windows.net/powerbi/connector/snowflake'
    )
    EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'unique_name'
    EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'login_name';
```

The only difference from Block A is `unique_name` instead of `upn`. Guest users still need Snowflake accounts with a `LOGIN_NAME` matching their email.

### US Government cloud

If your Power BI tenant is in Azure Government (`.us` domains), use different audience URLs in Block A:

```sql
EXTERNAL_OAUTH_AUDIENCE_LIST = (
    'https://analysis.usgovcloudapi.net/powerbi/connector/Snowflake',
    'https://analysis.usgovcloudapi.net/powerbi/connector/snowflake'
)
```

Everything else stays the same.

### IP restrictions on Snowflake

If your Snowflake account uses a network policy to restrict which IP addresses can connect, Power BI's IP addresses need to be on the allowed list. Microsoft's IPs change periodically, so you need to look them up from Microsoft's published list.

1. Download the Azure IP ranges file from Microsoft (search "Azure IP ranges download" — it's a JSON file updated weekly)
2. Search for `PowerBI.` followed by your Azure region (e.g., `PowerBI.EastUS`)
3. Add all IP ranges listed there to your Snowflake network policy

```sql
CREATE NETWORK POLICY powerbi_allowed_ips
    ALLOWED_IP_LIST = (
        '52.239.152.0/22'
        -- add all IP ranges for your region from the Azure JSON
    );

ALTER ACCOUNT SET NETWORK_POLICY = powerbi_allowed_ips;
```

Note: network policies can't be scoped to just Power BI connections — they apply at the account or user level.

---

## Reference links

- [Snowflake docs: Power BI SSO setup](https://docs.snowflake.com/en/user-guide/oauth-powerbi)
- [Snowflake docs: Microsoft Entra SCIM integration](https://docs.snowflake.com/en/user-guide/scim-azure)
- [Microsoft tutorial: Snowflake provisioning with Entra](https://learn.microsoft.com/en-us/azure/active-directory/saas-apps/snowflake-provisioning-tutorial)
- [Microsoft: Azure IP ranges download](https://www.microsoft.com/en-us/download/details.aspx?id=56519)
- [Microsoft: Power BI Snowflake connector](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-snowflake)
