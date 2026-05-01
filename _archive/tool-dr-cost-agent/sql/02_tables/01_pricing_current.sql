/******************************************************************************
 * DR Cost Agent - Pricing Table & Seed Data
 * Business Critical replication pricing rates (baseline estimates).
 * Admins can update via the cost_projection SPROC or direct SQL.
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

CREATE OR REPLACE TABLE PRICING_CURRENT (
    SERVICE_TYPE STRING    NOT NULL,
    CLOUD        STRING    NOT NULL,
    REGION       STRING    NOT NULL,
    UNIT         STRING    NOT NULL,
    RATE         NUMBER(10,4) NOT NULL,
    CURRENCY     STRING    DEFAULT 'CREDITS',
    UPDATED_AT   TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY   STRING    DEFAULT CURRENT_USER(),
    CONSTRAINT pk_pricing PRIMARY KEY (SERVICE_TYPE, CLOUD, REGION, UNIT)
) COMMENT = 'TOOL: Replication pricing rates (BC baseline) - Expires: 2026-05-01';

INSERT INTO PRICING_CURRENT (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY) VALUES
    -- AWS Regions
    ('DATA_TRANSFER',       'AWS',   'us-east-1',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'us-east-1',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'us-east-1',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'us-east-1',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'us-east-1',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'us-west-2',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'us-west-2',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'us-west-2',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'us-west-2',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'us-west-2',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'eu-west-1',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'eu-west-1',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'eu-west-1',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'eu-west-1',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'eu-west-1',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'ap-southeast-1',   'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'ap-southeast-1',   'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'ap-southeast-1',   'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'ap-southeast-1',   'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'ap-southeast-1',   'GB_MONTH', 0.06, 'CREDITS'),
    -- Azure Regions
    ('DATA_TRANSFER',       'AZURE', 'eastus2',          'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'eastus2',          'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'eastus2',          'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'eastus2',          'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'eastus2',          'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'westus2',          'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westus2',          'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'westus2',          'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'westus2',          'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'westus2',          'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'westeurope',       'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westeurope',       'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'westeurope',       'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'westeurope',       'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'westeurope',       'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'southeastasia',    'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'southeastasia',    'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'southeastasia',    'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'southeastasia',    'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'southeastasia',    'GB_MONTH', 0.07, 'CREDITS'),
    -- GCP Regions
    ('DATA_TRANSFER',       'GCP',   'us-central1',      'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'us-central1',      'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'us-central1',      'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'us-central1',      'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'us-central1',      'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'us-west1',         'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'us-west1',         'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'us-west1',         'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'us-west1',         'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'us-west1',         'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'europe-west1',     'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'europe-west1',     'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'europe-west1',     'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'europe-west1',     'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'europe-west1',     'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'asia-southeast1',  'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'asia-southeast1',  'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'asia-southeast1',  'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'asia-southeast1',  'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'asia-southeast1',  'GB_MONTH', 0.065, 'CREDITS');
