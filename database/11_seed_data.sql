-- ============================================
-- BAGS STORE - SEED DATA
-- ============================================
-- Sample data for testing and development
-- ============================================

-- ============================================
-- CATEGORIES
-- ============================================
INSERT INTO categories (id, name, name_ar, slug, description, sort_order, is_active, is_featured) VALUES
('11111111-1111-1111-1111-111111111101', 'Handbags', 'حقائب يد', 'handbags', 'Elegant handbags for everyday use', 1, TRUE, TRUE),
('11111111-1111-1111-1111-111111111102', 'Shoulder Bags', 'حقائب كتف', 'shoulder-bags', 'Stylish shoulder bags', 2, TRUE, TRUE),
('11111111-1111-1111-1111-111111111103', 'Clutches', 'كلاتش', 'clutches', 'Elegant clutches for special occasions', 3, TRUE, FALSE),
('11111111-1111-1111-1111-111111111104', 'Backpacks', 'حقائب ظهر', 'backpacks', 'Fashionable backpacks', 4, TRUE, FALSE),
('11111111-1111-1111-1111-111111111105', 'Tote Bags', 'حقائب توت', 'tote-bags', 'Spacious tote bags', 5, TRUE, TRUE);

-- ============================================
-- SUBCATEGORIES
-- ============================================
INSERT INTO subcategories (id, category_id, name, name_ar, slug, sort_order) VALUES
-- Handbags
('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101', 'Mini Bags', 'حقائب صغيرة', 'mini-bags', 1),
('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111101', 'Medium Bags', 'حقائب متوسطة', 'medium-bags', 2),
('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111101', 'Large Bags', 'حقائب كبيرة', 'large-bags', 3),
-- Shoulder Bags
('22222222-2222-2222-2222-222222222204', '11111111-1111-1111-1111-111111111102', 'Crossbody', 'كروس بودي', 'crossbody', 1),
('22222222-2222-2222-2222-222222222205', '11111111-1111-1111-1111-111111111102', 'Hobo Bags', 'هوبو', 'hobo-bags', 2);

-- ============================================
-- BRANDS
-- ============================================
INSERT INTO brands (id, name, slug, description, country_of_origin, is_featured, sort_order) VALUES
('33333333-3333-3333-3333-333333333301', 'Elegance', 'elegance', 'Premium quality bags with elegant designs', 'Italy', TRUE, 1),
('33333333-3333-3333-3333-333333333302', 'Luxe Collection', 'luxe-collection', 'Luxury bags for the discerning customer', 'France', TRUE, 2),
('33333333-3333-3333-3333-333333333303', 'Urban Style', 'urban-style', 'Modern bags for urban lifestyle', 'USA', FALSE, 3),
('33333333-3333-3333-3333-333333333304', 'Classic Heritage', 'classic-heritage', 'Timeless designs with classic appeal', 'UK', TRUE, 4),
('33333333-3333-3333-3333-333333333305', 'Avant Garde', 'avant-garde', 'Bold and innovative bag designs', 'Japan', FALSE, 5);

-- ============================================
-- PRODUCTS
-- ============================================
INSERT INTO products (id, category_id, subcategory_id, brand_id, name, name_ar, slug, sku, short_description, description, price, compare_at_price, material, is_featured, is_new_arrival, is_best_seller, is_active) VALUES
-- Handbags
('44444444-4444-4444-4444-444444444401', '11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222201', '33333333-3333-3333-3333-333333333301', 
 'Milano Mini Bag', 'حقيبة ميلانو الصغيرة', 'milano-mini-bag', 'ELG-001', 
 'Compact elegance for your essentials', 'A beautifully crafted mini bag perfect for carrying your daily essentials. Made from premium Italian leather with gold-tone hardware.',
 1250.00, 1500.00, 'Genuine Leather', TRUE, TRUE, FALSE, TRUE),

('44444444-4444-4444-4444-444444444402', '11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222202', '33333333-3333-3333-3333-333333333302', 
 'Paris Signature Bag', 'حقيبة باريس المميزة', 'paris-signature-bag', 'LXC-001', 
 'The iconic Parisian style', 'Experience the epitome of French luxury with this signature bag featuring quilted leather and chain strap.',
 2800.00, NULL, 'Quilted Leather', TRUE, FALSE, TRUE, TRUE),

('44444444-4444-4444-4444-444444444403', '11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222203', '33333333-3333-3333-3333-333333333304', 
 'Westminster Large Tote', 'حقيبة وستمنستر الكبيرة', 'westminster-large-tote', 'CLH-001', 
 'Classic British elegance', 'A spacious tote bag with timeless British design, perfect for work or weekend getaways.',
 1850.00, 2200.00, 'Full Grain Leather', FALSE, TRUE, FALSE, TRUE),

