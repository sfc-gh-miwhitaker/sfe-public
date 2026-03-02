/*==============================================================================
SAMPLE DATA - Glaze & Classify
~200 international bakery products across 6 markets (US, JP, FR, MX, UK, BR).
Includes easy (English), medium (foreign language), and hard (image-only) cases.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

----------------------------------------------------------------------
-- Category Taxonomy (gold standard)
----------------------------------------------------------------------
INSERT INTO RAW_CATEGORY_TAXONOMY (category, subcategory, description, sort_order) VALUES
    ('Glazed',      'Original Glazed',      'Classic glazed ring donuts',                    1),
    ('Glazed',      'Chocolate Glazed',     'Ring donuts with chocolate glaze coating',      2),
    ('Glazed',      'Maple Glazed',         'Ring donuts with maple-flavored glaze',         3),
    ('Glazed',      'Strawberry Glazed',    'Ring donuts with strawberry glaze',             4),
    ('Frosted',     'Chocolate Frosted',    'Donuts topped with chocolate frosting',         5),
    ('Frosted',     'Vanilla Frosted',      'Donuts topped with vanilla frosting',           6),
    ('Frosted',     'Sprinkle Frosted',     'Frosted donuts with sprinkle toppings',         7),
    ('Filled',      'Cream Filled',         'Donuts filled with cream or custard',           8),
    ('Filled',      'Jelly Filled',         'Donuts filled with fruit jelly or jam',         9),
    ('Filled',      'Chocolate Filled',     'Donuts filled with chocolate',                  10),
    ('Cake',        'Plain Cake',           'Dense cake-style donuts',                       11),
    ('Cake',        'Blueberry Cake',       'Cake donuts with blueberry flavor',             12),
    ('Cake',        'Cinnamon Cake',        'Cake donuts with cinnamon sugar coating',       13),
    ('Specialty',   'Cruller',              'Twisted or French-style cruller donuts',         14),
    ('Specialty',   'Old Fashioned',        'Traditional old fashioned donuts',              15),
    ('Specialty',   'Bear Claw',            'Pastry with almond filling',                   16),
    ('Seasonal',    'Pumpkin Spice',        'Fall seasonal pumpkin-flavored items',          17),
    ('Seasonal',    'Peppermint',           'Winter seasonal peppermint items',              18),
    ('Seasonal',    'Sakura',               'Spring seasonal cherry blossom items (Japan)',  19),
    ('Beverages',   'Hot Coffee',           'Brewed coffee beverages',                      20),
    ('Beverages',   'Iced Coffee',          'Cold coffee beverages',                        21),
    ('Beverages',   'Hot Chocolate',        'Chocolate-based hot beverages',                22),
    ('Merchandise', 'Apparel',              'Branded clothing items',                       23),
    ('Merchandise', 'Accessories',          'Branded accessories and gifts',                24);

----------------------------------------------------------------------
-- Keyword map for traditional SQL classification
----------------------------------------------------------------------
INSERT INTO RAW_KEYWORD_MAP (keyword, language_code, mapped_category, mapped_subcategory, priority) VALUES
    ('glazed',          'en', 'Glazed',     'Original Glazed',      10),
    ('original glazed', 'en', 'Glazed',     'Original Glazed',      1),
    ('chocolate glaze', 'en', 'Glazed',     'Chocolate Glazed',     1),
    ('maple glaze',     'en', 'Glazed',     'Maple Glazed',         1),
    ('maple',           'en', 'Glazed',     'Maple Glazed',         50),
    ('strawberry glaze','en', 'Glazed',     'Strawberry Glazed',    1),
    ('frosted',         'en', 'Frosted',    'Chocolate Frosted',    50),
    ('chocolate frost', 'en', 'Frosted',    'Chocolate Frosted',    1),
    ('vanilla frost',   'en', 'Frosted',    'Vanilla Frosted',      1),
    ('sprinkle',        'en', 'Frosted',    'Sprinkle Frosted',     10),
    ('cream filled',    'en', 'Filled',     'Cream Filled',         1),
    ('custard',         'en', 'Filled',     'Cream Filled',         10),
    ('jelly filled',    'en', 'Filled',     'Jelly Filled',         1),
    ('jam',             'en', 'Filled',     'Jelly Filled',         50),
    ('chocolate filled','en', 'Filled',     'Chocolate Filled',     1),
    ('cake donut',      'en', 'Cake',       'Plain Cake',           10),
    ('cake doughnut',   'en', 'Cake',       'Plain Cake',           10),
    ('blueberry cake',  'en', 'Cake',       'Blueberry Cake',       1),
    ('cinnamon',        'en', 'Cake',       'Cinnamon Cake',        20),
    ('cruller',         'en', 'Specialty',  'Cruller',              1),
    ('old fashioned',   'en', 'Specialty',  'Old Fashioned',        1),
    ('bear claw',       'en', 'Specialty',  'Bear Claw',            1),
    ('pumpkin',         'en', 'Seasonal',   'Pumpkin Spice',        10),
    ('peppermint',      'en', 'Seasonal',   'Peppermint',           10),
    ('coffee',          'en', 'Beverages',  'Hot Coffee',           50),
    ('iced coffee',     'en', 'Beverages',  'Iced Coffee',          1),
    ('hot chocolate',   'en', 'Beverages',  'Hot Chocolate',        1),
    ('t-shirt',         'en', 'Merchandise','Apparel',              1),
    ('hoodie',          'en', 'Merchandise','Apparel',              1),
    ('mug',             'en', 'Merchandise','Accessories',          1);

----------------------------------------------------------------------
-- US Market (en) — 50 products: straightforward English names
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('Original Glazed Donut',           'Our signature ring donut with a warm sugar glaze',                     'US', 'en', 'https://images.example.com/us/original-glazed.jpg',        'Donuts > Glazed',          1.29, 'USD', FALSE, 'Glazed', 'Original Glazed'),
    ('Chocolate Glazed Ring',           'Classic ring donut dipped in rich chocolate glaze',                     'US', 'en', 'https://images.example.com/us/choc-glazed.jpg',            'Donuts > Glazed',          1.49, 'USD', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Maple Glazed Donut',              'Ring donut with sweet maple-flavored glaze',                           'US', 'en', 'https://images.example.com/us/maple-glazed.jpg',           'Donuts > Glazed',          1.49, 'USD', FALSE, 'Glazed', 'Maple Glazed'),
    ('Strawberry Glazed Ring',          'Ring donut with a pink strawberry glaze finish',                       'US', 'en', 'https://images.example.com/us/strawberry-glazed.jpg',      'Donuts > Glazed',          1.49, 'USD', FALSE, 'Glazed', 'Strawberry Glazed'),
    ('Chocolate Frosted Donut',         'Raised donut with thick chocolate frosting',                           'US', 'en', 'https://images.example.com/us/choc-frosted.jpg',           'Donuts > Frosted',         1.59, 'USD', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('Vanilla Frosted with Sprinkles',  'Raised donut with vanilla frosting and rainbow sprinkles',             'US', 'en', 'https://images.example.com/us/vanilla-sprinkle.jpg',       'Donuts > Frosted',         1.59, 'USD', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('Bavarian Cream Filled',           'Shell donut filled with rich Bavarian cream',                          'US', 'en', 'https://images.example.com/us/bavarian-cream.jpg',         'Donuts > Filled',          1.79, 'USD', FALSE, 'Filled', 'Cream Filled'),
    ('Raspberry Jelly Filled',          'Shell donut bursting with raspberry jelly',                            'US', 'en', 'https://images.example.com/us/raspberry-jelly.jpg',        'Donuts > Filled',          1.79, 'USD', FALSE, 'Filled', 'Jelly Filled'),
    ('Chocolate Kreme Filled',          'Shell donut filled with chocolate kreme',                              'US', 'en', 'https://images.example.com/us/choc-kreme.jpg',             'Donuts > Filled',          1.79, 'USD', FALSE, 'Filled', 'Chocolate Filled'),
    ('Plain Cake Donut',                'Dense, satisfying cake donut with a crispy exterior',                  'US', 'en', 'https://images.example.com/us/plain-cake.jpg',             'Donuts > Cake',            1.29, 'USD', FALSE, 'Cake', 'Plain Cake'),
    ('Blueberry Cake Donut',            'Cake donut loaded with blueberry flavor',                              'US', 'en', 'https://images.example.com/us/blueberry-cake.jpg',         'Donuts > Cake',            1.49, 'USD', FALSE, 'Cake', 'Blueberry Cake'),
    ('Cinnamon Sugar Cake Ring',        'Cake donut rolled in cinnamon and sugar',                              'US', 'en', 'https://images.example.com/us/cinnamon-cake.jpg',          'Donuts > Cake',            1.49, 'USD', FALSE, 'Cake', 'Cinnamon Cake'),
    ('French Cruller',                  'Light, airy twisted cruller with honey glaze',                         'US', 'en', 'https://images.example.com/us/cruller.jpg',                'Donuts > Specialty',       1.69, 'USD', FALSE, 'Specialty', 'Cruller'),
    ('Old Fashioned Donut',             'Traditional old fashioned sour cream donut',                           'US', 'en', 'https://images.example.com/us/old-fashioned.jpg',          'Donuts > Specialty',       1.49, 'USD', FALSE, 'Specialty', 'Old Fashioned'),
    ('Almond Bear Claw',               'Flaky pastry with almond paste filling',                               'US', 'en', 'https://images.example.com/us/bear-claw.jpg',              'Pastry > Specialty',       2.29, 'USD', FALSE, 'Specialty', 'Bear Claw'),
    ('Pumpkin Spice Glazed',            'Limited edition fall glazed donut with pumpkin spice',                  'US', 'en', 'https://images.example.com/us/pumpkin-spice.jpg',          'Seasonal > Fall',          1.79, 'USD', TRUE,  'Seasonal', 'Pumpkin Spice'),
    ('Peppermint Mocha Frosted',        'Winter seasonal donut with peppermint mocha frosting',                 'US', 'en', 'https://images.example.com/us/peppermint.jpg',             'Seasonal > Winter',        1.79, 'USD', TRUE,  'Seasonal', 'Peppermint'),
    ('House Blend Coffee (Medium)',      'Freshly brewed medium roast coffee',                                  'US', 'en', 'https://images.example.com/us/coffee-medium.jpg',          'Drinks > Coffee',          2.49, 'USD', FALSE, 'Beverages', 'Hot Coffee'),
    ('Iced Vanilla Latte',              'Cold-brewed espresso with vanilla and milk over ice',                  'US', 'en', 'https://images.example.com/us/iced-latte.jpg',             'Drinks > Iced',            3.99, 'USD', FALSE, 'Beverages', 'Iced Coffee'),
    ('Rich Hot Chocolate',              'Velvety hot chocolate made with real cocoa',                           'US', 'en', 'https://images.example.com/us/hot-choc.jpg',               'Drinks > Hot',             3.49, 'USD', FALSE, 'Beverages', 'Hot Chocolate'),
    ('Logo T-Shirt',                    'Cotton tee with our iconic logo',                                      'US', 'en', 'https://images.example.com/us/tshirt.jpg',                 'Merch',                    19.99,'USD', FALSE, 'Merchandise', 'Apparel'),
    ('Ceramic Donut Mug',              'Glazed ceramic mug shaped like a donut',                                'US', 'en', 'https://images.example.com/us/mug.jpg',                   'Merch',                    14.99,'USD', FALSE, 'Merchandise', 'Accessories'),
    ('Double Chocolate Glazed',         'Extra chocolate glaze with cocoa drizzle',                              'US', 'en', 'https://images.example.com/us/double-choc.jpg',            'Donuts > Glazed',          1.79, 'USD', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Strawberry Cream Cheese Filled',  'Shell donut with strawberry cream cheese filling',                     'US', 'en', 'https://images.example.com/us/straw-cream.jpg',            'Donuts > Filled',          1.99, 'USD', FALSE, 'Filled', 'Cream Filled'),
    ('Vanilla Glazed Cruller',          'Twisted cruller with vanilla bean glaze',                               'US', 'en', 'https://images.example.com/us/vanilla-cruller.jpg',        'Donuts > Specialty',       1.69, 'USD', FALSE, 'Specialty', 'Cruller'),
    ('Maple Bacon Bar',                 'Long john donut with maple glaze and bacon bits',                      'US', 'en', 'https://images.example.com/us/maple-bacon.jpg',            'Donuts > Specialty',       2.49, 'USD', FALSE, 'Glazed', 'Maple Glazed'),
    ('Powdered Sugar Donut Holes',      'Bite-sized donut holes dusted in powdered sugar',                      'US', 'en', 'https://images.example.com/us/donut-holes.jpg',            'Donuts > Bites',           3.99, 'USD', FALSE, 'Cake', 'Plain Cake'),
    ('Glazed Blueberry Cake Ring',      'Cake donut with blueberry and a thin glaze',                           'US', 'en', 'https://images.example.com/us/glazed-blueberry.jpg',       'Donuts > Cake',            1.59, 'USD', FALSE, 'Cake', 'Blueberry Cake'),
    ('Chocolate Iced with Custard',     'Chocolate-topped ring filled with vanilla custard',                    'US', 'en', 'https://images.example.com/us/choc-custard.jpg',           'Donuts > Filled',          1.89, 'USD', FALSE, 'Filled', 'Cream Filled'),
    ('Caramel Iced Coffee',             'Cold brew with caramel drizzle over ice',                               'US', 'en', 'https://images.example.com/us/caramel-iced.jpg',           'Drinks > Iced',            4.29, 'USD', FALSE, 'Beverages', 'Iced Coffee'),
    ('Branded Hoodie',                  'Cozy pullover hoodie with embroidered logo',                            'US', 'en', 'https://images.example.com/us/hoodie.jpg',                 'Merch',                    39.99,'USD', FALSE, 'Merchandise', 'Apparel'),
    ('Dulce de Leche Filled',           'Shell donut filled with dulce de leche caramel',                       'US', 'en', 'https://images.example.com/us/dulce.jpg',                  'Donuts > Filled',          1.99, 'USD', FALSE, 'Filled', 'Cream Filled'),
    ('Cinnamon Toast Crunch Donut',     'Frosted donut coated in cinnamon cereal crumbles',                     'US', 'en', 'https://images.example.com/us/cinnamon-crunch.jpg',        'Donuts > Specialty',       2.29, 'USD', FALSE, 'Cake', 'Cinnamon Cake');

----------------------------------------------------------------------
-- JP Market (ja) — 35 products: Japanese katakana/hiragana names
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('オリジナル グレーズド',             'シグネチャーリングドーナツ、温かいシュガーグレーズ付き',                    'JP', 'ja', 'https://images.example.com/jp/original-glazed.jpg',        'ドーナツ > グレーズド',     180, 'JPY', FALSE, 'Glazed', 'Original Glazed'),
    ('チョコレート グレーズド リング',     '濃厚なチョコレートグレーズでコーティングしたリングドーナツ',                'JP', 'ja', 'https://images.example.com/jp/choc-glazed.jpg',            'ドーナツ > グレーズド',     210, 'JPY', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('メープル グレーズド',               'メープル風味のグレーズをかけたリングドーナツ',                              'JP', 'ja', 'https://images.example.com/jp/maple-glazed.jpg',           'ドーナツ > グレーズド',     210, 'JPY', FALSE, 'Glazed', 'Maple Glazed'),
    ('チョコレート フロスト',             '厚いチョコレートフロスティングのドーナツ',                                  'JP', 'ja', 'https://images.example.com/jp/choc-frosted.jpg',           'ドーナツ > フロスト',       230, 'JPY', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('バニラ スプリンクル',               'バニラフロスティングとレインボースプリンクルのドーナツ',                    'JP', 'ja', 'https://images.example.com/jp/vanilla-sprinkle.jpg',       'ドーナツ > フロスト',       230, 'JPY', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('カスタード クリーム',               'なめらかなカスタードクリームをたっぷり詰めたドーナツ',                      'JP', 'ja', 'https://images.example.com/jp/custard.jpg',                'ドーナツ > フィルド',       250, 'JPY', FALSE, 'Filled', 'Cream Filled'),
    ('いちごジャム フィルド',             'いちごジャムがぎっしり詰まったシェルドーナツ',                              'JP', 'ja', 'https://images.example.com/jp/ichigo-jam.jpg',             'ドーナツ > フィルド',       250, 'JPY', FALSE, 'Filled', 'Jelly Filled'),
    ('抹茶グレーズド',                    '京都産抹茶を使用したグレーズドリングドーナツ',                              'JP', 'ja', 'https://images.example.com/jp/matcha-glazed.jpg',          'ドーナツ > 季節限定',       280, 'JPY', TRUE,  'Seasonal', 'Sakura'),
    ('桜もちドーナツ',                    '桜の葉で包んだもちもち食感のドーナツ',                                      'JP', 'ja', 'https://images.example.com/jp/sakura-mochi.jpg',           'ドーナツ > 季節限定',       300, 'JPY', TRUE,  'Seasonal', 'Sakura'),
    ('きなこシュガー',                    'きなこパウダーをまぶしたケーキドーナツ',                                    'JP', 'ja', 'https://images.example.com/jp/kinako.jpg',                 'ドーナツ > ケーキ',         200, 'JPY', FALSE, 'Cake', 'Cinnamon Cake'),
    ('黒ごまオールドファッション',         '黒ごまを練り込んだ和風オールドファッションドーナツ',                        'JP', 'ja', 'https://images.example.com/jp/kurogoma.jpg',               'ドーナツ > スペシャル',     230, 'JPY', FALSE, 'Specialty', 'Old Fashioned'),
    ('ホットコーヒー (レギュラー)',        'ブレンドコーヒー ホット',                                                  'JP', 'ja', 'https://images.example.com/jp/hot-coffee.jpg',             'ドリンク > コーヒー',       300, 'JPY', FALSE, 'Beverages', 'Hot Coffee'),
    ('アイスカフェラテ',                  'エスプレッソとミルクをアイスで',                                            'JP', 'ja', 'https://images.example.com/jp/iced-latte.jpg',             'ドリンク > アイス',         400, 'JPY', FALSE, 'Beverages', 'Iced Coffee'),
    ('ダブルチョコレート',                 'チョコレート生地にチョコグレーズの贅沢ドーナツ',                            'JP', 'ja', 'https://images.example.com/jp/double-choc.jpg',            'ドーナツ > グレーズド',     250, 'JPY', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('ハニーディップ',                    'はちみつグレーズのふんわりドーナツ',                                        'JP', 'ja', 'https://images.example.com/jp/honey-dip.jpg',              'ドーナツ > グレーズド',     200, 'JPY', FALSE, 'Glazed', 'Original Glazed'),
    ('ストロベリー フロスト',             'いちごフロスティングのリングドーナツ',                                      'JP', 'ja', 'https://images.example.com/jp/straw-frost.jpg',            'ドーナツ > フロスト',       230, 'JPY', FALSE, 'Frosted', 'Vanilla Frosted'),
    ('チョコカスタード',                  'チョコレートカスタードをたっぷり詰めたドーナツ',                            'JP', 'ja', 'https://images.example.com/jp/choc-custard.jpg',           'ドーナツ > フィルド',       260, 'JPY', FALSE, 'Filled', 'Chocolate Filled'),
    ('ゆずハニーグレーズド',              '柚子とはちみつのグレーズドドーナツ',                                        'JP', 'ja', 'https://images.example.com/jp/yuzu-honey.jpg',             'ドーナツ > 季節限定',       280, 'JPY', TRUE,  'Seasonal', 'Sakura'),
    ('オリジナルグレーズドダズン',         'オリジナルグレーズド12個入りボックス',                                      'JP', 'ja', 'https://images.example.com/jp/dozen-box.jpg',              'ドーナツ > セット',         1800,'JPY', FALSE, 'Glazed', 'Original Glazed'),
    ('ロゴトートバッグ',                  'アイコニックロゴ入りキャンバストートバッグ',                                'JP', 'ja', 'https://images.example.com/jp/tote.jpg',                   'グッズ',                   1500,'JPY', FALSE, 'Merchandise', 'Accessories'),
    ('紅茶ドーナツ',                      'アールグレイを練り込んだケーキドーナツ',                                    'JP', 'ja', 'https://images.example.com/jp/earl-grey.jpg',              'ドーナツ > ケーキ',         220, 'JPY', FALSE, 'Cake', 'Plain Cake'),
    ('みたらしグレーズド',                'みたらし団子風の甘じょっぱいグレーズ',                                      'JP', 'ja', 'https://images.example.com/jp/mitarashi.jpg',              'ドーナツ > グレーズド',     250, 'JPY', FALSE, 'Glazed', 'Original Glazed'),
    ('あんドーナツ',                      'つぶあんをたっぷり詰めた揚げドーナツ',                                      'JP', 'ja', 'https://images.example.com/jp/anko.jpg',                   'ドーナツ > フィルド',       230, 'JPY', FALSE, 'Filled', 'Cream Filled'),
    ('フレンチクルーラー',                '軽くてふわふわのクルーラーにハニーグレーズ',                                'JP', 'ja', 'https://images.example.com/jp/cruller.jpg',                'ドーナツ > スペシャル',     220, 'JPY', FALSE, 'Specialty', 'Cruller'),
    ('チョコファッション',                'チョコレート味のオールドファッションドーナツ',                              'JP', 'ja', 'https://images.example.com/jp/choc-fashion.jpg',           'ドーナツ > スペシャル',     220, 'JPY', FALSE, 'Specialty', 'Old Fashioned');

----------------------------------------------------------------------
-- FR Market (fr) — 30 products: French pâtisserie terms
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('Donut Glacé Original',             'Notre donut signature avec un glaçage sucré',                          'FR', 'fr', 'https://images.example.com/fr/original-glace.jpg',         'Donuts > Glacé',           1.90, 'EUR', FALSE, 'Glazed', 'Original Glazed'),
    ('Donut Glacé au Chocolat',          'Donut anneau avec glaçage riche au chocolat',                          'FR', 'fr', 'https://images.example.com/fr/choc-glace.jpg',             'Donuts > Glacé',           2.10, 'EUR', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Donut au Glaçage Érable',          'Donut avec glaçage saveur érable du Québec',                           'FR', 'fr', 'https://images.example.com/fr/erable.jpg',                 'Donuts > Glacé',           2.10, 'EUR', FALSE, 'Glazed', 'Maple Glazed'),
    ('Donut Givré Chocolat',             'Donut moelleux avec nappage chocolat épais',                           'FR', 'fr', 'https://images.example.com/fr/givre-choc.jpg',             'Donuts > Givré',           2.30, 'EUR', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('Donut Vanille et Vermicelles',     'Donut givré vanille avec vermicelles arc-en-ciel',                     'FR', 'fr', 'https://images.example.com/fr/vanille-vermi.jpg',          'Donuts > Givré',           2.30, 'EUR', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('Donut Fourré Crème Pâtissière',    'Donut fourré d''une onctueuse crème pâtissière',                       'FR', 'fr', 'https://images.example.com/fr/creme-pat.jpg',              'Donuts > Fourré',          2.50, 'EUR', FALSE, 'Filled', 'Cream Filled'),
    ('Donut Fourré Confiture Framboise', 'Donut fourré de confiture de framboises',                              'FR', 'fr', 'https://images.example.com/fr/confiture.jpg',              'Donuts > Fourré',          2.50, 'EUR', FALSE, 'Filled', 'Jelly Filled'),
    ('Donut Gâteau Nature',              'Donut dense façon gâteau avec extérieur croustillant',                 'FR', 'fr', 'https://images.example.com/fr/gateau-nature.jpg',          'Donuts > Gâteau',          1.90, 'EUR', FALSE, 'Cake', 'Plain Cake'),
    ('Cruller Français',                 'Cruller léger et aérien avec glaçage au miel',                         'FR', 'fr', 'https://images.example.com/fr/cruller.jpg',                'Donuts > Spécialité',      2.40, 'EUR', FALSE, 'Specialty', 'Cruller'),
    ('Donut Old Fashioned',              'Donut traditionnel à l''ancienne à la crème fraîche',                  'FR', 'fr', 'https://images.example.com/fr/old-fashion.jpg',            'Donuts > Spécialité',      2.10, 'EUR', FALSE, 'Specialty', 'Old Fashioned'),
    ('Café Filtre',                       'Café filtre fraîchement torréfié',                                    'FR', 'fr', 'https://images.example.com/fr/cafe.jpg',                   'Boissons > Café',          2.80, 'EUR', FALSE, 'Beverages', 'Hot Coffee'),
    ('Café Glacé Vanille',               'Espresso froid avec vanille et lait sur glace',                        'FR', 'fr', 'https://images.example.com/fr/cafe-glace.jpg',             'Boissons > Glacé',         4.20, 'EUR', FALSE, 'Beverages', 'Iced Coffee'),
    ('Chocolat Chaud Maison',            'Chocolat chaud onctueux au vrai cacao',                                'FR', 'fr', 'https://images.example.com/fr/choc-chaud.jpg',             'Boissons > Chaud',         3.80, 'EUR', FALSE, 'Beverages', 'Hot Chocolate'),
    ('Donut Fourré Chocolat Noir',       'Donut fourré de ganache au chocolat noir 70%',                         'FR', 'fr', 'https://images.example.com/fr/ganache.jpg',                'Donuts > Fourré',          2.70, 'EUR', FALSE, 'Filled', 'Chocolate Filled'),
    ('Donut Glaçage Fraise',             'Donut anneau avec glaçage rose à la fraise',                           'FR', 'fr', 'https://images.example.com/fr/fraise.jpg',                 'Donuts > Glacé',           2.10, 'EUR', FALSE, 'Glazed', 'Strawberry Glazed'),
    ('Donut Cannelle Sucre',             'Donut gâteau roulé dans le sucre cannelle',                            'FR', 'fr', 'https://images.example.com/fr/cannelle.jpg',               'Donuts > Gâteau',          2.10, 'EUR', FALSE, 'Cake', 'Cinnamon Cake'),
    ('Donut Citron Meringué',            'Donut givré avec garniture citron et meringue torchée',                'FR', 'fr', 'https://images.example.com/fr/citron-meringue.jpg',        'Donuts > Spécialité',      2.80, 'EUR', TRUE,  'Seasonal', 'Peppermint'),
    ('Donut Praline Noisette',           'Donut glacé au praliné noisette croustillant',                         'FR', 'fr', 'https://images.example.com/fr/praline.jpg',                'Donuts > Glacé',           2.50, 'EUR', FALSE, 'Glazed', 'Original Glazed'),
    ('Donut Caramel Beurre Salé',        'Donut fourré de caramel au beurre salé breton',                        'FR', 'fr', 'https://images.example.com/fr/caramel-bs.jpg',             'Donuts > Fourré',          2.70, 'EUR', FALSE, 'Filled', 'Cream Filled'),
    ('T-shirt Logo',                      'T-shirt en coton avec notre logo iconique',                           'FR', 'fr', 'https://images.example.com/fr/tshirt.jpg',                 'Boutique',                 17.90,'EUR', FALSE, 'Merchandise', 'Apparel');

----------------------------------------------------------------------
-- MX Market (es) — 30 products: Mexican Spanish names
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('Dona Glaseada Original',           'Nuestra dona insignia con glaseado de azúcar caliente',                 'MX', 'es', 'https://images.example.com/mx/original-glaseada.jpg',      'Donas > Glaseada',         29.00,'MXN', FALSE, 'Glazed', 'Original Glazed'),
    ('Dona Glaseada de Chocolate',       'Dona de anillo bañada en glaseado de chocolate',                       'MX', 'es', 'https://images.example.com/mx/choc-glaseada.jpg',          'Donas > Glaseada',         35.00,'MXN', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Dona Glaseada de Maple',           'Dona de anillo con glaseado sabor maple',                              'MX', 'es', 'https://images.example.com/mx/maple.jpg',                  'Donas > Glaseada',         35.00,'MXN', FALSE, 'Glazed', 'Maple Glazed'),
    ('Dona de Chocolate con Cobertura',  'Dona esponjosa con cobertura de chocolate espeso',                     'MX', 'es', 'https://images.example.com/mx/choc-cobertura.jpg',         'Donas > Cobertura',        39.00,'MXN', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('Dona Rellena de Crema',            'Dona rellena de crema pastelera suave',                                'MX', 'es', 'https://images.example.com/mx/crema.jpg',                  'Donas > Rellena',          42.00,'MXN', FALSE, 'Filled', 'Cream Filled'),
    ('Dona Rellena de Mermelada de Fresa','Dona rellena de mermelada de fresa natural',                          'MX', 'es', 'https://images.example.com/mx/fresa-jam.jpg',              'Donas > Rellena',          42.00,'MXN', FALSE, 'Filled', 'Jelly Filled'),
    ('Dona de Pastel con Canela',        'Dona tipo pastel espolvoreada con canela y azúcar',                    'MX', 'es', 'https://images.example.com/mx/canela.jpg',                 'Donas > Pastel',           32.00,'MXN', FALSE, 'Cake', 'Cinnamon Cake'),
    ('Dona Old Fashioned',               'Dona tradicional estilo antiguo',                                      'MX', 'es', 'https://images.example.com/mx/old-fashion.jpg',            'Donas > Especial',         35.00,'MXN', FALSE, 'Specialty', 'Old Fashioned'),
    ('Dona de Cajeta',                    'Dona rellena de cajeta artesanal',                                     'MX', 'es', 'https://images.example.com/mx/cajeta.jpg',                 'Donas > Rellena',          45.00,'MXN', FALSE, 'Filled', 'Cream Filled'),
    ('Rosca de Día de Muertos',          'Dona especial decorada para Día de Muertos',                           'MX', 'es', 'https://images.example.com/mx/dia-muertos.jpg',            'Donas > Temporada',        55.00,'MXN', TRUE,  'Seasonal', 'Pumpkin Spice'),
    ('Café Americano',                    'Café americano recién preparado',                                     'MX', 'es', 'https://images.example.com/mx/cafe.jpg',                   'Bebidas > Café',           45.00,'MXN', FALSE, 'Beverages', 'Hot Coffee'),
    ('Café Helado con Leche',            'Café helado con leche fresca',                                         'MX', 'es', 'https://images.example.com/mx/cafe-helado.jpg',            'Bebidas > Frío',           65.00,'MXN', FALSE, 'Beverages', 'Iced Coffee'),
    ('Dona Glaseada de Fresa',           'Dona de anillo con glaseado rosa de fresa',                            'MX', 'es', 'https://images.example.com/mx/fresa-glaseada.jpg',         'Donas > Glaseada',         35.00,'MXN', FALSE, 'Glazed', 'Strawberry Glazed'),
    ('Dona Rellena de Chocolate',        'Dona rellena de mousse de chocolate',                                  'MX', 'es', 'https://images.example.com/mx/choc-rellena.jpg',           'Donas > Rellena',          42.00,'MXN', FALSE, 'Filled', 'Chocolate Filled'),
    ('Dona Cubierta de Vainilla',        'Dona con cobertura de vainilla y chispas de colores',                  'MX', 'es', 'https://images.example.com/mx/vainilla-chispas.jpg',       'Donas > Cobertura',        39.00,'MXN', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('Cruller Francés',                   'Cruller ligero y esponjoso con miel',                                 'MX', 'es', 'https://images.example.com/mx/cruller.jpg',                'Donas > Especial',         38.00,'MXN', FALSE, 'Specialty', 'Cruller'),
    ('Dona de Tres Leches',              'Dona inspirada en el pastel de tres leches',                           'MX', 'es', 'https://images.example.com/mx/tres-leches.jpg',            'Donas > Especial',         48.00,'MXN', FALSE, 'Cake', 'Plain Cake'),
    ('Chocolate Caliente con Chile',     'Chocolate caliente estilo mexicano con chile ancho',                   'MX', 'es', 'https://images.example.com/mx/choc-chile.jpg',             'Bebidas > Caliente',       55.00,'MXN', FALSE, 'Beverages', 'Hot Chocolate'),
    ('Playera con Logo',                  'Playera de algodón con nuestro logo',                                 'MX', 'es', 'https://images.example.com/mx/playera.jpg',                'Tienda',                   299.00,'MXN',FALSE, 'Merchandise', 'Apparel'),
    ('Dona Churro',                       'Dona cubierta de azúcar y canela estilo churro',                      'MX', 'es', 'https://images.example.com/mx/churro.jpg',                 'Donas > Especial',         42.00,'MXN', FALSE, 'Cake', 'Cinnamon Cake');

----------------------------------------------------------------------
-- UK Market (en-GB) — 25 products: British English terminology
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('Original Glazed Doughnut',         'Our signature ring doughnut with a warm sugar glaze',                  'UK', 'en', 'https://images.example.com/uk/original-glazed.jpg',        'Doughnuts > Glazed',       1.50, 'GBP', FALSE, 'Glazed', 'Original Glazed'),
    ('Chocolate Glazed Ring',            'Ring doughnut dipped in rich chocolate glaze',                          'UK', 'en', 'https://images.example.com/uk/choc-glazed.jpg',            'Doughnuts > Glazed',       1.80, 'GBP', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Maple Glazed Doughnut',            'Ring doughnut with sweet maple-flavoured glaze',                       'UK', 'en', 'https://images.example.com/uk/maple.jpg',                  'Doughnuts > Glazed',       1.80, 'GBP', FALSE, 'Glazed', 'Maple Glazed'),
    ('Chocolate Frosted Doughnut',       'Raised doughnut with thick chocolate frosting',                        'UK', 'en', 'https://images.example.com/uk/choc-frosted.jpg',           'Doughnuts > Frosted',      1.90, 'GBP', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('Jam Doughnut',                      'Classic British jam doughnut with strawberry conserve',                'UK', 'en', 'https://images.example.com/uk/jam.jpg',                    'Doughnuts > Filled',       1.80, 'GBP', FALSE, 'Filled', 'Jelly Filled'),
    ('Custard Doughnut',                  'Ring doughnut filled with proper English custard',                     'UK', 'en', 'https://images.example.com/uk/custard.jpg',                'Doughnuts > Filled',       1.90, 'GBP', FALSE, 'Filled', 'Cream Filled'),
    ('Ring Doughnut with Hundreds and Thousands', 'Frosted doughnut with hundreds and thousands',                'UK', 'en', 'https://images.example.com/uk/hundreds.jpg',               'Doughnuts > Frosted',      1.90, 'GBP', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('Victoria Sponge Doughnut',         'Doughnut filled with jam and cream, inspired by Victoria sponge',      'UK', 'en', 'https://images.example.com/uk/victoria.jpg',               'Doughnuts > Specialty',    2.20, 'GBP', FALSE, 'Filled', 'Cream Filled'),
    ('Lemon Curd Filled',                'Doughnut filled with tangy lemon curd',                                'UK', 'en', 'https://images.example.com/uk/lemon-curd.jpg',             'Doughnuts > Filled',       2.00, 'GBP', FALSE, 'Filled', 'Cream Filled'),
    ('Flat White',                        'Velvety flat white made with specialty beans',                         'UK', 'en', 'https://images.example.com/uk/flat-white.jpg',             'Drinks > Coffee',          3.20, 'GBP', FALSE, 'Beverages', 'Hot Coffee'),
    ('Iced Americano',                   'Double-shot americano over ice',                                       'UK', 'en', 'https://images.example.com/uk/iced-americano.jpg',         'Drinks > Iced',            3.50, 'GBP', FALSE, 'Beverages', 'Iced Coffee'),
    ('Salted Caramel Doughnut',          'Glazed doughnut with salted caramel drizzle',                          'UK', 'en', 'https://images.example.com/uk/salted-caramel.jpg',         'Doughnuts > Glazed',       2.10, 'GBP', FALSE, 'Glazed', 'Original Glazed'),
    ('Biscoff Glazed',                    'Ring doughnut with Lotus Biscoff spread glaze',                       'UK', 'en', 'https://images.example.com/uk/biscoff.jpg',                'Doughnuts > Glazed',       2.20, 'GBP', FALSE, 'Glazed', 'Original Glazed'),
    ('Bonfire Toffee Doughnut',          'Seasonal toffee-glazed doughnut for Bonfire Night',                    'UK', 'en', 'https://images.example.com/uk/bonfire.jpg',                'Doughnuts > Seasonal',     2.20, 'GBP', TRUE,  'Seasonal', 'Pumpkin Spice'),
    ('Mince Pie Doughnut',               'Christmas doughnut with mincemeat filling and sugar dusting',          'UK', 'en', 'https://images.example.com/uk/mince-pie.jpg',              'Doughnuts > Seasonal',     2.30, 'GBP', TRUE,  'Seasonal', 'Peppermint');

----------------------------------------------------------------------
-- BR Market (pt-BR) — 25 products: Brazilian Portuguese
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('Donut Glaceado Original',          'Nosso donut clássico com glaceado de açúcar quente',                   'BR', 'pt', 'https://images.example.com/br/original-glaceado.jpg',      'Donuts > Glaceado',        9.90, 'BRL', FALSE, 'Glazed', 'Original Glazed'),
    ('Donut Glaceado de Chocolate',      'Donut anel coberto com glaceado de chocolate',                         'BR', 'pt', 'https://images.example.com/br/choc-glaceado.jpg',          'Donuts > Glaceado',        12.90,'BRL', FALSE, 'Glazed', 'Chocolate Glazed'),
    ('Donut Cobertura de Chocolate',     'Donut fofinho com cobertura grossa de chocolate',                      'BR', 'pt', 'https://images.example.com/br/cobertura-choc.jpg',         'Donuts > Cobertura',       13.90,'BRL', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('Donut Baunilha com Granulado',     'Donut com cobertura de baunilha e granulado colorido',                 'BR', 'pt', 'https://images.example.com/br/baunilha-gran.jpg',          'Donuts > Cobertura',       13.90,'BRL', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('Donut Recheado Creme',             'Donut recheado com creme de confeiteiro',                              'BR', 'pt', 'https://images.example.com/br/creme.jpg',                  'Donuts > Recheado',        14.90,'BRL', FALSE, 'Filled', 'Cream Filled'),
    ('Donut Recheado Goiabada',          'Donut recheado com goiabada cascão derretida',                         'BR', 'pt', 'https://images.example.com/br/goiabada.jpg',               'Donuts > Recheado',        14.90,'BRL', FALSE, 'Filled', 'Jelly Filled'),
    ('Donut Recheado Brigadeiro',        'Donut recheado com brigadeiro gourmet',                                'BR', 'pt', 'https://images.example.com/br/brigadeiro.jpg',              'Donuts > Recheado',        15.90,'BRL', FALSE, 'Filled', 'Chocolate Filled'),
    ('Donut Bolo Simples',               'Donut tipo bolo com exterior crocante',                                'BR', 'pt', 'https://images.example.com/br/bolo-simples.jpg',           'Donuts > Bolo',            9.90, 'BRL', FALSE, 'Cake', 'Plain Cake'),
    ('Donut Canela e Açúcar',            'Donut tipo bolo polvilhado com canela e açúcar',                       'BR', 'pt', 'https://images.example.com/br/canela.jpg',                 'Donuts > Bolo',            11.90,'BRL', FALSE, 'Cake', 'Cinnamon Cake'),
    ('Cruller Francês',                   'Cruller leve e aerado com glacê de mel',                              'BR', 'pt', 'https://images.example.com/br/cruller.jpg',                'Donuts > Especial',        13.90,'BRL', FALSE, 'Specialty', 'Cruller'),
    ('Café Coado',                        'Café coado fresquinho do jeito brasileiro',                           'BR', 'pt', 'https://images.example.com/br/cafe.jpg',                   'Bebidas > Café',           7.90, 'BRL', FALSE, 'Beverages', 'Hot Coffee'),
    ('Café Gelado',                       'Café gelado com leite e gelo',                                        'BR', 'pt', 'https://images.example.com/br/cafe-gelado.jpg',            'Bebidas > Gelado',         12.90,'BRL', FALSE, 'Beverages', 'Iced Coffee'),
    ('Chocolate Quente',                  'Chocolate quente cremoso feito com cacau de verdade',                  'BR', 'pt', 'https://images.example.com/br/choc-quente.jpg',            'Bebidas > Quente',         10.90,'BRL', FALSE, 'Beverages', 'Hot Chocolate'),
    ('Donut Doce de Leite',              'Donut recheado com doce de leite argentino',                           'BR', 'pt', 'https://images.example.com/br/doce-leite.jpg',             'Donuts > Recheado',        15.90,'BRL', FALSE, 'Filled', 'Cream Filled'),
    ('Donut Coco Ralado',                'Donut glaceado coberto com coco ralado',                               'BR', 'pt', 'https://images.example.com/br/coco.jpg',                   'Donuts > Glaceado',        12.90,'BRL', FALSE, 'Glazed', 'Original Glazed'),
    ('Donut Maracujá',                   'Donut com glaceado de maracujá tropical',                              'BR', 'pt', 'https://images.example.com/br/maracuja.jpg',               'Donuts > Glaceado',        13.90,'BRL', FALSE, 'Glazed', 'Strawberry Glazed'),
    ('Donut Açaí',                       'Donut especial com cobertura de açaí da Amazônia',                     'BR', 'pt', 'https://images.example.com/br/acai.jpg',                   'Donuts > Especial',        16.90,'BRL', TRUE,  'Seasonal', 'Sakura'),
    ('Donut Paçoca',                     'Donut com cobertura de paçoca triturada',                              'BR', 'pt', 'https://images.example.com/br/pacoca.jpg',                 'Donuts > Especial',        14.90,'BRL', FALSE, 'Cake', 'Cinnamon Cake'),
    ('Camiseta Logo',                     'Camiseta de algodão com nosso logo icônico',                          'BR', 'pt', 'https://images.example.com/br/camiseta.jpg',               'Loja',                     59.90,'BRL', FALSE, 'Merchandise', 'Apparel'),
    ('Donut Romeu e Julieta',            'Donut recheado com goiabada e queijo minas',                           'BR', 'pt', 'https://images.example.com/br/romeu-julieta.jpg',          'Donuts > Recheado',        16.90,'BRL', FALSE, 'Filled', 'Cream Filled');

----------------------------------------------------------------------
-- IMAGE-ONLY products (no description, various markets)
-- These are the "hard" cases for classification
----------------------------------------------------------------------
INSERT INTO RAW_PRODUCTS (product_name, product_description, market_code, language_code, image_url, raw_category_string, price_local, currency_code, is_seasonal, gold_category, gold_subcategory) VALUES
    ('IMG_4521.jpg',    NULL, 'US', 'en', 'https://images.example.com/us/img_4521_glazed_ring.jpg',              NULL, 1.29, 'USD', FALSE, 'Glazed', 'Original Glazed'),
    ('IMG_4522.jpg',    NULL, 'US', 'en', 'https://images.example.com/us/img_4522_choc_frosted.jpg',             NULL, 1.59, 'USD', FALSE, 'Frosted', 'Chocolate Frosted'),
    ('IMG_4523.jpg',    NULL, 'US', 'en', 'https://images.example.com/us/img_4523_jelly_filled.jpg',             NULL, 1.79, 'USD', FALSE, 'Filled', 'Jelly Filled'),
    ('IMG_4524.jpg',    NULL, 'JP', 'ja', 'https://images.example.com/jp/img_4524_matcha.jpg',                   NULL, 280,  'JPY', FALSE, 'Seasonal', 'Sakura'),
    ('IMG_4525.jpg',    NULL, 'FR', 'fr', 'https://images.example.com/fr/img_4525_cruller.jpg',                  NULL, 2.40, 'EUR', FALSE, 'Specialty', 'Cruller'),
    ('IMG_4526.jpg',    NULL, 'MX', 'es', 'https://images.example.com/mx/img_4526_churro.jpg',                   NULL, 42.0, 'MXN', FALSE, 'Cake', 'Cinnamon Cake'),
    ('IMG_4527.jpg',    NULL, 'UK', 'en', 'https://images.example.com/uk/img_4527_jam.jpg',                      NULL, 1.80, 'GBP', FALSE, 'Filled', 'Jelly Filled'),
    ('IMG_4528.jpg',    NULL, 'BR', 'pt', 'https://images.example.com/br/img_4528_brigadeiro.jpg',               NULL, 15.9, 'BRL', FALSE, 'Filled', 'Chocolate Filled'),
    ('IMG_4529.jpg',    NULL, 'US', 'en', 'https://images.example.com/us/img_4529_coffee.jpg',                   NULL, 2.49, 'USD', FALSE, 'Beverages', 'Hot Coffee'),
    ('IMG_4530.jpg',    NULL, 'JP', 'ja', 'https://images.example.com/jp/img_4530_sakura.jpg',                   NULL, 300,  'JPY', TRUE,  'Seasonal', 'Sakura'),
    ('product_new_01',  NULL, 'US', 'en', 'https://images.example.com/us/product_new_01_sprinkle.jpg',           NULL, 1.59, 'USD', FALSE, 'Frosted', 'Sprinkle Frosted'),
    ('product_new_02',  NULL, 'FR', 'fr', 'https://images.example.com/fr/product_new_02_creme.jpg',              NULL, 2.50, 'EUR', FALSE, 'Filled', 'Cream Filled'),
    ('商品_001',         NULL, 'JP', 'ja', 'https://images.example.com/jp/item_001_honey.jpg',                   NULL, 200,  'JPY', FALSE, 'Glazed', 'Original Glazed'),
    ('produto_sem_desc', NULL, 'BR', 'pt', 'https://images.example.com/br/produto_coco.jpg',                    NULL, 12.9, 'BRL', FALSE, 'Glazed', 'Original Glazed'),
    ('foto_nueva_03',   NULL, 'MX', 'es', 'https://images.example.com/mx/foto_nueva_03_cajeta.jpg',             NULL, 45.0, 'MXN', FALSE, 'Filled', 'Cream Filled');
