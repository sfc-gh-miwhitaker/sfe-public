# Step 2: Governance First — Deploy Before You Connect

The progressive unlock thesis: **governance configuration must exist before external tool connections are allowed.**

## Why Governance First?

Without governance:
- Any user can add any MCP server (GitHub, Slack, arbitrary endpoints)
- No audit trail of what external tools are connected
- No constraints on what operations those tools can perform
- No IT visibility into AI-to-external-system communication

With governance:
- IT explicitly allows MCP connections via managed-settings.json
- Org policy controls which tools and accounts are available
- Sandbox mode is enforced
- A managed banner signals to users that policy is active

## The managed-settings.json for MCP

This demo uses a managed-settings.json that explicitly enables MCP while maintaining governance controls:

```json
{
  "version": "1.0",
  "permissions": {
    "dangerouslyAllowAll": false,
    "defaultMode": "allow"
  },
  "settings": {
    "forceSandboxEnabled": true
  },
  "required": {
    "minimumVersion": "1.0.0"
  },
  "ui": {
    "showManagedBanner": true,
    "bannerText": "[Governed] GitHub MCP Enabled — Managed by IT",
    "hideDangerousOptions": true
  }
}
```

See [reference/managed-settings-mcp-enabled.json](../reference/managed-settings-mcp-enabled.json) for the full template.

## Deploy the Policy

**macOS:**
```bash
sudo mkdir -p "/Library/Application Support/Cortex"
sudo cp reference/managed-settings-mcp-enabled.json \
  "/Library/Application Support/Cortex/managed-settings.json"
```

**Linux:**
```bash
sudo mkdir -p /etc/cortex
sudo cp reference/managed-settings-mcp-enabled.json \
  /etc/cortex/managed-settings.json
```

## Verify Deployment

1. Restart Cortex Code: `cortex`
2. Look for the banner: `[Governed] GitHub MCP Enabled — Managed by IT`
3. Try `cortex --dangerously-allow-all-tool-calls` — should be blocked

## Log the Deployment

After deploying, record it in the audit log by running this in Snowsight:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;

INSERT INTO GOVERNANCE_POLICY_LOG
    (POLICY_TYPE, DEPLOYER, PLATFORM, POLICY_SUMMARY, VALIDATION_RESULT, NOTES)
SELECT
    'managed-settings.json',
    CURRENT_USER(),
    CASE WHEN CURRENT_CLIENT() ILIKE '%mac%' THEN 'macOS' ELSE 'linux' END,
    PARSE_JSON('{
        "dangerouslyAllowAll": false,
        "forceSandboxEnabled": true,
        "showManagedBanner": true,
        "minimumVersion": "1.0.0"
    }'),
    'PASS',
    'Deployed governance policy enabling MCP with sandbox enforcement';
```

## Check Readiness

Ask the Governance Advisor: **"Am I ready to enable GitHub?"**

At this point, the advisor should report **PARTIAL** — governance is deployed but MCP is not yet configured.

## Next Step

→ [Step 3: GitHub MCP Setup](03-GITHUB-MCP-SETUP.md)
