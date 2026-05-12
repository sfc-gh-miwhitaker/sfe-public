USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA IOT_LIFECYCLE;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

INSERT INTO FLEET_VEHICLES (VEHICLE_ID, LICENSE_PLATE, DRIVER_NAME, VEHICLE_TYPE, CAPACITY_LBS, HOME_DEPOT, STATUS) VALUES
    ('V-001', 'GA-4821A', 'Marcus Johnson',  'Box Truck',  4500, 'Atlanta Central', 'ACTIVE'),
    ('V-002', 'GA-7733B', 'Keisha Williams', 'Box Truck',  4500, 'Atlanta Central', 'ACTIVE'),
    ('V-003', 'GA-1295C', 'David Chen',      'Cargo Van',  2800, 'Atlanta Central', 'ACTIVE'),
    ('V-004', 'GA-5508D', 'Sarah Mitchell',  'Box Truck',  4500, 'Atlanta Central', 'ACTIVE'),
    ('V-005', 'GA-3366E', 'James Rivera',    'Cargo Van',  2800, 'Atlanta Central', 'ACTIVE'),
    ('V-006', 'GA-9142F', 'Aisha Thompson',  'Box Truck',  4500, 'Atlanta Central', 'ACTIVE'),
    ('V-007', 'GA-2057G', 'Robert Kim',      'Cargo Van',  2800, 'Marietta Depot',  'ACTIVE'),
    ('V-008', 'GA-6891H', 'Lisa Patel',      'Box Truck',  4500, 'Marietta Depot',  'ACTIVE'),
    ('V-009', 'GA-8024J', 'Carlos Mendez',   'Box Truck',  4500, 'Decatur Depot',   'ACTIVE'),
    ('V-010', 'GA-4477K', 'Tamika Brown',    'Cargo Van',  2800, 'Decatur Depot',   'ACTIVE'),
    ('V-011', 'GA-1138L', 'Brian Foster',    'Box Truck',  4500, 'Atlanta Central', 'MAINTENANCE'),
    ('V-012', 'GA-5562M', 'Nina Gonzalez',   'Cargo Van',  2800, 'Atlanta Central', 'ACTIVE');

INSERT INTO CUSTOMERS (CUSTOMER_ID, CUSTOMER_NAME, INDUSTRY, ADDRESS, CITY, STATE, LATITUDE, LONGITUDE, CONTRACT_TYPE, MONTHLY_VALUE) VALUES
    ('C-001', 'Peachtree General Hospital',   'Healthcare',   '1500 Peachtree St NE',     'Atlanta',        'GA', 33.7896, -84.3843, 'WEEKLY',    4200.00),
    ('C-002', 'Buckhead Grand Hotel',         'Hospitality',  '3344 Peachtree Rd NE',     'Atlanta',        'GA', 33.8456, -84.3625, 'WEEKLY',    3800.00),
    ('C-003', 'Midtown Medical Center',       'Healthcare',   '550 Peachtree St NE',      'Atlanta',        'GA', 33.7710, -84.3850, 'WEEKLY',    5100.00),
    ('C-004', 'Southern Grill Restaurant',    'Food Service', '200 Ponce de Leon Ave',     'Atlanta',        'GA', 33.7725, -84.3650, 'WEEKLY',    1200.00),
    ('C-005', 'Sandy Springs Suites',         'Hospitality',  '6100 Roswell Rd',          'Sandy Springs',  'GA', 33.9286, -84.3533, 'WEEKLY',    2900.00),
    ('C-006', 'Decatur Auto Works',           'Automotive',   '315 E Ponce de Leon Ave',  'Decatur',        'GA', 33.7748, -84.2930, 'BIWEEKLY',  1800.00),
    ('C-007', 'Georgia Tech Dining',          'Food Service', '350 Ferst Dr NW',          'Atlanta',        'GA', 33.7756, -84.3963, 'WEEKLY',    3500.00),
    ('C-008', 'Emory University Hospital',    'Healthcare',   '1364 Clifton Rd NE',       'Atlanta',        'GA', 33.7940, -84.3230, 'WEEKLY',    6200.00),
    ('C-009', 'Marietta Factory Floor',       'Industrial',   '750 Franklin Gateway SE',  'Marietta',       'GA', 33.9381, -84.5214, 'WEEKLY',    2400.00),
    ('C-010', 'Atlantic Station Spa',         'Spa/Wellness', '261 19th St NW',           'Atlanta',        'GA', 33.7919, -84.3948, 'BIWEEKLY',   950.00),
    ('C-011', 'Vinings Dental Group',         'Dental',       '2900 Paces Ferry Rd SE',   'Atlanta',        'GA', 33.8622, -84.4639, 'BIWEEKLY',   750.00),
    ('C-012', 'Roswell Country Club',         'Hospitality',  '2500 Club Springs Dr',     'Roswell',        'GA', 34.0232, -84.3516, 'WEEKLY',    2100.00),
    ('C-013', 'Grady Memorial Hospital',      'Healthcare',   '80 Jesse Hill Jr Dr SE',   'Atlanta',        'GA', 33.7556, -84.3818, 'WEEKLY',    7500.00),
    ('C-014', 'Ponce City Market Kitchen',    'Food Service', '675 Ponce de Leon Ave NE', 'Atlanta',        'GA', 33.7725, -84.3655, 'WEEKLY',    1600.00),
    ('C-015', 'Kennesaw Manufacturing',       'Industrial',   '1100 Ernest Barrett Pkwy', 'Kennesaw',       'GA', 34.0232, -84.6155, 'BIWEEKLY',  3200.00),
    ('C-016', 'Dunwoody Hilton',              'Hospitality',  '4500 Ashford Dunwoody Rd', 'Dunwoody',       'GA', 33.9238, -84.3385, 'WEEKLY',    3100.00),
    ('C-017', 'Alpharetta Urgent Care',       'Healthcare',   '2550 Old Milton Pkwy',     'Alpharetta',     'GA', 34.0654, -84.2832, 'WEEKLY',    2200.00),
    ('C-018', 'Little Five Points Bistro',    'Food Service', '1083 Euclid Ave NE',       'Atlanta',        'GA', 33.7642, -84.3486, 'WEEKLY',     800.00),
    ('C-019', 'Smyrna Collision Center',      'Automotive',   '2700 Spring Rd SE',        'Smyrna',         'GA', 33.8837, -84.5144, 'BIWEEKLY',  1100.00),
    ('C-020', 'Piedmont Park Events',         'Hospitality',  '1320 Monroe Dr NE',        'Atlanta',        'GA', 33.7874, -84.3734, 'WEEKLY',    1700.00);

