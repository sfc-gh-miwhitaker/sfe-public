# Codex Leads, CoCo Handles the Snowflake Assignment

> Simplified from: [Use Codex with CoCo for Snowflake Work](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Keep Codex in charge and connect CoCo as a tool for specific Snowflake assignments.

## The Story

Think of renovating a house. The contractor coordinates the project, while an electrician handles one electrical job. You would not ask both to rebuild the same wall.

Codex is the contractor. CoCo is the Snowflake specialist. MCP is a standard connection that lets Codex call CoCo as a tool.

Start with that direct connection. AI Kit offers automatic routing, but its reviewed Codex launcher approves inner actions automatically and turns off CoCo's external MCP connections. Those differences make it an alternative to evaluate, not this guide's default.

If you simply want CoCo in Microsoft Visual Studio Code, start with the official Snowflake extension instead. Sign in and open its CoCo panel. You do not need the delegation setup or a separate CoCo CLI installation for that editor path.

## The Cast

- **Codex:** The assistant responsible for the overall project and final review.
- **CoCo:** The assistant receiving the Snowflake assignment.
- **MCP:** The connection that lets Codex call CoCo as a tool.
- **AI Kit:** An optional routing plugin with different approval behavior on its Codex path.
- **Handoff:** The assignment, permitted actions, relevant context, and expected evidence.
- **Access controls:** Enforced limits on database actions, files, and other resources.

## What Changes

- You can request Snowflake help without leaving Codex's conversation.
- Codex keeps the application work; CoCo receives one clearly scoped assignment.
- You send relevant context instead of the whole conversation.
- You review a proposal before authorizing changes.

For example, an order with two items can accidentally have its revenue counted twice. Give CoCo synthetic numbers first and check its explanation. Nobody needs production rows or deployment permission to explain that mistake.

## What to Watch Out For

**An assignment is not a key.** Saying “inspect only” explains your intention. Enforced permissions determine what CoCo can actually do.

**Native MCP is not a security boundary.** One approved call can start many steps. Check the actual arguments, connection, and directory before real work.

**AI Kit's read-only label is not enforcement on the reviewed Codex path.** Database and local restrictions must stand independently. Do not assume it behaves like the Claude integration.

**Results can enter Codex's provider context.** Use synthetic examples first and share only approved information. A local process connection does not keep the whole workflow local.

**Each native call starts independently.** Supply the relevant context each time. With AI Kit, resume the specific task's session rather than the last session globally.

**Timeouts do not undo work.** Check what completed before retrying, or the same change could happen twice.

## The One Thing to Remember

Delegate one job, enforce its limits, and check the evidence before calling it complete.

Ready to connect? [Start the native MCP walkthrough](README.md#recommended-native-mcp).

Using VS Code directly? [Install the official Snowflake extension](https://marketplace.visualstudio.com/items?itemName=snowflake.snowflake-vsc).

> For the full technical details, see the source document.
