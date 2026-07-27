/*==============================================================================
CI/CD SERVICE USER — GitHub Actions OIDC Authentication
Pair-programmed by SE Community + Cortex Code

PURPOSE:
  Creates a service user that GitHub Actions authenticates as via OIDC
  workload identity federation. No secrets, keys, or passwords stored in GitHub.

PREREQUISITES:
  - USERADMIN or ACCOUNTADMIN role
  - Account administrator setup for Snowflake App Runtime
    (so snow app deploy lands in a shared database)

RUN ONCE per account. This is NOT part of deploy_all.sql.
==============================================================================*/

USE ROLE USERADMIN;

-- Service user trusted by GitHub's OIDC provider
CREATE USER IF NOT EXISTS SFE_GITHUB_DEPLOY
  TYPE = SERVICE
  COMMENT = 'GitHub Actions CI/CD for Snowflake App Runtime deploys (OIDC)'
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:sfc-gh-miwhitaker/sfe-public:ref:refs/heads/main'
  );

-- Grant deploy privileges
USE ROLE SECURITYADMIN;
GRANT ROLE SYSADMIN TO USER SFE_GITHUB_DEPLOY;

-- Verify
DESCRIBE USER SFE_GITHUB_DEPLOY;
