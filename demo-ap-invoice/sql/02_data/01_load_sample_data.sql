/*==============================================================================
SAMPLE DATA - AP Invoice Pipeline
Loads realistic synthetic data for demonstration.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

----------------------------------------------------------------------
-- Vendor Master (8 vendors across hospitality categories)
----------------------------------------------------------------------
INSERT INTO VENDOR_MASTER (VENDOR_NAME, VENDOR_ALIASES, PAYMENT_TERMS)
SELECT column1, PARSE_JSON(column2), column3
FROM VALUES
    ('Alpine Food Supply Co.',       '["Alpine Foods","Alpine Food Svc","AFS Co"]',           'NET30'),
    ('Continental Linen Services',   '["Continental Linen","CLS Inc","Cont. Linen"]',         'NET30'),
    ('Metro IT Solutions',           '["Metro IT","MIS Corp","Metro Info Tech"]',              'NET45'),
    ('National Maintenance Group',   '["Natl Maintenance","NMG Services","Nat Maint Group"]', 'NET30'),
    ('Premier Entertainment Inc.',   '["Premier Ent","PEI","Premier Entertainment"]',         'NET15'),
    ('Statewide Beverage Dist.',     '["Statewide Bev","SBD","State Beverage"]',              'NET30'),
    ('Consolidated Building Supply', '["CBS","Consolidated Bldg","Consol Building"]',         'NET45'),
    ('Pacific Seafood Partners',     '["Pacific Seafood","PSP","Pac Seafood"]',               'NET30');

----------------------------------------------------------------------
-- GL Code Taxonomy (hospitality-specific)
----------------------------------------------------------------------
INSERT INTO GL_CODES (GL_CODE, GL_DESCRIPTION, CATEGORY)
VALUES
    ('5100', 'Food & Beverage',           'Operating'),
    ('5110', 'Dry Goods & Pantry',        'Operating'),
    ('5120', 'Fresh Produce & Dairy',     'Operating'),
    ('5130', 'Beverages & Bar Stock',     'Operating'),
    ('5200', 'Lodging Supplies',          'Operating'),
    ('5210', 'Linens & Bedding',          'Operating'),
    ('5220', 'Guest Amenities',           'Operating'),
    ('5300', 'Entertainment',             'Operating'),
    ('5310', 'Talent & Performers',       'Operating'),
    ('5320', 'AV & Production',           'Operating'),
    ('5400', 'Facilities & Maintenance',  'Operating'),
    ('5410', 'HVAC & Plumbing',           'Operating'),
    ('5420', 'Electrical & Lighting',     'Operating'),
    ('5430', 'Building Materials',        'Operating'),
    ('5500', 'IT Services',              'Operating'),
    ('5510', 'Software & Licensing',      'Operating'),
    ('5520', 'Hardware & Equipment',      'Operating'),
    ('6100', 'Professional Services',     'G&A'),
    ('6200', 'Insurance',                 'G&A'),
    ('6300', 'Utilities',                 'G&A');

----------------------------------------------------------------------
-- Invoice Headers (27 invoices: ~85% clean, ~15% ambiguous)
----------------------------------------------------------------------
-- Clean invoices (23) - high validation scores
INSERT INTO INVOICE_HEADER
    (SOURCE_FILE, VENDOR_NAME_RAW, VENDOR_ID_RESOLVED, INVOICE_NUMBER, INVOICE_DATE,
     PO_REFERENCE, TOTAL_AMOUNT, CURRENCY, PROPERTY, VALIDATION_SCORE, STATUS, APPROVED_BY, APPROVED_TS)
SELECT column1, column2, column3, column4, column5::DATE,
       column6, column7::NUMBER(12,2), column8, column9, column10::NUMBER(5,2), column11, column12, column13::TIMESTAMP_NTZ
FROM VALUES
    ('inv_alpine_001.pdf',      'Alpine Food Supply Co.',     1, 'AFS-2026-0441', '2026-03-01', 'PO-8801', 12450.00, 'USD', 'Resort East',      0.95, 'PROCESSED', 'SYSTEM', '2026-03-01 09:15:00'),
    ('inv_alpine_002.pdf',      'Alpine Food Supply Co.',     1, 'AFS-2026-0442', '2026-03-08', 'PO-8802', 8920.50,  'USD', 'Resort Northeast',  0.92, 'PROCESSED', 'SYSTEM', '2026-03-08 09:20:00'),
    ('inv_alpine_003.pdf',      'Alpine Food Supply Co.',     1, 'AFS-2026-0443', '2026-03-15', 'PO-8810', 15680.00, 'USD', 'Resort East',      0.97, 'PROCESSED', 'SYSTEM', '2026-03-15 09:10:00'),
    ('inv_contin_001.pdf',      'Continental Linen Services', 2, 'CLS-44021',     '2026-03-03', 'PO-8803', 6340.00,  'USD', 'Resort East',      0.91, 'PROCESSED', 'SYSTEM', '2026-03-03 10:00:00'),
    ('inv_contin_002.pdf',      'Continental Linen Services', 2, 'CLS-44022',     '2026-03-10', 'PO-8807', 7125.00,  'USD', 'Resort North',     0.93, 'PROCESSED', 'SYSTEM', '2026-03-10 10:05:00'),
    ('inv_contin_003.pdf',      'Continental Linen Services', 2, 'CLS-44023',     '2026-03-17', 'PO-8811', 5890.00,  'USD', 'Resort Northeast',  0.90, 'PROCESSED', 'SYSTEM', '2026-03-17 10:10:00'),
    ('inv_metro_001.pdf',       'Metro IT Solutions',         3, 'MIT-2026-1001', '2026-03-05', 'PO-8804', 24500.00, 'USD', 'Resort East',      0.96, 'PROCESSED', 'SYSTEM', '2026-03-05 11:00:00'),
    ('inv_metro_002.pdf',       'Metro IT Solutions',         3, 'MIT-2026-1002', '2026-03-12', NULL,       18750.00, 'USD', 'Resort Northeast',  0.88, 'PROCESSED', 'SYSTEM', '2026-03-12 11:05:00'),
    ('inv_national_001.pdf',    'National Maintenance Group', 4, 'NMG-60110',     '2026-03-02', 'PO-8805', 9870.00,  'USD', 'Resort East',      0.94, 'PROCESSED', 'SYSTEM', '2026-03-02 08:30:00'),
    ('inv_national_002.pdf',    'National Maintenance Group', 4, 'NMG-60111',     '2026-03-09', 'PO-8806', 11200.00, 'USD', 'Resort North',     0.91, 'PROCESSED', 'SYSTEM', '2026-03-09 08:35:00'),
    ('inv_national_003.pdf',    'National Maintenance Group', 4, 'NMG-60112',     '2026-03-20', 'PO-8815', 7650.00,  'USD', 'Resort Northeast',  0.93, 'PROCESSED', 'SYSTEM', '2026-03-20 08:40:00'),
    ('inv_premier_001.pdf',     'Premier Entertainment Inc.', 5, 'PEI-9900',      '2026-03-04', 'PO-8808', 35000.00, 'USD', 'Resort East',      0.95, 'PROCESSED', 'SYSTEM', '2026-03-04 14:00:00'),
    ('inv_premier_002.pdf',     'Premier Entertainment Inc.', 5, 'PEI-9901',      '2026-03-18', 'PO-8812', 42500.00, 'USD', 'Resort Northeast',  0.94, 'PROCESSED', 'SYSTEM', '2026-03-18 14:05:00'),
    ('inv_statewide_001.pdf',   'Statewide Beverage Dist.',   6, 'SBD-2026-771',  '2026-03-06', 'PO-8809', 16800.00, 'USD', 'Resort East',      0.96, 'PROCESSED', 'SYSTEM', '2026-03-06 07:45:00'),
    ('inv_statewide_002.pdf',   'Statewide Beverage Dist.',   6, 'SBD-2026-772',  '2026-03-13', 'PO-8813', 14350.00, 'USD', 'Resort North',     0.92, 'PROCESSED', 'SYSTEM', '2026-03-13 07:50:00'),
    ('inv_statewide_003.pdf',   'Statewide Beverage Dist.',   6, 'SBD-2026-773',  '2026-03-22', 'PO-8816', 19200.00, 'USD', 'Resort Northeast',  0.94, 'PROCESSED', 'SYSTEM', '2026-03-22 07:55:00'),
    ('inv_consol_001.pdf',      'Consolidated Building Supply', 7, 'CBS-30440',   '2026-03-07', 'PO-8814', 8900.00,  'USD', 'Resort East',      0.90, 'PROCESSED', 'SYSTEM', '2026-03-07 12:00:00'),
    ('inv_consol_002.pdf',      'Consolidated Building Supply', 7, 'CBS-30441',   '2026-03-14', NULL,       6750.00,  'USD', 'Resort North',     0.87, 'PROCESSED', 'SYSTEM', '2026-03-14 12:05:00'),
    ('inv_pacific_001.pdf',     'Pacific Seafood Partners',   8, 'PSP-2026-088',  '2026-03-11', 'PO-8817', 11400.00, 'USD', 'Resort East',      0.95, 'PROCESSED', 'SYSTEM', '2026-03-11 06:30:00'),
    ('inv_pacific_002.pdf',     'Pacific Seafood Partners',   8, 'PSP-2026-089',  '2026-03-19', 'PO-8818', 9850.00,  'USD', 'Resort Northeast',  0.93, 'PROCESSED', 'SYSTEM', '2026-03-19 06:35:00'),
    ('inv_alpine_004.pdf',      'Alpine Food Supply Co.',     1, 'AFS-2026-0444', '2026-03-25', 'PO-8820', 10200.00, 'USD', 'Resort North',     0.91, 'PROCESSED', 'SYSTEM', '2026-03-25 09:25:00'),
    ('inv_national_004.pdf',    'National Maintenance Group', 4, 'NMG-60113',     '2026-03-28', 'PO-8822', 13500.00, 'USD', 'Resort East',      0.92, 'PROCESSED', 'SYSTEM', '2026-03-28 08:45:00'),
    ('inv_contin_004.pdf',      'Continental Linen Services', 2, 'CLS-44024',     '2026-03-30', 'PO-8824', 8100.00,  'USD', 'Resort East',      0.94, 'PROCESSED', 'SYSTEM', '2026-03-30 10:15:00');

-- Ambiguous invoices (4) - low validation scores, routed to review queue
INSERT INTO INVOICE_HEADER
    (SOURCE_FILE, VENDOR_NAME_RAW, VENDOR_ID_RESOLVED, INVOICE_NUMBER, INVOICE_DATE,
     PO_REFERENCE, TOTAL_AMOUNT, CURRENCY, PROPERTY, VALIDATION_SCORE, STATUS)
SELECT column1, column2, column3, column4, column5::DATE,
       column6, column7::NUMBER(12,2), column8, column9, column10::NUMBER(5,2), column11
FROM VALUES
    ('inv_unknown_001.pdf',  'Alpine Foods LLC',     NULL, 'AF-99X',      '2026-03-21', NULL,       4580.00,  'USD', 'Resort East',     0.52, 'REVIEW'),
    ('inv_unclear_002.pdf',  'Metro Info Tech',      NULL, NULL,          '2026-03-23', 'PO-DRAFT', 31200.00, 'USD', 'Resort Northeast', 0.41, 'REVIEW'),
    ('inv_partial_003.pdf',  'Natl Maintenance',     NULL, 'NMG-PARTIAL', NULL,         NULL,       NULL,     'USD', 'Resort North',     0.28, 'REVIEW'),
    ('inv_damaged_004.pdf',  'State Beverage',       NULL, 'SBD-SCAN',    '2026-03-26', NULL,       7200.00,  'USD', 'Resort East',     0.63, 'REVIEW');

----------------------------------------------------------------------
-- Review Queue entries for ambiguous invoices
----------------------------------------------------------------------
INSERT INTO REVIEW_QUEUE (INVOICE_ID, FLAGGED_FIELDS, VALIDATION_SCORE, RESOLUTION)
SELECT column1, PARSE_JSON(column2), column3::NUMBER(5,2), column4
FROM VALUES
    (24, '["VENDOR_ID_RESOLVED","PO_REFERENCE"]',                        0.52, NULL),
    (25, '["VENDOR_ID_RESOLVED","INVOICE_NUMBER","PO_REFERENCE"]',       0.41, NULL),
    (26, '["VENDOR_ID_RESOLVED","INVOICE_DATE","TOTAL_AMOUNT"]',         0.28, NULL),
    (27, '["VENDOR_ID_RESOLVED","PO_REFERENCE"]',                        0.63, NULL);

----------------------------------------------------------------------
-- Line Items for processed invoices (representative subset)
----------------------------------------------------------------------
INSERT INTO INVOICE_LINE_ITEMS
    (INVOICE_ID, DESCRIPTION, QUANTITY, UNIT_PRICE, LINE_TOTAL,
     GL_CODE_SUGGESTED, GL_CODE_CONFIDENCE, GL_CODE_CONFIRMED, REVIEWER_OVERRIDE)
SELECT column1, column2, column3::NUMBER(10,2), column4::NUMBER(12,2), column5::NUMBER(12,2),
       column6, column7::NUMBER(5,4), column8, column9::BOOLEAN
FROM VALUES
    -- Invoice 1: Alpine Food (Resort East) - $12,450
    (1, 'Dry goods pantry restock - flour, sugar, spices',   1, 4200.00, 4200.00, '5110', 0.9200, '5110', FALSE),
    (1, 'Fresh produce weekly delivery',                     1, 5100.00, 5100.00, '5120', 0.9500, '5120', FALSE),
    (1, 'Dairy products - milk, cream, butter',              1, 3150.00, 3150.00, '5120', 0.9100, '5120', FALSE),
    -- Invoice 4: Continental Linen (Resort East) - $6,340
    (4, 'King size sheet sets (200 count)',                 200, 18.00,   3600.00, '5210', 0.9400, '5210', FALSE),
    (4, 'Bath towel replacement lot',                      400,  4.50,   1800.00, '5210', 0.9300, '5210', FALSE),
    (4, 'Pillow protectors',                               300,  3.13,    940.00, '5210', 0.8900, '5210', FALSE),
    -- Invoice 7: Metro IT (Resort East) - $24,500
    (7, 'Managed network services - March',                  1, 15000.00, 15000.00, '5500', 0.9600, '5500', FALSE),
    (7, 'Software license renewal - POS system',             1,  6500.00,  6500.00, '5510', 0.9100, '5510', FALSE),
    (7, 'Replacement access points (qty 12)',               12,   250.00,  3000.00, '5520', 0.8800, '5520', FALSE),
    -- Invoice 9: National Maintenance (Resort East) - $9,870
    (9,  'HVAC quarterly maintenance - main building',       1,  4200.00,  4200.00, '5410', 0.9300, '5410', FALSE),
    (9,  'Emergency plumbing repair - 3rd floor',            1,  2870.00,  2870.00, '5410', 0.8700, '5410', FALSE),
    (9,  'Light fixture replacement - lobby',               20,   140.00,  2800.00, '5420', 0.9000, '5420', FALSE),
    -- Invoice 12: Premier Entertainment (Resort East) - $35,000
    (12, 'Headline performer - March 15 weekend',            1, 25000.00, 25000.00, '5310', 0.9500, '5310', FALSE),
    (12, 'Sound & lighting production package',              1,  7500.00,  7500.00, '5320', 0.9200, '5320', FALSE),
    (12, 'Backstage catering & hospitality',                 1,  2500.00,  2500.00, '5100', 0.7800, '5100', FALSE),
    -- Invoice 14: Statewide Beverage (Resort East) - $16,800
    (14, 'Premium spirits replenishment',                    1,  8400.00,  8400.00, '5130', 0.9400, '5130', FALSE),
    (14, 'Draft beer kegs (assorted)',                      40,   120.00,  4800.00, '5130', 0.9600, '5130', FALSE),
    (14, 'Non-alcoholic beverage cases',                   200,    18.00,  3600.00, '5130', 0.9100, '5130', FALSE),
    -- Invoice 19: Pacific Seafood (Resort East) - $11,400
    (19, 'Fresh Atlantic salmon filets (200 lbs)',           1,  4800.00,  4800.00, '5120', 0.9300, '5120', FALSE),
    (19, 'Lobster tails for weekend service',              100,    42.00,  4200.00, '5120', 0.9500, '5120', FALSE),
    (19, 'Shrimp & shellfish assortment',                    1,  2400.00,  2400.00, '5120', 0.9100, '5120', FALSE),
    -- Ambiguous invoice 24: partial vendor match
    (24, 'Food supplies - misc',                             1,  2580.00,  2580.00, '5100', 0.6200, NULL,   FALSE),
    (24, 'Delivery surcharge',                               1,  2000.00,  2000.00, '6100', 0.4500, NULL,   FALSE),
    -- Ambiguous invoice 25: missing invoice number
    (25, 'Annual IT infrastructure assessment',              1, 18000.00, 18000.00, '5500', 0.7100, NULL,   FALSE),
    (25, 'Cybersecurity audit - all properties',             1, 13200.00, 13200.00, '5500', 0.6800, NULL,   FALSE);

----------------------------------------------------------------------
-- Audit Log entries for processed invoices
----------------------------------------------------------------------
INSERT INTO AUDIT_LOG (INVOICE_ID, ACTION, FIELD_NAME, OLD_VALUE, NEW_VALUE, ACTOR, ACTOR_TYPE, ACTION_TS)
SELECT column1, column2, column3, column4, column5, column6, column7, column8::TIMESTAMP_NTZ
FROM VALUES
    (1,  'EXTRACTED',      NULL,               NULL,    NULL,                'AI_EXTRACT',  'AI',    '2026-03-01 09:10:00'),
    (1,  'VENDOR_MATCHED', 'VENDOR_ID_RESOLVED', NULL,  '1',                'FUZZY_MATCH', 'AI',    '2026-03-01 09:11:00'),
    (1,  'GL_CLASSIFIED',  'GL_CODE_SUGGESTED',  NULL,  '5110,5120,5120',   'AI_CLASSIFY', 'AI',    '2026-03-01 09:12:00'),
    (1,  'AUTO_APPROVED',  'STATUS',           'PENDING','PROCESSED',        'SYSTEM',      'SYSTEM','2026-03-01 09:15:00'),
    (24, 'EXTRACTED',      NULL,               NULL,    NULL,                'AI_EXTRACT',  'AI',    '2026-03-21 09:00:00'),
    (24, 'VENDOR_UNMATCHED','VENDOR_ID_RESOLVED',NULL,  NULL,               'FUZZY_MATCH', 'AI',    '2026-03-21 09:01:00'),
    (24, 'FLAGGED',        'STATUS',           'PENDING','REVIEW',           'SYSTEM',      'SYSTEM','2026-03-21 09:02:00'),
    (25, 'EXTRACTED',      NULL,               NULL,    NULL,                'AI_EXTRACT',  'AI',    '2026-03-23 10:00:00'),
    (25, 'FLAGGED',        'STATUS',           'PENDING','REVIEW',           'SYSTEM',      'SYSTEM','2026-03-23 10:01:00'),
    (26, 'EXTRACTED',      NULL,               NULL,    NULL,                'AI_EXTRACT',  'AI',    '2026-03-24 11:00:00'),
    (26, 'FLAGGED',        'STATUS',           'PENDING','REVIEW',           'SYSTEM',      'SYSTEM','2026-03-24 11:01:00');

SELECT 'Sample data loaded: '
    || (SELECT COUNT(*) FROM VENDOR_MASTER) || ' vendors, '
    || (SELECT COUNT(*) FROM GL_CODES) || ' GL codes, '
    || (SELECT COUNT(*) FROM INVOICE_HEADER) || ' invoices, '
    || (SELECT COUNT(*) FROM INVOICE_LINE_ITEMS) || ' line items'
    AS status;
