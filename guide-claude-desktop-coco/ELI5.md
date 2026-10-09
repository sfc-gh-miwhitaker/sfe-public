# Claude Desktop Asks a Snowflake Specialist

> Simplified from: [Use Claude Desktop with CoCo for Snowflake Work](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Connect CoCo to Claude Desktop so you can request one Snowflake assignment and review its evidence in your chat.

## The Story

Think of talking to a project coordinator who calls an electrician for a specific problem. The coordinator explains the job and brings back the specialist's findings. You still decide whether to approve repairs.

Claude Desktop is the conversation with the coordinator. CoCo is the Snowflake specialist. MCP is the standard connection that lets Claude call CoCo as a tool.

Desktop starts CoCo on your computer using a small configuration file. The guide's helper prints the required settings from your chosen connection and folder. It does not change the file for you or read credentials.

This is not the Claude Code plugin workflow. If you want CoCo inside Microsoft's Visual Studio Code editor, use the official Snowflake extension instead.

## The Cast

- **Claude Desktop:** The application where you have the conversation and review results.
- **CoCo:** The assistant handling the specific Snowflake assignment.
- **MCP:** The connection that makes CoCo available as a tool.
- **Configuration:** The executable, approved connection name, and task folder Desktop uses to start CoCo.
- **Permissions:** Enforced limits on which files and database operations CoCo can access.

## What Changes

- Claude can ask CoCo for help without you moving the conversation to another app.
- CoCo receives the relevant assignment, not necessarily every attachment or previous message.
- You inspect a proposal before approving actual changes.
- A simple test confirms a response returned, without requesting database access.

For example, two items on one order can cause its revenue to be counted twice. Start with synthetic numbers and ask for an explanation. You do not need production rows to learn what went wrong.

## What to Watch Out For

**One approval can start many actions.** Approving Claude's call does not mean you will separately approve every step inside CoCo.

**The folder is not a locked room.** A working directory sets where work starts. It does not enforce which files the process can access.

**Local does not mean private to your computer.** Both assistants communicate with their services. Results returned to Claude can enter its provider context.

**Never share credentials.** The connection name refers to settings already on your computer. Do not copy passwords, keys, or connection-file contents into chat.

**A remembered conversation is not a remembered child session.** Each native CoCo call is independent; include the relevant context again.

**A timeout does not undo work.** Check what completed before retrying. If approval stalls, do not enable broad bypass to make it continue.

**Preserve existing configuration.** Merge only the new server entry and keep other servers. Restart Desktop after changing the file.

## The One Thing to Remember

Connect the specialist, assign one bounded job, and inspect the evidence before approving changes.

Ready to connect? [Follow the Desktop walkthrough](README.md#connect-claude-desktop).

> For the full technical details, see the source document.
