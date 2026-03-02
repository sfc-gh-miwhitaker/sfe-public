# QuickBooks Online API Setup

## Overview

This guide walks through configuring QuickBooks Online (QBO) OAuth 2.0 credentials for use with Snowflake's External Access Integration. Skip this if using sample data mode.

## Step 1: Create an Intuit Developer Account

1. Go to [developer.intuit.com](https://developer.intuit.com)
2. Sign up or sign in
3. Navigate to **My Apps** > **Create an app**
4. Select **QuickBooks Online and Payments**
5. Give your app a name (e.g., "Snowflake QBO Integration")

## Step 2: Configure OAuth 2.0

In your app's **Keys & credentials** tab:

- **Client ID**: Copy this value
- **Client Secret**: Copy this value
- **Redirect URI**: Add `https://login.snowflake.com/oauth/redirect` (Snowflake's OAuth callback)

### Scopes Required

- `com.intuit.quickbooks.accounting` -- read access to all accounting entities

### Sandbox vs Production

| Environment | Base URL | Use Case |
|------------|----------|----------|
| Sandbox | `sandbox-quickbooks.api.intuit.com` | Testing/demos |
| Production | `quickbooks.api.intuit.com` | Real company data |

The demo defaults to **sandbox**. To switch to production, update the `BASE_URL` in `03_fetch_procedures.sql`.

## Step 3: Find Your Realm ID (Company ID)

The Realm ID identifies which QuickBooks company you're connecting to:

1. Log into [QBO Sandbox](https://developer.intuit.com/app/developer/playground) or your production QBO
2. Look at the URL: `https://app.qbo.intuit.com/app/homepage?companyId=XXXXXXXXXX`
3. The `companyId` parameter is your Realm ID
4. Or use the API Explorer: the Company ID is shown in the header

## Step 4: Configure Snowflake Objects

Run `sql/02_bronze/01_network_and_auth.sql` and replace the placeholders:

```sql
-- In the SECURITY INTEGRATION:
OAUTH_CLIENT_ID = '<YOUR_INTUIT_CLIENT_ID>'          -- from Step 2
OAUTH_CLIENT_SECRET = '<YOUR_INTUIT_CLIENT_SECRET>'   -- from Step 2
```

## Step 5: Complete the OAuth Flow

After creating the secret, initiate the OAuth consent flow:

```sql
-- Start the flow (returns a URL to visit)
CALL SYSTEM$START_OAUTH_FLOW('SNOWFLAKE_EXAMPLE.QB_API.SFE_QBO_OAUTH_SECRET');

-- Visit the URL, log into QBO, authorize the app
-- Copy the query parameters from the redirect URL

-- Finish the flow (stores the refresh token in the secret)
CALL SYSTEM$FINISH_OAUTH_FLOW('state=<STATE>&code=<CODE>&realmId=<REALM_ID>');
```

## Step 6: Test the Connection

```sql
-- Fetch a single entity to verify
CALL FETCH_QBO_ENTITY('Customer', '<YOUR_REALM_ID>', TRUE);

-- Check results
SELECT COUNT(*) FROM RAW_CUSTOMER;
```

## Step 7: Configure the Task

Update the Realm ID in the task and resume it:

```sql
-- In sql/06_orchestration/01_tasks.sql, replace '<YOUR_REALM_ID>'
ALTER TASK FETCH_QBO_ENTITIES_TASK RESUME;
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `401 Unauthorized` | Refresh token expired. Re-run `SYSTEM$START_OAUTH_FLOW` |
| `403 Forbidden` | Check scopes in security integration |
| Network timeout | Verify network rule includes `oauth.platform.intuit.com` |
| Empty results | Check Realm ID matches your QBO company |

## Token Lifecycle

- **Access tokens** expire every 60 minutes (Snowflake refreshes automatically)
- **Refresh tokens** expire after 100 days of inactivity
- If the refresh token expires, re-run the OAuth flow (Step 5)
