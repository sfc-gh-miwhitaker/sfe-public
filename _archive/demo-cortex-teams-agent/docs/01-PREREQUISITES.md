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

- [ ] **Network policies** are supported (since March 2026) with two caveats:
  - IP addresses from Entra ID can be stale -- users may need to re-login to refresh
  - IPv6 addresses from Entra ID are not yet supported by Snowflake
  - See [Network Policies documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration#network-policies)
- [ ] **Private Link** is **not supported** with this integration (under evaluation)
- [ ] If network policy issues arise, see [Troubleshooting Network Policies](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration#network-policy-issues)

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
