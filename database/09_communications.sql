-- ============================================
-- BAGS STORE - COMMUNICATIONS TABLES
-- ============================================
-- Tables: notifications, contact_messages, newsletter_subscribers
-- ============================================

-- ============================================
-- 32. NOTIFICATIONS
-- ============================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Type and Category
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'order_created', 'order_confirmed', 'order_shipped', 'order_delivered',
        'order_cancelled', 'payment_received', 'payment_failed', 'refund_processed',
        'price_drop', 'back_in_stock', 'review_approved', 'review_reply',
        'coupon_expiring', 'wishlist_sale', 'system', 'promotion'
    )),
    category VARCHAR(20) DEFAULT 'general' CHECK (category IN (
        'order', 'payment', 'product', 'review', 'promotion', 'system', 'general'
    )),
    
    -- Content
    title VARCHAR(200) NOT NULL,
    title_ar VARCHAR(200),
    message TEXT NOT NULL,
    message_ar TEXT,
    
    -- Links
    action_url TEXT,
    action_text VARCHAR(50),
    
    -- Related entities
    reference_type VARCHAR(30),
    reference_id UUID,
    
    -- Image/Icon
    image_url TEXT,
    icon VARCHAR(50),
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- Push notification
    push_sent BOOLEAN DEFAULT FALSE,
    push_sent_at TIMESTAMPTZ,
    
    -- Expiry
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_category ON notifications(category);
CREATE INDEX idx_notifications_is_read ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_reference ON notifications(reference_type, reference_id);

-- ============================================
-- 33. CONTACT_MESSAGES
-- ============================================
CREATE TABLE contact_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Contact Info
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    
    -- Message
    subject VARCHAR(200),
    message TEXT NOT NULL,
    
    -- Categorization
    category VARCHAR(30) DEFAULT 'general' CHECK (category IN (
        'general', 'order_inquiry', 'product_question', 'complaint',
        'return_request', 'payment_issue', 'shipping', 'feedback', 'other'
    )),
    
    -- Status
    status VARCHAR(20) DEFAULT 'new' CHECK (status IN (
        'new', 'open', 'in_progress', 'waiting_customer', 'resolved', 'closed', 'spam'
    )),
    priority VARCHAR(10) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Assignment
    assigned_to UUID REFERENCES profiles(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ,
    
    -- Related order (if applicable)
    related_order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    
    -- Reply
    admin_reply TEXT,
    replied_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    replied_at TIMESTAMPTZ,
    
    -- Resolution
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Metadata
    source VARCHAR(20) DEFAULT 'website' CHECK (source IN ('website', 'email', 'phone', 'social', 'chat')),
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for contact_messages
CREATE INDEX idx_contact_messages_user_id ON contact_messages(user_id);
CREATE INDEX idx_contact_messages_email ON contact_messages(email);
CREATE INDEX idx_contact_messages_status ON contact_messages(status);
CREATE INDEX idx_contact_messages_priority ON contact_messages(priority);
CREATE INDEX idx_contact_messages_category ON contact_messages(category);
CREATE INDEX idx_contact_messages_assigned_to ON contact_messages(assigned_to);
CREATE INDEX idx_contact_messages_created_at ON contact_messages(created_at DESC);
CREATE INDEX idx_contact_messages_new ON contact_messages(status) WHERE status = 'new';

-- ============================================
-- 34. NEWSLETTER_SUBSCRIBERS
-- ============================================
CREATE TABLE newsletter_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Subscriber Info
    name VARCHAR(100),
    
    -- Preferences
    preferences JSONB DEFAULT '{"promotions": true, "new_arrivals": true, "sales": true}'::jsonb,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255),
    verified_at TIMESTAMPTZ,
    
    -- Subscription management
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    unsubscribed_at TIMESTAMPTZ,
    unsubscribe_reason TEXT,
    
    -- Source tracking
    source VARCHAR(50) DEFAULT 'website' CHECK (source IN (
        'website', 'checkout', 'popup', 'footer', 'landing_page', 'import'
    )),
    source_url TEXT,
    
    -- Engagement
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    last_email_at TIMESTAMPTZ,
    last_opened_at TIMESTAMPTZ,
    last_clicked_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for newsletter_subscribers
