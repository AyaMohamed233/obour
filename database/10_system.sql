-- ============================================
-- BAGS STORE - SYSTEM & ADMIN TABLES
-- ============================================
-- Tables: site_settings, static_pages, banners, faq, activity_logs
-- ============================================

-- ============================================
-- 35. SITE_SETTINGS
-- ============================================
CREATE TABLE site_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT,
    value_type VARCHAR(20) DEFAULT 'string' CHECK (value_type IN (
        'string', 'number', 'boolean', 'json', 'html', 'image'
    )),
    category VARCHAR(50) DEFAULT 'general' CHECK (category IN (
        'general', 'store', 'payment', 'shipping', 'email', 'social', 'seo', 'appearance'
    )),
    label VARCHAR(100),
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    is_editable BOOLEAN DEFAULT TRUE,
    updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default settings
INSERT INTO site_settings (key, value, value_type, category, label, is_public) VALUES
-- General
('store_name', 'Luxury Bags', 'string', 'general', 'Store Name', TRUE),
('store_name_ar', 'شنط فاخرة', 'string', 'general', 'Store Name (Arabic)', TRUE),
('store_email', 'info@luxurybags.com', 'string', 'general', 'Store Email', TRUE),
('store_phone', '+20 123 456 7890', 'string', 'general', 'Store Phone', TRUE),
('store_whatsapp', '+201234567890', 'string', 'general', 'WhatsApp Number', TRUE),
('store_address', 'Cairo, Egypt', 'string', 'general', 'Store Address', TRUE),
('store_currency', 'EGP', 'string', 'store', 'Currency', TRUE),
('store_currency_symbol', 'ج.م', 'string', 'store', 'Currency Symbol', TRUE),

-- Shipping
('free_shipping_threshold', '500', 'number', 'shipping', 'Free Shipping Threshold', TRUE),
('default_shipping_cost', '50', 'number', 'shipping', 'Default Shipping Cost', TRUE),
('cart_reservation_minutes', '30', 'number', 'store', 'Cart Reservation Time (minutes)', FALSE),

-- Payment
('stripe_enabled', 'true', 'boolean', 'payment', 'Stripe Enabled', FALSE),
('cod_enabled', 'true', 'boolean', 'payment', 'Cash on Delivery Enabled', TRUE),

-- SEO
('meta_title', 'Luxury Bags - Premium Fashion Bags', 'string', 'seo', 'Default Meta Title', TRUE),
('meta_description', 'Shop premium quality bags at Luxury Bags', 'string', 'seo', 'Default Meta Description', TRUE),

-- Social
('facebook_url', '', 'string', 'social', 'Facebook URL', TRUE),
('instagram_url', '', 'string', 'social', 'Instagram URL', TRUE),
('twitter_url', '', 'string', 'social', 'Twitter URL', TRUE),

-- Appearance
('primary_color', '#8B7355', 'string', 'appearance', 'Primary Color', TRUE),
('accent_color', '#C9A962', 'string', 'appearance', 'Accent Color', TRUE),
('logo_url', '', 'image', 'appearance', 'Logo URL', TRUE),
('favicon_url', '', 'image', 'appearance', 'Favicon URL', TRUE);

-- ============================================
-- 36. STATIC_PAGES
-- ============================================
CREATE TABLE static_pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    
    -- Content (English)
    title VARCHAR(200) NOT NULL,
    subtitle VARCHAR(300),
    content TEXT,
    
    -- Content (Arabic)
    title_ar VARCHAR(200),
    subtitle_ar VARCHAR(300),
    content_ar TEXT,
    
    -- SEO
    meta_title VARCHAR(200),
    meta_description TEXT,
    meta_keywords TEXT,
    
    -- Display
    featured_image TEXT,
    template VARCHAR(50) DEFAULT 'default',
    show_in_footer BOOLEAN DEFAULT FALSE,
    show_in_header BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_static_pages_slug ON static_pages(slug);
