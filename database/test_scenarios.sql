-- =====================================================
-- Restaurant Management System - Full Test Scenarios
-- =====================================================

-- =====================================================
-- SCENARIO 1: User Management
-- =====================================================

-- 1.1 Create Admin User
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP001', 'admin', 'admin@restaurant.com', 'hashed_password_123', 'System Admin', 'مدير النظام', '01000000001',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'admin' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

-- 1.2 Create Warehouse Manager
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP002', 'warehouse_mgr', 'warehouse@restaurant.com', 'hashed_password_123', 'Ahmed Mohamed', 'أحمد محمد', '01000000002',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'warehouse_manager' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

-- 1.3 Create Branch Supervisor for Branch 1
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP003', 'branch1_sup', 'branch1@restaurant.com', 'hashed_password_123', 'Mohamed Ali', 'محمد علي', '01000000003',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'branch_supervisor' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

-- 1.4 Create Cashier for Branch 1
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP004', 'cashier1', 'cashier1@restaurant.com', 'hashed_password_123', 'Sara Ahmed', 'سارة أحمد', '01000000004',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'cashier' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

-- 1.5 Create Chef for Branch 1
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP005', 'chef1', 'chef1@restaurant.com', 'hashed_password_123', 'Hassan Ibrahim', 'حسن إبراهيم', '01000000005',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'chef' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

-- =====================================================
-- SCENARIO 2: Categories & Items Setup
-- =====================================================

-- 2.1 Create Categories
INSERT INTO categories (code, name, name_ar, description, sort_order) VALUES
('CAT001', 'Meat', 'لحوم', 'All types of meat', 1),
('CAT002', 'Vegetables', 'خضروات', 'Fresh vegetables', 2),
('CAT003', 'Dairy', 'ألبان', 'Dairy products', 3),
('CAT004', 'Beverages', 'مشروبات', 'Drinks and beverages', 4),
('CAT005', 'Spices', 'توابل', 'Spices and seasonings', 5),
('CAT006', 'Oils', 'زيوت', 'Cooking oils', 6),
('CAT007', 'Grains', 'حبوب', 'Rice, pasta, etc.', 7),
('CAT008', 'Packaging', 'تغليف', 'Packaging materials', 8)
ON CONFLICT (code) DO NOTHING;

-- 2.2 Create Items
INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM001', '1234567890001', 'Chicken Breast', 'صدور دجاج', c.id, u.id, 80.00, 0, 50, TRUE, 5, 'active'
FROM categories c, units u WHERE c.code = 'CAT001' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM002', '1234567890002', 'Beef Meat', 'لحم بقري', c.id, u.id, 250.00, 0, 30, TRUE, 3, 'active'
FROM categories c, units u WHERE c.code = 'CAT001' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM003', '1234567890003', 'Tomatoes', 'طماطم', c.id, u.id, 15.00, 0, 100, TRUE, 7, 'active'
FROM categories c, units u WHERE c.code = 'CAT002' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM004', '1234567890004', 'Onions', 'بصل', c.id, u.id, 10.00, 0, 80, TRUE, 14, 'active'
FROM categories c, units u WHERE c.code = 'CAT002' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM005', '1234567890005', 'Cooking Oil', 'زيت طبخ', c.id, u.id, 45.00, 0, 20, FALSE, 365, 'active'
FROM categories c, units u WHERE c.code = 'CAT006' AND u.code = 'L'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM006', '1234567890006', 'Rice', 'أرز', c.id, u.id, 35.00, 0, 100, FALSE, 180, 'active'
FROM categories c, units u WHERE c.code = 'CAT007' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM007', '1234567890007', 'Cheese', 'جبنة', c.id, u.id, 120.00, 0, 20, TRUE, 30, 'active'
FROM categories c, units u WHERE c.code = 'CAT003' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, selling_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM008', '1234567890008', 'Pepsi', 'بيبسي', c.id, u.id, 8.00, 0, 200, FALSE, 180, 'active'
FROM categories c, units u WHERE c.code = 'CAT004' AND u.code = 'BTL'
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- SCENARIO 3: Suppliers Setup
-- =====================================================

