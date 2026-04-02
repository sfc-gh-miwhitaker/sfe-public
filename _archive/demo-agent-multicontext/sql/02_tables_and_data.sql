/*==============================================================================
02 - Tables and Sample Data (TV Network Theme)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-02
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA AGENT_MULTICONTEXT;

----------------------------------------------------------------------
-- Station directory
----------------------------------------------------------------------
CREATE OR REPLACE TABLE STATION_INFO (
  station_id    VARCHAR(10),
  station_name  VARCHAR(100),
  call_sign     VARCHAR(10),
  market        VARCHAR(100),
  region        VARCHAR(50),
  timezone      VARCHAR(30),
  website       VARCHAR(200)
) COMMENT = 'DEMO: Station directory (Expires: 2026-04-02)';

INSERT INTO STATION_INFO VALUES
  ('STN001', 'WETA Washington',    'WETA',  'Washington DC',    'Mid-Atlantic', 'America/New_York',    'weta.org'),
  ('STN002', 'KQED San Francisco', 'KQED',  'San Francisco',    'West',         'America/Los_Angeles', 'kqed.org'),
  ('STN003', 'WGBH Boston',        'WGBH',  'Boston',           'Northeast',    'America/New_York',    'wgbh.org'),
  ('STN004', 'WTTW Chicago',       'WTTW',  'Chicago',          'Midwest',      'America/Chicago',     'wttw.com'),
  ('STN005', 'KCET Los Angeles',   'KCET',  'Los Angeles',      'West',         'America/Los_Angeles', 'kcet.org');

----------------------------------------------------------------------
-- Programming schedule
----------------------------------------------------------------------
CREATE OR REPLACE TABLE PROGRAMMING_SCHEDULE (
  schedule_id   VARCHAR(20),
  station_id    VARCHAR(10),
  program_title VARCHAR(200),
  genre         VARCHAR(50),
  air_date      DATE,
  air_time      TIME,
  duration_min  INTEGER,
  is_premiere   BOOLEAN,
  season        INTEGER,
  episode       INTEGER
) COMMENT = 'DEMO: Programming schedule (Expires: 2026-04-02)';

INSERT INTO PROGRAMMING_SCHEDULE VALUES
  ('SCH001', 'STN001', 'Nature: Ocean Giants',          'Nature',      '2026-03-03', '20:00', 60,  TRUE,  1, 1),
  ('SCH002', 'STN001', 'NewsHour',                      'News',        '2026-03-03', '18:00', 60,  FALSE, 45, 120),
  ('SCH003', 'STN001', 'Frontline: Digital Divide',     'Documentary', '2026-03-04', '21:00', 90,  TRUE,  44, 1),
  ('SCH004', 'STN002', 'Nova: Quantum Leap',            'Science',     '2026-03-03', '21:00', 60,  TRUE,  52, 1),
  ('SCH005', 'STN002', 'This Old House',                'Home',        '2026-03-05', '19:00', 30,  FALSE, 46, 10),
  ('SCH006', 'STN003', 'Masterpiece: Austen Reimagined','Drama',       '2026-03-06', '21:00', 90,  TRUE,  55, 1),
  ('SCH007', 'STN003', 'Antiques Roadshow',             'Lifestyle',   '2026-03-04', '20:00', 60,  FALSE, 29, 15),
  ('SCH008', 'STN004', 'American Experience: Route 66', 'History',     '2026-03-05', '21:00', 120, TRUE,  37, 1),
  ('SCH009', 'STN004', 'Chicago Tonight',               'News',        '2026-03-03', '19:00', 60,  FALSE, 40, 85),
  ('SCH010', 'STN005', 'Independent Lens',              'Documentary', '2026-03-07', '22:00', 90,  FALSE, 26, 8),
  ('SCH011', 'STN001', 'PBS NewsHour Weekend',          'News',        '2026-03-08', '17:00', 30,  FALSE, 12, 22),
  ('SCH012', 'STN002', 'Forum with Michael Krasny',     'Talk',        '2026-03-03', '09:00', 60,  FALSE, 30, 150),
  ('SCH013', 'STN005', 'SoCal Connected',               'News',        '2026-03-04', '19:30', 30,  FALSE, 15, 42),
  ('SCH014', 'STN001', 'Great Performances: Met Opera', 'Arts',        '2026-03-09', '20:00', 180, TRUE,  50, 1),
  ('SCH015', 'STN003', 'Ken Burns: The National Parks', 'Documentary', '2026-03-10', '20:00', 120, FALSE, 1,  3);

----------------------------------------------------------------------
-- Viewership metrics (station-scoped, protected by RAP)
----------------------------------------------------------------------
CREATE OR REPLACE TABLE VIEWERSHIP_METRICS (
  metric_id       VARCHAR(20),
  station_id      VARCHAR(10),
  program_title   VARCHAR(200),
  air_date        DATE,
  viewers_total   INTEGER,
  viewers_18_49   INTEGER,
  rating          DECIMAL(4,2),
  share           DECIMAL(4,2),
  stream_starts   INTEGER,
  avg_watch_min   DECIMAL(6,2)
) COMMENT = 'DEMO: Viewership metrics (Expires: 2026-04-02)';

INSERT INTO VIEWERSHIP_METRICS VALUES
  ('VM001', 'STN001', 'Nature: Ocean Giants',          '2026-03-03', 285000, 72000,  2.10, 5.40, 45000,  48.20),
  ('VM002', 'STN001', 'NewsHour',                      '2026-03-03', 410000, 95000,  3.20, 7.80, 62000,  52.10),
  ('VM003', 'STN001', 'Frontline: Digital Divide',     '2026-03-04', 320000, 88000,  2.50, 6.10, 55000,  71.30),
  ('VM004', 'STN002', 'Nova: Quantum Leap',            '2026-03-03', 195000, 58000,  1.80, 4.20, 38000,  51.40),
  ('VM005', 'STN002', 'This Old House',                '2026-03-05', 165000, 32000,  1.50, 3.80, 22000,  26.80),
  ('VM006', 'STN003', 'Masterpiece: Austen Reimagined','2026-03-06', 350000, 105000, 2.80, 6.90, 72000,  78.50),
  ('VM007', 'STN003', 'Antiques Roadshow',             '2026-03-04', 275000, 48000,  2.20, 5.50, 31000,  44.60),
  ('VM008', 'STN004', 'American Experience: Route 66', '2026-03-05', 230000, 62000,  1.90, 4.60, 41000,  95.20),
  ('VM009', 'STN004', 'Chicago Tonight',               '2026-03-03', 180000, 45000,  1.60, 4.00, 28000,  42.30),
  ('VM010', 'STN005', 'Independent Lens',              '2026-03-07', 140000, 52000,  1.30, 3.20, 35000,  68.70),
  ('VM011', 'STN001', 'PBS NewsHour Weekend',          '2026-03-08', 195000, 51000,  1.50, 3.90, 33000,  24.50),
  ('VM012', 'STN002', 'Forum with Michael Krasny',     '2026-03-03', 88000,  22000,  0.80, 2.10, 15000,  38.40),
  ('VM013', 'STN005', 'SoCal Connected',               '2026-03-04', 95000,  28000,  0.90, 2.30, 18000,  22.10),
  ('VM014', 'STN001', 'Great Performances: Met Opera', '2026-03-09', 210000, 38000,  1.70, 4.30, 29000,  142.50),
  ('VM015', 'STN003', 'Ken Burns: The National Parks', '2026-03-10', 390000, 82000,  3.10, 7.50, 68000,  108.30);

----------------------------------------------------------------------
-- Member accounts (station-scoped, protected by RAP)
----------------------------------------------------------------------
CREATE OR REPLACE TABLE MEMBER_ACCOUNTS (
  member_id       VARCHAR(20),
  station_id      VARCHAR(10),
  member_name     VARCHAR(100),
  email           VARCHAR(200),
  membership_tier VARCHAR(20),
  join_date       DATE,
  renewal_date    DATE,
  annual_pledge   DECIMAL(10,2),
  lifetime_giving DECIMAL(12,2),
  is_active       BOOLEAN
) COMMENT = 'DEMO: Member accounts (Expires: 2026-04-02)';

INSERT INTO MEMBER_ACCOUNTS VALUES
  ('MBR001', 'STN001', 'Alice Johnson',   'alice@example.com',   'Sustainer',  '2019-05-10', '2026-05-10', 240.00, 1680.00,  TRUE),
  ('MBR002', 'STN001', 'Bob Chen',        'bob@example.com',     'Basic',      '2023-11-15', '2026-11-15', 60.00,  120.00,   TRUE),
  ('MBR003', 'STN001', 'Carol Martinez',  'carol@example.com',   'Leadership', '2015-02-20', '2026-02-20', 1000.00, 11000.00, TRUE),
  ('MBR004', 'STN002', 'David Kim',       'david@example.com',   'Sustainer',  '2020-08-01', '2026-08-01', 180.00, 1080.00,  TRUE),
  ('MBR005', 'STN002', 'Eve Nakamura',    'eve@example.com',     'Basic',      '2025-01-05', '2026-01-05', 60.00,  60.00,    FALSE),
  ('MBR006', 'STN003', 'Frank O''Brien',  'frank@example.com',   'Leadership', '2012-09-14', '2026-09-14', 2500.00, 35000.00, TRUE),
  ('MBR007', 'STN003', 'Grace Liu',       'grace@example.com',   'Sustainer',  '2021-03-22', '2026-03-22', 300.00, 1500.00,  TRUE),
  ('MBR008', 'STN004', 'Hank Williams',   'hank@example.com',    'Basic',      '2024-06-30', '2026-06-30', 60.00,  120.00,   TRUE),
  ('MBR009', 'STN004', 'Iris Patel',      'iris@example.com',    'Sustainer',  '2018-12-01', '2026-12-01', 360.00, 2880.00,  TRUE),
  ('MBR010', 'STN005', 'Jake Torres',     'jake@example.com',    'Basic',      '2025-07-20', '2026-07-20', 60.00,  60.00,    TRUE);

----------------------------------------------------------------------
-- Support / knowledge-base articles (used by Cortex Search)
----------------------------------------------------------------------
CREATE OR REPLACE TABLE SUPPORT_ARTICLES (
  article_id    VARCHAR(20),
  station_id    VARCHAR(10),
  category      VARCHAR(50),
  title         VARCHAR(200),
  content       VARCHAR(5000),
  last_updated  DATE
) COMMENT = 'DEMO: Support knowledge base for Cortex Search (Expires: 2026-04-02)';

INSERT INTO SUPPORT_ARTICLES VALUES
  ('ART001', NULL, 'Streaming', 'How to watch on the PBS App',
   'Download the PBS app from the App Store or Google Play. Create a free account or sign in with your local station credentials. You can stream live TV, watch on-demand episodes, and access Passport content if you are a member. Supported devices include iOS, Android, Roku, Apple TV, Amazon Fire TV, and Chromecast.',
   '2026-02-15'),
  ('ART002', NULL, 'Membership', 'PBS Passport: What is included',
   'PBS Passport is an extended on-demand library available to members who contribute $5 or more per month or $60 annually. Passport gives you access to thousands of episodes of your favorite PBS shows before they air and long after broadcast. Activate at pbs.org/passport with your station member credentials.',
   '2026-01-20'),
  ('ART003', NULL, 'Technical', 'Closed captions and audio descriptions',
   'All PBS programming includes closed captions. To enable captions, look for the CC button on your video player or in your device accessibility settings. Audio descriptions are available on select programs and can be enabled through the AD button or your device SAP/audio settings.',
   '2026-02-01'),
  ('ART004', NULL, 'Programming', 'How to find your local schedule',
   'Visit pbs.org/tv-schedules and enter your ZIP code to see programming for your local station. You can also check your station website directly. Schedules are updated weekly and may differ from the national feed due to local programming choices.',
   '2026-02-10'),
  ('ART005', 'STN001', 'Local', 'WETA events and community screenings',
   'WETA hosts regular community screenings, fundraiser galas, and educational workshops in the Washington DC metro area. Check weta.org/events for upcoming events. Members at the Leadership Circle level receive priority invitations and reserved seating.',
   '2026-03-01'),
  ('ART006', 'STN002', 'Local', 'KQED live events and forums',
   'KQED produces live community forums, podcast tapings, and film screenings throughout the San Francisco Bay Area. Events are listed at kqed.org/events. KQED members receive early access to event registration.',
   '2026-03-01'),
  ('ART007', NULL, 'Membership', 'How to renew or upgrade your membership',
   'Log in to your station account at your local station website. Navigate to My Account > Membership to renew, upgrade your tier, or update payment information. You can also call your station member services line. Sustainer members are renewed automatically each month.',
   '2026-02-20'),
  ('ART008', NULL, 'Technical', 'Troubleshooting buffering and playback issues',
   'If you experience buffering: 1) Check your internet speed (minimum 5 Mbps recommended). 2) Close other streaming apps. 3) Restart the PBS app. 4) Clear app cache in device settings. 5) Try a lower video quality setting. If issues persist, contact support at help.pbs.org.',
   '2026-01-30'),
  ('ART009', 'STN003', 'Local', 'WGBH educational resources for teachers',
   'WGBH provides free educational resources for K-12 teachers through PBS LearningMedia. Access lesson plans, interactive activities, and video clips aligned with curriculum standards at pbslearningmedia.org. WGBH also offers professional development workshops for educators in the Boston area.',
   '2026-02-25'),
  ('ART010', NULL, 'Programming', 'Kids programming and PBS KIDS app',
   'PBS KIDS offers free educational content for children ages 2-8. Download the PBS KIDS app for games and full episodes. The PBS KIDS 24/7 channel streams live programming. All content is curriculum-based and developed with educational advisors. No subscription required.',
   '2026-02-05');