CREATE INDEX idx_static_pages_is_active ON static_pages(is_active);
CREATE INDEX idx_static_pages_footer ON static_pages(show_in_footer) WHERE show_in_footer = TRUE;

-- Default pages
INSERT INTO static_pages (slug, title, title_ar, is_active) VALUES
('about', 'About Us', 'من نحن', TRUE),
('privacy', 'Privacy Policy', 'سياسة الخصوصية', TRUE),
('terms', 'Terms & Conditions', 'الشروط والأحكام', TRUE),
('shipping', 'Shipping Policy', 'سياسة الشحن', TRUE),
('returns', 'Returns & Refunds', 'الإرجاع والاسترداد', TRUE);

-- ============================================
-- 37. BANNERS
-- ============================================
CREATE TABLE banners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Content
    title VARCHAR(200),
    title_ar VARCHAR(200),
    subtitle TEXT,
    subtitle_ar TEXT,
    
    -- Images
    image_url TEXT NOT NULL,
    image_url_mobile TEXT,
    
    -- Link
    link_url TEXT,
    link_text VARCHAR(50),
    link_text_ar VARCHAR(50),
    link_target VARCHAR(10) DEFAULT '_self' CHECK (link_target IN ('_self', '_blank')),
    
    -- Positioning
    position VARCHAR(50) DEFAULT 'hero' CHECK (position IN (
        'hero', 'hero_secondary', 'sidebar', 'popup', 'footer', 'category', 'product'
    )),
    
    -- Display
    text_color VARCHAR(7) DEFAULT '#FFFFFF',
    background_color VARCHAR(7),
    overlay_opacity DECIMAL(3,2) DEFAULT 0.3,
    text_alignment VARCHAR(10) DEFAULT 'center' CHECK (text_alignment IN ('left', 'center', 'right')),
    
    -- Schedule
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    
    -- Analytics
    view_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_banners_position ON banners(position);
