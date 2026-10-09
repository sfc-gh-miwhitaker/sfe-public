#!/usr/bin/env python3
"""Pair-programmed by SE Community + Cortex Code.

Print a Claude Desktop MCP fragment without reading or changing user config.
"""

import json
import shutil
import sys
from pathlib import Path


def build_config(executable, connection, workdir):
    if not executable:
        raise ValueError("CoCo was not found on PATH. Install the approved CLI and reopen your terminal.")
    executable_path = Path(executable).expanduser().resolve()
    if not executable_path.is_file():
        raise ValueError("The CoCo executable does not exist. Check your approved CLI installation.")
    connection = connection.strip()
    if not connection or connection.startswith("-") or any(ord(char) < 32 for char in connection):
        raise ValueError("Enter a nonempty connection name from cortex connections list, not a flag or credentials.")
    if not workdir.strip():
        raise ValueError("Enter an existing dedicated task directory; do not leave it blank.")
    directory = Path(workdir).expanduser().resolve()
    if not directory.is_dir():
        raise ValueError("The working directory does not exist. Create or choose an approved task folder first.")
    return {"mcpServers": {"coco-snowflake": {
        "command": str(executable_path),
        "args": ["mcp", "serve", "--connection", connection, "--workdir", str(directory)],
    }}}


def main():
    try:
        executable = shutil.which("cortex")
        if not executable:
            raise ValueError("CoCo was not found on PATH. Install the approved CLI and reopen your terminal.")
        print("Approved development connection name: ", end="", file=sys.stderr, flush=True)
        connection = input()
        print("Existing dedicated task directory: ", end="", file=sys.stderr, flush=True)
        workdir = input()
        config = build_config(executable, connection, workdir)
    except (ValueError, OSError, EOFError) as error:
        print(f"Cannot generate configuration: {error}", file=sys.stderr)
        return 1
    print(json.dumps(config, indent=2))
    print("Review and merge only this server entry; preserve existing Desktop settings.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
