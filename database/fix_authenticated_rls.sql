-- =====================================================
-- Fix RLS Policies for Authenticated Role
-- This script adds INSERT/UPDATE/DELETE policies for
-- the 'authenticated' role on items and inventory tables
-- =====================================================

-- First, add policies for authenticated role on items table
CREATE POLICY "authenticated_all" ON items 
  FOR ALL 
  TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Add policies for authenticated role on inventory table
CREATE POLICY "authenticated_all" ON inventory 
  FOR ALL 
  TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Add policies for authenticated role on units table (needed for unit lookup)
CREATE POLICY "authenticated_all" ON units 
  FOR ALL 
  TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Add policies for authenticated role on categories table
CREATE POLICY "authenticated_all" ON categories 
  FOR ALL 
  TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Add policies for authenticated role on branches table
CREATE POLICY "authenticated_all" ON branches 
  FOR ALL 
  TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- =====================================================
-- Verify policies exist
-- Run: SELECT tablename, policyname, roles FROM pg_policies 
--      WHERE schemaname = 'public' AND policyname LIKE 'authenticated%';
-- =====================================================
