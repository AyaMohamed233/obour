-- ============================================
-- BAGS STORE - INVENTORY MANAGEMENT TABLES
-- ============================================
-- Tables: inventory_logs, stock_alerts, stock_reservations
-- ============================================

-- ============================================
-- 14. INVENTORY_LOGS (stock movement history)
-- ============================================
CREATE TABLE inventory_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    color_id UUID REFERENCES product_colors(id) ON DELETE SET NULL,
    action VARCHAR(30) NOT NULL CHECK (action IN (
        'add', 'remove', 'reserve', 'release', 
        'adjust', 'order_deduct', 'order_cancel_restore',
        'return_restore', 'import', 'export'
    )),
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reserved_before INTEGER,
    reserved_after INTEGER,
    reference_type VARCHAR(30) CHECK (reference_type IN (
        'order', 'return', 'adjustment', 'import', 
        'cart', 'manual', 'system'
    )),
    reference_id UUID,
    notes TEXT,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for inventory_logs
CREATE INDEX idx_inventory_logs_product_id ON inventory_logs(product_id);
CREATE INDEX idx_inventory_logs_color_id ON inventory_logs(color_id);
CREATE INDEX idx_inventory_logs_action ON inventory_logs(action);
CREATE INDEX idx_inventory_logs_reference ON inventory_logs(reference_type, reference_id);
CREATE INDEX idx_inventory_logs_created_at ON inventory_logs(created_at DESC);
CREATE INDEX idx_inventory_logs_created_by ON inventory_logs(created_by);

-- ============================================
-- 15. STOCK_ALERTS (low stock notifications)
-- ============================================
CREATE TABLE stock_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    color_id UUID REFERENCES product_colors(id) ON DELETE CASCADE,
    alert_type VARCHAR(20) NOT NULL CHECK (alert_type IN ('low_stock', 'out_of_stock', 'back_in_stock')),
    current_quantity INTEGER NOT NULL,
    threshold INTEGER,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for stock_alerts
CREATE INDEX idx_stock_alerts_product_id ON stock_alerts(product_id);
CREATE INDEX idx_stock_alerts_color_id ON stock_alerts(color_id);
CREATE INDEX idx_stock_alerts_type ON stock_alerts(alert_type);
CREATE INDEX idx_stock_alerts_is_resolved ON stock_alerts(is_resolved) WHERE is_resolved = FALSE;
CREATE INDEX idx_stock_alerts_created_at ON stock_alerts(created_at DESC);

-- ============================================
-- 16. STOCK_RESERVATIONS (cart reservations)
-- ============================================
CREATE TABLE stock_reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    session_id VARCHAR(255), -- For guest users
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    color_id UUID NOT NULL REFERENCES product_colors(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    converted_to_order BOOLEAN DEFAULT FALSE,
    order_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CHECK (user_id IS NOT NULL OR session_id IS NOT NULL)
);

-- Indexes for stock_reservations
CREATE INDEX idx_stock_reservations_user_id ON stock_reservations(user_id);
CREATE INDEX idx_stock_reservations_session_id ON stock_reservations(session_id);
CREATE INDEX idx_stock_reservations_product_id ON stock_reservations(product_id);
CREATE INDEX idx_stock_reservations_color_id ON stock_reservations(color_id);
CREATE INDEX idx_stock_reservations_expires_at ON stock_reservations(expires_at);
CREATE INDEX idx_stock_reservations_is_active ON stock_reservations(is_active) WHERE is_active = TRUE;

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-create stock alert when stock is low
CREATE OR REPLACE FUNCTION check_stock_level()
RETURNS TRIGGER AS $$
DECLARE
    available_qty INTEGER;
    threshold INTEGER;
BEGIN
    available_qty := NEW.quantity - NEW.reserved_quantity;
    threshold := NEW.low_stock_threshold;
    
    -- Check for out of stock
    IF available_qty = 0 THEN
        INSERT INTO stock_alerts (product_id, color_id, alert_type, current_quantity, threshold)
        VALUES (NEW.product_id, NEW.id, 'out_of_stock', available_qty, threshold)
        ON CONFLICT DO NOTHING;
    -- Check for low stock
    ELSIF available_qty <= threshold AND available_qty > 0 THEN
        INSERT INTO stock_alerts (product_id, color_id, alert_type, current_quantity, threshold)
        VALUES (NEW.product_id, NEW.id, 'low_stock', available_qty, threshold)
        ON CONFLICT DO NOTHING;
    -- Check for back in stock (was 0, now > 0)
    ELSIF OLD.quantity - OLD.reserved_quantity = 0 AND available_qty > 0 THEN
        INSERT INTO stock_alerts (product_id, color_id, alert_type, current_quantity, threshold)
        VALUES (NEW.product_id, NEW.id, 'back_in_stock', available_qty, threshold)
        ON CONFLICT DO NOTHING;
        
        -- Resolve any out_of_stock alerts
        UPDATE stock_alerts 
        SET is_resolved = TRUE, resolved_at = NOW()
        WHERE color_id = NEW.id 
        AND alert_type = 'out_of_stock'
        AND is_resolved = FALSE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_stock_level
    AFTER UPDATE ON product_colors
    FOR EACH ROW
    WHEN (OLD.quantity IS DISTINCT FROM NEW.quantity 
          OR OLD.reserved_quantity IS DISTINCT FROM NEW.reserved_quantity)
    EXECUTE FUNCTION check_stock_level();

