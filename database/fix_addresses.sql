-- ============================================
-- FIX: Addresses Table - RLS and Column Alias
-- ============================================
-- Run this in Supabase SQL Editor

-- 1. Drop existing policies on addresses
DROP POLICY IF EXISTS "Users can manage own addresses" ON addresses;

-- 2. Create proper policies
CREATE POLICY "Users can view own addresses"
    ON addresses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own addresses"
    ON addresses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own addresses"
    ON addresses FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own addresses"
    ON addresses FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Add address_line1 as an alias column (generated column)
-- First check if column exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'addresses' AND column_name = 'address_line1'
    ) THEN
        ALTER TABLE addresses ADD COLUMN address_line1 TEXT GENERATED ALWAYS AS (street_address) STORED;
    END IF;
END $$;

-- Success
SELECT 'Addresses RLS and column alias fixed!' as message;
