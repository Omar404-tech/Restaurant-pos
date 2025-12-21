-- =====================================================
-- Enable Inventory Triggers
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Create trigger for damages (when status changes to 'approved')
DROP TRIGGER IF EXISTS trg_update_inventory_on_damage ON damages;
CREATE TRIGGER trg_update_inventory_on_damage
    AFTER UPDATE ON damages
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_damage();

-- 2. Create trigger for transfers (when status changes to 'received')
DROP TRIGGER IF EXISTS trg_update_inventory_on_transfer ON transfers;
CREATE TRIGGER trg_update_inventory_on_transfer
    AFTER UPDATE ON transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_transfer();

-- 3. Create trigger for supplier returns (when status changes to 'approved')
DROP TRIGGER IF EXISTS trg_update_inventory_on_return ON supplier_returns;
CREATE TRIGGER trg_update_inventory_on_return
    AFTER UPDATE ON supplier_returns
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_return();

-- 4. Create adjust_inventory_quantity RPC function for direct calls
CREATE OR REPLACE FUNCTION adjust_inventory_quantity(
    p_branch_id UUID,
    p_item_id UUID,
    p_quantity NUMERIC
)
RETURNS VOID AS $$
DECLARE
    v_current_qty NUMERIC;
    v_inventory_id UUID;
BEGIN
    -- Get current inventory
    SELECT id, quantity INTO v_inventory_id, v_current_qty
    FROM inventory
    WHERE branch_id = p_branch_id AND item_id = p_item_id;
    
    IF v_inventory_id IS NULL THEN
        -- Create new inventory record if doesn't exist
        INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
        VALUES (p_branch_id, p_item_id, GREATEST(p_quantity, 0), 0);
    ELSE
        -- Update existing inventory
        UPDATE inventory
        SET quantity = GREATEST(quantity + p_quantity, 0),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_inventory_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for branch returns
CREATE OR REPLACE FUNCTION update_inventory_on_branch_return()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process when status changes to 'received'
    IF NEW.status = 'received' AND (OLD.status IS NULL OR OLD.status != 'received') THEN
        -- Process each return item
        DECLARE
            v_item RECORD;
        BEGIN
            FOR v_item IN 
                SELECT item_id, COALESCE(received_quantity, requested_quantity) as qty
                FROM branch_return_items 
                WHERE return_id = NEW.id
            LOOP
                -- Deduct from source branch
                UPDATE inventory 
                SET quantity = GREATEST(quantity - v_item.qty, 0),
                    updated_at = CURRENT_TIMESTAMP
                WHERE branch_id = NEW.from_branch_id AND item_id = v_item.item_id;
                
                -- Add to destination branch (main warehouse)
                UPDATE inventory 
                SET quantity = quantity + v_item.qty,
                    updated_at = CURRENT_TIMESTAMP
                WHERE branch_id = NEW.to_branch_id AND item_id = v_item.item_id;
                
                -- If destination doesn't have this item, create it
                IF NOT FOUND THEN
                    INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
                    VALUES (NEW.to_branch_id, v_item.item_id, v_item.qty, 0);
                END IF;
            END LOOP;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_inventory_on_branch_return ON branch_returns;
CREATE TRIGGER trg_update_inventory_on_branch_return
    AFTER UPDATE ON branch_returns
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_branch_return();

-- =====================================================
-- Verify triggers are created
-- =====================================================
SELECT 
    tgname as trigger_name,
    relname as table_name,
    proname as function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE relname IN ('damages', 'transfers', 'supplier_returns', 'branch_returns')
AND tgname NOT LIKE 'RI_%'
ORDER BY relname;
