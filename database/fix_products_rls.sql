-- Fix Products RLS Policies for Admin
-- This allows admins to update/insert/delete products

-- First, check if RLS is enabled
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_colors ENABLE ROW LEVEL SECURITY;

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Products are viewable by everyone" ON products;
DROP POLICY IF EXISTS "Admins can manage products" ON products;
DROP POLICY IF EXISTS "Admin full access to products" ON products;

-- Create new policies for products
CREATE POLICY "Products are viewable by everyone"
ON products FOR SELECT
USING (true);

CREATE POLICY "Admins can insert products"
ON products FOR INSERT
WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can update products"
ON products FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can delete products"
ON products FOR DELETE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- Product Images Policies
DROP POLICY IF EXISTS "Images viewable by everyone" ON product_images;
DROP POLICY IF EXISTS "Admins can manage images" ON product_images;

CREATE POLICY "Images viewable by everyone"
ON product_images FOR SELECT
USING (true);

CREATE POLICY "Admins can insert images"
ON product_images FOR INSERT
WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can update images"
ON product_images FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can delete images"
ON product_images FOR DELETE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- Product Colors Policies
DROP POLICY IF EXISTS "Colors viewable by everyone" ON product_colors;
DROP POLICY IF EXISTS "Admins can manage colors" ON product_colors;

CREATE POLICY "Colors viewable by everyone"
ON product_colors FOR SELECT
USING (true);

CREATE POLICY "Admins can insert colors"
ON product_colors FOR INSERT
WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can update colors"
ON product_colors FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

CREATE POLICY "Admins can delete colors"
ON product_colors FOR DELETE
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- Categories and Brands (also needed)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Categories viewable by everyone" ON categories;
CREATE POLICY "Categories viewable by everyone"
ON categories FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Brands viewable by everyone" ON brands;
CREATE POLICY "Brands viewable by everyone"
ON brands FOR SELECT
USING (true);
