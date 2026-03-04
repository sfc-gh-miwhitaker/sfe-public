#!/usr/bin/env node
/**
 * Key-Pair JWT authentication for the Snowflake agent:run API.
 *
 * Zero external dependencies -- uses only Node.js built-in `crypto`.
 * Suitable for service accounts, CI/CD, or any environment where
 * password/PAT auth is not available.
 *
 * Environment Variables:
 *   SNOWFLAKE_ACCOUNT          Account identifier (e.g. 'myorg-myaccount')
 *   SNOWFLAKE_USER             Snowflake username with RSA public key assigned
 *   SNOWFLAKE_PRIVATE_KEY_PATH Path to PEM-encoded RSA private key
 *
 * Snowflake setup (one-time):
 *   openssl genrsa -out rsa_key.pem 2048
 *   openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
 *   ALTER USER my_user SET RSA_PUBLIC_KEY='<pub key without header/footer>';
 *
 * See also:
 *   https://docs.snowflake.com/en/user-guide/key-pair-auth
 *   https://docs.snowflake.com/en/developer-guide/sql-api/authenticating
 */

const fs = require('fs');
const { createHash, createPublicKey, createSign } = require('crypto');

// ---------------------------------------------------------------------------
// JWT generation (no dependencies)
// ---------------------------------------------------------------------------

function normalizeAccount(account) {
  return account
    .trim()
    .replace('.snowflakecomputing.com', '')
    .replace(/\./g, '-')
    .toUpperCase();
}

function buildFingerprint(privateKeyPem) {
  const publicKeyDer = createPublicKey(privateKeyPem).export({
    type: 'spki',
    format: 'der',
  });
  return createHash('sha256').update(publicKeyDer).digest('base64');
}

function toBase64Url(input) {
  return Buffer.from(input).toString('base64url');
}

function signJwt({ account, user, privateKeyPem, expiresInSeconds = 3600 }) {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + expiresInSeconds;

  const normalizedAccount = normalizeAccount(account);
  const username = user.trim().toUpperCase();
  const qualified = `${normalizedAccount}.${username}`;

  const normalizedKey = privateKeyPem.replace(/\\n/g, '\n').trim();
  const fingerprint = buildFingerprint(normalizedKey);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: `${qualified}.SHA256:${fingerprint}`,
    sub: qualified,
    iat: now,
    exp,
  };

  const signingInput = `${toBase64Url(JSON.stringify(header))}.${toBase64Url(JSON.stringify(payload))}`;
  const signature = createSign('RSA-SHA256')
    .update(signingInput)
    .end()
    .sign(normalizedKey, 'base64url');

  return { token: `${signingInput}.${signature}`, exp };
}

// Token cache -- reuse until 5 minutes before expiry
let cachedJwt = null;

function getJwt(account, user, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.exp - 300 > now) {
    return cachedJwt.token;
  }
  cachedJwt = signJwt({ account, user, privateKeyPem });
  return cachedJwt.token;
}

// ---------------------------------------------------------------------------
// Snowflake helpers
// ---------------------------------------------------------------------------

function buildHeaders(jwt) {
  return {
    Authorization: `Bearer ${jwt}`,
    'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT',
    'Content-Type': 'application/json',
  };
}

async function createThread(account, jwt) {
  const url = `https://${account.trim()}.snowflakecomputing.com/api/v2/cortex/threads`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: buildHeaders(jwt),
    body: JSON.stringify({ origin_application: 'keypair_jwt_example' }),
  });
  if (!resp.ok) throw new Error(`Thread creation failed: ${resp.status} ${await resp.text()}`);
  const data = await resp.json();
  return data.id ?? data.thread_id;
}

async function runAgent({
  account, jwt, database, schema, agentName,
  threadId, message, role, warehouse,
}) {
  const base = `https://${account.trim()}.snowflakecomputing.com`;
  const url = `${base}/api/v2/databases/${database}/schemas/${schema}/agents/${agentName}:run`;

  const headers = buildHeaders(jwt);
  if (role) headers['X-Snowflake-Role'] = role;
  if (warehouse) headers['X-Snowflake-Warehouse'] = warehouse;

  const body = {
    thread_id: threadId,
    parent_message_id: 0,
    messages: [{ role: 'user', content: [{ type: 'text', text: message }] }],
  };

  console.log(`\n${'='.repeat(70)}`);
  console.log(`Agent:  ${database}.${schema}.${agentName}`);
  console.log(`Auth:   Key-Pair JWT`);
  if (role) console.log(`Role:   ${role}`);
  if (warehouse) console.log(`WH:     ${warehouse}`);
  console.log(`Q:      ${message}`);
  console.log(`${'='.repeat(70)}\n`);

  const resp = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  if (!resp.ok) throw new Error(`agent:run failed: ${resp.status} ${await resp.text()}`);

  const reader = resp.body.getReader();
  const decoder = new TextDecoder();
  let eventType = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const chunk = decoder.decode(value);
    for (const line of chunk.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.split(':')[1].trim();
      } else if (line.startsWith('data:')) {
        try {
          const data = JSON.parse(line.slice(5).trim());
          if (eventType === 'response.text.delta') {
            process.stdout.write(data.text || '');
          } else if (eventType === 'error') {
            console.error(`\n[ERROR] ${data.message || 'Unknown'}`);
          }
        } catch { /* skip non-JSON lines */ }
      }
    }
  }
  console.log();
}

// ---------------------------------------------------------------------------
// Exports (for use as a module in other projects)
// ---------------------------------------------------------------------------

module.exports = {
  normalizeAccount,
  buildFingerprint,
  signJwt,
  getJwt,
  buildHeaders,
};

// ---------------------------------------------------------------------------
// Main (when run directly)
// ---------------------------------------------------------------------------

async function main() {
  const account = process.env.SNOWFLAKE_ACCOUNT;
  const user = process.env.SNOWFLAKE_USER;
  const keyPath = process.env.SNOWFLAKE_PRIVATE_KEY_PATH;

  if (!account || !user || !keyPath) {
    console.error('Required environment variables:');
    console.error('  SNOWFLAKE_ACCOUNT          e.g. myorg-myaccount');
    console.error('  SNOWFLAKE_USER             e.g. MY_SERVICE_USER');
    console.error('  SNOWFLAKE_PRIVATE_KEY_PATH e.g. ./rsa_key.pem');
    process.exit(1);
  }

  const privateKeyPem = fs.readFileSync(keyPath, 'utf8');

  console.log('Generating key-pair JWT...');
  const jwt = getJwt(account, user, privateKeyPem);
  console.log('OK  JWT generated');

  console.log('Creating thread...');
  const threadId = await createThread(account, jwt);
  console.log(`OK  Thread: ${threadId}`);

  // --- Customize these to match your agent ---
  await runAgent({
    account,
    jwt,
    database: 'MYDB',
    schema: 'MYSCHEMA',
    agentName: 'my_agent',
    threadId,
    message: 'What were the top 5 products by revenue last month?',
    role: 'ANALYST_ROLE',
    warehouse: 'COMPUTE_WH',
  });
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
