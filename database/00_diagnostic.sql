-- ============================================
-- DIAGNOSTIC: Database Structure Analysis
-- ============================================
-- Run this FIRST and share the results

-- 1. List all existing tables
SELECT '=== TABLES ===' as section;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 2. Orders table structure
SELECT '=== ORDERS COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'orders'
ORDER BY ordinal_position;

-- 3. Order Items table structure
SELECT '=== ORDER_ITEMS COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'order_items'
ORDER BY ordinal_position;

-- 4. Cart Items table structure
SELECT '=== CART_ITEMS COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'cart_items'
ORDER BY ordinal_position;

-- 5. Addresses table structure
SELECT '=== ADDRESSES COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'addresses'
ORDER BY ordinal_position;

-- 6. Products table structure
SELECT '=== PRODUCTS COLUMNS ===' as section;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'products'
ORDER BY ordinal_position;

-- 7. Existing RLS policies
SELECT '=== RLS POLICIES ===' as section;
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
