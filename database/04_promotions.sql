-- ============================================
-- BAGS STORE - PROMOTIONS & DISCOUNTS TABLES
-- ============================================
-- Tables: sales, coupons, coupon_usage
-- ============================================

-- ============================================
-- 17. SALES (product discounts)
-- ============================================
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sale_type VARCHAR(20) NOT NULL CHECK (sale_type IN ('percentage', 'fixed')),
    sale_percentage DECIMAL(5,2) CHECK (sale_percentage >= 0 AND sale_percentage <= 100),
    sale_price DECIMAL(10,2) CHECK (sale_price >= 0),
    original_price DECIMAL(10,2) NOT NULL,
    savings_amount DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE 
            WHEN sale_type = 'fixed' THEN original_price - sale_price
            WHEN sale_type = 'percentage' THEN original_price * (sale_percentage / 100)
            ELSE 0
        END
    ) STORED,
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0, -- Higher priority takes precedence
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id),
    CHECK (
        (sale_type = 'percentage' AND sale_percentage IS NOT NULL) OR
        (sale_type = 'fixed' AND sale_price IS NOT NULL)
    )
);

-- Indexes for sales
CREATE INDEX idx_sales_product_id ON sales(product_id);
CREATE INDEX idx_sales_is_active ON sales(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_sales_dates ON sales(start_date, end_date);
CREATE INDEX idx_sales_end_date ON sales(end_date) WHERE end_date IS NOT NULL;

-- ============================================
-- 18. COUPONS
-- ============================================
CREATE TABLE coupons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100),
    description TEXT,
    description_ar TEXT,
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed', 'free_shipping')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value >= 0),
    min_order_amount DECIMAL(10,2) DEFAULT 0 CHECK (min_order_amount >= 0),
    max_discount_amount DECIMAL(10,2) CHECK (max_discount_amount >= 0),
    usage_limit INTEGER, -- Total times this coupon can be used
    usage_limit_per_user INTEGER DEFAULT 1,
    used_count INTEGER DEFAULT 0,
    applies_to VARCHAR(20) DEFAULT 'all' CHECK (applies_to IN ('all', 'categories', 'products', 'brands')),
    applicable_category_ids UUID[],
    applicable_product_ids UUID[],
    applicable_brand_ids UUID[],
    excluded_product_ids UUID[],
    excluded_category_ids UUID[],
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_to TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    is_first_order_only BOOLEAN DEFAULT FALSE,
    is_single_use BOOLEAN DEFAULT FALSE,
    minimum_items INTEGER DEFAULT 1,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for coupons
CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_is_active ON coupons(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_coupons_valid_dates ON coupons(valid_from, valid_to);
CREATE INDEX idx_coupons_discount_type ON coupons(discount_type);

-- ============================================
-- 19. COUPON_USAGE (track who used coupons)
-- ============================================
CREATE TABLE coupon_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    order_id UUID NOT NULL, -- Will reference orders table
    discount_amount DECIMAL(10,2) NOT NULL,
    order_total_before DECIMAL(10,2),
    order_total_after DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(coupon_id, order_id)
);

-- Indexes for coupon_usage
CREATE INDEX idx_coupon_usage_coupon_id ON coupon_usage(coupon_id);
CREATE INDEX idx_coupon_usage_user_id ON coupon_usage(user_id);
CREATE INDEX idx_coupon_usage_order_id ON coupon_usage(order_id);
CREATE INDEX idx_coupon_usage_created_at ON coupon_usage(created_at DESC);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_sales_updated_at
    BEFORE UPDATE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_coupons_updated_at
    BEFORE UPDATE ON coupons
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-increment coupon used_count
CREATE OR REPLACE FUNCTION increment_coupon_usage()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE coupons 
    SET used_count = used_count + 1
    WHERE id = NEW.coupon_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_increment_coupon_usage
    AFTER INSERT ON coupon_usage
    FOR EACH ROW
    EXECUTE FUNCTION increment_coupon_usage();

-- Auto-deactivate expired sales
CREATE OR REPLACE FUNCTION deactivate_expired_sales()
RETURNS void AS $$
BEGIN
    UPDATE sales 
    SET is_active = FALSE
    WHERE is_active = TRUE 
    AND end_date IS NOT NULL 
    AND end_date < NOW();
END;
$$ LANGUAGE plpgsql;

-- Auto-deactivate expired coupons
CREATE OR REPLACE FUNCTION deactivate_expired_coupons()
RETURNS void AS $$
BEGIN
    UPDATE coupons 
    SET is_active = FALSE
    WHERE is_active = TRUE 
    AND valid_to IS NOT NULL 
    AND valid_to < NOW();
    
    -- Also deactivate coupons that reached usage limit
    UPDATE coupons 
    SET is_active = FALSE
    WHERE is_active = TRUE 
    AND usage_limit IS NOT NULL 
    AND used_count >= usage_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Validate and apply coupon
