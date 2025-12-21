-- =====================================================
-- Fix Branch Returns Inventory Issue - DIAGNOSTIC SCRIPT
-- Run this to check for any triggers that might be 
-- duplicating inventory updates for branch returns
-- =====================================================

-- Step 1: Check triggers on branch_returns table
SELECT 
    t.tgname as trigger_name,
    p.proname as function_name,
    CASE t.tgtype::int & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END as timing
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname = 'branch_returns'
AND NOT t.tgisinternal;

-- Step 2: Check triggers on branch_return_items table
SELECT 
    t.tgname as trigger_name,
    p.proname as function_name,
    CASE t.tgtype::int & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END as timing
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname = 'branch_return_items'
AND NOT t.tgisinternal;

-- Step 3: Check for any functions that might update inventory on branch_return
SELECT proname, prosrc
FROM pg_proc 
WHERE (proname LIKE '%branch_return%' OR proname LIKE '%return_inventory%')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Step 4: Check recent inventory transactions for branch_return
SELECT 
    it.operation_type,
    it.quantity,
    it.quantity_before,
    it.quantity_after,
    it.reference_type,
    it.notes,
    it.created_at,
    b.name_ar as branch_name,
    i.name_ar as item_name
FROM inventory_transactions it
JOIN branches b ON it.branch_id = b.id
JOIN items i ON it.item_id = i.id
WHERE it.reference_type = 'branch_return'
ORDER BY it.created_at DESC
LIMIT 10;

-- =====================================================
-- SOLUTION IMPLEMENTED IN CODE:
-- The inventory updates are handled ONLY in:
-- restaurant-react/src/pages/returns/BranchReturnDetail.tsx
-- 
-- The handleReceive function:
-- 1. Checks if return is already received (prevents double processing)
-- 2. Updates status to 'received' with optimistic locking
-- 3. Updates inventory for each item
-- 4. Verifies final inventory values
-- =====================================================
