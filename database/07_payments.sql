-- ============================================
-- BAGS STORE - PAYMENTS & TRANSACTIONS TABLES
-- ============================================
-- Tables: transactions, refunds, payment_methods_saved
-- ============================================

-- ============================================
-- 27. TRANSACTIONS
-- ============================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Type and Method
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN (
        'payment', 'refund', 'chargeback', 'payout'
    )),
    payment_method VARCHAR(20) CHECK (payment_method IN ('cod', 'card', 'wallet', 'bank_transfer')),
    
    -- Amount
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EGP',
    status VARCHAR(20) NOT NULL CHECK (status IN (
        'pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded'
    )),
    
    -- Stripe Info
    stripe_payment_intent_id VARCHAR(255),
    stripe_charge_id VARCHAR(255),
    stripe_refund_id VARCHAR(255),
    stripe_fee DECIMAL(10,2),
    net_amount DECIMAL(10,2), -- Amount after fees
    
    -- Card Details (for display)
    card_last_four VARCHAR(4),
    card_brand VARCHAR(20),
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    
    -- Additional Info
    description TEXT,
    notes TEXT,
    metadata JSONB,
    failure_reason TEXT,
    
    -- For balance calculations
    affects_balance BOOLEAN DEFAULT TRUE,
    balance_effect DECIMAL(10,2), -- Positive = credit, Negative = debit
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for transactions
CREATE INDEX idx_transactions_order_id ON transactions(order_id);
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_stripe_payment ON transactions(stripe_payment_intent_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_affects_balance ON transactions(affects_balance) WHERE affects_balance = TRUE;

-- ============================================
-- 28. REFUNDS
-- ============================================
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    original_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    
    -- Amount
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    reason_code VARCHAR(50) CHECK (reason_code IN (
        'customer_request', 'damaged_item', 'wrong_item', 
        'item_not_received', 'duplicate_charge', 'other'
    )),
    reason TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'approved', 'rejected', 'processing', 'completed', 'failed'
    )),
    
    -- Refund Method
    refund_method VARCHAR(20) CHECK (refund_method IN (
        'original_payment', 'store_credit', 'cash', 'bank_transfer'
    )),
    
    -- Stripe
    stripe_refund_id VARCHAR(255),
    
    -- Processing
    processed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    processed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- Items being refunded
    refund_items JSONB, -- Array of {order_item_id, quantity, amount}
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for refunds
CREATE INDEX idx_refunds_order_id ON refunds(order_id);
CREATE INDEX idx_refunds_status ON refunds(status);
CREATE INDEX idx_refunds_created_at ON refunds(created_at DESC);

