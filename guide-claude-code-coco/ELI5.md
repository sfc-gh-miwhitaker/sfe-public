# Claude Leads, CoCo Handles the Snowflake Assignment

> Simplified from: [Use Claude Code with CoCo for Snowflake Work](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Keep Claude Code in charge and use the Snowflake plugin to give CoCo a specific Snowflake assignment.

## The Story

Think of renovating a house. The contractor coordinates the project, while an electrician handles one electrical job. You would not ask both to rebuild the same wall.

Claude is the contractor. CoCo is the Snowflake specialist. Snowflake AI Kit supplies a plugin that helps Claude recognize Snowflake requests and pass them to CoCo.

Start with that plugin for recurring delegation. You can also select its `cortex-run` skill to hand over a task explicitly. Automatic routing is a convenience, not permission to change things.

If you simply want CoCo in Microsoft Visual Studio Code, start with the official Snowflake extension instead. Sign in and open its CoCo panel. You do not need the delegation setup or a separate CoCo CLI installation for that editor path.

## The Cast

- **Claude Code:** The assistant responsible for the overall project and final review.
- **CoCo:** The assistant receiving the Snowflake assignment.
- **AI Kit plugin:** The package that helps Claude route Snowflake work to CoCo.
- **MCP:** A standard tool connection; an alternative to the plugin, not a prerequisite.
- **Handoff:** The assignment, permitted actions, relevant context, and expected evidence.
- **Access controls:** Enforced limits on database actions, files, and other resources.

## What Changes

- You can request Snowflake help without leaving Claude's conversation.
- Claude keeps the application work; CoCo receives one clearly scoped assignment.
- You send relevant context instead of the whole conversation.
- You review a proposal before authorizing changes.

For example, an order with two items can accidentally have its revenue counted twice. Give CoCo synthetic numbers first and check its explanation. Nobody needs production rows or deployment permission to explain that mistake.

## What to Watch Out For

**An assignment is not a key.** Saying “inspect only” explains your intention. Enforced permissions determine what CoCo can actually do.

**The plugin is not a complete security boundary.** Its reviewed Claude path checks tool permissions, but those checks do not replace database restrictions or local isolation. Approval configuration does not guarantee an interactive prompt for every action.

**One approval can start many steps.** Inspect the scope and effective connection before real work. Never enable broad bypass just to fix a stalled request.

**Results can enter Claude's provider context.** Use synthetic examples first and share only approved information. A local process connection does not keep the whole workflow local.

**Follow-ups need the right history.** Resume the specific plugin session for this task, not whichever session ran last. Native MCP calls are independent.

**Timeouts do not undo work.** Check what completed before retrying, or the same change could happen twice.

## The One Thing to Remember

Let the plugin help route work, but enforce limits and check evidence yourself.

Ready to connect? [Start the AI Kit walkthrough](README.md#recommended-ai-kit-plugin).

Using VS Code directly? [Install the official Snowflake extension](https://marketplace.visualstudio.com/items?itemName=snowflake.snowflake-vsc).

> For the full technical details, see the source document.
