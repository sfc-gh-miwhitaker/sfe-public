/*==============================================================================
Snowflake Intelligence Brand Configurator -- Teardown
Pair-programmed by SE Community + Cortex Code | Expires: 2026-06-10

Removes the SI Brand Configurator tool and all supporting objects.
Does NOT remove branded agents the tool generated -- those have their own
teardown scripts produced by the tool itself.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR.SFE_SI_BRAND_CONFIGURATOR;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS SFE_BRAND_SCRAPER_EAI;

USE ROLE SYSADMIN;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_SI_BRAND_CONFIGURATOR CASCADE;
DROP WAREHOUSE IF EXISTS SFE_SI_BRAND_CONFIGURATOR_WH;

SELECT 'SI Brand Configurator teardown complete' AS status;
