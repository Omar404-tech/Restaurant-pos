-- ============================================
-- POS Inventory Integration Migration
-- ============================================
-- This migration integrates POS system with inventory
-- Products sold in POS will be deducted from inventory

-- Step 1: Add new cashier for Branch 1
-- ============================================
DO $$
DECLARE
    v_role_id uuid;
    v_branch_id uuid;
BEGIN
    -- Get cashier role ID
    SELECT id INTO v_role_id FROM roles WHERE name = 'cashier' LIMIT 1;
    
    -- Get Branch 1 ID
    SELECT id INTO v_branch_id FROM branches WHERE code = 'BR001' LIMIT 1;
    
    -- Insert new cashier if not exists
    INSERT INTO users (
        employee_code,
        username,
        email,
        password_hash,
        full_name,
        full_name_ar,
        phone,
        role_id,
        branch_id,
        status
    )
    SELECT 
        'EMP010',
        'cashier1b',
        'cashier1b@restaurant.com',
        '$2b$10$rZ5L3KxH9vQ8yP2wX1nJ4.8kF7mN6tR9sA3bC5dE7fG8hI9jK0lM1', -- hashed '1234'
        'Laila Hassan',
        'ليلى حسن',
        '01234567890',
        v_role_id,
        v_branch_id,
        'active'
    WHERE NOT EXISTS (
        SELECT 1 FROM users WHERE email = 'cashier1b@restaurant.com'
    );
    
    RAISE NOTICE 'Cashier added successfully';
END $$;


-- Step 2: Create new table for branch POS items (replacing branch_menu_prices)
-- ============================================
CREATE TABLE IF NOT EXISTS branch_pos_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    item_id uuid NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    price numeric NOT NULL CHECK (price >= 0),
    is_available boolean DEFAULT true,
    display_order integer DEFAULT 0,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(branch_id, item_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_branch_pos_items_branch ON branch_pos_items(branch_id);
CREATE INDEX IF NOT EXISTS idx_branch_pos_items_item ON branch_pos_items(item_id);
CREATE INDEX IF NOT EXISTS idx_branch_pos_items_available ON branch_pos_items(is_available);

COMMENT ON TABLE branch_pos_items IS 'Items available for sale in POS per branch - linked to inventory';
COMMENT ON COLUMN branch_pos_items.price IS 'Selling price for this item in this branch';
COMMENT ON COLUMN branch_pos_items.is_available IS 'Whether item is enabled for sale in POS';


-- Step 3: Migrate existing data from branch_menu_prices (if needed)
-- ============================================
-- Note: We will NOT migrate old menu_items data
-- Admin will manually add items from inventory to POS


-- Step 4: Update order_items to support inventory items
-- ============================================
-- Add item_id column to order_items (in addition to menu_item_id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'order_items' AND column_name = 'item_id'
    ) THEN
        ALTER TABLE order_items ADD COLUMN item_id uuid REFERENCES items(id);
        CREATE INDEX idx_order_items_item ON order_items(item_id);
        COMMENT ON COLUMN order_items.item_id IS 'Reference to inventory item (for POS sales)';
    END IF;
END $$;


-- Step 5: Create function to check inventory before sale
-- ============================================
CREATE OR REPLACE FUNCTION check_inventory_before_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_available_qty numeric;
    v_branch_id uuid;
BEGIN
    -- Only check if item_id is set (POS sale from inventory)
    IF NEW.item_id IS NOT NULL THEN
        -- Get branch from order
        SELECT branch_id INTO v_branch_id FROM orders WHERE id = NEW.order_id;
        
        -- Get available quantity
        SELECT quantity INTO v_available_qty 
        FROM inventory 
        WHERE branch_id = v_branch_id AND item_id = NEW.item_id;
        
        -- Check if enough quantity available
        IF v_available_qty IS NULL OR v_available_qty < NEW.quantity THEN
            RAISE EXCEPTION 'Insufficient inventory: only % available', COALESCE(v_available_qty, 0);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_check_inventory_before_sale ON order_items;
CREATE TRIGGER trg_check_inventory_before_sale
    BEFORE INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION check_inventory_before_sale();


-- Step 6: Create function to deduct from inventory after sale
-- ============================================
CREATE OR REPLACE FUNCTION deduct_inventory_after_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_branch_id uuid;
    v_user_id uuid;
BEGIN
    -- Only process if item_id is set (POS sale from inventory)
    IF NEW.item_id IS NOT NULL THEN
        -- Get branch and cashier from order
        SELECT branch_id, cashier_id INTO v_branch_id, v_user_id 
        FROM orders WHERE id = NEW.order_id;
        
        -- Deduct from inventory
        UPDATE inventory 
        SET 
            quantity = quantity - NEW.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE branch_id = v_branch_id AND item_id = NEW.item_id;
        
        -- Record transaction
        INSERT INTO inventory_transactions (
            branch_id,
            item_id,
            operation_type,
            quantity,
            quantity_before,
            quantity_after,
            reference_type,
            reference_id,
            notes,
            created_by
        )
        SELECT 
            v_branch_id,
            NEW.item_id,
            'consumption',
            -NEW.quantity,
            i.quantity + NEW.quantity,
            i.quantity,
            'order',
            NEW.order_id,
            'POS Sale - Order Item',
            v_user_id
        FROM inventory i
        WHERE i.branch_id = v_branch_id AND i.item_id = NEW.item_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_deduct_inventory_after_sale ON order_items;
CREATE TRIGGER trg_deduct_inventory_after_sale
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION deduct_inventory_after_sale();


-- Step 7: Enable RLS on new table
-- ============================================
ALTER TABLE branch_pos_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view POS items for their branch
CREATE POLICY branch_pos_items_select_policy ON branch_pos_items
    FOR SELECT
    USING (
        branch_id IN (
            SELECT branch_id FROM users WHERE id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role_id IN (
                SELECT id FROM roles WHERE name IN ('admin', 'warehouse_manager')
            )
        )
    );

-- Policy: Only admin and warehouse_manager can modify
CREATE POLICY branch_pos_items_modify_policy ON branch_pos_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role_id IN (
                SELECT id FROM roles WHERE name IN ('admin', 'warehouse_manager')
            )
        )
    );


