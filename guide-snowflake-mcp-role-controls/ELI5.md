# ELI5: Snowflake MCP Role Controls

> Simplified from: `guide-snowflake-mcp-role-controls/README.md`

A Snowflake-managed MCP server is a secured doorway that lets an AI client use approved Snowflake tools. Roles determine which rooms the person entering that doorway can reach.

## One-Sentence Version

Give the MCP client one small, purpose-built key instead of letting it carry every key the user owns.

## The Story

Imagine a user works in a large office building:

- The **primary role** is the badge they present at reception.
- **Secondary roles** are extra badges they may carry at the same time.
- The **OAuth integration** tells reception which badges this application may accept.
- A **session policy** tells security which extra badges may actually be active inside the building.
- MCP and tool grants determine which specific doors each active badge can open.

The safest design gives the MCP client one badge called something like `MCP_ACCESS_ROLE`. That badge opens only the MCP server, its approved tools, and the data those tools require. Extra badges stay disabled.

## The Cast

- **MCP server:** The secured doorway an AI client uses to reach approved Snowflake tools.
- **Primary role:** The main badge presented when the Snowflake session starts.
- **Secondary role:** An extra badge whose privileges can be active at the same time.
- **OAuth integration:** Reception rules that authenticate the user and limit acceptable roles.
- **Session policy:** Security rules that limit which secondary roles may remain active.
- **Tool grant:** Permission to open one specific door after entering through MCP.

## What Changed

Snowflake provides separate controls for primary and secondary roles:

- `ALLOWED_ROLES_LIST` is on OAuth. It limits roles the application can use for the session.
- `ALLOWED_SECONDARY_ROLES` is on a session policy. It limits extra roles that can be active alongside the primary role.

They are not two spellings for the same setting.

## What to Watch Out For

Sometimes one role cannot be used because existing access is deliberately split. In that case, OAuth can activate the user's default secondary roles, while a session policy cuts the set down to named roles such as `MCP_ANALYST_ROLE` and `MCP_SEARCH_ROLE`.

That option is more complex. The administrator must test both the allowed and denied paths because combining roles combines their privileges.

## The misleading word "all"

Some MCP clients request an OAuth scope named `session:role:all`. Here, "all" does not mean all Snowflake roles. It tells Snowflake to use the user's default role. Whether secondary roles are active is decided separately.

## The One Thing to Remember

Start with one dedicated MCP access role and no secondary roles. Add selected secondary roles only when there is a documented requirement that the single role cannot satisfy.

Pair-programmed by SE Community + Cortex Code

> For the full technical details, see the source document.
