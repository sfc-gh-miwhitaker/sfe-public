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

### Teams vs M365 Copilot

| Capability | Microsoft Teams | Microsoft 365 Copilot |
|---|---|---|
| License required | Microsoft 365 | Microsoft 365 Copilot |
| Conversation model | Single continuous chat | Multiple separate conversations |
| UI | Standard Teams bot UI | Improved, modern Copilot UI |
| Feedback (thumbs up/down) | Propagated to Snowflake via Feedback API | Not propagated (Microsoft limitation) |
| Custom branding | Available (Teams admin) | Not available |

---

## Data Processing Consent

Accounts located in a region **other than Azure US East 2** will see a one-time
consent prompt acknowledging that prompts and responses are processed (not stored)
through Azure US East 2. Your Snowflake data remains in your account's home region.

To check your account region:

```sql
SELECT CURRENT_REGION();
```

Reference: [Data Processing Consent](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration#consent-for-accounts-outside-azure-us-east-2)

---

## Update the App

When a new version of the Snowflake Cortex Agents app is released:

**Method 1 -- From the chat:**
1. Look for the **"Update"** button in the top-right of the Cortex Agents chat
2. Click **"Update now"** on the app card

**Method 2 -- From the Apps menu:**
1. Click **"Apps"** in Teams
2. Search for **"Cortex Agents"** (or browse **"Built for your org"**)
3. Click **"Open"**, then **"Update now"** on the app card

---

## Available Commands

| Command | Availability | Description |
|---|---|---|
| `What is a snowflake cortex agent` | Always | Brief product description |
| `Help` | Always | Context-specific guidance and usage tips |
| `Choose agent` | Requires configured account | Switch between agents |
| `Starter prompts` | Requires agent with sample questions | Show example questions |
| `Show configured accounts` | Requires configured account | List connected Snowflake accounts |
| `Clear context` | Requires selected agent | Start a new conversation thread |
| `Logout` | Always | Log out from current account |
| `Admin Panel` | Always (admin actions need privileges) | Manage Snowflake accounts |
| `Add account` | Always (admin privileges to complete) | Connect a new Snowflake account |
| `Describe account` | Administrator only | View account URL, name, region, locator |
| `Remove account` | Administrator only | Disconnect a Snowflake account |

---

## Response Types

### Text Responses

Standard text answers appear directly in the chat.

### Table Responses

When the agent returns tabular data:
- Tables with more than 5 columns/rows or long values expand via **"View full table"**
- **Download as CSV** -- click the download icon; the file is uploaded to OneDrive
  and returned in the message (you will be prompted to allow OneDrive access)
- **Query ID** -- click the info icon to see the underlying Snowflake query ID

### Chart Responses

Charts are rendered as static images (interactive charts are not supported in
Teams/Copilot). If a table is available for the same data, you can toggle between
chart and table views.

### Citations

When the agent uses a Cortex Search tool, clickable text citations appear in the
response. Citation display requires properly configured ID and title columns in the
Cortex Search service.

### Thinking Steps

Click **"Show details"** on any response to see the agent's reasoning steps and
tool calls.

---

## Feedback

Rate agent responses with **thumbs up / thumbs down** icons. You can also add
free-text feedback. Administrators can review feedback in
[Monitoring Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-monitor).

> **Note:** Feedback is propagated to Snowflake via the
> [Feedback API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-feedback-rest-api)
> in Microsoft Teams only. In M365 Copilot, feedback controls are not yet connected
> to the Snowflake Feedback API.

---

## Clear Context

Type **"clear context"** to start a fresh conversation thread with the selected
agent. This creates a new session via the
[Threads API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-threads-rest-api).
If the agent returns incomplete results, clearing context often resolves the issue.

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

- See `docs/04-CUSTOMIZATION.md` for production use cases, custom branding, and handoff patterns