-- Step 8: Create view for POS items with inventory info
-- ============================================
CREATE OR REPLACE VIEW v_branch_pos_items_with_stock AS
SELECT 
    bpi.id,
    bpi.branch_id,
    bpi.item_id,
    bpi.price,
    bpi.is_available,
    bpi.display_order,
    i.code as item_code,
    i.name as item_name,
    i.name_ar as item_name_ar,
    i.is_recipe,
    i.image_url,
    u.name_ar as unit_name,
    u.code as unit_code,
    COALESCE(inv.quantity, 0) as stock_quantity,
    CASE 
        WHEN COALESCE(inv.quantity, 0) > 0 THEN true
        ELSE false
    END as in_stock,
    bpi.created_at,
    bpi.updated_at
FROM branch_pos_items bpi
INNER JOIN items i ON bpi.item_id = i.id
LEFT JOIN units u ON i.unit_id = u.id
LEFT JOIN inventory inv ON inv.branch_id = bpi.branch_id AND inv.item_id = bpi.item_id
WHERE i.status = 'active';

COMMENT ON VIEW v_branch_pos_items_with_stock IS 'POS items with current stock levels';


-- Step 9: Grant permissions
-- ============================================
GRANT SELECT ON branch_pos_items TO authenticated;
GRANT SELECT ON v_branch_pos_items_with_stock TO authenticated;
GRANT INSERT, UPDATE, DELETE ON branch_pos_items TO authenticated;


-- ============================================
-- Migration Complete
-- ============================================
-- Summary:
-- 1. ✅ Added new cashier (cashier1b@restaurant.com)
-- 2. ✅ Created branch_pos_items table
-- 3. ✅ Added item_id to order_items
-- 4. ✅ Created inventory check trigger
-- 5. ✅ Created inventory deduction trigger
-- 6. ✅ Set up RLS policies
-- 7. ✅ Created view with stock info
-- 
-- Next Steps:
-- - Update frontend to use new branch_pos_items
-- - Update POS Management page to add/remove items
-- - Update Cashier page to check stock and deduct inventory
