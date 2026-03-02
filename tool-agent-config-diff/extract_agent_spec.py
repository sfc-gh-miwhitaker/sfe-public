#!/usr/bin/env python3
"""
Extract Cortex Agent Specification for Configuration Management

This script provides programmatic access to agent specs, working around
the limitations of the SQL API (no session variables, no RESULT_SCAN).

Usage:
    python extract_agent_spec.py SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN
    python extract_agent_spec.py SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN --format full
    python extract_agent_spec.py SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN --format spec_only
    python extract_agent_spec.py SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN --format export

Environment:
    SNOWFLAKE_CONNECTION_NAME: Connection name from ~/.snowflake/connections.toml
"""

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime

import snowflake.connector


def extract_agent_spec(conn, agent_fqn: str, output_format: str = "export") -> dict:
    """Extract agent specification from Snowflake."""
    cursor = conn.cursor()

    try:
        cursor.execute(f"DESC AGENT {agent_fqn}")
        row = cursor.fetchone()

        if not row:
            raise ValueError(f"Agent not found: {agent_fqn}")

        columns = [desc[0].lower() for desc in cursor.description]
        data = dict(zip(columns, row))

        spec_yaml = data.get("agent_spec", "")
        profile_str = data.get("profile", "")
        config_hash = hashlib.md5(
            (spec_yaml or "").encode() + (profile_str or "").encode()
        ).hexdigest()

        profile_json = None
        profile_valid = True
        if profile_str:
            try:
                profile_json = json.loads(profile_str)
            except json.JSONDecodeError:
                profile_valid = False

        if output_format == "full":
            return {
                "agent_name": data["name"],
                "agent_fqn": f"{data['database_name']}.{data['schema_name']}.{data['name']}",
                "owner": data["owner"],
                "comment": data.get("comment"),
                "profile_json": profile_json,
                "profile_status": "OK" if profile_valid else "INVALID_JSON",
                "spec_yaml": spec_yaml,
                "created_on": str(data["created_on"]),
                "config_hash": config_hash,
            }
        elif output_format == "spec_only":
            return {
                "spec_yaml": spec_yaml,
                "spec_hash": hashlib.md5((spec_yaml or "").encode()).hexdigest(),
            }
        else:  # export
            return {
                "extracted_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "agent_fqn": f"{data['database_name']}.{data['schema_name']}.{data['name']}",
                "config_hash": config_hash,
                "metadata": {
                    "name": data["name"],
                    "database": data["database_name"],
                    "schema": data["schema_name"],
                    "owner": data["owner"],
                    "comment": data.get("comment"),
                    "created_on": str(data["created_on"]),
                },
                "profile": profile_json,
                "profile_valid": profile_valid,
                "spec_yaml": spec_yaml,
            }
    finally:
        cursor.close()


def main():
    parser = argparse.ArgumentParser(
        description="Extract Cortex Agent specification from Snowflake"
    )
    parser.add_argument("agent_fqn", help="Fully qualified agent name (DB.SCHEMA.AGENT)")
    parser.add_argument(
        "--format",
        choices=["full", "spec_only", "export"],
        default="export",
        help="Output format (default: export)",
    )
    parser.add_argument(
        "--connection",
        default=os.getenv("SNOWFLAKE_CONNECTION_NAME", "default"),
        help="Snowflake connection name",
    )
    args = parser.parse_args()

    conn = snowflake.connector.connect(connection_name=args.connection)

    try:
        result = extract_agent_spec(conn, args.agent_fqn, args.format)
        print(json.dumps(result, indent=2, default=str))
    finally:
        conn.close()


if __name__ == "__main__":
    main()