-- Shoulder Bags
('44444444-4444-4444-4444-444444444404', '11111111-1111-1111-1111-111111111102', '22222222-2222-2222-2222-222222222204', '33333333-3333-3333-3333-333333333303', 
 'Brooklyn Crossbody', 'حقيبة بروكلين كروس', 'brooklyn-crossbody', 'URB-001', 
 'Urban chic meets functionality', 'A versatile crossbody bag designed for the modern urban lifestyle with multiple compartments.',
 950.00, NULL, 'Vegan Leather', TRUE, TRUE, TRUE, TRUE),

('44444444-4444-4444-4444-444444444405', '11111111-1111-1111-1111-111111111102', '22222222-2222-2222-2222-222222222205', '33333333-3333-3333-3333-333333333301', 
 'Roma Hobo Bag', 'حقيبة روما هوبو', 'roma-hobo-bag', 'ELG-002', 
 'Effortless Italian style', 'A slouchy hobo bag that combines comfort with Italian craftsmanship.',
 1650.00, 1900.00, 'Soft Leather', FALSE, FALSE, TRUE, TRUE),

-- Clutches
('44444444-4444-4444-4444-444444444406', '11111111-1111-1111-1111-111111111103', NULL, '33333333-3333-3333-3333-333333333302', 
 'Soirée Crystal Clutch', 'كلاتش سواريه كريستال', 'soiree-crystal-clutch', 'LXC-002', 
 'Sparkle at every event', 'An exquisite evening clutch adorned with crystals, perfect for galas and special occasions.',
 1450.00, NULL, 'Satin with Crystals', TRUE, TRUE, FALSE, TRUE),

('44444444-4444-4444-4444-444444444407', '11111111-1111-1111-1111-111111111103', NULL, '33333333-3333-3333-3333-333333333305', 
 'Tokyo Minimal Clutch', 'كلاتش طوكيو البسيط', 'tokyo-minimal-clutch', 'AVG-001', 
 'Minimalist Japanese design', 'A sleek, minimalist clutch featuring innovative Japanese design principles.',
 1100.00, 1300.00, 'Recycled Materials', FALSE, TRUE, FALSE, TRUE),

-- Backpacks
('44444444-4444-4444-4444-444444444408', '11111111-1111-1111-1111-111111111104', NULL, '33333333-3333-3333-3333-333333333303', 
 'Manhattan Leather Backpack', 'حقيبة ظهر مانهاتن', 'manhattan-leather-backpack', 'URB-002', 
 'Professional meets practical', 'A sophisticated leather backpack perfect for the modern professional.',
 1750.00, NULL, 'Premium Leather', TRUE, FALSE, TRUE, TRUE),

-- Tote Bags
('44444444-4444-4444-4444-444444444409', '11111111-1111-1111-1111-111111111105', NULL, '33333333-3333-3333-3333-333333333304', 
 'Oxford Canvas Tote', 'حقيبة أكسفورد القماشية', 'oxford-canvas-tote', 'CLH-002', 
 'Casual British charm', 'A durable canvas tote with leather trim, perfect for everyday use.',
 750.00, 900.00, 'Canvas with Leather Trim', FALSE, TRUE, FALSE, TRUE),

('44444444-4444-4444-4444-444444444410', '11111111-1111-1111-1111-111111111105', NULL, '33333333-3333-3333-3333-333333333301', 
 'Venezia Summer Tote', 'حقيبة فينيسيا الصيفية', 'venezia-summer-tote', 'ELG-003', 
 'Summer in Venice', 'A vibrant summer tote inspired by Venetian artistry with woven leather details.',
 1350.00, 1600.00, 'Woven Leather', TRUE, TRUE, FALSE, TRUE);

