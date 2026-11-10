/*==============================================================================
  Strong Auth Network Policies | 99 Teardown
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  Removes ONLY the practice objects from script 00. It never touches your
  real users, your rules from script 03, or any account-level policy.
  The shared SNOWFLAKE_EXAMPLE database is preserved.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- A policy cannot be dropped while a user still references it.
ALTER USER IF EXISTS SFE_NETPOL_PRACTICE_SVC UNSET NETWORK_POLICY;
DROP USER IF EXISTS SFE_NETPOL_PRACTICE_SVC;
DROP NETWORK POLICY IF EXISTS SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE;
DROP ROLE IF EXISTS SFE_NETPOL_PRACTICE_ROLE;

SELECT 'Practice objects removed' AS status;
