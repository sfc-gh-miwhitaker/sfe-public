-- Grants for DCM-managed objects only.
-- Grants on procedures, semantic views, and agent are in the post-hook
-- script (sql/99_grants/01_grants.sql) since those objects aren't DCM-managed.

GRANT USAGE ON DATABASE {{db}} TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA {{db}}.{{schema}} TO ROLE PUBLIC;
GRANT SELECT ON TABLE {{db}}.{{schema}}.PRICING_CURRENT TO ROLE PUBLIC;
GRANT SELECT ON VIEW {{db}}.{{schema}}.DB_METADATA_V2 TO ROLE PUBLIC;
GRANT SELECT ON VIEW {{db}}.{{schema}}.HYBRID_TABLE_METADATA TO ROLE PUBLIC;
GRANT SELECT ON VIEW {{db}}.{{schema}}.REPLICATION_HISTORY TO ROLE PUBLIC;
GRANT USAGE ON WAREHOUSE {{wh_name}} TO ROLE PUBLIC;
