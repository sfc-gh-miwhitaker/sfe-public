/*==============================================================================
04_attach_cowork.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

When an account has a Snowflake CoWork object, an agent appears in CoWork only
after it is added to that object. Run as a role with MODIFY on the object
(ACCOUNTADMIN by default). Never fails the deploy: it reports what it did.
==============================================================================*/

EXECUTE IMMEDIATE $$
DECLARE
    si_count INTEGER DEFAULT 0;
    result   VARCHAR DEFAULT '';
BEGIN
    SHOW SNOWFLAKE INTELLIGENCES;
    SELECT COUNT(*) INTO :si_count
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "name" = 'SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT';

    IF (si_count = 0) THEN
        RETURN 'No CoWork object in this account: both agents already appear in CoWork for roles with USAGE.';
    END IF;

    BEGIN
        ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
            ADD AGENT SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.MEMBER_VALUE_AGENT;
        result := result || 'MEMBER_VALUE_AGENT added to CoWork. ';
    EXCEPTION
        WHEN OTHER THEN
            result := result || 'MEMBER_VALUE_AGENT not added (' || SQLERRM || '). ';
    END;

    BEGIN
        ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
            ADD AGENT SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.RAW_DATA_AGENT;
        result := result || 'RAW_DATA_AGENT added to CoWork.';
    EXCEPTION
        WHEN OTHER THEN
            result := result || 'RAW_DATA_AGENT not added (' || SQLERRM || '). If it is already attached, ignore this; otherwise run this file as ACCOUNTADMIN.';
    END;

    RETURN result;
END;
$$;
