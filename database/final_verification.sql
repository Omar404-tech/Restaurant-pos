-- =====================================================
-- FINAL LOGIN VERIFICATION
-- Run this in your Supabase SQL Editor
-- =====================================================

-- 1. Check if Branch 3 and 4 exist
SELECT '--- Branches ---' as label;
SELECT id, code, name_ar, status 
FROM branches 
WHERE code IN ('BR03', 'BR04');

-- 2. Check if Users exist and their status/email
-- WE USE LOWER() TO CHECK CASE SENSITIVITY
SELECT '--- Users ---' as label;
SELECT 
    id, 
    username, 
    email, 
    status, 
    branch_id, 
    role_id,
    (SELECT name_ar FROM roles WHERE id = role_id) as role_name,
    (SELECT name_ar FROM branches WHERE id = branch_id) as branch_name
FROM users 
WHERE LOWER(email) IN ('branch3@restaurant.com', 'branch4@restaurant.com');

-- 3. Check for any RLS issues specifically for 'anon'
-- This query helps see if 'anon' can really see these rows
-- (Note: Running this as postgres superuser always works, 
-- but we check the policy definitions)
SELECT '--- RLS Check ---' as label;
SELECT tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename IN ('users', 'branches', 'roles')
ORDER BY tablename;
