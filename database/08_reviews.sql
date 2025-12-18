-- ============================================
-- BAGS STORE - REVIEWS & RATINGS TABLES
-- ============================================
-- Tables: reviews, review_images
-- ============================================

-- ============================================
-- 30. REVIEWS
-- ============================================
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
    
    -- Review Content
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    pros TEXT,
    cons TEXT,
    
    -- Verification
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    
    -- Moderation
    is_approved BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    is_hidden BOOLEAN DEFAULT FALSE,
    moderation_status VARCHAR(20) DEFAULT 'pending' CHECK (moderation_status IN (
        'pending', 'approved', 'rejected', 'flagged'
    )),
    moderation_notes TEXT,
    moderated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ,
    
    -- Engagement
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    reported_count INTEGER DEFAULT 0,
    
    -- Admin Response
    admin_reply TEXT,
    admin_reply_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    admin_reply_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- One review per product per user
    UNIQUE(user_id, product_id)
);

-- Indexes for reviews
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_product_id ON reviews(product_id);
CREATE INDEX idx_reviews_order_id ON reviews(order_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_is_approved ON reviews(is_approved) WHERE is_approved = TRUE;
CREATE INDEX idx_reviews_is_featured ON reviews(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_reviews_moderation_status ON reviews(moderation_status);
CREATE INDEX idx_reviews_created_at ON reviews(created_at DESC);
CREATE INDEX idx_reviews_helpful ON reviews(helpful_count DESC);

-- ============================================
-- 31. REVIEW_IMAGES
-- ============================================
CREATE TABLE review_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    alt_text VARCHAR(200),
    sort_order INTEGER DEFAULT 0,
    is_approved BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for review_images
CREATE INDEX idx_review_images_review_id ON review_images(review_id);
CREATE INDEX idx_review_images_is_approved ON review_images(is_approved);

-- ============================================
-- REVIEW_HELPFUL (track who found reviews helpful)
-- ============================================
CREATE TABLE review_helpful (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    is_helpful BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(review_id, user_id)
);

-- Indexes
CREATE INDEX idx_review_helpful_review_id ON review_helpful(review_id);
CREATE INDEX idx_review_helpful_user_id ON review_helpful(user_id);

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trigger_reviews_updated_at
    BEFORE UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Update product rating when review is added/updated
CREATE OR REPLACE FUNCTION update_product_rating()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id UUID;
BEGIN
    -- Determine which product to update
    IF TG_OP = 'DELETE' THEN
        v_product_id := OLD.product_id;
    ELSE
        v_product_id := NEW.product_id;
    END IF;
    
    -- Calculate new average rating
    UPDATE products 
    SET avg_rating = COALESCE((
            SELECT ROUND(AVG(rating)::DECIMAL, 2) 
            FROM reviews 
            WHERE product_id = v_product_id 
            AND is_approved = TRUE
        ), 0),
        review_count = (
            SELECT COUNT(*) 
            FROM reviews 
            WHERE product_id = v_product_id 
            AND is_approved = TRUE
        )
    WHERE id = v_product_id;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_rating
    AFTER INSERT OR UPDATE OR DELETE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_product_rating();

-- Update helpful counts
CREATE OR REPLACE FUNCTION update_review_helpful_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_helpful THEN
            UPDATE reviews SET helpful_count = helpful_count + 1 WHERE id = NEW.review_id;
        ELSE
            UPDATE reviews SET not_helpful_count = not_helpful_count + 1 WHERE id = NEW.review_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_helpful != NEW.is_helpful THEN
            IF NEW.is_helpful THEN
                UPDATE reviews 
                SET helpful_count = helpful_count + 1,
                    not_helpful_count = GREATEST(0, not_helpful_count - 1)
                WHERE id = NEW.review_id;
            ELSE
                UPDATE reviews 
                SET helpful_count = GREATEST(0, helpful_count - 1),
                    not_helpful_count = not_helpful_count + 1
                WHERE id = NEW.review_id;
            END IF;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.is_helpful THEN
            UPDATE reviews SET helpful_count = GREATEST(0, helpful_count - 1) WHERE id = OLD.review_id;
        ELSE
            UPDATE reviews SET not_helpful_count = GREATEST(0, not_helpful_count - 1) WHERE id = OLD.review_id;
        END IF;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_helpful_counts
    AFTER INSERT OR UPDATE OR DELETE ON review_helpful
    FOR EACH ROW
    EXECUTE FUNCTION update_review_helpful_counts();

-- Mark order item as reviewed
CREATE OR REPLACE FUNCTION mark_order_item_reviewed()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_item_id IS NOT NULL THEN
        UPDATE order_items 
        SET has_reviewed = TRUE 
        WHERE id = NEW.order_item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_mark_order_item_reviewed
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION mark_order_item_reviewed();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Create review
CREATE OR REPLACE FUNCTION create_review(
    p_user_id UUID,
    p_product_id UUID,
    p_order_id UUID,
    p_order_item_id UUID,
    p_rating INTEGER,
    p_title VARCHAR(200),
    p_comment TEXT,
    p_pros TEXT DEFAULT NULL,
    p_cons TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_review_id UUID;
    v_is_verified BOOLEAN;
BEGIN
    -- Check if user purchased this product
    SELECT EXISTS (
        SELECT 1 FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        WHERE o.user_id = p_user_id 
        AND oi.product_id = p_product_id
        AND o.status = 'delivered'
    ) INTO v_is_verified;
    
    -- Create review
    INSERT INTO reviews (
        user_id, product_id, order_id, order_item_id,
        rating, title, comment, pros, cons,
        is_verified_purchase
    ) VALUES (
        p_user_id, p_product_id, p_order_id, p_order_item_id,
        p_rating, p_title, p_comment, p_pros, p_cons,
        v_is_verified
    ) RETURNING id INTO v_review_id;
    
    RETURN v_review_id;
END;
$$ LANGUAGE plpgsql;

-- Get product reviews with pagination
CREATE OR REPLACE FUNCTION get_product_reviews(
    p_product_id UUID,
    p_page INTEGER DEFAULT 1,
    p_limit INTEGER DEFAULT 10,
    p_sort_by VARCHAR(20) DEFAULT 'newest'
)
RETURNS TABLE (
    review_id UUID,
    user_id UUID,
    user_name VARCHAR,
    user_avatar TEXT,
    rating INTEGER,
    title VARCHAR,
    comment TEXT,
    pros TEXT,
    cons TEXT,
    is_verified_purchase BOOLEAN,
    helpful_count INTEGER,
    admin_reply TEXT,
    admin_reply_at TIMESTAMPTZ,
    images JSONB,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as review_id,
        r.user_id,
        p.full_name as user_name,
        p.avatar_url as user_avatar,
        r.rating,
        r.title,
        r.comment,
        r.pros,
        r.cons,
        r.is_verified_purchase,
        r.helpful_count,
        r.admin_reply,
        r.admin_reply_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('url', ri.image_url, 'thumbnail', ri.thumbnail_url))
             FROM review_images ri WHERE ri.review_id = r.id AND ri.is_approved = TRUE),
            '[]'::jsonb
        ) as images,
        r.created_at
    FROM reviews r
    JOIN profiles p ON r.user_id = p.id
    WHERE r.product_id = p_product_id
    AND r.is_approved = TRUE
    AND r.is_hidden = FALSE
    ORDER BY 
        CASE WHEN p_sort_by = 'newest' THEN r.created_at END DESC,
        CASE WHEN p_sort_by = 'oldest' THEN r.created_at END ASC,
        CASE WHEN p_sort_by = 'highest' THEN r.rating END DESC,
        CASE WHEN p_sort_by = 'lowest' THEN r.rating END ASC,
        CASE WHEN p_sort_by = 'helpful' THEN r.helpful_count END DESC
    LIMIT p_limit
    OFFSET (p_page - 1) * p_limit;
END;
$$ LANGUAGE plpgsql;

-- Get review statistics for product
CREATE OR REPLACE FUNCTION get_review_stats(p_product_id UUID)
RETURNS TABLE (
    total_reviews INTEGER,
    average_rating DECIMAL,
    rating_5 INTEGER,
    rating_4 INTEGER,
    rating_3 INTEGER,
    rating_2 INTEGER,
    rating_1 INTEGER,
    verified_count INTEGER,
    with_images_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_reviews,
        ROUND(AVG(rating)::DECIMAL, 2) as average_rating,
        COUNT(*) FILTER (WHERE rating = 5)::INTEGER as rating_5,
        COUNT(*) FILTER (WHERE rating = 4)::INTEGER as rating_4,
        COUNT(*) FILTER (WHERE rating = 3)::INTEGER as rating_3,
        COUNT(*) FILTER (WHERE rating = 2)::INTEGER as rating_2,
        COUNT(*) FILTER (WHERE rating = 1)::INTEGER as rating_1,
        COUNT(*) FILTER (WHERE is_verified_purchase = TRUE)::INTEGER as verified_count,
        COUNT(DISTINCT r.id) FILTER (WHERE EXISTS (
            SELECT 1 FROM review_images ri WHERE ri.review_id = r.id
        ))::INTEGER as with_images_count
    FROM reviews r
    WHERE r.product_id = p_product_id
    AND r.is_approved = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_helpful ENABLE ROW LEVEL SECURITY;

-- Anyone can view approved reviews
CREATE POLICY "Anyone can view approved reviews"
    ON reviews FOR SELECT
    USING (is_approved = TRUE AND is_hidden = FALSE);

-- Users can create reviews
CREATE POLICY "Users can create reviews"
    ON reviews FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update own reviews
CREATE POLICY "Users can update own reviews"
    ON reviews FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete own reviews
CREATE POLICY "Users can delete own reviews"
    ON reviews FOR DELETE
    USING (auth.uid() = user_id);

-- Anyone can view approved review images
CREATE POLICY "Anyone can view approved review images"
    ON review_images FOR SELECT
    USING (is_approved = TRUE);

-- Users can add images to own reviews
CREATE POLICY "Users can add images to own reviews"
    ON review_images FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM reviews 
            WHERE reviews.id = review_images.review_id 
            AND reviews.user_id = auth.uid()
        )
    );

-- Users can manage own helpful votes
CREATE POLICY "Users can manage own helpful votes"
    ON review_helpful FOR ALL
    USING (auth.uid() = user_id);