CREATE OR REPLACE FUNCTION validate_coupon(
    p_code VARCHAR(50),
    p_user_id UUID,
    p_order_subtotal DECIMAL(10,2),
    p_item_count INTEGER DEFAULT 1
)
RETURNS TABLE (
    is_valid BOOLEAN,
    coupon_id UUID,
    discount_type VARCHAR(20),
    discount_value DECIMAL(10,2),
    calculated_discount DECIMAL(10,2),
    error_message TEXT
) AS $$
DECLARE
    v_coupon RECORD;
    v_user_usage_count INTEGER;
    v_calculated_discount DECIMAL(10,2);
    v_is_first_order BOOLEAN;
BEGIN
    -- Get coupon
    SELECT * INTO v_coupon
    FROM coupons
    WHERE code = UPPER(p_code)
    FOR UPDATE;
    
    -- Check if coupon exists
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'Invalid coupon code'::TEXT;
        RETURN;
    END IF;
    
    -- Check if active
    IF NOT v_coupon.is_active THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'Coupon is no longer active'::TEXT;
        RETURN;
    END IF;
    
    -- Check validity dates
    IF v_coupon.valid_from > NOW() THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'Coupon is not yet valid'::TEXT;
        RETURN;
    END IF;
    
    IF v_coupon.valid_to IS NOT NULL AND v_coupon.valid_to < NOW() THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'Coupon has expired'::TEXT;
        RETURN;
    END IF;
    
    -- Check usage limit
    IF v_coupon.usage_limit IS NOT NULL AND v_coupon.used_count >= v_coupon.usage_limit THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'Coupon usage limit reached'::TEXT;
        RETURN;
    END IF;
    
    -- Check per-user limit
    SELECT COUNT(*) INTO v_user_usage_count
    FROM coupon_usage
    WHERE coupon_id = v_coupon.id AND user_id = p_user_id;
    
    IF v_coupon.usage_limit_per_user IS NOT NULL AND v_user_usage_count >= v_coupon.usage_limit_per_user THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'You have already used this coupon'::TEXT;
        RETURN;
    END IF;
    
    -- Check minimum order amount
    IF p_order_subtotal < v_coupon.min_order_amount THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 
            FORMAT('Minimum order amount is %s', v_coupon.min_order_amount)::TEXT;
        RETURN;
    END IF;
    
    -- Check minimum items
    IF p_item_count < v_coupon.minimum_items THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL,
            FORMAT('Minimum %s items required', v_coupon.minimum_items)::TEXT;
        RETURN;
    END IF;
    
    -- Check first order only
    IF v_coupon.is_first_order_only THEN
        SELECT NOT EXISTS (
            SELECT 1 FROM orders 
            WHERE user_id = p_user_id 
            AND status NOT IN ('cancelled')
        ) INTO v_is_first_order;
        
        IF NOT v_is_first_order THEN
            RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::DECIMAL, NULL::DECIMAL, 'This coupon is for first orders only'::TEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Calculate discount
    IF v_coupon.discount_type = 'percentage' THEN
        v_calculated_discount := p_order_subtotal * (v_coupon.discount_value / 100);
    ELSIF v_coupon.discount_type = 'fixed' THEN
        v_calculated_discount := v_coupon.discount_value;
    ELSIF v_coupon.discount_type = 'free_shipping' THEN
        v_calculated_discount := 0; -- Shipping will be handled separately
    END IF;
    
    -- Apply max discount cap
    IF v_coupon.max_discount_amount IS NOT NULL AND v_calculated_discount > v_coupon.max_discount_amount THEN
        v_calculated_discount := v_coupon.max_discount_amount;
    END IF;
    
    -- Don't exceed order total
    IF v_calculated_discount > p_order_subtotal THEN
        v_calculated_discount := p_order_subtotal;
    END IF;
    
    RETURN QUERY SELECT TRUE, v_coupon.id, v_coupon.discount_type, v_coupon.discount_value, v_calculated_discount, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Get active sale price for product
CREATE OR REPLACE FUNCTION get_sale_price(p_product_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_sale RECORD;
    v_sale_price DECIMAL(10,2);
BEGIN
    SELECT * INTO v_sale
    FROM sales
    WHERE product_id = p_product_id
    AND is_active = TRUE
    AND start_date <= NOW()
    AND (end_date IS NULL OR end_date > NOW())
    ORDER BY priority DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    IF v_sale.sale_type = 'fixed' THEN
        v_sale_price := v_sale.sale_price;
    ELSE
        v_sale_price := v_sale.original_price - (v_sale.original_price * v_sale.sale_percentage / 100);
    END IF;
    
    RETURN ROUND(v_sale_price, 2);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;

-- Anyone can view active sales
CREATE POLICY "Anyone can view active sales"
    ON sales FOR SELECT
    USING (is_active = TRUE AND start_date <= NOW() AND (end_date IS NULL OR end_date > NOW()));

-- Authenticated users can view active coupons (for validation)
CREATE POLICY "Authenticated users can validate coupons"
    ON coupons FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Users can view their own coupon usage
CREATE POLICY "Users can view own coupon usage"
    ON coupon_usage FOR SELECT
    USING (auth.uid() = user_id);

-- Admin policies will be added in admin section