-- ============================================
-- PRODUCT IMAGES
-- ============================================
INSERT INTO product_images (product_id, image_url, alt_text, sort_order, is_primary) VALUES
('44444444-4444-4444-4444-444444444401', 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800', 'Milano Mini Bag - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444401', 'https://images.unsplash.com/photo-1594223274512-ad4803739b7c?w=800', 'Milano Mini Bag - Detail', 2, FALSE),
('44444444-4444-4444-4444-444444444402', 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=800', 'Paris Signature Bag - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444403', 'https://images.unsplash.com/photo-1591561954555-607968c989ab?w=800', 'Westminster Large Tote - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444404', 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800', 'Brooklyn Crossbody - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444405', 'https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?w=800', 'Roma Hobo Bag - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444406', 'https://images.unsplash.com/photo-1594633313593-bab3825d0caf?w=800', 'Soirée Crystal Clutch - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444407', 'https://images.unsplash.com/photo-1612902456551-333ac5afa26e?w=800', 'Tokyo Minimal Clutch - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444408', 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800', 'Manhattan Leather Backpack - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444409', 'https://images.unsplash.com/photo-1544816155-12df9643f363?w=800', 'Oxford Canvas Tote - Main', 1, TRUE),
('44444444-4444-4444-4444-444444444410', 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=800', 'Venezia Summer Tote - Main', 1, TRUE);

-- ============================================
-- PRODUCT COLORS
-- ============================================
INSERT INTO product_colors (product_id, color_name, color_name_ar, color_hex, quantity, low_stock_threshold, sort_order) VALUES
-- Milano Mini Bag
('44444444-4444-4444-4444-444444444401', 'Black', 'أسود', '#000000', 15, 3, 1),
('44444444-4444-4444-4444-444444444401', 'Cognac', 'كونياك', '#8B4513', 10, 3, 2),
('44444444-4444-4444-4444-444444444401', 'Nude', 'بيج', '#E8D5C4', 8, 3, 3),
-- Paris Signature Bag
('44444444-4444-4444-4444-444444444402', 'Black', 'أسود', '#000000', 12, 3, 1),
('44444444-4444-4444-4444-444444444402', 'Burgundy', 'عنابي', '#722F37', 7, 3, 2),
('44444444-4444-4444-4444-444444444402', 'Navy', 'كحلي', '#1A237E', 5, 3, 3),
-- Westminster Large Tote
('44444444-4444-4444-4444-444444444403', 'Tan', 'تان', '#D2691E', 20, 5, 1),
('44444444-4444-4444-4444-444444444403', 'Black', 'أسود', '#000000', 18, 5, 2),
-- Brooklyn Crossbody
('44444444-4444-4444-4444-444444444404', 'Olive', 'زيتي', '#808000', 25, 5, 1),
('44444444-4444-4444-4444-444444444404', 'Black', 'أسود', '#000000', 30, 5, 2),
('44444444-4444-4444-4444-444444444404', 'Camel', 'جملي', '#C19A6B', 22, 5, 3),
-- Roma Hobo Bag
('44444444-4444-4444-4444-444444444405', 'Caramel', 'كراميل', '#FFD59A', 10, 3, 1),
('44444444-4444-4444-4444-444444444405', 'Black', 'أسود', '#000000', 14, 3, 2),
-- Soirée Crystal Clutch
('44444444-4444-4444-4444-444444444406', 'Silver', 'فضي', '#C0C0C0', 8, 2, 1),
('44444444-4444-4444-4444-444444444406', 'Gold', 'ذهبي', '#FFD700', 6, 2, 2),
('44444444-4444-4444-4444-444444444406', 'Rose Gold', 'روز جولد', '#B76E79', 5, 2, 3),
-- Tokyo Minimal Clutch
('44444444-4444-4444-4444-444444444407', 'White', 'أبيض', '#FFFFFF', 12, 3, 1),
('44444444-4444-4444-4444-444444444407', 'Black', 'أسود', '#000000', 15, 3, 2),
-- Manhattan Leather Backpack
('44444444-4444-4444-4444-444444444408', 'Black', 'أسود', '#000000', 20, 4, 1),
('44444444-4444-4444-4444-444444444408', 'Brown', 'بني', '#8B4513', 15, 4, 2),
-- Oxford Canvas Tote
('44444444-4444-4444-4444-444444444409', 'Navy', 'كحلي', '#1A237E', 30, 5, 1),
('44444444-4444-4444-4444-444444444409', 'Khaki', 'كاكي', '#C3B091', 25, 5, 2),
-- Venezia Summer Tote
('44444444-4444-4444-4444-444444444410', 'Natural', 'طبيعي', '#FAEBD7', 18, 4, 1),
('44444444-4444-4444-4444-444444444410', 'Indigo', 'نيلي', '#3F51B5', 12, 4, 2);

-- ============================================
-- SALES
-- ============================================
INSERT INTO sales (product_id, sale_type, sale_percentage, original_price, start_date, end_date, is_active) VALUES
('44444444-4444-4444-4444-444444444401', 'percentage', 15.00, 1500.00, NOW(), NOW() + INTERVAL '30 days', TRUE),
('44444444-4444-4444-4444-444444444403', 'percentage', 20.00, 2200.00, NOW(), NOW() + INTERVAL '30 days', TRUE),
('44444444-4444-4444-4444-444444444407', 'percentage', 15.00, 1300.00, NOW(), NOW() + INTERVAL '30 days', TRUE),
('44444444-4444-4444-4444-444444444409', 'percentage', 20.00, 900.00, NOW(), NOW() + INTERVAL '30 days', TRUE),
('44444444-4444-4444-4444-444444444410', 'percentage', 15.00, 1600.00, NOW(), NOW() + INTERVAL '30 days', TRUE);

-- ============================================
-- SHIPPING METHODS
-- ============================================
INSERT INTO shipping_methods (id, name, name_ar, code, description, base_cost, free_shipping_threshold, estimated_days_min, estimated_days_max, is_default, sort_order) VALUES
('55555555-5555-5555-5555-555555555501', 'Standard Shipping', 'الشحن العادي', 'standard', 'Delivery within 3-5 business days', 50.00, 500.00, 3, 5, TRUE, 1),
('55555555-5555-5555-5555-555555555502', 'Express Shipping', 'الشحن السريع', 'express', 'Delivery within 1-2 business days', 100.00, 1000.00, 1, 2, FALSE, 2),
('55555555-5555-5555-5555-555555555503', 'Same Day Delivery', 'التوصيل في نفس اليوم', 'same-day', 'Delivery on the same day (Cairo only)', 150.00, NULL, 0, 0, FALSE, 3);

-- ============================================
-- COUPONS
-- ============================================
INSERT INTO coupons (id, code, name, description, discount_type, discount_value, min_order_amount, max_discount_amount, usage_limit, valid_from, valid_to, is_active) VALUES
('66666666-6666-6666-6666-666666666601', 'WELCOME10', 'Welcome Discount', '10% off your first order', 'percentage', 10.00, 200.00, 100.00, NULL, NOW(), NOW() + INTERVAL '90 days', TRUE),
('66666666-6666-6666-6666-666666666602', 'SUMMER25', 'Summer Sale', '25% off summer collection', 'percentage', 25.00, 500.00, 250.00, 100, NOW(), NOW() + INTERVAL '30 days', TRUE),
('66666666-6666-6666-6666-666666666603', 'FREESHIP', 'Free Shipping', 'Free shipping on any order', 'free_shipping', 0.00, 300.00, NULL, 50, NOW(), NOW() + INTERVAL '60 days', TRUE);

-- ============================================
-- FAQ
-- ============================================
INSERT INTO faq (category, question, question_ar, answer, answer_ar, sort_order, is_featured) VALUES
('shipping', 'How long does shipping take?', 'كم يستغرق الشحن؟', 'Standard shipping takes 3-5 business days. Express shipping is available for 1-2 day delivery.', 'الشحن العادي يستغرق 3-5 أيام عمل. الشحن السريع متاح للتوصيل خلال 1-2 يوم.', 1, TRUE),
('shipping', 'Do you offer free shipping?', 'هل توفرون شحن مجاني؟', 'Yes! We offer free standard shipping on orders over 500 EGP.', 'نعم! نوفر شحن مجاني على الطلبات التي تزيد عن 500 جنيه.', 2, TRUE),
('returns', 'What is your return policy?', 'ما هي سياسة الإرجاع؟', 'We accept returns within 14 days of delivery. Items must be unused and in original packaging.', 'نقبل الإرجاع خلال 14 يوم من التوصيل. يجب أن تكون المنتجات غير مستخدمة وفي عبوتها الأصلية.', 1, TRUE),
('payment', 'What payment methods do you accept?', 'ما هي طرق الدفع المقبولة؟', 'We accept credit/debit cards (Visa, Mastercard) and cash on delivery.', 'نقبل بطاقات الائتمان/الخصم (فيزا، ماستركارد) والدفع عند الاستلام.', 1, TRUE),
('products', 'Are your bags authentic?', 'هل الحقائب أصلية؟', 'Yes, all our products are 100% authentic and sourced directly from manufacturers.', 'نعم، جميع منتجاتنا أصلية 100% ومستوردة مباشرة من المصنعين.', 1, FALSE);

-- ============================================
-- BANNERS
-- ============================================
INSERT INTO banners (title, title_ar, subtitle, subtitle_ar, image_url, link_url, link_text, link_text_ar, position, sort_order, is_active) VALUES
('New Collection 2024', 'مجموعة 2024 الجديدة', 'Discover our latest arrivals', 'اكتشفي أحدث الوصولات', 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=1920', '/pages/products.html', 'Shop Now', 'تسوقي الآن', 'hero', 1, TRUE),
('Summer Sale', 'تخفيضات الصيف', 'Up to 25% off selected items', 'خصم يصل إلى 25% على منتجات مختارة', 'https://images.unsplash.com/photo-1591561954555-607968c989ab?w=1920', '/pages/sale.html', 'View Sale', 'عرض التخفيضات', 'hero', 2, TRUE),
('Free Shipping', 'شحن مجاني', 'On orders over 500 EGP', 'على الطلبات فوق 500 جنيه', 'https://images.unsplash.com/photo-1594633313593-bab3825d0caf?w=1920', '/pages/products.html', 'Start Shopping', 'ابدأي التسوق', 'hero_secondary', 1, TRUE);
