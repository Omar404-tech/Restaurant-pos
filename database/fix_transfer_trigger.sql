-- Fix the transfer trigger function to handle multiple items correctly
CREATE OR REPLACE FUNCTION update_inventory_on_transfer()
RETURNS TRIGGER AS $$
DECLARE
    v_item RECORD;
    v_from_inv_id UUID;
    v_to_inv_id UUID;
BEGIN
    -- Only process when transfer is received
    IF NEW.status = 'received' AND OLD.status != 'received' THEN
        -- Process each transfer item
        FOR v_item IN 
            SELECT ti.item_id, ti.received_quantity
            FROM transfer_items ti
            WHERE ti.transfer_id = NEW.id
        LOOP
            -- Get source inventory ID
            SELECT id INTO v_from_inv_id 
            FROM inventory 
            WHERE branch_id = NEW.from_branch_id AND item_id = v_item.item_id
            LIMIT 1;
            
            -- Get destination inventory ID
            SELECT id INTO v_to_inv_id 
            FROM inventory 
            WHERE branch_id = NEW.to_branch_id AND item_id = v_item.item_id
            LIMIT 1;
            
            -- Deduct from source
            IF v_from_inv_id IS NOT NULL THEN
                UPDATE inventory 
                SET quantity = quantity - COALESCE(v_item.received_quantity, 0),
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_from_inv_id;
            END IF;
            
            -- Add to destination (create if not exists)
            IF v_to_inv_id IS NULL THEN
                INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
                VALUES (NEW.to_branch_id, v_item.item_id, COALESCE(v_item.received_quantity, 0), 0);
            ELSE
                UPDATE inventory 
                SET quantity = quantity + COALESCE(v_item.received_quantity, 0),
                    last_restock_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_to_inv_id;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
