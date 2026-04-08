/******************************************************************************
 * DCM Post-Hook: Seed PRICING_CURRENT
 * Idempotent -- only inserts rows that don't already exist.
 * DCM manages the table structure; this script manages the data.
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

MERGE INTO PRICING_CURRENT AS tgt
USING (
    SELECT column1 AS SERVICE_TYPE, column2 AS CLOUD, column3 AS REGION,
           column4 AS UNIT, column5 AS RATE, column6 AS CURRENCY
    FROM VALUES
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
        ('HYBRID_STORAGE',      'GCP',   'asia-southeast1',  'GB_MONTH', 0.065, 'CREDITS')
) AS src
ON  tgt.SERVICE_TYPE = src.SERVICE_TYPE
AND tgt.CLOUD        = src.CLOUD
AND tgt.REGION       = src.REGION
AND tgt.UNIT         = src.UNIT
WHEN NOT MATCHED THEN INSERT (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY)
    VALUES (src.SERVICE_TYPE, src.CLOUD, src.REGION, src.UNIT, src.RATE, src.CURRENCY);
