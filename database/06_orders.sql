-- ============================================
-- BAGS STORE - ORDERS TABLES
-- ============================================
-- Tables: shipping_methods, orders, order_items, order_status_history
-- ============================================

-- ============================================
-- 23. SHIPPING_METHODS
-- ============================================
CREATE TABLE shipping_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100),
    code VARCHAR(20) UNIQUE NOT NULL,
    description TEXT,
    description_ar TEXT,
    base_cost DECIMAL(10,2) NOT NULL CHECK (base_cost >= 0),
    cost_per_kg DECIMAL(10,2) DEFAULT 0,
    free_shipping_threshold DECIMAL(10,2),
    estimated_days_min INTEGER,
    estimated_days_max INTEGER,
    tracking_url_template TEXT, -- e.g., https://tracking.example.com/{tracking_number}
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_shipping_methods_is_active ON shipping_methods(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_shipping_methods_code ON shipping_methods(code);

-- ============================================
-- 24. ORDERS
-- ============================================
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    address_id UUID REFERENCES addresses(id) ON DELETE SET NULL,
    coupon_id UUID REFERENCES coupons(id) ON DELETE SET NULL,
    shipping_method_id UUID REFERENCES shipping_methods(id) ON DELETE SET NULL,
    
    -- Order Number (human readable)
    order_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Just created, awaiting payment/confirmation
        'confirmed',    -- Payment received / COD confirmed
        'processing',   -- Being prepared
        'shipped',      -- Handed to shipping carrier
        'delivered',    -- Delivered to customer
        'cancelled',    -- Cancelled
        'refunded'      -- Fully refunded
    )),
    
    -- Payment Info
    payment_method VARCHAR(20) CHECK (payment_method IN ('cod', 'card', 'wallet')),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN (
        'pending',              -- Awaiting payment
        'paid',                 -- Fully paid
        'failed',               -- Payment failed
        'refunded',             -- Fully refunded
        'partially_refunded',   -- Partially refunded
        'cash_pending'          -- COD - awaiting cash collection
    )),
    stripe_payment_intent_id VARCHAR(255),
    stripe_checkout_session_id VARCHAR(255),
    
    -- Pricing
    subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    shipping_cost DECIMAL(10,2) DEFAULT 0 CHECK (shipping_cost >= 0),
    tax_amount DECIMAL(10,2) DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    
    -- Item counts
    total_items INTEGER DEFAULT 0,
    total_quantity INTEGER DEFAULT 0,
    
    -- Customer Info (snapshot at time of order)
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    customer_phone_alt VARCHAR(20),
    
    -- Shipping Address (snapshot at time of order)
    shipping_governorate VARCHAR(50),
    shipping_city VARCHAR(100),
    shipping_district VARCHAR(100),
    shipping_address TEXT,
    shipping_building VARCHAR(20),
    shipping_floor VARCHAR(10),
    shipping_apartment VARCHAR(20),
    shipping_postal_code VARCHAR(10),
    shipping_landmark TEXT,
    
    -- Notes
    customer_notes TEXT,
    admin_notes TEXT,
    internal_notes TEXT,
    
    -- Shipping Tracking
    tracking_number VARCHAR(100),
    tracking_url TEXT,
    carrier_name VARCHAR(50),
    estimated_delivery_date DATE,
    actual_delivery_date DATE,
    
    -- Timestamps
    confirmed_at TIMESTAMPTZ,
    processing_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancelled_by VARCHAR(20) CHECK (cancelled_by IN ('user', 'admin', 'system')),
    cancel_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for orders
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_order_number ON orders(order_number);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_payment_method ON orders(payment_method);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_shipped_at ON orders(shipped_at DESC);
CREATE INDEX idx_orders_stripe_payment ON orders(stripe_payment_intent_id);

-- ============================================
-- 25. ORDER_ITEMS
-- ============================================
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    color_id UUID REFERENCES product_colors(id) ON DELETE SET NULL,
    
    -- Snapshot at time of order (in case product is deleted/changed)
    product_name VARCHAR(200) NOT NULL,
    product_name_ar VARCHAR(200),
    product_sku VARCHAR(50),
    color_name VARCHAR(50),
    color_hex VARCHAR(7),
    product_image TEXT,
    
    -- Pricing
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    original_price DECIMAL(10,2) CHECK (original_price >= 0), -- Before sale
    discount_amount DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    
    -- For returns/reviews tracking
    quantity_returned INTEGER DEFAULT 0,
    has_reviewed BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for order_items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_color_id ON order_items(color_id);

