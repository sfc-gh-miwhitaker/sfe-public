/*==============================================================================
  02_data/04_load_documents.sql
  Media Campaign Analytics — Synthetic Campaign Documents
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  ~60 documents across 4 types:
    - Campaign Briefs (strategy + objectives for key campaigns)
    - Creative Copy (ad headlines, body, CTAs)
    - Channel Strategy (why a channel was chosen for a client)
    - Client Notes (relationship context, preferences, history)
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

INSERT INTO DOC_CAMPAIGN_CONTENT (DOC_ID, CLIENT_ID, CAMPAIGN_ID, DOC_TYPE, TITLE, CONTENT, CREATED_DATE)
VALUES
-- ══════════════════════════════════════════════════════════════════════════════
-- CLIENT NOTES (no specific campaign — account-level context)
-- ══════════════════════════════════════════════════════════════════════════════
(1, 1, NULL, 'Client Notes', 'Client Alpha — Account Overview',
 'Client Alpha is an Enterprise-tier retail brand with 400+ physical stores and a rapidly growing DTC e-commerce business. Primary KPI is blended ROAS across all channels. Their CMO is data-driven and expects weekly performance summaries with channel-level attribution. They have historically over-indexed on paid search and are open to diversifying into connected TV for brand awareness. Budget decisions are made quarterly with a 60-day planning horizon. Key contact: VP of Digital Marketing.',
 '2025-01-05'),

(2, 2, NULL, 'Client Notes', 'Client Bravo — Account Overview',
 'Client Bravo is an Enterprise financial services firm focused on lead generation for wealth management products. Strict compliance requirements limit creative flexibility — all copy must pass legal review (5-day turnaround). They prioritize cost-per-lead over ROAS and measure success at the 90-day attribution window. Social media performance has been inconsistent; they prefer paid search and display retargeting. Budget is allocated monthly from a fixed annual plan.',
 '2025-01-08'),

(3, 3, NULL, 'Client Notes', 'Client Charlie — Account Overview',
 'Client Charlie is an Enterprise healthcare brand marketing elective procedures and wellness services. HIPAA-adjacent content restrictions apply — no patient testimonials, no before/after imagery in certain channels. They measure success via consultation bookings (tracked as conversions). Connected TV has been their fastest-growing channel due to the ability to tell longer-form stories. They run seasonal campaigns aligned with insurance deductible resets (January, July).',
 '2025-01-10'),

(4, 4, NULL, 'Client Notes', 'Client Delta — Account Overview',
 'Client Delta is an Enterprise B2B technology company selling cloud infrastructure. Long sales cycles (90-180 days) make direct-response attribution challenging. They invest heavily in brand awareness via connected TV and streaming audio to stay top-of-mind with IT decision-makers. Lead gen campaigns target technical content downloads (whitepapers, webinars). Their ICP is enterprise companies with 1000+ employees in manufacturing and logistics verticals.',
 '2025-01-12'),

(5, 5, NULL, 'Client Notes', 'Client Echo — Account Overview',
 'Client Echo is an Enterprise CPG brand with a portfolio of household cleaning products. Highly seasonal business — peaks around spring cleaning (March-April) and back-to-school (August). Mass-reach channels (display, streaming audio) drive brand recall; paid search captures in-market shoppers. They A/B test creative aggressively and rotate copy every 2 weeks. ROAS targets are lower (2-3x) because they optimize for market share, not margin.',
 '2025-01-15'),

(6, 6, NULL, 'Client Notes', 'Client Foxtrot — Account Overview',
 'Client Foxtrot is a Mid-Market regional retail chain (85 locations, Southeast US). Limited digital maturity — just moved from print/radio to programmatic in 2024. Needs hand-holding on reporting. Primary goal is store traffic measured through mobile location attribution. Budget is modest but growing 30% YoY as they see results.',
 '2025-01-18'),

(7, 9, NULL, 'Client Notes', 'Client India — Account Overview',
 'Client India is a Mid-Market SaaS company selling project management tools. Product-led growth model means they value free-trial signups over raw leads. Retargeting is their highest-performing tactic — site visitors who saw a product demo page convert at 3x the rate of cold traffic. They are experimenting with streaming audio ads targeting commuters.',
 '2025-02-01'),

(8, 14, NULL, 'Client Notes', 'Client November — Account Overview',
 'Client November is an SMB cybersecurity startup targeting mid-market IT buyers. Very tight budget ($15K/month) but willing to experiment. Paid search drives most conversions. They want to build brand recognition but cannot afford connected TV at current CPMs. Social media has been their brand-building workaround.',
 '2025-02-05'),

-- ══════════════════════════════════════════════════════════════════════════════
-- CAMPAIGN BRIEFS (tied to specific campaigns)
-- ══════════════════════════════════════════════════════════════════════════════
(9, 1, 1, 'Campaign Brief', 'Client Alpha — Q1 2025 Paid Search Lead Gen Brief',
 'Objective: Drive qualified traffic to spring collection landing pages. Target audience: Women 25-44 in top 50 DMAs with household income $75K+. KPIs: CTR > 4%, CPC < $2.50, ROAS > 4x. Messaging pillars: New arrivals, limited-time offers, free shipping over $99. Competitive context: Main competitor increasing search spend 20% this quarter — we need to defend branded terms and expand non-brand coverage. Budget: $120K over 90 days. Flight: Jan 15 – Apr 15.',
 '2025-01-10'),

(10, 1, 2, 'Campaign Brief', 'Client Alpha — Spring Social Awareness Brief',
 'Objective: Build brand awareness for the spring/summer 2025 collection among new-to-brand audiences. Target: Lookalike audiences built from top 10% LTV customers. Channels: Instagram Reels and TikTok. KPIs: Reach 2M unique users, video completion rate > 30%, brand lift +5pts (measured via third-party study). Creative direction: lifestyle-first, diverse casting, outdoor settings. No hard sell — focus on brand world. Budget: $85K. Flight: Feb 1 – Mar 31.',
 '2025-01-20'),

(11, 2, 16, 'Campaign Brief', 'Client Bravo — Wealth Management Lead Gen Brief',
 'Objective: Generate qualified leads for the new robo-advisory product launch. Target: HHI $250K+, ages 35-55, currently using competitor platforms (Betterment, Wealthfront). Channels: Paid search (non-brand terms: "best robo advisor", "automated investing"). KPIs: CPL < $180, lead-to-meeting rate > 8%. Compliance notes: All claims must include "past performance" disclaimer. No guaranteed returns language. Budget: $95K. Flight: Feb 1 – Apr 30.',
 '2025-01-25'),

(12, 3, 31, 'Campaign Brief', 'Client Charlie — January Wellness Push Brief',
 'Objective: Capture demand from insurance deductible resets. Patients with new annual benefits are most likely to book elective procedures in Q1. Target: Adults 30-60 within 25-mile radius of clinic locations. Channels: Connected TV (30-second spots) + retargeting display. KPIs: Consultation bookings (target 200 in Q1), CPB < $350. Creative: Doctor testimonials, patient journey stories (no identifiable patient info). Budget: $140K. Flight: Jan 2 – Mar 31.',
 '2025-01-03'),

(13, 4, 46, 'Campaign Brief', 'Client Delta — Cloud Infrastructure Awareness Brief',
 'Objective: Position Client Delta as the #1 choice for enterprise cloud migration. Target: CIOs and VP-level IT leaders at companies with 1000+ employees in manufacturing and logistics. Channels: Connected TV (premium business content — CNBC, Bloomberg) + LinkedIn (via paid search proxy). KPIs: Aided brand awareness +10pts (pre/post survey), target 500K impressions among ICP. No direct-response expectation — this is pure top-of-funnel. Budget: $200K. Flight: Jan – Jun 2025.',
 '2025-01-08'),

(14, 5, 61, 'Campaign Brief', 'Client Echo — Spring Cleaning Campaign Brief',
 'Objective: Drive seasonal sales uplift for all-purpose cleaner and disinfectant lines. Target: Household decision-makers 25-54. Channels: Streaming audio (Spotify, iHeart) for frequency + display for reach. KPIs: Brand search lift > 15%, display CTR > 0.2%, ROAS > 2.5x. Creative: "Fresh Start" messaging — new year, new clean. Audio ads 30 seconds, casual conversational tone. Budget: $160K. Flight: Feb 15 – Apr 30.',
 '2025-02-01'),

(15, 1, 3, 'Campaign Brief', 'Client Alpha — Display Retargeting Q1 Brief',
 'Objective: Recapture site visitors who viewed products but did not purchase. Target: All site visitors in last 30 days who viewed 2+ product pages and did not convert. Exclude existing customers (suppress via CRM list). Channels: Programmatic display (Google DV360 + TTD). KPIs: ROAS > 6x, CPA < $25. Creative: Dynamic product ads showing the exact items viewed. Frequency cap: 3 impressions/user/day. Budget: $45K. Flight: Jan 1 – Mar 31.',
 '2025-01-02'),

(16, 6, 76, 'Campaign Brief', 'Client Foxtrot — Store Traffic Q1 Brief',
 'Objective: Drive foot traffic to 12 newly renovated Southeast locations. Target: Adults 18-55 within 10-mile radius of each store. Channels: Social media (geo-targeted) + display (geo-fenced mobile). KPIs: Store visits measured via Foursquare Attribution, target 5,000 incremental visits, cost per visit < $8. Creative: Grand reopening messaging, local offers, "shop local" theme. Budget: $28K. Flight: Feb 1 – Mar 15.',
 '2025-01-28'),

(17, 9, 121, 'Campaign Brief', 'Client India — Free Trial Retargeting Brief',
 'Objective: Convert product demo page visitors into free trial signups. Target: Site visitors who viewed the demo page or pricing page in last 14 days but did not start a trial. Channels: Display retargeting + social media (LinkedIn, Facebook). KPIs: Trial signup rate > 5%, CPA < $45. Creative: "See it in action — start free today" with product screenshots. Include social proof (customer logos, review scores). Budget: $18K. Flight: Ongoing (always-on).',
 '2025-02-10'),

-- ══════════════════════════════════════════════════════════════════════════════
-- CREATIVE COPY (actual ad text tied to campaigns)
-- ══════════════════════════════════════════════════════════════════════════════
(18, 1, 1, 'Creative Copy', 'Client Alpha — Paid Search Ad Copy Set A',
 'Headline 1: New Spring Styles Just Dropped | Free Shipping $99+
Headline 2: Shop the Spring Collection — 400+ New Arrivals
Headline 3: Fresh Looks for Less | Up to 30% Off Select Styles
Description 1: Discover the latest trends in women''s fashion. Free shipping on orders over $99. Easy 30-day returns. Shop now.
Description 2: Spring is here. Refresh your wardrobe with hundreds of new arrivals — from casual to cocktail. Order today, wear tomorrow.
CTA: Shop Now
Landing Page: /collections/spring-2025
Notes: A/B test headline 1 vs headline 3 for CTR. Pause underperformer after 500 clicks.',
 '2025-01-12'),

(19, 1, 2, 'Creative Copy', 'Client Alpha — Social Video Script (Instagram Reels)',
 'Format: 15-second vertical video (Instagram Reels / TikTok)
Visual: Model walking through a sunlit garden, cuts between 3 outfits
Audio: Upbeat indie track (licensed via Epidemic Sound)
Text Overlay: "Your spring uniform" (frame 1), "New drops weekly" (frame 2), brand logo (frame 3)
CTA: "Tap to explore" → deep link to app collection page
Voiceover: None — music-driven
Compliance: No price claims in this version (awareness, not conversion)
Variations: 3 versions with different model/outfit combinations for creative fatigue testing',
 '2025-01-22'),

(20, 2, 16, 'Creative Copy', 'Client Bravo — Paid Search Ad Copy (Wealth Management)',
 'Headline 1: Smarter Investing Starts Here | Robo-Advisory
Headline 2: Automated Wealth Management — Personalized for You
Headline 3: Grow Your Portfolio — AI-Powered Investment Plans
Description 1: Professional-grade portfolio management without the fees. Personalized to your goals and risk tolerance. Start with as little as $5,000.
Description 2: Join 50,000+ investors who trust automated, tax-optimized portfolios. No hidden fees. Cancel anytime.
CTA: Get Started
Disclaimer: Past performance does not guarantee future results. Investment involves risk including possible loss of principal.
Landing Page: /robo-advisory/signup
Notes: Legal approved 2025-01-22. Review expires 2025-04-22 — must re-submit for Q2.',
 '2025-01-26'),

(21, 3, 31, 'Creative Copy', 'Client Charlie — Connected TV Spot Script (30s)',
 'Title: "New Year, New You"
Duration: 30 seconds
Open: Wide shot of a confident woman walking into a modern clinic lobby. Natural light, warm tones.
:05 — Doctor (on camera): "Every January, people tell me they finally have the benefits to invest in themselves."
:12 — Montage: consultation room, patient smiling at results (no before/after), doctor reviewing plan on tablet
:18 — Doctor VO: "Whether it''s rejuvenation, wellness, or just feeling like yourself again — this is your year."
:25 — Card: Clinic logo + "Book your consultation today" + URL
:28 — Disclaimer: "Results vary. Consult with a qualified provider."
Compliance: No identifiable patient imagery. No outcome guarantees. Approved by legal 2025-01-02.',
 '2025-01-03'),

(22, 4, 46, 'Creative Copy', 'Client Delta — Connected TV Spot Script (15s)',
 'Title: "Built for Scale"
Duration: 15 seconds
:00 — Data visualization: servers scaling up in real-time, numbers climbing
:04 — VO: "When a million transactions hit at once, you need infrastructure that doesn''t flinch."
:09 — Cut to: engineer calmly sipping coffee while dashboards show green
:12 — Card: Client Delta logo + "Enterprise cloud. Zero downtime." + URL
:14 — Tagline: "Scale without the scramble."
Tone: Confident, calm, technical-but-accessible. Target audience relates to the "sipping coffee during peak traffic" moment.',
 '2025-01-10'),

(23, 5, 61, 'Creative Copy', 'Client Echo — Streaming Audio Ad (30s)',
 'Title: "Fresh Start"
Duration: 30 seconds
Format: Spotify/iHeart pre-roll
Script: [Upbeat acoustic guitar intro, 2 seconds]
"Hey — quick question. When was the last time you actually enjoyed cleaning? [pause] Yeah, us neither. But Client Echo all-purpose cleaner makes it weirdly satisfying. One spray, one wipe, done. No residue, no harsh smell, just... clean. Grab a bottle at [retailer] or order online — and maybe put on some music while you''re at it. Client Echo. A fresh start, every time."
CTA: "Find it at Target, Walmart, or clientecho.com"
Notes: Keep tone casual and conversational — NOT a "hard sell." Think friendly neighbor, not announcer.',
 '2025-02-03'),

(24, 5, 62, 'Creative Copy', 'Client Echo — Display Banner Set (Spring Cleaning)',
 'Sizes: 300x250, 728x90, 320x50, 160x600
Headline: "Spring Clean Like You Mean It"
Body (300x250): Bright green gradient background. Product hero shot (spray bottle). "All-purpose. All-natural. All yours." + CTA button "Shop Now"
Body (728x90): Horizontal product lineup (3 SKUs) + "New scents for spring" + CTA "Explore"
Animation: Subtle sparkle effect on product — 3 frames, loops once. No auto-play video.
Landing: /spring-cleaning-essentials
Frequency cap: 3/user/day across all sizes
Notes: Include "as seen in Good Housekeeping" trust badge on 300x250 only.',
 '2025-02-05'),

-- ══════════════════════════════════════════════════════════════════════════════
-- CHANNEL STRATEGY (why this channel for this client)
-- ══════════════════════════════════════════════════════════════════════════════
(25, 1, 1, 'Channel Strategy', 'Client Alpha — Paid Search Strategy Rationale',
 'Paid search is Client Alpha''s highest-converting channel (ROAS 4-5x historically) because their customers actively search for fashion terms when ready to buy. We allocate 35% of total budget here. Strategy: defend branded terms (competitor conquesting has increased 20%), expand non-brand into "spring outfits" and "women''s workwear" categories. Key risk: rising CPCs in fashion vertical — mitigate with quality score optimization and negative keyword hygiene. Monthly budget pacing review on the 15th.',
 '2025-01-08'),

(26, 1, 2, 'Channel Strategy', 'Client Alpha — Social Media Strategy Rationale',
 'Social media serves two roles for Client Alpha: (1) prospecting via lookalike audiences to find new customers at scale, and (2) mid-funnel engagement to nurture consideration. We do NOT optimize social for direct ROAS — it feeds the retargeting pool. Success metrics are reach, engagement rate, and the volume of new users added to retargeting audiences weekly. Instagram Reels and TikTok over-index for the 25-34 demo, which is Alpha''s growth segment.',
 '2025-01-08'),

(27, 1, 3, 'Channel Strategy', 'Client Alpha — Display Retargeting Strategy Rationale',
 'Display retargeting is the highest-margin tactic in Alpha''s mix (ROAS 6-8x) because we are reaching warm audiences who already showed purchase intent. We keep this always-on with dynamic creative showing viewed products. Key principles: strict frequency capping (3/day) to avoid fatigue, 30-day lookback window, suppress converters immediately. This channel''s budget is elastic — if paid search drives more site traffic, retargeting budget scales proportionally.',
 '2025-01-08'),

(28, 3, 31, 'Channel Strategy', 'Client Charlie — Connected TV Strategy Rationale',
 'Connected TV is ideal for healthcare because it allows longer-form storytelling (15-30s) that builds trust — critical for elective procedures. Unlike display or search, CTV lets us show doctor testimonials and patient journeys in a premium, brand-safe environment. We target health-conscious audiences on platforms like Hulu, Peacock, and YouTube TV. No click attribution exists for CTV, so we measure lift via pre/post brand studies and consultation booking correlation.',
 '2025-01-05'),

(29, 4, 46, 'Channel Strategy', 'Client Delta — Connected TV Strategy Rationale',
 'For a B2B company selling to CIOs, connected TV might seem unusual — but premium business content (CNBC, Bloomberg, WSJ) reaches exactly our ICP during market hours. CTV impressions among IT leaders are 3x cheaper than LinkedIn InMail and create top-of-funnel awareness that shortens sales cycles downstream. We pair CTV with display retargeting to re-engage viewers who visit the site after exposure. Attribution is multi-touch with a 90-day window.',
 '2025-01-09'),

(30, 4, 49, 'Channel Strategy', 'Client Delta — Streaming Audio Strategy Rationale',
 'Streaming audio complements Delta''s CTV presence by reaching the same IT decision-maker persona during commute hours (6-9 AM, 4-7 PM). Podcast adjacency on Spotify gives contextual relevance — targeting listeners of tech/business podcasts. Audio ads are 30s, conversational tone, ending with a branded URL. Frequency: 2-3 exposures per listener per week. Combined with CTV, this creates a surround-sound awareness effect without relying on clickable channels.',
 '2025-01-09'),

(31, 5, 61, 'Channel Strategy', 'Client Echo — Streaming Audio Strategy Rationale',
 'Streaming audio drives frequency at low cost for Echo''s spring cleaning campaign. Our target (household shoppers 25-54) over-indexes on music streaming during chores and commutes — exactly when cleaning products are top of mind. Audio CPMs are $10-20 vs $25-45 for CTV, allowing 3-4x more frequency within budget. We pair audio with display to create a visual+audio combination. Success metric: brand search lift (measured via Google Trends correlation).',
 '2025-02-01'),

(32, 6, 76, 'Channel Strategy', 'Client Foxtrot — Social Media Geo-Targeting Rationale',
 'For a regional retailer with 12 newly renovated stores, social media geo-targeting is the most cost-effective way to reach local audiences. We draw 10-mile radius fences around each store and serve carousel ads showing the new store layout, local offers, and "come see what''s new" messaging. Mobile-first creative since 80% of impressions will be on phones. Store visit measurement via Foursquare Attribution provides closed-loop measurement.',
 '2025-01-28'),

(33, 9, 121, 'Channel Strategy', 'Client India — Display Retargeting Strategy Rationale',
 'For a PLG SaaS company, display retargeting is the most efficient conversion tactic. Users who viewed the demo or pricing page are 3x more likely to start a free trial when re-engaged within 14 days. We use dynamic creative showing the specific feature pages they viewed, plus social proof overlays (customer logos, G2 rating). LinkedIn retargeting adds B2B context — showing "teams like yours use [Product]" messaging. Always-on budget, no flight dates.',
 '2025-02-10'),

-- ══════════════════════════════════════════════════════════════════════════════
-- ADDITIONAL CAMPAIGN BRIEFS (more clients for search variety)
-- ══════════════════════════════════════════════════════════════════════════════
(34, 7, 91, 'Campaign Brief', 'Client Golf — Q1 Retirement Planning Campaign Brief',
 'Objective: Generate leads for retirement planning consultations. Target: Professionals 45-65 with investable assets $500K+. Channels: Paid search (high-intent terms: "retirement planner near me", "401k rollover advisor") + display retargeting. KPIs: CPL < $200, consultation booking rate > 5%. Creative: "Your retirement. Your rules." messaging — emphasize personalization and fiduciary status. Compliance: Fiduciary disclaimer required on all ads. Budget: $42K. Flight: Jan – Mar 2025.',
 '2025-01-15'),

(35, 8, 106, 'Campaign Brief', 'Client Hotel — Telehealth Expansion Campaign Brief',
 'Objective: Drive awareness and signups for Client Hotel''s new telehealth platform. Target: Patients in rural areas (25+ miles from nearest clinic) who have visited the website. Channels: Social media (Facebook — skews older demographic in rural areas) + streaming audio (local radio station apps). KPIs: App downloads > 2,000, cost per download < $12. Creative: "Your doctor, your schedule, your couch." Emphasize convenience and board-certified providers. Budget: $22K. Flight: Feb – Apr 2025.',
 '2025-02-01'),

(36, 10, 136, 'Campaign Brief', 'Client Juliet — New Product Launch Brief',
 'Objective: Launch awareness for an organic snack bar line extension. Target: Health-conscious consumers 22-40, skewing female, urban and suburban. Channels: Social media (Instagram, TikTok — influencer seeding) + display (health/wellness publisher direct buys). KPIs: Reach 1.5M unique, engagement rate > 3%, branded search lift > 20%. Creative: "Snack smarter" — bright, minimal packaging-forward creative with ingredient transparency messaging. Budget: $55K. Flight: Mar 1 – Apr 30.',
 '2025-02-20'),

(37, 11, 151, 'Campaign Brief', 'Client Kilo — Memorial Day Sales Event Brief',
 'Objective: Drive traffic and revenue for Memorial Day weekend sale (25% off storewide). Target: Existing customers (CRM list) + past purchasers in last 12 months. Channels: Paid search (sale-specific terms) + social media (carousel ads with top deals) + display retargeting (urgency messaging). KPIs: Revenue > $800K during sale period, ROAS > 5x. Creative: "The Big Weekend — 25% Off Everything" with countdown timer in display. Budget: $35K. Flight: May 20 – May 28.',
 '2025-04-15'),

(38, 12, 166, 'Campaign Brief', 'Client Lima — Tax Season Lead Gen Brief',
 'Objective: Capture leads during tax season for financial planning services. Target: Filers with AGI > $200K who are searching for tax optimization strategies. Channels: Paid search (terms: "tax planning advisor", "reduce tax bill", "capital gains strategy"). KPIs: CPL < $150, form completion rate > 12%. Creative: "Keep more of what you earn." Messaging focuses on proactive planning, not reactive filing. Budget: $38K. Flight: Jan 15 – Apr 15.',
 '2025-01-12'),

-- ══════════════════════════════════════════════════════════════════════════════
-- ADDITIONAL CREATIVE COPY
-- ══════════════════════════════════════════════════════════════════════════════
(39, 7, 91, 'Creative Copy', 'Client Golf — Paid Search Ad Copy (Retirement)',
 'Headline 1: Plan Your Retirement With Confidence | Fiduciary Advisor
Headline 2: Personalized Retirement Plans — No Cookie-Cutter Advice
Headline 3: 401(k) Rollover? Get Expert Guidance Today
Description 1: Work with a fee-only fiduciary advisor who puts your interests first. Customized retirement plans starting at $500K in investable assets. Free initial consultation.
Description 2: Don''t leave your retirement to chance. Our certified planners build strategies for your specific goals, timeline, and risk tolerance. Schedule a call today.
CTA: Book Free Consultation
Disclaimer: Advisory services offered through [Registered Entity]. Fiduciary standard applies to investment advice only.
Landing: /retirement-consultation',
 '2025-01-18'),

(40, 8, 106, 'Creative Copy', 'Client Hotel — Social Media Ad Copy (Telehealth)',
 'Headline: Your Doctor. Your Schedule. Your Couch.
Body: Skip the drive. Skip the waiting room. Client Hotel''s new telehealth platform connects you with board-certified doctors in minutes — from wherever you are. Video visits for primary care, follow-ups, prescriptions, and more.
CTA: Download the App — First Visit Free
Visual direction: Split-screen — left shows a long rural road/clinic, right shows someone on their couch with phone. Warm, inviting colors.
Targeting notes: Facebook only (Instagram skews too young for this rural demo). Age 35-65, 25+ miles from metro area.
Variations: Version B replaces "your couch" with "your lunch break" for working professionals.',
 '2025-02-03'),

(41, 10, 136, 'Creative Copy', 'Client Juliet — TikTok Influencer Brief',
 'Campaign: Organic Snack Bar Launch
Format: TikTok creator partnership (3 creators, 2 posts each)
Brief to creators: Show the product in your real daily routine — gym bag, desk snack, kid''s lunchbox. Keep it authentic, not scripted. Mention: clean ingredients (you can actually pronounce them), tastes amazing, available at [retailers].
Hashtags: #SnackSmarter #CleanSnacking #ClientJuliet (branded)
Dos: Show ingredient list close-up, genuine reaction to taste, creative packaging shots
Don''ts: No health claims ("helps you lose weight"), no competitor mentions, no prices
Payment: $3,500/creator + product + $500 bonus if post hits 100K views
Usage rights: 60 days paid amplification rights after organic post.',
 '2025-02-22'),

-- ══════════════════════════════════════════════════════════════════════════════
-- ADDITIONAL CHANNEL STRATEGY NOTES
-- ══════════════════════════════════════════════════════════════════════════════
(42, 2, 16, 'Channel Strategy', 'Client Bravo — Paid Search Strategy (Financial Services)',
 'Paid search is the workhorse for Bravo''s lead generation because prospects actively searching "robo advisor" or "automated investing" are high-intent. We bid aggressively on non-brand terms in the $5-8 CPC range — expensive but qualified. Brand defense is critical as competitor spend has increased 40% YoY in fintech terms. Key constraint: landing page must include a compliance footer which reduces above-the-fold CTA visibility. We compensate with expanded sitelinks.',
 '2025-01-25'),

(43, 2, 17, 'Channel Strategy', 'Client Bravo — Social Media Strategy (Financial Services)',
 'Social media for financial services is challenging due to compliance restrictions on claims and testimonials. Our approach: LinkedIn for B2B lead gen (targeting financial professionals as prospects), Facebook for consumer robo-advisory awareness. All social creative goes through a 5-day legal review cycle, so we plan content 3 weeks ahead. Video performs best but compliance extends review to 8 days for video. We optimize for landing page views, not engagement, due to low organic reach in finance.',
 '2025-01-25'),

(44, 14, 196, 'Channel Strategy', 'Client November — Social Media Brand Building (Startup)',
 'For a cybersecurity startup with a $15K/month budget, social media is the most cost-effective brand-building channel. We cannot afford CTV CPMs ($25-45), but social lets us build thought leadership through educational content — "Did you know?" security tips, threat landscape infographics, and short expert commentary videos. LinkedIn drives B2B awareness among IT buyers. Twitter/X provides real-time engagement with the security community. Paid amplification on best-performing organic posts only.',
 '2025-02-06'),

-- ══════════════════════════════════════════════════════════════════════════════
-- ADDITIONAL CLIENT NOTES (more depth for key clients)
-- ══════════════════════════════════════════════════════════════════════════════
(45, 1, NULL, 'Client Notes', 'Client Alpha — Q1 2025 Retrospective Notes',
 'Q1 results: Total spend $250K, blended ROAS 4.2x (above 3.8x target). Paid search carried performance (ROAS 5.1x) while social awareness campaigns were measured on reach (hit 2.1M unique, above 2M target). Display retargeting ROAS was 7.3x but volume-limited by site traffic. Action items for Q2: (1) Increase social spend to feed more users into retargeting pool, (2) Test connected TV for the first time with summer collection, (3) Explore streaming audio for "outfit inspiration" positioning.',
 '2025-04-05'),

(46, 3, NULL, 'Client Notes', 'Client Charlie — Channel Performance YTD Summary',
 'YTD through June 2025: Connected TV is clearly the winner for Client Charlie. Consultation bookings correlated 0.82 with CTV impression volume (weekly lag). Patients cite "I saw your ad on Hulu" in intake forms. Display retargeting supports CTV by re-engaging site visitors who came from CTV exposure (multi-touch attribution shows 2.3 average touchpoints before booking). Paid search captures demand but does not create it — volume follows CTV investment. Recommendation: shift 15% from display prospecting to CTV.',
 '2025-07-01'),

(47, 4, NULL, 'Client Notes', 'Client Delta — Sales Cycle Attribution Analysis',
 'Analysis period: Jan–Jun 2025. Average sales cycle: 127 days from first impression to closed deal. Connected TV impressions appear in 73% of winning deal journeys (vs 31% of lost deals). Streaming audio appears in 52% of wins. Key finding: deals exposed to both CTV + audio close 23% faster than single-channel exposure. The "surround sound" strategy is working — IT decision-makers recall the brand when sales reaches out. Attribution window must remain at 90+ days for these results to surface.',
 '2025-07-10'),

(48, 5, NULL, 'Client Notes', 'Client Echo — Creative Fatigue Analysis',
 'The spring cleaning campaign rotated creative every 2 weeks as planned. Performance data shows clear fatigue curves: CTR drops 40% by day 12 of the same creative, recovers immediately on rotation. Streaming audio shows NO fatigue signal — same ad performs consistently across 8 weeks. Hypothesis: audio is consumed passively during chores/commutes, so repetition builds familiarity rather than annoyance. Recommendation for fall campaign: keep 2-week rotation for display, extend audio to 4-week rotation.',
 '2025-05-15'),

-- ══════════════════════════════════════════════════════════════════════════════
-- MORE CREATIVE COPY + BRIEFS FOR SEARCH VARIETY
-- ══════════════════════════════════════════════════════════════════════════════
(49, 3, 34, 'Creative Copy', 'Client Charlie — Display Retargeting Banner Copy',
 'Sizes: 300x250, 728x90, 320x50
Headline: "Ready When You Are"
Body (300x250): Warm clinic interior photo. "You visited us online — now let us welcome you in person. Book your consultation today." + CTA "Schedule Now"
Body (728x90): Doctor headshot + "Dr. [Name] is accepting new patients" + CTA "Book Online"
Frequency cap: 2/user/day (healthcare ads need lower frequency to avoid feeling invasive)
Suppression: Suppress users who already booked (CRM sync weekly)
Notes: No urgency language ("limited time", "act now") — healthcare audiences respond to trust, not pressure.',
 '2025-01-20'),

(50, 9, 121, 'Creative Copy', 'Client India — Display Retargeting Ad Copy (SaaS)',
 'Sizes: 300x250, 728x90, 160x600
Dynamic creative: Pull the specific feature page viewed from the product catalog feed.
Headline template: "Still thinking about [Feature Name]?"
Body: "[Feature Name] helps teams like yours ship 2x faster. Start your free trial — no credit card required."
Social proof overlay: G2 badge (4.7 stars) + "Trusted by 1,200+ teams"
CTA: "Start Free Trial"
Fallback (if no feature page viewed): Generic "See why 1,200 teams chose [Product]" with product screenshot.
Frequency: 2/user/day. Suppress after 14 days if no trial start (move to nurture sequence).',
 '2025-02-12'),

(51, 14, 196, 'Creative Copy', 'Client November — LinkedIn Thought Leadership Copy',
 'Format: LinkedIn sponsored content (single image + copy)
Post 1: "73% of mid-market companies experienced a ransomware attempt in 2024. Most didn''t know until it was too late. Here''s what proactive detection looks like → [link to blog]"
Post 2: "Your firewall isn''t enough. We built [Product] because endpoint detection needs to be as smart as the threats it fights. See our approach → [link to product page]"
Post 3: "Security shouldn''t require a 50-person SOC team. [Product] gives mid-market IT teams enterprise-grade protection without enterprise-grade complexity."
Visual: Dark backgrounds, subtle circuit-board patterns, green accent color (security = green).
Targeting: IT Managers, Directors, VPs at 200-2000 employee companies. Industry: all except government.',
 '2025-02-08'),

(52, 11, 151, 'Creative Copy', 'Client Kilo — Memorial Day Display Ads',
 'Sizes: 300x250, 728x90, 320x50, 300x600
Headline: "The Big Weekend — 25% Off Everything"
Body (300x250): Bold red/white/blue color scheme. Large "25% OFF" text. Product grid (4 best-sellers). Countdown timer widget showing days:hours:minutes until sale ends.
Body (300x600): Extended version with "Top Picks For You" section (dynamic product feed from on-site behavior).
Animation: Countdown timer updates in real-time (HTML5). Confetti burst on hover.
CTA: "Shop the Sale"
Urgency messaging: "Ends Monday at midnight" (added May 25 for final push)
Landing: /memorial-day-sale (dedicated LP with filtered product grid)',
 '2025-04-18'),

(53, 6, 78, 'Creative Copy', 'Client Foxtrot — Social Media Carousel (Store Reopening)',
 'Format: Facebook/Instagram carousel (5 cards)
Card 1: Store exterior with "Grand Reopening" banner — "Your store just got an upgrade"
Card 2: Interior shot of new fitting rooms — "Fitting rooms you actually want to use"
Card 3: Product display wall — "New brands. New finds. Same prices you love."
Card 4: Staff group photo — "Come say hi to the team"
Card 5: Map + offer — "Show this ad for 15% off your first visit" (geo-fenced to 10mi radius)
CTA: "Get Directions"
Targeting: Age 18-55, 10mi radius of each store. Exclude existing app users (they already know).
Budget: $180/store/week for 3 weeks post-opening.',
 '2025-02-01'),

-- Final batch: more client notes and briefs for breadth
(54, 15, 211, 'Campaign Brief', 'Client Oscar — Back-to-School Campaign Brief',
 'Objective: Drive online and in-store sales for Client Oscar''s line of sustainable lunchbox products during back-to-school season. Target: Parents 28-45 with children ages 5-14. Channels: Social media (Pinterest + Instagram — parents plan BTS purchases here) + paid search (terms: "eco-friendly lunchbox", "sustainable school supplies"). KPIs: ROAS > 3x, CAC < $18. Creative: "Pack with purpose" — emphasize BPA-free materials, dishwasher-safe, fun kid-friendly designs. Budget: $30K. Flight: Jul 15 – Sep 5.',
 '2025-06-20'),

(55, 16, 226, 'Campaign Brief', 'Client Papa — Holiday Gift Guide Campaign Brief',
 'Objective: Position Client Papa as the go-to holiday gift destination for fashion-conscious shoppers. Target: Gift buyers 25-55 (70% female). Channels: Social media (Instagram Shopping, Pinterest gift boards) + display (contextual targeting on gift guide editorial content). KPIs: Revenue $400K during Nov 15 – Dec 24, ROAS > 4x. Creative: "The Gift They Actually Want" — styled flat-lay product photography, gift-wrapping imagery, price tiers ($25/$50/$100+). Budget: $48K. Flight: Nov 1 – Dec 24.',
 '2025-10-01'),

(56, 17, 241, 'Campaign Brief', 'Client Quebec — Year-End Financial Planning Brief',
 'Objective: Generate leads for year-end tax-loss harvesting and charitable giving consultations. Target: HNW individuals ($1M+ investable) searching for tax optimization before Dec 31. Channels: Paid search (terms: "tax loss harvesting", "year-end tax planning", "charitable trust advisor") + LinkedIn (targeting CFOs and business owners). KPIs: CPL < $250 (higher threshold justified by client LTV $50K+). Creative: "Make December count — optimize before year-end." Budget: $55K. Flight: Oct 15 – Dec 20.',
 '2025-09-15'),

(57, 1, 4, 'Channel Strategy', 'Client Alpha — Connected TV Test Strategy (Q2 2025)',
 'This is Alpha''s first CTV test. Rationale: awareness channels feed downstream conversion channels. As Alpha diversifies beyond search/social/display, CTV provides premium reach at scale among fashion-forward audiences. Test plan: $40K over 8 weeks, targeting women 25-44 on Hulu/Peacock/YouTube TV during primetime. Creative: 15-second brand spots (no direct response). Measurement: pre/post brand lift study via Kantar + correlation analysis between CTV exposure and site traffic/search volume. If lift > 5pts, recommend scaling to $150K/quarter in Q3.',
 '2025-04-10'),

(58, 2, 18, 'Campaign Brief', 'Client Bravo — Display Retargeting (Financial Services)',
 'Objective: Re-engage site visitors who started the robo-advisory signup but abandoned at the risk questionnaire step. Target: Abandoners from last 21 days (pixel-based audience). Channels: Programmatic display (DV360). KPIs: Form completion rate > 15% of retargeted users, CPA < $120. Creative: "Pick up where you left off — 3 minutes to your personalized plan" with a progress bar visual showing they are 60% done. Frequency cap: 2/day for 14 days, then suppress. Budget: $18K/month. Always-on.',
 '2025-02-05'),

(59, 20, NULL, 'Client Notes', 'Client Tango — Account Overview',
 'Client Tango is an SMB consumer goods brand selling premium pet food online (DTC only, no retail distribution). Small team (2 marketers) with $12K/month budget. Heavy social media presence organically (30K Instagram followers) but just starting paid. Dog and cat owners 25-45 in urban areas are the core audience. They measure success by subscription signups (recurring revenue model). Paid search captures high-intent "best organic dog food" traffic; social builds community.',
 '2025-03-01'),

(60, 20, 286, 'Campaign Brief', 'Client Tango — Subscription Launch Paid Search Brief',
 'Objective: Drive first-time subscription signups for premium pet food auto-delivery. Target: Dog/cat owners searching "organic dog food delivery", "healthy pet food subscription", "best dog food online". Channels: Paid search (Google + Bing). KPIs: CPA < $35 per first subscription, ROAS > 2x (calculated on first 3 months of subscription value). Creative: "Fresh food, delivered. Subscribe and save 20% on your first box." Highlight: human-grade ingredients, vet-formulated, cancel anytime. Budget: $8K/month. Always-on with seasonal bumps (National Pet Day, holiday gifting).',
 '2025-03-05');
