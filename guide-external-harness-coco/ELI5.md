# Two Coding Assistants, One Clear Assignment

> Simplified from: [Use Claude Code or Codex with CoCo for Snowflake Work](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Keep your usual coding assistant in charge, and give CoCo a specific Snowflake assignment with clear limits and proof of completion.

## The Story

Think of renovating a house. Your general contractor coordinates the project, while an electrician handles a specific electrical job. You do not ask both people to independently rebuild the same wall.

Claude Code or Codex can act as the contractor. CoCo can handle the Snowflake-specific assignment. The contractor gives CoCo the relevant requirements, then checks the returned work before integrating it.

You can explicitly call CoCo through MCP, a standard way for software assistants to use tools. Alternatively, Snowflake AI Kit helps route Snowflake requests automatically. Automatic routing saves effort, but it does not decide what access is safe.

An assignment is not the same as a key. Saying “inspect only” explains your intention. Database permissions and other enforced restrictions determine what the assistant can actually do.

## The Cast

- **Main assistant:** Claude Code or Codex, responsible for the overall project and final review.
- **CoCo:** The assistant receiving the Snowflake-specific assignment.
- **MCP:** The connection that lets your main assistant call CoCo as a tool.
- **AI Kit:** A plugin that helps detect and route Snowflake work.
- **Handoff:** The assignment, permitted actions, relevant context, and expected evidence.
- **Access controls:** Enforced limits on database actions, files, and other resources.

## A Small Example

You are building a daily sales report. One order has two items, so a careless join counts its revenue twice.

Keep the application work with your main assistant. Give CoCo the synthetic example and ask for the correct totals, an explanation, and checks.

Review its proposal before changing the real query. Nobody needs production rows or permission to deploy just to explain the problem.

## Why Use Two Assistants?

- Instead of changing tools for every question, you can delegate from your existing assistant.
- Instead of sharing the entire conversation, you can send only the context needed for one assignment.
- Instead of accepting “done,” you can require actual results, validation, and a list of changes.
- Instead of letting both assistants edit everything, you can give each a clear responsibility.

## What to Watch Out For

**The two host integrations differ.** AI Kit's reviewed Codex path automatically approves CoCo's inner tool calls and disables its external tool connections. Its “read-only” label does not enforce the same checks as the Claude path.

**Approval can cover many actions.** Approving one delegation can start a multi-step job. Agree on the scope before approving it.

**Your data can leave the database boundary.** Results returned to an external assistant can enter that provider's model context. Start with synthetic examples and share only approved information.

**A local connection does not make everything local.** The assistants still communicate with their respective services. Keep credentials and unrelated conversations out of handoffs.

**“Continue” needs the right history.** Native CoCo MCP calls are independent. With AI Kit, resume the specific session for your task, not whichever session ran last.

**A timeout does not undo work.** Check what completed before retrying. Otherwise, a repeated request could apply the same change twice.

**Proposals and execution are separate.** First ask what should change. Approve the exact change only after reviewing the proposal and its validation steps.

## The One Thing to Remember

Delegate a specific job, enforce its limits, and check the evidence before calling it complete.

Ready to connect? [Start the native MCP walkthrough](README.md#native-mcp-explicit-delegation).

> For the full technical details, see the source document.
