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

This sets up SCIM — the automated sync that lets Entra create and manage Snowflake user accounts. When you add someone to the right Entra group in Microsoft, their Snowflake account appears automatically. When you remove them, access is revoked.

> **Note on the `AAD` name:** The SQL below uses `aad_provisioner` and `aad_provisioning`. "AAD" stands for Azure Active Directory — Microsoft's old name for what is now called Microsoft Entra ID. The names in the SQL are just identifiers; they don't refer to a different product.

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

### Generate the SCIM token

The Microsoft tutorial (Step 2) will ask for a **Secret Token** to authenticate its connection to Snowflake. Generate it now and keep it somewhere safe — you'll paste it into the Microsoft setup.

```sql
SELECT SYSTEM$GENERATE_SCIM_ACCESS_TOKEN('AAD_PROVISIONING');
```

Copy the value this returns. It won't be shown again after you close this result.

### Verify the integrations exist

```sql
SHOW INTEGRATIONS;
```

You should see `POWERBI` (type: `EXTERNAL_OAUTH`) and `AAD_PROVISIONING` (type: `SCIM`) in the list. If either is missing, re-run the block above.

---

### Which of these describes your Power BI users?

> **The single rule that causes most failures:**
> Every Power BI user needs a Snowflake account where the `LOGIN_NAME` field equals their exact work email address.
>
> If it doesn't match — even by one character, even if everything else is correct — the login fails with a misleading "invalid credentials" error.

Run this diagnostic query first. It reads the output of `SHOW USERS`, so you must run both statements:

```sql
SHOW USERS;
SELECT "name", "login_name", "email"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";
```

> **How this query pattern works:** `SHOW USERS` loads the user list into a temporary result. `RESULT_SCAN(LAST_QUERY_ID())` reads that result so you can filter and sort it. Both statements must run together.

Look at the `login_name` column in the results and identify which situation applies. **Your account may have users in more than one path — handle each group separately.**

---

**Path A — Users with no Snowflake account yet**

If a user doesn't appear in the results at all, they don't have a Snowflake account. SCIM will create their account automatically when Step 2 is complete. Nothing to do here for these users.

---

**Path B — Users whose `login_name` is already their work email**

If `login_name` looks like `alice@contoso.com`, these users are correctly configured. The OAuth integration will recognize them automatically once it's live.

No action needed for these users. → Continue to Step 2 when all users are accounted for.

---

**Path C — Users whose `login_name` is NOT their work email**

If `login_name` looks like `ALICE_SMITH` or `alice.smith` — anything that isn't an email address — these users will fail Power BI OAuth until fixed. This is the most common surprise when setting up OAuth on an account that already has users.

Pick one fix per user:

**Fix 1 — Update the login name directly** (simplest; best for a handful of users)

```sql
USE ROLE SECURITYADMIN;
ALTER USER ALICE_SMITH SET LOGIN_NAME = 'alice@contoso.com';
```

Repeat for each affected user. Their Snowflake permissions and settings are unchanged — only the login credential is updated.

**Fix 2 — Hand ownership to the SCIM provisioner** (best for many users, or if you want Entra to manage them long-term)

```sql
USE ROLE ACCOUNTADMIN;
GRANT OWNERSHIP ON USER ALICE_SMITH TO ROLE AAD_PROVISIONER;
```

After this, Entra will update the user's `LOGIN_NAME` at the next sync. Two things to know before using this fix:

- **Check the email in Entra first.** The sync will set `LOGIN_NAME` to whatever email address is on the user's Entra profile. If that's wrong, fix it in Entra before transferring ownership.
- **The sync runs automatically every ~40 minutes.** If you need it to happen immediately, go to Entra → Enterprise Applications → Snowflake → Provisioning → click **Provision on demand** for a specific user, or **Restart provisioning** to force a full sync.

> Existing Snowflake users not owned by `AAD_PROVISIONER` can't be updated by SCIM — that's why ownership transfer is required for Fix 2.

→ Once all users are in Path A or B (no one left in Path C), continue to Step 2.

---

## Step 2: Connect Microsoft Entra to Snowflake

This step happens in Microsoft Entra, not Snowflake. When complete, Entra will create and maintain Snowflake accounts for whoever you assign.

**Two values to have ready from Step 1:**

| Field | Value |
|---|---|
| **Tenant URL** | Your Snowflake SCIM endpoint — see below |
| **Secret Token** | The value returned by `SYSTEM$GENERATE_SCIM_ACCESS_TOKEN` in Step 1 |

**Construct your Tenant URL:**

