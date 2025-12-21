-- =====================================================
-- Schema Update V4: Branch Returns System
-- Returns from Branches to Main Warehouse
-- =====================================================

-- 1. Create Branch Return Status ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'branch_return_status') THEN
        CREATE TYPE branch_return_status AS ENUM ('pending', 'approved', 'rejected', 'in_transit', 'received', 'cancelled');
    END IF;
END $$;

-- 2. Create Branch Returns Table (Master)
CREATE TABLE IF NOT EXISTS branch_returns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_number VARCHAR(30) NOT NULL UNIQUE,
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- From Branch to Main Warehouse
    from_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    to_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    
    -- Status and Reason
    status branch_return_status DEFAULT 'pending',
    return_reason TEXT NOT NULL,
    
    -- Totals
    total_items INTEGER DEFAULT 0,
    total_quantity DECIMAL(12, 3) DEFAULT 0,
    total_value DECIMAL(12, 2) DEFAULT 0,
    
    -- Notes
    notes TEXT,
    
    -- Workflow - Request
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Workflow - Approval
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    
    -- Workflow - Shipping & Receiving
    shipped_at TIMESTAMP WITH TIME ZONE,
    received_by UUID REFERENCES users(id),
    received_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint: Cannot return to same branch
    CONSTRAINT chk_different_branches CHECK (from_branch_id != to_branch_id)
);

CREATE INDEX IF NOT EXISTS idx_branch_returns_date ON branch_returns(return_date);
CREATE INDEX IF NOT EXISTS idx_branch_returns_status ON branch_returns(status);
CREATE INDEX IF NOT EXISTS idx_branch_returns_from ON branch_returns(from_branch_id);
CREATE INDEX IF NOT EXISTS idx_branch_returns_to ON branch_returns(to_branch_id);

-- 3. Create Branch Return Items Table (Details)
CREATE TABLE IF NOT EXISTS branch_return_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_id UUID NOT NULL REFERENCES branch_returns(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    
    -- Quantities
    requested_quantity DECIMAL(12, 3) NOT NULL,
    approved_quantity DECIMAL(12, 3),
    shipped_quantity DECIMAL(12, 3),
    received_quantity DECIMAL(12, 3),
    
    -- Pricing (for value calculation)
    unit_cost DECIMAL(12, 2),
    total_value DECIMAL(12, 2),
    
    -- Reason for this specific item
    item_reason TEXT,
    
    -- Batch info (if returning specific batch)
    batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL,
    
    -- Notes
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_return_item UNIQUE (return_id, item_id),
    CONSTRAINT chk_return_qty CHECK (requested_quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_br_items_return ON branch_return_items(return_id);
CREATE INDEX IF NOT EXISTS idx_br_items_item ON branch_return_items(item_id);

-- 4. Add Return Reasons Lookup Table
CREATE TABLE IF NOT EXISTS branch_return_reasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Insert Default Return Reasons
INSERT INTO branch_return_reasons (code, name, name_ar, sort_order) VALUES
('EXCESS', 'Excess Stock', 'فائض مخزون', 1),
('SLOW_MOVING', 'Slow Moving Items', 'أصناف بطيئة الحركة', 2),
('NEAR_EXPIRY', 'Near Expiry', 'قرب انتهاء الصلاحية', 3),
('QUALITY_ISSUE', 'Quality Issue', 'مشكلة جودة', 4),
('WRONG_DELIVERY', 'Wrong Delivery', 'توصيل خاطئ', 5),
('BRANCH_CLOSING', 'Branch Closing/Renovation', 'إغلاق/تجديد الفرع', 6),
('REBALANCING', 'Stock Rebalancing', 'إعادة توزيع المخزون', 7),
('OTHER', 'Other', 'أخرى', 99)
ON CONFLICT (code) DO NOTHING;

-- 6. Add system setting for branch return prefix
INSERT INTO system_settings (key, value, value_type, description) VALUES
('branch_return_prefix', 'BRT', 'string', 'Branch return number prefix')
ON CONFLICT (key) DO NOTHING;

-- 7. Create View for Branch Returns Report
CREATE OR REPLACE VIEW vw_branch_returns AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY br.return_date DESC, br.return_number) as row_num,
    br.return_number,
    br.return_date,
    fb.name as from_branch,
    tb.name as to_branch,
    i.code as item_code,
    i.name as item_name,
    bri.requested_quantity,
    bri.approved_quantity,
    bri.received_quantity,
    bri.unit_cost,
    bri.total_value,
    br.return_reason,
    bri.item_reason,
    br.status,
    u.full_name as requested_by_name,
    br.requested_at
FROM branch_returns br
JOIN branch_return_items bri ON br.id = bri.return_id
JOIN branches fb ON br.from_branch_id = fb.id
JOIN branches tb ON br.to_branch_id = tb.id
JOIN items i ON bri.item_id = i.id
JOIN users u ON br.requested_by = u.id
ORDER BY br.return_date DESC, br.return_number, i.code;

-- 8. Create Function to Generate Branch Return Number
CREATE OR REPLACE FUNCTION generate_branch_return_number()
RETURNS VARCHAR AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'branch_return_prefix';
    prefix := COALESCE(prefix, 'BRT');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(return_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM branch_returns
    WHERE return_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- 9. Create Trigger to Update Branch Return Totals
CREATE OR REPLACE FUNCTION update_branch_return_totals()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE branch_returns SET
        total_items = (SELECT COUNT(*) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        total_quantity = (SELECT COALESCE(SUM(requested_quantity), 0) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        total_value = (SELECT COALESCE(SUM(total_value), 0) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = COALESCE(NEW.return_id, OLD.return_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_br_totals ON branch_return_items;
CREATE TRIGGER trg_update_br_totals
AFTER INSERT OR UPDATE OR DELETE ON branch_return_items
FOR EACH ROW EXECUTE FUNCTION update_branch_return_totals();

-- 10. Add 'branch_return' to inventory_operation ENUM if not exists
-- Note: PostgreSQL doesn't allow easy ALTER TYPE ADD VALUE in transaction
-- So we'll handle this in application logic or use a workaround