-- ============================================
-- 26. ORDER_STATUS_HISTORY
-- ============================================
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    old_payment_status VARCHAR(20),
    new_payment_status VARCHAR(20),
    notes TEXT,
    notify_customer BOOLEAN DEFAULT TRUE,
    notification_sent BOOLEAN DEFAULT FALSE,
    changed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    changed_by_type VARCHAR(20) DEFAULT 'system' CHECK (changed_by_type IN ('user', 'admin', 'system')),
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for order_status_history
CREATE INDEX idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX idx_order_status_history_created_at ON order_status_history(created_at DESC);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_shipping_methods_updated_at
    BEFORE UPDATE ON shipping_methods
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
    v_date_part VARCHAR(8);
    v_seq INTEGER;
BEGIN
    v_date_part := TO_CHAR(NOW(), 'YYYYMMDD');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM 10) AS INTEGER)), 0) + 1
    INTO v_seq
    FROM orders
    WHERE order_number LIKE 'ORD' || v_date_part || '%';
    
    NEW.order_number := 'ORD' || v_date_part || LPAD(v_seq::TEXT, 4, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_order_number
    BEFORE INSERT ON orders
    FOR EACH ROW
    WHEN (NEW.order_number IS NULL)
    EXECUTE FUNCTION generate_order_number();

-- Track status changes
CREATE OR REPLACE FUNCTION track_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status OR OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        INSERT INTO order_status_history (
            order_id, old_status, new_status, 
            old_payment_status, new_payment_status,
            changed_by_type
        ) VALUES (
            NEW.id, OLD.status, NEW.status,
            OLD.payment_status, NEW.payment_status,
            'system'
        );
        
        -- Update timestamps
        IF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
            NEW.confirmed_at := NOW();
        ELSIF NEW.status = 'processing' AND OLD.status != 'processing' THEN
            NEW.processing_at := NOW();
        ELSIF NEW.status = 'shipped' AND OLD.status != 'shipped' THEN
            NEW.shipped_at := NOW();
        ELSIF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
            NEW.delivered_at := NOW();
            NEW.actual_delivery_date := CURRENT_DATE;
        ELSIF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
            NEW.cancelled_at := NOW();
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_track_order_status
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION track_order_status_change();

-- Update order totals
CREATE OR REPLACE FUNCTION update_order_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE orders 
        SET total_items = (SELECT COUNT(*) FROM order_items WHERE order_id = OLD.order_id),
            total_quantity = COALESCE((SELECT SUM(quantity) FROM order_items WHERE order_id = OLD.order_id), 0)
        WHERE id = OLD.order_id;
        RETURN OLD;
    ELSE
        UPDATE orders 
        SET total_items = (SELECT COUNT(*) FROM order_items WHERE order_id = NEW.order_id),
            total_quantity = COALESCE((SELECT SUM(quantity) FROM order_items WHERE order_id = NEW.order_id), 0)
        WHERE id = NEW.order_id;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_order_counts
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_counts();

-- Update product order count
CREATE OR REPLACE FUNCTION update_product_order_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products 
    SET order_count = order_count + NEW.quantity
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_order_count
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_product_order_count();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Create order from cart
CREATE OR REPLACE FUNCTION create_order_from_cart(
    p_user_id UUID,
    p_address_id UUID,
    p_payment_method VARCHAR(20),
    p_shipping_method_id UUID,
    p_coupon_code VARCHAR(50) DEFAULT NULL,
    p_customer_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_address RECORD;
    v_profile RECORD;
    v_cart_item RECORD;
    v_subtotal DECIMAL(10,2) := 0;
    v_discount_amount DECIMAL(10,2) := 0;
    v_shipping_cost DECIMAL(10,2) := 0;
    v_total_amount DECIMAL(10,2);
    v_coupon_id UUID;
    v_coupon_result RECORD;
    v_item_price DECIMAL(10,2);
    v_original_price DECIMAL(10,2);
    v_product_image TEXT;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get address
    SELECT * INTO v_address FROM addresses WHERE id = p_address_id AND user_id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Address not found';
    END IF;
    
    -- Verify cart has items
    IF NOT EXISTS (SELECT 1 FROM cart_items WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'Cart is empty';
    END IF;
    
    -- Calculate subtotal
    SELECT SUM(ci.quantity * COALESCE(get_sale_price(ci.product_id), p.price))
    INTO v_subtotal
    FROM cart_items ci
    JOIN products p ON ci.product_id = p.id
    WHERE ci.user_id = p_user_id;
    
    -- Validate and apply coupon
    IF p_coupon_code IS NOT NULL THEN
        SELECT * INTO v_coupon_result
        FROM validate_coupon(
            p_coupon_code, p_user_id, v_subtotal,
            (SELECT COUNT(*) FROM cart_items WHERE user_id = p_user_id)::INTEGER
        );
        
        IF v_coupon_result.is_valid THEN
            v_coupon_id := v_coupon_result.coupon_id;
            v_discount_amount := v_coupon_result.calculated_discount;
        ELSE
            RAISE EXCEPTION 'Coupon error: %', v_coupon_result.error_message;
        END IF;
    END IF;
    
    -- Calculate shipping
    SELECT CASE 
        WHEN free_shipping_threshold IS NOT NULL AND v_subtotal >= free_shipping_threshold THEN 0
        ELSE base_cost
    END INTO v_shipping_cost
    FROM shipping_methods WHERE id = p_shipping_method_id;
    
    v_shipping_cost := COALESCE(v_shipping_cost, 0);
    
    -- Calculate total
    v_total_amount := v_subtotal - v_discount_amount + v_shipping_cost;
    
    -- Create order
    INSERT INTO orders (
        user_id, address_id, coupon_id, shipping_method_id,
        status, payment_method, payment_status,
        subtotal, discount_amount, shipping_cost, total_amount,
        customer_name, customer_email, customer_phone, customer_phone_alt,
        shipping_governorate, shipping_city, shipping_district,
        shipping_address, shipping_building, shipping_floor, shipping_apartment,
        shipping_postal_code, shipping_landmark, customer_notes
    ) VALUES (
        p_user_id, p_address_id, v_coupon_id, p_shipping_method_id,
        CASE WHEN p_payment_method = 'cod' THEN 'confirmed' ELSE 'pending' END,
        p_payment_method,
        CASE WHEN p_payment_method = 'cod' THEN 'cash_pending' ELSE 'pending' END,
        v_subtotal, v_discount_amount, v_shipping_cost, v_total_amount,
        COALESCE(v_address.recipient_name, v_profile.full_name),
        v_profile.email,
        COALESCE(v_address.phone, v_profile.phone),
        NULL,
        v_address.governorate, v_address.city, v_address.district,
        v_address.street_address, v_address.building_number, v_address.floor,
        v_address.apartment, v_address.postal_code, v_address.landmark,
        p_customer_notes
    ) RETURNING id INTO v_order_id;
    
    -- Create order items from cart
    FOR v_cart_item IN
        SELECT ci.*, p.name, p.name_ar, p.sku, p.price,
               pc.color_name, pc.color_hex
        FROM cart_items ci
        JOIN products p ON ci.product_id = p.id
        JOIN product_colors pc ON ci.color_id = pc.id
        WHERE ci.user_id = p_user_id
    LOOP
        -- Get sale price
        v_item_price := COALESCE(get_sale_price(v_cart_item.product_id), v_cart_item.price);
        v_original_price := v_cart_item.price;
        
        -- Get product image
        SELECT image_url INTO v_product_image
        FROM product_images
        WHERE product_id = v_cart_item.product_id
        ORDER BY is_primary DESC, sort_order
        LIMIT 1;
        
        -- Insert order item
        INSERT INTO order_items (
            order_id, product_id, color_id,
            product_name, product_name_ar, product_sku,
            color_name, color_hex, product_image,
            quantity, unit_price, original_price,
            discount_amount, total_price
        ) VALUES (
            v_order_id, v_cart_item.product_id, v_cart_item.color_id,
            v_cart_item.name, v_cart_item.name_ar, v_cart_item.sku,
            v_cart_item.color_name, v_cart_item.color_hex, v_product_image,
            v_cart_item.quantity, v_item_price, v_original_price,
            CASE WHEN v_original_price > v_item_price THEN v_original_price - v_item_price ELSE 0 END,
            v_cart_item.quantity * v_item_price
        );
        
        -- Convert reservation to order (deduct from reserved, deduct from quantity)
        IF v_cart_item.reservation_id IS NOT NULL THEN
            UPDATE stock_reservations
            SET is_active = FALSE, converted_to_order = TRUE, order_id = v_order_id
            WHERE id = v_cart_item.reservation_id;
            
            -- Move from reserved to actually sold
            UPDATE product_colors
            SET reserved_quantity = reserved_quantity - v_cart_item.quantity,
                quantity = quantity - v_cart_item.quantity
            WHERE id = v_cart_item.color_id;
            
            -- Log inventory change
            INSERT INTO inventory_logs (
                product_id, color_id, action, quantity_change,
                quantity_before, quantity_after, reference_type, reference_id
            )
            SELECT 
                v_cart_item.product_id, v_cart_item.color_id, 'order_deduct', 
                -v_cart_item.quantity, quantity + v_cart_item.quantity, quantity,
                'order', v_order_id
            FROM product_colors WHERE id = v_cart_item.color_id;
        END IF;
    END LOOP;
    
    -- Record coupon usage
    IF v_coupon_id IS NOT NULL THEN
        INSERT INTO coupon_usage (coupon_id, user_id, order_id, discount_amount, order_total_before, order_total_after)
        VALUES (v_coupon_id, p_user_id, v_order_id, v_discount_amount, v_subtotal, v_subtotal - v_discount_amount);
    END IF;
    
    -- Clear cart
    DELETE FROM cart_items WHERE user_id = p_user_id;
    
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- Cancel order
CREATE OR REPLACE FUNCTION cancel_order(
    p_order_id UUID,
    p_user_id UUID,
    p_cancelled_by VARCHAR(20),
    p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_order RECORD;
    v_order_item RECORD;
BEGIN
    -- Get order
    SELECT * INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;
    
    -- Check if user owns order or is admin
    IF v_order.user_id != p_user_id AND p_cancelled_by != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- Check if can be cancelled
    IF v_order.status IN ('delivered', 'cancelled', 'refunded') THEN
        RAISE EXCEPTION 'Order cannot be cancelled';
    END IF;
    
    -- Restore stock for each item
    FOR v_order_item IN SELECT * FROM order_items WHERE order_id = p_order_id
    LOOP
        IF v_order_item.color_id IS NOT NULL THEN
            UPDATE product_colors
            SET quantity = quantity + v_order_item.quantity
            WHERE id = v_order_item.color_id;
            
            -- Log inventory restoration
            INSERT INTO inventory_logs (
                product_id, color_id, action, quantity_change,
                quantity_before, quantity_after, reference_type, reference_id
            )
            SELECT 
                v_order_item.product_id, v_order_item.color_id, 'order_cancel_restore',
                v_order_item.quantity, quantity - v_order_item.quantity, quantity,
                'order', p_order_id
            FROM product_colors WHERE id = v_order_item.color_id;
        END IF;
    END LOOP;
    
    -- Update order status
    UPDATE orders
    SET status = 'cancelled',
        cancelled_by = p_cancelled_by,
        cancel_reason = p_reason,
        cancelled_at = NOW()
    WHERE id = p_order_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE shipping_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;

-- Public can view active shipping methods
CREATE POLICY "Anyone can view active shipping methods"
    ON shipping_methods FOR SELECT
    USING (is_active = TRUE);

-- Users can view own orders
CREATE POLICY "Users can view own orders"
    ON orders FOR SELECT
    USING (auth.uid() = user_id);

-- Users can create orders
CREATE POLICY "Users can create orders"
    ON orders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can view own order items
CREATE POLICY "Users can view own order items"
    ON order_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND orders.user_id = auth.uid()
        )
    );

-- Users can view own order history
CREATE POLICY "Users can view own order status history"
    ON order_status_history FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_status_history.order_id 
            AND orders.user_id = auth.uid()
        )
    );