-- Auto-release expired reservations
CREATE OR REPLACE FUNCTION release_expired_reservations()
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT id, color_id, quantity 
        FROM stock_reservations 
        WHERE is_active = TRUE 
        AND expires_at < NOW()
    LOOP
        -- Release the reserved quantity
        UPDATE product_colors 
        SET reserved_quantity = reserved_quantity - r.quantity
        WHERE id = r.color_id;
        
        -- Mark reservation as inactive
        UPDATE stock_reservations 
        SET is_active = FALSE
        WHERE id = r.id;
        
        -- Log the release
        INSERT INTO inventory_logs (
            product_id, color_id, action, quantity_change,
            quantity_before, quantity_after, reference_type, reference_id, notes
        )
        SELECT 
            pc.product_id, r.color_id, 'release', r.quantity,
            pc.quantity, pc.quantity, 'cart', r.id, 'Auto-released expired reservation'
        FROM product_colors pc WHERE pc.id = r.color_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Reserve stock for cart
CREATE OR REPLACE FUNCTION reserve_stock(
    p_user_id UUID,
    p_color_id UUID,
    p_quantity INTEGER,
    p_duration_minutes INTEGER DEFAULT 30
)
RETURNS UUID AS $$
DECLARE
    v_product_id UUID;
    v_available INTEGER;
    v_reservation_id UUID;
    v_qty_before INTEGER;
    v_reserved_before INTEGER;
BEGIN
    -- Get product and available stock
    SELECT product_id, quantity - reserved_quantity, quantity, reserved_quantity
    INTO v_product_id, v_available, v_qty_before, v_reserved_before
    FROM product_colors
    WHERE id = p_color_id
    FOR UPDATE;
    
    -- Check if enough stock available
    IF v_available < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', v_available, p_quantity;
    END IF;
    
    -- Create reservation
    INSERT INTO stock_reservations (
        user_id, product_id, color_id, quantity, expires_at
    ) VALUES (
        p_user_id, v_product_id, p_color_id, p_quantity,
        NOW() + (p_duration_minutes || ' minutes')::INTERVAL
    ) RETURNING id INTO v_reservation_id;
    
    -- Update reserved quantity
    UPDATE product_colors 
    SET reserved_quantity = reserved_quantity + p_quantity
    WHERE id = p_color_id;
    
    -- Log the reservation
    INSERT INTO inventory_logs (
        product_id, color_id, action, quantity_change,
        quantity_before, quantity_after,
        reserved_before, reserved_after,
        reference_type, reference_id, created_by
    ) VALUES (
        v_product_id, p_color_id, 'reserve', p_quantity,
        v_qty_before, v_qty_before,
        v_reserved_before, v_reserved_before + p_quantity,
        'cart', v_reservation_id, p_user_id
    );
    
    RETURN v_reservation_id;
END;
$$ LANGUAGE plpgsql;

-- Release stock reservation
CREATE OR REPLACE FUNCTION release_stock(
    p_reservation_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_reservation RECORD;
    v_qty_before INTEGER;
    v_reserved_before INTEGER;
BEGIN
    -- Get reservation
    SELECT * INTO v_reservation
    FROM stock_reservations
    WHERE id = p_reservation_id AND is_active = TRUE
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Get current stock info
    SELECT quantity, reserved_quantity 
    INTO v_qty_before, v_reserved_before
    FROM product_colors WHERE id = v_reservation.color_id;
    
    -- Release reserved quantity
    UPDATE product_colors 
    SET reserved_quantity = GREATEST(0, reserved_quantity - v_reservation.quantity)
    WHERE id = v_reservation.color_id;
    
    -- Mark reservation as inactive
    UPDATE stock_reservations 
    SET is_active = FALSE
    WHERE id = p_reservation_id;
    
    -- Log the release
    INSERT INTO inventory_logs (
        product_id, color_id, action, quantity_change,
        quantity_before, quantity_after,
        reserved_before, reserved_after,
        reference_type, reference_id, created_by
    ) VALUES (
        v_reservation.product_id, v_reservation.color_id, 'release', v_reservation.quantity,
        v_qty_before, v_qty_before,
        v_reserved_before, GREATEST(0, v_reserved_before - v_reservation.quantity),
        'cart', p_reservation_id, v_reservation.user_id
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE inventory_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_reservations ENABLE ROW LEVEL SECURITY;

-- Only admins can view inventory logs
CREATE POLICY "Admins can view inventory logs"
    ON inventory_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND is_admin = TRUE
        )
    );

-- Only admins can view stock alerts
CREATE POLICY "Admins can view stock alerts"
    ON stock_alerts FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND is_admin = TRUE
        )
    );

-- Users can view their own reservations
CREATE POLICY "Users can view own reservations"
    ON stock_reservations FOR SELECT
    USING (auth.uid() = user_id);
