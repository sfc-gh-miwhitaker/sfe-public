# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this repository, please report it responsibly:

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. Email the repository maintainers directly or use GitHub's private vulnerability reporting feature
3. Include a description of the issue, steps to reproduce, and any relevant context

We will acknowledge receipt within 48 hours and provide a timeline for remediation.

## Credential Hygiene

This repository is designed to contain **zero real credentials**. Every secret reference uses one of these safe patterns:

| Pattern | Example | Meaning |
|---|---|---|
| `<YOUR_...>` placeholder | `OAUTH_CLIENT_SECRET = '<YOUR_INTUIT_CLIENT_SECRET>'` | Replace with your value |
| Obvious fakes | `T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX` | Placeholder for Slack webhooks |
| Environment variables | `os.getenv("SNOWFLAKE_PASSWORD")` | Loaded at runtime, never stored |
| Snowflake secrets | `CREATE SECRET ... TYPE = OAUTH2` | Managed by Snowflake, not in code |
| `.env.example` templates | `SNOWFLAKE_ACCOUNT=your_account_here` | Template only; `.env` files gitignored |

### For Contributors

Before committing, verify that:

- [ ] No real passwords, API keys, tokens, or private keys are in your changes
- [ ] No Snowflake account identifiers (e.g., `xy12345.snowflakecomputing.com`) are hardcoded
- [ ] Credentials use environment variables, Snowflake secrets objects, or `<YOUR_...>` placeholders
- [ ] You have `pre-commit` installed and hooks are active (`pre-commit install`)

### Automated Protections

This repository implements multiple layers of secret detection:

| Layer | Tool | Scope |
|---|---|---|
| Pre-commit hook | [detect-secrets](https://github.com/Yelp/detect-secrets) | Blocks secrets before commit |
| Pre-commit hook | [gitleaks](https://github.com/gitleaks/gitleaks) | Second scanner for defense-in-depth |
| Pre-commit hook | `detect-private-key` | Blocks PEM/key file content |
| Pre-commit hook | Custom policy checks | Blocks `.env`, `.pem`, `.key`, `.p8` files |
| CI pipeline | GitHub Actions `security-scan` | Scans every push and PR |
| `.gitignore` | Repository-level | Prevents `.env`, `*.pem`, `*.key`, `*.p8` from staging |
| Global gitignore | Team-level | Additional coverage for team members |

### Setup for New Contributors

```bash
# Install pre-commit (one-time)
pip install pre-commit

# Activate hooks in your local clone
cd sfe-public
pre-commit install

# Verify hooks are working
pre-commit run --all-files
```

## Dependency Policy

- Pin dependency versions in `requirements.txt`, `package.json`, and `environment.yml`
- Review dependency updates before merging
- Use `npm audit` / `pip audit` periodically

## License

See individual project directories for applicable licenses.
