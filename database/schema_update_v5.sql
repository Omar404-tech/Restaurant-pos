-- =====================================================
-- Schema Update V5: Branch Inventory Fields
-- Additional fields for branch item tracking
-- =====================================================

-- 1. Add new columns to inventory table for branch tracking
ALTER TABLE inventory 
ADD COLUMN IF NOT EXISTS entry_date DATE DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS document_number VARCHAR(30),
ADD COLUMN IF NOT EXISTS partial_quantity DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS content_quantity DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_quantity DECIMAL(12, 3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS content_description TEXT;

-- 2. Create index for document number
CREATE INDEX IF NOT EXISTS idx_inventory_document ON inventory(document_number);
CREATE INDEX IF NOT EXISTS idx_inventory_entry_date ON inventory(entry_date);

-- 3. Create View for Branch Inventory with new fields
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
    inv.updated_at
FROM inventory inv
JOIN items i ON inv.item_id = i.id
JOIN branches b ON inv.branch_id = b.id
WHERE b.code != 'MAIN'
ORDER BY inv.entry_date DESC, i.code;

-- 4. Function to generate document number for branch inventory
CREATE OR REPLACE FUNCTION generate_branch_inventory_doc_number(branch_code VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    prefix := 'INV-' || branch_code;
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(document_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM inventory
    WHERE document_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger to auto-calculate total_quantity
CREATE OR REPLACE FUNCTION calculate_branch_inventory_total()
RETURNS TRIGGER AS $$
BEGIN
    NEW.total_quantity := COALESCE(NEW.partial_quantity, 0) + COALESCE(NEW.content_quantity, 0);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calc_inventory_total ON inventory;
CREATE TRIGGER trg_calc_inventory_total
BEFORE INSERT OR UPDATE OF partial_quantity, content_quantity ON inventory
FOR EACH ROW EXECUTE FUNCTION calculate_branch_inventory_total();
