# Step 5: Progressive Unlock Test

Verify the full progressive unlock sequence works end-to-end.

## Test Matrix

| Test | Expected Result | Status |
|------|-----------------|--------|
| Ask advisor before governance | Reports **NOT READY** | |
| Deploy managed-settings.json | Banner appears, bypass blocked | |
| Ask advisor after governance | Reports **PARTIAL** | |
| Configure GitHub MCP | `/mcp` shows github connected | |
| Ask advisor after MCP | Reports **READY** | |
| Use scoped toolset | Only approved GitHub tools work | |

## Test 1: Before Governance

If you haven't deployed managed-settings.json yet:

```sql
SELECT SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.VALIDATE_GOVERNANCE_POLICY('quick');
```

Expected: `"readiness": "NOT READY"` with next step pointing to docs/02-GOVERNANCE-FIRST.md.

## Test 2: After Governance, Before MCP

After deploying managed-settings.json and logging it:

```sql
SELECT SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.VALIDATE_GOVERNANCE_POLICY('full');
```

Expected: `"readiness": "PARTIAL"` with next step pointing to docs/03-GITHUB-MCP-SETUP.md.

## Test 3: Full Validation

After both governance and MCP are configured:

```sql
SELECT SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.VALIDATE_GOVERNANCE_POLICY('full');
```

Expected: `"readiness": "READY"` with next step pointing to docs/04-TOOLSET-SCOPING.md.

## Test 4: Agent Conversation

In Snowflake Intelligence, start a conversation with `GOVERNANCE_ADVISOR`:

1. "Am I ready to enable GitHub?"
2. "What governance gaps do I have?"
3. "Show me the governance audit trail"

The agent should call `VALIDATE_GOVERNANCE_POLICY` and provide clear status with next steps.

## Test 5: GitHub MCP Functional Test

In Cortex Code with GitHub MCP configured:

```
# Should work (repos toolset):
"List the repositories in sfc-gh-miwhitaker"

# Should work (issues toolset, if using standard profile):
"Show open issues in sfe-public"

# May be blocked (depending on toolset profile):
"Create a pull request in sfe-public"
```

## Cleanup

If this was a test deployment, remove the managed-settings.json:

**macOS:**
```bash
sudo rm "/Library/Application Support/Cortex/managed-settings.json"
```

**Linux:**
```bash
sudo rm /etc/cortex/managed-settings.json
```

And run `teardown_all.sql` in Snowsight to remove Snowflake objects.
