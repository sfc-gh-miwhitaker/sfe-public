# Install Teams & M365 Copilot App

**For:** End users and administrators
**Time:** 2 minutes
**Depends:** All Snowflake setup complete, Entra ID consent granted

---

## Install from Teams Store

1. Open **Microsoft Teams**
2. Click **"Apps"** in the left sidebar
3. Search for: **"Snowflake Cortex Agents"**
4. Click **"Add"** to install

> **Note:** Depending on your organization's Teams policies, a Teams Administrator
> may need to approve the app before it appears in the store.

---

## Connect Your Snowflake Account

The **first user** to open the app must have ACCOUNTADMIN or SECURITYADMIN privileges.

1. Open the Cortex Agents bot chat in Teams
2. Click **"I'm the Snowflake administrator"**
3. Enter your Snowflake account URL (format: `your-org-your-account.snowflakecomputing.com`)
4. Complete the configuration wizard
5. The app validates your connection and discovers available agents

> **Important:** Do not use ACCOUNTADMIN as your default role for setup. The security
> integration blocks administrative roles. Create a dedicated role or use secondary roles:
> ```sql
> GRANT ROLE CORTEX_AGENT_USERS TO USER <setup_user>;
> ALTER USER <setup_user> SET DEFAULT_SECONDARY_ROLES = ('ALL');
> ```

After setup, additional users simply install and authenticate -- no admin steps needed.

---

## Connect Additional Accounts

To add more Snowflake accounts to the same Teams app:
1. In the bot chat, type: **"add account"**
2. Follow the same connection flow

---

## Select an Agent

1. In the bot chat, type: **"choose agent"**
2. Select **Joke Assistant** from the list
3. Start chatting!

---

## Microsoft 365 Copilot Integration

If your organization has M365 Copilot licenses:

1. The same agents are automatically available in **Microsoft 365 Copilot**
2. Users can invoke Snowflake agents within their broader Copilot workflow
3. No additional setup required -- agents created for Teams work in Copilot too

> **Note:** A Copilot license is required for M365 Copilot access.
> The feedback feature is available only in Microsoft Teams, not in Copilot.

---

## Available Commands

| Command | Description |
|---|---|
| `Help` | List available commands |
| `Choose agent` | Switch between agents |
| `Logout` | Log out from current account |
| `Show configured accounts` | List connected Snowflake accounts |
| `Clear context` | Reset chat history |
| `Starter prompts` | Show example questions |
| `Admin Panel` | Admin commands for your account |
| `Add account` | Connect another Snowflake account |
| `Remove account` | Disconnect a Snowflake account |

---

## Test the Integration

Ask the Joke Assistant:
```
Tell me a joke about data engineers
```

Expected response: A clean, workplace-appropriate joke about data engineers.

Try more:
```
Give me a joke about SQL
Make me laugh about cloud computing
Tell me something funny about Snowflake
```

---

## Next Steps

- See `docs/04-CUSTOMIZATION.md` for production use cases and handoff patterns