Your Snowflake account URL is visible in your browser when you're in Snowsight — it looks like `https://YOUR_ORG-YOUR_ACCOUNT.snowflake.com`. Take everything before `.snowflake.com` and append `.snowflakecomputing.com/scim/v2/`:

```
https://YOUR_ORG-YOUR_ACCOUNT.snowflakecomputing.com/scim/v2/
```

**Follow Microsoft's tutorial:**
[Snowflake Provisioning Tutorial — Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/saas-apps/snowflake-provisioning-tutorial)

The tutorial walks through creating an enterprise application in Entra, entering the Tenant URL and Secret Token, and assigning which groups or users sync to Snowflake.

> **Important:** Create a new enterprise application — don't reuse an existing Snowflake application. Reusing one causes unpredictable behavior.

**What "done" looks like:**

After completing the tutorial, trigger a sync: in Entra → Enterprise Applications → your new Snowflake app → Provisioning → **Start provisioning** (or **Provision on demand** for specific users).

Then run `SHOW USERS;` in Snowsight. New users should appear with `login_name` values that are email addresses, owned by `AAD_PROVISIONER`. The automatic sync cycle runs every ~40 minutes; use **Provision on demand** if you need a user available immediately.

→ Once users appear in Snowflake with email login names, continue to Step 3.

---

## Step 3: Connect Power BI Desktop

First, make sure you have a report open (or create one) — you'll publish it at the end of this step.

1. Click **Get Data** → **Snowflake**
2. Enter your **Snowflake account URL**

   Find this in your browser while logged into Snowsight: it looks like `https://YOUR_ORG-YOUR_ACCOUNT.snowflake.com`. In Power BI, enter just `YOUR_ORG-YOUR_ACCOUNT.snowflakecomputing.com` (no `https://`, and use `.snowflakecomputing.com` not `.snowflake.com`).

3. Enter the **Warehouse** name

   Not sure which warehouse to use? Run `SHOW WAREHOUSES;` in Snowsight — it lists every warehouse your role can see. Pick one your Power BI users have access to, or ask your Snowflake admin.

4. Set **Data Connectivity mode** to the option you chose at the start of this guide
5. Click **OK**
6. When the authentication dialog appears, select **Microsoft Account**
7. Click **Sign in** and use your normal organizational email and password
8. Once signed in, the navigator shows your Snowflake databases — select your tables and build your report
9. When ready: **File → Publish → Publish to Power BI** → select your workspace

> **If you see a username and password field instead of "Microsoft Account":** Look for a tab or option labeled "Microsoft Account" or "Organizational account" — it may not be the default selection. Do not enter a Snowflake password here.

→ Once published, continue to Step 4.

---

## Step 4: Finish setup in Power BI Service

Publishing alone isn't enough — you need to configure credentials in Power BI Service so each viewer uses their own identity rather than the publisher's.

