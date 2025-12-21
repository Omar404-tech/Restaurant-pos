-- =====================================================
-- Schema Update V6: Fix Branch Inventory Calculation
-- total = partial * content (not partial + content)
-- =====================================================

-- 1. Update trigger to calculate total = partial * content
CREATE OR REPLACE FUNCTION calculate_branch_inventory_total()
RETURNS TRIGGER AS $$
BEGIN
    -- total_quantity = partial_quantity * content_quantity
    -- Example: 5 bags * 10 kg per bag = 50 kg total
    NEW.total_quantity := COALESCE(NEW.partial_quantity, 0) * COALESCE(NEW.content_quantity, 0);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Add comments for clarity
COMMENT ON COLUMN inventory.partial_quantity IS 'Number of units (bags, boxes, cans) - entered manually when adding item';
COMMENT ON COLUMN inventory.content_quantity IS 'Content per unit (kg per bag, items per box) - the unit itself';
COMMENT ON COLUMN inventory.total_quantity IS 'Total = partial * content (e.g., 5 bags * 10 kg = 50 kg total)';
COMMENT ON COLUMN inventory.content_description IS 'Description of content (e.g., divided into plates, cartons)';

-- 3. Update existing test data with correct calculation
-- BR001 - Chicken: 5 bags * 6 kg per bag = 30 kg
UPDATE inventory SET 
    partial_quantity = 5,
    content_quantity = 6,
    total_quantity = 30,
    content_description = 'Chicken breast - 5 bags, each 6 kg, for grilling'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- BR001 - Beef: 2 boxes * 5 kg per box = 10 kg
UPDATE inventory SET 
    partial_quantity = 2,
    content_quantity = 5,
    total_quantity = 10,
    content_description = 'Beef cuts - 2 boxes, each 5 kg, for steaks'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- BR002 - Chicken: 1 bag * 2 kg = 2 kg
UPDATE inventory SET 
    partial_quantity = 1,
    content_quantity = 2,
    total_quantity = 2,
    content_description = 'Chicken - 1 bag, 2 kg remaining'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- BR001 - Rice: 4 bags * 10 kg per bag = 40 kg
UPDATE inventory SET 
    partial_quantity = 4,
    content_quantity = 10,
    total_quantity = 40,
    content_description = 'Rice - 4 bags, each 10 kg'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

-- BR001 - Pepsi: 2 cartons * 24 bottles = 48 bottles (but we have 50)
UPDATE inventory SET 
    partial_quantity = 2,
    content_quantity = 24,
    total_quantity = 48,
    content_description = 'Pepsi - 2 cartons, 24 bottles each + 2 loose'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM008');

-- BR002 - Pepsi: 2 cartons * 24 + extra = 62
UPDATE inventory SET 
    partial_quantity = 2,
    content_quantity = 24,
    total_quantity = 48,
    content_description = 'Pepsi - 2 cartons + 14 loose bottles'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM008');

-- 4. Update view to show calculation clearly
CREATE OR REPLACE VIEW vw_branch_inventory_details AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY inv.entry_date DESC, i.code) as row_num,
    inv.entry_date,
    inv.document_number,
    i.code as item_code,
    i.name as item_name,
    inv.partial_quantity,
    inv.content_quantity,
    inv.total_quantity,
    inv.content_description,
    b.code as branch_code,
    b.name as branch_name,
    inv.quantity as current_stock,
    inv.min_quantity,
    u.symbol as unit_symbol,
    inv.updated_at
FROM inventory inv
JOIN items i ON inv.item_id = i.id
JOIN branches b ON inv.branch_id = b.id
LEFT JOIN units u ON i.unit_id = u.id
WHERE b.code != 'MAIN'
ORDER BY inv.entry_date DESC, i.code;
