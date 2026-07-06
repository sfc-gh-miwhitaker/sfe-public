# Path 1 — CoCo in the Snowflake VS Code Extension

> **Preview Feature — Open.** Available to all accounts.

The Snowflake Extension for Visual Studio Code ships CoCo as a built-in side panel. If you already sign into Snowflake through the extension for SQL editing or Snowpark, CoCo is already available — no separate auth, no CLI install, no Snowflake admin required.

## When to use this path

You want to work directly in CoCo. This is the fastest start: one click, no setup beyond the extension sign-in you likely already have. Full CoCo agent — natural-language sessions, Snowflake SQL execution, bundled skills — plus a visual UI layer: diff review for file changes, inline SQL result grids, named session history, and editor context (active file, text selection).

Works in **VS Code and Cursor** identically.

## Prerequisites

| | |
|---|---|
| **VS Code or Cursor** | Any recent version |
| **Snowflake extension** | `snowflake.snowflake-vsc` from the VS Code Marketplace |
| **Extension sign-in** | Sign in to a Snowflake account through the extension |
| **Role** | `SNOWFLAKE.CORTEX_USER` or `SNOWFLAKE.CORTEX_AGENT_USER` database role granted |

The CoCo CLI is installed automatically by the extension on first use. To update later: `cortex update`.

## Setup

**Step 1 — Install the extension**

Search for **Snowflake** in VS Code Extensions (`Ctrl+Shift+X` / `Cmd+Shift+X`) and install the extension published by Snowflake. Confirm the Snowflake badge before installing.

**Step 2 — Sign in**

Select the Snowflake icon in the Activity Bar. Enter your account identifier and choose an auth method: SSO (recommended for org accounts), username/password, key-pair, or `connections.toml`.

**Step 3 — Open CoCo**

Select the **CoCo icon** in the Activity Bar. The side panel opens. Start a session.

CoCo is enabled by default. If the icon is missing, confirm `CoCo: Enabled` is on in VS Code Settings (`Extensions > Snowflake`), or add `"snowflake.coco.enabled": true` to `settings.json`.

**Step 4 — Verify**

```
What databases do I have access to?
```

CoCo should respond with a list from your account. If it returns a permissions error, grant the required database role:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_default_role>;
```

---

## Limits and gotchas

- **Public preview.** UI labels and behavior can change between builds.
- **Uses the extension's active role.** CoCo starts with your `DEFAULT_ROLE`. Ask CoCo to switch roles during the session if needed, or set `DEFAULT_ROLE` on the account.
- **Cross-region inference may be required.** If the selected model isn't in your account's region:
  ```sql
  -- AWS (recommended: AWS_GLOBAL for full Claude coverage)
  ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_GLOBAL';
  -- Azure: AZURE_GLOBAL; multi-cloud: ANY_REGION
  ```
- **Government regions not supported.**

---

## Troubleshooting

**CoCo icon missing** — Toggle `CoCo: Enabled` in VS Code Settings.

**"CoCo CLI not found"** — The extension auto-installs, but if it fails:
```bash
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh
# Windows: irm https://ai.snowflake.com/static/cc-scripts/install.ps1 | iex
```
Reload VS Code after installing.

**Model availability error** — Enable cross-region inference (see above). If it persists, verify the model is enabled in your account's AI model access settings.

---

## References

- [Snowflake Extension for VS Code — CoCo section](https://docs.snowflake.com/en/user-guide/vscode-ext#coco-in-the-snowflake-extension-for-visual-studio-code)
- [VS Code Marketplace — Snowflake extension](https://marketplace.visualstudio.com/items?itemName=snowflake.snowflake-vsc)
- [CoCo overview](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
