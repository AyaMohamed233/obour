-- ============================================
-- BAGS STORE - SHOPPING TABLES
-- ============================================
-- Tables: cart_items, wishlists, recently_viewed
-- ============================================

-- ============================================
-- 20. CART_ITEMS
-- ============================================
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    color_id UUID NOT NULL REFERENCES product_colors(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2), -- Price at time of adding (for reference)
    reservation_id UUID REFERENCES stock_reservations(id) ON DELETE SET NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id, color_id)
);

-- Indexes for cart_items
CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);
CREATE INDEX idx_cart_items_color_id ON cart_items(color_id);
CREATE INDEX idx_cart_items_added_at ON cart_items(added_at DESC);

-- ============================================
-- 21. WISHLISTS
-- ============================================
CREATE TABLE wishlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    notes TEXT,
    notify_on_sale BOOLEAN DEFAULT TRUE,
    notify_on_restock BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0, -- For sorting wishlist items
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- Indexes for wishlists
CREATE INDEX idx_wishlists_user_id ON wishlists(user_id);
CREATE INDEX idx_wishlists_product_id ON wishlists(product_id);
CREATE INDEX idx_wishlists_created_at ON wishlists(created_at DESC);
CREATE INDEX idx_wishlists_notify_sale ON wishlists(product_id, notify_on_sale) WHERE notify_on_sale = TRUE;
CREATE INDEX idx_wishlists_notify_restock ON wishlists(product_id, notify_on_restock) WHERE notify_on_restock = TRUE;

