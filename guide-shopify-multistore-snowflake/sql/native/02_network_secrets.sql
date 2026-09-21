/*
  guide-shopify-multistore-snowflake — sql/native/02_network_secrets.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    External access and the per-store credential pattern.

    Run the network rule once. Create one PASSWORD secret per store
    interactively; never put a Client ID or Client Secret in this file, in a
    committed file, or in a chat prompt.

  WHY A WILDCARD RULE
    Unlike the Openflow path, which enumerates every store domain and must be
    ALTERed for each new store, this path allows *.myshopify.com once. The
    per-store boundary here is the secret and the EAI's
    ALLOWED_AUTHENTICATION_SECRETS list, not the host list.

  RUN AS      ACCOUNTADMIN
  SOURCE      https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access
              https://docs.snowflake.com/en/sql-reference/sql/create-secret
*/

USE ROLE ACCOUNTADMIN;

CREATE NETWORK RULE IF NOT EXISTS SHOPIFY_NATIVE.CONTROL.SHOPIFY_API_RULE
  MODE       = EGRESS
  TYPE       = HOST_PORT
  VALUE_LIST = ('*.myshopify.com:443', 'storage.googleapis.com:443')
  COMMENT    = 'Shopify Admin API and Bulk Operation result downloads';

/*
  STOP HERE.

  1. Create every store secret through private worksheet input. For each store,
     create a TYPE = PASSWORD secret whose USERNAME is the Shopify Client ID and
     whose PASSWORD is the Shopify Client Secret, named to match the
     CREDENTIAL_OBJECT_FQN you registered, for example:

       SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS

     Do not save that statement in this repository and do not paste the values
     into a prompt, an automation workspace, or a log.

  2. Then run tools/generate_store_bindings.py. Its output creates the EAI,
     grants READ on each secret, and MERGEs the credential FQNs into the shared
     registry. It is ordered that way on purpose: the EAI is created only after
     every secret it references exists, which avoids an undeployable
     placeholder reference.

  3. Verify metadata only. DESC never returns the password value:

       DESC SECRET SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS;

  Secret rotation replaces the secret in place; the procedure's SECRETS clause
  binds by name, so no redeployment is needed for a rotation. Adding a store
  does require regenerating the bindings, because the alias list is fixed at
  procedure creation time.
*/