-- ============================================
-- 29. PAYMENT_METHODS_SAVED
-- ============================================
CREATE TABLE payment_methods_saved (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Stripe
    stripe_payment_method_id VARCHAR(255) NOT NULL,
    stripe_customer_id VARCHAR(255),
    
    -- Card Info
    card_brand VARCHAR(20),
    card_last_four VARCHAR(4),
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    card_funding VARCHAR(20), -- credit, debit, prepaid
    
    -- Display
    nickname VARCHAR(50),
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Verification
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for payment_methods_saved
CREATE INDEX idx_payment_methods_user_id ON payment_methods_saved(user_id);
CREATE INDEX idx_payment_methods_is_default ON payment_methods_saved(user_id, is_default) WHERE is_default = TRUE;
CREATE INDEX idx_payment_methods_stripe ON payment_methods_saved(stripe_payment_method_id);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_refunds_updated_at
    BEFORE UPDATE ON refunds
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods_saved
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Ensure only one default payment method per user
CREATE OR REPLACE FUNCTION ensure_single_default_payment_method()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default = TRUE THEN
        UPDATE payment_methods_saved 
        SET is_default = FALSE 
        WHERE user_id = NEW.user_id 
        AND id != NEW.id 
        AND is_default = TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_single_default_payment_method
    BEFORE INSERT OR UPDATE ON payment_methods_saved
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_default_payment_method();

-- Calculate balance effect
CREATE OR REPLACE FUNCTION calculate_balance_effect()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.transaction_type = 'payment' AND NEW.status = 'completed' THEN
        NEW.balance_effect := NEW.amount;
    ELSIF NEW.transaction_type = 'refund' AND NEW.status = 'completed' THEN
        NEW.balance_effect := -NEW.amount;
    ELSIF NEW.transaction_type = 'chargeback' AND NEW.status = 'completed' THEN
        NEW.balance_effect := -NEW.amount;
    ELSE
        NEW.balance_effect := 0;
    END IF;
    
    NEW.net_amount := NEW.amount - COALESCE(NEW.stripe_fee, 0);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_balance_effect
    BEFORE INSERT OR UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION calculate_balance_effect();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Get financial summary
CREATE OR REPLACE FUNCTION get_financial_summary(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    total_revenue DECIMAL,
    total_refunds DECIMAL,
    total_fees DECIMAL,
    net_revenue DECIMAL,
    total_orders INTEGER,
    cod_revenue DECIMAL,
    online_revenue DECIMAL,
    pending_cod DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN t.transaction_type = 'payment' AND t.status = 'completed' THEN t.amount ELSE 0 END), 0) as total_revenue,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'refund' AND t.status = 'completed' THEN t.amount ELSE 0 END), 0) as total_refunds,
        COALESCE(SUM(CASE WHEN t.status = 'completed' THEN t.stripe_fee ELSE 0 END), 0) as total_fees,
        COALESCE(SUM(t.balance_effect), 0) as net_revenue,
        COUNT(DISTINCT t.order_id)::INTEGER as total_orders,
        COALESCE(SUM(CASE WHEN t.payment_method = 'cod' AND t.status = 'completed' THEN t.amount ELSE 0 END), 0) as cod_revenue,
        COALESCE(SUM(CASE WHEN t.payment_method IN ('card', 'wallet') AND t.status = 'completed' THEN t.amount ELSE 0 END), 0) as online_revenue,
        COALESCE(SUM(CASE WHEN t.payment_method = 'cod' AND t.status = 'pending' THEN t.amount ELSE 0 END), 0) as pending_cod
    FROM transactions t
    WHERE t.affects_balance = TRUE
    AND (p_start_date IS NULL OR t.created_at >= p_start_date)
    AND (p_end_date IS NULL OR t.created_at <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- Create payment transaction
CREATE OR REPLACE FUNCTION create_payment_transaction(
    p_order_id UUID,
    p_payment_method VARCHAR(20),
    p_amount DECIMAL(10,2),
    p_stripe_payment_intent_id VARCHAR(255) DEFAULT NULL,
    p_card_last_four VARCHAR(4) DEFAULT NULL,
    p_card_brand VARCHAR(20) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
    v_user_id UUID;
    v_status VARCHAR(20);
BEGIN
    -- Get order info
    SELECT user_id INTO v_user_id FROM orders WHERE id = p_order_id;
    
    -- Determine status
    IF p_payment_method = 'cod' THEN
        v_status := 'pending';
    ELSE
        v_status := 'completed';
    END IF;
    
    -- Create transaction
    INSERT INTO transactions (
        order_id, user_id, transaction_type, payment_method,
        amount, status, stripe_payment_intent_id,
        card_last_four, card_brand
    ) VALUES (
        p_order_id, v_user_id, 'payment', p_payment_method,
        p_amount, v_status, p_stripe_payment_intent_id,
        p_card_last_four, p_card_brand
    ) RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Process refund
CREATE OR REPLACE FUNCTION process_refund(
    p_refund_id UUID,
    p_admin_id UUID,
    p_approve BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_refund RECORD;
    v_transaction_id UUID;
BEGIN
    -- Get refund
    SELECT * INTO v_refund FROM refunds WHERE id = p_refund_id FOR UPDATE;
    
    IF NOT FOUND OR v_refund.status != 'pending' THEN
        RETURN FALSE;
    END IF;
    
    IF NOT p_approve THEN
        UPDATE refunds
        SET status = 'rejected',
            processed_by = p_admin_id,
            processed_at = NOW(),
            rejection_reason = p_rejection_reason
        WHERE id = p_refund_id;
        RETURN TRUE;
    END IF;
    
    -- Create refund transaction
    INSERT INTO transactions (
        order_id, user_id, transaction_type, payment_method,
        amount, status, description
    )
    SELECT 
        v_refund.order_id, o.user_id, 'refund', o.payment_method,
        v_refund.amount, 'completed', v_refund.reason
    FROM orders o WHERE o.id = v_refund.order_id
    RETURNING id INTO v_transaction_id;
    
    -- Update refund
    UPDATE refunds
    SET status = 'completed',
        transaction_id = v_transaction_id,
        processed_by = p_admin_id,
        processed_at = NOW()
    WHERE id = p_refund_id;
    
    -- Update order payment status
    UPDATE orders
    SET payment_status = 'refunded'
    WHERE id = v_refund.order_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods_saved ENABLE ROW LEVEL SECURITY;

-- Users can view own transactions
CREATE POLICY "Users can view own transactions"
    ON transactions FOR SELECT
    USING (auth.uid() = user_id);

-- Users can view own refunds
CREATE POLICY "Users can view own refunds"
    ON refunds FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = refunds.order_id 
            AND orders.user_id = auth.uid()
        )
    );

-- Users can manage own payment methods
CREATE POLICY "Users can manage own payment methods"
    ON payment_methods_saved FOR ALL
    USING (auth.uid() = user_id);