-- 3.1 Create Suppliers
INSERT INTO suppliers (code, name, name_ar, contact_person, phone, email, address, city, payment_terms, credit_limit, credit_period_days, status)
VALUES 
('SUP001', 'Fresh Meat Co.', 'شركة اللحوم الطازجة', 'Mahmoud Hassan', '01100000001', 'meat@supplier.com', '123 Industrial Area', 'Cairo', 'credit', 50000.00, 30, 'active'),
('SUP002', 'Green Farms', 'المزارع الخضراء', 'Ali Mohamed', '01100000002', 'farms@supplier.com', '456 Agriculture Zone', 'Giza', 'cash', 0, 0, 'active'),
('SUP003', 'Dairy Products Ltd', 'منتجات الألبان', 'Fatma Ahmed', '01100000003', 'dairy@supplier.com', '789 Food District', 'Alexandria', 'credit', 30000.00, 15, 'active'),
('SUP004', 'Beverages Distributor', 'موزع المشروبات', 'Omar Khaled', '01100000004', 'drinks@supplier.com', '321 Commercial St', 'Cairo', 'credit', 20000.00, 7, 'active')
ON CONFLICT (code) DO NOTHING;

-- 3.2 Link Suppliers to Items
INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'SM-001', 78.00, 10, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'SM-002', 245.00, 5, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'GF-001', 14.00, 20, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP002' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'GF-002', 9.00, 30, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP002' AND i.code = 'ITM004'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'DP-001', 115.00, 5, 2, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP003' AND i.code = 'ITM007'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'BD-001', 7.50, 100, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP004' AND i.code = 'ITM008'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;


-- =====================================================
-- SCENARIO 4: Supply Flow (توريد من المورد)
-- =====================================================

-- 4.1 Create Supply from SUP001 (Credit) to Main Warehouse
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, received_by, received_at)
SELECT 'SUP-2024-001', s.id, b.id, 'INV-001', CURRENT_DATE, 5000.00, 700.00, 5700.00, 'credit', 'pending', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'SUP001' AND b.code = 'MAIN' AND u.username = 'warehouse_mgr'
ON CONFLICT (supply_number) DO NOTHING;

-- 4.2 Add Supply Items
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 30, 30, 78.00, 14, 2668.80, 'BATCH-001', CURRENT_DATE + INTERVAL '5 days'
FROM supplies sup, items i
WHERE sup.supply_number = 'SUP-2024-001' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 10, 10, 245.00, 14, 2793.00, 'BATCH-002', CURRENT_DATE + INTERVAL '3 days'
FROM supplies sup, items i
WHERE sup.supply_number = 'SUP-2024-001' AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- 4.3 Update Supplier Balance (Credit Purchase)
UPDATE suppliers SET current_balance = current_balance + 5700.00 WHERE code = 'SUP001';

-- 4.4 Create Supply from SUP002 (Cash) to Main Warehouse
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, paid_amount, received_by, received_at)
SELECT 'SUP-2024-002', s.id, b.id, 'INV-002', CURRENT_DATE, 1000.00, 140.00, 1140.00, 'cash', 'paid', 1140.00, u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'SUP002' AND b.code = 'MAIN' AND u.username = 'warehouse_mgr'
ON CONFLICT (supply_number) DO NOTHING;

-- 4.5 Add Supply Items for Cash Supply
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 50, 50, 14.00, 14, 798.00, 'BATCH-003', CURRENT_DATE + INTERVAL '7 days'
FROM supplies sup, items i
WHERE sup.supply_number = 'SUP-2024-002' AND i.code = 'ITM003'
ON CONFLICT DO NOTHING;

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 40, 40, 9.00, 14, 410.40, 'BATCH-004', CURRENT_DATE + INTERVAL '14 days'
FROM supplies sup, items i
WHERE sup.supply_number = 'SUP-2024-002' AND i.code = 'ITM004'
ON CONFLICT DO NOTHING;

-- =====================================================
-- SCENARIO 5: Initialize Inventory
-- =====================================================

-- 5.1 Add Inventory for Main Warehouse
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 30, 50, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 30;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 10, 30, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 10;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 50, 100, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 50;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 40, 80, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM004'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 40;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 25, 20, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM005'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 25;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 150, 100, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM006'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 150;

-- 5.2 Add Inventory Batches
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-001', 30, 30, 78.00, CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-001'
WHERE b.code = 'MAIN' AND i.code = 'ITM001';

INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-002', 10, 10, 245.00, CURRENT_DATE + INTERVAL '3 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-001'
WHERE b.code = 'MAIN' AND i.code = 'ITM002';

-- 5.3 Record Inventory Transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'supply', 30, 0, 30, 78.00, 'supply', sup.id, u.id
FROM branches b, items i, supplies sup, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND sup.supply_number = 'SUP-2024-001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'supply', 10, 0, 10, 245.00, 'supply', sup.id, u.id
FROM branches b, items i, supplies sup, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND sup.supply_number = 'SUP-2024-001' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO 6: Transfer Flow (تحويل من المخزن للفرع)
-- =====================================================

