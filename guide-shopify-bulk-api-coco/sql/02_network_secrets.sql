/* Shopify Bulk API + CoCo — external access and secret pattern
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-12-03

   Run the object setup once. Create one PASSWORD secret per store interactively;
   never put the Client ID or Client Secret in this file or chat. */

USE ROLE ACCOUNTADMIN;

CREATE NETWORK RULE IF NOT EXISTS SHOPIFY_NATIVE.CONTROL.SHOPIFY_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('*.myshopify.com:443', 'storage.googleapis.com:443')
  COMMENT = 'Shopify Admin API and Bulk Operation result downloads';

-- Stop here. Create every store secret in private worksheet input, then run
-- tools/generate_store_bindings.py. Its output creates the EAI only after all
-- referenced secrets exist. This avoids an undeployable placeholder reference.

/* In a private worksheet, create a TYPE=PASSWORD Snowflake secret named
SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS. Enter the Shopify
Client ID as its username and the Shopify Client Secret as its password.
Do not save that statement in this repository or send the values through chat.

Then grant SHOPIFY_PIPELINE_RL READ on the secret and verify only its metadata:

DESC SECRET SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS;

DESC never returns the password value. */
