-- =====================================================
-- Fix Branch Returns Inventory - Version 2
-- This creates a database trigger to handle inventory
-- updates when branch_return status changes to 'received'
-- =====================================================

-- Step 1: Drop any existing trigger on branch_returns
DROP TRIGGER IF EXISTS trg_branch_return_inventory ON branch_returns;

-- Step 2: Create the function to update inventory
CREATE OR REPLACE FUNCTION update_inventory_on_branch_return()
RETURNS TRIGGER AS $$
DECLARE
    v_item RECORD;
    v_source_inv_id UUID;
    v_dest_inv_id UUID;
    v_source_qty NUMERIC;
    v_dest_qty NUMERIC;
    v_item_cost NUMERIC;
BEGIN
    -- Only process when status changes to 'received'
    IF NEW.status = 'received' AND (OLD.status IS NULL OR OLD.status != 'received') THEN
        
        -- Process each item in the return
        FOR v_item IN 
            SELECT 
                bri.item_id,
                COALESCE(bri.received_quantity, bri.shipped_quantity, bri.approved_quantity, bri.requested_quantity) as quantity,
                COALESCE(bri.unit_cost, 0) as unit_cost
            FROM branch_return_items bri
            WHERE bri.return_id = NEW.id
        LOOP
            -- Get source inventory (from_branch)
            SELECT id, quantity INTO v_source_inv_id, v_source_qty
            FROM inventory
            WHERE branch_id = NEW.from_branch_id AND item_id = v_item.item_id;
            
            -- Get destination inventory (to_branch)
            SELECT id, quantity INTO v_dest_inv_id, v_dest_qty
            FROM inventory
            WHERE branch_id = NEW.to_branch_id AND item_id = v_item.item_id;
            
            -- Deduct from source branch
            IF v_source_inv_id IS NOT NULL THEN
                UPDATE inventory 
                SET quantity = GREATEST(0, quantity - v_item.quantity),
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_source_inv_id;
                
                -- Log transaction for source
                INSERT INTO inventory_transactions (
                    branch_id, item_id, operation_type, quantity,
                    quantity_before, quantity_after, unit_cost,
                    reference_type, notes, created_by
                ) VALUES (
                    NEW.from_branch_id, v_item.item_id, 'transfer_out', v_item.quantity,
                    v_source_qty, GREATEST(0, v_source_qty - v_item.quantity), v_item.unit_cost,
                    'branch_return', 'Branch return ' || NEW.return_number, NEW.received_by
                );
            END IF;
            
            -- Add to destination branch
            IF v_dest_inv_id IS NOT NULL THEN
                UPDATE inventory 
                SET quantity = quantity + v_item.quantity,
                    last_restock_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_dest_inv_id;
                
                -- Log transaction for destination
                INSERT INTO inventory_transactions (
                    branch_id, item_id, operation_type, quantity,
                    quantity_before, quantity_after, unit_cost,
                    reference_type, notes, created_by
                ) VALUES (
                    NEW.to_branch_id, v_item.item_id, 'transfer_in', v_item.quantity,
                    v_dest_qty, v_dest_qty + v_item.quantity, v_item.unit_cost,
                    'branch_return', 'Branch return ' || NEW.return_number, NEW.received_by
                );
            ELSE
                -- Create new inventory record for destination
                INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
                VALUES (NEW.to_branch_id, v_item.item_id, v_item.quantity, 0);
                
                -- Log transaction
                INSERT INTO inventory_transactions (
                    branch_id, item_id, operation_type, quantity,
                    quantity_before, quantity_after, unit_cost,
                    reference_type, notes, created_by
                ) VALUES (
                    NEW.to_branch_id, v_item.item_id, 'transfer_in', v_item.quantity,
                    0, v_item.quantity, v_item.unit_cost,
                    'branch_return', 'Branch return ' || NEW.return_number, NEW.received_by
                );
            END IF;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger
CREATE TRIGGER trg_branch_return_inventory
    AFTER UPDATE ON branch_returns
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_branch_return();

-- Step 4: Verify the trigger was created
SELECT 
    t.tgname as trigger_name,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname = 'branch_returns'
AND NOT t.tgisinternal;

-- =====================================================
-- IMPORTANT: After running this script, the React code
-- should NOT update inventory manually. The trigger
-- will handle it automatically when status = 'received'
-- =====================================================