-- 6.1 Create Transfer Request from Main to Branch 1
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TRF-2024-001', b1.id, b2.id, 'pending', 1, 'Weekly supply for Branch 1', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'branch1_sup'
ON CONFLICT (transfer_number) DO NOTHING;

-- 6.2 Add Transfer Items
INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 10, 'Urgent need'
FROM transfers t, items i
WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM001';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 5, NULL
FROM transfers t, items i
WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM002';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 20, NULL
FROM transfers t, items i
WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM003';

-- 6.3 Approve Transfer
UPDATE transfers SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'warehouse_mgr'),
    approved_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TRF-2024-001';

UPDATE transfer_items SET 
    approved_quantity = requested_quantity,
    shipped_quantity = requested_quantity
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-001');

-- 6.4 Receive Transfer at Branch
UPDATE transfers SET 
    status = 'received',
    received_by = (SELECT id FROM users WHERE username = 'branch1_sup'),
    received_at = CURRENT_TIMESTAMP,
    shipped_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TRF-2024-001';

UPDATE transfer_items SET received_quantity = shipped_quantity
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-001');

-- 6.5 Update Inventory after Transfer
-- Deduct from Main Warehouse
UPDATE inventory SET quantity = quantity - 10 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity - 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE inventory SET quantity = quantity - 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM003');

-- Add to Branch 1
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 10, 10 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 10;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 5, 5 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 5;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 20, 20 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 20;

-- 6.6 Record Transfer Transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'transfer_out', 10, 30, 20, 'transfer', t.id, u.id
FROM branches b, items i, transfers t, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND t.transfer_number = 'TRF-2024-001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'transfer_in', 10, 0, 10, 'transfer', t.id, u.id
FROM branches b, items i, transfers t, users u
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND t.transfer_number = 'TRF-2024-001' AND u.username = 'branch1_sup';


-- =====================================================
-- SCENARIO 7: Damage Flow (تسجيل تالف)
-- =====================================================

-- 7.1 Register Damage at Main Warehouse (Expired Item)
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-001', b.id, i.id, 2, 245.00, 490.00, dr.id, 'Found expired during inspection', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND dr.code = 'EXPIRED' AND u.username = 'warehouse_mgr'
ON CONFLICT (damage_number) DO NOTHING;

-- 7.2 Approve Damage
UPDATE damages SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE damage_number = 'DMG-2024-001';

-- 7.3 Deduct from Inventory
UPDATE inventory SET quantity = quantity - 2 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 7.4 Record Damage Transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'damage', 2, 5, 3, 245.00, 'damage', d.id, u.id
FROM branches b, items i, damages d, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND d.damage_number = 'DMG-2024-001' AND u.username = 'warehouse_mgr';

-- 7.5 Register Damage at Branch (Storage Issue)
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-002', b.id, i.id, 3, 78.00, 234.00, dr.id, 'Refrigerator malfunction', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND dr.code = 'STORAGE' AND u.username = 'branch1_sup'
ON CONFLICT (damage_number) DO NOTHING;

-- =====================================================
-- SCENARIO 8: Supplier Return Flow (مرتجع للمورد)
-- =====================================================

-- 8.1 Register Return for Defective Items
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'RET-2024-001', sup.id, s.id, i.id, 5, 78.00, 390.00, 'Defective quality', 'Chicken had bad smell upon opening', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'SUP-2024-001' AND s.code = 'SUP001' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr'
ON CONFLICT (return_number) DO NOTHING;

-- 8.2 Approve Return
UPDATE supplier_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'RET-2024-001';

-- 8.3 Deduct from Inventory
UPDATE inventory SET quantity = quantity - 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 8.4 Update Supplier Balance (Credit Return)
UPDATE suppliers SET current_balance = current_balance - 390.00 WHERE code = 'SUP001';

-- 8.5 Record Return Transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'return', 5, 20, 15, 78.00, 'supplier_return', sr.id, u.id
FROM branches b, items i, supplier_returns sr, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND sr.return_number = 'RET-2024-001' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO 9: Supplier Payment Flow (سداد للمورد)
-- =====================================================

-- 9.1 Make Partial Payment to Supplier
INSERT INTO supplier_payments (payment_number, supplier_id, supply_id, amount, payment_method, reference_number, payment_date, notes, created_by)
SELECT 'PAY-2024-001', s.id, sup.id, 3000.00, 'bank_transfer', 'TRX-123456', CURRENT_DATE, 'Partial payment', u.id
FROM suppliers s, supplies sup, users u
WHERE s.code = 'SUP001' AND sup.supply_number = 'SUP-2024-001' AND u.username = 'admin'
ON CONFLICT (payment_number) DO NOTHING;