1. Go to your Power BI workspace in the browser
2. Find your published report's dataset — in newer Power BI it's called a **Semantic model** (older versions call it a **Dataset** — they're the same thing)
3. Click the three-dot menu → **Settings**
4. Under **Data source credentials**, click **Edit credentials** for the Snowflake entry
5. Set the authentication method to **OAuth2**
6. Check **Report viewers can only access this data source with their own Power BI identities**
7. Click **Sign in** and authenticate with your Microsoft account
8. Save

> **Step 6 is what enables per-person data access.** Without that checkbox, every viewer of the report uses the publisher's Snowflake credentials — row-level security won't work and the audit log will show all activity under one account.

**Do you need a gateway?**

| Your setup | Gateway |
|---|---|
| Power BI Service → Snowflake on a standard public URL | Not needed — Power BI has a built-in Snowflake driver |
| Power BI Service → Snowflake via Private Link or VPN | Required — [install an on-premises data gateway](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-onprem). Private Link means Snowflake is accessed over a private network, not the public internet — common in security-conscious organizations. |
| Power BI Desktop → Snowflake | Never needed |

---

## Check that it worked

After the first successful Power BI connection, run this in Snowsight:

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

If the query returns no rows at all, Power BI connected using username and password instead of the Microsoft login. Go back to Steps 3 and 4 and confirm "Microsoft Account" and "OAuth2" were selected.

---

## When something goes wrong

### Error table

| Power BI shows | What it means | Fix |
|---|---|---|
| "Invalid OAuth access token" | Tenant ID is wrong, or the issuer URL is missing the trailing `/` | Re-check Step 1 Block A. Run `DESC SECURITY INTEGRATION powerbi` in Snowsight and verify the issuer URL contains your tenant ID and ends with `/`. |
| "Incorrect username or password" | Snowflake can't find a user whose `LOGIN_NAME` matches the email | See the Path C section above |
| "User access disabled" | The Snowflake user account is disabled | `ALTER USER <name> SET DISABLED = FALSE` |
| "OAuth Authz Server Integration is not enabled" | The Block A integration (the trust agreement with Microsoft) is missing or disabled | Re-run Step 1 Block A. Run `SHOW INTEGRATIONS` to check. |
| "No default role has been assigned to the user" | The Snowflake user has no default role set | `ALTER USER <name> SET DEFAULT_ROLE = <role>` |
| "User's configured default role is not granted" | The default role isn't actually granted to the user | `GRANT ROLE <role> TO USER <name>` |
| Warehouse error / report won't load | Warehouse is suspended and not set to wake up automatically | `ALTER WAREHOUSE <name> SET AUTO_RESUME = TRUE` |
| "We couldn't authenticate with the credentials provided" | Almost always a `LOGIN_NAME` mismatch | See the Path C section above |

### Diagnostic checklist

Run through this in order before spending time on deeper investigation:

```
□ SHOW INTEGRATIONS → POWERBI (EXTERNAL_OAUTH) and AAD_PROVISIONING (SCIM) both listed
□ DESC SECURITY INTEGRATION powerbi → issuer URL has your tenant ID and ends with /
□ SHOW USERS → affected user exists, login_name is an email address
□ SHOW GRANTS TO USER <name> → their default role appears in the list
□ login_history → FIRST_AUTHENTICATION_FACTOR = OAUTH_ACCESS_TOKEN on successful logins
□ Warehouse → AUTO_RESUME = TRUE
□ Power BI Service → dataset credentials set to OAuth2, per-viewer identity checkbox enabled
```

### Getting the real error message

If Power BI shows an error containing a long ID string (a UUID), run this in Snowsight — it returns the actual reason Snowflake rejected the login, which is far more useful than the generic Power BI message:

```sql
SELECT SYSTEM$GET_LOGIN_FAILURE_DETAILS('<paste-uuid-here>');
```

---

## Special cases

These only apply to specific situations. If none match your setup, you're done.

### External partners or guest users (Microsoft B2B)

"B2B" means people from another company's Microsoft tenant who have been invited as guests into your Power BI workspace. They need a separate security integration with one setting changed.

In Block A, Microsoft identifies regular users by their `upn` — the User Principal Name, which is just their work email address in Microsoft's system. For B2B guests, the equivalent identifier is `unique_name`. Create this integration in addition to the one in Block A:

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

Guest users still need Snowflake accounts with a `LOGIN_NAME` matching their email — the same Path A/B/C logic applies.

### US Government cloud

If your Power BI tenant is in Azure Government (your Power BI URL ends in `.us` or contains `usgov`), use different audience URLs in Block A:

```sql
EXTERNAL_OAUTH_AUDIENCE_LIST = (
    'https://analysis.usgovcloudapi.net/powerbi/connector/Snowflake',
    'https://analysis.usgovcloudapi.net/powerbi/connector/snowflake'
)
```

Everything else stays the same.

### IP restrictions on Snowflake

If your Snowflake account has a network policy (a list of allowed IP addresses), Power BI's IP addresses need to be on it. Microsoft's IPs change periodically, so you pull them from Microsoft's published list rather than hardcoding them.

1. Download the Azure IP ranges file from Microsoft (search "Azure IP ranges download" — it's a JSON file updated weekly)
2. Search for `PowerBI.` followed by your Azure region (e.g., `PowerBI.EastUS`)
3. Add all IP ranges listed there to a Snowflake network policy

```sql
CREATE NETWORK POLICY powerbi_allowed_ips
    ALLOWED_IP_LIST = (
        '52.239.152.0/22'
        -- add all IP ranges for your region from the Azure JSON
    );

ALTER ACCOUNT SET NETWORK_POLICY = powerbi_allowed_ips;
```

Network policies apply at the account or user level — they can't be scoped to just Power BI connections.

---

## Reference links

- [Snowflake docs: Power BI SSO setup](https://docs.snowflake.com/en/user-guide/oauth-powerbi)
- [Snowflake docs: Microsoft Entra SCIM integration](https://docs.snowflake.com/en/user-guide/scim-azure)
- [Microsoft tutorial: Snowflake provisioning with Entra](https://learn.microsoft.com/en-us/azure/active-directory/saas-apps/snowflake-provisioning-tutorial)
- [Microsoft: Azure IP ranges download](https://www.microsoft.com/en-us/download/details.aspx?id=56519)
- [Microsoft: Power BI Snowflake connector](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-snowflake)
- [Microsoft: On-premises data gateway](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-onprem)
