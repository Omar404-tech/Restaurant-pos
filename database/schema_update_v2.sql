-- =====================================================
-- Schema Update V2: Inventory Enhancements
-- Adding fields for Main Warehouse tracking
-- =====================================================

-- Add new columns to inventory table
ALTER TABLE inventory 
ADD COLUMN IF NOT EXISTS opening_balance DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS incoming_quantity DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS consumption_quantity DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS consumption_description TEXT,
ADD COLUMN IF NOT EXISTS period_start_date DATE,
ADD COLUMN IF NOT EXISTS period_end_date DATE;

-- Add comments for documentation
COMMENT ON COLUMN inventory.opening_balance IS 'Opening balance at start of period (رصيد أول المدة)';
COMMENT ON COLUMN inventory.incoming_quantity IS 'Total incoming quantity in period (الوارد)';
COMMENT ON COLUMN inventory.consumption_quantity IS 'Total consumption in period (المحتوى بالكمية)';
COMMENT ON COLUMN inventory.consumption_description IS 'Description of consumption (وصف المحتوى)';
COMMENT ON COLUMN inventory.period_start_date IS 'Start date of tracking period';
COMMENT ON COLUMN inventory.period_end_date IS 'End date of tracking period';

-- Create a view for Main Warehouse Inventory Report
CREATE OR REPLACE VIEW vw_main_warehouse_inventory AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY c.name, i.code) as row_num,
    c.name as category,
    c.name_ar as category_ar,
    i.code as item_code,
    i.name as item_name,
    i.name_ar as item_name_ar,
    u.name as unit_name,
    u.name_ar as unit_name_ar,
    inv.opening_balance,
    inv.incoming_quantity as incoming,
    inv.consumption_quantity as consumption,
    inv.quantity as total_balance,
    inv.consumption_description,
    inv.min_quantity,
    CASE 
        WHEN inv.quantity < inv.min_quantity THEN 'LOW'
        WHEN inv.quantity < inv.min_quantity * 1.5 THEN 'WARNING'
        ELSE 'OK'
    END as stock_status,
    inv.period_start_date,
    inv.period_end_date,
    inv.updated_at
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN categories c ON i.category_id = c.id
JOIN units u ON i.unit_id = u.id
WHERE b.is_main_warehouse = TRUE
ORDER BY c.name, i.code;

-- Create a view for Branch Inventory Report
CREATE OR REPLACE VIEW vw_branch_inventory AS
SELECT 
    ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY c.name, i.code) as row_num,
    b.code as branch_code,
    b.name as branch_name,
    c.name as category,
    i.code as item_code,
    i.name as item_name,
    u.name as unit_name,
    inv.opening_balance,
    inv.incoming_quantity as incoming,
    inv.consumption_quantity as consumption,
    inv.quantity as total_balance,
    inv.consumption_description,
    inv.min_quantity,
    CASE 
        WHEN inv.quantity < inv.min_quantity THEN 'LOW'
        WHEN inv.quantity < inv.min_quantity * 1.5 THEN 'WARNING'
        ELSE 'OK'
    END as stock_status
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN categories c ON i.category_id = c.id
JOIN units u ON i.unit_id = u.id
WHERE b.is_main_warehouse = FALSE
ORDER BY b.name, c.name, i.code;

-- Create a function to calculate inventory summary
CREATE OR REPLACE FUNCTION calculate_inventory_period(
    p_branch_id UUID,
    p_start_date DATE,
    p_end_date DATE
) RETURNS TABLE (
    item_id UUID,
    opening_balance DECIMAL,
    incoming DECIMAL,
    consumption DECIMAL,
    closing_balance DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        inv.item_id,
        -- Opening balance: quantity at start of period
        COALESCE(
            (SELECT SUM(CASE 
                WHEN it.operation_type IN ('supply', 'transfer_in', 'adjustment') THEN it.quantity
                WHEN it.operation_type IN ('transfer_out', 'damage', 'return', 'consumption') THEN -it.quantity
                ELSE 0
            END)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.created_at < p_start_date::timestamp), 0
        )::DECIMAL as opening_balance,
        -- Incoming: supplies + transfers in during period
        COALESCE(
            (SELECT SUM(it.quantity)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.operation_type IN ('supply', 'transfer_in')
            AND it.created_at >= p_start_date::timestamp
            AND it.created_at <= p_end_date::timestamp), 0
        )::DECIMAL as incoming,
        -- Consumption: all outgoing during period
        COALESCE(
            (SELECT SUM(it.quantity)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.operation_type IN ('transfer_out', 'damage', 'return', 'consumption')
            AND it.created_at >= p_start_date::timestamp
            AND it.created_at <= p_end_date::timestamp), 0
        )::DECIMAL as consumption,
        -- Closing balance
        inv.quantity::DECIMAL as closing_balance
    FROM inventory inv
    WHERE inv.branch_id = p_branch_id;
END;
$$ LANGUAGE plpgsql;

-- Create a procedure to update inventory period data
CREATE OR REPLACE PROCEDURE update_inventory_period(
    p_branch_id UUID,
    p_start_date DATE,
    p_end_date DATE
) AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT * FROM calculate_inventory_period(p_branch_id, p_start_date, p_end_date)
    LOOP
        UPDATE inventory 
        SET 
            opening_balance = rec.opening_balance,
            incoming_quantity = rec.incoming,
            consumption_quantity = rec.consumption,
            period_start_date = p_start_date,
            period_end_date = p_end_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE branch_id = p_branch_id AND item_id = rec.item_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Update existing inventory records with initial values
UPDATE inventory SET 
    opening_balance = 0,
    incoming_quantity = quantity,
    consumption_quantity = 0,
    period_start_date = CURRENT_DATE,
    period_end_date = CURRENT_DATE
WHERE opening_balance IS NULL;