-- 9.2 Update Supplier Balance
UPDATE suppliers SET current_balance = current_balance - 3000.00 WHERE code = 'SUP001';

-- 9.3 Update Supply Payment Status
UPDATE supplies SET 
    paid_amount = paid_amount + 3000.00,
    payment_status = 'partial'
WHERE supply_number = 'SUP-2024-001';

-- =====================================================
-- SCENARIO 10: Menu & Orders Flow (المنيو والأوردرات)
-- =====================================================

-- 10.1 Create Menu Categories
INSERT INTO menu_categories (code, name, name_ar, description, sort_order, is_active) VALUES
('MCAT001', 'Grills', 'مشويات', 'Grilled items', 1, TRUE),
('MCAT002', 'Sandwiches', 'سندوتشات', 'Sandwiches', 2, TRUE),
('MCAT003', 'Meals', 'وجبات', 'Complete meals', 3, TRUE),
('MCAT004', 'Drinks', 'مشروبات', 'Beverages', 4, TRUE)
ON CONFLICT (code) DO NOTHING;

-- 10.2 Create Menu Items
INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU001', 'Grilled Chicken', 'دجاج مشوي', 'Quarter grilled chicken with rice', mc.id, 85.00, 45.00, 14, 20, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT001'
ON CONFLICT (code) DO NOTHING;

INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU002', 'Beef Kofta', 'كفتة لحم', 'Grilled beef kofta with salad', mc.id, 120.00, 70.00, 14, 25, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT001'
ON CONFLICT (code) DO NOTHING;

INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU003', 'Chicken Sandwich', 'سندوتش فراخ', 'Grilled chicken sandwich', mc.id, 45.00, 25.00, 14, 10, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT002'
ON CONFLICT (code) DO NOTHING;

INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU004', 'Pepsi', 'بيبسي', 'Pepsi 330ml', mc.id, 15.00, 8.00, 14, 1, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT004'
ON CONFLICT (code) DO NOTHING;

-- 10.3 Add Menu Item Ingredients
INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.250, u.id, FALSE
FROM menu_items mi, items i, units u
WHERE mi.code = 'MENU001' AND i.code = 'ITM001' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.100, u.id, FALSE
FROM menu_items mi, items i, units u
WHERE mi.code = 'MENU001' AND i.code = 'ITM006' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.200, u.id, FALSE
FROM menu_items mi, items i, units u
WHERE mi.code = 'MENU002' AND i.code = 'ITM002' AND u.code = 'KG';

-- 10.4 Create Order
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, payment_method, status, cashier_id, created_at)
SELECT 'ORD-2024-001', b.id, 'dine_in', 'Ahmed Customer', '01200000001', 220.00, 30.80, 250.80, 'cash', 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'cashier1'
ON CONFLICT (order_number) DO NOTHING;

-- 10.5 Add Order Items
INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 2, 85.00, 170.00, 'pending'
FROM orders o, menu_items mi
WHERE o.order_number = 'ORD-2024-001' AND mi.code = 'MENU001';

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 2, 15.00, 30.00, 'pending'
FROM orders o, menu_items mi
WHERE o.order_number = 'ORD-2024-001' AND mi.code = 'MENU004';

-- 10.6 Update Order Status Flow
UPDATE orders SET status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE order_number = 'ORD-2024-001';
UPDATE orders SET status = 'in_kitchen', sent_to_kitchen_at = CURRENT_TIMESTAMP, chef_id = (SELECT id FROM users WHERE username = 'chef1') WHERE order_number = 'ORD-2024-001';
UPDATE orders SET status = 'preparing', preparation_started_at = CURRENT_TIMESTAMP WHERE order_number = 'ORD-2024-001';
UPDATE orders SET status = 'ready', ready_at = CURRENT_TIMESTAMP WHERE order_number = 'ORD-2024-001';
UPDATE orders SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP WHERE order_number = 'ORD-2024-001';

-- 10.7 Deduct Ingredients from Inventory (Consumption)
UPDATE inventory SET quantity = quantity - 0.5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 10.8 Record Consumption Transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, reference_id, created_by)
SELECT b.id, i.id, 'consumption', 0.5, 10, 9.5, 'order', o.id, u.id
FROM branches b, items i, orders o, users u
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND o.order_number = 'ORD-2024-001' AND u.username = 'cashier1';


