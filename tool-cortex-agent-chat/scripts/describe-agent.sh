#!/usr/bin/env bash
set -euo pipefail

# Helper script to describe a Snowflake Cortex Agent using the documented REST API.
# It can read configuration directly from the project .env.local file that powers the React client.
# Variables are resolved in the following order (first non-empty wins):
#   1. Explicit SNOWFLAKE_* environment variables (exported in the shell)
#   2. REACT_APP_SNOWFLAKE_* variables (from .env.local or the shell)
#   3. Script fails with a clear message if a required value is still missing

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env.local"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC2046
  set -o allexport
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +o allexport
fi

# Map React env vars to the shell variables used below if explicit overrides are not present
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-${REACT_APP_SNOWFLAKE_ACCOUNT:-}}"
SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-${REACT_APP_SNOWFLAKE_DATABASE:-}}"
SNOWFLAKE_SCHEMA="${SNOWFLAKE_SCHEMA:-${REACT_APP_SNOWFLAKE_SCHEMA:-}}"
SNOWFLAKE_AGENT="${SNOWFLAKE_AGENT:-${REACT_APP_CORTEX_AGENT_NAME:-${REACT_APP_SNOWFLAKE_AGENT:-}}}"
SNOWFLAKE_PAT="${SNOWFLAKE_PAT:-${REACT_APP_SNOWFLAKE_PAT:-}}"

: "${SNOWFLAKE_ACCOUNT:?SNOWFLAKE_ACCOUNT is required}"
: "${SNOWFLAKE_DATABASE:?SNOWFLAKE_DATABASE is required}"
: "${SNOWFLAKE_SCHEMA:?SNOWFLAKE_SCHEMA is required}"
: "${SNOWFLAKE_AGENT:?SNOWFLAKE_AGENT is required}"
: "${SNOWFLAKE_PAT:?SNOWFLAKE_PAT is required}"

account_host="${SNOWFLAKE_ACCOUNT}"
if [[ "${account_host}" != *.snowflakecomputing.com ]]; then
  account_host="${account_host}.snowflakecomputing.com"
fi

encode() {
  printf '%s' "$1" | jq -sRr @uri
}

endpoint="https://${account_host}/api/v2/databases/$(encode "${SNOWFLAKE_DATABASE}")/schemas/$(encode "${SNOWFLAKE_SCHEMA}")/agents/$(encode "${SNOWFLAKE_AGENT}")"

echo "Describing agent ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}.${SNOWFLAKE_AGENT}..." >&2

declare -a curl_cmd=(
  curl -sSL -X GET "${endpoint}"
  -H "Content-Type: application/json"
  -H "Accept: application/json"
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}"
)

"${curl_cmd[@]}" | jq '.'
