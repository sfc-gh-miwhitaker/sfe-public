-- =============================================================================
-- 01_setup.sql — Minimal foundation for the agent-versioning example
-- Pair-programmed by SE Community + Cortex Code
--
-- Creates a tiny, self-contained world so the version lifecycle in the later
-- scripts has something real to run against: one warehouse, one small table,
-- and one semantic view that a Cortex Analyst tool can query.
--
-- Run order: 01 -> 02 -> 03 -> (04 optional, Git) -> 05 -> 06.  99 tears down.
-- Replace nothing: every identifier below is self-contained and safe to run.
-- =============================================================================

-- --- Warehouse (with a timeout guardrail) ------------------------------------
CREATE WAREHOUSE IF NOT EXISTS AGENT_VERSIONING_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'Compute for the Cortex Agent versioning example';

CREATE DATABASE IF NOT EXISTS AGENT_VERSIONING_DEMO
  COMMENT = 'Self-contained example for Cortex Agent versioning + GitHub';

USE DATABASE AGENT_VERSIONING_DEMO;
CREATE SCHEMA IF NOT EXISTS DEMO
  COMMENT = 'Objects for the agent-versioning walkthrough';

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- --- Sample data: a few orders across regions --------------------------------
CREATE OR REPLACE TABLE ORDERS (
  order_id    NUMBER(10,0)  NOT NULL,
  region      VARCHAR(20)   NOT NULL,
  amount      NUMBER(12,2)  NOT NULL,
  order_date  DATE          NOT NULL,
  CONSTRAINT pk_orders PRIMARY KEY (order_id)
);

INSERT INTO ORDERS (order_id, region, amount, order_date) VALUES
  (1, 'AMER', 1200.00, '2026-01-05'),
  (2, 'AMER',  850.50, '2026-01-11'),
  (3, 'EMEA',  430.00, '2026-02-02'),
  (4, 'EMEA', 1975.25, '2026-02-19'),
  (5, 'APJ',   610.75, '2026-03-08'),
  (6, 'APJ',  1340.00, '2026-03-22'),
  (7, 'AMER',  220.00, '2026-04-01'),
  (8, 'EMEA',  980.00, '2026-04-14');

-- --- Semantic view: what the Cortex Analyst tool will query ------------------
-- Small on purpose. The point of this guide is versioning the AGENT, not
-- semantic modeling — this view just gives the agent a real thing to answer.
CREATE OR REPLACE SEMANTIC VIEW ORDERS_SV
  TABLES (
    orders AS ORDERS PRIMARY KEY (order_id)
  )
  FACTS (
    orders.amount AS amount
  )
  DIMENSIONS (
    orders.region AS region,
    orders.order_date AS order_date
  )
  METRICS (
    orders.total_revenue AS SUM(orders.amount),
    orders.order_count AS COUNT(orders.order_id)
  )
  COMMENT = 'Tiny revenue model over ORDERS for the agent tool';

-- --- Verify -------------------------------------------------------------------
SELECT region, SUM(amount) AS revenue, COUNT(*) AS orders
FROM ORDERS
GROUP BY region
ORDER BY revenue DESC;

SHOW SEMANTIC VIEWS LIKE 'ORDERS_SV' IN SCHEMA AGENT_VERSIONING_DEMO.DEMO;
