/*
 * Cross-cloud account replication: target side (Azure)
 * Pair-programmed by SE Community + Cortex Code
 *
 * Run in the new AZURE account as ACCOUNTADMIN (the DR_ADMIN user from step 02).
 * Paste the two values printed at the end of 03_source_aws.sql into the SETs below.
 *
 * Creating the replica triggers the first full refresh automatically; after that the
 * 10-minute schedule from the primary takes over. No manual REFRESH is required.
 */

USE ROLE ACCOUNTADMIN;

SET FAILOVER_GROUP_PRIMARY = '<ORG>.<SOURCE_ACCOUNT>.ACCOUNT_FG';    -- from 03 output
SET CONNECTION_PRIMARY     = '<ORG>.<SOURCE_ACCOUNT>.PRIMARY_CONN';  -- from 03 output

-- Names must match the primary objects; derive them from the pasted values.
EXECUTE IMMEDIATE $$
BEGIN
  EXECUTE IMMEDIATE 'CREATE FAILOVER GROUP IF NOT EXISTS ' || SPLIT_PART($FAILOVER_GROUP_PRIMARY, '.', 3) ||
                    ' AS REPLICA OF ' || $FAILOVER_GROUP_PRIMARY;
  EXECUTE IMMEDIATE 'CREATE CONNECTION IF NOT EXISTS ' || SPLIT_PART($CONNECTION_PRIMARY, '.', 3) ||
                    ' AS REPLICA OF ' || $CONNECTION_PRIMARY;
  RETURN 'Secondary failover group and connection created; initial refresh started';
END;
$$;

-- Watch the initial refresh. Large accounts take hours; the phase moves to COMPLETED.
SELECT phase_name, start_time, end_time, job_uuid
  FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('ACCOUNT_FG'))
 ORDER BY start_time DESC
 LIMIT 10;
