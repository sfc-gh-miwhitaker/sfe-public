# Authentication Options for the Cortex Redirect

The `ANTHROPIC_AUTH_TOKEN` that Claude Code sends to Snowflake as `Authorization: Bearer` can come from several sources. This page covers all of them, ranked by security posture.

> **Quick start:** If you just want to try the redirect, [get a PAT](#option-1-pat-quickest-start) and move on. Come back to this page when you're ready to harden auth for your team or stop storing a static token in your shell profile.

---

## Summary

| Option | Best for | Secret on disk? | Admin required? |
|--------|----------|-----------------|-----------------|
| [PAT via env var](#option-1-pat-quickest-start) | Getting started, any platform | Yes (in profile) | No |
| [PAT via OS credential store + `apiKeyHelper`](#option-2-apikeyhelper--os-credential-store) | Personal developer machines | No | No |
| [Key-Pair JWT via `apiKeyHelper`](#option-3-key-pair-jwt-via-apikeyhelper) | Service accounts, CI/CD | Private key only | No (key setup) |
| [CI/CD secrets](#option-4-cicd-and-cloud-environments) | GitHub Actions, cloud VMs | No | Platform-specific |
| [Claude Desktop OAuth](#option-5-claude-desktop-oauth) | Claude Desktop users | No | Snowflake admin |

---

## Option 1: PAT — Quickest Start

A Programmatic Access Token (PAT) is Snowflake's equivalent of an API key. It's the simplest path to a working redirect.

**Create a PAT in Snowsight:**

1. Click your username (top right) → **My Profile**
2. Scroll to **Programmatic access tokens** → **Generate new token**
3. Set a name, restrict it to a single role (recommended: `CORTEX_REST_API_ROLE` or equivalent), set a short expiry (90 days is reasonable), click **Generate**
4. Copy the token — it is shown only once

**Security tips for PATs:**
- Always restrict to a role — scope the token to `SNOWFLAKE.CORTEX_REST_API_USER` so it can't escalate to `ACCOUNTADMIN`
- Set a short expiry (90 days, not 1 year) and add a calendar reminder to rotate
- Issue one PAT per application/user — if one leaks, revoke only that one
- If you must store a PAT in a shell profile, ensure the profile file is `chmod 600`

**Usage:**

```bash
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
```

**Limitation:** Static token in a plaintext file. Use Option 2 instead if you want the token off disk.

---

## Option 2: `apiKeyHelper` + OS Credential Store

Claude Code has a built-in mechanism for dynamic credential retrieval: `apiKeyHelper`. Set it in `~/.claude/settings.json` and Claude Code will call that shell command to get the token instead of reading a static env var.

The token never lives in a config file. It's retrieved live from the OS-managed encrypted credential store.

> **Important:** `ANTHROPIC_AUTH_TOKEN` takes precedence over `apiKeyHelper` in Claude Code's auth chain. Don't set both — if you use `apiKeyHelper`, remove `ANTHROPIC_AUTH_TOKEN` from your shell profile.

### macOS — Keychain

Store the PAT in Keychain once:

```bash
security add-generic-password \
  -a snowflake-cortex-pat \
  -s cortex-redirect \
  -w "<your-snowflake-pat>"
```

Configure `apiKeyHelper` in `~/.claude/settings.json`. Create a one-line wrapper script first so the settings.json stays clean:

```bash
# Save as ~/.snowflake/get-cortex-token.sh and chmod +x
#!/bin/bash
security find-generic-password -a snowflake-cortex-pat -s cortex-redirect -w
```

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
  },
  "apiKeyHelper": "~/.snowflake/get-cortex-token.sh"
}
```

### Windows — Credential Manager

Store the PAT once (PowerShell):

```powershell
$cred = New-Object System.Management.Automation.PSCredential(
    "snowflake-cortex",
    (ConvertTo-SecureString "<your-snowflake-pat>" -AsPlainText -Force)
)
$cred | Export-Clixml "$env:APPDATA\snowflake-cortex.xml"
```

Configure `apiKeyHelper`. Create a wrapper script:

```powershell
# Save as C:\Users\<you>\.snowflake\get-cortex-token.ps1
(Import-Clixml "$env:APPDATA\snowflake-cortex.xml").GetNetworkCredential().Password
```

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
  },
  "apiKeyHelper": "powershell -File %USERPROFILE%\\.snowflake\\get-cortex-token.ps1"  // pragma: allowlist secret
}
```

### Linux — `pass` or `secret-tool`

```bash
# Store with pass
pass insert snowflake/cortex-pat
# or with secret-tool (GNOME Keyring)
secret-tool store --label="Snowflake Cortex PAT" service cortex-redirect username snowflake-cortex-pat
```

```bash
# Save as ~/.snowflake/get-cortex-token.sh and chmod +x
#!/bin/bash
pass show snowflake/cortex-pat
# or: secret-tool lookup service cortex-redirect username snowflake-cortex-pat
```

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
  },
  "apiKeyHelper": "~/.snowflake/get-cortex-token.sh"
}
```

### Token caching

By default, Claude Code caches the `apiKeyHelper` output for the duration of the session. To control how long it's cached:

```bash
export CLAUDE_CODE_API_KEY_HELPER_TTL_MS=3600000  # 1 hour in milliseconds
```

---

## Option 3: Key-Pair JWT via `apiKeyHelper`

This is the gold standard for service accounts and automation. Your RSA private key lives on disk; a JWT is generated fresh for each session and expires in 59 minutes. No static secret ever leaves your machine.

**Concept:** Claude Code calls `apiKeyHelper`, which runs a script that signs a fresh JWT using your private key. The JWT is passed as the bearer token to Snowflake. Snowflake verifies the signature against the public key you registered.

### Setup

**Step 1 — Generate an RSA key pair:**

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ~/.snowflake/rsa_key.p8 -nocrypt
openssl rsa -in ~/.snowflake/rsa_key.p8 -pubout -out ~/.snowflake/rsa_key.pub
chmod 600 ~/.snowflake/rsa_key.p8
```

> For production: add a passphrase and store the key in a secrets manager. The `-nocrypt` flag skips the passphrase for convenience in development.

**Step 2 — Register the public key with your Snowflake user:**

```sql
-- In Snowflake: strip the header/footer/newlines from rsa_key.pub and paste the body
ALTER USER <your-username> SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQE...';
```

Verify registration:

```sql
DESCRIBE USER <your-username>;  -- look for RSA_PUBLIC_KEY_FP
```

**Step 3 — Create a JWT generation script:**

Save as `~/.snowflake/generate_cortex_jwt.py`:

```python
#!/usr/bin/env python3
"""Generates a short-lived Snowflake JWT for Cortex REST API authentication.
Output is consumed by Claude Code's apiKeyHelper setting.
"""
import os, sys, time, hashlib, base64
from pathlib import Path
import jwt
from cryptography.hazmat.primitives.serialization import (
    load_pem_private_key, Encoding, PublicFormat,
)
from cryptography.hazmat.backends import default_backend

ACCOUNT      = os.environ["SNOWFLAKE_ACCOUNT"]   # e.g., "myorg-myaccount"
USER         = os.environ["SNOWFLAKE_USER"]
KEY_PATH     = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH",
                               str(Path.home() / ".snowflake/rsa_key.p8"))
JWT_LIFETIME = 3540  # 59 minutes (Snowflake max is 60)

account_upper  = ACCOUNT.upper().replace(".", "-")
user_upper     = USER.upper()
qualified_user = f"{account_upper}.{user_upper}"

pem         = Path(KEY_PATH).read_bytes()
private_key = load_pem_private_key(pem, password=None, backend=default_backend())
pub_der     = private_key.public_key().public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)
fingerprint = "SHA256:" + base64.b64encode(hashlib.sha256(pub_der).digest()).decode()

now = int(time.time())
payload = {
    "iss": f"{qualified_user}.{fingerprint}",
    "sub": qualified_user,
    "iat": now,
    "exp": now + JWT_LIFETIME,
}

print(jwt.encode(payload, private_key, algorithm="RS256"), end="")
```

Install the dependencies once:

```bash
pip install pyjwt cryptography
```

**Step 4 — Configure `apiKeyHelper`:**

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "SNOWFLAKE_ACCOUNT": "myorg-myaccount",
    "SNOWFLAKE_USER": "my_service_user"
  },
  "apiKeyHelper": "python3 ~/.snowflake/generate_cortex_jwt.py",  // pragma: allowlist secret
  "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "3540000"
}
```

Set the TTL to match the JWT lifetime (59 minutes = 3,540,000 ms) so Claude Code refreshes the token before it expires.

**What stays on disk:** only the RSA private key (`rsa_key.p8`). No token, no password, no PAT. The JWT is generated fresh on each helper call.

---

## Option 4: CI/CD and Cloud Environments

For automated pipelines, never use PATs or key files in environment variables. Use the platform's native secret mechanism.

**GitHub Actions:**

```yaml
- name: Run Claude Code task
  env:
    ANTHROPIC_BASE_URL: "https://${{ vars.SNOWFLAKE_ACCOUNT }}.snowflakecomputing.com/api/v2/cortex"
    ANTHROPIC_AUTH_TOKEN: ${{ secrets.SNOWFLAKE_PAT }}
  run: claude --print "summarize this codebase"
