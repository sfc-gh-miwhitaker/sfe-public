-- Table structures only. Data seeding runs as a post-hook script
-- since DCM definition files cannot contain DML (INSERT/MERGE).

DEFINE TABLE {{db}}.{{schema}}.PRICING_CURRENT (
    SERVICE_TYPE STRING    NOT NULL,
    CLOUD        STRING    NOT NULL,
    REGION       STRING    NOT NULL,
    UNIT         STRING    NOT NULL,
    RATE         NUMBER(10,4) NOT NULL,
    CURRENCY     STRING    DEFAULT 'CREDITS',
    UPDATED_AT   TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY   STRING    DEFAULT CURRENT_USER(),
    CONSTRAINT pk_pricing PRIMARY KEY (SERVICE_TYPE, CLOUD, REGION, UNIT)
) COMMENT = 'TOOL: Replication pricing rates (BC baseline) - Expires: {{expiration_date}}';
