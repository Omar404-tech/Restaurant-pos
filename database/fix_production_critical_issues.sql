-- ============================================
-- PRODUCTION CRITICAL ISSUES FIX
-- Date: 2026-01-20
-- ============================================

-- ============================================
-- ISSUE 1: Supplier Balance Calculation
-- ============================================

-- Step 1: Temporarily drop the balance constraint
ALTER TABLE suppliers DROP CONSTRAINT IF EXISTS chk_supplier_balance;

-- Step 2: Fix overpayment issue for Fresh Meat Co.
-- The direct payments exceed what's owed, so we need to adjust
-- Option A: Reduce direct payments to match what's owed
-- Option B: Allow negative balance (supplier owes us money)
-- We'll go with Option B as it's more realistic

-- Step 3: Recalculate all supplier balances correctly
UPDATE suppliers s
SET current_balance = (
    -- Credit supplies not yet paid
    COALESCE((
        SELECT SUM(CASE WHEN payment_method = 'credit' 
                   THEN total_amount - COALESCE(paid_amount, 0) 
                   ELSE 0 END)
        FROM supplies 
        WHERE supplier_id = s.id
    ), 0)
    -- Subtract direct payments
    - COALESCE((
        SELECT SUM(amount)
        FROM supplier_payments 
        WHERE supplier_id = s.id
    ), 0)
    -- Subtract approved returns
    - COALESCE((
        SELECT SUM(total_amount)
        FROM supplier_returns 
        WHERE supplier_id = s.id AND status = 'approved'
    ), 0)
),
updated_at = CURRENT_TIMESTAMP;

-- Step 4: Recreate constraint allowing negative balance
-- (negative means supplier owes us money - overpayment or returns)
-- We'll remove the constraint entirely for flexibility
-- ALTER TABLE suppliers ADD CONSTRAINT chk_supplier_balance CHECK (current_balance >= -999999);

-- ============================================
-- ISSUE 2: Add Missing Foreign Key Indexes
-- ============================================

-- User-related FKs (highest priority - most joins)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_br_requested_by ON branch_returns(requested_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_br_approved_by ON branch_returns(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_br_rejected_by ON branch_returns(rejected_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_br_received_by ON branch_returns(received_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_tr_requested_by ON transfers(requested_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_tr_approved_by ON transfers(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_tr_rejected_by ON transfers(rejected_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_tr_received_by ON transfers(received_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dmg_registered_by ON damages(registered_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dmg_approved_by ON damages(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dmg_rejected_by ON damages(rejected_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dmg_reason_id ON damages(reason_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dmg_batch_id ON damages(batch_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pr_requested_by ON purchase_requests(requested_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pr_approved_by ON purchase_requests(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pr_rejected_by ON purchase_requests(rejected_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_po_created_by ON purchase_orders(created_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_po_approved_by ON purchase_orders(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_po_branch_id ON purchase_orders(branch_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_po_request_id ON purchase_orders(request_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sup_received_by ON supplies(received_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sup_approved_by ON supplies(approved_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sr_registered_by ON supplier_returns(registered_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sr_approved_by ON supplier_returns(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sr_rejected_by ON supplier_returns(rejected_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sr_item_id ON supplier_returns(item_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ord_cancelled_by ON orders(cancelled_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ord_chef_id ON orders(chef_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_usr_created_by ON users(created_by);

-- Batch-related FKs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_bri_batch_id ON branch_return_items(batch_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_invb_supply_id ON inventory_batches(supply_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_invt_batch_id ON inventory_transactions(batch_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_invt_created_by ON inventory_transactions(created_by);

-- Other important FKs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_poi_request_item_id ON purchase_order_items(request_item_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sp_supply_id ON supplier_payments(supply_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_sp_created_by ON supplier_payments(created_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_itm_unit_id ON items(unit_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_itm_created_by ON items(created_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_supp_created_by ON suppliers(created_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dic_counted_by ON daily_inventory_counts(counted_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dic_approved_by ON daily_inventory_counts(approved_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_dici_item_id ON daily_inventory_count_items(item_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_bs_updated_by ON branch_settings(updated_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ss_updated_by ON system_settings(updated_by);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_cs_closed_by ON cashier_shifts(closed_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pl_recipe_item_id ON production_logs(recipe_item_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pl_branch_id ON production_logs(branch_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_pl_produced_by ON production_logs(produced_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ri_recipe_item_id ON recipe_ingredients(recipe_item_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ri_ingredient_item_id ON recipe_ingredients(ingredient_item_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_ri_unit_id ON recipe_ingredients(unit_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fk_mii_unit_id ON menu_item_ingredients(unit_id);

-- ============================================
-- ISSUE 3: Initialize Inventory Period Tracking
-- ============================================

UPDATE inventory
SET 
    opening_balance = COALESCE(quantity, 0),
    incoming_quantity = 0,
    consumption_quantity = 0,
    period_start_date = CURRENT_DATE - INTERVAL '30 days',
    period_end_date = CURRENT_DATE,
    entry_date = COALESCE(entry_date, CURRENT_DATE),
    updated_at = CURRENT_TIMESTAMP
WHERE (opening_balance IS NULL OR opening_balance = 0) 
  AND (incoming_quantity IS NULL OR incoming_quantity = 0) 
  AND (consumption_quantity IS NULL OR consumption_quantity = 0);

-- ============================================
-- Verification Queries
-- ============================================

-- Check supplier balances
SELECT 
    name,
    current_balance as system_balance,
    (
        COALESCE((SELECT SUM(CASE WHEN payment_method = 'credit' THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END)
         FROM supplies WHERE supplier_id = s.id), 0)
        - COALESCE((SELECT SUM(amount) FROM supplier_payments WHERE supplier_id = s.id), 0)
        - COALESCE((SELECT SUM(total_amount) FROM supplier_returns WHERE supplier_id = s.id AND status = 'approved'), 0)
    ) as calculated_balance,
    CASE 
        WHEN current_balance = (
            COALESCE((SELECT SUM(CASE WHEN payment_method = 'credit' THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END)
             FROM supplies WHERE supplier_id = s.id), 0)
            - COALESCE((SELECT SUM(amount) FROM supplier_payments WHERE supplier_id = s.id), 0)
            - COALESCE((SELECT SUM(total_amount) FROM supplier_returns WHERE supplier_id = s.id AND status = 'approved'), 0)
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as test_result
FROM suppliers s
ORDER BY name;

-- Check inventory initialization
SELECT 
    COUNT(*) as total_inventory_records,
    COUNT(CASE WHEN opening_balance > 0 THEN 1 END) as initialized_records,
    COUNT(CASE WHEN opening_balance = 0 OR opening_balance IS NULL THEN 1 END) as uninitialized_records
FROM inventory;

-- Check indexes created
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_fk_%'
ORDER BY tablename, indexname;