CREATE INDEX idx_banners_is_active ON banners(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_banners_dates ON banners(start_date, end_date);
CREATE INDEX idx_banners_sort ON banners(position, sort_order);

-- ============================================
-- 38. FAQ
-- ============================================
CREATE TABLE faq (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Category
    category VARCHAR(50) DEFAULT 'general' CHECK (category IN (
        'general', 'ordering', 'shipping', 'payment', 'returns', 'products', 'account'
    )),
    
    -- Content
    question TEXT NOT NULL,
    question_ar TEXT,
    answer TEXT NOT NULL,
    answer_ar TEXT,
    
    -- Display
    sort_order INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Analytics
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_faq_category ON faq(category);
CREATE INDEX idx_faq_is_active ON faq(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_faq_is_featured ON faq(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_faq_sort ON faq(category, sort_order);

-- ============================================
-- 39. ACTIVITY_LOGS
-- ============================================
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Action
    action VARCHAR(50) NOT NULL,
    action_category VARCHAR(30) CHECK (action_category IN (
        'auth', 'user', 'product', 'order', 'payment', 'admin', 'system'
    )),
    
    -- Target
    entity_type VARCHAR(50),
    entity_id UUID,
    entity_name VARCHAR(200),
    
    -- Changes
    old_values JSONB,
    new_values JSONB,
    
    -- Context
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    request_url TEXT,
    request_method VARCHAR(10),
    
    -- Result
    is_success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX idx_activity_logs_action ON activity_logs(action);
CREATE INDEX idx_activity_logs_category ON activity_logs(action_category);
CREATE INDEX idx_activity_logs_entity ON activity_logs(entity_type, entity_id);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at DESC);

-- Partitioning by month (for performance with large volumes)
-- This would typically be done in a production environment

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_static_pages_updated_at
    BEFORE UPDATE ON static_pages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_banners_updated_at
    BEFORE UPDATE ON banners
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_faq_updated_at
    BEFORE UPDATE ON faq
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Get setting value
CREATE OR REPLACE FUNCTION get_setting(p_key VARCHAR(100))
RETURNS TEXT AS $$
BEGIN
    RETURN (SELECT value FROM site_settings WHERE key = p_key);
END;
$$ LANGUAGE plpgsql;

-- Get all public settings
CREATE OR REPLACE FUNCTION get_public_settings()
RETURNS JSONB AS $$
BEGIN
    RETURN (
        SELECT jsonb_object_agg(key, 
            CASE value_type
                WHEN 'number' THEN to_jsonb(value::DECIMAL)
                WHEN 'boolean' THEN to_jsonb(value::BOOLEAN)
                WHEN 'json' THEN value::JSONB
                ELSE to_jsonb(value)
            END
        )
        FROM site_settings
        WHERE is_public = TRUE
    );
END;
$$ LANGUAGE plpgsql;

-- Update setting
CREATE OR REPLACE FUNCTION update_setting(
    p_key VARCHAR(100),
    p_value TEXT,
    p_admin_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE site_settings
    SET value = p_value,
        updated_by = p_admin_id,
        updated_at = NOW()
    WHERE key = p_key AND is_editable = TRUE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Log activity
CREATE OR REPLACE FUNCTION log_activity(
    p_user_id UUID,
    p_action VARCHAR(50),
    p_category VARCHAR(30),
    p_entity_type VARCHAR(50) DEFAULT NULL,
    p_entity_id UUID DEFAULT NULL,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO activity_logs (
        user_id, action, action_category,
        entity_type, entity_id,
        old_values, new_values, description
    ) VALUES (
        p_user_id, p_action, p_category,
        p_entity_type, p_entity_id,
        p_old_values, p_new_values, p_description
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Get active banners by position
CREATE OR REPLACE FUNCTION get_active_banners(p_position VARCHAR(50))
RETURNS SETOF banners AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM banners
    WHERE position = p_position
    AND is_active = TRUE
    AND start_date <= NOW()
    AND (end_date IS NULL OR end_date > NOW())
    ORDER BY sort_order;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE static_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE faq ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Anyone can view public settings
CREATE POLICY "Anyone can view public settings"
    ON site_settings FOR SELECT
    USING (is_public = TRUE);

-- Anyone can view active static pages
CREATE POLICY "Anyone can view active static pages"
    ON static_pages FOR SELECT
    USING (is_active = TRUE);

-- Anyone can view active banners
CREATE POLICY "Anyone can view active banners"
    ON banners FOR SELECT
    USING (
        is_active = TRUE 
        AND start_date <= NOW() 
        AND (end_date IS NULL OR end_date > NOW())
    );

-- Anyone can view active FAQ
CREATE POLICY "Anyone can view active FAQ"
    ON faq FOR SELECT
    USING (is_active = TRUE);

-- Only admins can view activity logs (through admin policies)
CREATE POLICY "Admins can view activity logs"
    ON activity_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND is_admin = TRUE
        )
    );

-- ============================================
-- ADMIN POLICIES (for all tables)
-- ============================================

-- Create a function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND is_admin = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin full access to all tables
DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN 
        SELECT unnest(ARRAY[
            'profiles', 'addresses', 'categories', 'subcategories', 'brands',
            'products', 'product_images', 'product_colors', 'product_tags',
            'product_attributes', 'related_products', 'inventory_logs',
            'stock_alerts', 'sales', 'coupons', 'coupon_usage',
            'orders', 'order_items', 'order_status_history', 'shipping_methods',
            'transactions', 'refunds', 'reviews', 'review_images',
            'notifications', 'contact_messages', 'newsletter_subscribers',
            'site_settings', 'static_pages', 'banners', 'faq', 'activity_logs'
        ])
    LOOP
        EXECUTE format('
            CREATE POLICY "Admins have full access to %I"
            ON %I FOR ALL
            USING (is_admin())
            WITH CHECK (is_admin())
        ', table_name, table_name);
    END LOOP;
END $$;