INSERT INTO ROUTES (ROUTE_ID, ROUTE_NAME, VEHICLE_ID, DAY_OF_WEEK, STOP_COUNT, ESTIMATED_MILES) VALUES
    ('R-001', 'Midtown Healthcare',    'V-001', 'MONDAY',    4, 28.5),
    ('R-002', 'Buckhead Hospitality',  'V-002', 'MONDAY',    3, 22.0),
    ('R-003', 'Decatur/Emory',         'V-003', 'TUESDAY',   3, 31.2),
    ('R-004', 'Sandy Springs North',   'V-004', 'TUESDAY',   4, 38.7),
    ('R-005', 'Midtown Food Service',  'V-005', 'WEDNESDAY', 4, 19.4),
    ('R-006', 'West Metro Industrial', 'V-006', 'WEDNESDAY', 3, 42.1),
    ('R-007', 'Marietta/Kennesaw',     'V-007', 'THURSDAY',  3, 35.6),
    ('R-008', 'East Atlanta Mixed',    'V-009', 'FRIDAY',    4, 26.3);

INSERT INTO GPS_TELEMETRY (VEHICLE_ID, TIMESTAMP, LATITUDE, LONGITUDE, SPEED_MPH, HEADING, ENGINE_STATUS)
SELECT v.VEHICLE_ID, t.TS, t.LAT, t.LNG, t.SPD, t.HDG, t.ENG
FROM (VALUES
    ('V-001','2026-04-15 06:00:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'ON'),
    ('V-001','2026-04-15 06:05:00'::TIMESTAMP_NTZ, 33.7520,-84.3865,18.3,  15.0,'ON'),
    ('V-001','2026-04-15 06:10:00'::TIMESTAMP_NTZ, 33.7565,-84.3852,22.1,  12.0,'ON'),
    ('V-001','2026-04-15 06:15:00'::TIMESTAMP_NTZ, 33.7620,-84.3848,25.4,  10.0,'ON'),
    ('V-001','2026-04-15 06:20:00'::TIMESTAMP_NTZ, 33.7680,-84.3845,28.0,   8.0,'ON'),
    ('V-001','2026-04-15 06:25:00'::TIMESTAMP_NTZ, 33.7740,-84.3843,24.6,   5.0,'ON'),
    ('V-001','2026-04-15 06:30:00'::TIMESTAMP_NTZ, 33.7800,-84.3842,20.2,   3.0,'ON'),
    ('V-001','2026-04-15 06:35:00'::TIMESTAMP_NTZ, 33.7850,-84.3843,15.8, 358.0,'ON'),
    ('V-001','2026-04-15 06:40:00'::TIMESTAMP_NTZ, 33.7896,-84.3843, 0.0,   0.0,'IDLE'),
    ('V-001','2026-04-15 06:55:00'::TIMESTAMP_NTZ, 33.7896,-84.3843, 0.0,   0.0,'ON'),
    ('V-001','2026-04-15 07:00:00'::TIMESTAMP_NTZ, 33.7860,-84.3845,16.2, 185.0,'ON'),
    ('V-001','2026-04-15 07:05:00'::TIMESTAMP_NTZ, 33.7810,-84.3848,22.5, 188.0,'ON'),
    ('V-001','2026-04-15 07:10:00'::TIMESTAMP_NTZ, 33.7760,-84.3850,24.8, 190.0,'ON'),
    ('V-001','2026-04-15 07:15:00'::TIMESTAMP_NTZ, 33.7710,-84.3850, 0.0,   0.0,'IDLE'),
    ('V-001','2026-04-15 07:30:00'::TIMESTAMP_NTZ, 33.7710,-84.3850, 0.0,   0.0,'ON'),
    ('V-001','2026-04-15 07:35:00'::TIMESTAMP_NTZ, 33.7680,-84.3820,18.5, 130.0,'ON'),
    ('V-001','2026-04-15 07:40:00'::TIMESTAMP_NTZ, 33.7650,-84.3790,22.0, 135.0,'ON'),
    ('V-001','2026-04-15 07:45:00'::TIMESTAMP_NTZ, 33.7620,-84.3770,20.1, 140.0,'ON'),
    ('V-001','2026-04-15 07:50:00'::TIMESTAMP_NTZ, 33.7556,-84.3818, 0.0,   0.0,'IDLE'),
    ('V-001','2026-04-15 08:10:00'::TIMESTAMP_NTZ, 33.7556,-84.3818, 0.0,   0.0,'ON'),
    ('V-001','2026-04-15 08:15:00'::TIMESTAMP_NTZ, 33.7530,-84.3840,15.0, 210.0,'ON'),
    ('V-001','2026-04-15 08:20:00'::TIMESTAMP_NTZ, 33.7500,-84.3860,18.5, 220.0,'ON'),
    ('V-001','2026-04-15 08:25:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'IDLE'),

    ('V-002','2026-04-15 06:15:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'ON'),
    ('V-002','2026-04-15 06:20:00'::TIMESTAMP_NTZ, 33.7530,-84.3870,16.0,  20.0,'ON'),
    ('V-002','2026-04-15 06:25:00'::TIMESTAMP_NTZ, 33.7590,-84.3850,24.3,  18.0,'ON'),
    ('V-002','2026-04-15 06:30:00'::TIMESTAMP_NTZ, 33.7660,-84.3820,28.5,  25.0,'ON'),
    ('V-002','2026-04-15 06:35:00'::TIMESTAMP_NTZ, 33.7740,-84.3780,30.2,  30.0,'ON'),
    ('V-002','2026-04-15 06:40:00'::TIMESTAMP_NTZ, 33.7830,-84.3740,28.0,  25.0,'ON'),
    ('V-002','2026-04-15 06:45:00'::TIMESTAMP_NTZ, 33.7920,-84.3700,25.6,  20.0,'ON'),
    ('V-002','2026-04-15 06:50:00'::TIMESTAMP_NTZ, 33.8020,-84.3660,30.1,  18.0,'ON'),
    ('V-002','2026-04-15 06:55:00'::TIMESTAMP_NTZ, 33.8150,-84.3640,32.4,  15.0,'ON'),
    ('V-002','2026-04-15 07:00:00'::TIMESTAMP_NTZ, 33.8300,-84.3630,28.5,  12.0,'ON'),
    ('V-002','2026-04-15 07:05:00'::TIMESTAMP_NTZ, 33.8456,-84.3625, 0.0,   0.0,'IDLE'),
    ('V-002','2026-04-15 07:25:00'::TIMESTAMP_NTZ, 33.8456,-84.3625, 0.0,   0.0,'ON'),
    ('V-002','2026-04-15 07:30:00'::TIMESTAMP_NTZ, 33.8500,-84.3600,18.0,  10.0,'ON'),
    ('V-002','2026-04-15 07:35:00'::TIMESTAMP_NTZ, 33.8560,-84.3575,22.5,   8.0,'ON'),
    ('V-002','2026-04-15 07:40:00'::TIMESTAMP_NTZ, 33.8622,-84.3548,20.0, 340.0,'ON'),
    ('V-002','2026-04-15 07:45:00'::TIMESTAMP_NTZ, 33.8700,-84.3530,18.0, 340.0,'ON'),
    ('V-002','2026-04-15 07:50:00'::TIMESTAMP_NTZ, 33.8800,-84.3510,22.0, 338.0,'ON'),
    ('V-002','2026-04-15 07:55:00'::TIMESTAMP_NTZ, 33.8900,-84.3500,20.5, 345.0,'ON'),
    ('V-002','2026-04-15 08:00:00'::TIMESTAMP_NTZ, 33.9000,-84.3490,24.0, 348.0,'ON'),
    ('V-002','2026-04-15 08:05:00'::TIMESTAMP_NTZ, 33.9100,-84.3500,22.0, 350.0,'ON'),
    ('V-002','2026-04-15 08:10:00'::TIMESTAMP_NTZ, 33.9200,-84.3520,18.5, 355.0,'ON'),
    ('V-002','2026-04-15 08:15:00'::TIMESTAMP_NTZ, 33.9286,-84.3533, 0.0,   0.0,'IDLE'),
    ('V-002','2026-04-15 08:35:00'::TIMESTAMP_NTZ, 33.9286,-84.3533, 0.0,   0.0,'ON'),
    ('V-002','2026-04-15 08:40:00'::TIMESTAMP_NTZ, 33.9200,-84.3510,20.0, 175.0,'ON'),
    ('V-002','2026-04-15 08:45:00'::TIMESTAMP_NTZ, 33.9100,-84.3520,28.0, 178.0,'ON'),
    ('V-002','2026-04-15 08:50:00'::TIMESTAMP_NTZ, 33.8900,-84.3540,32.0, 180.0,'ON'),
    ('V-002','2026-04-15 08:55:00'::TIMESTAMP_NTZ, 33.8700,-84.3600,30.0, 195.0,'ON'),
    ('V-002','2026-04-15 09:00:00'::TIMESTAMP_NTZ, 33.8500,-84.3650,28.0, 200.0,'ON'),
    ('V-002','2026-04-15 09:05:00'::TIMESTAMP_NTZ, 33.8300,-84.3700,26.0, 205.0,'ON'),
    ('V-002','2026-04-15 09:10:00'::TIMESTAMP_NTZ, 33.8100,-84.3750,24.0, 210.0,'ON'),
    ('V-002','2026-04-15 09:15:00'::TIMESTAMP_NTZ, 33.7900,-84.3800,22.0, 215.0,'ON'),
    ('V-002','2026-04-15 09:20:00'::TIMESTAMP_NTZ, 33.7700,-84.3840,18.0, 220.0,'ON'),
    ('V-002','2026-04-15 09:25:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'IDLE'),

    ('V-003','2026-04-15 07:00:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'ON'),
    ('V-003','2026-04-15 07:05:00'::TIMESTAMP_NTZ, 33.7510,-84.3820,20.0, 100.0,'ON'),
    ('V-003','2026-04-15 07:10:00'::TIMESTAMP_NTZ, 33.7540,-84.3720,28.0, 105.0,'ON'),
    ('V-003','2026-04-15 07:15:00'::TIMESTAMP_NTZ, 33.7580,-84.3600,32.0, 108.0,'ON'),
    ('V-003','2026-04-15 07:20:00'::TIMESTAMP_NTZ, 33.7630,-84.3480,30.0, 110.0,'ON'),
    ('V-003','2026-04-15 07:25:00'::TIMESTAMP_NTZ, 33.7680,-84.3370,28.0, 108.0,'ON'),
    ('V-003','2026-04-15 07:30:00'::TIMESTAMP_NTZ, 33.7748,-84.3230,24.0, 100.0,'ON'),
    ('V-003','2026-04-15 07:35:00'::TIMESTAMP_NTZ, 33.7800,-84.3230,18.0,  90.0,'ON'),
    ('V-003','2026-04-15 07:40:00'::TIMESTAMP_NTZ, 33.7874,-84.3234,15.0,   5.0,'ON'),
    ('V-003','2026-04-15 07:45:00'::TIMESTAMP_NTZ, 33.7940,-84.3230, 0.0,   0.0,'IDLE'),
    ('V-003','2026-04-15 08:05:00'::TIMESTAMP_NTZ, 33.7940,-84.3230, 0.0,   0.0,'ON'),
    ('V-003','2026-04-15 08:10:00'::TIMESTAMP_NTZ, 33.7870,-84.3250,20.0, 200.0,'ON'),
    ('V-003','2026-04-15 08:15:00'::TIMESTAMP_NTZ, 33.7810,-84.3300,24.0, 210.0,'ON'),
    ('V-003','2026-04-15 08:20:00'::TIMESTAMP_NTZ, 33.7748,-84.2930, 0.0,   0.0,'IDLE'),

    ('V-005','2026-04-15 06:30:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'ON'),
    ('V-005','2026-04-15 06:35:00'::TIMESTAMP_NTZ, 33.7530,-84.3900,14.0, 290.0,'ON'),
    ('V-005','2026-04-15 06:40:00'::TIMESTAMP_NTZ, 33.7580,-84.3920,18.0, 300.0,'ON'),
    ('V-005','2026-04-15 06:45:00'::TIMESTAMP_NTZ, 33.7650,-84.3940,22.0, 310.0,'ON'),
    ('V-005','2026-04-15 06:50:00'::TIMESTAMP_NTZ, 33.7720,-84.3955,20.0, 320.0,'ON'),
    ('V-005','2026-04-15 06:55:00'::TIMESTAMP_NTZ, 33.7756,-84.3963, 0.0,   0.0,'IDLE'),
    ('V-005','2026-04-15 07:15:00'::TIMESTAMP_NTZ, 33.7756,-84.3963, 0.0,   0.0,'ON'),
    ('V-005','2026-04-15 07:20:00'::TIMESTAMP_NTZ, 33.7730,-84.3930,16.0, 150.0,'ON'),
    ('V-005','2026-04-15 07:25:00'::TIMESTAMP_NTZ, 33.7725,-84.3860,18.0, 140.0,'ON'),
    ('V-005','2026-04-15 07:30:00'::TIMESTAMP_NTZ, 33.7725,-84.3790,22.0, 100.0,'ON'),
    ('V-005','2026-04-15 07:35:00'::TIMESTAMP_NTZ, 33.7725,-84.3710,24.0,  95.0,'ON'),
    ('V-005','2026-04-15 07:40:00'::TIMESTAMP_NTZ, 33.7725,-84.3655, 0.0,   0.0,'IDLE')
) AS t(VEHICLE_ID, TS, LAT, LNG, SPD, HDG, ENG)
CROSS JOIN (SELECT 1) AS v(VEHICLE_ID)
WHERE 1=1;

DELETE FROM GPS_TELEMETRY WHERE 1=0;
INSERT INTO GPS_TELEMETRY (VEHICLE_ID, TIMESTAMP, LATITUDE, LONGITUDE, SPEED_MPH, HEADING, ENGINE_STATUS)
SELECT col1, col2, col3, col4, col5, col6, col7 FROM VALUES
    ('V-004','2026-04-15 06:00:00'::TIMESTAMP_NTZ, 33.7490,-84.3880, 0.0,   0.0,'ON'),
    ('V-004','2026-04-15 06:05:00'::TIMESTAMP_NTZ, 33.7540,-84.3900,18.0, 330.0,'ON'),
    ('V-004','2026-04-15 06:10:00'::TIMESTAMP_NTZ, 33.7600,-84.3910,22.0, 340.0,'ON'),
    ('V-004','2026-04-15 06:15:00'::TIMESTAMP_NTZ, 33.7700,-84.3920,28.0, 345.0,'ON'),
    ('V-004','2026-04-15 06:20:00'::TIMESTAMP_NTZ, 33.7800,-84.3920,30.0, 350.0,'ON'),
    ('V-004','2026-04-15 06:25:00'::TIMESTAMP_NTZ, 33.7920,-84.3910,28.0, 355.0,'ON'),
    ('V-004','2026-04-15 06:30:00'::TIMESTAMP_NTZ, 33.8050,-84.3880,32.0,   0.0,'ON'),
    ('V-004','2026-04-15 06:35:00'::TIMESTAMP_NTZ, 33.8200,-84.3850,34.0,   5.0,'ON'),
    ('V-004','2026-04-15 06:40:00'::TIMESTAMP_NTZ, 33.8400,-84.3800,36.0,  10.0,'ON'),
    ('V-004','2026-04-15 06:45:00'::TIMESTAMP_NTZ, 33.8600,-84.3700,34.0,  15.0,'ON'),
    ('V-004','2026-04-15 06:50:00'::TIMESTAMP_NTZ, 33.8800,-84.3600,30.0,  10.0,'ON'),
    ('V-004','2026-04-15 06:55:00'::TIMESTAMP_NTZ, 33.9000,-84.3550,28.0,   5.0,'ON'),
    ('V-004','2026-04-15 07:00:00'::TIMESTAMP_NTZ, 33.9238,-84.3385, 0.0,   0.0,'IDLE'),
    ('V-004','2026-04-15 07:20:00'::TIMESTAMP_NTZ, 33.9238,-84.3385, 0.0,   0.0,'ON'),
    ('V-004','2026-04-15 07:25:00'::TIMESTAMP_NTZ, 33.9300,-84.3400,18.0,   5.0,'ON'),
    ('V-004','2026-04-15 07:30:00'::TIMESTAMP_NTZ, 33.9500,-84.3450,24.0,  10.0,'ON'),
    ('V-004','2026-04-15 07:35:00'::TIMESTAMP_NTZ, 33.9700,-84.3500,28.0,  12.0,'ON'),
    ('V-004','2026-04-15 07:40:00'::TIMESTAMP_NTZ, 33.9900,-84.3500,30.0,  15.0,'ON'),
    ('V-004','2026-04-15 07:45:00'::TIMESTAMP_NTZ, 34.0100,-84.3510,28.0,  10.0,'ON'),
    ('V-004','2026-04-15 07:50:00'::TIMESTAMP_NTZ, 34.0232,-84.3516, 0.0,   0.0,'IDLE');

INSERT INTO GARMENTS (GARMENT_ID, RFID_TAG, GARMENT_TYPE, SIZE, COLOR, CUSTOMER_ID, ASSIGNED_DATE, STATUS, WASH_COUNT)
SELECT 'G-' || LPAD(seq4()::VARCHAR, 4, '0'),
       'RFID-' || LPAD(UNIFORM(100000, 999999, RANDOM())::VARCHAR, 6, '0') || '-' || LPAD(seq4()::VARCHAR, 4, '0'),
       t.GARMENT_TYPE, t.SIZE, t.COLOR, t.CUSTOMER_ID,
       DATEADD('day', -UNIFORM(30, 365, RANDOM()), '2026-04-15'::DATE),
       t.STATUS, t.WASH_COUNT
FROM (VALUES
    ('Scrubs Top',     'M',  'Ceil Blue',  'C-001', 'IN_SERVICE', 45),
    ('Scrubs Top',     'L',  'Ceil Blue',  'C-001', 'IN_SERVICE', 38),
    ('Scrubs Bottom',  'M',  'Ceil Blue',  'C-001', 'IN_SERVICE', 44),
    ('Lab Coat',       'L',  'White',      'C-001', 'IN_SERVICE', 22),
    ('Lab Coat',       'M',  'White',      'C-003', 'IN_SERVICE', 31),
    ('Scrubs Top',     'S',  'Navy',       'C-003', 'IN_SERVICE', 52),
    ('Scrubs Bottom',  'S',  'Navy',       'C-003', 'IN_SERVICE', 51),
    ('Scrubs Top',     'XL', 'Ceil Blue',  'C-008', 'IN_SERVICE', 28),
    ('Scrubs Bottom',  'XL', 'Ceil Blue',  'C-008', 'IN_SERVICE', 27),
    ('Lab Coat',       'XL', 'White',      'C-008', 'IN_SERVICE', 15),
    ('Patient Gown',   'OS', 'Blue Print', 'C-008', 'IN_SERVICE', 60),
    ('Patient Gown',   'OS', 'Blue Print', 'C-013', 'IN_SERVICE', 72),
    ('Chef Coat',      'L',  'White',      'C-004', 'IN_SERVICE', 36),
    ('Chef Coat',      'M',  'White',      'C-007', 'IN_SERVICE', 40),
    ('Apron',          'OS', 'Black',      'C-004', 'IN_SERVICE', 55),
    ('Apron',          'OS', 'Black',      'C-007', 'IN_SERVICE', 48),
    ('Apron',          'OS', 'White',      'C-014', 'IN_SERVICE', 33),
    ('Table Linen',    'OS', 'White',      'C-002', 'IN_SERVICE', 80),
    ('Table Linen',    'OS', 'White',      'C-005', 'IN_SERVICE', 65),
    ('Napkin Set',     'OS', 'White',      'C-002', 'IN_SERVICE', 90),
    ('Bed Sheet',      'King','White',     'C-002', 'IN_SERVICE', 75),
    ('Bed Sheet',      'Queen','White',    'C-005', 'IN_SERVICE', 70),
    ('Bath Towel',     'OS', 'White',      'C-005', 'IN_SERVICE', 85),
    ('Bath Towel',     'OS', 'White',      'C-016', 'IN_SERVICE', 62),
    ('Pool Towel',     'OS', 'White',      'C-012', 'IN_SERVICE', 50),
    ('Shop Towel',     'OS', 'Red',        'C-006', 'IN_SERVICE', 95),
    ('Shop Towel',     'OS', 'Red',        'C-019', 'IN_SERVICE', 88),
    ('Coverall',       'L',  'Navy',       'C-009', 'IN_SERVICE', 42),
    ('Coverall',       'XL', 'Navy',       'C-015', 'IN_SERVICE', 35),
    ('Hi-Vis Vest',    'L',  'Orange',     'C-009', 'IN_SERVICE', 20),
    ('Floor Mat',      'OS', 'Black',      'C-010', 'IN_SERVICE', 100),
    ('Floor Mat',      'OS', 'Black',      'C-011', 'IN_SERVICE', 90),
    ('Massage Sheet',  'OS', 'White',      'C-010', 'IN_SERVICE', 55),
    ('Dental Bib',     'OS', 'Blue',       'C-011', 'IN_SERVICE', 120),
    ('Scrubs Top',     'M',  'Wine',       'C-017', 'IN_SERVICE', 18),
    ('Scrubs Bottom',  'M',  'Wine',       'C-017', 'IN_SERVICE', 17),
    ('Lab Coat',       'S',  'White',      'C-001', 'LOST',       30),
    ('Scrubs Top',     'L',  'Navy',       'C-003', 'LOST',       48),
    ('Chef Coat',      'L',  'White',      'C-007', 'RETIRED',    110),
    ('Table Linen',    'OS', 'White',      'C-020', 'IN_SERVICE', 40)
) AS t(GARMENT_TYPE, SIZE, COLOR, CUSTOMER_ID, STATUS, WASH_COUNT),
TABLE(GENERATOR(ROWCOUNT => 40)) AS g
WHERE g.seq4() < 40;

INSERT INTO GARMENT_EVENTS (GARMENT_ID, EVENT_TYPE, EVENT_TIMESTAMP, LOCATION, SCANNER_ID, NOTES)
SELECT ge.GARMENT_ID, ge.EVENT_TYPE, ge.EVENT_TIMESTAMP, ge.LOCATION, ge.SCANNER_ID, ge.NOTES
FROM (VALUES
    ('G-0000','CHECK_IN', '2026-04-14 16:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled pickup from C-001'),
    ('G-0000','WASH',     '2026-04-14 18:30:00'::TIMESTAMP_NTZ,'Wash Line 2',   'SC-003','Standard wash cycle'),
    ('G-0000','DRY',      '2026-04-14 19:45:00'::TIMESTAMP_NTZ,'Dryer Bay 1',   'SC-004','45 min high heat'),
    ('G-0000','FOLD',     '2026-04-14 20:30:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','QC passed'),
    ('G-0000','DISPATCH', '2026-04-15 05:30:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-001 for R-001'),
    ('G-0000','DELIVER',  '2026-04-15 06:42:00'::TIMESTAMP_NTZ,'C-001 Dock',     'SC-007','Delivered to Peachtree General'),
    ('G-0001','CHECK_IN', '2026-04-14 16:05:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled pickup from C-001'),
    ('G-0001','WASH',     '2026-04-14 18:35:00'::TIMESTAMP_NTZ,'Wash Line 2',   'SC-003','Standard wash cycle'),
    ('G-0001','DRY',      '2026-04-14 19:50:00'::TIMESTAMP_NTZ,'Dryer Bay 1',   'SC-004','45 min high heat'),
    ('G-0001','FOLD',     '2026-04-14 20:35:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','QC passed'),
    ('G-0001','DISPATCH', '2026-04-15 05:30:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-001 for R-001'),
    ('G-0001','DELIVER',  '2026-04-15 06:42:00'::TIMESTAMP_NTZ,'C-001 Dock',     'SC-007','Delivered to Peachtree General'),
    ('G-0002','CHECK_IN', '2026-04-14 16:10:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled pickup from C-001'),
    ('G-0002','WASH',     '2026-04-14 18:40:00'::TIMESTAMP_NTZ,'Wash Line 1',   'SC-002','Hygienically clean cycle'),
    ('G-0002','DRY',      '2026-04-14 20:00:00'::TIMESTAMP_NTZ,'Dryer Bay 2',   'SC-004','60 min high heat'),
    ('G-0002','FOLD',     '2026-04-14 21:00:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','QC passed'),
    ('G-0002','DISPATCH', '2026-04-15 05:30:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-001 for R-001'),
    ('G-0002','DELIVER',  '2026-04-15 06:42:00'::TIMESTAMP_NTZ,'C-001 Dock',     'SC-007','Delivered to Peachtree General'),
    ('G-0012','CHECK_IN', '2026-04-14 14:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled from C-004'),
    ('G-0012','WASH',     '2026-04-14 16:00:00'::TIMESTAMP_NTZ,'Wash Line 3',   'SC-003','Grease-cut cycle'),
    ('G-0012','DRY',      '2026-04-14 17:30:00'::TIMESTAMP_NTZ,'Dryer Bay 3',   'SC-004','50 min medium heat'),
    ('G-0012','FOLD',     '2026-04-14 18:15:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','Minor stain noted'),
    ('G-0012','DISPATCH', '2026-04-15 05:45:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-005 for R-005'),
    ('G-0012','DELIVER',  '2026-04-15 06:56:00'::TIMESTAMP_NTZ,'C-004 Dock',     'SC-007','Delivered to Southern Grill'),
    ('G-0017','CHECK_IN', '2026-04-13 10:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled from C-002'),
    ('G-0017','WASH',     '2026-04-13 12:00:00'::TIMESTAMP_NTZ,'Wash Line 1',   'SC-002','Delicate linen cycle'),
    ('G-0017','DRY',      '2026-04-13 13:30:00'::TIMESTAMP_NTZ,'Dryer Bay 1',   'SC-004','Low heat press dry'),
    ('G-0017','FOLD',     '2026-04-13 14:15:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','Pressed and folded'),
    ('G-0017','DISPATCH', '2026-04-14 05:30:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-002 for R-002'),
    ('G-0017','DELIVER',  '2026-04-14 07:06:00'::TIMESTAMP_NTZ,'C-002 Dock',     'SC-007','Delivered to Buckhead Grand'),
    ('G-0025','CHECK_IN', '2026-04-14 15:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled from C-006'),
    ('G-0025','WASH',     '2026-04-14 17:00:00'::TIMESTAMP_NTZ,'Wash Line 3',   'SC-003','Industrial degreaser cycle'),
    ('G-0025','DRY',      '2026-04-14 18:30:00'::TIMESTAMP_NTZ,'Dryer Bay 3',   'SC-004','High heat tumble'),
    ('G-0025','FOLD',     '2026-04-14 19:15:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','QC passed'),
    ('G-0025','DISPATCH', '2026-04-15 06:00:00'::TIMESTAMP_NTZ,'Loading Dock',   'SC-006','Loaded on V-003 for R-003'),
    ('G-0036','CHECK_IN', '2026-04-10 14:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled from C-001'),
    ('G-0036','WASH',     '2026-04-10 16:00:00'::TIMESTAMP_NTZ,'Wash Line 1',   'SC-002','Standard cycle'),
    ('G-0036','LOST',     '2026-04-10 17:30:00'::TIMESTAMP_NTZ,'Wash Line 1',   'SC-002','RFID not detected post-wash -- marked lost'),
    ('G-0037','CHECK_IN', '2026-04-08 10:00:00'::TIMESTAMP_NTZ,'Receiving Dock','SC-001','Soiled from C-003'),
    ('G-0037','WASH',     '2026-04-08 12:00:00'::TIMESTAMP_NTZ,'Wash Line 2',   'SC-003','Standard cycle'),
    ('G-0037','DRY',      '2026-04-08 13:30:00'::TIMESTAMP_NTZ,'Dryer Bay 2',   'SC-004','Standard dry'),
    ('G-0037','LOST',     '2026-04-08 14:00:00'::TIMESTAMP_NTZ,'Finishing Area', 'SC-005','Not found during sort -- marked lost')
) AS ge(GARMENT_ID, EVENT_TYPE, EVENT_TIMESTAMP, LOCATION, SCANNER_ID, NOTES);

INSERT INTO GL_CODES (GL_CODE, GL_NAME, GL_CATEGORY, GL_TYPE) VALUES
    ('4100', 'Uniform Rental Revenue',      'Revenue',         'REVENUE'),
    ('4200', 'Linen Service Revenue',        'Revenue',         'REVENUE'),
    ('4300', 'Floor Mat Revenue',            'Revenue',         'REVENUE'),
    ('4400', 'Specialty Services Revenue',   'Revenue',         'REVENUE'),
    ('5100', 'Laundry Processing',           'COGS',            'EXPENSE'),
    ('5200', 'Garment Replacement',          'COGS',            'EXPENSE'),
    ('5300', 'Delivery & Logistics',         'COGS',            'EXPENSE'),
    ('5400', 'Plant Supplies',               'COGS',            'EXPENSE'),
    ('6100', 'Sales & Marketing',            'Operating Expense','EXPENSE'),
    ('6200', 'General & Administrative',     'Operating Expense','EXPENSE'),
    ('6300', 'Fleet Maintenance',            'Operating Expense','EXPENSE'),
    ('6400', 'Depreciation',                 'Operating Expense','EXPENSE'),
    ('6500', 'Insurance',                    'Operating Expense','EXPENSE'),
    ('6600', 'Rent & Utilities',             'Operating Expense','EXPENSE'),
    ('6700', 'IT & Systems',                 'Operating Expense','EXPENSE');

INSERT INTO FINANCIAL_ACTUALS (PERIOD_ID, FISCAL_YEAR, FISCAL_QUARTER, FISCAL_MONTH, GL_CODE, AMOUNT)
SELECT
    'FA-' || LPAD(ROW_NUMBER() OVER (ORDER BY m.FISCAL_MONTH, g.GL_CODE)::VARCHAR, 4, '0'),
    m.FY, m.FQ, m.FISCAL_MONTH, g.GL_CODE, g.BASE_AMT * m.MULTIPLIER * (1 + (UNIFORM(-5, 5, RANDOM()) / 100.0))
FROM (VALUES
    ('2024-04-01'::DATE, 2025, 'Q1', 1.00), ('2024-05-01'::DATE, 2025, 'Q1', 1.01),
    ('2024-06-01'::DATE, 2025, 'Q1', 0.98), ('2024-07-01'::DATE, 2025, 'Q2', 1.02),
    ('2024-08-01'::DATE, 2025, 'Q2', 1.03), ('2024-09-01'::DATE, 2025, 'Q2', 1.00),
    ('2024-10-01'::DATE, 2025, 'Q3', 1.04), ('2024-11-01'::DATE, 2025, 'Q3', 1.05),
    ('2024-12-01'::DATE, 2025, 'Q3', 0.95), ('2025-01-01'::DATE, 2025, 'Q4', 0.92),
    ('2025-02-01'::DATE, 2026, 'Q1', 1.06), ('2025-03-01'::DATE, 2026, 'Q1', 1.07),
    ('2025-04-01'::DATE, 2026, 'Q1', 1.08), ('2025-05-01'::DATE, 2026, 'Q2', 1.09),
    ('2025-06-01'::DATE, 2026, 'Q2', 1.05), ('2025-07-01'::DATE, 2026, 'Q2', 1.10),
    ('2025-08-01'::DATE, 2026, 'Q2', 1.11), ('2025-09-01'::DATE, 2026, 'Q3', 1.08),
    ('2025-10-01'::DATE, 2026, 'Q3', 1.12), ('2025-11-01'::DATE, 2026, 'Q3', 1.13),
    ('2025-12-01'::DATE, 2026, 'Q3', 1.02), ('2026-01-01'::DATE, 2026, 'Q4', 0.98),
    ('2026-02-01'::DATE, 2027, 'Q1', 1.14), ('2026-03-01'::DATE, 2027, 'Q1', 1.15)
) AS m(FISCAL_MONTH, FY, FQ, MULTIPLIER)
CROSS JOIN (VALUES
    ('4100', 95000.00), ('4200', 62000.00), ('4300', 18000.00), ('4400', 12000.00),
    ('5100', 42000.00), ('5200', 15000.00), ('5300', 22000.00), ('5400',  6500.00),
    ('6100',  8500.00), ('6200', 12000.00), ('6300',  7500.00), ('6400',  5000.00),
    ('6500',  3200.00), ('6600',  9000.00), ('6700',  4500.00)
) AS g(GL_CODE, BASE_AMT);

INSERT INTO FINANCIAL_BUDGET (PERIOD_ID, FISCAL_YEAR, FISCAL_QUARTER, FISCAL_MONTH, GL_CODE, BUDGET_AMOUNT)
SELECT
    'FB-' || LPAD(ROW_NUMBER() OVER (ORDER BY fa.FISCAL_MONTH, fa.GL_CODE)::VARCHAR, 4, '0'),
    fa.FISCAL_YEAR, fa.FISCAL_QUARTER, fa.FISCAL_MONTH, fa.GL_CODE,
    CASE
        WHEN g.GL_TYPE = 'REVENUE' THEN fa.AMOUNT * (1 + UNIFORM(2, 8, RANDOM()) / 100.0)
        ELSE fa.AMOUNT * (1 - UNIFORM(1, 5, RANDOM()) / 100.0)
    END
FROM FINANCIAL_ACTUALS fa
JOIN GL_CODES g ON fa.GL_CODE = g.GL_CODE;

INSERT INTO INVOICES (INVOICE_ID, CUSTOMER_ID, INVOICE_DATE, DUE_DATE, TOTAL_AMOUNT, PAYMENT_STATUS, PAID_DATE)
SELECT
    'INV-' || LPAD(ROW_NUMBER() OVER (ORDER BY i.INVOICE_DATE, i.CUSTOMER_ID)::VARCHAR, 4, '0'),
    i.CUSTOMER_ID, i.INVOICE_DATE, DATEADD('day', 30, i.INVOICE_DATE),
    i.TOTAL_AMOUNT, i.PAYMENT_STATUS, i.PAID_DATE
FROM (VALUES
    ('C-001','2026-03-01'::DATE, 4200.00,'PAID','2026-03-28'::DATE),
    ('C-001','2026-04-01'::DATE, 4350.00,'PAID','2026-04-25'::DATE),
    ('C-002','2026-03-01'::DATE, 3800.00,'PAID','2026-03-22'::DATE),
    ('C-002','2026-04-01'::DATE, 3950.00,'PENDING',NULL),
    ('C-003','2026-03-01'::DATE, 5100.00,'PAID','2026-03-30'::DATE),
    ('C-003','2026-04-01'::DATE, 5250.00,'PAID','2026-04-28'::DATE),
    ('C-004','2026-03-01'::DATE, 1200.00,'PAID','2026-03-15'::DATE),
    ('C-004','2026-04-01'::DATE, 1200.00,'PENDING',NULL),
    ('C-005','2026-03-01'::DATE, 2900.00,'PAID','2026-03-25'::DATE),
    ('C-005','2026-04-01'::DATE, 3050.00,'PENDING',NULL),
    ('C-007','2026-03-01'::DATE, 3500.00,'PAID','2026-03-20'::DATE),
    ('C-007','2026-04-01'::DATE, 3500.00,'PAID','2026-04-18'::DATE),
    ('C-008','2026-03-01'::DATE, 6200.00,'PAID','2026-03-29'::DATE),
    ('C-008','2026-04-01'::DATE, 6450.00,'PENDING',NULL),
    ('C-009','2026-03-01'::DATE, 2400.00,'PAID','2026-03-28'::DATE),
    ('C-009','2026-04-01'::DATE, 2400.00,'OVERDUE',NULL),
    ('C-013','2026-03-01'::DATE, 7500.00,'PAID','2026-03-31'::DATE),
    ('C-013','2026-04-01'::DATE, 7800.00,'PAID','2026-04-29'::DATE),
    ('C-016','2026-03-01'::DATE, 3100.00,'PAID','2026-03-18'::DATE),
    ('C-016','2026-04-01'::DATE, 3100.00,'PENDING',NULL),
    ('C-006','2026-03-15'::DATE, 1800.00,'PAID','2026-04-10'::DATE),
    ('C-010','2026-03-15'::DATE,  950.00,'PAID','2026-04-05'::DATE),
    ('C-011','2026-03-15'::DATE,  750.00,'PAID','2026-04-01'::DATE),
    ('C-012','2026-04-01'::DATE, 2100.00,'PENDING',NULL),
    ('C-014','2026-04-01'::DATE, 1600.00,'PENDING',NULL),
    ('C-015','2026-03-15'::DATE, 3200.00,'PAID','2026-04-12'::DATE),
    ('C-017','2026-04-01'::DATE, 2200.00,'PENDING',NULL),
    ('C-018','2026-04-01'::DATE,  800.00,'PENDING',NULL),
    ('C-019','2026-03-15'::DATE, 1100.00,'PAID','2026-04-08'::DATE),
    ('C-020','2026-04-01'::DATE, 1700.00,'PENDING',NULL)
) AS i(CUSTOMER_ID, INVOICE_DATE, TOTAL_AMOUNT, PAYMENT_STATUS, PAID_DATE);

INSERT INTO INVOICE_LINE_ITEMS (INVOICE_ID, SERVICE_TYPE, QUANTITY, UNIT_PRICE, LINE_TOTAL)
SELECT inv.INVOICE_ID, li.SERVICE_TYPE, li.QUANTITY, li.UNIT_PRICE, li.QUANTITY * li.UNIT_PRICE
FROM INVOICES inv
CROSS JOIN (VALUES
    ('Uniform Rental',    50, 28.00),
    ('Linen Service',     30, 35.00),
    ('Floor Mat Service', 10, 15.00)
) AS li(SERVICE_TYPE, QUANTITY, UNIT_PRICE)
WHERE inv.CUSTOMER_ID IN ('C-001','C-003','C-008','C-013');

INSERT INTO INVOICE_LINE_ITEMS (INVOICE_ID, SERVICE_TYPE, QUANTITY, UNIT_PRICE, LINE_TOTAL)
SELECT inv.INVOICE_ID, li.SERVICE_TYPE, li.QUANTITY, li.UNIT_PRICE, li.QUANTITY * li.UNIT_PRICE
FROM INVOICES inv
CROSS JOIN (VALUES
    ('Linen Service',     80, 25.00),
    ('Towel Service',     60, 12.00)
) AS li(SERVICE_TYPE, QUANTITY, UNIT_PRICE)
WHERE inv.CUSTOMER_ID IN ('C-002','C-005','C-016');
