-- =====================================================
-- Schema Update V3: Purchase Manager System
-- Adding Purchase Requests and Purchase Manager Role
-- =====================================================

-- 1. Add Purchase Manager Role
INSERT INTO roles (name, name_ar, description, permissions, is_system_role) VALUES
('purchase_manager', 'Purchase Manager', 'Manages all purchase requests and supplier orders', 
 '{"purchases": true, "suppliers": true, "inventory_view": true}', TRUE)
ON CONFLICT (name) DO NOTHING;

-- 2. Create Purchase Request Status ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_request_status') THEN
        CREATE TYPE purchase_request_status AS ENUM ('draft', 'pending', 'approved', 'rejected', 'ordered', 'partially_received', 'completed', 'cancelled');
    END IF;
END $$;

-- 3. Create Purchase Requests Table (Master)
CREATE TABLE IF NOT EXISTS purchase_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_number VARCHAR(30) NOT NULL UNIQUE,
    request_date DATE NOT NULL DEFAULT CURRENT_DATE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    status purchase_request_status DEFAULT 'draft',
    priority INTEGER DEFAULT 0,
    notes TEXT,
    total_items INTEGER DEFAULT 0,
    total_quantity DECIMAL(12, 3) DEFAULT 0,
    estimated_cost DECIMAL(12, 2) DEFAULT 0,
    
    -- Workflow
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_purchase_requests_date ON purchase_requests(request_date);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_branch ON purchase_requests(branch_id);

-- 4. Create Purchase Request Items Table (Details)
CREATE TABLE IF NOT EXISTS purchase_request_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    
    -- Quantities
    requested_quantity DECIMAL(12, 3) NOT NULL,
    approved_quantity DECIMAL(12, 3),
    ordered_quantity DECIMAL(12, 3),
    received_quantity DECIMAL(12, 3) DEFAULT 0,
    
    -- Pricing
    estimated_unit_price DECIMAL(12, 2),
    estimated_total DECIMAL(12, 2),
    
    -- Notes
    notes TEXT,
    
    -- Status
    item_status VARCHAR(20) DEFAULT 'pending',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_request_item UNIQUE (request_id, item_id),
    CONSTRAINT chk_request_qty CHECK (requested_quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_pr_items_request ON purchase_request_items(request_id);
CREATE INDEX IF NOT EXISTS idx_pr_items_item ON purchase_request_items(item_id);
CREATE INDEX IF NOT EXISTS idx_pr_items_supplier ON purchase_request_items(supplier_id);

-- 5. Create Purchase Orders Table (When request is converted to order)
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(30) NOT NULL UNIQUE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    request_id UUID REFERENCES purchase_requests(id) ON DELETE SET NULL,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    
    -- Amounts
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) DEFAULT 0,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',
    expected_delivery_date DATE,
    
    -- Notes
    notes TEXT,
    
    -- Workflow
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_po_date ON purchase_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON purchase_orders(status);

-- 6. Create Purchase Order Items Table
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    request_item_id UUID REFERENCES purchase_request_items(id) ON DELETE SET NULL,
    
    quantity DECIMAL(12, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    total_price DECIMAL(12, 2) NOT NULL,
    
    received_quantity DECIMAL(12, 3) DEFAULT 0,
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_po_item_qty CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_poi_order ON purchase_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_poi_item ON purchase_order_items(item_id);

-- 7. Add system setting for purchase request prefix
INSERT INTO system_settings (key, value, value_type, description) VALUES
('purchase_request_prefix', 'PR', 'string', 'Purchase request number prefix'),
('purchase_order_prefix', 'PO', 'string', 'Purchase order number prefix')
ON CONFLICT (key) DO NOTHING;

-- 8. Create View for Purchase Manager Dashboard
CREATE OR REPLACE VIEW vw_purchase_requests AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY pr.request_date DESC, pr.request_number) as row_num,
    pr.request_date as date,
    pr.request_number as document_number,
    pri.id as item_row_id,
    i.code as item_code,
    i.name as item_name,
    i.name_ar as item_name_ar,
    COALESCE(s.name, 'Not Assigned') as supplier_name,
    COALESCE(s.name_ar, 'Not Assigned') as supplier_name_ar,
    pri.requested_quantity as quantity,
    pri.notes as notes,
    pr.status as request_status,
    b.name as branch_name,
    u.full_name as requested_by_name
FROM purchase_requests pr
JOIN purchase_request_items pri ON pr.id = pri.request_id
JOIN items i ON pri.item_id = i.id
LEFT JOIN suppliers s ON pri.supplier_id = s.id
JOIN branches b ON pr.branch_id = b.id
JOIN users u ON pr.requested_by = u.id
ORDER BY pr.request_date DESC, pr.request_number, i.code;

-- 9. Create View for Purchase Manager Report (Arabic Headers)
CREATE OR REPLACE VIEW vw_purchase_manager_report AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY pr.request_date DESC, pr.request_number, i.code) as "م",
    pr.request_date as "التاريخ",
    pr.request_number as "رقم المستند",
    i.code as "كود الصنف",
    i.name as "اسم الصنف",
    COALESCE(s.name, '-') as "اسم الشركة / المورد",
    pri.requested_quantity as "الكمية",
    COALESCE(pri.notes, '') as "ملاحظات"
FROM purchase_requests pr
JOIN purchase_request_items pri ON pr.id = pri.request_id
JOIN items i ON pri.item_id = i.id
LEFT JOIN suppliers s ON pri.supplier_id = s.id
ORDER BY pr.request_date DESC, pr.request_number, i.code;

-- 10. Create Function to Generate Purchase Request Number
CREATE OR REPLACE FUNCTION generate_purchase_request_number()
RETURNS VARCHAR AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'purchase_request_prefix';
    prefix := COALESCE(prefix, 'PR');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(request_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM purchase_requests
    WHERE request_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- 11. Create Function to Generate Purchase Order Number
CREATE OR REPLACE FUNCTION generate_purchase_order_number()
RETURNS VARCHAR AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'purchase_order_prefix';
    prefix := COALESCE(prefix, 'PO');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM purchase_orders
    WHERE order_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- 12. Create Trigger to Update Purchase Request Totals
CREATE OR REPLACE FUNCTION update_purchase_request_totals()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE purchase_requests SET
        total_items = (SELECT COUNT(*) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        total_quantity = (SELECT COALESCE(SUM(requested_quantity), 0) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        estimated_cost = (SELECT COALESCE(SUM(estimated_total), 0) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = COALESCE(NEW.request_id, OLD.request_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_pr_totals ON purchase_request_items;
CREATE TRIGGER trg_update_pr_totals
AFTER INSERT OR UPDATE OR DELETE ON purchase_request_items
FOR EACH ROW EXECUTE FUNCTION update_purchase_request_totals();
