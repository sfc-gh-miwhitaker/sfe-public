#!/usr/bin/env bash
# curl examples for Anthropic direct vs Cortex redirect.
#
# Prerequisites:
#   export ANTHROPIC_API_KEY="sk-ant-..."  # pragma: allowlist secret
#   export SNOWFLAKE_ACCOUNT="myorg-myaccount"
#   export SNOWFLAKE_PAT="ver:1:..."
#
# Usage:
#   bash curl_examples.sh

set -euo pipefail

PROMPT="Explain how a snowflake forms in exactly two sentences."
MODEL="claude-sonnet-4-5"

echo "============================================================"
echo "  1. Anthropic Direct"
echo "============================================================"

curl -s "https://api.anthropic.com/v1/messages" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "'"${MODEL}"'",
    "max_tokens": 256,
    "messages": [
      {"role": "user", "content": "'"${PROMPT}"'"}
    ]
  }' | python3 -m json.tool

echo ""
echo "============================================================"
echo "  2. Cortex Redirect"
echo "============================================================"
echo "  Endpoint: ${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com"
echo ""

curl -s "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/v1/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "'"${MODEL}"'",
    "max_tokens": 256,
    "messages": [
      {"role": "user", "content": "'"${PROMPT}"'"}
    ]
  }' | python3 -m json.tool

echo ""
echo "============================================================"
echo "  Comparison"
echo "============================================================"
echo "  Request body: IDENTICAL"
echo "  Auth header:  x-api-key (Anthropic) vs Authorization: Bearer (Cortex)"
echo "  Endpoint:     api.anthropic.com vs ${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com"
