# Migrate from PAT to Key-Pair JWT Authentication

Step-by-step recipes for switching an existing Snowflake agent project from Personal Access Token (PAT) authentication to RSA key-pair JWT authentication.

**Use key-pair JWT when:**

| Scenario | PAT | Key-Pair JWT |
|----------|-----|-------------|
| Quick testing and dev | Recommended | Works |
| Service accounts (no human login) | Not ideal | Recommended |
| CI/CD pipelines | Requires token rotation | Recommended |
| No-password security policies | May not comply | Compliant |
| Key rotation requirements | Manual regeneration | Standard RSA rotation |
| Long-running backend services | Token may expire | Auto-refreshed (1h, cached) |

---

## Prerequisites (All Recipes)

### 1. Generate RSA Key Pair

```bash
openssl genrsa -out rsa_key.pem 2048
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
```

### 2. Get Public Key Content (Without Header/Footer)

```bash
grep -v "BEGIN\|END" rsa_key.pub | tr -d '\n'
```

### 3. Assign Public Key to Snowflake User

```sql
USE ROLE ACCOUNTADMIN;
ALTER USER MY_SERVICE_USER SET RSA_PUBLIC_KEY='MIIBIjANBgkqhki...';

-- Verify
DESC USER MY_SERVICE_USER;
-- Look for RSA_PUBLIC_KEY_FP (should be populated)
```

### 4. Verify with Snow CLI (Optional)

```bash
snow connection test \
  --account myorg-myaccount \
  --user MY_SERVICE_USER \
  --private-key-path rsa_key.pem
```

---

## Recipe 1: Node.js / Express Backend

Targets the PAT pattern used in [`demo-agent-multicontext/backend/server.js`](../demo-agent-multicontext/backend/server.js) and similar Express backends.

### Step 1: Copy the JWT Module

Copy [`agent_run_keypair_jwt.js`](agent_run_keypair_jwt.js) into your project. It has zero external dependencies (uses Node.js built-in `crypto`).

```bash
cp guide-api-agent-context/agent_run_keypair_jwt.js my-project/
```

### Step 2: Replace Environment Variables

**Before (PAT):**
```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="ver:1-hint:abc..."
```

**After (Key-Pair JWT):**
```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_USER="MY_SERVICE_USER"
export SNOWFLAKE_PRIVATE_KEY_PATH="./rsa_key.pem"
```

### Step 3: Update server.js

**Before (PAT):**
```javascript
const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_PAT = process.env.SNOWFLAKE_PAT;

if (!SNOWFLAKE_ACCOUNT || !SNOWFLAKE_PAT) {
  console.error('Required env vars: SNOWFLAKE_ACCOUNT, SNOWFLAKE_PAT');
  process.exit(1);
}

// ... in each route handler:
const headers = {
  Authorization: `Bearer ${SNOWFLAKE_PAT}`,
  'Content-Type': 'application/json',
};
```

**After (Key-Pair JWT):**
```javascript
const fs = require('fs');
const { getJwt, buildHeaders } = require('./agent_run_keypair_jwt');

const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_USER = process.env.SNOWFLAKE_USER;
const PRIVATE_KEY = fs.readFileSync(process.env.SNOWFLAKE_PRIVATE_KEY_PATH, 'utf8');

if (!SNOWFLAKE_ACCOUNT || !SNOWFLAKE_USER || !PRIVATE_KEY) {
  console.error('Required env vars: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH');
  process.exit(1);
}

// ... in each route handler:
const jwt = getJwt(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, PRIVATE_KEY);
const headers = buildHeaders(jwt);
```

### Step 4: Update Each Route

Every route that calls Snowflake needs the same change. Here is the thread-creation route as an example.

**Before:**
```javascript
app.post('/api/agent/thread', async (_req, res) => {
  const response = await fetch(`${BASE_URL}/api/v2/cortex/threads`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${SNOWFLAKE_PAT}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ origin_application: 'my_app' }),
  });
  // ...
});
```

**After:**
```javascript
app.post('/api/agent/thread', async (_req, res) => {
  const jwt = getJwt(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, PRIVATE_KEY);
  const response = await fetch(`${BASE_URL}/api/v2/cortex/threads`, {
    method: 'POST',
    headers: buildHeaders(jwt),
    body: JSON.stringify({ origin_application: 'my_app' }),
  });
  // ...
});
```

