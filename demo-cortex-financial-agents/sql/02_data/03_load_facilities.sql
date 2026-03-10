/*==============================================================================
03 - Load Facilities (Synthetic)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Credit facilities across five product types.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

INSERT INTO RAW_FACILITIES (facility_id, borrower_id, facility_type, origination_date, maturity_date, commitment_amount, outstanding_balance, interest_rate, advance_rate, ltv_ratio, status)
VALUES
    -- Apex Manufacturing: ABL + term loan
    ('F-2024-001', 'B-001', 'asset_based_line',         '2024-01-15', '2027-01-15', 15000000.00, 11200000.00, 8.250, 85.00, NULL,  'performing'),
    ('F-2024-002', 'B-001', 'term_loan',                '2024-01-15', '2029-01-15', 10000000.00,  8500000.00, 9.500, NULL,  72.00, 'performing'),

    -- Meridian Health: revolver + equipment
    ('F-2023-003', 'B-002', 'working_capital_revolver',  '2023-06-01', '2026-06-01', 20000000.00, 14000000.00, 7.750, NULL,  NULL,  'performing'),
    ('F-2024-004', 'B-002', 'equipment_finance',         '2024-03-10', '2029-03-10',  5000000.00,  4200000.00, 8.000, NULL,  65.00, 'performing'),

    -- Pinnacle Logistics: ABL (watchlist)
    ('F-2023-005', 'B-003', 'asset_based_line',         '2023-09-01', '2026-09-01', 12000000.00, 10800000.00, 9.000, 80.00, NULL,  'watchlist'),

    -- Veridian Tech: term loan
    ('F-2024-006', 'B-004', 'term_loan',                '2024-02-20', '2028-02-20',  8000000.00,  7200000.00, 10.000, NULL, 68.00, 'performing'),

    -- Ironbridge Energy: large revolver + bridge
    ('F-2022-007', 'B-005', 'working_capital_revolver',  '2022-11-15', '2027-11-15', 35000000.00, 22000000.00, 7.500, NULL,  NULL,  'performing'),
    ('F-2024-008', 'B-005', 'real_estate_bridge',        '2024-06-01', '2026-06-01', 25000000.00, 25000000.00, 11.500, NULL, 75.00, 'performing'),

    -- Cascade Paper: ABL (watchlist, high utilization)
    ('F-2023-009', 'B-006', 'asset_based_line',         '2023-04-15', '2026-04-15',  8000000.00,  7600000.00, 9.750, 82.00, NULL,  'watchlist'),

    -- Sterling Medical: equipment finance
    ('F-2024-010', 'B-007', 'equipment_finance',         '2024-05-01', '2029-05-01',  6000000.00,  5400000.00, 8.500, NULL,  60.00, 'performing'),

    -- Atlas Freight: ABL + term
    ('F-2023-011', 'B-008', 'asset_based_line',         '2023-03-01', '2026-03-01', 18000000.00, 13500000.00, 8.000, 85.00, NULL,  'performing'),
    ('F-2024-012', 'B-008', 'term_loan',                '2024-01-10', '2028-01-10',  7000000.00,  6300000.00, 9.250, NULL,  70.00, 'performing'),

    -- Quantum Data: term loan (watchlist -- startup risk)
    ('F-2024-013', 'B-009', 'term_loan',                '2024-04-01', '2028-04-01',  5000000.00,  4750000.00, 11.000, NULL, 78.00, 'watchlist'),

    -- Heartland Grain: large ABL
    ('F-2022-014', 'B-010', 'asset_based_line',         '2022-08-01', '2027-08-01', 25000000.00, 18000000.00, 7.250, 80.00, NULL,  'performing'),

    -- Pacific Rim Seafood: ABL + equipment
    ('F-2023-015', 'B-011', 'asset_based_line',         '2023-10-01', '2026-10-01', 10000000.00,  8500000.00, 8.750, 78.00, NULL,  'performing'),
    ('F-2024-016', 'B-011', 'equipment_finance',         '2024-02-15', '2029-02-15',  3000000.00,  2700000.00, 9.000, NULL,  62.00, 'performing'),

    -- Summit Construction: bridge + revolver
    ('F-2023-017', 'B-012', 'real_estate_bridge',        '2023-07-01', '2025-07-01', 20000000.00, 18500000.00, 12.000, NULL, 72.00, 'performing'),
    ('F-2024-018', 'B-012', 'working_capital_revolver',  '2024-01-01', '2027-01-01', 10000000.00,  6000000.00, 8.250, NULL,  NULL,  'performing'),

    -- Redwood Environmental: term loan (default)
    ('F-2023-019', 'B-013', 'term_loan',                '2023-05-01', '2027-05-01',  6000000.00,  5800000.00, 10.500, NULL, 85.00, 'default'),

    -- Liberty Aerospace: ABL
    ('F-2022-020', 'B-014', 'asset_based_line',         '2022-06-01', '2027-06-01', 12000000.00,  8400000.00, 7.500, 85.00, NULL,  'performing'),

    -- Coastal Hospitality: bridge (watchlist -- seasonal stress)
    ('F-2024-021', 'B-015', 'real_estate_bridge',        '2024-03-01', '2026-03-01', 15000000.00, 14500000.00, 12.500, NULL, 80.00, 'watchlist'),

    -- Northstar Chemical: revolver + term
    ('F-2023-022', 'B-016', 'working_capital_revolver',  '2023-01-15', '2026-01-15', 15000000.00, 10500000.00, 7.750, NULL,  NULL,  'performing'),
    ('F-2024-023', 'B-016', 'term_loan',                '2024-06-01', '2029-06-01',  8000000.00,  7200000.00, 9.000, NULL,  65.00, 'performing'),

    -- Keystone Auto Parts: ABL (default)
    ('F-2022-024', 'B-017', 'asset_based_line',         '2022-12-01', '2025-12-01',  7000000.00,  6800000.00, 10.250, 75.00, NULL,  'default'),

    -- Bridgewater Real Estate: bridge
    ('F-2024-025', 'B-018', 'real_estate_bridge',        '2024-04-15', '2026-04-15', 30000000.00, 28000000.00, 11.000, NULL, 70.00, 'performing'),

    -- Trident Defense: large term + revolver
    ('F-2021-026', 'B-019', 'term_loan',                '2021-08-01', '2028-08-01', 25000000.00, 17500000.00, 7.000, NULL,  55.00, 'performing'),
    ('F-2023-027', 'B-019', 'working_capital_revolver',  '2023-08-01', '2028-08-01', 20000000.00, 12000000.00, 7.250, NULL,  NULL,  'performing'),

    -- Clearwater Pharma: term loan (watchlist)
    ('F-2024-028', 'B-020', 'term_loan',                '2024-05-15', '2028-05-15',  6000000.00,  5700000.00, 10.750, NULL, 82.00, 'watchlist'),

    -- Horizon Renewable: equipment finance
    ('F-2024-029', 'B-021', 'equipment_finance',         '2024-07-01', '2029-07-01',  9000000.00,  8100000.00, 8.750, NULL,  58.00, 'performing'),

    -- Great Lakes Plastics: ABL
    ('F-2023-030', 'B-022', 'asset_based_line',         '2023-02-01', '2026-02-01',  8000000.00,  6400000.00, 8.500, 80.00, NULL,  'performing'),

    -- Vanguard IT: term loan (watchlist -- thin capitalization)
    ('F-2024-031', 'B-023', 'term_loan',                '2024-08-01', '2028-08-01',  4000000.00,  3900000.00, 11.500, NULL, 88.00, 'watchlist'),

    -- Patriot Staffing: ABL
    ('F-2023-032', 'B-024', 'asset_based_line',         '2023-11-01', '2026-11-01', 12000000.00,  9600000.00, 8.250, 82.00, NULL,  'performing'),

    -- Evergreen Timber: ABL + equipment
    ('F-2022-033', 'B-025', 'asset_based_line',         '2022-09-01', '2027-09-01', 10000000.00,  7000000.00, 7.750, 80.00, NULL,  'performing'),
    ('F-2024-034', 'B-025', 'equipment_finance',         '2024-03-15', '2029-03-15',  4000000.00,  3600000.00, 8.500, NULL,  55.00, 'performing'),

    -- Additional facilities for portfolio depth
    ('F-2024-035', 'B-010', 'equipment_finance',         '2024-09-01', '2029-09-01',  6000000.00,  5400000.00, 8.250, NULL,  60.00, 'performing'),
    ('F-2024-036', 'B-005', 'term_loan',                '2024-01-01', '2030-01-01', 15000000.00, 13500000.00, 8.500, NULL,  62.00, 'performing'),
    ('F-2023-037', 'B-012', 'equipment_finance',         '2023-11-15', '2028-11-15',  4500000.00,  3800000.00, 8.750, NULL,  58.00, 'performing'),
    ('F-2024-038', 'B-014', 'term_loan',                '2024-04-01', '2029-04-01',  8000000.00,  7000000.00, 8.000, NULL,  60.00, 'performing'),
    ('F-2024-039', 'B-003', 'equipment_finance',         '2024-06-15', '2029-06-15',  3500000.00,  3200000.00, 9.500, NULL,  70.00, 'watchlist'),
    ('F-2023-040', 'B-015', 'working_capital_revolver',  '2023-06-01', '2026-06-01',  8000000.00,  7200000.00, 9.000, NULL,  NULL,  'watchlist');
