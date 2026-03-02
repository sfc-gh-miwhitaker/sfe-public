# Prerequisites

**Time:** 5 minutes
**Frequency:** Verify once before starting

---

## Snowflake Requirements

- [ ] **ACCOUNTADMIN role** access in your Snowflake account
- [ ] **Cortex AI** enabled (verify: `SELECT AI_COMPLETE('mistral-large2', 'hello');`)
- [ ] **Cross-region inference** recommended for full model access:
  ```sql
  ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
  ```

## Microsoft Requirements

- [ ] **Microsoft Entra ID** Global Administrator privileges (or equivalent)
- [ ] **Microsoft Teams** license for end users
- [ ] **Microsoft 365 Copilot** license (optional, for M365 Copilot integration)
- [ ] **Tenant ID** available (Azure Portal -> Microsoft Entra ID -> Overview)

## Network Requirements

- [ ] **No network policies** blocking Snowflake (Teams integration does not support network policies)
- [ ] **No Private Link** configured (not supported with this integration)
- [ ] If either is enabled, see `sql/01_setup/05_grant_permissions.sql` for disable instructions

## User Mapping

Every end user needs:
- A Snowflake user account
- A Microsoft Entra ID account
- **Matching identities:** Snowflake EMAIL_ADDRESS must match Entra ID email/UPN

Verify your own mapping:
```sql
DESCRIBE USER CURRENT_USER();
-- Check the EMAIL property matches your Entra ID email
```

---

## Next Steps

Proceed to `docs/02-ENTRA-ID-SETUP.md` for Entra ID consent and security integration.