-- ============================================
-- 22. RECENTLY_VIEWED
-- ============================================
CREATE TABLE recently_viewed (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 1,
    last_viewed_at TIMESTAMPTZ DEFAULT NOW(),
    first_viewed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- Indexes for recently_viewed
CREATE INDEX idx_recently_viewed_user_id ON recently_viewed(user_id);
CREATE INDEX idx_recently_viewed_product_id ON recently_viewed(product_id);
CREATE INDEX idx_recently_viewed_last_viewed ON recently_viewed(user_id, last_viewed_at DESC);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_cart_items_updated_at
    BEFORE UPDATE ON cart_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Update wishlist count on product when added/removed
CREATE OR REPLACE FUNCTION update_product_wishlist_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE products 
        SET wishlist_count = wishlist_count + 1
        WHERE id = NEW.product_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE products 
        SET wishlist_count = GREATEST(0, wishlist_count - 1)
        WHERE id = OLD.product_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_wishlist_count
    AFTER INSERT OR DELETE ON wishlists
    FOR EACH ROW
    EXECUTE FUNCTION update_product_wishlist_count();

-- Update product view count
CREATE OR REPLACE FUNCTION update_product_view_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE products 
        SET view_count = view_count + 1
        WHERE id = NEW.product_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.view_count > OLD.view_count THEN
        UPDATE products 
        SET view_count = view_count + (NEW.view_count - OLD.view_count)
        WHERE id = NEW.product_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_view_count
    AFTER INSERT OR UPDATE ON recently_viewed
    FOR EACH ROW
    EXECUTE FUNCTION update_product_view_count();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Add to cart with stock reservation
CREATE OR REPLACE FUNCTION add_to_cart(
    p_user_id UUID,
    p_product_id UUID,
    p_color_id UUID,
    p_quantity INTEGER
)
RETURNS UUID AS $$
DECLARE
    v_existing_item RECORD;
    v_cart_item_id UUID;
    v_reservation_id UUID;
    v_unit_price DECIMAL(10,2);
    v_available_stock INTEGER;
BEGIN
    -- Get product price (with sale if applicable)
    SELECT COALESCE(get_sale_price(p_product_id), price) INTO v_unit_price
    FROM products WHERE id = p_product_id;
    
    -- Check available stock
    SELECT quantity - reserved_quantity INTO v_available_stock
    FROM product_colors WHERE id = p_color_id;
    
    -- Check if item already in cart
    SELECT * INTO v_existing_item
    FROM cart_items
    WHERE user_id = p_user_id AND product_id = p_product_id AND color_id = p_color_id;
    
    IF FOUND THEN
        -- Check if new total quantity exceeds stock
        IF (v_existing_item.quantity + p_quantity) > v_available_stock + 
           COALESCE((SELECT quantity FROM stock_reservations WHERE id = v_existing_item.reservation_id), 0) THEN
            RAISE EXCEPTION 'Insufficient stock. Available: %', v_available_stock;
        END IF;
        
        -- Update existing cart item
        UPDATE cart_items
        SET quantity = quantity + p_quantity,
            updated_at = NOW()
        WHERE id = v_existing_item.id
        RETURNING id INTO v_cart_item_id;
        
        -- Update reservation
        IF v_existing_item.reservation_id IS NOT NULL THEN
            UPDATE stock_reservations
            SET quantity = quantity + p_quantity,
                expires_at = NOW() + INTERVAL '30 minutes'
            WHERE id = v_existing_item.reservation_id;
            
            UPDATE product_colors
            SET reserved_quantity = reserved_quantity + p_quantity
            WHERE id = p_color_id;
        END IF;
    ELSE
        -- Check stock for new item
        IF p_quantity > v_available_stock THEN
            RAISE EXCEPTION 'Insufficient stock. Available: %', v_available_stock;
        END IF;
        
        -- Reserve stock
        v_reservation_id := reserve_stock(p_user_id, p_color_id, p_quantity, 30);
        
        -- Create new cart item
        INSERT INTO cart_items (user_id, product_id, color_id, quantity, unit_price, reservation_id)
        VALUES (p_user_id, p_product_id, p_color_id, p_quantity, v_unit_price, v_reservation_id)
        RETURNING id INTO v_cart_item_id;
    END IF;
    
    RETURN v_cart_item_id;
END;
$$ LANGUAGE plpgsql;

-- Remove from cart
CREATE OR REPLACE FUNCTION remove_from_cart(
    p_user_id UUID,
    p_cart_item_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_cart_item RECORD;
BEGIN
    -- Get cart item
    SELECT * INTO v_cart_item
    FROM cart_items
    WHERE id = p_cart_item_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Release stock reservation
    IF v_cart_item.reservation_id IS NOT NULL THEN
        PERFORM release_stock(v_cart_item.reservation_id);
    END IF;
    
    -- Delete cart item
    DELETE FROM cart_items WHERE id = p_cart_item_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Update cart item quantity
CREATE OR REPLACE FUNCTION update_cart_quantity(
    p_user_id UUID,
    p_cart_item_id UUID,
    p_new_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_cart_item RECORD;
    v_available_stock INTEGER;
    v_quantity_diff INTEGER;
BEGIN
    IF p_new_quantity <= 0 THEN
        RETURN remove_from_cart(p_user_id, p_cart_item_id);
    END IF;
    
    -- Get cart item
    SELECT * INTO v_cart_item
    FROM cart_items
    WHERE id = p_cart_item_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Get available stock (plus current reservation)
    SELECT (quantity - reserved_quantity) + 
           COALESCE((SELECT quantity FROM stock_reservations WHERE id = v_cart_item.reservation_id), 0)
    INTO v_available_stock
    FROM product_colors WHERE id = v_cart_item.color_id;
    
    IF p_new_quantity > v_available_stock THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %', v_available_stock;
    END IF;
    
    v_quantity_diff := p_new_quantity - v_cart_item.quantity;
    
    -- Update cart item
    UPDATE cart_items
    SET quantity = p_new_quantity,
        updated_at = NOW()
    WHERE id = p_cart_item_id;
    
    -- Update reservation
    IF v_cart_item.reservation_id IS NOT NULL THEN
        UPDATE stock_reservations
        SET quantity = p_new_quantity,
            expires_at = NOW() + INTERVAL '30 minutes'
        WHERE id = v_cart_item.reservation_id;
        
        UPDATE product_colors
        SET reserved_quantity = reserved_quantity + v_quantity_diff
        WHERE id = v_cart_item.color_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Get cart with product details
CREATE OR REPLACE FUNCTION get_cart_details(p_user_id UUID)
RETURNS TABLE (
    cart_item_id UUID,
    product_id UUID,
    product_name VARCHAR,
    product_image TEXT,
    color_id UUID,
    color_name VARCHAR,
    color_hex VARCHAR,
    quantity INTEGER,
    unit_price DECIMAL,
    sale_price DECIMAL,
    available_stock INTEGER,
    line_total DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id as cart_item_id,
        ci.product_id,
        p.name as product_name,
        COALESCE(
            (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.id AND pi.is_primary = TRUE LIMIT 1),
            (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.id ORDER BY sort_order LIMIT 1)
        ) as product_image,
        ci.color_id,
        pc.color_name,
        pc.color_hex,
        ci.quantity,
        p.price as unit_price,
        get_sale_price(p.id) as sale_price,
        (pc.quantity - pc.reserved_quantity + ci.quantity)::INTEGER as available_stock,
        (ci.quantity * COALESCE(get_sale_price(p.id), p.price))::DECIMAL as line_total
    FROM cart_items ci
    JOIN products p ON ci.product_id = p.id
    JOIN product_colors pc ON ci.color_id = pc.id
    WHERE ci.user_id = p_user_id
    ORDER BY ci.added_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Track product view
CREATE OR REPLACE FUNCTION track_product_view(
    p_user_id UUID,
    p_product_id UUID
)
RETURNS void AS $$
BEGIN
    INSERT INTO recently_viewed (user_id, product_id, view_count, last_viewed_at)
    VALUES (p_user_id, p_product_id, 1, NOW())
    ON CONFLICT (user_id, product_id) DO UPDATE
    SET view_count = recently_viewed.view_count + 1,
        last_viewed_at = NOW();
        
    -- Keep only last 50 viewed products per user
    DELETE FROM recently_viewed
    WHERE user_id = p_user_id
    AND id NOT IN (
        SELECT id FROM recently_viewed
        WHERE user_id = p_user_id
        ORDER BY last_viewed_at DESC
        LIMIT 50
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE recently_viewed ENABLE ROW LEVEL SECURITY;

-- Cart items policies
CREATE POLICY "Users can manage own cart"
    ON cart_items FOR ALL
    USING (auth.uid() = user_id);

-- Wishlists policies
CREATE POLICY "Users can manage own wishlist"
    ON wishlists FOR ALL
    USING (auth.uid() = user_id);

-- Recently viewed policies
CREATE POLICY "Users can manage own recently viewed"
    ON recently_viewed FOR ALL
    USING (auth.uid() = user_id);