```

Store the PAT in GitHub Actions Secrets (not variables). It's encrypted at rest and never appears in logs.

**Workload Identity (cloud VMs — no stored credentials):**

For AWS EC2, Azure VMs, or GCP instances, use the platform's identity to exchange for a short-lived Snowflake token via [External OAuth with workload identity](https://docs.snowflake.com/en/user-guide/oauth-external). The compute identity proves itself; no secret is stored anywhere.

---

## Option 5: Claude Desktop OAuth

If you use **Claude Desktop** (not the `claude` CLI), Snowflake OAuth is available via the built-in third-party inference settings — no static credentials required.

> This is Claude Desktop's "Developer > Configure Third Party Inference" feature, not the CLI. Claude Code CLI does not yet support OAuth because Snowflake does not support dynamic client registration, which the CLI requires.

**Admin setup (Snowflake):**

```sql
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE SECURITY INTEGRATION claude_desktop_oauth
    TYPE = OAUTH
    OAUTH_CLIENT = CUSTOM
    OAUTH_CLIENT_TYPE = 'PUBLIC'
    OAUTH_REDIRECT_URI = 'http://127.0.0.1:63353/callback'
    ALLOWED_ROLES_LIST = ('CORTEX_REST_API_ROLE')
    OAUTH_USE_SECONDARY_ROLES = NONE
    OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE
    OAUTH_ENFORCE_PKCE = TRUE
    ENABLED = TRUE;

