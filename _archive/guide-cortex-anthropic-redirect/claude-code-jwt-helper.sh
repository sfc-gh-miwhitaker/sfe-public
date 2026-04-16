#!/usr/bin/env bash
# Claude Code apiKeyHelper script -- generates a Snowflake key-pair JWT
# and prints it to stdout for use as ANTHROPIC_AUTH_TOKEN.
#
# Configure in ~/.claude/settings.json:
#   { "apiKeyHelper": "/path/to/claude-code-jwt-helper.sh" }
#
# Required env vars:
#   SNOWFLAKE_ACCOUNT          your account identifier
#   SNOWFLAKE_USER             e.g. MY_SERVICE_USER
#   SNOWFLAKE_PRIVATE_KEY_PATH e.g. ./rsa_key.pem
#
# Also set:
#   CLAUDE_CODE_API_KEY_HELPER_TTL_MS=3300000  (refresh every ~55 min)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 -c "
import sys, os
sys.path.insert(0, os.path.join('${SCRIPT_DIR}', 'python'))
from snowflake_auth import generate_keypair_jwt

account  = os.environ['SNOWFLAKE_ACCOUNT']
user     = os.environ['SNOWFLAKE_USER']
key_path = os.environ['SNOWFLAKE_PRIVATE_KEY_PATH']

private_key_pem = open(key_path, 'rb').read()
token, _ = generate_keypair_jwt(account, user, private_key_pem)
print(token)
"
