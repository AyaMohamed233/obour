-- ============================================
-- FIX: Profiles RLS Infinite Recursion
-- ============================================
-- Run this in Supabase SQL Editor to fix the infinite recursion error

-- 1. Drop the problematic policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- 2. Create a SECURITY DEFINER function to check admin status
-- This avoids the infinite recursion by bypassing RLS
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM profiles WHERE id = auth.uid()),
    FALSE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 3. Recreate the policies correctly
-- Users can view their own profile (simple, no recursion)
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Admins can view all profiles (using the SECURITY DEFINER function)
CREATE POLICY "Admins can view all profiles"
    ON profiles FOR SELECT
    USING (is_admin());

-- 4. Allow INSERT for new users (needed for the trigger)
CREATE POLICY "Enable insert for service role"
    ON profiles FOR INSERT
    WITH CHECK (true);

-- Success message
SELECT 'RLS policies fixed successfully!' as message;
