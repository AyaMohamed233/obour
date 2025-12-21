-- ============================================
-- FIX: Essential RPC Function Permissions (Simplified)
-- ============================================
-- Run this in Supabase SQL Editor

-- 1. First, let's check what functions exist and grant permissions only to those

-- Create the add_to_cart function if it doesn't exist or fix it
CREATE OR REPLACE FUNCTION add_to_cart(
    p_user_id UUID,
    p_product_id UUID,
    p_color_id UUID,
    p_quantity INTEGER
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing_item RECORD;
    v_cart_item_id UUID;
    v_unit_price DECIMAL(10,2);
    v_available INTEGER;
BEGIN
    -- Verify user
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Get product price
    SELECT price INTO v_unit_price FROM products WHERE id = p_product_id;
    IF v_unit_price IS NULL THEN
        RAISE EXCEPTION 'Product not found';
    END IF;
    
    -- Get available stock
    SELECT quantity - COALESCE(reserved_quantity, 0) INTO v_available
    FROM product_colors WHERE id = p_color_id;
    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Color not found';
    END IF;
    
    -- Check existing cart item
    SELECT * INTO v_existing_item FROM cart_items
    WHERE user_id = p_user_id AND product_id = p_product_id AND color_id = p_color_id;
    
    IF FOUND THEN
        IF (v_existing_item.quantity + p_quantity) > v_available THEN
            RAISE EXCEPTION 'Insufficient stock. Available: %', v_available;
        END IF;
        UPDATE cart_items SET quantity = quantity + p_quantity, updated_at = NOW()
        WHERE id = v_existing_item.id RETURNING id INTO v_cart_item_id;
    ELSE
        IF p_quantity > v_available THEN 
            RAISE EXCEPTION 'Insufficient stock. Available: %', v_available;
        END IF;
        INSERT INTO cart_items (user_id, product_id, color_id, quantity, unit_price)
        VALUES (p_user_id, p_product_id, p_color_id, p_quantity, v_unit_price)
        RETURNING id INTO v_cart_item_id;
    END IF;
    
    RETURN v_cart_item_id;
END;
$$ LANGUAGE plpgsql;

-- Create get_cart_details function
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
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    RETURN QUERY
    SELECT 
        ci.id as cart_item_id,
        ci.product_id,
        p.name as product_name,
        (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.id ORDER BY is_primary DESC, sort_order LIMIT 1) as product_image,
        ci.color_id,
        pc.color_name,
        pc.color_hex,
        ci.quantity,
        p.price as unit_price,
        NULL::DECIMAL as sale_price,
        (pc.quantity - COALESCE(pc.reserved_quantity, 0))::INTEGER as available_stock,
        (ci.quantity * p.price)::DECIMAL as line_total
    FROM cart_items ci
    JOIN products p ON ci.product_id = p.id
    JOIN product_colors pc ON ci.color_id = pc.id
    WHERE ci.user_id = p_user_id
    ORDER BY ci.added_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create remove_from_cart function
CREATE OR REPLACE FUNCTION remove_from_cart(
    p_user_id UUID,
    p_cart_item_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    DELETE FROM cart_items WHERE id = p_cart_item_id AND user_id = p_user_id;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create update_cart_quantity function
CREATE OR REPLACE FUNCTION update_cart_quantity(
    p_user_id UUID,
    p_cart_item_id UUID,
    p_new_quantity INTEGER
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cart_item RECORD;
    v_available INTEGER;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    IF p_new_quantity <= 0 THEN
        DELETE FROM cart_items WHERE id = p_cart_item_id AND user_id = p_user_id;
        RETURN TRUE;
    END IF;
    
    SELECT ci.*, pc.quantity - COALESCE(pc.reserved_quantity, 0) as avail
    INTO v_cart_item
    FROM cart_items ci
    JOIN product_colors pc ON ci.color_id = pc.id
    WHERE ci.id = p_cart_item_id AND ci.user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    IF p_new_quantity > v_cart_item.avail THEN
        RAISE EXCEPTION 'Insufficient stock';
    END IF;
    
    UPDATE cart_items SET quantity = p_new_quantity, updated_at = NOW()
    WHERE id = p_cart_item_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION add_to_cart(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_cart_details(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_from_cart(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_cart_quantity(UUID, UUID, INTEGER) TO authenticated;

-- Success
SELECT 'Essential shopping functions created and permissions granted!' as message;
