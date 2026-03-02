# Microsoft Entra ID & Security Integration Setup

**For:** Azure Global Administrator + Snowflake ACCOUNTADMIN
**Time:** 5 minutes
**Frequency:** One-time per tenant

---

## Overview

Two manual steps connect Microsoft Teams to your Snowflake account:
1. **Entra ID consent** -- authorize two Snowflake apps in your Azure tenant
2. **Security integration** -- set your tenant ID in `deploy_all.sql` and re-run that section

---

## Part 1: Entra ID Consent (Azure Admin)

Grant tenant-wide consent for **both** Snowflake applications:

| Application | Purpose | Client ID |
|---|---|---|
| **Cortex Agents Bot OAuth Resource** | Protected Snowflake API + access scopes | `5a840489-78db-4a42-8772-47be9d833efe` |
| **Cortex Agents Bot OAuth Client** | Teams app backend that calls Snowflake API | `bfdfa2a2-bce5-4aee-ad3d-41ef70eb5086` |

### Step 1: Grant Consent for OAuth Resource

Replace `YOUR_TENANT_ID` and navigate to this URL:

```
https://login.microsoftonline.com/YOUR_TENANT_ID/adminconsent?client_id=5a840489-78db-4a42-8772-47be9d833efe
```

Sign in as Global Administrator, review permissions, click **"Accept"**.

### Step 2: Grant Consent for OAuth Client

```
https://login.microsoftonline.com/YOUR_TENANT_ID/adminconsent?client_id=bfdfa2a2-bce5-4aee-ad3d-41ef70eb5086
```

You will see **two** permission dialogs. Click **"Accept"** on both.

> You may see a benign error after the second consent:
> `{"error": {"code": "ServiceError", "message": "Missing required query string parameter: code..."}}`
> Consent was still granted. Verify below.

### Step 3: Verify

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com/)
2. Navigate to **Enterprise applications**
3. Search for **"Snowflake Cortex Agent"**
4. Confirm both applications appear

---

## Part 2: Security Integration (Snowflake ACCOUNTADMIN)

The security integration is created by `deploy_all.sql`, but it ships with a
placeholder tenant ID. Update it:

1. Open `deploy_all.sql` in Snowsight
2. Find `SET entra_tenant_id = 'YOUR_TENANT_ID';` (section 8)
3. Replace `YOUR_TENANT_ID` with your actual tenant ID
4. Re-run that section (or re-run the whole script)

Verify:

```sql
DESCRIBE SECURITY INTEGRATION SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION;
```

Confirm `EXTERNAL_OAUTH_ISSUER` contains your tenant ID and `ENABLED` = `true`.

### User Mapping

Snowflake users must match Entra ID users. The default maps by email:

| Mapping | JWT Claim | Snowflake Property |
|---|---|---|
| **Email (default)** | `email` | `EMAIL_ADDRESS` |
| **UPN (alternative)** | `upn` | `LOGIN_NAME` |

To switch to UPN mapping:

```sql
ALTER SECURITY INTEGRATION SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION SET
    EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = ('upn')
    EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME';
```

---

## Regional Data Processing

If your Snowflake account is outside Azure US East 2, users see a one-time consent
acknowledging that prompts and responses are processed (not stored) through Azure
US East 2. Your Snowflake data remains in your account's home region.

---

## Optional: Restrict User Access

**Require user assignment:**
```
Enterprise applications -> Snowflake Cortex Agents Bot OAuth Client
-> Properties -> "User assignment required" = Yes
-> Users and groups -> Add specific users/groups
```

**Conditional Access:**
```
Entra ID -> Security -> Conditional Access -> New policy
-> Target: "Snowflake Cortex Agents" -> Require MFA, etc.
```

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| "Need admin approval" | Consent not granted | Re-do Part 1 steps |
| "Application not found" | Consent incomplete | Complete both consent steps; wait 5 min |
| 390303 (Invalid OAuth token) | Wrong tenant ID | Check tenant ID in security integration |
| 390304 (User mapping failed) | EMAIL_ADDRESS mismatch | Verify Snowflake email matches Entra ID |
| 390317 (Role not in token) | ANY_ROLE_MODE disabled | Set `EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE'` |
| 390186 (Role not granted) | Default role blocked | Check BLOCKED_ROLES_LIST |

---

## Next Steps

Proceed to `docs/03-INSTALL-TEAMS-APP.md` to install the Teams app.