USE ROLE SECURITYADMIN;
GRANT USAGE ON INTEGRATION claude_desktop_oauth TO ROLE CORTEX_REST_API_ROLE;

-- Get the values you need for Claude Desktop:
DESCRIBE INTEGRATION CLAUDE_DESKTOP_OAUTH;
```

**Claude Desktop configuration:**

In **Developer > Configure Third Party Inference**:

| Field | Value |
|-------|-------|
| Connection | Gateway |
| Credential kind | Interactive sign-in |
| Gateway base URL | `https://<account>.snowflakecomputing.com/api/v2/cortex/anthropic` |
| Client ID | from `DESCRIBE INTEGRATION` (`OAUTH_CLIENT_ID`) |
| Authorization URL | from `DESCRIBE INTEGRATION` (`OAUTH_AUTHORIZATION_ENDPOINT`) |
| Token URL | from `DESCRIBE INTEGRATION` (`OAUTH_TOKEN_ENDPOINT`) |
| Bearer token | Access token |
| Scopes | `refresh_token session:role:CORTEX_REST_API_ROLE` |
| Append offline_access | **Off** — Snowflake does not accept this scope |
| Redirect port | `63353` |

Users authenticate once through the browser. Claude Desktop manages token refresh automatically.

> Source: [Powering Claude Desktop with Cortex Inference](https://medium.com/snowflake/powering-claude-desktop-with-cortex-inference-b024e3cb973d) — Snowflake Builders Blog, Chris Cardillo (June 2026)

---

## External References

- [Snowflake REST API Authentication](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/authentication) — PAT, Key-Pair JWT, OAuth
- [Three Options to Authenticate to the Cortex REST API](https://medium.com/snowflake/you-have-three-options-to-authenticate-to-the-cortex-rest-api-heres-how-each-one-works-cfede8c15aec) — Navnit Shukla, Snowflake Builders Blog (April 2026)
- [Generating a Programmatic Access Token](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [Snowflake OAuth Overview](https://docs.snowflake.com/en/user-guide/oauth-snowflake-overview)
