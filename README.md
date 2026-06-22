![Projects](https://img.shields.io/badge/Projects-3-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake guides for connecting AI coding assistants to Snowflake. Every project includes an `AGENTS.md` file that works with AI coding assistants ([Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Cursor](https://www.cursor.com/)) to guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

## Projects

### Guides and References

| Directory | Description | Features |
|---|---|---|
| [guide-connecting-claude-snowflake](guide-connecting-claude-snowflake/) | Post-Summit-26 guide to putting Claude in front of Snowflake: context over connection. Why raw text-to-SQL is ~24% accurate, how Horizon Context + Cortex Sense reach ~86%, CoWork/CoCo surfaces, Natoma governed MCP gateway; legacy OAuth/Entra MCP demoted | CoWork, CoCo, Cortex Sense, Horizon Context, Natoma, governed MCP |
| [guide-cowork-only-users](guide-cowork-only-users/) | Admin runbook for provisioning users with access to only Snowflake CoWork — no Snowsight, no SQL worksheets. Covers `CORTEX_AGENT_USER` role, `ALLOWED_INTERFACES`, CoWork object setup, single user and bulk provisioning scripts, verification, and access removal | CoWork, RBAC, ALLOWED_INTERFACES, bulk provisioning |
| [guide-vscode-copilot-cortex](guide-vscode-copilot-cortex/) | Connect VS Code GitHub Copilot to Snowflake Cortex: managed MCP for Copilot Chat, subagent skill for Copilot CLI, and the CoCo CLI (formerly Cortex Code) in the integrated terminal. Post-Summit-26, with the shared semantic-view accuracy foundation | Snowflake MCP, OAuth, PAT, subagent-cortex-code, CoCo CLI |

## Quick Start

### Develop with AI Assistance

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
cd sfe-public/<project-name>
```

Then open the project with your AI assistant of choice:
- **Cortex Code:** `cortex`
- **Claude Code:** `claude`
- **Cursor:** Open the folder in Cursor

Tell the AI: *"Help me get started with this project"*

Every project includes an `AGENTS.md` that any Claude-compatible tool reads automatically.

### Guides

Open the guide directory and follow the README.

## License

Apache License 2.0. See [LICENSE](LICENSE) and each project directory.