For routes that also set `X-Snowflake-Role`:

```javascript
const jwt = getJwt(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, PRIVATE_KEY);
const headers = buildHeaders(jwt);
if (role) headers['X-Snowflake-Role'] = role;
```

### What `buildHeaders()` Returns

```javascript
{
  'Authorization': 'Bearer <jwt_token>',
  'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT',
  'Content-Type': 'application/json',
}
```

The `getJwt()` function caches the token and auto-refreshes 5 minutes before the 1-hour expiry.

---

## Recipe 2: Python Backend

Targets the pattern in [`agent_run_with_context.py`](agent_run_with_context.py).

### Step 1: Install Dependency

```bash
pip install cryptography
```

### Step 2: Replace Environment Variables

**Before:**
```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="ver:1-hint:abc..."
```

**After:**
```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_USER="MY_SERVICE_USER"
export SNOWFLAKE_PRIVATE_KEY_PATH="./rsa_key.pem"
```

### Step 3: Use `agent_run_with_context.py` Directly

The script already supports all three auth methods. Just set the env vars above and run:

```bash
python agent_run_with_context.py
```

It auto-detects: PAT > Key-Pair JWT > OAuth (in priority order).

### Step 4: Or Import into Your Own Code

```python
from agent_run_keypair_jwt import get_jwt, _build_headers

private_key_pem = open("rsa_key.pem", "rb").read()
jwt = get_jwt("myorg-myaccount", "MY_SERVICE_USER", private_key_pem)
headers = _build_headers(jwt)

# Use headers in your requests
response = requests.post(url, headers=headers, json=payload, stream=True)
```

---

## Recipe 3: curl Quick Test

Verify your key setup works before modifying application code.

### Generate a JWT from the Command Line

This uses `openssl` and Python (both pre-installed on macOS/Linux):

```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_USER="MY_SERVICE_USER"
export SNOWFLAKE_PRIVATE_KEY_PATH="./rsa_key.pem"

# Generate JWT using the standalone script
JWT=$(python agent_run_keypair_jwt.py 2>/dev/null | head -1)

# Or if you just want to test connectivity:
python agent_run_keypair_jwt.py
```

### Use the JWT in a curl Call

```bash
# Create a thread
THREAD_ID=$(curl -s -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads" \
  -H "Authorization: Bearer ${JWT}" \
  -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  -H "Content-Type: application/json" \
  -d '{"origin_application": "jwt_test"}' | jq -r '.id')

echo "Thread: $THREAD_ID"

# Call an agent
curl -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/MYDB/schemas/MYSCHEMA/agents/my_agent:run" \
  -H "Authorization: Bearer ${JWT}" \
  -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Role: ANALYST_ROLE" \
  -d '{
    "thread_id": "'"$THREAD_ID"'",
    "parent_message_id": 0,
    "messages": [{"role": "user", "content": [{"type": "text", "text": "Hello"}]}]
  }' --no-buffer
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `401 Unauthorized` | Missing `X-Snowflake-Authorization-Token-Type` header | Add `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT` to every request |
| `401 Unauthorized` | Public key not assigned | Run `DESC USER <user>` and check `RSA_PUBLIC_KEY_FP` is populated |
| `401 Unauthorized` | Account format wrong in JWT | Must be UPPERCASE with dots replaced by hyphens (e.g., `MYORG-MYACCOUNT`) |
| `JWT token is invalid` | Key-pair mismatch | The public key in Snowflake must match the private key used for signing |
| `Invalid key format` | Wrong PEM format or extra whitespace | Ensure standard PEM with valid PKCS#8 header/footer lines |
| Works in curl but not in app | Env var not loaded | Check `SNOWFLAKE_PRIVATE_KEY_PATH` points to the correct file |

## References

- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth) -- Snowflake setup guide
- [REST API Authentication](https://docs.snowflake.com/en/developer-guide/sql-api/authenticating) -- JWT token format
- [`agent_run_keypair_jwt.js`](agent_run_keypair_jwt.js) -- Node.js implementation (zero dependencies)
- [`agent_run_keypair_jwt.py`](agent_run_keypair_jwt.py) -- Python implementation (`cryptography` library)
