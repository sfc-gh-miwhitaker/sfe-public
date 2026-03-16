-- ============================================================================
-- Project-specific objects for coco-governance-github
-- Inherits role, warehouse, and database context from deploy_all.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB
    COMMENT = 'DEMO: coco-governance-github - GitHub-powered project tooling for Cortex Code (Expires: 2026-04-15)';

USE SCHEMA SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;

-- ---------------------------------------------------------------------------
-- Sample tables -- give Cortex Code something real to write queries against
-- so the AGENTS.md standards and SQL review skill can be tested.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS CUSTOMERS (
    CUSTOMER_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    FULL_NAME VARCHAR(200) NOT NULL,
    EMAIL VARCHAR(300),
    REGION VARCHAR(50),
    SIGNUP_DATE DATE,
    TIER VARCHAR(20) DEFAULT 'standard'
)
COMMENT = 'DEMO: coco-governance-github - Sample customer dimension (Expires: 2026-04-15)';

CREATE TABLE IF NOT EXISTS PRODUCTS (
    PRODUCT_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    PRODUCT_NAME VARCHAR(200) NOT NULL,
    CATEGORY VARCHAR(100),
    UNIT_PRICE NUMBER(10,2),
    IS_ACTIVE BOOLEAN DEFAULT TRUE
)
COMMENT = 'DEMO: coco-governance-github - Sample product dimension (Expires: 2026-04-15)';

CREATE TABLE IF NOT EXISTS ORDERS (
    ORDER_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    CUSTOMER_ID NUMBER NOT NULL,
    PRODUCT_ID NUMBER NOT NULL,
    ORDER_DATE DATE NOT NULL,
    QUANTITY NUMBER DEFAULT 1,
    TOTAL_AMOUNT NUMBER(12,2),
    STATUS VARCHAR(20) DEFAULT 'pending'
)
COMMENT = 'DEMO: coco-governance-github - Sample order fact table (Expires: 2026-04-15)';

-- ---------------------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------------------

INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, REGION, SIGNUP_DATE, TIER)
SELECT column1, column2, column3, column4::DATE, column5
FROM VALUES
    ('Ada Lovelace',    'ada@example.com',    'EMEA',   '2024-03-15', 'enterprise'),
    ('Grace Hopper',    'grace@example.com',  'NA',     '2024-06-01', 'standard'),
    ('Alan Turing',     'alan@example.com',   'EMEA',   '2024-09-20', 'enterprise'),
    ('Linus Torvalds',  'linus@example.com',  'NA',     '2025-01-10', 'standard'),
    ('Margaret Hamilton','margaret@example.com','APAC',  '2025-04-05', 'premium');

INSERT INTO PRODUCTS (PRODUCT_NAME, CATEGORY, UNIT_PRICE, IS_ACTIVE)
SELECT column1, column2, column3, column4
FROM VALUES
    ('Compute Credits',   'Infrastructure', 3.00,  TRUE),
    ('Storage (TB/mo)',   'Infrastructure', 23.00, TRUE),
    ('Cortex Tokens',     'AI/ML',         0.01,  TRUE),
    ('Serverless Credits','Infrastructure', 2.40,  TRUE);

INSERT INTO ORDERS (CUSTOMER_ID, PRODUCT_ID, ORDER_DATE, QUANTITY, TOTAL_AMOUNT, STATUS)
SELECT column1, column2, column3::DATE, column4, column5, column6
FROM VALUES
    (1, 1, '2025-01-15', 100,  300.00,  'completed'),
    (1, 3, '2025-01-15', 5000, 50.00,   'completed'),
    (2, 1, '2025-02-01', 50,   150.00,  'completed'),
    (2, 2, '2025-02-01', 2,    46.00,   'completed'),
    (3, 1, '2025-02-15', 200,  600.00,  'completed'),
    (3, 3, '2025-02-15', 20000,200.00,  'completed'),
    (4, 4, '2025-03-01', 75,   180.00,  'pending'),
    (5, 1, '2025-03-10', 150,  450.00,  'pending'),
    (5, 2, '2025-03-10', 5,    115.00,  'pending');
