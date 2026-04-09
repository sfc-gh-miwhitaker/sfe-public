/*==============================================================================
02 - Load Borrowers (Synthetic)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Middle-market companies across diverse industries.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

INSERT INTO RAW_BORROWERS (borrower_id, company_name, industry, annual_revenue, ebitda, employee_count, state, risk_rating, relationship_start)
VALUES
    ('B-001', 'Apex Manufacturing Corp',      'manufacturing',  85000000.00,  12750000.00, 340, 'OH', 2, '2019-03-15'),
    ('B-002', 'Meridian Health Systems',       'healthcare',    120000000.00,  18000000.00, 580, 'TX', 1, '2018-07-22'),
    ('B-003', 'Pinnacle Logistics Group',      'logistics',      62000000.00,   8060000.00, 210, 'GA', 3, '2020-01-10'),
    ('B-004', 'Veridian Technologies',         'technology',     45000000.00,   9000000.00, 125, 'CA', 2, '2021-05-18'),
    ('B-005', 'Ironbridge Energy Partners',    'energy',        200000000.00,  34000000.00, 420, 'TX', 1, '2017-11-03'),
    ('B-006', 'Cascade Paper & Packaging',     'manufacturing',  38000000.00,   4940000.00, 150, 'OR', 3, '2022-02-28'),
    ('B-007', 'Sterling Medical Devices',      'healthcare',     55000000.00,  11000000.00, 190, 'MA', 2, '2020-09-14'),
    ('B-008', 'Atlas Freight Solutions',        'logistics',      95000000.00,  12350000.00, 380, 'IL', 2, '2019-06-20'),
    ('B-009', 'Quantum Data Systems',          'technology',     28000000.00,   5600000.00,  85, 'WA', 3, '2023-01-05'),
    ('B-010', 'Heartland Grain Cooperative',   'agriculture',   150000000.00,  15000000.00, 260, 'IA', 2, '2018-04-12'),
    ('B-011', 'Pacific Rim Seafood Inc',       'food_processing', 72000000.00,  8640000.00, 290, 'AK', 3, '2021-08-30'),
    ('B-012', 'Summit Construction Group',     'construction',   110000000.00, 11000000.00, 450, 'CO', 2, '2019-12-01'),
    ('B-013', 'Redwood Environmental Services','environmental',   33000000.00,  5280000.00, 110, 'CA', 4, '2022-06-15'),
    ('B-014', 'Liberty Aerospace Components',  'manufacturing',   68000000.00, 10200000.00, 230, 'CT', 1, '2017-09-08'),
    ('B-015', 'Coastal Hospitality Group',     'hospitality',     88000000.00,  8800000.00, 620, 'FL', 3, '2020-03-22'),
    ('B-016', 'Northstar Chemical Corp',       'chemicals',       95000000.00, 15200000.00, 185, 'NJ', 2, '2019-01-17'),
    ('B-017', 'Keystone Auto Parts LLC',       'automotive',      42000000.00,  5460000.00, 175, 'MI', 4, '2021-11-09'),
    ('B-018', 'Bridgewater Real Estate Holdings','real_estate',   65000000.00, 26000000.00,  45, 'NY', 2, '2018-08-25'),
    ('B-019', 'Trident Defense Systems',       'defense',        180000000.00, 27000000.00, 510, 'VA', 1, '2016-05-30'),
    ('B-020', 'Clearwater Pharmaceuticals',    'healthcare',      35000000.00,  7000000.00,  95, 'NC', 3, '2023-04-18'),
    ('B-021', 'Horizon Renewable Energy',      'energy',          58000000.00,  8700000.00, 140, 'AZ', 2, '2022-10-01'),
    ('B-022', 'Great Lakes Plastics Inc',      'manufacturing',   47000000.00,  6110000.00, 200, 'WI', 3, '2021-02-14'),
    ('B-023', 'Vanguard IT Solutions',         'technology',      22000000.00,  4400000.00,  60, 'VA', 4, '2024-01-20'),
    ('B-024', 'Patriot Staffing Services',     'staffing',        82000000.00,  4920000.00, 140, 'PA', 3, '2020-07-11'),
    ('B-025', 'Evergreen Timber Products',     'forestry',        53000000.00,  7950000.00, 170, 'WA', 2, '2019-05-06');