CREATE INDEX idx_newsletter_email ON newsletter_subscribers(email);
CREATE INDEX idx_newsletter_user_id ON newsletter_subscribers(user_id);
CREATE INDEX idx_newsletter_is_active ON newsletter_subscribers(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_newsletter_is_verified ON newsletter_subscribers(is_verified);
CREATE INDEX idx_newsletter_subscribed_at ON newsletter_subscribers(subscribed_at DESC);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_contact_messages_updated_at
    BEFORE UPDATE ON contact_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_newsletter_updated_at
    BEFORE UPDATE ON newsletter_subscribers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Create notification
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type VARCHAR(50),
    p_title VARCHAR(200),
    p_message TEXT,
    p_action_url TEXT DEFAULT NULL,
    p_reference_type VARCHAR(30) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_notification_id UUID;
    v_category VARCHAR(20);
BEGIN
    -- Determine category from type
    v_category := CASE 
        WHEN p_type LIKE 'order%' THEN 'order'
        WHEN p_type LIKE 'payment%' OR p_type LIKE 'refund%' THEN 'payment'
        WHEN p_type LIKE 'price%' OR p_type LIKE 'back_in%' THEN 'product'
        WHEN p_type LIKE 'review%' THEN 'review'
        WHEN p_type LIKE 'coupon%' OR p_type LIKE 'wishlist%' OR p_type = 'promotion' THEN 'promotion'
        WHEN p_type = 'system' THEN 'system'
        ELSE 'general'
    END;
    
    INSERT INTO notifications (
        user_id, type, category, title, message,
        action_url, reference_type, reference_id
    ) VALUES (
        p_user_id, p_type, v_category, p_title, p_message,
        p_action_url, p_reference_type, p_reference_id
    ) RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- Mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(
    p_user_id UUID,
    p_notification_ids UUID[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF p_notification_ids IS NULL THEN
        -- Mark all as read
        UPDATE notifications
        SET is_read = TRUE, read_at = NOW()
        WHERE user_id = p_user_id AND is_read = FALSE;
    ELSE
        -- Mark specific ones as read
        UPDATE notifications
        SET is_read = TRUE, read_at = NOW()
        WHERE user_id = p_user_id 
        AND id = ANY(p_notification_ids)
        AND is_read = FALSE;
    END IF;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Get unread notification count
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) 
        FROM notifications 
        WHERE user_id = p_user_id 
        AND is_read = FALSE 
        AND is_archived = FALSE
        AND (expires_at IS NULL OR expires_at > NOW())
    )::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Subscribe to newsletter
CREATE OR REPLACE FUNCTION subscribe_newsletter(
    p_email VARCHAR(255),
    p_name VARCHAR(100) DEFAULT NULL,
    p_source VARCHAR(50) DEFAULT 'website',
    p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_subscriber_id UUID;
    v_token VARCHAR(255);
BEGIN
    -- Generate verification token
    v_token := encode(gen_random_bytes(32), 'hex');
    
    INSERT INTO newsletter_subscribers (email, name, source, user_id, verification_token)
    VALUES (p_email, p_name, p_source, p_user_id, v_token)
    ON CONFLICT (email) DO UPDATE
    SET is_active = TRUE,
        unsubscribed_at = NULL,
        updated_at = NOW()
    RETURNING id INTO v_subscriber_id;
    
    RETURN v_subscriber_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE newsletter_subscribers ENABLE ROW LEVEL SECURITY;

-- Users can manage own notifications
CREATE POLICY "Users can manage own notifications"
    ON notifications FOR ALL
    USING (auth.uid() = user_id);

-- Users can view own contact messages
CREATE POLICY "Users can view own contact messages"
    ON contact_messages FOR SELECT
    USING (auth.uid() = user_id);

-- Anyone can create contact messages
CREATE POLICY "Anyone can create contact messages"
    ON contact_messages FOR INSERT
    WITH CHECK (TRUE);

-- Users can manage own newsletter subscription
CREATE POLICY "Users can manage own newsletter subscription"
    ON newsletter_subscribers FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL);
