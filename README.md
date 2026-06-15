![Projects](https://img.shields.io/badge/Projects-2-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake guides for connecting AI coding assistants to Snowflake. Every project includes an `AGENTS.md` file that works with AI coding assistants ([Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Cursor](https://www.cursor.com/)) to guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

## Projects

### Guides and References

| Directory | Description | Features |
|---|---|---|
| [guide-connecting-claude-snowflake](guide-connecting-claude-snowflake/) | Connect Claude to Snowflake: MCP OAuth, Entra ID External OAuth, and Cortex Code plugin with profiles and experience shaping | MCP, External OAuth, Entra ID, Cortex Code Plugin, Profiles |
| [guide-vscode-copilot-cortex](guide-vscode-copilot-cortex/) | Connect VS Code GitHub Copilot to Snowflake Cortex: managed MCP for Copilot Chat, subagent skill for Copilot CLI, Cortex Code CLI in the integrated terminal | Snowflake MCP, OAuth, PAT, subagent-cortex-code, Cortex Code CLI |

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