-- =====================================================
-- SCENARIO 11: Daily Inventory Count (الجرد اليومي)
-- =====================================================

-- 11.1 Create Morning Count
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'morning', 'submitted', 'Morning opening count', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'branch1_sup';

-- 11.2 Add Count Items
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 10, 10, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'morning' AND i.code = 'ITM001';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 5, 5, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'morning' AND i.code = 'ITM002';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 20, 19, 'One tomato was damaged'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'morning' AND i.code = 'ITM003';

-- =====================================================
-- SCENARIO 12: Notifications & Alerts
-- =====================================================

-- 12.1 Low Stock Alert
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, reference_id, is_read)
SELECT u.id, b.id, 'low_stock', 'Low Stock Alert', 'Item ITM002 (Beef Meat) is below minimum stock level', 'high', 'item', i.id, FALSE
FROM users u, branches b, items i
WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN' AND i.code = 'ITM002';

-- 12.2 Expiry Warning
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'expiry_warning', 'Expiry Warning', 'Some items will expire in 3 days', 'high', 'inventory', FALSE
FROM users u, branches b
WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- 12.3 Transfer Request Notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, reference_id, is_read)
SELECT u.id, b.id, 'transfer_request', 'New Transfer Request', 'Branch 1 requested items transfer', 'normal', 'transfer', t.id, FALSE
FROM users u, branches b, transfers t
WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN' AND t.transfer_number = 'TRF-2024-001';

-- 12.4 Pending Approval Notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, reference_id, is_read)
SELECT u.id, NULL, 'pending_approval', 'Damage Pending Approval', 'Damage DMG-2024-002 needs your approval', 'normal', 'damage', d.id, FALSE
FROM users u, damages d
WHERE u.username = 'admin' AND d.damage_number = 'DMG-2024-002';

-- =====================================================
-- SCENARIO 13: Alert Settings
-- =====================================================

INSERT INTO alert_settings (branch_id, alert_type, is_enabled, threshold_value, threshold_days, notify_roles)
SELECT b.id, 'low_stock', TRUE, NULL, 7, ARRAY['warehouse_manager', 'admin']
FROM branches b WHERE b.code = 'MAIN'
ON CONFLICT ON CONSTRAINT uk_alert_setting DO NOTHING;

INSERT INTO alert_settings (branch_id, alert_type, is_enabled, threshold_value, threshold_days, notify_roles)
SELECT b.id, 'expiry_warning', TRUE, NULL, 30, ARRAY['warehouse_manager', 'admin']
FROM branches b WHERE b.code = 'MAIN'
ON CONFLICT ON CONSTRAINT uk_alert_setting DO NOTHING;

INSERT INTO alert_settings (branch_id, alert_type, is_enabled, threshold_value, threshold_days, notify_roles)
SELECT b.id, 'low_stock', TRUE, NULL, 3, ARRAY['branch_supervisor']
FROM branches b WHERE b.code = 'BR001'
ON CONFLICT ON CONSTRAINT uk_alert_setting DO NOTHING;

-- =====================================================
-- SCENARIO 14: Audit Logs
-- =====================================================

INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplies', sup.id, NULL, '{"supply_number": "SUP-2024-001", "total_amount": 5700}', '192.168.1.100'
FROM users u, supplies sup
WHERE u.username = 'warehouse_mgr' AND sup.supply_number = 'SUP-2024-001';

INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'transfers', t.id, '{"status": "pending"}', '{"status": "approved"}', '192.168.1.100'
FROM users u, transfers t
WHERE u.username = 'warehouse_mgr' AND t.transfer_number = 'TRF-2024-001';

INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'damages', d.id, '{"status": "pending"}', '{"status": "approved"}', '192.168.1.101'
FROM users u, damages d
WHERE u.username = 'admin' AND d.damage_number = 'DMG-2024-001';

-- =====================================================
-- SCENARIO 15: User Sessions
-- =====================================================

INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_abc123', 'Chrome on Windows', '192.168.1.100', TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', CURRENT_TIMESTAMP
FROM users u WHERE u.username = 'admin';

INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_def456', 'Firefox on Windows', '192.168.1.101', TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', CURRENT_TIMESTAMP
FROM users u WHERE u.username = 'cashier1';

-- =====================================================
-- SCENARIO 16: Branch Settings
-- =====================================================

INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'receipt_header', 'Welcome to Our Restaurant', u.id
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;

INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'receipt_footer', 'Thank you for visiting!', u.id
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;

INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'auto_print_kitchen', 'true', u.id
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;
