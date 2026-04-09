/*==============================================================================
04 - Load Covenants (Synthetic)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Quarterly covenant test results across multiple periods.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

INSERT INTO RAW_COVENANTS (covenant_id, facility_id, covenant_type, threshold_value, actual_value, reporting_period, in_compliance, waiver_granted)
VALUES
    -- Apex Manufacturing (F-2024-001 ABL, F-2024-002 term) -- performing, tight on leverage
    ('C-001', 'F-2024-002', 'leverage_ratio',        3.50,  2.80, '2024-Q2', TRUE,  FALSE),
    ('C-002', 'F-2024-002', 'interest_coverage',      2.00,  3.10, '2024-Q2', TRUE,  FALSE),
    ('C-003', 'F-2024-002', 'leverage_ratio',        3.50,  3.20, '2024-Q3', TRUE,  FALSE),
    ('C-004', 'F-2024-002', 'interest_coverage',      2.00,  2.80, '2024-Q3', TRUE,  FALSE),
    ('C-005', 'F-2024-002', 'leverage_ratio',        3.50,  3.65, '2024-Q4', FALSE, TRUE),
    ('C-006', 'F-2024-002', 'interest_coverage',      2.00,  2.40, '2024-Q4', TRUE,  FALSE),
    ('C-007', 'F-2024-001', 'min_ebitda',            10000000.00, 12750000.00, '2024-Q4', TRUE, FALSE),

    -- Meridian Health (F-2023-003 revolver) -- strong compliance
    ('C-008', 'F-2023-003', 'leverage_ratio',        4.00,  2.50, '2024-Q2', TRUE,  FALSE),
    ('C-009', 'F-2023-003', 'fixed_charge_coverage',  1.25,  1.80, '2024-Q2', TRUE,  FALSE),
    ('C-010', 'F-2023-003', 'leverage_ratio',        4.00,  2.40, '2024-Q3', TRUE,  FALSE),
    ('C-011', 'F-2023-003', 'fixed_charge_coverage',  1.25,  1.90, '2024-Q3', TRUE,  FALSE),
    ('C-012', 'F-2023-003', 'leverage_ratio',        4.00,  2.30, '2024-Q4', TRUE,  FALSE),
    ('C-013', 'F-2023-003', 'fixed_charge_coverage',  1.25,  1.95, '2024-Q4', TRUE,  FALSE),

    -- Pinnacle Logistics (F-2023-005 ABL, watchlist) -- breached leverage
    ('C-014', 'F-2023-005', 'leverage_ratio',        3.00,  3.40, '2024-Q2', FALSE, FALSE),
    ('C-015', 'F-2023-005', 'interest_coverage',      1.75,  1.60, '2024-Q2', FALSE, FALSE),
    ('C-016', 'F-2023-005', 'leverage_ratio',        3.00,  3.80, '2024-Q3', FALSE, TRUE),
    ('C-017', 'F-2023-005', 'interest_coverage',      1.75,  1.45, '2024-Q3', FALSE, TRUE),
    ('C-018', 'F-2023-005', 'leverage_ratio',        3.00,  4.10, '2024-Q4', FALSE, FALSE),
    ('C-019', 'F-2023-005', 'interest_coverage',      1.75,  1.30, '2024-Q4', FALSE, FALSE),
    ('C-020', 'F-2023-005', 'min_ebitda',            6000000.00, 5200000.00, '2024-Q4', FALSE, FALSE),

    -- Veridian Tech (F-2024-006 term) -- performing
    ('C-021', 'F-2024-006', 'leverage_ratio',        4.00,  2.90, '2024-Q3', TRUE,  FALSE),
    ('C-022', 'F-2024-006', 'min_ebitda',            7000000.00, 9000000.00, '2024-Q3', TRUE, FALSE),
    ('C-023', 'F-2024-006', 'leverage_ratio',        4.00,  3.10, '2024-Q4', TRUE,  FALSE),
    ('C-024', 'F-2024-006', 'min_ebitda',            7000000.00, 8500000.00, '2024-Q4', TRUE, FALSE),

    -- Ironbridge Energy (F-2022-007 revolver) -- strong
    ('C-025', 'F-2022-007', 'leverage_ratio',        3.50,  1.80, '2024-Q2', TRUE,  FALSE),
    ('C-026', 'F-2022-007', 'interest_coverage',      2.50,  4.20, '2024-Q2', TRUE,  FALSE),
    ('C-027', 'F-2022-007', 'leverage_ratio',        3.50,  1.90, '2024-Q3', TRUE,  FALSE),
    ('C-028', 'F-2022-007', 'interest_coverage',      2.50,  4.00, '2024-Q3', TRUE,  FALSE),
    ('C-029', 'F-2022-007', 'leverage_ratio',        3.50,  2.10, '2024-Q4', TRUE,  FALSE),

    -- Cascade Paper (F-2023-009 ABL, watchlist) -- multiple breaches
    ('C-030', 'F-2023-009', 'leverage_ratio',        3.00,  3.50, '2024-Q2', FALSE, FALSE),
    ('C-031', 'F-2023-009', 'fixed_charge_coverage',  1.10,  0.95, '2024-Q2', FALSE, FALSE),
    ('C-032', 'F-2023-009', 'leverage_ratio',        3.00,  3.90, '2024-Q3', FALSE, TRUE),
    ('C-033', 'F-2023-009', 'fixed_charge_coverage',  1.10,  0.88, '2024-Q3', FALSE, TRUE),
    ('C-034', 'F-2023-009', 'leverage_ratio',        3.00,  4.20, '2024-Q4', FALSE, FALSE),
    ('C-035', 'F-2023-009', 'fixed_charge_coverage',  1.10,  0.82, '2024-Q4', FALSE, FALSE),
    ('C-036', 'F-2023-009', 'max_capex',             2000000.00, 2400000.00, '2024-Q4', FALSE, FALSE),

    -- Quantum Data (F-2024-013 term, watchlist) -- tight
    ('C-037', 'F-2024-013', 'leverage_ratio',        4.50,  4.20, '2024-Q3', TRUE,  FALSE),
    ('C-038', 'F-2024-013', 'min_ebitda',            4000000.00, 4100000.00, '2024-Q3', TRUE, FALSE),
    ('C-039', 'F-2024-013', 'leverage_ratio',        4.50,  4.80, '2024-Q4', FALSE, FALSE),
    ('C-040', 'F-2024-013', 'min_ebitda',            4000000.00, 3600000.00, '2024-Q4', FALSE, FALSE),

    -- Redwood Environmental (F-2023-019 term, default) -- serial breach
    ('C-041', 'F-2023-019', 'leverage_ratio',        3.50,  5.20, '2024-Q1', FALSE, FALSE),
    ('C-042', 'F-2023-019', 'interest_coverage',      1.50,  0.90, '2024-Q1', FALSE, FALSE),
    ('C-043', 'F-2023-019', 'leverage_ratio',        3.50,  6.10, '2024-Q2', FALSE, FALSE),
    ('C-044', 'F-2023-019', 'interest_coverage',      1.50,  0.65, '2024-Q2', FALSE, FALSE),
    ('C-045', 'F-2023-019', 'min_ebitda',            4000000.00, 2100000.00, '2024-Q2', FALSE, FALSE),

    -- Keystone Auto Parts (F-2022-024 ABL, default) -- deteriorating
    ('C-046', 'F-2022-024', 'leverage_ratio',        3.00,  4.50, '2024-Q2', FALSE, TRUE),
    ('C-047', 'F-2022-024', 'fixed_charge_coverage',  1.10,  0.75, '2024-Q2', FALSE, TRUE),
    ('C-048', 'F-2022-024', 'leverage_ratio',        3.00,  5.80, '2024-Q3', FALSE, FALSE),
    ('C-049', 'F-2022-024', 'fixed_charge_coverage',  1.10,  0.55, '2024-Q3', FALSE, FALSE),

    -- Coastal Hospitality (F-2024-021 bridge, watchlist) -- seasonal stress
    ('C-050', 'F-2024-021', 'leverage_ratio',        4.00,  3.80, '2024-Q3', TRUE,  FALSE),
    ('C-051', 'F-2024-021', 'interest_coverage',      1.50,  1.55, '2024-Q3', TRUE,  FALSE),
    ('C-052', 'F-2024-021', 'leverage_ratio',        4.00,  4.50, '2024-Q4', FALSE, FALSE),
    ('C-053', 'F-2024-021', 'interest_coverage',      1.50,  1.20, '2024-Q4', FALSE, FALSE),

    -- Clearwater Pharma (F-2024-028 term, watchlist) -- R&D burn
    ('C-054', 'F-2024-028', 'leverage_ratio',        4.00,  3.60, '2024-Q3', TRUE,  FALSE),
    ('C-055', 'F-2024-028', 'min_ebitda',            5000000.00, 5200000.00, '2024-Q3', TRUE, FALSE),
    ('C-056', 'F-2024-028', 'leverage_ratio',        4.00,  4.30, '2024-Q4', FALSE, FALSE),
    ('C-057', 'F-2024-028', 'min_ebitda',            5000000.00, 4200000.00, '2024-Q4', FALSE, FALSE),

    -- Vanguard IT (F-2024-031 term, watchlist) -- thin capitalization
    ('C-058', 'F-2024-031', 'leverage_ratio',        5.00,  5.20, '2024-Q4', FALSE, FALSE),
    ('C-059', 'F-2024-031', 'min_ebitda',            3000000.00, 2800000.00, '2024-Q4', FALSE, FALSE),

    -- Strong performers: Atlas, Heartland, Liberty, Trident, Evergreen
    ('C-060', 'F-2023-011', 'leverage_ratio',        3.50,  2.20, '2024-Q4', TRUE,  FALSE),
    ('C-061', 'F-2023-011', 'interest_coverage',      2.00,  3.50, '2024-Q4', TRUE,  FALSE),
    ('C-062', 'F-2022-014', 'leverage_ratio',        3.50,  2.00, '2024-Q4', TRUE,  FALSE),
    ('C-063', 'F-2022-014', 'min_ebitda',            12000000.00, 15000000.00, '2024-Q4', TRUE, FALSE),
    ('C-064', 'F-2022-020', 'leverage_ratio',        3.00,  1.60, '2024-Q4', TRUE,  FALSE),
    ('C-065', 'F-2021-026', 'leverage_ratio',        3.00,  1.40, '2024-Q4', TRUE,  FALSE),
    ('C-066', 'F-2021-026', 'interest_coverage',      2.50,  5.20, '2024-Q4', TRUE,  FALSE),
    ('C-067', 'F-2022-033', 'leverage_ratio',        3.50,  2.10, '2024-Q4', TRUE,  FALSE),

    -- Summit Construction: performing on covenants
    ('C-068', 'F-2023-017', 'leverage_ratio',        4.00,  3.20, '2024-Q3', TRUE,  FALSE),
    ('C-069', 'F-2023-017', 'interest_coverage',      1.50,  1.80, '2024-Q3', TRUE,  FALSE),
    ('C-070', 'F-2023-017', 'leverage_ratio',        4.00,  3.40, '2024-Q4', TRUE,  FALSE),

    -- Northstar Chemical: solid
    ('C-071', 'F-2023-022', 'leverage_ratio',        3.50,  2.30, '2024-Q4', TRUE,  FALSE),
    ('C-072', 'F-2023-022', 'fixed_charge_coverage',  1.25,  1.70, '2024-Q4', TRUE,  FALSE),
    ('C-073', 'F-2024-023', 'leverage_ratio',        3.50,  2.30, '2024-Q4', TRUE,  FALSE),

    -- Pinnacle Logistics equipment (F-2024-039, watchlist)
    ('C-074', 'F-2024-039', 'leverage_ratio',        3.00,  3.60, '2024-Q4', FALSE, FALSE),
    ('C-075', 'F-2024-039', 'interest_coverage',      1.75,  1.40, '2024-Q4', FALSE, FALSE),

    -- Coastal Hospitality revolver (F-2023-040, watchlist)
    ('C-076', 'F-2023-040', 'leverage_ratio',        4.00,  4.30, '2024-Q4', FALSE, FALSE),
    ('C-077', 'F-2023-040', 'fixed_charge_coverage',  1.10,  0.90, '2024-Q4', FALSE, FALSE),

    -- Patriot Staffing: performing
    ('C-078', 'F-2023-032', 'leverage_ratio',        4.00,  3.20, '2024-Q4', TRUE,  FALSE),
    ('C-079', 'F-2023-032', 'min_ebitda',            3500000.00, 4920000.00, '2024-Q4', TRUE, FALSE),

    -- Horizon Renewable: performing
    ('C-080', 'F-2024-029', 'leverage_ratio',        4.00,  2.80, '2024-Q4', TRUE,  FALSE);
